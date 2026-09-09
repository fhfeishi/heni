use std::{
    collections::{BTreeMap, BTreeSet},
    env, fs,
    io::Write,
    path::{Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};

use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use super::{
    contracts::{LegacyImportOutcome, LegacyImportStatus, LibraryError, LibraryImportItem},
    repository::{normalized_path_key, LibraryRepository},
    scanner::media_kind,
};

const LEGACY_SCHEMA_VERSION: u32 = 1;
const MAX_LEGACY_JSON_BYTES: u64 = 32 * 1024 * 1024;
pub(super) const LEGACY_IMPORT_KIND: &str = "flutter-v1-json";

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct LegacyLibrary {
    schema_version: u32,
    #[serde(default)]
    library_directories: Vec<String>,
    #[serde(default)]
    library_files: Vec<String>,
    #[serde(default)]
    media_durations: BTreeMap<String, u64>,
    #[serde(default)]
    playlists: Vec<LegacyPlaylist>,
    active_playlist_id: Option<String>,
    #[serde(default)]
    scenery_image_paths: Vec<String>,
    #[serde(default = "default_opacity")]
    scenery_image_opacity: f64,
    active_palette_name: Option<String>,
    active_ui_style: Option<String>,
    #[serde(rename = "sidebarMode")]
    sidebar_mode_name: Option<String>,
    playback_mode_name: Option<String>,
    repeat_mode_name: Option<String>,
    shuffle_enabled: Option<bool>,
    volume_level: Option<f64>,
    last_audible_volume: Option<f64>,
    #[serde(default = "default_true")]
    recursive_scan: bool,
    #[serde(default = "default_true")]
    include_video: bool,
    #[serde(default = "default_true")]
    autoplay_on_load: bool,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct LegacyPlaylist {
    id: String,
    name: String,
    #[serde(default)]
    description: String,
    #[serde(default)]
    item_paths: Vec<String>,
}

#[derive(Clone, Debug)]
pub(super) struct LegacyRootPlan {
    pub(super) path: String,
    pub(super) normalized_path: String,
    pub(super) recursive: bool,
    pub(super) include_video: bool,
}

#[derive(Clone, Debug)]
pub(super) struct LegacyMediaPlan {
    pub(super) item: LibraryImportItem,
    pub(super) available: bool,
    pub(super) manual: bool,
    pub(super) root_keys: Vec<String>,
}

#[derive(Clone, Debug)]
pub(super) struct LegacyPlaylistPlan {
    pub(super) id: String,
    pub(super) name: String,
    pub(super) description: String,
    pub(super) media_ids: Vec<String>,
}

#[derive(Clone, Debug)]
pub(super) struct LegacyImportPlan {
    pub(super) roots: Vec<LegacyRootPlan>,
    pub(super) media: Vec<LegacyMediaPlan>,
    pub(super) playlists: Vec<LegacyPlaylistPlan>,
    pub(super) settings: Vec<(String, String)>,
}

impl LegacyImportPlan {
    fn media_count(&self) -> Result<u64, LibraryError> {
        u64::try_from(self.media.len()).map_err(|_| invalid_legacy())
    }

    fn playlist_count(&self) -> Result<u64, LibraryError> {
        u64::try_from(self.playlists.len()).map_err(|_| invalid_legacy())
    }
}

pub(super) fn status(
    repository: &LibraryRepository,
    source: Option<&Path>,
) -> Result<LegacyImportStatus, LibraryError> {
    if repository.has_completed_legacy_import()? {
        return Ok(LegacyImportStatus::Imported);
    }
    let Some(source) = source else {
        return Ok(LegacyImportStatus::NotFound);
    };
    if !source.is_file() {
        return Ok(LegacyImportStatus::NotFound);
    }

    let bytes = read_source(source)?;
    let plan = prepare_plan(&bytes)?;
    Ok(LegacyImportStatus::Ready {
        media_count: plan.media_count()?,
        playlist_count: plan.playlist_count()?,
    })
}

pub(super) fn import(
    repository: &mut LibraryRepository,
    source: Option<&Path>,
    backup_directory: &Path,
) -> Result<LegacyImportOutcome, LibraryError> {
    if repository.has_completed_legacy_import()? {
        return Ok(LegacyImportOutcome {
            snapshot: repository.snapshot()?,
            imported_media: 0,
            imported_playlists: 0,
            backup_path: None,
            already_imported: true,
        });
    }
    let source = source.ok_or_else(source_unavailable)?;
    let bytes = read_source(source)?;
    let plan = prepare_plan(&bytes)?;
    let fingerprint = sha256(&bytes);
    let backup_path = create_readonly_backup(&bytes, backup_directory)?;
    let source_path = source.to_string_lossy().into_owned();
    let backup_display_path = backup_path.to_string_lossy().into_owned();

    repository.import_legacy(&plan, &source_path, &backup_display_path, &fingerprint)?;

    Ok(LegacyImportOutcome {
        snapshot: repository.snapshot()?,
        imported_media: plan.media_count()?,
        imported_playlists: plan.playlist_count()?,
        backup_path: Some(backup_display_path),
        already_imported: false,
    })
}

pub(super) fn default_source_path() -> Option<PathBuf> {
    let base = if cfg!(target_os = "windows") {
        env::var_os("APPDATA").map(PathBuf::from).or_else(|| {
            env::var_os("USERPROFILE")
                .map(PathBuf::from)
                .map(|home| home.join("AppData").join("Roaming"))
        })
    } else if cfg!(target_os = "macos") {
        env::var_os("HOME")
            .map(PathBuf::from)
            .map(|home| home.join("Library").join("Application Support"))
    } else {
        env::var_os("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .or_else(|| {
                env::var_os("HOME")
                    .map(PathBuf::from)
                    .map(|home| home.join(".config"))
            })
    }?;
    Some(base.join("Heni").join("library.json"))
}

fn read_source(source: &Path) -> Result<Vec<u8>, LibraryError> {
    let metadata = fs::metadata(source).map_err(|_| source_unavailable())?;
    if !metadata.is_file() || metadata.len() > MAX_LEGACY_JSON_BYTES {
        return Err(LibraryError::new(
            "invalid-contract",
            "The Flutter v1 library file is missing or exceeds the safe import limit.",
        ));
    }
    fs::read(source).map_err(|_| source_unavailable())
}

fn prepare_plan(bytes: &[u8]) -> Result<LegacyImportPlan, LibraryError> {
    let legacy: LegacyLibrary = serde_json::from_slice(bytes).map_err(|_| invalid_legacy())?;
    validate_scalar_preferences(&legacy)?;
    if legacy.schema_version != LEGACY_SCHEMA_VERSION {
        return Err(LibraryError::new(
            "unsupported-schema",
            "Only Flutter library schemaVersion 1 can be imported.",
        ));
    }

    let roots = prepare_roots(&legacy)?;
    let durations = prepare_durations(&legacy.media_durations)?;
    let manual_paths = prepare_manual_paths(&legacy.library_files)?;
    let mut media_paths = BTreeMap::<String, String>::new();
    for path in &legacy.library_files {
        insert_media_path(&mut media_paths, path)?;
    }
    for (key, (path, _)) in &durations {
        media_paths
            .entry(key.clone())
            .or_insert_with(|| path.clone());
    }

    let mut playlist_ids = BTreeSet::new();
    for playlist in &legacy.playlists {
        validate_non_empty(&playlist.id)?;
        validate_non_empty(&playlist.name)?;
        if !playlist_ids.insert(playlist.id.clone()) {
            return Err(invalid_legacy());
        }
        for path in &playlist.item_paths {
            insert_media_path(&mut media_paths, path)?;
        }
    }

    let media = media_paths
        .iter()
        .map(|(key, path)| {
            let kind = media_kind(Path::new(path), true).ok_or_else(invalid_legacy)?;
            let duration_ms = durations.get(key).map(|(_, value)| *value);
            let root_keys = roots
                .iter()
                .filter(|root| root_contains(&root.normalized_path, key))
                .map(|root| root.normalized_path.clone())
                .collect();
            Ok(LegacyMediaPlan {
                item: LibraryImportItem {
                    path: path.clone(),
                    title: title_from_path(path)?,
                    kind,
                    duration_ms,
                },
                available: Path::new(path).is_file(),
                manual: manual_paths.contains(key),
                root_keys,
            })
        })
        .collect::<Result<Vec<_>, LibraryError>>()?;

    let settings = prepare_settings(&legacy)?;
    let playlists = legacy
        .playlists
        .into_iter()
        .map(|playlist| {
            let mut seen = BTreeSet::new();
            let media_ids = playlist
                .item_paths
                .iter()
                .map(|path| normalized_path_key(path))
                .filter(|id| seen.insert(id.clone()))
                .collect();
            LegacyPlaylistPlan {
                id: playlist.id,
                name: playlist.name,
                description: playlist.description,
                media_ids,
            }
        })
        .collect();
    Ok(LegacyImportPlan {
        roots,
        media,
        playlists,
        settings,
    })
}

fn prepare_roots(legacy: &LegacyLibrary) -> Result<Vec<LegacyRootPlan>, LibraryError> {
    let mut roots = BTreeMap::new();
    for path in &legacy.library_directories {
        validate_non_empty(path)?;
        let key = normalized_path_key(path).trim_end_matches('\\').to_owned();
        if key.is_empty() {
            return Err(invalid_legacy());
        }
        roots.entry(key.clone()).or_insert_with(|| LegacyRootPlan {
            path: path.clone(),
            normalized_path: key,
            recursive: legacy.recursive_scan,
            include_video: legacy.include_video,
        });
    }
    Ok(roots.into_values().collect())
}

fn prepare_durations(
    values: &BTreeMap<String, u64>,
) -> Result<BTreeMap<String, (String, u64)>, LibraryError> {
    let mut durations = BTreeMap::new();
    for (path, duration) in values {
        validate_non_empty(path)?;
        if *duration == 0 || media_kind(Path::new(path), true).is_none() {
            return Err(invalid_legacy());
        }
        let key = normalized_path_key(path);
        if let Some((_, existing)) = durations.get(&key) {
            if existing != duration {
                return Err(invalid_legacy());
            }
        } else {
            durations.insert(key, (path.clone(), *duration));
        }
    }
    Ok(durations)
}

fn prepare_manual_paths(paths: &[String]) -> Result<BTreeSet<String>, LibraryError> {
    paths
        .iter()
        .map(|path| {
            validate_non_empty(path)?;
            if media_kind(Path::new(path), true).is_none() {
                return Err(invalid_legacy());
            }
            Ok(normalized_path_key(path))
        })
        .collect()
}

fn insert_media_path(
    values: &mut BTreeMap<String, String>,
    path: &str,
) -> Result<(), LibraryError> {
    validate_non_empty(path)?;
    if media_kind(Path::new(path), true).is_none() {
        return Err(invalid_legacy());
    }
    values
        .entry(normalized_path_key(path))
        .or_insert_with(|| path.to_owned());
    Ok(())
}

fn prepare_settings(legacy: &LegacyLibrary) -> Result<Vec<(String, String)>, LibraryError> {
    let (repeat_mode, shuffle) = resolved_playback_preferences(legacy);
    let mut settings = vec![
        json_setting("library.recursiveScan", &legacy.recursive_scan)?,
        json_setting("library.includeVideo", &legacy.include_video)?,
        json_setting("library.autoplayOnLoad", &legacy.autoplay_on_load)?,
        json_setting("playback.repeatMode", repeat_mode)?,
        json_setting("playback.shuffle", &shuffle)?,
        json_setting("scenery.imagePaths", &legacy.scenery_image_paths)?,
        json_setting("scenery.opacity", &legacy.scenery_image_opacity)?,
    ];
    for (key, value) in [
        ("library.activePlaylistId", &legacy.active_playlist_id),
        ("ui.palette", &legacy.active_palette_name),
        ("ui.style", &legacy.active_ui_style),
        ("ui.sidebarMode", &legacy.sidebar_mode_name),
    ] {
        if let Some(value) = value {
            settings.push(json_setting(key, value)?);
        }
    }
    if let Some(value) = legacy.volume_level {
        settings.push(json_setting("playback.volume", &value)?);
    }
    if let Some(value) = legacy.last_audible_volume {
        settings.push(json_setting("playback.lastAudibleVolume", &value)?);
    }
    Ok(settings)
}

fn resolved_playback_preferences(legacy: &LegacyLibrary) -> (&'static str, bool) {
    if legacy.shuffle_enabled == Some(true) {
        return ("all", true);
    }
    if let Some(repeat) = legacy.repeat_mode_name.as_deref() {
        return (if repeat == "one" { "one" } else { "all" }, false);
    }
    match legacy.playback_mode_name.as_deref() {
        Some("random") => ("all", true),
        Some("singleLoop") => ("one", false),
        _ => ("all", false),
    }
}

fn validate_scalar_preferences(legacy: &LegacyLibrary) -> Result<(), LibraryError> {
    if !(0.0..=1.0).contains(&legacy.scenery_image_opacity) {
        return Err(invalid_legacy());
    }
    if legacy
        .volume_level
        .is_some_and(|volume| !(0.0..=100.0).contains(&volume))
        || legacy
            .last_audible_volume
            .is_some_and(|volume| !(0.0..=100.0).contains(&volume) || volume == 0.0)
    {
        return Err(invalid_legacy());
    }
    for value in [
        legacy.active_playlist_id.as_deref(),
        legacy.active_palette_name.as_deref(),
        legacy.active_ui_style.as_deref(),
        legacy.sidebar_mode_name.as_deref(),
        legacy.playback_mode_name.as_deref(),
        legacy.repeat_mode_name.as_deref(),
    ]
    .into_iter()
    .flatten()
    {
        validate_non_empty(value)?;
    }
    for path in &legacy.scenery_image_paths {
        validate_non_empty(path)?;
    }
    Ok(())
}

fn json_setting<T: Serialize + ?Sized>(
    key: &str,
    value: &T,
) -> Result<(String, String), LibraryError> {
    serde_json::to_string(value)
        .map(|json| (key.to_owned(), json))
        .map_err(|_| invalid_legacy())
}

fn root_contains(root: &str, path: &str) -> bool {
    path.strip_prefix(root)
        .is_some_and(|remainder| remainder.starts_with('\\'))
}

fn title_from_path(path: &str) -> Result<String, LibraryError> {
    let filename = path
        .replace('\\', "/")
        .rsplit('/')
        .next()
        .unwrap_or_default()
        .to_owned();
    let title = filename
        .rsplit_once('.')
        .map(|(stem, _)| stem)
        .filter(|stem| !stem.is_empty())
        .unwrap_or(&filename)
        .trim();
    validate_non_empty(title)?;
    Ok(title.to_owned())
}

fn validate_non_empty(value: &str) -> Result<(), LibraryError> {
    if value.trim().is_empty() {
        Err(invalid_legacy())
    } else {
        Ok(())
    }
}

fn create_readonly_backup(bytes: &[u8], directory: &Path) -> Result<PathBuf, LibraryError> {
    fs::create_dir_all(directory).map_err(|_| backup_failed())?;
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|_| backup_failed())?
        .as_millis();

    for suffix in 0..100_u16 {
        let filename = if suffix == 0 {
            format!("flutter-v1-library-{timestamp}.json")
        } else {
            format!("flutter-v1-library-{timestamp}-{suffix}.json")
        };
        let path = directory.join(filename);
        let mut file = match fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&path)
        {
            Ok(file) => file,
            Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => continue,
            Err(_) => return Err(backup_failed()),
        };
        file.write_all(bytes).map_err(|_| backup_failed())?;
        file.sync_all().map_err(|_| backup_failed())?;
        let mut permissions = file.metadata().map_err(|_| backup_failed())?.permissions();
        permissions.set_readonly(true);
        fs::set_permissions(&path, permissions).map_err(|_| backup_failed())?;
        return Ok(path);
    }
    Err(backup_failed())
}

fn sha256(bytes: &[u8]) -> String {
    Sha256::digest(bytes)
        .iter()
        .map(|byte| format!("{byte:02x}"))
        .collect()
}

fn default_true() -> bool {
    true
}

fn default_opacity() -> f64 {
    1.0
}

fn invalid_legacy() -> LibraryError {
    LibraryError::new(
        "invalid-contract",
        "The Flutter v1 library file does not match the supported schema.",
    )
}

fn source_unavailable() -> LibraryError {
    LibraryError::new(
        "file-unavailable",
        "The Flutter v1 library file is no longer available.",
    )
}

fn backup_failed() -> LibraryError {
    LibraryError::new(
        "backup-failed",
        "Heni could not create a protected backup, so no legacy data was imported.",
    )
}

#[cfg(test)]
mod tests {
    use std::sync::atomic::{AtomicU64, Ordering};

    use rusqlite::Connection;
    use serde_json::json;

    use super::*;

    static TEST_COUNTER: AtomicU64 = AtomicU64::new(0);

    #[test]
    fn rejects_unknown_fields_and_unsupported_schema_versions() {
        let unknown = serde_json::to_vec(&json!({
            "schemaVersion": 1,
            "unexpected": true
        }))
        .expect("unknown fixture");
        let future = serde_json::to_vec(&json!({ "schemaVersion": 2 })).expect("future fixture");

        assert_eq!(
            prepare_plan(&unknown).expect_err("unknown field").code,
            "invalid-contract"
        );
        assert_eq!(
            prepare_plan(&future).expect_err("future schema").code,
            "unsupported-schema"
        );
    }

    #[test]
    fn creates_an_exact_readonly_backup_and_imports_missing_playlist_references() {
        let root = test_directory("success");
        let media_directory = root.join("音乐");
        fs::create_dir_all(&media_directory).expect("media directory");
        let present = media_directory.join("存在.flac");
        fs::write(&present, b"fixture").expect("media fixture");
        let missing = media_directory.join("missing.mp3");
        let source = root.join("library.json");
        let backup_directory = root.join("backups");
        let source_bytes = serde_json::to_vec_pretty(&json!({
            "schemaVersion": 1,
            "libraryDirectories": [media_directory],
            "libraryFiles": [present],
            "mediaDurations": {
                present.to_string_lossy().into_owned(): 1234
            },
            "playlists": [{
                "id": "night-run",
                "name": "夜跑",
                "description": "测试歌单",
                "itemPaths": [present, missing]
            }],
            "repeatModeName": "one",
            "shuffleEnabled": false
        }))
        .expect("legacy fixture");
        fs::write(&source, &source_bytes).expect("legacy source");
        let mut repository = repository();

        let outcome = import(&mut repository, Some(&source), &backup_directory).expect("import");

        assert!(!outcome.already_imported);
        assert_eq!(outcome.imported_media, 2);
        assert_eq!(outcome.imported_playlists, 1);
        assert_eq!(fs::read(&source).expect("source unchanged"), source_bytes);
        let backup_path = PathBuf::from(outcome.backup_path.expect("backup path"));
        assert_eq!(fs::read(&backup_path).expect("backup bytes"), source_bytes);
        assert!(fs::metadata(&backup_path)
            .expect("backup metadata")
            .permissions()
            .readonly());
        assert_eq!(outcome.snapshot.items.len(), 2);
        assert_eq!(
            outcome
                .snapshot
                .items
                .iter()
                .filter(|item| item.available)
                .count(),
            1
        );
        assert_eq!(table_count(&repository, "playlists"), 1);
        assert_eq!(table_count(&repository, "playlist_items"), 2);
        assert_eq!(table_count(&repository, "settings"), 7);
        assert!(repository
            .has_completed_legacy_import()
            .expect("completed history"));

        let repeated =
            import(&mut repository, Some(&source), &backup_directory).expect("idempotent retry");
        assert!(repeated.already_imported);
        assert_eq!(repeated.imported_media, 0);
        assert_eq!(fs::read_dir(&backup_directory).expect("backups").count(), 1);
        cleanup(root, Some(backup_path));
    }

    #[test]
    fn rolls_back_every_database_write_when_a_playlist_reference_is_invalid() {
        let bytes = serde_json::to_vec(&json!({
            "schemaVersion": 1,
            "libraryFiles": ["C:\\Music\\one.flac"],
            "playlists": [{
                "id": "broken",
                "name": "Broken",
                "itemPaths": ["C:\\Music\\one.flac"]
            }]
        }))
        .expect("legacy fixture");
        let mut plan = prepare_plan(&bytes).expect("valid plan");
        plan.playlists[0]
            .media_ids
            .push("c:\\music\\not-imported.flac".to_owned());
        let mut repository = repository();

        let error = repository
            .import_legacy(&plan, "source.json", "backup.json", "fingerprint")
            .expect_err("foreign key should fail");

        assert_eq!(error.code, "database");
        assert!(repository.snapshot().expect("snapshot").items.is_empty());
        assert_eq!(table_count(&repository, "library_roots"), 0);
        assert_eq!(table_count(&repository, "settings"), 0);
        assert_eq!(table_count(&repository, "import_history"), 0);
    }

    fn repository() -> LibraryRepository {
        LibraryRepository::from_connection(
            Connection::open_in_memory().expect("in-memory connection"),
        )
        .expect("repository")
    }

    fn table_count(repository: &LibraryRepository, table: &str) -> i64 {
        repository
            .connection
            .query_row(&format!("SELECT COUNT(*) FROM {table}"), [], |row| {
                row.get(0)
            })
            .expect("table count")
    }

    fn test_directory(label: &str) -> PathBuf {
        let unique = TEST_COUNTER.fetch_add(1, Ordering::Relaxed);
        let path = env::temp_dir().join(format!(
            "heni-legacy-import-{label}-{}-{unique}",
            std::process::id()
        ));
        fs::create_dir_all(&path).expect("test directory");
        path
    }

    #[allow(clippy::permissions_set_readonly_false)]
    fn cleanup(root: PathBuf, readonly_file: Option<PathBuf>) {
        if let Some(path) = readonly_file {
            if let Ok(metadata) = fs::metadata(&path) {
                #[cfg(windows)]
                {
                    let mut permissions = metadata.permissions();
                    permissions.set_readonly(false);
                    let _ = fs::set_permissions(&path, permissions);
                }
                #[cfg(unix)]
                {
                    use std::os::unix::fs::PermissionsExt;

                    let mut permissions = metadata.permissions();
                    permissions.set_mode(permissions.mode() | 0o200);
                    let _ = fs::set_permissions(&path, permissions);
                }
            }
        }
        let _ = fs::remove_dir_all(root);
    }
}
