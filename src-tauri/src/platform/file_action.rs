use std::path::Path;

use serde::{Deserialize, Serialize};
use tauri::State;

use crate::library::{LibraryError, LibraryRuntime};

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct RevealMediaRequest {
    media_id: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub(crate) struct FileActionError {
    code: String,
    message: String,
}

impl FileActionError {
    fn new(code: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            code: code.into(),
            message: message.into(),
        }
    }

    fn unavailable() -> Self {
        Self::new(
            "file-manager-unavailable",
            "Windows File Explorer could not reveal the selected media file.",
        )
    }
}

impl From<LibraryError> for FileActionError {
    fn from(error: LibraryError) -> Self {
        match error.code.as_str() {
            "invalid-contract" | "not-found" | "file-unavailable" => {
                Self::new(error.code, error.message)
            }
            _ => Self::new(
                "internal",
                "The local library could not resolve the selected media file.",
            ),
        }
    }
}

#[tauri::command]
pub(crate) fn file_action_reveal_media(
    request: RevealMediaRequest,
    library: State<'_, LibraryRuntime>,
) -> Result<(), FileActionError> {
    if request.media_id.trim().is_empty() {
        return Err(FileActionError::new(
            "invalid-contract",
            "File reveal requires a non-empty library media id.",
        ));
    }
    let path = library.available_media_path(&request.media_id)?;
    reveal_in_file_manager(Path::new(&path))
}

fn reveal_in_file_manager(path: &Path) -> Result<(), FileActionError> {
    if !path.is_file() {
        return Err(FileActionError::new(
            "file-unavailable",
            "The selected media file is no longer available.",
        ));
    }
    reveal_existing_file(path)
}

#[cfg(target_os = "windows")]
fn reveal_existing_file(path: &Path) -> Result<(), FileActionError> {
    use std::{os::windows::ffi::OsStrExt, ptr};
    use windows_sys::Win32::UI::Shell::{ILCreateFromPathW, ILFree, SHOpenFolderAndSelectItems};

    let path = path
        .as_os_str()
        .encode_wide()
        .chain(std::iter::once(0))
        .collect::<Vec<_>>();
    // SAFETY: `path` is a null-terminated UTF-16 buffer that remains alive for the call.
    let item_id_list = unsafe { ILCreateFromPathW(path.as_ptr()) };
    if item_id_list.is_null() {
        return Err(FileActionError::unavailable());
    }
    // SAFETY: the PIDL came from `ILCreateFromPathW`; cidl=0 asks Shell to select
    // this fully-qualified item in its parent folder. It is released exactly once below.
    let result = unsafe { SHOpenFolderAndSelectItems(item_id_list, 0, ptr::null(), 0) };
    // SAFETY: `item_id_list` is non-null and owned by this function.
    unsafe { ILFree(item_id_list) };
    if result < 0 {
        return Err(FileActionError::unavailable());
    }
    Ok(())
}

#[cfg(not(target_os = "windows"))]
fn reveal_existing_file(_path: &Path) -> Result<(), FileActionError> {
    Err(FileActionError::new(
        "unsupported-platform",
        "Revealing media in the system file manager is currently Windows-only.",
    ))
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;

    use super::*;

    #[test]
    fn maps_public_library_failures_without_exposing_unrelated_database_details() {
        assert_eq!(
            FileActionError::from(LibraryError::new("not-found", "missing row")).code,
            "not-found"
        );
        let internal = FileActionError::from(LibraryError::new(
            "database",
            r"database failure at C:\Users\listener\private.db",
        ));
        assert_eq!(internal.code, "internal");
        assert!(!internal.message.contains("private.db"));
    }

    #[test]
    fn rejects_a_missing_file_before_calling_the_platform_shell() {
        let path =
            PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("missing-file-action-fixture.flac");

        let error = reveal_in_file_manager(&path).expect_err("missing media");

        assert_eq!(error.code, "file-unavailable");
    }
}
