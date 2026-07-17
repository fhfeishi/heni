# Heni Windows Plan

Last updated: 2026-07-17

## Current Focus

Ship the panoramic theme canvas as the Windows baseline and verify the same
commit in both the feature worktree and the normal workspace Release output.

## Release Acceptance

- [x] The scenery image reaches the full UI, including title bar, navigation,
  workspace, and bottom dock.
- [x] Theme-derived semantic surfaces keep controls readable without restoring
  a default gray outer frame.
- [x] The only shell wordmark is lowercase `heni`; the Windows icon uses the
  same lowercase wordmark and contains 16/24/32/48/256-pixel frames.
- [x] Custom minimize, maximize/restore, close, and drag behavior remains wired.
- [x] The window cannot shrink below the usable `900 × 620` logical client
  area.
- [x] The sidebar defaults to labeled expanded mode, forces compact mode below
  the narrow threshold, and restores expanded mode with resize hysteresis.
- [x] The progress display preserves its seek track and keeps time labels from
  colliding while the window width changes.
- [x] The queue locator centers and briefly highlights the current track without
  clearing an active search filter.
- [x] Volume uses a theme-matched horizontal popover with mute/restore, wheel
  adjustment, percentage feedback, and persisted final values.
- [x] Lyrics and user-facing FLAC/audio export are absent; FLAC playback and
  honest source-codec labeling remain supported.
- [x] Final feature-worktree Release build, launch/UI smoke, and checksum are
  recorded in `logs/windows.md`.
- [ ] The feature commit is fast-forwarded into the normal workspace, rebuilt
  there, launch-smoked, and pushed to the remote.

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

- `flutter test` cannot start its test harness on this machine because the
  runner cannot connect to its local listener on `127.0.0.1` before any test
  assertion. Status: `已验证` as a host-environment limitation on 2026-07-17.
  Use static analysis, the available pure-Dart subset, Windows builds, and
  native runtime checks; never report the blocked widget suite as passing.
