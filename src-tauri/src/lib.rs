mod commands;
mod library;
mod media_support;
mod platform;
mod playback;
mod scenery;
mod settings;
mod storage;

use tauri::Manager;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let window_runtime = platform::window::WindowRuntime::default();
    let video_runtime = playback::video::VideoRuntime::default();
    let builder = tauri::Builder::default()
        .manage(video_runtime)
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_dialog::init())
        .manage(scenery::SceneryRuntime::default());
    #[cfg(desktop)]
    let builder = builder.plugin(
        tauri_plugin_window_state::Builder::default()
            .with_state_flags(platform::window::persisted_state_flags())
            .build(),
    );
    let builder = builder.manage(window_runtime);

    builder
        .setup(|app| {
            app.manage(library::LibraryRuntime::open(app.handle())?);
            let settings_runtime = settings::SettingsRuntime::open(app.handle())?;
            let audio_preferences = settings_runtime.playback_preferences().map_err(|_| {
                playback::PlaybackError::new(
                    "preferences-unavailable",
                    "The saved audio preferences could not be restored.",
                )
            });
            app.manage(playback::PlaybackRuntime::new(
                audio_preferences,
                app.state::<playback::video::VideoRuntime>().inner().clone(),
            ));
            app.manage(settings_runtime);
            #[cfg(desktop)]
            if let Some(window) = app.get_webview_window("main") {
                let runtime = app
                    .state::<platform::window::WindowRuntime>()
                    .inner()
                    .clone();
                let window_for_close = window.clone();
                window.on_window_event(move |event| {
                    if matches!(event, tauri::WindowEvent::CloseRequested { .. }) {
                        platform::window::restore_main_before_close(&window_for_close, &runtime);
                    }
                });
            }
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::runtime_info,
            library::library_snapshot,
            library::library_import_files,
            library::library_relocate_media,
            library::library_media_details,
            library::library_legacy_import_status,
            library::library_import_legacy,
            library::playlist_create,
            library::playlist_update,
            library::playlist_delete,
            library::playlist_add_items,
            library::playlist_remove_items,
            library::library_scan_directory,
            library::library_cancel_scan,
            playback::playback_snapshot,
            playback::playback_poll,
            playback::playback_dispatch,
            playback::video::video_exchange,
            platform::file_action::file_action_reveal_media,
            settings::settings_snapshot,
            settings::settings_update,
            scenery::scenery_read,
            scenery::scenery_choose,
            scenery::scenery_clear,
            scenery::scenery_step,
            platform::window::window_snapshot,
            platform::window::window_set_mode
        ])
        .run(tauri::generate_context!())
        .expect("failed to run the Heni Tauri application");
}
