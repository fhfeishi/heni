mod ffprobe;

use std::{fs, fs::File, path::Path};

pub(crate) use ffprobe::FfprobeMediaInspector;
use symphonia::{
    core::{
        common::Limit,
        formats::{probe::Hint, FormatOptions, TrackType},
        io::MediaSourceStream,
        meta::MetadataOptions,
    },
    default::get_probe,
};

use super::contracts::{
    LibraryFastMetadata, LibraryImportItem, LibraryIndexedItem, LibraryMediaKind,
    LibraryMetadataStatus,
};
use crate::media_support::audio_codec_registry;

pub(crate) fn index_import_item(item: LibraryImportItem) -> LibraryIndexedItem {
    if item.kind == LibraryMediaKind::Video {
        return LibraryIndexedItem {
            fast_metadata: file_size_metadata(Path::new(&item.path)),
            item,
            metadata_status: LibraryMetadataStatus::Pending,
        };
    }

    let path = Path::new(&item.path);
    match inspect_audio(path) {
        Some((duration_ms, fast_metadata)) => {
            let mut item = item;
            item.duration_ms = duration_ms.or(item.duration_ms);
            LibraryIndexedItem {
                item,
                metadata_status: LibraryMetadataStatus::Indexed,
                fast_metadata: Some(fast_metadata),
            }
        }
        None => LibraryIndexedItem {
            fast_metadata: file_size_metadata(path),
            item,
            metadata_status: LibraryMetadataStatus::Failed,
        },
    }
}

fn inspect_audio(path: &Path) -> Option<(Option<u64>, LibraryFastMetadata)> {
    let file = File::open(path).ok()?;
    let source = MediaSourceStream::new(Box::new(file), Default::default());
    let mut hint = Hint::new();
    if let Some(extension) = path.extension().and_then(|value| value.to_str()) {
        hint.with_extension(extension);
    }
    let metadata_options = MetadataOptions::default()
        .limit_tag_bytes(Limit::Maximum(64 * 1024))
        .limit_visual_bytes(Limit::Maximum(0));
    let format = get_probe()
        .probe(&hint, source, FormatOptions::default(), metadata_options)
        .ok()?;
    let track = format.default_track(TrackType::Audio)?;
    let audio = track.codec_params.as_ref()?.audio()?;
    let duration_ms = track
        .duration
        .and_then(|duration| track.time_base?.calc_duration(duration))
        .and_then(|duration| u64::try_from(duration.as_millis()).ok())
        .or_else(|| {
            let sample_rate = audio.sample_rate?;
            track
                .num_frames
                .map(|frames| frames.saturating_mul(1_000) / u64::from(sample_rate))
        });
    let file_size_bytes = fs::metadata(path).ok().map(|metadata| metadata.len());
    let estimated_bit_rate_bps = file_size_bytes
        .zip(duration_ms)
        .filter(|(_, duration)| *duration > 0)
        .and_then(|(size, duration)| {
            size.checked_mul(8)?
                .checked_mul(1_000)?
                .checked_div(duration)
        });
    let codec_name = audio_codec_registry()
        .get_audio_decoder(audio.codec)
        .map(|decoder| decoder.codec.info.short_name.to_owned());

    Some((
        duration_ms,
        LibraryFastMetadata {
            codec_name,
            sample_rate_hz: audio.sample_rate,
            channels: audio
                .channels
                .as_ref()
                .and_then(|channels| u32::try_from(channels.count()).ok()),
            bits_per_sample: audio.bits_per_sample,
            file_size_bytes,
            estimated_bit_rate_bps,
        },
    ))
}

fn file_size_metadata(path: &Path) -> Option<LibraryFastMetadata> {
    fs::metadata(path).ok().map(|metadata| LibraryFastMetadata {
        file_size_bytes: Some(metadata.len()),
        ..LibraryFastMetadata::default()
    })
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;

    use super::*;

    fn fixture(name: &str) -> String {
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("..")
            .join("spikes")
            .join("media-fixtures")
            .join("generated")
            .join(name)
            .to_string_lossy()
            .into_owned()
    }

    #[test]
    fn indexes_audio_headers_without_decoding_the_whole_file() {
        let indexed = index_import_item(LibraryImportItem {
            path: fixture("tone.flac"),
            title: "tone.flac".to_owned(),
            kind: LibraryMediaKind::Audio,
            duration_ms: None,
        });

        assert_eq!(indexed.metadata_status, LibraryMetadataStatus::Indexed);
        assert!(indexed
            .item
            .duration_ms
            .is_some_and(|duration| duration >= 900));
        let metadata = indexed.fast_metadata.expect("fast metadata");
        assert_eq!(metadata.codec_name.as_deref(), Some("flac"));
        assert_eq!(metadata.sample_rate_hz, Some(48_000));
        assert_eq!(metadata.channels, Some(2));
        assert!(metadata.file_size_bytes.is_some_and(|size| size > 0));
        assert!(metadata
            .estimated_bit_rate_bps
            .is_some_and(|bit_rate| bit_rate > 0));
    }

    #[test]
    fn keeps_video_for_detailed_probe_instead_of_starting_ffprobe_during_indexing() {
        let indexed = index_import_item(LibraryImportItem {
            path: fixture("tone.mp4"),
            title: "tone.mp4".to_owned(),
            kind: LibraryMediaKind::Video,
            duration_ms: None,
        });

        assert_eq!(indexed.metadata_status, LibraryMetadataStatus::Pending);
        assert!(indexed
            .fast_metadata
            .and_then(|value| value.file_size_bytes)
            .is_some());
    }
}
