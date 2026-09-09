use std::{
    collections::BTreeMap,
    ffi::OsString,
    io::{self, Read},
    path::{Path, PathBuf},
    process::{Command, Stdio},
    thread,
    time::{Duration, Instant},
};

use serde::Deserialize;
use serde_json::Value;

use super::super::contracts::{
    LibraryError, MediaChapterDetails, MediaDetails, MediaStreamDetails, MediaStreamKind,
};

const PROCESS_TIMEOUT: Duration = Duration::from_secs(30);
const MAX_STDOUT_BYTES: usize = 8 * 1024 * 1024;
const MAX_STDERR_BYTES: usize = 128 * 1024;
const MAX_STREAMS: usize = 256;
const MAX_CHAPTERS: usize = 10_000;

#[derive(Clone)]
pub(crate) struct FfprobeMediaInspector {
    executable: PathBuf,
}

impl FfprobeMediaInspector {
    pub(crate) fn new(executable: PathBuf) -> Self {
        Self { executable }
    }

    pub(crate) fn inspect(
        &self,
        media_id: String,
        path: String,
    ) -> Result<MediaDetails, LibraryError> {
        self.inspect_with(&SystemMediaProcessRunner, media_id, path)
    }

    fn inspect_with<R: MediaProcessRunner>(
        &self,
        runner: &R,
        media_id: String,
        path: String,
    ) -> Result<MediaDetails, LibraryError> {
        let arguments = ffprobe_arguments(Path::new(&path));
        let result = runner
            .run(&self.executable, &arguments, PROCESS_TIMEOUT)
            .map_err(process_error)?;
        if !result.success {
            return Err(LibraryError::new(
                "metadata-probe-failed",
                "ffprobe could not read details for this media file.",
            ));
        }
        parse_document(&result.stdout, media_id, path)
    }
}

fn ffprobe_arguments(path: &Path) -> Vec<OsString> {
    [
        "-v",
        "error",
        "-print_format",
        "json",
        "-show_format",
        "-show_streams",
        "-show_chapters",
    ]
    .into_iter()
    .map(OsString::from)
    .chain(std::iter::once(path.as_os_str().to_owned()))
    .collect()
}

struct MediaProcessResult {
    success: bool,
    stdout: Vec<u8>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum ProcessError {
    Unavailable,
    TimedOut,
    OutputTooLarge,
    Io,
}

trait MediaProcessRunner {
    fn run(
        &self,
        executable: &Path,
        arguments: &[OsString],
        timeout: Duration,
    ) -> Result<MediaProcessResult, ProcessError>;
}

#[derive(Clone, Copy, Default)]
struct SystemMediaProcessRunner;

impl MediaProcessRunner for SystemMediaProcessRunner {
    fn run(
        &self,
        executable: &Path,
        arguments: &[OsString],
        timeout: Duration,
    ) -> Result<MediaProcessResult, ProcessError> {
        let mut child = Command::new(executable)
            .args(arguments)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .map_err(|error| {
                if error.kind() == io::ErrorKind::NotFound {
                    ProcessError::Unavailable
                } else {
                    ProcessError::Io
                }
            })?;
        let stdout = child.stdout.take().ok_or(ProcessError::Io)?;
        let stderr = child.stderr.take().ok_or(ProcessError::Io)?;

        thread::scope(|scope| {
            let stdout_worker = scope.spawn(move || read_bounded(stdout, MAX_STDOUT_BYTES));
            let stderr_worker = scope.spawn(move || read_bounded(stderr, MAX_STDERR_BYTES));
            let deadline = Instant::now() + timeout;
            let status = loop {
                match child.try_wait().map_err(|_| ProcessError::Io)? {
                    Some(status) => break status,
                    None if Instant::now() >= deadline => {
                        let _ = child.kill();
                        let _ = child.wait();
                        return Err(ProcessError::TimedOut);
                    }
                    None => thread::sleep(Duration::from_millis(10)),
                }
            };
            let stdout = stdout_worker.join().map_err(|_| ProcessError::Io)??;
            let stderr = stderr_worker.join().map_err(|_| ProcessError::Io)??;
            if stdout.truncated || stderr.truncated {
                return Err(ProcessError::OutputTooLarge);
            }
            Ok(MediaProcessResult {
                success: status.success(),
                stdout: stdout.bytes,
            })
        })
    }
}

struct BoundedOutput {
    bytes: Vec<u8>,
    truncated: bool,
}

fn read_bounded(mut reader: impl Read, maximum: usize) -> Result<BoundedOutput, ProcessError> {
    let mut bytes = Vec::with_capacity(maximum.min(64 * 1024));
    let mut buffer = [0_u8; 16 * 1024];
    let mut truncated = false;
    loop {
        let count = reader.read(&mut buffer).map_err(|_| ProcessError::Io)?;
        if count == 0 {
            break;
        }
        let remaining = maximum.saturating_sub(bytes.len());
        let retained = remaining.min(count);
        bytes.extend_from_slice(&buffer[..retained]);
        truncated |= retained < count;
    }
    Ok(BoundedOutput { bytes, truncated })
}

fn process_error(error: ProcessError) -> LibraryError {
    match error {
        ProcessError::Unavailable => LibraryError::new(
            "metadata-probe-unavailable",
            "Detailed media inspection requires ffprobe on this Windows installation.",
        ),
        ProcessError::TimedOut => LibraryError::new(
            "metadata-probe-failed",
            "Detailed media inspection exceeded the 30 second safety limit.",
        ),
        ProcessError::OutputTooLarge => LibraryError::new(
            "metadata-probe-failed",
            "Detailed media inspection returned more metadata than Heni accepts safely.",
        ),
        ProcessError::Io => LibraryError::new(
            "metadata-probe-failed",
            "Detailed media inspection could not complete its process I/O.",
        ),
    }
}

#[derive(Deserialize)]
struct FfprobeDocument {
    #[serde(default)]
    streams: Vec<FfprobeStream>,
    #[serde(default)]
    chapters: Vec<FfprobeChapter>,
    format: Option<FfprobeFormat>,
}

#[derive(Deserialize)]
struct FfprobeFormat {
    format_name: Option<String>,
    format_long_name: Option<String>,
    duration: Option<Value>,
    size: Option<Value>,
    bit_rate: Option<Value>,
    #[serde(default)]
    tags: BTreeMap<String, String>,
}

#[derive(Deserialize)]
struct FfprobeStream {
    index: Option<Value>,
    codec_type: Option<String>,
    codec_name: Option<String>,
    codec_long_name: Option<String>,
    profile: Option<String>,
    width: Option<Value>,
    height: Option<Value>,
    sample_rate: Option<Value>,
    channels: Option<Value>,
    duration: Option<Value>,
    avg_frame_rate: Option<String>,
    bit_rate: Option<Value>,
    #[serde(default)]
    tags: BTreeMap<String, String>,
}

#[derive(Deserialize)]
struct FfprobeChapter {
    id: Option<Value>,
    start_time: Option<Value>,
    end_time: Option<Value>,
    #[serde(default)]
    tags: BTreeMap<String, String>,
}

fn parse_document(
    bytes: &[u8],
    media_id: String,
    source_path: String,
) -> Result<MediaDetails, LibraryError> {
    let document: FfprobeDocument = serde_json::from_slice(bytes).map_err(|_| {
        LibraryError::new(
            "metadata-probe-failed",
            "ffprobe returned an invalid media details document.",
        )
    })?;
    if document.streams.len() > MAX_STREAMS || document.chapters.len() > MAX_CHAPTERS {
        return Err(LibraryError::new(
            "metadata-probe-failed",
            "The media file contains more streams or chapters than Heni accepts safely.",
        ));
    }
    let format = document.format;
    let streams = document
        .streams
        .into_iter()
        .map(|stream| MediaStreamDetails {
            index: stream.index.as_ref().and_then(parse_i64).unwrap_or(-1),
            kind: match stream.codec_type.as_deref() {
                Some("audio") => MediaStreamKind::Audio,
                Some("video") => MediaStreamKind::Video,
                _ => MediaStreamKind::Unknown,
            },
            codec_name: non_empty(stream.codec_name),
            codec_long_name: non_empty(stream.codec_long_name),
            profile: non_empty(stream.profile),
            width: stream.width.as_ref().and_then(parse_u32),
            height: stream.height.as_ref().and_then(parse_u32),
            sample_rate_hz: stream.sample_rate.as_ref().and_then(parse_u32),
            channels: stream.channels.as_ref().and_then(parse_u32),
            duration_ms: stream.duration.as_ref().and_then(parse_duration_ms),
            frame_rate: stream.avg_frame_rate.filter(|value| valid_rational(value)),
            bit_rate_bps: stream.bit_rate.as_ref().and_then(parse_u64),
            tags: stream.tags,
        })
        .collect();
    let chapters = document
        .chapters
        .into_iter()
        .map(|chapter| MediaChapterDetails {
            id: chapter.id.as_ref().and_then(parse_i64).unwrap_or(-1),
            start_ms: chapter
                .start_time
                .as_ref()
                .and_then(parse_duration_ms)
                .unwrap_or(0),
            end_ms: chapter
                .end_time
                .as_ref()
                .and_then(parse_duration_ms)
                .unwrap_or(0),
            tags: chapter.tags,
        })
        .collect();
    let (format_name, format_long_name, duration_ms, size_bytes, bit_rate_bps, tags) = format
        .map_or((None, None, None, None, None, BTreeMap::new()), |value| {
            (
                non_empty(value.format_name),
                non_empty(value.format_long_name),
                value.duration.as_ref().and_then(parse_duration_ms),
                value.size.as_ref().and_then(parse_u64),
                value.bit_rate.as_ref().and_then(parse_u64),
                value.tags,
            )
        });

    Ok(MediaDetails {
        media_id,
        source_path,
        provider: "ffprobe".to_owned(),
        format_name,
        format_long_name,
        duration_ms,
        size_bytes,
        bit_rate_bps,
        streams,
        chapters,
        tags,
    })
}

fn non_empty(value: Option<String>) -> Option<String> {
    value.filter(|text| !text.is_empty())
}

fn parse_i64(value: &Value) -> Option<i64> {
    match value {
        Value::Number(number) => number.as_i64(),
        Value::String(text) => text.parse().ok(),
        _ => None,
    }
}

fn parse_u64(value: &Value) -> Option<u64> {
    match value {
        Value::Number(number) => number.as_u64(),
        Value::String(text) => text.parse().ok(),
        _ => None,
    }
}

fn parse_u32(value: &Value) -> Option<u32> {
    parse_u64(value).and_then(|number| u32::try_from(number).ok())
}

fn parse_duration_ms(value: &Value) -> Option<u64> {
    let seconds = match value {
        Value::Number(number) => number.as_f64(),
        Value::String(text) => text.parse::<f64>().ok(),
        _ => None,
    }?;
    (seconds.is_finite() && seconds >= 0.0 && seconds <= u64::MAX as f64 / 1_000.0)
        .then(|| (seconds * 1_000.0).round() as u64)
}

fn valid_rational(value: &str) -> bool {
    let Some((numerator, denominator)) = value.split_once('/') else {
        return false;
    };
    numerator.parse::<i64>().is_ok()
        && denominator
            .parse::<i64>()
            .is_ok_and(|denominator| denominator != 0)
}

#[cfg(test)]
mod tests {
    use super::*;

    struct FakeRunner {
        result: Vec<u8>,
    }

    impl MediaProcessRunner for FakeRunner {
        fn run(
            &self,
            _executable: &Path,
            _arguments: &[OsString],
            _timeout: Duration,
        ) -> Result<MediaProcessResult, ProcessError> {
            Ok(MediaProcessResult {
                success: true,
                stdout: self.result.clone(),
            })
        }
    }

    #[test]
    fn parses_the_flutter_media_detail_baseline_into_typed_fields() {
        let runner = FakeRunner {
            result: br#"{
              "streams": [
                {"index": 0, "codec_name": "h264", "codec_long_name": "H.264 / AVC", "codec_type": "video", "width": 1920, "height": 1080, "avg_frame_rate": "30000/1001", "duration": "12.500000"},
                {"index": 1, "codec_name": "aac", "codec_type": "audio", "sample_rate": "48000", "channels": 2, "duration": "12.500000", "bit_rate": "128000"}
              ],
              "chapters": [{"id": 7, "start_time": "1.250", "end_time": "2.500", "tags": {"title": "Intro"}}],
              "format": {"format_name": "mov,mp4,m4a,3gp,3g2,mj2", "format_long_name": "QuickTime / MOV", "duration": "12.500000", "size": "1234567", "bit_rate": "789000", "tags": {"title": "Sample"}}
            }"#.to_vec(),
        };
        let inspector = FfprobeMediaInspector::new(PathBuf::from("ffprobe"));

        let details = inspector
            .inspect_with(
                &runner,
                "media-one".to_owned(),
                r"C:\Music\sample.mp4".to_owned(),
            )
            .expect("details");

        assert_eq!(details.provider, "ffprobe");
        assert_eq!(details.duration_ms, Some(12_500));
        assert_eq!(details.streams[0].kind, MediaStreamKind::Video);
        assert_eq!(details.streams[0].width, Some(1_920));
        assert_eq!(details.streams[1].sample_rate_hz, Some(48_000));
        assert_eq!(details.chapters[0].start_ms, 1_250);
        assert_eq!(
            details.tags.get("title").map(String::as_str),
            Some("Sample")
        );
    }

    #[test]
    fn builds_structured_arguments_with_the_source_path_as_one_os_argument() {
        let path = Path::new(r"C:\Music files\一首歌.flac");

        let arguments = ffprobe_arguments(path);

        assert_eq!(arguments.len(), 8);
        assert_eq!(arguments[6], OsString::from("-show_chapters"));
        assert_eq!(arguments[7], path.as_os_str());
    }

    #[test]
    fn rejects_invalid_json_and_zero_denominator_frame_rates() {
        assert!(!valid_rational("0/0"));
        assert!(!valid_rational("unknown"));
        assert!(parse_document(b"[]", "id".to_owned(), "path".to_owned()).is_err());
    }

    #[test]
    #[ignore = "requires ffprobe on PATH and the generated media fixture"]
    fn probes_the_generated_mp4_through_the_production_process_runner() {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("..")
            .join("spikes")
            .join("media-fixtures")
            .join("generated")
            .join("tone.mp4");
        let inspector = FfprobeMediaInspector::new(PathBuf::from("ffprobe"));

        let details = inspector
            .inspect(
                "generated-video".to_owned(),
                path.to_string_lossy().into_owned(),
            )
            .expect("production ffprobe details");

        assert_eq!(details.duration_ms, Some(1_000));
        assert!(details
            .streams
            .iter()
            .any(|stream| stream.kind == MediaStreamKind::Audio));
    }
}
