pub(crate) mod migrations;

use std::{fs, path::PathBuf};

use tauri::Manager;

pub(crate) fn app_data_directory(
    app: &tauri::AppHandle,
) -> Result<PathBuf, Box<dyn std::error::Error>> {
    let directory = app.path().app_data_dir()?;
    fs::create_dir_all(&directory)?;
    Ok(directory)
}

pub(crate) fn database_path(directory: &std::path::Path) -> PathBuf {
    directory.join("heni.sqlite3")
}
