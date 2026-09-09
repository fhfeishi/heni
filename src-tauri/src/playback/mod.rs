mod contracts;
mod controller;
mod engine;
mod order;
pub(crate) mod preferences;
mod session;
pub(crate) mod video;

use std::{
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc, Mutex,
    },
    thread::{self, JoinHandle},
    time::Duration,
};

pub(crate) use contracts::PlaybackError;
use contracts::{PlaybackCommand, PlaybackSnapshot, PlaybackUpdate, PlaybackVersion};
use controller::PlaybackController;
use engine::HybridEngine;
use tauri::Manager;
use tauri_plugin_fs::FsExt;

pub struct PlaybackRuntime {
    controller: Arc<Mutex<PlaybackController<HybridEngine>>>,
    monitor_shutdown: Arc<AtomicBool>,
    monitor: Option<JoinHandle<()>>,
}

impl PlaybackRuntime {
    pub(crate) fn new(
        preferences: Result<preferences::PlaybackPreferences, PlaybackError>,
        video: video::VideoRuntime,
    ) -> Self {
        let mut controller = PlaybackController::new(HybridEngine::new(video));
        controller.restore_preferences(preferences);
        let controller = Arc::new(Mutex::new(controller));
        let monitor_shutdown = Arc::new(AtomicBool::new(false));
        let monitor_controller = Arc::clone(&controller);
        let monitor_signal = Arc::clone(&monitor_shutdown);
        let monitor = thread::Builder::new()
            .name("heni-playback-monitor".to_owned())
            .spawn(move || {
                while !monitor_signal.load(Ordering::Acquire) {
                    let Ok(mut controller) = monitor_controller.lock() else {
                        break;
                    };
                    let _ = controller.tick();
                    drop(controller);
                    thread::sleep(Duration::from_millis(50));
                }
            })
            .expect("failed to start the Heni playback monitor");

        Self {
            controller,
            monitor_shutdown,
            monitor: Some(monitor),
        }
    }
}

impl Drop for PlaybackRuntime {
    fn drop(&mut self) {
        self.monitor_shutdown.store(true, Ordering::Release);
        if let Some(monitor) = self.monitor.take() {
            let _ = monitor.join();
        }
    }
}

impl PlaybackRuntime {
    fn lock(
        &self,
    ) -> Result<std::sync::MutexGuard<'_, PlaybackController<HybridEngine>>, PlaybackError> {
        self.controller.lock().map_err(|_| {
            PlaybackError::new(
                "internal",
                "The playback session is temporarily unavailable.",
            )
        })
    }
}

#[tauri::command]
pub async fn playback_snapshot(app: tauri::AppHandle) -> Result<PlaybackSnapshot, PlaybackError> {
    playback_work(move || Ok(app.state::<PlaybackRuntime>().lock()?.snapshot())).await
}

#[tauri::command]
pub async fn playback_poll(
    known_version: PlaybackVersion,
    app: tauri::AppHandle,
) -> Result<PlaybackUpdate, PlaybackError> {
    playback_work(move || Ok(app.state::<PlaybackRuntime>().lock()?.update(known_version))).await
}

#[tauri::command]
pub async fn playback_dispatch(
    command: PlaybackCommand,
    app: tauri::AppHandle,
    window: tauri::WebviewWindow,
) -> Result<PlaybackSnapshot, PlaybackError> {
    playback_work(move || {
        dispatch_authorized(
            command,
            &app.state::<PlaybackRuntime>(),
            &app.state::<crate::library::LibraryRuntime>(),
            &app.state::<crate::settings::SettingsRuntime>(),
            &window,
        )
    })
    .await
}

// Lock waits, source loading and SQLite commits must not occupy the window or async executor thread.
async fn playback_work<T: Send + 'static>(
    work: impl FnOnce() -> Result<T, PlaybackError> + Send + 'static,
) -> Result<T, PlaybackError> {
    tauri::async_runtime::spawn_blocking(work)
        .await
        .map_err(|_| PlaybackError::new("internal", "The playback operation could not finish."))?
}

fn dispatch_authorized(
    command: PlaybackCommand,
    runtime: &PlaybackRuntime,
    library: &crate::library::LibraryRuntime,
    settings: &crate::settings::SettingsRuntime,
    window: &tauri::WebviewWindow,
) -> Result<PlaybackSnapshot, PlaybackError> {
    let incoming_items: Option<&[contracts::PlaybackItem]> = match &command {
        PlaybackCommand::ReplaceQueue { queue, .. } => Some(queue),
        PlaybackCommand::Enqueue { items } | PlaybackCommand::PlayNext { items } => Some(items),
        PlaybackCommand::RefreshItem { item } => Some(std::slice::from_ref(item)),
        _ => None,
    };
    if let Some(items) = incoming_items {
        let scope = window.fs_scope();
        for item in items {
            let persisted = library.contains_path(&item.path).map_err(|_| {
                PlaybackError::new(
                    "internal",
                    "The local library authorization could not be checked.",
                )
            })?;
            if !scope.is_allowed(&item.path) && !persisted {
                return Err(PlaybackError::new(
                    "path-not-authorized",
                    "Select or import each local media file through Heni before loading it.",
                ));
            }
        }
    }
    let mut controller = runtime.lock()?;
    if matches!(
        command,
        PlaybackCommand::SetVolume { .. } | PlaybackCommand::SetMuted { .. }
    ) {
        controller.dispatch_with_preferences(command, |preferences| {
            settings.set_playback_preferences(preferences).map_err(|_| {
                PlaybackError::new(
                    "preferences-unavailable",
                    "The audio preferences could not be saved.",
                )
            })
        })
    } else {
        controller.dispatch(command)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn blocking_playback_work_runs_off_the_calling_thread() {
        let caller = thread::current().id();
        let worker = tauri::async_runtime::block_on(playback_work(|| Ok(thread::current().id())))
            .expect("worker result");
        assert_ne!(caller, worker);
    }

    #[test]
    fn playback_worker_preserves_finite_domain_errors() {
        let result = tauri::async_runtime::block_on(playback_work(|| {
            Err::<(), _>(PlaybackError::new("preferences-unavailable", "fixture"))
        }));
        assert_eq!(
            result.expect_err("save failed").code,
            "preferences-unavailable"
        );
    }

    #[test]
    fn playback_worker_failure_does_not_expose_a_panic_payload() {
        let result =
            tauri::async_runtime::block_on(playback_work(|| -> Result<(), PlaybackError> {
                panic!("private fixture diagnostic");
            }));
        let error = result.expect_err("worker panicked");
        assert_eq!(error.code, "internal");
        assert!(!error.message.contains("private fixture"));
    }
}
