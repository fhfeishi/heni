# Heni

Heni is a local audio and video player focused on a calm, beautiful playback
surface. The first milestone is a polished player shell with selectable scenery
images. The media layer is intentionally separated so future editing,
transcoding, waveform, and export features can grow without tangling the UI.

Current focus: Windows desktop. Android, iOS, macOS, and Ubuntu/Linux are
scaffolded but paused; see `logs/paused-platforms.md`.

## Current Direction

- Flutter for the cross-platform application shell.
- `media_kit` for playback.
- `ffprobe`/`ffmpeg` as a process-backed media toolkit for inspection and
  future editing jobs.
- Riverpod for state boundaries.
- Small domain models instead of code generation-heavy architecture at the
  beginning.

## Local Setup

Run:

```powershell
flutter pub get
flutter run -d windows
```

The Windows environment should have `ffmpeg` and `ffprobe` available on PATH for
media probing and extraction.

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

Release output:

```text
build/windows/x64/runner/Release/heni.exe
```

## Docs

- `docs/architecture.md` explains the application boundaries.
- `docs/media-pipeline.md` explains the playback, probing, and future codec
  pipeline in learning-friendly terms.
- `docs/project-overview.md` maps the current project structure.
- `logs/windows.md` records active Windows progress.
- `logs/paused-platforms.md` records paused platform status.
