mod contracts;
mod legacy_import;
mod metadata;
mod playlist_repository;
mod repository;
mod scanner;

use std::{
    collections::HashMap,
    path::PathBuf,
    sync::{
        atomic::{AtomicBool, AtomicU64, Ordering},
        Arc, Mutex,
    },
};

pub(crate) use contracts::LibraryError;
use contracts::{
    LegacyImportOutcome, LegacyImportStatus, LibraryImportItem, LibraryRelocateRequest,
    LibraryScanEvent, LibraryScanRequest, LibrarySnapshot, MediaDetails, MediaDetailsRequest,
    PlaylistCreateRequest, PlaylistIdRequest, PlaylistItemsRequest, PlaylistUpdateRequest,
};
use metadata::{index_import_item, FfprobeMediaInspector};
use repository::LibraryRepository;
use scanner::{scan_directory, ScanOptions};
use tauri::ipc::Channel;
use tauri::{Manager, State};
use tauri_plugin_fs::FsExt;

pub(crate) struct LibraryRuntime {
    repository: Mutex<LibraryRepository>,
    legacy_source_path: Option<PathBuf>,
    legacy_backup_directory: PathBuf,
    scan_counter: AtomicU64,
    scans: Mutex<HashMap<String, Arc<AtomicBool>>>,
    detail_probe: FfprobeMediaInspector,
}

impl LibraryRuntime {
    pub(crate) fn open(app: &tauri::AppHandle) -> Result<Self, Box<dyn std::error::Error>> {
        let directory = crate::storage::app_data_directory(app)?;
        let repository = LibraryRepository::open(&crate::storage::database_path(&directory))
            .map_err(|error| std::io::Error::other(error.message))?;
        let bundled_ffprobe = app.path().resource_dir()?.join("bin").join("ffprobe.exe");
        let ffprobe_executable = if bundled_ffprobe.is_file() {
            bundled_ffprobe
        } else {
            PathBuf::from("ffprobe")
        };
        Ok(Self {
            repository: Mutex::new(repository),
            legacy_source_path: legacy_import::default_source_path(),
            legacy_backup_directory: directory.join("migration-backups"),
            scan_counter: AtomicU64::new(0),
            scans: Mutex::new(HashMap::new()),
            detail_probe: FfprobeMediaInspector::new(ffprobe_executable),
        })
    }

    fn lock(&self) -> Result<std::sync::MutexGuard<'_, LibraryRepository>, LibraryError> {
        self.repository.lock().map_err(|_| {
            LibraryError::new(
                "database",
                "The local Heni library database is temporarily unavailable.",
            )
        })
    }

    pub(crate) fn contains_path(&self, path: &str) -> Result<bool, LibraryError> {
        self.lock()?.contains_path(path)
    }

    pub(crate) fn available_media_path(&self, media_id: &str) -> Result<String, LibraryError> {
        self.lock()
            .and_then(|repository| repository.media_probe_target(media_id))
            .map(|target| target.path)
    }

    fn register_scan(&self) -> Result<(String, Arc<AtomicBool>), LibraryError> {
        let number = self.scan_counter.fetch_add(1, Ordering::Relaxed) + 1;
        let scan_id = format!("scan-{number}");
        let cancelled = Arc::new(AtomicBool::new(false));
        self.scans
            .lock()
            .map_err(|_| LibraryError::new("internal", "The scan registry is unavailable."))?
            .insert(scan_id.clone(), Arc::clone(&cancelled));
        Ok((scan_id, cancelled))
    }

    fn finish_scan(&self, scan_id: &str) {
        if let Ok(mut scans) = self.scans.lock() {
            scans.remove(scan_id);
        }
    }

    fn cancel_scan(&self, scan_id: &str) -> Result<bool, LibraryError> {
        let scans = self
            .scans
            .lock()
            .map_err(|_| LibraryError::new("internal", "The scan registry is unavailable."))?;
        let Some(cancelled) = scans.get(scan_id) else {
            return Ok(false);
        };
        cancelled.store(true, Ordering::Release);
        Ok(true)
    }
}

fn new_playlist_id() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};

    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |duration| duration.as_micros());
    format!("playlist-{timestamp:x}-{:016x}", fastrand::u64(..))
}

#[tauri::command]
pub(crate) async fn library_snapshot(
    app: tauri::AppHandle,
) -> Result<LibrarySnapshot, LibraryError> {
    library_work(move || app.state::<LibraryRuntime>().lock()?.snapshot()).await
}

#[tauri::command]
pub(crate) async fn library_import_files(
    items: Vec<LibraryImportItem>,
    app: tauri::AppHandle,
    window: tauri::WebviewWindow,
) -> Result<LibrarySnapshot, LibraryError> {
    library_work(move || {
        let scope = window.fs_scope();
        if items.iter().any(|item| !scope.is_allowed(&item.path)) {
            return Err(LibraryError::new(
                "path-not-authorized",
                "Select each local media file through Heni before importing it.",
            ));
        }
        let indexed = items.into_iter().map(index_import_item).collect::<Vec<_>>();
        app.state::<LibraryRuntime>()
            .lock()?
            .import_indexed_files(&indexed)
    })
    .await
}

#[tauri::command]
pub(crate) async fn library_relocate_media(
    request: LibraryRelocateRequest,
    app: tauri::AppHandle,
    window: tauri::WebviewWindow,
) -> Result<LibrarySnapshot, LibraryError> {
    library_work(move || {
        let runtime = app.state::<LibraryRuntime>();
        let replacement_path = PathBuf::from(&request.new_path);
        if !window.fs_scope().is_allowed(&replacement_path) {
            return Err(LibraryError::new(
                "path-not-authorized",
                "Select the replacement media file through Heni before relocating it.",
            ));
        }
        if !replacement_path.is_file() {
            return Err(LibraryError::new(
                "file-unavailable",
                "The selected replacement media file is no longer available.",
            ));
        }
        let expected_kind = runtime
            .lock()?
            .media_relocation_target(&request.media_id)?
            .kind;
        let Some(kind) = scanner::media_kind(&replacement_path, true) else {
            return Err(LibraryError::new(
                "unsupported-media-kind",
                "The selected replacement does not use a supported media extension.",
            ));
        };
        if kind != expected_kind {
            return Err(LibraryError::new(
                "unsupported-media-kind",
                "The replacement file must have the same media kind as the original item.",
            ));
        }
        let title = replacement_path
            .file_name()
            .map(|value| value.to_string_lossy().into_owned())
            .filter(|value| !value.trim().is_empty())
            .ok_or_else(|| {
                LibraryError::new(
                    "invalid-contract",
                    "The replacement media file must have a readable file name.",
                )
            })?;
        let replacement = index_import_item(LibraryImportItem {
            path: request.new_path,
            title,
            kind,
            duration_ms: None,
        });
        if !replacement_path.is_file() {
            return Err(LibraryError::new(
                "file-unavailable",
                "The selected replacement media file is no longer available.",
            ));
        }
        let snapshot = runtime
            .lock()?
            .relocate_media(&request.media_id, &replacement)?;
        Ok(snapshot)
    })
    .await
}

#[tauri::command]
pub(crate) async fn library_media_details(
    request: MediaDetailsRequest,
    app: tauri::AppHandle,
) -> Result<MediaDetails, LibraryError> {
    library_work(move || {
        let runtime = app.state::<LibraryRuntime>();
        let target = runtime.lock()?.media_probe_target(&request.media_id)?;
        if !PathBuf::from(&target.path).is_file() {
            return Err(LibraryError::new(
                "file-unavailable",
                "The requested media file is no longer available.",
            ));
        }
        runtime.detail_probe.inspect(target.media_id, target.path)
    })
    .await
}

#[tauri::command]
pub(crate) async fn library_legacy_import_status(
    app: tauri::AppHandle,
) -> Result<LegacyImportStatus, LibraryError> {
    library_work(move || {
        let runtime = app.state::<LibraryRuntime>();
        let repository = runtime.lock()?;
        legacy_import::status(&repository, runtime.legacy_source_path.as_deref())
    })
    .await
}

async fn library_work<T: Send + 'static>(
    work: impl FnOnce() -> Result<T, LibraryError> + Send + 'static,
) -> Result<T, LibraryError> {
    tauri::async_runtime::spawn_blocking(work)
        .await
        .map_err(|_| LibraryError::new("internal", "The library operation could not finish."))?
}

#[tauri::command]
pub(crate) async fn library_import_legacy(
    app: tauri::AppHandle,
) -> Result<LegacyImportOutcome, LibraryError> {
    library_work(move || {
        let runtime = app.state::<LibraryRuntime>();
        let mut repository = runtime.lock()?;
        legacy_import::import(
            &mut repository,
            runtime.legacy_source_path.as_deref(),
            &runtime.legacy_backup_directory,
        )
    })
    .await
}

#[tauri::command]
pub(crate) async fn playlist_create(
    request: PlaylistCreateRequest,
    app: tauri::AppHandle,
) -> Result<LibrarySnapshot, LibraryError> {
    library_work(move || {
        app.state::<LibraryRuntime>()
            .lock()?
            .create_playlist(&new_playlist_id(), &request)
    })
    .await
}

#[tauri::command]
pub(crate) async fn playlist_update(
    request: PlaylistUpdateRequest,
    app: tauri::AppHandle,
) -> Result<LibrarySnapshot, LibraryError> {
    library_work(move || {
        app.state::<LibraryRuntime>()
            .lock()?
            .update_playlist(&request)
    })
    .await
}

#[tauri::command]
pub(crate) async fn playlist_delete(
    request: PlaylistIdRequest,
    app: tauri::AppHandle,
) -> Result<LibrarySnapshot, LibraryError> {
    library_work(move || {
        app.state::<LibraryRuntime>()
            .lock()?
            .delete_playlist(&request.playlist_id)
    })
    .await
}

#[tauri::command]
pub(crate) async fn playlist_add_items(
    request: PlaylistItemsRequest,
    app: tauri::AppHandle,
) -> Result<LibrarySnapshot, LibraryError> {
    library_work(move || {
        app.state::<LibraryRuntime>()
            .lock()?
            .add_playlist_items(&request)
    })
    .await
}

#[tauri::command]
pub(crate) async fn playlist_remove_items(
    request: PlaylistItemsRequest,
    app: tauri::AppHandle,
) -> Result<LibrarySnapshot, LibraryError> {
    library_work(move || {
        app.state::<LibraryRuntime>()
            .lock()?
            .remove_playlist_items(&request)
    })
    .await
}

#[tauri::command]
pub(crate) async fn library_scan_directory(
    request: LibraryScanRequest,
    on_event: Channel<LibraryScanEvent>,
    app: tauri::AppHandle,
    window: tauri::WebviewWindow,
) -> Result<LibrarySnapshot, LibraryError> {
    library_work(move || {
        let runtime = app.state::<LibraryRuntime>();
        let root = PathBuf::from(&request.root);
        if !window.fs_scope().is_allowed(&root) {
            return Err(LibraryError::new(
                "path-not-authorized",
                "Select the local directory through Heni before scanning it.",
            ));
        }

        let root_id = runtime.lock()?.register_root(
            &request.root,
            request.recursive,
            request.include_video,
        )?;
        let (scan_id, cancelled) = runtime.register_scan()?;
        if on_event
            .send(LibraryScanEvent::Started {
                scan_id: scan_id.clone(),
            })
            .is_err()
        {
            cancelled.store(true, Ordering::Release);
        }

        let result = scan_directory(
            &ScanOptions {
                root,
                recursive: request.recursive,
                include_video: request.include_video,
            },
            &cancelled,
            |progress| {
                on_event
                    .send(LibraryScanEvent::Progress {
                        scan_id: scan_id.clone(),
                        visited: progress.visited,
                        matched: progress.matched,
                        unreadable: progress.unreadable,
                    })
                    .is_ok()
            },
            |items| {
                runtime
                    .lock()?
                    .import_scanned_files(root_id, &scan_id, items)
            },
        );
        runtime.finish_scan(&scan_id);
        let summary = result?;
        if !summary.cancelled {
            runtime.lock()?.complete_root_scan(root_id, &scan_id)?;
        }
        let final_event = if summary.cancelled {
            LibraryScanEvent::Cancelled {
                scan_id,
                visited: summary.progress.visited,
                matched: summary.progress.matched,
                unreadable: summary.progress.unreadable,
            }
        } else {
            LibraryScanEvent::Completed {
                scan_id,
                visited: summary.progress.visited,
                matched: summary.progress.matched,
                unreadable: summary.progress.unreadable,
            }
        };
        let _ = on_event.send(final_event);
        let snapshot = runtime.lock()?.snapshot()?;
        Ok(snapshot)
    })
    .await
}

#[tauri::command]
pub(crate) fn library_cancel_scan(
    scan_id: String,
    runtime: State<'_, LibraryRuntime>,
) -> Result<bool, LibraryError> {
    runtime.cancel_scan(&scan_id)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn blocking_library_work_runs_off_the_calling_thread() {
        let caller = std::thread::current().id();
        let worker =
            tauri::async_runtime::block_on(library_work(|| Ok(std::thread::current().id())))
                .expect("worker result");
        assert_ne!(caller, worker);
    }

    #[test]
    fn library_worker_preserves_authorization_errors() {
        let result = tauri::async_runtime::block_on(library_work(|| {
            Err::<(), _>(LibraryError::new("path-not-authorized", "fixture"))
        }));
        assert_eq!(
            result.expect_err("unauthorized").code,
            "path-not-authorized"
        );
    }

    #[test]
    fn library_worker_failure_does_not_expose_a_panic_payload() {
        let result =
            tauri::async_runtime::block_on(library_work(|| -> Result<(), LibraryError> {
                panic!("private fixture diagnostic");
            }));
        let error = result.expect_err("worker panicked");
        assert_eq!(error.code, "internal");
        assert!(!error.message.contains("private fixture"));
    }
}
