//! One WebView video output, subordinate to the existing Rust playback session.
mod stream;
use super::{
    contracts::{PlaybackError, PlaybackItem},
    engine::EngineObservation,
};
use serde::{Deserialize, Serialize};
use std::{
    fs::File,
    sync::{Arc, Mutex, OnceLock},
};

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct VideoIntent {
    pub source: String,
    pub epoch: u64,
    pub revision: u64,
    pub position_ms: u64,
    pub playing: bool,
    pub volume: f64,
    pub muted: bool,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct VideoReport {
    pub epoch: u64,
    pub revision: u64,
    pub position_ms: u64,
    pub duration_ms: Option<u64>,
    pub paused: bool,
    pub ended: bool,
    pub failed: bool,
}

struct ActiveVideo {
    intent: VideoIntent,
    file: File,
    mime: &'static str,
    observation: EngineObservation,
    quiet: bool,
}

#[derive(Default)]
struct VideoState {
    epoch: u64,
    active: Option<ActiveVideo>,
}

#[derive(Clone, Default)]
pub struct VideoRuntime(
    Arc<Mutex<VideoState>>,
    Arc<OnceLock<Result<stream::VideoServer, String>>>,
);

impl VideoRuntime {
    pub(super) fn load(
        &self,
        item: &PlaybackItem,
        position_ms: u64,
        playing: bool,
        volume: f64,
        muted: bool,
        before_publish: impl FnOnce(),
    ) -> Result<(), PlaybackError> {
        // Paths have already passed the shared picker/library authorization gate.
        let file = File::open(&item.path).map_err(|_| {
            PlaybackError::new("file-unavailable", "The local video could not be opened.")
        })?;
        if !file
            .metadata()
            .is_ok_and(|meta| meta.is_file() && meta.len() > 0)
        {
            return Err(PlaybackError::new(
                "unsupported-media",
                "The video file is empty or unavailable.",
            ));
        }
        let extension = std::path::Path::new(&item.path)
            .extension()
            .and_then(|s| s.to_str())
            .unwrap_or("")
            .to_ascii_lowercase();
        let mime = match extension.as_str() {
            "mp4" | "m4v" | "mov" => "video/mp4",
            "webm" => "video/webm",
            _ => return Err(PlaybackError::new("unsupported-media", "This video container is not supported by the current WebView adapter. Use MP4 or WebM.")),
        };
        let mut state = self
            .0
            .lock()
            .map_err(|_| PlaybackError::new("internal", "The video session is unavailable."))?;
        let server = self
            .1
            .get_or_init(|| stream::VideoServer::start(Arc::downgrade(&self.0)))
            .as_ref()
            .map_err(|_| {
                PlaybackError::new(
                    "playback-unavailable",
                    "The local video stream could not start.",
                )
            })?;
        before_publish();
        state.epoch += 1;
        state.active = Some(ActiveVideo {
            intent: VideoIntent {
                source: server.source(state.epoch),
                epoch: state.epoch,
                revision: 0,
                position_ms,
                playing,
                volume,
                muted,
            },
            file,
            mime,
            quiet: true,
            observation: EngineObservation {
                active: true,
                position_ms,
                duration_ms: item.duration_ms,
                ..Default::default()
            },
        });
        Ok(())
    }

    pub(super) fn stop(&self) {
        if let Ok(mut state) = self.0.lock() {
            state.active = None;
        }
    }

    pub(super) fn change(&self, change: impl FnOnce(&mut VideoIntent)) {
        if let Ok(mut state) = self.0.lock() {
            if let Some(active) = &mut state.active {
                change(&mut active.intent);
                active.intent.revision += 1;
            }
        }
    }

    pub(super) fn observation(&self) -> Option<EngineObservation> {
        self.0
            .lock()
            .ok()?
            .active
            .as_ref()
            .map(|active| active.observation)
    }

    #[allow(
        dead_code,
        reason = "kept for output-state diagnostics and bridge tests"
    )]
    pub(super) fn is_quiet(&self) -> bool {
        self.0.lock().is_ok_and(|state| {
            state.active.as_ref().is_none_or(|active| {
                // A report can be dropped when its revision is stale; the observed
                // terminal state must still count as quiet or audio can never resume.
                active.quiet || active.observation.completed || active.observation.failed
            })
        })
    }

    pub fn exchange(
        &self,
        report: Option<VideoReport>,
    ) -> Result<Option<VideoIntent>, PlaybackError> {
        let mut state = self
            .0
            .lock()
            .map_err(|_| PlaybackError::new("internal", "The video session is unavailable."))?;
        if let Some(active) = &mut state.active {
            if let Some(report) = report.filter(|report| {
                report.epoch == active.intent.epoch && report.revision == active.intent.revision
            }) {
                active.quiet = report.paused || report.ended || report.failed;
                active.observation = EngineObservation {
                    active: true,
                    position_ms: report.position_ms,
                    duration_ms: report.duration_ms,
                    completed: report.ended,
                    failed: report.failed,
                };
            }
            return Ok(Some(active.intent.clone()));
        }
        Ok(None)
    }
}

// The transport streams this extent through bounded reads; never truncate the declared range.
fn byte_range(header: Option<&str>, length: u64) -> Option<(u64, u64)> {
    if length == 0 {
        return None;
    }
    let (start, end) = if let Some(header) = header {
        let (start, end) = header.strip_prefix("bytes=")?.split_once('-')?;
        if start.is_empty() {
            let suffix = end.parse::<u64>().ok()?;
            if suffix == 0 {
                return None;
            }
            (length.saturating_sub(suffix), length - 1)
        } else {
            (
                start.parse::<u64>().ok()?,
                if end.is_empty() {
                    length - 1
                } else {
                    end.parse::<u64>().ok()?.min(length - 1)
                },
            )
        }
    } else {
        (0, length - 1)
    };
    if start >= length || end < start {
        return None;
    }
    Some((start, end))
}

#[tauri::command]
pub async fn video_exchange(
    report: Option<VideoReport>,
    app: tauri::AppHandle,
) -> Result<Option<VideoIntent>, PlaybackError> {
    use tauri::Manager;
    // The stream reader briefly holds the same state lock during file IO.
    // Never wait for that lock on the window thread (especially for removable media).
    super::playback_work(move || app.state::<VideoRuntime>().exchange(report)).await
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{Read, Write};

    fn request(source: &str, range: Option<&str>) -> Vec<u8> {
        let (address, path) = source
            .strip_prefix("http://")
            .unwrap()
            .split_once('/')
            .unwrap();
        let mut socket = std::net::TcpStream::connect(address).unwrap();
        socket
            .set_read_timeout(Some(std::time::Duration::from_secs(3)))
            .unwrap();
        write!(
            socket,
            "GET /{path} HTTP/1.1\r\nHost: {address}\r\nConnection: close\r\n"
        )
        .unwrap();
        if let Some(range) = range {
            write!(socket, "Range: {range}\r\n").unwrap();
        }
        write!(socket, "\r\n").unwrap();
        let mut response = Vec::new();
        socket.read_to_end(&mut response).unwrap();
        response
    }
    struct Fixture(std::path::PathBuf);
    impl Fixture {
        fn new() -> Self {
            let path = std::env::temp_dir().join(format!("heni-video-{}.mp4", fastrand::u128(..)));
            std::fs::write(&path, b"0123456789").unwrap();
            Self(path)
        }
        fn item(&self) -> PlaybackItem {
            PlaybackItem {
                id: "video".into(),
                path: self.0.to_string_lossy().into_owned(),
                title: "fixture".into(),
                kind: super::super::contracts::MediaKind::Video,
                duration_ms: Some(1000),
            }
        }
    }
    impl Drop for Fixture {
        fn drop(&mut self) {
            let _ = std::fs::remove_file(&self.0);
        }
    }

    #[test]
    fn serves_only_the_active_file_and_revokes_old_sources() {
        let fixture = Fixture::new();
        let runtime = VideoRuntime::default();
        runtime
            .load(&fixture.item(), 0, true, 20.0, false, || {})
            .unwrap();
        let first = runtime.exchange(None).unwrap().unwrap();
        let response = String::from_utf8(request(&first.source, Some("bytes=2-5"))).unwrap();
        assert!(response.starts_with("HTTP/1.1 206"));
        assert!(response
            .to_ascii_lowercase()
            .contains("content-range: bytes 2-5/10"));
        assert!(response.ends_with("2345"));
        runtime
            .load(&fixture.item(), 500, false, 20.0, true, || {})
            .unwrap();
        assert!(request(&first.source, None).starts_with(b"HTTP/1.1 403"));
        runtime.stop();
        assert!(runtime.exchange(None).unwrap().is_none());
    }

    #[test]
    fn streams_beyond_the_old_one_megabyte_boundary_and_rejects_unknown_tokens() {
        let fixture = Fixture::new();
        let bytes = vec![42u8; 3 * 1024 * 1024 + 17];
        std::fs::write(&fixture.0, &bytes).unwrap();
        let runtime = VideoRuntime::default();
        runtime
            .load(&fixture.item(), 0, true, 20.0, false, || {})
            .unwrap();
        let source = runtime.exchange(None).unwrap().unwrap().source;
        for range in [None, Some("bytes=0-")] {
            let response = request(&source, range);
            let start = response
                .windows(4)
                .position(|window| window == b"\r\n\r\n")
                .unwrap()
                + 4;
            assert_eq!(response.len() - start, bytes.len());
            assert!(
                response[start..] == bytes,
                "The streamed body must preserve every source byte"
            );
        }
        let origin = source
            .rsplit_once('/')
            .unwrap()
            .0
            .rsplit_once('/')
            .unwrap()
            .0;
        assert!(request(&format!("{origin}/wrong/1"), None).starts_with(b"HTTP/1.1 403"));
        runtime.stop();
        assert!(request(&source, None).starts_with(b"HTTP/1.1 403"));
    }

    #[test]
    fn rejects_old_reports_and_retains_current_position_and_quiet_state() {
        let fixture = Fixture::new();
        let runtime = VideoRuntime::default();
        runtime
            .load(&fixture.item(), 0, true, 20.0, false, || {})
            .unwrap();
        let first = runtime.exchange(None).unwrap().unwrap();
        let report = VideoReport {
            epoch: first.epoch,
            revision: first.revision,
            position_ms: 400,
            duration_ms: Some(1000),
            paused: false,
            ended: false,
            failed: false,
        };
        runtime.exchange(Some(report.clone())).unwrap();
        assert!(!runtime.is_quiet());
        runtime.change(|intent| intent.playing = false);
        let mut stale = report.clone();
        stale.paused = true;
        stale.position_ms = 900;
        runtime.exchange(Some(stale.clone())).unwrap();
        assert!(!runtime.is_quiet());
        assert_eq!(runtime.observation().unwrap().position_ms, 400);
        stale.revision += 1;
        runtime.exchange(Some(stale)).unwrap();
        assert!(runtime.is_quiet());
    }

    #[test]
    fn video_completion_uses_the_existing_repeat_session() {
        use super::super::{
            contracts::PlaybackCommand, controller::PlaybackController, engine::HybridEngine,
        };
        let fixture = Fixture::new();
        let video = VideoRuntime::default();
        let mut controller = PlaybackController::new(HybridEngine::new(video.clone()));
        let initial = controller
            .dispatch(PlaybackCommand::ReplaceQueue {
                queue: vec![fixture.item()],
                current_index: Some(0),
                autoplay: true,
            })
            .unwrap();
        let intent = video.exchange(None).unwrap().unwrap();
        video
            .exchange(Some(VideoReport {
                epoch: intent.epoch,
                revision: intent.revision,
                position_ms: 1000,
                duration_ms: Some(1000),
                paused: true,
                ended: true,
                failed: false,
            }))
            .unwrap();
        controller.tick().unwrap();
        let repeated = controller.snapshot();
        assert!(repeated.generation > initial.generation);
        assert_eq!(repeated.position_ms, 0);
        assert!(video.exchange(None).unwrap().unwrap().epoch > intent.epoch);
        controller.dispatch(PlaybackCommand::Stop).unwrap();
    }
    #[test]
    fn ranges_are_bounded_and_validate_edges() {
        assert_eq!(byte_range(Some("bytes=10-19"), 100), Some((10, 19)));
        assert_eq!(byte_range(Some("bytes=-10"), 100), Some((90, 99)));
        assert_eq!(byte_range(Some("bytes=90-"), 100), Some((90, 99)));
        assert_eq!(byte_range(None, 10_000_000), Some((0, 9_999_999)));
        for invalid in [
            "bytes=100-",
            "bytes=20-10",
            "bytes=-0",
            "bytes=0-2,4-5",
            "file=0-9",
        ] {
            assert_eq!(byte_range(Some(invalid), 100), None);
        }
    }
}
