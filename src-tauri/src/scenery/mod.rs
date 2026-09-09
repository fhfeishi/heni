use std::{
    fs::File,
    io::{Cursor, Read},
    path::Path,
    sync::Mutex,
};

use base64::{engine::general_purpose::STANDARD, Engine};
use image::{ImageDecoder, ImageFormat, ImageReader, Limits};
use serde::Serialize;
use tauri::Manager;
use tauri_plugin_dialog::DialogExt;

use crate::settings::SettingsRuntime;

pub(crate) mod collection;
use collection::{SceneryCollection, MAX_IMAGES};

const MAX_FILE_BYTES: u64 = 8 * 1024 * 1024;
const MAX_IMAGE_EDGE: u32 = 8192;
const MAX_IMAGE_PIXELS: u64 = 24_000_000;
const MAX_COLLECTION_BYTES: u64 = 64 * 1024 * 1024;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "kebab-case")]
pub(crate) enum SceneryError {
    Busy,
    Database,
    FileUnavailable,
    UnsupportedImage,
    ImageTooLarge,
    CollectionTooLarge,
    Internal,
}

#[derive(Debug, Serialize)]
#[serde(
    tag = "state",
    rename_all = "kebab-case",
    rename_all_fields = "camelCase"
)]
pub(crate) enum ScenerySnapshot {
    Empty,
    Ready {
        file_name: String,
        data_url: String,
        collection: CollectionPosition,
    },
    Unavailable {
        file_name: String,
        reason: SceneryError,
        collection: CollectionPosition,
    },
}

#[derive(Debug, Serialize)]
pub(crate) struct CollectionPosition {
    index: usize,
    count: usize,
}

fn collection_snapshot(value: &SceneryCollection) -> ScenerySnapshot {
    let mut snapshot = restore_scenery(value.current());
    match &mut snapshot {
        ScenerySnapshot::Ready { collection, .. }
        | ScenerySnapshot::Unavailable { collection, .. } => {
            *collection = CollectionPosition {
                index: value.index,
                count: value.paths.len(),
            };
        }
        ScenerySnapshot::Empty => {}
    }
    snapshot
}

fn validate_selection(paths: Vec<std::path::PathBuf>) -> Result<SceneryCollection, SceneryError> {
    if paths.is_empty() || paths.len() > MAX_IMAGES {
        return Err(SceneryError::CollectionTooLarge);
    }
    let mut value = SceneryCollection::default();
    let mut total = 0u64;
    for path in paths {
        let path = path
            .canonicalize()
            .map_err(|_| SceneryError::FileUnavailable)?;
        let reference = path
            .to_str()
            .ok_or(SceneryError::FileUnavailable)?
            .to_owned();
        if value.paths.contains(&reference) {
            continue;
        }
        total += path
            .metadata()
            .map_err(|_| SceneryError::FileUnavailable)?
            .len();
        if total > MAX_COLLECTION_BYTES {
            return Err(SceneryError::CollectionTooLarge);
        }
        // Validate serially and release each decoded image before reading the next.
        // No collection-wide base64 cache or payload is retained.
        read_image(&path)?;
        value.paths.push(reference);
    }
    Ok(value)
}

// One native picker / mutation at a time. Reads may use the last committed path.
#[derive(Default)]
pub(crate) struct SceneryRuntime(Mutex<()>);

fn file_name(path: &Path) -> String {
    path.file_name()
        .map(|name| name.to_string_lossy().into_owned())
        .unwrap_or_else(|| "本地图片".to_string())
}

fn image_error(error: image::ImageError) -> SceneryError {
    if matches!(error, image::ImageError::Limits(_)) {
        SceneryError::ImageTooLarge
    } else {
        SceneryError::UnsupportedImage
    }
}

fn image_data_url(bytes: &[u8]) -> Result<String, SceneryError> {
    if bytes.len() as u64 > MAX_FILE_BYTES {
        return Err(SceneryError::ImageTooLarge);
    }
    let format = image::guess_format(bytes).map_err(image_error)?;
    let mime = match format {
        ImageFormat::Png => "image/png",
        ImageFormat::Jpeg => "image/jpeg",
        _ => return Err(SceneryError::UnsupportedImage),
    };
    let mut header = ImageReader::with_format(Cursor::new(bytes), format);
    let mut header_limits = Limits::default();
    header_limits.max_alloc = Some(128 * 1024 * 1024);
    let (width, height) = if format == ImageFormat::Png {
        let decoder =
            image::codecs::png::PngDecoder::with_limits(Cursor::new(bytes), header_limits)
                .map_err(image_error)?;
        if decoder.is_apng().map_err(image_error)? {
            return Err(SceneryError::UnsupportedImage);
        }
        decoder.dimensions()
    } else {
        header.limits(header_limits);
        header.into_dimensions().map_err(image_error)?
    };
    if width > MAX_IMAGE_EDGE
        || height > MAX_IMAGE_EDGE
        || u64::from(width) * u64::from(height) > MAX_IMAGE_PIXELS
    {
        return Err(SceneryError::ImageTooLarge);
    }
    let mut reader = ImageReader::with_format(Cursor::new(bytes), format);
    let mut limits = Limits::default();
    limits.max_image_width = Some(MAX_IMAGE_EDGE);
    limits.max_image_height = Some(MAX_IMAGE_EDGE);
    limits.max_alloc = Some(128 * 1024 * 1024);
    reader.limits(limits);
    // Decode before committing the selection; a valid header alone is not enough.
    reader.decode().map_err(image_error)?;
    Ok(format!("data:{mime};base64,{}", STANDARD.encode(bytes)))
}

fn read_image(path: &Path) -> Result<ScenerySnapshot, SceneryError> {
    let file = File::open(path).map_err(|_| SceneryError::FileUnavailable)?;
    let metadata = file.metadata().map_err(|_| SceneryError::FileUnavailable)?;
    if !metadata.is_file() {
        return Err(SceneryError::FileUnavailable);
    }
    if metadata.len() > MAX_FILE_BYTES {
        return Err(SceneryError::ImageTooLarge);
    }
    let mut bytes = Vec::new();
    file.take(MAX_FILE_BYTES + 1)
        .read_to_end(&mut bytes)
        .map_err(|_| SceneryError::FileUnavailable)?;
    Ok(ScenerySnapshot::Ready {
        file_name: file_name(path),
        data_url: image_data_url(&bytes)?,
        collection: CollectionPosition { index: 0, count: 1 },
    })
}

fn restore_scenery(path: Option<&str>) -> ScenerySnapshot {
    let Some(path) = path else {
        return ScenerySnapshot::Empty;
    };
    let path = Path::new(path);
    read_image(path).unwrap_or_else(|reason| ScenerySnapshot::Unavailable {
        file_name: file_name(path),
        reason,
        collection: CollectionPosition { index: 0, count: 1 },
    })
}

#[tauri::command]
pub(crate) async fn scenery_read(app: tauri::AppHandle) -> Result<ScenerySnapshot, SceneryError> {
    tauri::async_runtime::spawn_blocking(move || {
        let collection = app
            .state::<SettingsRuntime>()
            .scenery_collection()
            .map_err(|_| SceneryError::Database)?;
        Ok(collection_snapshot(&collection))
    })
    .await
    .map_err(|_| SceneryError::Internal)?
}

#[tauri::command]
pub(crate) async fn scenery_choose(
    app: tauri::AppHandle,
    window: tauri::WebviewWindow,
) -> Result<Option<ScenerySnapshot>, SceneryError> {
    tauri::async_runtime::spawn_blocking(move || {
        let runtime = app.state::<SceneryRuntime>();
        let _operation = runtime.0.try_lock().map_err(|_| SceneryError::Busy)?;
        // No caller-supplied path is accepted by IPC: authorization is this native picker.
        let selected = app
            .dialog()
            .file()
            .set_parent(&window)
            .set_title("选择 heni 美景背景")
            .add_filter("静态图片（PNG、JPEG）", &["png", "jpg", "jpeg"])
            .blocking_pick_files();
        let Some(selected) = selected else {
            return Ok(None);
        };
        if selected.is_empty() {
            return Ok(None);
        }
        let paths = selected
            .into_iter()
            .map(|file| file.into_path().map_err(|_| SceneryError::FileUnavailable))
            .collect::<Result<Vec<_>, _>>()?;
        let collection = validate_selection(paths)?;
        let snapshot = collection_snapshot(&collection);
        if let ScenerySnapshot::Unavailable { reason, .. } = snapshot {
            return Err(reason);
        }
        app.state::<SettingsRuntime>()
            .set_scenery_collection(&collection)
            .map_err(|_| SceneryError::Database)?;
        Ok(Some(snapshot))
    })
    .await
    .map_err(|_| SceneryError::Internal)?
}

#[tauri::command]
pub(crate) async fn scenery_clear(app: tauri::AppHandle) -> Result<ScenerySnapshot, SceneryError> {
    tauri::async_runtime::spawn_blocking(move || {
        let runtime = app.state::<SceneryRuntime>();
        let _operation = runtime.0.try_lock().map_err(|_| SceneryError::Busy)?;
        // Clear only the preference, never the user's source file.
        app.state::<SettingsRuntime>()
            .set_scenery_collection(&SceneryCollection::default())
            .map_err(|_| SceneryError::Database)?;
        Ok(ScenerySnapshot::Empty)
    })
    .await
    .map_err(|_| SceneryError::Internal)?
}

#[tauri::command]
pub(crate) async fn scenery_step(
    app: tauri::AppHandle,
    forward: bool,
) -> Result<ScenerySnapshot, SceneryError> {
    tauri::async_runtime::spawn_blocking(move || {
        let runtime = app.state::<SceneryRuntime>();
        let _operation = runtime.0.try_lock().map_err(|_| SceneryError::Busy)?;
        let settings = app.state::<SettingsRuntime>();
        let mut collection = settings
            .scenery_collection()
            .map_err(|_| SceneryError::Database)?;
        collection.advance(forward);
        let snapshot = collection_snapshot(&collection);
        settings
            .set_scenery_collection(&collection)
            .map_err(|_| SceneryError::Database)?;
        Ok(snapshot)
    })
    .await
    .map_err(|_| SceneryError::Internal)?
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fixture(format: ImageFormat) -> Vec<u8> {
        let image = image::RgbImage::from_pixel(3, 2, image::Rgb([60, 100, 120]));
        let mut bytes = Cursor::new(Vec::new());
        image
            .write_to(&mut bytes, format)
            .expect("fixture encoding");
        bytes.into_inner()
    }

    #[test]
    fn selection_is_bounded_deduplicated_and_does_not_hide_missing_members() {
        assert!(matches!(
            validate_selection(vec![]),
            Err(SceneryError::CollectionTooLarge)
        ));
        assert!(matches!(
            validate_selection(vec!["missing.png".into(); MAX_IMAGES + 1]),
            Err(SceneryError::CollectionTooLarge)
        ));
        let path = std::env::temp_dir().join(format!(
            "heni-collection-image-{}-{}.png",
            std::process::id(),
            fastrand::u64(..)
        ));
        let bytes = fixture(ImageFormat::Png);
        std::fs::write(&path, &bytes).expect("isolated fixture");
        let mut value = validate_selection(vec![path.clone(), path.clone()]).expect("deduplicated");
        assert_eq!(value.paths.len(), 1);
        assert_eq!(std::fs::read(&path).expect("source unchanged"), bytes);
        value
            .paths
            .push("missing-heni-collection-member.png".into());
        value.advance(true);
        assert!(matches!(
            collection_snapshot(&value),
            ScenerySnapshot::Unavailable {
                reason: SceneryError::FileUnavailable,
                collection: CollectionPosition { index: 1, count: 2 },
                ..
            }
        ));
        value.advance(true);
        assert!(matches!(
            collection_snapshot(&value),
            ScenerySnapshot::Ready {
                collection: CollectionPosition { index: 0, count: 2 },
                ..
            }
        ));
        std::fs::remove_file(path).expect("remove only generated image fixture");
    }

    #[test]
    fn restoring_selection_reads_without_modifying_the_source_and_retains_missing_identity() {
        let path = std::env::temp_dir().join(format!(
            "heni-scenery-{}-{}.png",
            std::process::id(),
            fastrand::u64(..)
        ));
        let bytes = fixture(ImageFormat::Png);
        std::fs::write(&path, &bytes).expect("new isolated fixture");
        assert!(matches!(restore_scenery(None), ScenerySnapshot::Empty));
        assert!(matches!(
            restore_scenery(path.to_str()),
            ScenerySnapshot::Ready { .. }
        ));
        assert_eq!(std::fs::read(&path).expect("source remains"), bytes);
        std::fs::remove_file(&path).expect("remove only this generated fixture");
        let restored = restore_scenery(path.to_str());
        assert!(matches!(
            restored,
            ScenerySnapshot::Unavailable {
                reason: SceneryError::FileUnavailable,
                ..
            }
        ));
    }

    #[test]
    fn validates_png_and_jpeg_content_without_relying_on_extension() {
        for (format, mime) in [
            (ImageFormat::Png, "image/png"),
            (ImageFormat::Jpeg, "image/jpeg"),
        ] {
            let bytes = fixture(format);
            assert_eq!(
                image_data_url(&bytes).expect("valid"),
                format!("data:{mime};base64,{}", STANDARD.encode(&bytes))
            );
        }
    }

    #[test]
    fn decoding_budget_failures_have_an_actionable_size_error() {
        let error = image::ImageError::Limits(image::error::LimitError::from_kind(
            image::error::LimitErrorKind::InsufficientMemory,
        ));
        assert_eq!(image_error(error), SceneryError::ImageTooLarge);
    }

    #[test]
    fn rejects_unknown_or_corrupt_images() {
        for bytes in [
            b"<svg onload='script'/>".as_slice(),
            b"not a picture",
            b"GIF89a",
        ] {
            assert_eq!(image_data_url(bytes), Err(SceneryError::UnsupportedImage));
        }
        let mut bytes = fixture(ImageFormat::Png);
        bytes.truncate(40);
        assert_eq!(image_data_url(&bytes), Err(SceneryError::UnsupportedImage));
    }

    #[test]
    fn rejects_oversized_input_and_decoded_dimensions() {
        assert_eq!(
            image_data_url(&vec![0; MAX_FILE_BYTES as usize + 1]),
            Err(SceneryError::ImageTooLarge)
        );
        let image = image::RgbImage::new(MAX_IMAGE_EDGE + 1, 1);
        let mut bytes = Cursor::new(Vec::new());
        image
            .write_to(&mut bytes, ImageFormat::Png)
            .expect("large header fixture");
        assert_eq!(
            image_data_url(bytes.get_ref()),
            Err(SceneryError::ImageTooLarge)
        );
    }

    #[test]
    fn missing_file_is_unavailable_and_filename_never_exposes_parent_directories() {
        assert!(matches!(
            read_image(Path::new("missing-heni-scenery-test.png")),
            Err(SceneryError::FileUnavailable)
        ));
        assert_eq!(file_name(Path::new("private/folder/海岸.png")), "海岸.png");
    }
}
