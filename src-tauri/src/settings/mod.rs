use std::{path::Path, sync::Mutex};

use rusqlite::{params, Connection, OptionalExtension, TransactionBehavior};
use serde::{de::DeserializeOwned, Deserialize, Serialize};
use tauri::Manager;

use crate::playback::preferences::PlaybackPreferences;
use crate::scenery::collection::SceneryCollection;
use crate::storage::migrations;

const THEME_KEY: &str = "ui.themeId";
const GLASS_KEY: &str = "ui.glass";
const RECURSIVE_SCAN_KEY: &str = "library.recursiveScan";
const INCLUDE_VIDEO_KEY: &str = "library.includeVideo";
const AUTOPLAY_ON_LOAD_KEY: &str = "library.autoplayOnLoad";
const SCENERY_PATH_KEY: &str = "ui.sceneryPath";
const SCENERY_COLLECTION_KEY: &str = "ui.sceneryCollection";
const SCENERY_INTENSITY_KEY: &str = "ui.sceneryIntensity";
const SCENERY_REVEAL_KEY: &str = "ui.sceneryReveal";
const SCENERY_AUTO_ROTATE_KEY: &str = "ui.sceneryAutoRotate";
const PLAYBACK_PREFERENCES_KEY: &str = "playback.preferences";
const UPSERT_PREFERENCE: &str = "INSERT INTO settings (key, value_json) VALUES (?1, ?2)
    ON CONFLICT(key) DO UPDATE SET value_json = excluded.value_json,
    updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')";

#[derive(Clone, Copy, Debug, Default, Deserialize, PartialEq, Eq, Serialize)]
#[serde(rename_all = "kebab-case")]
enum ThemeId {
    #[default]
    Studio,
    Nocturne,
    Tide,
    Rose,
    Iris,
    Ember,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct SettingsSnapshot {
    glass: GlassSettings,
    schema_version: u32,
    theme_id: ThemeId,
    recursive_scan: bool,
    include_video: bool,
    autoplay_on_load: bool,
    scenery_intensity: u8,
    scenery_reveal: u16,
    scenery_auto_rotate: bool,
}

impl Default for SettingsSnapshot {
    fn default() -> Self {
        Self {
            glass: GlassSettings::default(),
            schema_version: 1,
            theme_id: ThemeId::default(),
            recursive_scan: true,
            include_video: true,
            autoplay_on_load: true,
            scenery_intensity: 100,
            scenery_reveal: 0,
            scenery_auto_rotate: false,
        }
    }
}

#[derive(Clone, Debug, Default, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct SettingsUpdateRequest {
    glass: Option<GlassSettings>,
    theme_id: Option<ThemeId>,
    recursive_scan: Option<bool>,
    include_video: Option<bool>,
    autoplay_on_load: Option<bool>,
    scenery_intensity: Option<u8>,
    scenery_reveal: Option<u16>,
    scenery_auto_rotate: Option<bool>,
}

impl SettingsUpdateRequest {
    fn is_empty(&self) -> bool {
        self.theme_id.is_none()
            && self.glass.is_none()
            && self.recursive_scan.is_none()
            && self.include_video.is_none()
            && self.autoplay_on_load.is_none()
            && self.scenery_intensity.is_none()
            && self.scenery_reveal.is_none()
            && self.scenery_auto_rotate.is_none()
    }
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq, Serialize)]
#[serde(rename_all = "kebab-case")]
enum GlassMaterial {
    Clear,
    Soft,
    Frosted,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq, Serialize)]
#[serde(deny_unknown_fields)]
struct GlassSettings {
    material: GlassMaterial,
    transparency: u8,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    fog: Option<u8>,
}

impl Default for GlassSettings {
    fn default() -> Self {
        Self {
            material: GlassMaterial::Soft,
            transparency: 35,
            fog: None,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub(crate) struct SettingsError {
    code: String,
    message: String,
}

impl SettingsError {
    fn new(code: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            code: code.into(),
            message: message.into(),
        }
    }

    fn database() -> Self {
        Self::new(
            "database",
            "The local Heni settings database is temporarily unavailable.",
        )
    }
}

struct SettingsRepository {
    connection: Connection,
}

impl SettingsRepository {
    fn scenery_collection(&self) -> Result<SceneryCollection, SettingsError> {
        let saved: Option<SceneryCollection> = self.read_json(SCENERY_COLLECTION_KEY, None)?;
        let collection = match saved {
            Some(saved) => saved,
            None => SceneryCollection {
                paths: self.scenery_path()?.into_iter().collect(),
                index: 0,
            },
        };
        if !collection.valid() {
            return Err(SettingsError::database());
        }
        Ok(collection)
    }

    fn set_scenery_collection(&mut self, value: &SceneryCollection) -> Result<(), SettingsError> {
        if !value.valid() {
            return Err(SettingsError::database());
        }
        self.write_json(SCENERY_COLLECTION_KEY, value)
    }

    fn playback_preferences(&self) -> Result<PlaybackPreferences, SettingsError> {
        self.read_json(PLAYBACK_PREFERENCES_KEY, PlaybackPreferences::default())?
            .validate()
            .map_err(|_| SettingsError::database())
    }

    fn set_playback_preferences(
        &mut self,
        preferences: PlaybackPreferences,
    ) -> Result<(), SettingsError> {
        preferences
            .validate()
            .map_err(|_| SettingsError::new("invalid-contract", "Invalid audio preferences."))?;
        self.write_json(PLAYBACK_PREFERENCES_KEY, &preferences)
    }

    fn scenery_path(&self) -> Result<Option<String>, SettingsError> {
        self.read_json(SCENERY_PATH_KEY, None)
    }

    #[cfg(test)]
    fn set_scenery_path(&mut self, path: Option<&str>) -> Result<(), SettingsError> {
        self.write_json(SCENERY_PATH_KEY, &path)
    }

    fn write_json<T: Serialize>(&mut self, key: &str, value: &T) -> Result<(), SettingsError> {
        let value = encode(value)?;
        let transaction = self
            .connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(|_| SettingsError::database())?;
        transaction
            .execute(UPSERT_PREFERENCE, params![key, value])
            .map_err(|_| SettingsError::database())?;
        transaction.commit().map_err(|_| SettingsError::database())
    }

    fn open(path: &Path) -> Result<Self, SettingsError> {
        let connection = Connection::open(path).map_err(|_| SettingsError::database())?;
        Self::from_connection(connection)
    }

    fn from_connection(mut connection: Connection) -> Result<Self, SettingsError> {
        migrations::apply(&mut connection).map_err(|_| SettingsError::database())?;
        Ok(Self { connection })
    }

    fn read_json<T: DeserializeOwned>(&self, key: &str, fallback: T) -> Result<T, SettingsError> {
        let value = self
            .connection
            .query_row(
                "SELECT value_json FROM settings WHERE key = ?1",
                [key],
                |row| row.get::<_, String>(0),
            )
            .optional()
            .map_err(|_| SettingsError::database())?;
        value.map_or(Ok(fallback), |json| {
            serde_json::from_str(&json).map_err(|_| SettingsError::database())
        })
    }

    fn snapshot(&self) -> Result<SettingsSnapshot, SettingsError> {
        let defaults = SettingsSnapshot::default();
        let glass: GlassSettings = self.read_json(GLASS_KEY, GlassSettings::default())?;
        let scenery_reveal: u16 = self.read_json(SCENERY_REVEAL_KEY, defaults.scenery_reveal)?;
        if scenery_reveal > 300 {
            return Err(SettingsError::database());
        }
        if glass.transparency > 100 || glass.fog.is_some_and(|fog| fog > 100) {
            return Err(SettingsError::database());
        }
        Ok(SettingsSnapshot {
            scenery_reveal,
            glass,
            schema_version: defaults.schema_version,
            theme_id: self.read_json(THEME_KEY, defaults.theme_id)?,
            recursive_scan: self.read_json(RECURSIVE_SCAN_KEY, defaults.recursive_scan)?,
            include_video: self.read_json(INCLUDE_VIDEO_KEY, defaults.include_video)?,
            autoplay_on_load: self.read_json(AUTOPLAY_ON_LOAD_KEY, defaults.autoplay_on_load)?,
            scenery_intensity: self
                .read_json::<u8>(SCENERY_INTENSITY_KEY, defaults.scenery_intensity)?
                .min(100),
            scenery_auto_rotate: self
                .read_json(SCENERY_AUTO_ROTATE_KEY, defaults.scenery_auto_rotate)?,
        })
    }

    fn update(
        &mut self,
        request: &SettingsUpdateRequest,
    ) -> Result<SettingsSnapshot, SettingsError> {
        if request.is_empty() {
            return Err(SettingsError::new(
                "invalid-contract",
                "A settings update must include at least one preference.",
            ));
        }
        if request
            .glass
            .as_ref()
            .is_some_and(|glass| glass.transparency > 100 || glass.fog.is_some_and(|fog| fog > 100))
        {
            return Err(SettingsError::new(
                "invalid-contract",
                "Invalid glass preferences.",
            ));
        }
        if request.scenery_intensity.is_some_and(|value| value > 100)
            || request.scenery_reveal.is_some_and(|value| value > 300)
        {
            return Err(SettingsError::new(
                "invalid-contract",
                "Invalid scenery intensity.",
            ));
        }
        let transaction = self
            .connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(|_| SettingsError::database())?;
        for (key, value) in request.entries()? {
            transaction
                .execute(UPSERT_PREFERENCE, params![key, value])
                .map_err(|_| SettingsError::database())?;
        }
        transaction
            .commit()
            .map_err(|_| SettingsError::database())?;
        self.snapshot()
    }
}

impl SettingsUpdateRequest {
    fn entries(&self) -> Result<Vec<(&'static str, String)>, SettingsError> {
        let mut entries = Vec::with_capacity(4);
        if let Some(value) = &self.glass {
            entries.push((GLASS_KEY, encode(value)?));
        }
        if let Some(value) = self.theme_id {
            entries.push((THEME_KEY, encode(&value)?));
        }
        if let Some(value) = self.recursive_scan {
            entries.push((RECURSIVE_SCAN_KEY, encode(&value)?));
        }
        if let Some(value) = self.include_video {
            entries.push((INCLUDE_VIDEO_KEY, encode(&value)?));
        }
        if let Some(value) = self.autoplay_on_load {
            entries.push((AUTOPLAY_ON_LOAD_KEY, encode(&value)?));
        }
        if let Some(value) = self.scenery_intensity {
            entries.push((SCENERY_INTENSITY_KEY, encode(&value)?));
        }
        if let Some(value) = self.scenery_reveal {
            entries.push((SCENERY_REVEAL_KEY, encode(&value)?));
        }
        if let Some(value) = self.scenery_auto_rotate {
            entries.push((SCENERY_AUTO_ROTATE_KEY, encode(&value)?));
        }
        Ok(entries)
    }
}

fn encode<T: Serialize>(value: &T) -> Result<String, SettingsError> {
    serde_json::to_string(value).map_err(|_| SettingsError::database())
}

pub(crate) struct SettingsRuntime {
    repository: Mutex<SettingsRepository>,
}

impl SettingsRuntime {
    pub(crate) fn scenery_collection(&self) -> Result<SceneryCollection, SettingsError> {
        self.lock()?.scenery_collection()
    }

    pub(crate) fn set_scenery_collection(
        &self,
        value: &SceneryCollection,
    ) -> Result<(), SettingsError> {
        self.lock()?.set_scenery_collection(value)
    }
    pub(crate) fn playback_preferences(&self) -> Result<PlaybackPreferences, SettingsError> {
        self.lock()?.playback_preferences()
    }

    pub(crate) fn set_playback_preferences(
        &self,
        preferences: PlaybackPreferences,
    ) -> Result<(), SettingsError> {
        self.lock()?.set_playback_preferences(preferences)
    }

    pub(crate) fn open(app: &tauri::AppHandle) -> Result<Self, Box<dyn std::error::Error>> {
        let directory = crate::storage::app_data_directory(app)?;
        let repository = SettingsRepository::open(&crate::storage::database_path(&directory))
            .map_err(|error| std::io::Error::other(error.message))?;
        Ok(Self {
            repository: Mutex::new(repository),
        })
    }

    fn lock(&self) -> Result<std::sync::MutexGuard<'_, SettingsRepository>, SettingsError> {
        self.repository.lock().map_err(|_| {
            SettingsError::new("database", "The settings database lock is unavailable.")
        })
    }
}

#[tauri::command]
pub(crate) async fn settings_snapshot(
    app: tauri::AppHandle,
) -> Result<SettingsSnapshot, SettingsError> {
    settings_work(move || app.state::<SettingsRuntime>().lock()?.snapshot()).await
}

#[tauri::command]
pub(crate) async fn settings_update(
    request: SettingsUpdateRequest,
    app: tauri::AppHandle,
) -> Result<SettingsSnapshot, SettingsError> {
    settings_work(move || app.state::<SettingsRuntime>().lock()?.update(&request)).await
}

async fn settings_work<T: Send + 'static>(
    work: impl FnOnce() -> Result<T, SettingsError> + Send + 'static,
) -> Result<T, SettingsError> {
    tauri::async_runtime::spawn_blocking(work)
        .await
        .map_err(|_| SettingsError::database())?
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn blocking_settings_work_runs_off_the_calling_thread() {
        let caller = std::thread::current().id();
        let worker =
            tauri::async_runtime::block_on(settings_work(|| Ok(std::thread::current().id())))
                .expect("worker result");
        assert_ne!(caller, worker);
    }

    #[test]
    fn settings_worker_preserves_domain_errors() {
        let result = tauri::async_runtime::block_on(settings_work(|| {
            Err::<(), _>(SettingsError::new("invalid-contract", "fixture"))
        }));
        assert_eq!(
            result.expect_err("invalid preference").code,
            "invalid-contract"
        );
    }

    #[test]
    fn settings_worker_failure_does_not_expose_a_panic_payload() {
        let result =
            tauri::async_runtime::block_on(settings_work(|| -> Result<(), SettingsError> {
                panic!("private fixture diagnostic");
            }));
        let error = result.expect_err("worker panicked");
        assert_eq!(error.code, "database");
        assert!(!error.message.contains("private fixture"));
    }

    fn repository() -> SettingsRepository {
        SettingsRepository::from_connection(
            Connection::open_in_memory().expect("in-memory settings database"),
        )
        .expect("settings repository")
    }

    #[test]
    fn collection_restores_legacy_reference_and_clear_does_not_resurrect_it() {
        let mut repository = repository();
        repository
            .set_scenery_path(Some("legacy.png"))
            .expect("legacy fixture");
        assert_eq!(
            repository.scenery_collection().expect("legacy").current(),
            Some("legacy.png")
        );
        repository
            .set_scenery_collection(&SceneryCollection::default())
            .expect("clear");
        assert_eq!(
            repository.scenery_collection().expect("cleared"),
            SceneryCollection::default()
        );
        assert_eq!(
            repository.scenery_path().expect("legacy preserved"),
            Some("legacy.png".into())
        );
    }

    #[test]
    fn collection_reopens_with_order_and_position_and_failed_replacement_is_atomic() {
        let path = std::env::temp_dir().join(format!(
            "heni-collection-{}-{}.sqlite3",
            std::process::id(),
            fastrand::u64(..)
        ));
        let original = SceneryCollection {
            paths: vec!["one.png".into(), "two.jpg".into()],
            index: 1,
        };
        {
            let mut repository = SettingsRepository::open(&path).expect("fixture");
            repository.set_scenery_collection(&original).expect("save");
        }
        {
            let mut repository = SettingsRepository::open(&path).expect("reopen");
            assert_eq!(repository.scenery_collection().expect("restored"), original);
            repository
                .connection
                .execute_batch(
                    "CREATE TRIGGER reject_collection BEFORE UPDATE ON settings
                 WHEN NEW.key = 'ui.sceneryCollection' BEGIN SELECT RAISE(ABORT, 'fixture'); END;",
                )
                .expect("failure fixture");
            assert!(repository
                .set_scenery_collection(&SceneryCollection::default())
                .is_err());
            assert_eq!(
                repository.scenery_collection().expect("unchanged"),
                original
            );
        }
        std::fs::remove_file(path).expect("remove only generated collection fixture");
    }

    #[test]
    fn audio_defaults_do_not_write_or_change_the_existing_schema() {
        let mut repository = repository();
        assert_eq!(
            repository.playback_preferences().expect("defaults"),
            PlaybackPreferences::default()
        );
        let rows: i64 = repository
            .connection
            .query_row("SELECT COUNT(*) FROM settings", [], |row| row.get(0))
            .expect("settings count");
        assert_eq!(rows, 0);
        migrations::apply(&mut repository.connection).expect("migration remains idempotent");
        let versions: i64 = repository
            .connection
            .query_row("SELECT COUNT(*) FROM schema_migrations", [], |row| {
                row.get(0)
            })
            .expect("schema count");
        assert_eq!(versions, 3);
    }

    #[test]
    fn audio_preferences_survive_reopen_without_changing_theme_or_scenery() {
        let path = std::env::temp_dir().join(format!(
            "heni-audio-preferences-{}-{}.sqlite3",
            std::process::id(),
            fastrand::u64(..)
        ));
        let preferences = PlaybackPreferences {
            volume: 0.0,
            muted: true,
            last_audible_volume: 29.0,
        };
        {
            let mut repository = SettingsRepository::open(&path).expect("open");
            repository
                .update(&SettingsUpdateRequest {
                    theme_id: Some(ThemeId::Tide),
                    ..SettingsUpdateRequest::default()
                })
                .expect("theme");
            repository
                .set_scenery_path(Some("C:/Pictures/original.jpg"))
                .expect("scenery");
            repository
                .set_playback_preferences(preferences)
                .expect("audio");
        }
        {
            let repository = SettingsRepository::open(&path).expect("reopen");
            assert_eq!(
                repository.playback_preferences().expect("restored"),
                preferences
            );
            assert_eq!(
                repository.snapshot().expect("theme").theme_id,
                ThemeId::Tide
            );
            assert_eq!(
                repository.scenery_path().expect("scenery").as_deref(),
                Some("C:/Pictures/original.jpg")
            );
        }
        std::fs::remove_file(path).expect("remove only the generated audio-preference database");
    }

    #[test]
    fn failed_audio_write_rolls_back_the_entire_preference_group() {
        let mut repository = repository();
        repository
            .set_playback_preferences(PlaybackPreferences::default())
            .expect("initial");
        repository
            .connection
            .execute_batch(
                "CREATE TRIGGER reject_audio BEFORE UPDATE ON settings
            WHEN NEW.key = 'playback.preferences' BEGIN SELECT RAISE(ABORT, 'test failure'); END;",
            )
            .expect("failure fixture");
        assert!(repository
            .set_playback_preferences(PlaybackPreferences {
                volume: 0.0,
                muted: true,
                last_audible_volume: 35.0,
            })
            .is_err());
        assert_eq!(
            repository.playback_preferences().expect("unchanged"),
            PlaybackPreferences::default()
        );
    }

    #[test]
    fn corrupt_audio_preferences_are_reported_without_silently_overwriting_them() {
        let mut repository = repository();
        for raw in [
            "broken-json",
            r#"{"volume":200,"muted":false,"lastAudibleVolume":30}"#,
        ] {
            repository
                .connection
                .execute(
                    "INSERT OR REPLACE INTO settings(key,value_json) VALUES (?1,?2)",
                    params![PLAYBACK_PREFERENCES_KEY, raw],
                )
                .expect("corrupt fixture");
            assert!(repository.playback_preferences().is_err());
            let stored: String = repository
                .connection
                .query_row(
                    "SELECT value_json FROM settings WHERE key=?1",
                    [PLAYBACK_PREFERENCES_KEY],
                    |row| row.get(0),
                )
                .expect("retained value");
            assert_eq!(stored, raw);
        }
        repository
            .set_playback_preferences(PlaybackPreferences::default())
            .expect("explicit repair");
        assert_eq!(
            repository.playback_preferences().expect("repaired"),
            PlaybackPreferences::default()
        );
    }

    #[test]
    fn scenery_is_an_optional_preference_and_does_not_change_other_settings() {
        let mut repository = repository();
        assert_eq!(repository.scenery_path().expect("default"), None);
        repository
            .set_scenery_path(Some("C:/Pictures/海岸.png"))
            .expect("select");
        assert_eq!(
            repository.scenery_path().expect("saved").as_deref(),
            Some("C:/Pictures/海岸.png")
        );
        repository.set_scenery_path(None).expect("clear");
        assert_eq!(repository.scenery_path().expect("cleared"), None);
        assert_eq!(
            repository.snapshot().expect("settings"),
            SettingsSnapshot::default()
        );
        migrations::apply(&mut repository.connection).expect("migration remains idempotent");
    }

    #[test]
    fn failed_scenery_update_rolls_back_the_previous_selection() {
        let mut repository = repository();
        repository
            .set_scenery_path(Some("C:/Pictures/original.jpg"))
            .expect("initial");
        repository
            .connection
            .execute_batch(
                "CREATE TRIGGER reject_scenery BEFORE UPDATE ON settings
             WHEN NEW.key = 'ui.sceneryPath'
             BEGIN SELECT RAISE(ABORT, 'test failure'); END;",
            )
            .expect("failure fixture");
        assert!(repository
            .set_scenery_path(Some("C:/Pictures/new.jpg"))
            .is_err());
        assert!(repository.set_scenery_path(None).is_err());
        assert_eq!(
            repository.scenery_path().expect("unchanged").as_deref(),
            Some("C:/Pictures/original.jpg")
        );
    }

    #[test]
    fn scenery_selection_and_clear_survive_database_reopen() {
        let path = std::env::temp_dir().join(format!(
            "heni-scenery-settings-{}-{}.sqlite3",
            std::process::id(),
            fastrand::u64(..)
        ));
        {
            let mut repository = SettingsRepository::open(&path).expect("new database");
            repository
                .set_scenery_path(Some("C:/Pictures/海岸.png"))
                .expect("persist selection");
        }
        {
            let mut repository = SettingsRepository::open(&path).expect("reopen");
            assert_eq!(
                repository.scenery_path().expect("restored").as_deref(),
                Some("C:/Pictures/海岸.png")
            );
            repository.set_scenery_path(None).expect("persist clear");
        }
        {
            let repository = SettingsRepository::open(&path).expect("reopen after clear");
            assert_eq!(repository.scenery_path().expect("cleared"), None);
            assert_eq!(
                repository.snapshot().expect("other settings"),
                SettingsSnapshot::default()
            );
        }
        std::fs::remove_file(path).expect("remove only the generated database");
    }

    #[test]
    fn reads_defaults_then_persists_partial_updates() {
        let mut repository = repository();
        assert_eq!(
            repository.snapshot().expect("defaults"),
            SettingsSnapshot::default()
        );

        let updated = repository
            .update(&SettingsUpdateRequest {
                theme_id: Some(ThemeId::Tide),
                include_video: Some(false),
                ..SettingsUpdateRequest::default()
            })
            .expect("update settings");

        assert_eq!(updated.theme_id, ThemeId::Tide);
        assert!(!updated.include_video);
        assert!(updated.recursive_scan);
        assert!(updated.autoplay_on_load);
        assert_eq!(repository.snapshot().expect("persisted"), updated);
    }

    #[test]
    fn rejects_an_empty_update_without_writing() {
        let mut repository = repository();
        let error = repository
            .update(&SettingsUpdateRequest::default())
            .expect_err("empty update");

        assert_eq!(error.code, "invalid-contract");
        assert_eq!(
            repository.snapshot().expect("unchanged"),
            SettingsSnapshot::default()
        );
    }

    #[test]
    fn glass_reopens_and_failed_update_preserves_material_and_theme() {
        let legacy: GlassSettings =
            serde_json::from_str(r#"{"material":"clear","transparency":70}"#)
                .expect("legacy glass");
        assert_eq!(legacy.fog, None);
        let mut fixture = repository();
        assert!(fixture
            .update(&SettingsUpdateRequest {
                glass: Some(GlassSettings {
                    fog: Some(101),
                    ..legacy
                }),
                ..SettingsUpdateRequest::default()
            })
            .is_err());
        let path = std::env::temp_dir().join(format!(
            "heni-glass-{}-{}.sqlite3",
            std::process::id(),
            fastrand::u64(..)
        ));
        let glass = GlassSettings {
            material: GlassMaterial::Clear,
            transparency: 80,
            fog: Some(62),
        };
        {
            let mut repository = SettingsRepository::open(&path).expect("fixture");
            assert_eq!(
                repository.snapshot().expect("legacy default").glass,
                GlassSettings::default()
            );
            repository
                .update(&SettingsUpdateRequest {
                    glass: Some(glass.clone()),
                    ..SettingsUpdateRequest::default()
                })
                .expect("save");
        }
        {
            let mut repository = SettingsRepository::open(&path).expect("reopen");
            assert_eq!(repository.snapshot().expect("restore").glass, glass);
            assert!(repository
                .update(&SettingsUpdateRequest {
                    glass: Some(GlassSettings {
                        material: GlassMaterial::Soft,
                        transparency: 101,
                        fog: None,
                    }),
                    ..SettingsUpdateRequest::default()
                })
                .is_err());
            repository.connection.execute_batch("CREATE TRIGGER reject_glass BEFORE UPDATE ON settings WHEN NEW.key = 'ui.glass' BEGIN SELECT RAISE(ABORT, 'fixture'); END;").expect("failure fixture");
            assert!(repository
                .update(&SettingsUpdateRequest {
                    glass: Some(GlassSettings::default()),
                    theme_id: Some(ThemeId::Rose),
                    ..SettingsUpdateRequest::default()
                })
                .is_err());
            let saved = repository.snapshot().expect("unchanged");
            assert_eq!(saved.glass, glass);
            assert_eq!(saved.theme_id, ThemeId::Studio);
        }
        std::fs::remove_file(path).expect("remove only generated glass fixture");
    }

    #[test]
    fn new_palettes_round_trip_through_the_existing_settings_protocol() {
        let mut repository = repository();
        for name in ["rose", "iris", "ember"] {
            let request: SettingsUpdateRequest =
                serde_json::from_value(serde_json::json!({"themeId": name}))
                    .expect("theme request");
            let updated = repository.update(&request).expect("persist palette");
            assert_eq!(
                serde_json::to_value(updated).expect("snapshot")["themeId"],
                name
            );
            assert_eq!(
                serde_json::to_value(repository.snapshot().expect("restored")).expect("snapshot")
                    ["themeId"],
                name
            );
        }
    }

    #[test]
    fn rotation_defaults_off_survives_reopen_and_failed_disable_preserves_preference() {
        let path = std::env::temp_dir().join(format!(
            "heni-rotation-{}-{}.sqlite3",
            std::process::id(),
            fastrand::u64(..)
        ));
        {
            let mut repository = SettingsRepository::open(&path).expect("fixture");
            assert!(!repository.snapshot().expect("default").scenery_auto_rotate);
            repository
                .update(&SettingsUpdateRequest {
                    scenery_auto_rotate: Some(true),
                    ..SettingsUpdateRequest::default()
                })
                .expect("enable");
        }
        {
            let mut repository = SettingsRepository::open(&path).expect("reopen");
            assert!(repository.snapshot().expect("restored").scenery_auto_rotate);
            repository.connection.execute_batch("CREATE TRIGGER reject_rotation BEFORE UPDATE ON settings WHEN NEW.key = 'ui.sceneryAutoRotate' BEGIN SELECT RAISE(ABORT, 'fixture'); END;").expect("failure fixture");
            assert!(repository
                .update(&SettingsUpdateRequest {
                    scenery_auto_rotate: Some(false),
                    ..SettingsUpdateRequest::default()
                })
                .is_err());
            assert!(
                repository
                    .snapshot()
                    .expect("unchanged")
                    .scenery_auto_rotate
            );
        }
        std::fs::remove_file(path).expect("remove only generated rotation fixture");
    }

    #[test]
    fn intensity_rejects_invalid_updates_and_rolls_back_failed_writes() {
        let mut repository = repository();
        repository
            .update(&SettingsUpdateRequest {
                scenery_intensity: Some(35),
                ..SettingsUpdateRequest::default()
            })
            .expect("initial intensity");
        let error = repository
            .update(&SettingsUpdateRequest {
                scenery_intensity: Some(101),
                theme_id: Some(ThemeId::Tide),
                ..SettingsUpdateRequest::default()
            })
            .expect_err("invalid intensity");
        assert_eq!(error.code, "invalid-contract");
        assert_eq!(
            repository.snapshot().expect("unchanged").scenery_intensity,
            35
        );
        repository
            .connection
            .execute_batch(
                "CREATE TRIGGER reject_intensity BEFORE UPDATE ON settings
             WHEN NEW.key = 'ui.sceneryIntensity'
             BEGIN SELECT RAISE(ABORT, 'test failure'); END;",
            )
            .expect("failure fixture");
        assert!(repository
            .update(&SettingsUpdateRequest {
                scenery_intensity: Some(60),
                theme_id: Some(ThemeId::Tide),
                ..SettingsUpdateRequest::default()
            })
            .is_err());
        let snapshot = repository.snapshot().expect("rolled back");
        assert_eq!(snapshot.scenery_intensity, 35);
        assert_eq!(snapshot.theme_id, ThemeId::Studio);
    }

    #[test]
    fn intensity_survives_database_reopen_including_zero() {
        let path = std::env::temp_dir().join(format!(
            "heni-intensity-{}-{}.sqlite3",
            std::process::id(),
            fastrand::u64(..)
        ));
        for intensity in [0, 35, 100] {
            {
                let mut repository = SettingsRepository::open(&path).expect("open fixture");
                repository
                    .update(&SettingsUpdateRequest {
                        scenery_intensity: Some(intensity),
                        ..SettingsUpdateRequest::default()
                    })
                    .expect("save intensity");
            }
            let repository = SettingsRepository::open(&path).expect("reopen fixture");
            assert_eq!(
                repository.snapshot().expect("restored").scenery_intensity,
                intensity
            );
        }
        std::fs::remove_file(path).expect("remove only generated intensity fixture");
    }

    #[test]
    fn rejects_corrupt_persisted_json_instead_of_silently_overwriting_it() {
        let repository = repository();
        repository
            .connection
            .execute(
                "INSERT INTO settings (key, value_json) VALUES (?1, ?2)",
                params![INCLUDE_VIDEO_KEY, "not-json"],
            )
            .expect("corrupt fixture");
        assert!(repository.snapshot().is_err());
    }

    #[test]
    fn reveal_persists_and_preserves_legacy_intensity() {
        let path = std::env::temp_dir().join(format!(
            "heni-reveal-{}-{}.sqlite3",
            std::process::id(),
            fastrand::u64(..)
        ));
        {
            let mut repository = SettingsRepository::open(&path).expect("open fixture");
            assert_eq!(repository.snapshot().expect("default").scenery_reveal, 0);
            repository
                .update(&SettingsUpdateRequest {
                    scenery_reveal: Some(300),
                    ..SettingsUpdateRequest::default()
                })
                .expect("save");
        }
        {
            let repository = SettingsRepository::open(&path).expect("reopen fixture");
            let snapshot = repository.snapshot().expect("restored");
            assert_eq!(snapshot.scenery_reveal, 300);
            assert_eq!(snapshot.scenery_intensity, 100);
        }
        std::fs::remove_file(path).expect("remove generated reveal fixture");
    }

    #[test]
    fn reveal_rejects_invalid_values_and_rolls_back_failed_writes() {
        let mut repository = repository();
        repository
            .update(&SettingsUpdateRequest {
                scenery_reveal: Some(40),
                ..SettingsUpdateRequest::default()
            })
            .expect("initial");
        assert!(repository
            .update(&SettingsUpdateRequest {
                scenery_reveal: Some(301),
                theme_id: Some(ThemeId::Rose),
                ..SettingsUpdateRequest::default()
            })
            .is_err());
        repository.connection.execute_batch("CREATE TRIGGER reject_reveal BEFORE UPDATE ON settings WHEN NEW.key = 'ui.sceneryReveal' BEGIN SELECT RAISE(ABORT, 'fixture'); END;").expect("failure trigger");
        assert!(repository
            .update(&SettingsUpdateRequest {
                scenery_reveal: Some(100),
                theme_id: Some(ThemeId::Rose),
                ..SettingsUpdateRequest::default()
            })
            .is_err());
        let snapshot = repository.snapshot().expect("unchanged");
        assert_eq!(snapshot.scenery_reveal, 40);
        assert_eq!(snapshot.theme_id, ThemeId::Studio);
    }

    #[test]
    fn reveal_rejects_corrupt_persisted_value() {
        let repository = repository();
        repository
            .connection
            .execute(
                "INSERT INTO settings (key, value_json) VALUES (?1, ?2)",
                params![SCENERY_REVEAL_KEY, "301"],
            )
            .expect("corrupt fixture");

        assert_eq!(
            repository.snapshot().expect_err("corrupt data").code,
            "database"
        );
    }
}
