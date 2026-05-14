# Windows Development Log

Last updated: 2026-05-14

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
  - Product-style desktop layout with top navigation, left playlist sidebar,
    main playback content area, and bottom transport bar.
  - Simplified top navigation: Heni logo, 美景/歌曲 switch, centered palette
    selector, and settings only.
  - Top "歌曲" tab opens the playlist/song-list view; the built-in all-media
    collection remains named "曲库" in the left sidebar.
  - Simplified UI mode selector: 美景 and 歌曲. 影院模式先暂停，等有明确的
    视频沉浸播放设计后再做。
  - Full-screen scenery stage inside the playback content area.
  - Local audio/video file picker.
  - Local folder scanning for audio/video media.
  - Local scenery image picker.
  - Library that merges media from multiple folders and file imports.
  - Playlists that add library songs as path references without copying media.
  - Library rows expose an explicit "加入歌单" action for adding songs to user
    playlists.
  - Playlist pages expose "从曲库添加" with search and multi-select bulk add.
  - User playlists expose a three-dot sidebar menu for adding songs from the
    library, renaming, editing descriptions, and deleting.
  - Playlist browsing no longer interrupts the independent playback queue.
  - Playlist/library UI style.
  - Playback controls.
  - Previous/next item controls backed by the current playback queue.
  - Icon-only playback mode control: sequence, list loop, single loop, random.
  - Progress slider.
  - Speaker-only volume control that opens a bare vertical slider on click.
  - Rich compact top palette selector with solid color swatches, black/white
    palette choices, selected glow, and expanded preset themes.
  - Active palette visibly tints the top bar, sidebar, selected playlist rows,
    bottom bar, utility controls, and volume control.
  - Cleaner bottom bar layout with left now-playing, centered transport/progress,
    and right-side utility controls.
  - Speaker volume opens a bare custom vertical slider with no visible panel,
    prompt, percent label, or inactive track; it starts from the actual cached
    current volume.
  - Optional local lyric display for same-name `.lrc` and `.txt` files.
  - Unified app font family preferring Microsoft YaHei with desktop fallbacks.
  - UI style selector: 美景, 歌曲.
  - Chinese UI copy for the main Windows player.
  - Basic settings: recursive folder scan, include video files, autoplay on load.
  - Media metadata line.
  - FLAC audio extraction action.
- Playback abstraction implemented with `PlaybackEngine` and `media_kit`.
- Video rendering implemented with `media_kit_video`.
- Playback queue controller implemented for Heni-side playlist state and
  automatic advance after media completion.
- Local media scanner implemented for folder-based libraries.
- Local JSON library config implemented at `%APPDATA%/Heni/library.json` on
  Windows. It stores media directories, manually added file paths, playlist
  path references, and basic scan settings.
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

Current test count: 27 passing tests.

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
- Playlist persistence now stores path references, not copied media files.
- Playlist editing is basic: create/delete playlist, add library items, rename,
  edit descriptions, load folders, select and play items. Reorder is not
  implemented yet.
- FFmpeg/ffprobe paths currently rely on PATH; a settings override should be
  added later.

## Next Windows Steps

1. Run `flutter run -d windows` and visually test the first screen.
2. Test opening local MP3, FLAC, WAV, MP4, MKV, and WebM files.
3. Test loading a folder with recursive scan on and off.
4. Test sequence, list loop, single loop, and random modes across short playlists.
5. Test selecting multiple scenery images and watching transitions.
6. Test `Extract FLAC` on audio-only and video files.
7. Improve empty states, loading states, and export error display.
8. Add a small debug media-details panel for codec learning.
9. Add persistent settings for theme, scenery pack, playlists, and FFmpeg path.
