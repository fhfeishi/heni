# Heni Project Router

Heni is a Windows-first Flutter local music player. Keep this file short: use it
to choose the smallest relevant document set before changing code.

## Start Here

- Product surface and directory map: `docs/project-overview.md`
- Runtime boundaries: `docs/architecture.md`
- Playback, probing, and audio-quality notes: `docs/media-pipeline.md`
- Current priorities and residual risks: `logs/plan.md`
- Windows implementation and verification history: `logs/windows.md`
- User-request decisions and completed work: `logs/request-log.md`
- Approved design/implementation records: `docs/superpowers/`

## Current Product Boundary

- Active platform: Windows desktop.
- Playback: original local media path through `media_kit`.
- Metadata: `ffprobe` when available on `PATH`.
- No lyric surface.
- No user-facing FLAC/audio export. Converting lossy audio to FLAC does not
  restore lost detail.
- Minimum full-player client size: `900 × 620` logical pixels.

## Task Routing

- UI, resize, title bar, queue, or playback interaction:
  `docs/project-overview.md` → `logs/plan.md` → relevant recent design plan.
- Playback quality, codec, bitrate, or web-downloaded MP4:
  `docs/media-pipeline.md` → playback service and probe models.
- Windows build or release:
  `logs/windows.md` → `README.md`.
- Historical product intent:
  search the dated entries in `logs/request-log.md`.

## Verification Rule

Before release, run static analysis, available pure-Dart tests, Windows Debug
and Release builds, and a launch/UI smoke check. Record environmental blockers
instead of reporting an unexecuted test as passing.
