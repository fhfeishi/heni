# Media Pipeline Notes

This document is the learning trail for Heni's audio/video internals.

## Playback Is Not Editing

The player should not decode frames by hand. For local playback we use
`media_kit`, which delegates the hard real-time work to a mature media engine.
That keeps the UI responsive and lets us focus on controls, scenery, themes,
and user workflow.

Editing and export are different. They need deterministic jobs that can be
retried, cancelled, inspected, and logged. Heni retains low-level FFmpeg job
infrastructure for possible future editing, but the current player has no
user-facing audio-export action.

## Terms

- Container: the file wrapper, such as `mp4`, `mkv`, `m4a`, `flac`, or `wav`.
- Stream: one track inside the container, such as video, audio, subtitle, or
  attachment.
- Codec: how a stream is encoded, such as H.264, HEVC, AAC, Opus, or FLAC.
- Probe: reading structure and metadata without converting the file.
- Transcode: decoding and re-encoding one or more streams.
- Remux: changing the container while copying streams without re-encoding.

## Current Implementation

`MediaKitPlaybackEngine` opens the selected local media path directly through
`media_kit`. The player does not first convert the file with FFmpeg and does not
add an equalizer, loudness normalizer, pitch filter, or lossy re-encode step.
Status: `已验证` by source audit and Windows runtime playback on 2026-07-16.

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

`FfmpegCommandBuilder` and `FfmpegJobRunner` remain as low-level, tested
infrastructure for trim/job experiments. The former audio-editor/controller
path and the player FLAC export button were removed. Lossy AAC/MP3 converted to
FLAC would only create a larger lossless wrapper around already-lost detail.

## Listening Quality Interpretation

- MP4 is a container, not an audio-quality grade. A downloaded MP4 may contain
  low-bitrate AAC or a higher-quality stream; inspect the audio codec and
  bitrate before judging it by extension.
- The listening console reports source codec, bitrate, sample rate, channel
  count, and a conservative lossless label for FLAC, ALAC, WavPack, and PCM.
- A high sample rate or FLAC label does not prove that the recording was never
  transcoded earlier. It only describes the current source stream.
- Heni currently makes no bit-perfect claim. Windows or the selected output
  device may resample decoded PCM according to the system mix format. Status:
  `待核验` per output device unless a future diagnostics view measures the
  complete device path.
- Perceived fatigue can come from the source master, clipping, low-bitrate
  encoding, or repeated web transcoding even when player logic is neutral.

## Possible Editing Capabilities Later

1. Inspect media with `ffprobe`.
2. Trim without re-encoding when possible.
3. Extract or transcode audio only as an explicit editing workflow, with copy
   and re-encode semantics clearly explained.
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
