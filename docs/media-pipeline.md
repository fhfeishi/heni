# Media Pipeline Notes

This document is the learning trail for Heni's audio/video internals.

## Playback Is Not Editing

The player should not decode frames by hand. For local playback we use
`media_kit`, which delegates the hard real-time work to a mature media engine.
That keeps the UI responsive and lets us focus on controls, scenery, themes,
and user workflow.

Editing and export are different. They need deterministic jobs that can be
retried, cancelled, inspected, and logged. For that path we start with FFmpeg
as an external process.

## Terms

- Container: the file wrapper, such as `mp4`, `mkv`, `m4a`, `flac`, or `wav`.
- Stream: one track inside the container, such as video, audio, subtitle, or
  attachment.
- Codec: how a stream is encoded, such as H.264, HEVC, AAC, Opus, or FLAC.
- Probe: reading structure and metadata without converting the file.
- Transcode: decoding and re-encoding one or more streams.
- Remux: changing the container while copying streams without re-encoding.

## Current Implementation

`FfprobeMediaInspector` calls:

```text
ffprobe -v error -print_format json -show_format -show_streams -show_chapters <input>
```

The JSON result is parsed into `MediaProbe`, `MediaStreamProbe`, and
`MediaChapterProbe`. UI code should depend on these typed objects, not raw JSON.

`FfmpegCommandBuilder` creates argument lists for future jobs. It returns
`List<String>` instead of a shell command string. This matters because media
paths often contain spaces, quotes, non-ASCII characters, and user-controlled
text.

`FfmpegJobRunner` adds `-progress pipe:1 -nostats` to FFmpeg commands and reads
the machine-friendly progress protocol. FFmpeg emits blocks of `key=value`
lines, ending each block with `progress=continue` or `progress=end`. Heni parses
those blocks into `FfmpegProgress` objects so the UI can eventually show export
progress, speed, output duration, and completion state.

The current FFmpeg build emits both `out_time_us` and `out_time_ms`. They carry
the same microsecond value in practice, so Heni prefers `out_time_us` and treats
`out_time_ms` as a compatibility fallback.

`FfmpegMediaEditor` is the first use-case layer above raw commands. It exposes
`extractAudio`, while internally using `FfmpegCommandBuilder` and
`FfmpegJobRunner`. The UI now calls this use case through a Riverpod controller
instead of knowing how to assemble FFmpeg arguments itself.

## First Editing Capabilities To Add Later

1. Inspect media with `ffprobe`.
2. Trim without re-encoding when possible.
3. Extract audio to WAV/FLAC/Opus.
4. Generate waveform data or preview images.
5. Export video with a small set of profiles.

## Fast Trim vs Accurate Trim

FFmpeg has an important tradeoff:

- Stream copy trim (`-c copy`) is fast because it does not decode and encode the
  streams again. Its boundaries can land on packet or keyframe edges, so the
  output duration may not exactly match the requested range.
- Re-encoded trim is slower and may change quality, but it can be much more
  accurate for editing UI, previews, and exports.

Heni should expose this later as two clear modes: quick lossless clip and
precise export.

## Licensing Note

Using the user's installed FFmpeg as an external process is the simplest early
development path. If Heni later bundles FFmpeg binaries, the build choice
matters: GPL-enabled codecs such as x264/x265 impose distribution obligations.
We should decide that deliberately when packaging begins.
