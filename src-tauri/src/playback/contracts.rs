use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PlaybackItem {
    pub id: String,
    pub path: String,
    pub title: String,
    pub kind: MediaKind,
    pub duration_ms: Option<u64>,
}

#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum MediaKind {
    Audio,
    Video,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
#[expect(
    dead_code,
    reason = "loading and failed are reserved for the Phase 1 audio adapter"
)]
pub enum PlaybackStatus {
    Idle,
    Loading,
    Playing,
    Paused,
    Stopped,
    Completed,
    Failed,
}

#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum RepeatMode {
    None,
    All,
    One,
}

/// The three user-facing modes. `sequential` and `shuffle` both loop the queue;
/// `one` repeats the current track. There is no "stop at the end" mode anymore.
#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum PlaybackMode {
    Sequential,
    Shuffle,
    One,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PlaybackSnapshot {
    pub generation: u64,
    pub sequence: u64,
    pub status: PlaybackStatus,
    pub queue: Vec<PlaybackItem>,
    pub current_index: Option<usize>,
    pub position_ms: u64,
    pub duration_ms: Option<u64>,
    pub volume: f64,
    pub muted: bool,
    pub repeat_mode: RepeatMode,
    pub shuffle: bool,
    /// The item the playback order will actually play next (shuffle/repeat aware).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub next_index: Option<usize>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub preferences_error: Option<PlaybackError>,
}

#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct PlaybackVersion {
    pub generation: u64,
    pub sequence: u64,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PlaybackPosition {
    pub generation: u64,
    pub sequence: u64,
    pub status: PlaybackStatus,
    pub media_id: Option<String>,
    pub position_ms: u64,
    pub duration_ms: Option<u64>,
}

#[derive(Clone, Debug, Serialize)]
#[serde(tag = "type", rename_all = "lowercase")]
pub enum PlaybackUpdate {
    Snapshot { snapshot: PlaybackSnapshot },
    Position { position: PlaybackPosition },
}

#[derive(Clone, Debug, Deserialize)]
#[serde(
    tag = "type",
    rename_all = "kebab-case",
    rename_all_fields = "camelCase"
)]
pub enum PlaybackCommand {
    ReplaceQueue {
        queue: Vec<PlaybackItem>,
        current_index: Option<usize>,
        autoplay: bool,
    },
    Play,
    Pause,
    Stop,
    Seek {
        position_ms: u64,
    },
    Next,
    Previous,
    PlayIndex {
        index: usize,
    },
    RemoveIndex {
        index: usize,
    },
    ReorderQueue {
        from_index: usize,
        to_index: usize,
    },
    RefreshItem {
        item: PlaybackItem,
    },
    Enqueue {
        items: Vec<PlaybackItem>,
    },
    PlayNext {
        items: Vec<PlaybackItem>,
    },
    SetVolume {
        volume: f64,
    },
    PreviewVolume {
        volume: f64,
        generation: u64,
        sequence: u64,
        gesture_id: String,
    },
    CancelVolumePreview {
        generation: u64,
        sequence: u64,
        gesture_id: String,
    },
    CommitVolumePreview {
        volume: f64,
        generation: u64,
        sequence: u64,
        gesture_id: String,
    },
    SetMuted {
        muted: bool,
    },
    SetRepeatMode {
        repeat_mode: RepeatMode,
    },
    SetShuffle {
        shuffle: bool,
    },
    SetPlaybackMode {
        mode: PlaybackMode,
    },
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct PlaybackError {
    pub code: String,
    pub message: String,
}

impl PlaybackError {
    pub fn new(code: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            code: code.into(),
            message: message.into(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::PlaybackCommand;

    #[test]
    fn accepts_every_shared_typescript_rust_ipc_command_fixture() {
        let fixtures = serde_json::from_str::<Vec<serde_json::Value>>(include_str!(
            "../../../fixtures/playback/commands.json"
        ))
        .expect("shared command fixtures should be valid JSON");

        for fixture in fixtures {
            serde_json::from_value::<PlaybackCommand>(fixture)
                .expect("shared command fixture should match the Rust contract");
        }
    }

    #[test]
    fn serializes_the_exact_updates_validated_by_typescript() {
        use super::{PlaybackItem, PlaybackVersion};
        use crate::playback::session::PlaybackSession;
        let fixtures: Vec<serde_json::Value> =
            serde_json::from_str(include_str!("../../../fixtures/playback/updates.json"))
                .expect("shared update fixtures");
        let item: PlaybackItem =
            serde_json::from_value(fixtures[0]["snapshot"]["queue"][0].clone())
                .expect("fixture item");
        let mut session = PlaybackSession::default();
        session
            .dispatch(PlaybackCommand::ReplaceQueue {
                queue: vec![item],
                current_index: Some(0),
                autoplay: true,
            })
            .expect("load fixture");
        // JavaScript has one number type; serde_json distinguishes 100 from 100.0.
        let mut expected_snapshot = fixtures[0].clone();
        expected_snapshot["snapshot"]["volume"] = serde_json::json!(fixtures[0]["snapshot"]
            ["volume"]
            .as_f64()
            .expect("numeric volume"));
        assert_eq!(
            serde_json::to_value(session.update(PlaybackVersion {
                generation: 0,
                sequence: 0,
            }))
            .expect("full wire"),
            expected_snapshot
        );
        session.sync_runtime(250, Some(60_000), false, false);
        assert_eq!(
            serde_json::to_value(session.update(PlaybackVersion {
                generation: 1,
                sequence: 0,
            }))
            .expect("position wire"),
            fixtures[1]
        );
    }
}
