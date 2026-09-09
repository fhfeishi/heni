# Heni Project Router

Heni is a Windows-first local music player. Flutter remains the product
baseline while a Tauri 2 + React + TypeScript implementation is developed
incrementally. Keep this file short: use it to choose the smallest relevant
document set before changing code.

## Start Here

- Product surface and directory map: `docs/project-overview.md`
- Frozen Tauri demand and authority: `docs/task-demand.md`
- Migration baseline and parity: `docs/migration/phase-0-audit.md` →
  `docs/migration/feature-parity-matrix.md`
- Architecture decisions: `docs/adr/`
- Open-source research and license boundaries: `research/README.md`
- Runtime boundaries: `docs/architecture.md`
- Playback, probing, and audio-quality notes: `docs/media-pipeline.md`
- Current priorities and residual risks: `logs/plan.md`
- Windows implementation and verification history: `logs/windows.md`
- User-request decisions and completed work: `logs/request-log.md`
- Approved design/implementation records: `docs/superpowers/`

## Current Product Boundary

- Active platform: Windows desktop.
- Current default: Flutter; Tauri walking skeleton: `apps/desktop`.
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

- Any Tauri migration task: `docs/task-demand.md` →
  `docs/migration/feature-parity-matrix.md` → relevant ADR and learning note.
- Playback-engine selection: `docs/adr/0002-playback-engine-spike.md` →
  `docs/migration/phase-1-plan.md` → `docs/media-pipeline.md`.

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

For Flutter releases, run static analysis, available pure-Dart tests, Windows
Debug/Release and launch/UI smoke. For Tauri milestones, run pnpm lint,
typecheck, test and build plus Rust fmt, clippy, test and the applicable Windows
Release build. Record environmental blockers instead of reporting an
unexecuted test as passing.
