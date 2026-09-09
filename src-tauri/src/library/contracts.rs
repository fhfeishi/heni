use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub(crate) enum LibraryMediaKind {
    Audio,
    Video,
}

impl LibraryMediaKind {
    pub(crate) fn as_str(self) -> &'static str {
        match self {
            Self::Audio => "audio",
            Self::Video => "video",
        }
    }
}

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct LibraryImportItem {
    pub(crate) path: String,
    pub(crate) title: String,
    pub(crate) kind: LibraryMediaKind,
    pub(crate) duration_ms: Option<u64>,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct LibraryRelocateRequest {
    pub(crate) media_id: String,
    pub(crate) new_path: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "kebab-case")]
pub(crate) enum LibraryMetadataStatus {
    Pending,
    Indexed,
    Failed,
}

impl LibraryMetadataStatus {
    pub(crate) fn as_str(self) -> &'static str {
        match self {
            Self::Pending => "pending",
            Self::Indexed => "indexed",
            Self::Failed => "failed",
        }
    }
}

#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct LibraryFastMetadata {
    pub(crate) codec_name: Option<String>,
    pub(crate) sample_rate_hz: Option<u32>,
    pub(crate) channels: Option<u32>,
    pub(crate) bits_per_sample: Option<u32>,
    pub(crate) file_size_bytes: Option<u64>,
    pub(crate) estimated_bit_rate_bps: Option<u64>,
}

#[derive(Clone, Debug)]
pub(crate) struct LibraryIndexedItem {
    pub(crate) item: LibraryImportItem,
    pub(crate) metadata_status: LibraryMetadataStatus,
    pub(crate) fast_metadata: Option<LibraryFastMetadata>,
}

impl LibraryIndexedItem {
    #[cfg(test)]
    pub(crate) fn pending(item: LibraryImportItem) -> Self {
        Self {
            item,
            metadata_status: LibraryMetadataStatus::Pending,
            fast_metadata: None,
        }
    }
}

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct LibraryScanRequest {
    pub(crate) root: String,
    pub(crate) recursive: bool,
    pub(crate) include_video: bool,
}

#[derive(Clone, Debug, Serialize)]
#[serde(
    tag = "event",
    rename_all = "kebab-case",
    rename_all_fields = "camelCase"
)]
pub(crate) enum LibraryScanEvent {
    Started {
        scan_id: String,
    },
    Progress {
        scan_id: String,
        visited: u64,
        matched: u64,
        unreadable: u64,
    },
    Completed {
        scan_id: String,
        visited: u64,
        matched: u64,
        unreadable: u64,
    },
    Cancelled {
        scan_id: String,
        visited: u64,
        matched: u64,
        unreadable: u64,
    },
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct LibraryItem {
    pub(crate) id: String,
    pub(crate) path: String,
    pub(crate) title: String,
    pub(crate) kind: LibraryMediaKind,
    pub(crate) duration_ms: Option<u64>,
    pub(crate) available: bool,
    pub(crate) metadata_status: LibraryMetadataStatus,
    pub(crate) fast_metadata: Option<LibraryFastMetadata>,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct MediaDetailsRequest {
    pub(crate) media_id: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub(crate) enum MediaStreamKind {
    Audio,
    Video,
    Unknown,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct MediaStreamDetails {
    pub(crate) index: i64,
    pub(crate) kind: MediaStreamKind,
    pub(crate) codec_name: Option<String>,
    pub(crate) codec_long_name: Option<String>,
    pub(crate) profile: Option<String>,
    pub(crate) width: Option<u32>,
    pub(crate) height: Option<u32>,
    pub(crate) sample_rate_hz: Option<u32>,
    pub(crate) channels: Option<u32>,
    pub(crate) duration_ms: Option<u64>,
    pub(crate) frame_rate: Option<String>,
    pub(crate) bit_rate_bps: Option<u64>,
    pub(crate) tags: BTreeMap<String, String>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct MediaChapterDetails {
    pub(crate) id: i64,
    pub(crate) start_ms: u64,
    pub(crate) end_ms: u64,
    pub(crate) tags: BTreeMap<String, String>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct MediaDetails {
    pub(crate) media_id: String,
    pub(crate) source_path: String,
    pub(crate) provider: String,
    pub(crate) format_name: Option<String>,
    pub(crate) format_long_name: Option<String>,
    pub(crate) duration_ms: Option<u64>,
    pub(crate) size_bytes: Option<u64>,
    pub(crate) bit_rate_bps: Option<u64>,
    pub(crate) streams: Vec<MediaStreamDetails>,
    pub(crate) chapters: Vec<MediaChapterDetails>,
    pub(crate) tags: BTreeMap<String, String>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct LibraryPlaylist {
    pub(crate) id: String,
    pub(crate) name: String,
    pub(crate) description: String,
    pub(crate) item_ids: Vec<String>,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct PlaylistCreateRequest {
    pub(crate) name: String,
    pub(crate) description: String,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct PlaylistUpdateRequest {
    pub(crate) playlist_id: String,
    pub(crate) name: String,
    pub(crate) description: String,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct PlaylistIdRequest {
    pub(crate) playlist_id: String,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct PlaylistItemsRequest {
    pub(crate) playlist_id: String,
    pub(crate) media_ids: Vec<String>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct LibrarySnapshot {
    pub(crate) schema_version: u32,
    pub(crate) items: Vec<LibraryItem>,
    pub(crate) playlists: Vec<LibraryPlaylist>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(
    tag = "state",
    rename_all = "kebab-case",
    rename_all_fields = "camelCase"
)]
pub(crate) enum LegacyImportStatus {
    NotFound,
    Ready {
        media_count: u64,
        playlist_count: u64,
    },
    Imported,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct LegacyImportOutcome {
    pub(crate) snapshot: LibrarySnapshot,
    pub(crate) imported_media: u64,
    pub(crate) imported_playlists: u64,
    pub(crate) backup_path: Option<String>,
    pub(crate) already_imported: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub(crate) struct LibraryError {
    pub(crate) code: String,
    pub(crate) message: String,
}

impl LibraryError {
    pub(crate) fn new(code: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            code: code.into(),
            message: message.into(),
        }
    }

    pub(crate) fn database() -> Self {
        Self::new(
            "database",
            "The local Heni library database could not complete this operation.",
        )
    }
}
