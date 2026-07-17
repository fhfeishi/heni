# Heni Project Router

Heni is a Windows-first Flutter local music player with a panoramic,
theme-derived desktop shell. Keep this file short: use it to choose the
smallest relevant document set before changing code.

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
- Lowercase `heni` is the product wordmark in the shell and Windows icon.
- The default sidebar is labeled and expanded; narrow widths temporarily force
  the compact icon rail without overwriting the stored preference.

## Task Routing

- UI, resize, title bar, queue, or playback interaction:
  `docs/project-overview.md` → `logs/plan.md` →
  `docs/plans/2026-07-17-panoramic-theme-shell-design.md` when the task affects
  the panoramic shell.
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
