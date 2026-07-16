# Heni Windows Plan

Last updated: 2026-07-16

## Current Focus

Ship the studio-matte listening-console update as the new Windows baseline.

## Release Acceptance

- [x] The outer Windows frame follows the active Heni theme.
- [x] Custom minimize, maximize/restore, close, and drag behavior works.
- [x] The window cannot shrink below the usable `900 × 620` logical client
  area.
- [x] The background image affects the full shell while retaining readable
  matte surfaces.
- [x] Audio playback shows the current track, source path, real probe metadata,
  next track, file location, and queue-location actions.
- [x] The queue dialog opens centered on the current track and remains
  scrollable in shorter windows.
- [x] Lyrics and user-facing FLAC export are absent.
- [x] Final Windows Release build and launch smoke are recorded in
  `logs/windows.md`.

## Next Product Work

1. Test representative MP3, AAC-in-MP4/M4A, FLAC, WAV, Opus, and video files
   through the Release executable.
2. Add an optional audio-output diagnostics view only if users need to inspect
   Windows output format or resampling; do not label playback as bit-perfect
   without device-path evidence.
3. Add playlist reorder after the current queue and library interactions have
   settled.
4. Add configurable `ffprobe` discovery if relying on `PATH` becomes a common
   setup problem.

## Known Environment Risk

- `flutter test` cannot start its test harness on this machine because both
  `127.0.0.1` and `::1` loopback connections fail before any test assertion.
  Pure-Dart tests and Windows runtime checks remain usable. Status: `已验证`
  as an operating-system/network limitation on 2026-07-16.
