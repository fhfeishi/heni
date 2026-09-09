use std::{
    fs,
    path::{Path, PathBuf},
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
};

use super::{
    contracts::{LibraryError, LibraryImportItem, LibraryIndexedItem, LibraryMediaKind},
    metadata::index_import_item,
};

const BATCH_SIZE: usize = 128;
const AUDIO_EXTENSIONS: &[&str] = &[
    "aac", "aiff", "alac", "flac", "m4a", "mp3", "ogg", "opus", "wav", "wma",
];
const VIDEO_EXTENSIONS: &[&str] = &[
    "avi", "flv", "m4v", "mkv", "mov", "mp4", "mpeg", "mpg", "ts", "webm", "wmv",
];

pub(crate) struct ScanOptions {
    pub(crate) root: PathBuf,
    pub(crate) recursive: bool,
    pub(crate) include_video: bool,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub(crate) struct ScanProgress {
    pub(crate) visited: u64,
    pub(crate) matched: u64,
    pub(crate) unreadable: u64,
}

pub(crate) struct ScanSummary {
    pub(crate) progress: ScanProgress,
    pub(crate) cancelled: bool,
}

pub(crate) fn scan_directory<Progress, Batch>(
    options: &ScanOptions,
    cancelled: &Arc<AtomicBool>,
    mut on_progress: Progress,
    mut on_batch: Batch,
) -> Result<ScanSummary, LibraryError>
where
    Progress: FnMut(ScanProgress) -> bool,
    Batch: FnMut(&[LibraryIndexedItem]) -> Result<(), LibraryError>,
{
    if !options.root.is_dir() {
        return Err(LibraryError::new(
            "file-unavailable",
            "The selected library directory is no longer available.",
        ));
    }

    let mut progress = ScanProgress::default();
    let mut directories = vec![options.root.clone()];
    let mut batch = Vec::with_capacity(BATCH_SIZE);

    while let Some(directory) = directories.pop() {
        if cancelled.load(Ordering::Acquire) {
            break;
        }
        let mut entries = match fs::read_dir(&directory) {
            Ok(entries) => entries.filter_map(Result::ok).collect::<Vec<_>>(),
            Err(_) => {
                progress.unreadable = progress.unreadable.saturating_add(1);
                continue;
            }
        };
        entries.sort_by_key(fs::DirEntry::path);

        for entry in entries {
            if cancelled.load(Ordering::Acquire) {
                break;
            }
            progress.visited = progress.visited.saturating_add(1);
            let file_type = match entry.file_type() {
                Ok(file_type) => file_type,
                Err(_) => {
                    progress.unreadable = progress.unreadable.saturating_add(1);
                    continue;
                }
            };
            if file_type.is_symlink() {
                continue;
            }
            if file_type.is_dir() {
                if options.recursive {
                    directories.push(entry.path());
                }
                continue;
            }
            if !file_type.is_file() {
                continue;
            }

            let path = entry.path();
            let Some(kind) = media_kind(&path, options.include_video) else {
                continue;
            };
            let Some(title) = path
                .file_name()
                .map(|value| value.to_string_lossy().into_owned())
            else {
                continue;
            };
            batch.push(index_import_item(LibraryImportItem {
                path: path.to_string_lossy().into_owned(),
                title,
                kind,
                duration_ms: None,
            }));
            progress.matched = progress.matched.saturating_add(1);

            if batch.len() >= BATCH_SIZE {
                on_batch(&batch)?;
                batch.clear();
                if !on_progress(progress) {
                    cancelled.store(true, Ordering::Release);
                    break;
                }
            }
        }
    }

    if !batch.is_empty() {
        on_batch(&batch)?;
    }
    let was_cancelled = cancelled.load(Ordering::Acquire);
    if !on_progress(progress) {
        cancelled.store(true, Ordering::Release);
    }
    Ok(ScanSummary {
        progress,
        cancelled: was_cancelled || cancelled.load(Ordering::Acquire),
    })
}

pub(super) fn media_kind(path: &Path, include_video: bool) -> Option<LibraryMediaKind> {
    let extension = path.extension()?.to_string_lossy().to_lowercase();
    if AUDIO_EXTENSIONS.contains(&extension.as_str()) {
        return Some(LibraryMediaKind::Audio);
    }
    (include_video && VIDEO_EXTENSIONS.contains(&extension.as_str()))
        .then_some(LibraryMediaKind::Video)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn classifies_the_flutter_audio_and_video_extension_baseline() {
        assert_eq!(
            media_kind(Path::new("C:/Music/ONE.FLAC"), false),
            Some(LibraryMediaKind::Audio)
        );
        assert_eq!(media_kind(Path::new("C:/Music/movie.mkv"), false), None);
        assert_eq!(
            media_kind(Path::new("C:/Music/movie.mkv"), true),
            Some(LibraryMediaKind::Video)
        );
        assert_eq!(media_kind(Path::new("C:/Music/cover.jpg"), true), None);
    }

    #[test]
    fn scans_generated_fixtures_in_bounded_batches() {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("..")
            .join("spikes")
            .join("media-fixtures")
            .join("generated");
        let cancelled = Arc::new(AtomicBool::new(false));
        let mut paths = Vec::new();

        let summary = scan_directory(
            &ScanOptions {
                root,
                recursive: true,
                include_video: false,
            },
            &cancelled,
            |_| true,
            |items| {
                paths.extend(items.iter().map(|item| item.item.path.clone()));
                Ok(())
            },
        )
        .expect("fixture scan");

        assert!(!summary.cancelled);
        assert!(summary.progress.matched >= 6);
        assert_eq!(summary.progress.matched as usize, paths.len());
        assert!(paths.iter().all(|path| !path.ends_with("tone.mp4")));
    }

    #[test]
    fn honours_a_cancellation_token_before_reading_the_directory() {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("..")
            .join("spikes")
            .join("media-fixtures")
            .join("generated");
        let cancelled = Arc::new(AtomicBool::new(true));
        let mut batches = 0;

        let summary = scan_directory(
            &ScanOptions {
                root,
                recursive: true,
                include_video: true,
            },
            &cancelled,
            |_| true,
            |_| {
                batches += 1;
                Ok(())
            },
        )
        .expect("cancelled scan");

        assert!(summary.cancelled);
        assert_eq!(summary.progress.visited, 0);
        assert_eq!(batches, 0);
    }
}
