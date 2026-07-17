# Heni

Heni is a local audio and video player focused on a calm, beautiful playback
surface. The current Windows shell uses a studio-matte listening console,
full-window panoramic scenery, theme-derived chrome and surfaces, adaptive
navigation, and a custom themed title bar. Playback and media inspection remain
separated from the UI.

Current focus: Windows desktop. Android, iOS, macOS, and Ubuntu/Linux are
scaffolded but paused; see `logs/paused-platforms.md`.

## Current Direction

- Flutter for the cross-platform application shell.
- `media_kit` for playback.
- `ffprobe` for source metadata and retained low-level `ffmpeg` infrastructure
  for possible future editing work. There is no user-facing audio export.
- Riverpod for state boundaries.
- Small domain models instead of code generation-heavy architecture at the
  beginning.

## Local Setup

Run:

```powershell
flutter pub get
flutter run -d windows
```

The Windows environment should have `ffprobe` available on PATH for source
metadata. Low-level FFmpeg utilities remain in the repository, but Heni has no
user-facing audio export.

On Windows, Flutter desktop plugins require symlink support. If `flutter pub get`
or `flutter build windows` reports that plugins need symlinks, enable Developer
Mode in Windows Settings:

```powershell
start ms-settings:developers
```

Then reopen Codex or run Flutter from a fresh terminal so the PATH and system
settings are visible to the process.

## Windows Build

```powershell
flutter analyze
flutter test
flutter build windows --release
```

If `flutter test` cannot connect to its local listener, verify Windows loopback
health first. The current development machine has an operating-system-level
loopback failure; see `logs/plan.md`.

Release output:

```text
build/windows/x64/runner/Release/heni.exe
```

## Docs

- `strata.md` routes development tasks to the smallest relevant document set.
- `docs/architecture.md` explains the application boundaries.
- `docs/media-pipeline.md` explains the playback, probing, and future codec
  pipeline in learning-friendly terms.
- `docs/project-overview.md` maps the current project structure.
- `logs/plan.md` records current release acceptance and next priorities.
- `logs/windows.md` records active Windows progress.
- `logs/paused-platforms.md` records paused platform status.
