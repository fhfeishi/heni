# Windows Development Log

Last updated: 2026-05-13

## Status

Windows is the active development target.

## Environment

- Flutter: 3.41.9 stable
- Dart: 3.11.5
- Windows target: windows-x64
- Visual Studio: Community 2022 17.14.30
- Windows SDK: 10.0.26100.0
- Developer Mode: enabled
- FFmpeg/ffprobe: available on PATH

## Implemented

- Flutter project scaffold generated for Windows and other future platforms.
- Windows plugin symlink issue resolved by enabling Developer Mode.
- Windows CMake install prefix fixed to bundle files beside `heni.exe`.
- Debug build succeeds:
  `build/windows/x64/runner/Debug/heni.exe`
- Release build succeeds:
  `build/windows/x64/runner/Release/heni.exe`
- Debug and Release executables pass a short launch smoke test.
- UI shell implemented:
  - Full-screen scenery stage.
  - Local audio/video file picker.
  - Local folder scanning for audio/video media.
  - Local scenery image picker.
  - In-memory playlists.
  - Playlist/library UI style.
  - Playback controls.
  - Previous/next item controls.
  - Shuffle mode.
  - Repeat all and repeat one modes.
  - Progress slider.
  - Palette selector.
  - UI style selector: Scenery, Cinema, Library.
  - Basic settings: recursive folder scan, include video files, autoplay on load.
  - Media metadata line.
  - FLAC audio extraction action.
- Playback abstraction implemented with `PlaybackEngine` and `media_kit`.
- Video rendering implemented with `media_kit_video`.
- Playback queue controller implemented for Heni-side playlist state and
  automatic advance after media completion.
- Local media scanner implemented for folder-based libraries.
- Media inspection implemented with `ffprobe` JSON parsing.
- FFmpeg command builder implemented for trim and audio extraction.
- FFmpeg job runner implemented with progress parsing, stderr tail capture,
  timeout handling, and cancellation.
- Audio extraction use case and Riverpod controller implemented.

## Verified

```powershell
flutter pub get
flutter analyze
flutter test
flutter build windows --debug
flutter build windows --release
```

Current test count: 16 passing tests.

## Issues Seen And Resolved

- `media_kit_libs_windows_video` first downloaded a zero-byte `ANGLE.7z`.
  Removing the bad archive and rebuilding resolved it.
- CMake tried to install into `C:/Program Files/heni`.
  `windows/CMakeLists.txt` now forces local bundle install beside the exe.

## Current Gaps

- Interactive UI testing with real audio/video files is still pending.
- Playback behavior with different codecs and large files is still pending.
- FLAC extraction has unit and process-level coverage, but needs manual UI
  verification from the running app.
- Playlists are currently in-memory only.
- Playlist editing is basic: create playlist, add files, load folder, select and
  play items. Rename/delete/reorder are not implemented yet.
- FFmpeg/ffprobe paths currently rely on PATH; a settings override should be
  added later.

## Next Windows Steps

1. Run `flutter run -d windows` and visually test the first screen.
2. Test opening local MP3, FLAC, WAV, MP4, MKV, and WebM files.
3. Test loading a folder with recursive scan on and off.
4. Test shuffle, repeat all, and repeat one across short playlists.
5. Test selecting multiple scenery images and watching transitions.
6. Test `Extract FLAC` on audio-only and video files.
7. Improve empty states, loading states, and export error display.
8. Add a small debug media-details panel for codec learning.
9. Add persistent settings for theme, scenery pack, playlists, and FFmpeg path.
