# Windows Development Log

Last updated: 2026-07-17

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
- Windows app icon unified to the provided custom `d.ico` asset.
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
  - Top and bottom shell bands now share a more unified breathing rhythm
    through matched framing, glow, and subtle entrance motion.
  - The shared shell-band system now also mirrors highlight placement between
    the top navigation and bottom playback areas for stronger frame continuity.
  - Simplified top navigation: Heni logo, 美景/歌曲 switch, centered palette
    selector, and settings only.
  - Top "歌曲" tab opens the playlist/song-list view; the built-in all-media
    collection remains named "曲库" in the left sidebar.
  - Refreshed shell styling with coordinated matte/glass surfaces across the
    top bar, sidebar, content header, library view, and bottom player bar.
  - Added palette-tinted ambient backdrop lighting behind the shell so theme
    changes read more clearly across the full window.
  - Refined the top bar with a compact logo tile, calmer spacing, and a more
    polished palette selector.
  - Sidebar now shows compact library metrics and a more deliberate empty state
    for playlists.
  - Song list presentation refined with summary pills, a softer table header,
    numbered rows, and more structured type/source metadata.
  - Bottom player bar refined with a clearer now-playing summary, stronger
    transport hierarchy, pill-style progress area, and calmer utility grouping.
  - The bottom-right utility group now includes a dedicated current playback
    list control ahead of playback mode and volume.
  - The current playback queue dialog now has stronger hierarchy with source
    and count pills, current-track emphasis, and queue search.
  - Current playback queue rows now use calmer inline action buttons and more
    deliberate hover/current-item emphasis.
  - Main player dialogs now share a more consistent frame with unified inset,
    inner spacing, and action-area rhythm.
  - Theme-level dialog and popup styling now reinforces that same consistency
    through shared radius, tint, text, and menu spacing.
  - The sidebar now transitions into the main content through a softer bridge
    and right-edge glow instead of a harder split.
  - The top palette selector now has a richer active-theme preview and more
    refined swatch sizing/treatment.
  - Information hierarchy is now more deliberate across the songs header,
    sidebar status area, and bottom now-playing summary.
  - Hover timing and content transitions now share a calmer motion language
    across playlist tiles, song rows, queue rows, theme changes, and now-
    playing updates.
  - Icon density is now more consistent across bottom controls and row actions,
    table spacing is tighter, and the scenery page's lower info block sits more
    lightly against the background.
  - High-frequency action labels have been tightened for a more even product
    density, and a final Windows release/launch smoke pass completed cleanly.
  - Add-from-library dialog rows now use rounded card styling and clearer media
    type chips so playlist curation feels more integrated with the main UI.
  - Top navigation theme control now shows the active palette name and reads as
    a more complete product control instead of a bare swatch strip.
  - Song rows now respond to hover and selection with animated leading
    indicators, deeper surfaces, and calmer action emphasis.
  - Sidebar playlist items now respond to hover with light lift, softer motion,
    and clearer option-menu emphasis.
  - The 美景/歌曲 switcher now sits inside a clearer rounded shell and includes
    lightweight icons for stronger mode identity.
  - The scenery playback page now uses a dedicated listening console for audio
    instead of an optional lyric surface.
  - The main play button now has subtle motion and glow changes between play
    and pause states.
  - Scenery image transitions now use slower layered fade/scale motion with a
    calmer drift for a more cinematic background change.
  - Lower-left media information in scenery mode now has clearer hierarchy and
    lighter containment.
  - Centered video playback now sits inside a softer framed surface with
    rounded outer spacing and shadow.
  - Scenery ambience now subtly responds to active playback so the page feels
    more connected to the transport state.
  - Bottom now-playing summary now reflects play state with small glow and
    emphasis changes.
  - Video mode now reuses the lower-left scenery info block.
  - Right-side songs-view header now distinguishes correctly between the full
    library and custom playlists when displaying counts and supporting metrics.
  - Settings now open as a dedicated dialog with grouped toggle cards and a
    compact library summary.
  - Songs-view empty states now use a more polished card instead of raw text.
  - Scenery audio mode now composes the ambient orb with the lower info block
    rather than leaving it static in the center of the stage.
  - Top navigation now has a gentler entrance feel and a more alive
    palette-responsive brand treatment.
  - Bottom now-playing information now transitions more smoothly when the
    current media changes.
  - Theme choice, UI mode, and scenery image selections are now restored as
    part of the app's persisted shell experience.
  - Library refresh is now a first-class action that rescans configured sources
    with current scan settings and keeps playlist path references aligned with
    refreshed library items.
  - Songs-view header now shows gentler refresh progress/result pills, and the
    settings dialog includes an immediate refresh action.
  - Songs-view refresh feedback now uses calmer animated badges for active
    refresh and refresh/restore results.
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
  - Custom playlists now support row-level removal and a dedicated
    multi-select "管理歌曲" flow for removing songs without touching local
    files.
  - Custom playlist song tables now also support in-place multi-select mode
    with checkbox rows, select-all, batch removal, and selected-count feedback.
  - Songs-table row styling now more clearly distinguishes hover, now-playing,
    and checked-for-batch-edit states.
  - User playlists expose a three-dot sidebar menu for adding songs from the
    library, renaming, editing descriptions, and deleting.
  - Playlist browsing no longer interrupts the independent playback queue.
  - The current playback queue now has a dedicated dialog that can jump
    playback to any queued item and remove queued songs directly.
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
  - Unified app font family preferring Microsoft YaHei with desktop fallbacks.
  - UI style selector: 美景, 歌曲.
  - Chinese UI copy for the main Windows player.
  - Basic settings: recursive folder scan, include video files, autoplay on load.
  - Media metadata line.
  - No lyric surface and no user-facing audio export.
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
dart test test/services/files/local_file_actions_test.dart test/features/player/presentation/playback_queue_location_test.dart
flutter build windows --debug
flutter build windows --release
```

The available pure-Dart regression set passes. `flutter test` is currently
blocked before suite loading by the host loopback failure described below.

## Issues Seen And Resolved

- `media_kit_libs_windows_video` first downloaded a zero-byte `ANGLE.7z`.
  Removing the bad archive and rebuilding resolved it.
- CMake tried to install into `C:/Program Files/heni`.
  `windows/CMakeLists.txt` now forces local bundle install beside the exe.

## Current Gaps

- Broader Release playback behavior across representative codecs and large
  files is still pending.
- Playlist persistence now stores path references, not copied media files.
- Playlist editing is basic: create/delete playlist, add library items, rename,
  edit descriptions, remove items, load folders, select and play items.
  Reorder is not implemented yet.
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

## 2026-05-16 - Launch Crash Fix

- Symptom:
  app launched to a black screen and logged
  `Cannot hit test a render box that has never been laid out.`
- Root cause:
  the top navigation used `_ShellBand` with an unbounded `Stack`; after that
  was fixed, `_TopPaletteDeck` still had a height-collapse overflow caused by
  an `AnimatedSwitcher` around the active theme label.
- Fix:
  gave the top shell band a fixed height and simplified the theme label
  animation to a stable text-style transition.
- Validation:
  `flutter analyze`, `flutter test`,
  `flutter build windows --release`,
  Windows release launch smoke passed.

## 2026-05-17 - Responsive UI Polish

- Added a shell layout model with compact and quiet modes for the Windows UI.
- Top and bottom shell bands now tighten their height based on window size.
- Sidebar width, padding, and the optional status block now respond to window
  size.
- The scenery page hides the decorative orb in quieter layouts to protect the
  main media stage.
- The bottom player hides lower-priority now-playing details in quieter layouts
  so transport and utility controls stay readable.
- The songs table header and rows now share the same column widths, which fixes
  the previous visual misalignment in playlist detail pages.
- The top theme picker now shows palette names on hover instead of keeping the
  text always visible.

## 2026-05-17 - Theme Atmosphere And Table Finish

- The main Windows backdrop now animates when the palette changes instead of
  switching abruptly.
- Added an extra palette-linked glow wash so the active theme feels more global.
- The top border accent now blends between seed and accent colors for a richer
  palette signature.
- The songs table header now has clearer hierarchy and a slightly more premium
  surface treatment.
- The songs rows now use subtle alternating rhythm plus a refined active rail
  and highlight line for better scanability.

## 2026-05-17 - Palette Strip Cleanup And Glass Pass

- The top palette chooser on Windows is now a pure swatch strip with no reserved
  label space on the left.
- Removed hover-driven palette strip reflow to stop the earlier flicker.
- Shared glass panels now use stronger blur and layered highlights/shadows for
  a more dimensional translucent look.

## 2026-05-17 - Shell Glass Unification

- Added shared shell-glass fill and border helpers for the Windows UI shell.
- Top band, left sidebar, and content header now use the same material recipe
  with only small emphasis differences.
- The songs panel was adjusted toward the same family so the whole app shell
  reads as one coherent glass system.

## 2026-05-17 - Glass Content Hierarchy

- Added shared contrast helpers for text placed on glass surfaces.
- Top bar, sidebar, pills, badges, empty states, and playlist text were updated
  to use a more consistent primary/secondary/tertiary hierarchy.
- Shared button sizing and label weight were tightened so controls feel more
  consistent across the Windows glass shell.

## 2026-05-17 - Accent Contrast Fixes

- Windows theme primary now follows `palette.accent` with a luminance-aware
  `onPrimary` color.
- High-visibility controls and labels no longer rely on dark palette hues as
  direct foreground text colors.
- This improves readability for difficult themes such as black and other very
  dark palette variants.

## 2026-05-17 - Multi-Theme Contrast Sweep

- Added shared contrast helpers for solid accent surfaces and for accent text
  shown on dark glass, so the Windows UI stops mixing those two cases.
- Updated scenery status labels, bottom now-playing status text, playlist add
  chips, selected-state pills, and active row icons to use palette-aware glass
  foreground colors.
- Added automated palette contrast coverage to catch unreadable accent text and
  `onPrimary` regressions before release.

## 2026-05-17 - Playback Mode Persistence

- The Windows player now stores the last selected playback mode in the local
  Heni config file.
- Restoring the app rehydrates `repeatMode` and `shuffle` from that saved mode,
  so sequence, list loop, single loop, and random all come back automatically.
- Added a controller-level regression test for playback-mode restore.

## 2026-05-17 - Volume And Window Restore

- The Windows player now stores the last volume in the local Heni config and
  reapplies it during startup.
- Volume persistence is debounced so the config file is not rewritten on every
  tiny drag update.
- The Windows runner now remembers the last window position, size, and
  maximized state and restores them on the next launch.

## 2026-05-17 - Structure Refactor Round 1

- The Windows top bar now behaves as a global work bar with search, palette
  controls, scope counts, and settings instead of housing the main mode switch.
- The left sidebar now treats `曲库` and `当前播放列表` as first-level browsing
  destinations, with user playlists grouped underneath.
- The `歌曲 / 播放中` switch moved into the content header, so playback stage vs.
  songs view is now framed as a content-mode decision rather than a global shell
  tab.
- The active songs view now understands the playback queue as its own context,
  with dedicated copy and empty-state behavior.

## 2026-05-17 - Content Workspace Round 2

- The Windows songs workspace now exposes list-level search feedback and a sort
  selector for queue order, title, type, and source.
- Added a duration column to the songs table with tabular time formatting so
  the list reads more like a real media workspace.
- The current playback queue now behaves more like a dedicated queue page,
  including queue-specific copy and a direct return path to the playback stage.

## 2026-05-17 - Adaptive Header And Resize Stability

- The Windows content header now switches to stacked layouts before narrow
  widths become unsafe, so playlist/library headers no longer try to force all
  pills, actions, and mode controls into one row.
- The songs workspace toolbar now wraps and stacks intelligently during resize,
  which removes common overflow pressure from search, selection, and sort
  controls.
- The bottom player bar now auto-enters its compact variant on narrower window
  widths, improving resize stability without requiring manual focus mode.
- Theme swatch selection was simplified to a steadier dot treatment, so the
  palette picker feels calmer and avoids small selection-size jitter.

## 2026-05-17 - Visual Hierarchy And Glass Quieting

- The Windows top shell was quieted by slightly reducing its height, padding,
  and emphasis, with a calmer focus treatment in the global search field.
- The songs workspace panel now uses the shared shell-glass recipe, which makes
  the right content area feel more like part of the same material system.
- The library hero banner was softened through lighter gradients, gentler
  shadows, and a less dominant title/icon treatment.
- Chips and metadata pills now use lighter fills and borders, improving content
  hierarchy inside the glass UI without hurting readability across themes.

## 2026-05-17 - Sidebar/Table Balance And Bottom Density

- The Windows sidebar was quieted further through softer edge glow, lighter
  section headers, calmer playlist-tile hover/selected states, and subtler
  count badges.
- The songs table header gained slightly clearer spacing and contrast so the
  main content side reads with more confidence against the quieter sidebar.
- The bottom player now uses a tighter now-playing summary, more restrained
  secondary text, smaller transport emphasis, and denser utility spacing.

## 2026-05-17 - Final Spacing Calibration

- The Windows sidebar now uses more even section spacing between browse,
  playlists, and status areas, which improves overall shell rhythm.
- Songs-table rows were tuned with slightly calmer spacing, softer highlight
  treatment, and cleaner internal alignment.
- The bottom progress area now uses subtler time labels, a slimmer track, and
  a lighter hover thumb for a more refined footer presentation.

## 2026-05-17 - Windows Visual QA Sweep

- Performed a Windows screenshot-based visual QA pass across wide, medium,
  compact, and narrow window sizes.
- The current adaptive shell remained stable during the sweep with no new
  overflow issues observed in the inspected desktop sizes.
- Narrow-width review exposed one last density issue in the top shell, so the
  quiet-layout search placeholder was shortened to `搜索歌曲或路径`.

## 2026-05-17 - Sidebar Centering And Row Breathing

- Re-centered the left-sidebar playlist tile content so the icon/title group
  sits more comfortably on the tile’s vertical middle.
- Added a little more horizontal breathing room between the songs-table media
  icon cluster and the track title block.

## 2026-05-24 - Modal Action Re-entry Guard

- Added an app-level modal action guard so repeated clicks on `添加歌曲` no
  longer open multiple add-from-library dialogs.
- The same guard now protects other Windows modal/file-picker actions, including
  adding files, importing folders, changing scenery images, exporting audio,
  playlist edit flows, and the playback queue dialog.
- File pickers that were missing `lockParentWindow` now set it, reducing stray
  native picker behavior around the Heni window.

## 2026-05-25 - Duration Metadata And Songs Panel Refinement

- Windows library metadata now persists detected media durations in the local
  Heni config and restores them into visible library/playlist rows.
- Library import, folder scan, restore, and refresh now trigger background
  duration inspection for missing durations, so unplayed songs can still gain
  stable duration values.
- Duration updates discovered during playback or background probing are written
  back to the local config.
- The right-side songs panel was tightened with lighter glass, smaller toolbar
  spacing, a more compact table header, and denser song rows.

## 2026-05-25 - White Theme Contrast And Quiet UI Direction

- The Windows white palette now uses a soft sage accent instead of pure white,
  improving filled-button and state-icon visibility while keeping the clean
  white-theme feel.
- Palette swatches and high-frequency controls now use explicit readable
  foreground colors instead of relying on default icon contrast.
- Added automated contrast coverage to prevent the white palette from regressing
  to unreadable pure-white control states.

## 2026-07-16 - Playback Quality And Desktop Shell Overhaul

- Audited the Windows playback path and confirmed that local media is opened
  directly by `media_kit`; FFmpeg remains limited to inspection/export work.
- Made the neutral player configuration explicit and kept pitch manipulation
  and startup mute disabled.
- Removed playback-position-driven full-window background rebuilds and reduced
  full-screen blur, glow, hover movement, and decorative animation load.
- Added visible codec, bitrate, sample-rate, lossless, and low-bitrate source
  hints so web-downloaded MP4/AAC quality is easier to identify.
- Rebuilt the Windows shell with a flatter header, responsive icon rail, quieter
  playlist workspace, denser song rows, and a fixed bottom playback dock.
- Performed DPI-aware screenshot QA at full desktop and compact window sizes;
  the sweep caught and corrected an 8-pixel bottom-player overflow.

## 2026-07-16 - Playback Queue Locator And Utility Cleanup

- The Windows playback queue now centers the current track automatically when
  opened and exposes a dedicated `定位当前歌曲` button beside search.
- The locator handles long lazy lists with an estimated first scroll followed
  by exact row centering once the current row has been built.
- An active queue search is cleared only when it prevents the current track from
  appearing.
- Removed the bottom-player FLAC/audio export action and its full application and
  FFmpeg export path; FLAC and Opus files remain supported for normal playback.
- Confirmed the redesigned bottom utility group now contains queue, playback
  mode, and volume only.
- `flutter analyze` completed with no issues and the Windows Debug target built
  successfully.
- `flutter test` remains blocked before suite loading by local Flutter listener
  timeouts on `127.0.0.1`; no test assertion was reached.

## 2026-07-16 - DPI-Aware Minimum Size And Progress Resize Fix

- Added `WM_GETMINMAXINFO` handling so the full Windows player cannot shrink
  below a DPI-scaled `900 × 620` logical client area.
- The bottom progress display is now a focused component with a narrow fallback
  that preserves the seek track and suppresses time labels when they cannot fit.
- Hover and drag math no longer divides by a zero-width track, and tooltip
  positioning remains valid below 48 logical pixels.
- Added a repeatable PowerShell runtime check that requests `220 × 300` and
  verifies Windows clamps Heni to its minimum size.
- On the current 200% DPI monitor, the verified minimum outer window is
  `913 × 656`, with no progress/time overlap or Flutter overflow banners.

## 2026-07-16 - Mature Adaptive Sidebar Interaction

- The default Windows player now opens with a labeled 224-pixel expanded
  sidebar instead of incorrectly selecting the icon rail from window height.
- Added a 72-pixel compact rail with an explicit expand control, icon
  destinations, stable hit targets, and explanatory tooltips.
- Manual expanded/compact preference persists as `sidebarMode`; automatic
  narrow-window compaction remains transient.
- Width hysteresis enters compact at 1040 and releases at 1140, preventing
  repeated sidebar flicker during slow resize.
- When expansion is blocked by width, the expand control remains visible and
  explains that the window must be widened.
- The default 1280 × 720 layout now uses a compact bottom bar because of its
  vertical density, eliminating the 10-pixel overflow observed during the first
  expanded-sidebar QA capture.
- DPI-aware screenshots verified expanded, narrow compact, hysteresis compact,
  restored expanded, and manual compact states.

## 2026-07-16 - Studio-Matte Listening Console Release

- Replaced the default Windows outer frame with a captionless themed frame and
  integrated drag, minimize, maximize/restore, and close controls into Heni.
- Applied the selected scenery image and active palette across the entire
  player shell, with stronger treatment in playback and quieter treatment in
  the library.
- Added the responsive listening console:
  - current source title/path and real ffprobe metadata;
  - conservative lossless labeling;
  - next-track preview;
  - `定位当前曲目` and `打开文件位置`;
  - useful empty-state file/folder actions.
- Removed the remaining lyric state/UI and kept audio export absent.
- The queue dialog now sizes its internal list from the available dialog
  height. DPI-aware runtime QA caught a 93-pixel bottom overflow before this
  adjustment and confirmed it is gone afterwards.
- The captionless frame uses `WS_POPUP | WS_THICKFRAME | WS_MINIMIZEBOX |
  WS_MAXIMIZEBOX | WS_SYSMENU`. Release runtime style was `0x940F0000` with no
  `WS_CAPTION`.
- At 200% DPI, a requested `300 × 300` window was clamped to a DPI-aware
  `1824 × 1264` physical outer size, preserving the `900 × 620` logical client
  minimum.
- Custom Release maximize and restore clicks changed `IsZoomed` from false to
  true and back to false.
- Verified:
  - `flutter analyze`: no issues;
  - 8 pure-Dart file-action/queue-location tests: passed;
  - Windows Debug build: passed;
  - Windows Release build and launch smoke: passed.
- Release artifact:
  `build/windows/x64/runner/Release/heni.exe`,
  SHA-256
  `0BE51F746CF5460B59FC76A4EEF236B5FFC2F2AD166D0C60178D6B7322448DDD`.
- `flutter test` still fails before loading the suite because
  `flutter_tester` cannot connect to its listener at `127.0.0.1`
  (`SocketException`, Windows error 121). No widget-test assertion ran.

## 2026-07-17 - Panoramic Theme Canvas And Usability Finish

- Replaced the remaining layered gray shell impression with one edge-to-edge
  scenery canvas and semantic theme surfaces for chrome, rail, content, dock,
  hover, pressed, selected, border, and text roles.
- The selected scenery now visibly continues behind the custom title bar,
  navigation, library/playback workspace, and bottom transport dock. Playback
  and library modes use different veil strengths while keeping the same theme.
- Standardized the visible brand to lowercase `heni` and generated a matching
  five-frame Windows ICO (16, 24, 32, 48, and 256 pixels).
- Calibrated the expanded/compact sidebar transition for the `900 × 620`
  minimum-size shell: narrow widths force the compact rail and wider widths
  restore the labeled expanded rail with hysteresis.
- Preserved the seek track and separated time geometry throughout horizontal
  resizing; minimum-size runtime checks remain available in
  `tool/verify_windows_minimum_size.ps1`.
- Replaced the old volume bubble with a theme-matched horizontal popover that
  supports live adjustment, final-value persistence, mute/restore, percentage
  feedback, and wheel steps.
- Changed queue location so an active search filter is never silently cleared.
  A visible current item is centered and highlighted for 900 ms; a hidden item
  produces an explanatory filter message.
- Confirmed the panoramic work does not change the `media_kit` playback engine,
  FFmpeg filters, equalization, loudness, pitch, or source-path behavior.
- Verification in the feature worktree:
  - `dart test` pure-Dart subset: 8 tests passed;
  - `flutter analyze`: no issues;
  - Windows Debug and Release builds: passed;
  - Release minimum resize: `912 × 632` logical outer window;
  - Release style: `0x940F0000`, no `WS_CAPTION`;
  - custom maximize and restore clicks: passed;
  - DPI-aware wide, minimum-size, and volume-popover screenshots: no visible
    overflow banner or progress/time collision;
  - Release SHA-256:
    `C1270F3F074B23679D314EFC733EF2FA14BBACA311D537416327A75E38C7BE32`.
- `flutter test` was not reported as passing: the existing host loopback issue
  prevents the Flutter test harness from reaching assertions. The user approved
  the documented static-analysis/native-build exception for this delivery.
- The implementation was fast-forwarded into the normal workspace on
  `codex/player-usability-upgrade` at `1763aee`, then the normal workspace
  repeated the 8 pure-Dart tests, clean static analysis, Windows Release build,
  `912 × 632` minimum-size probe, captionless-style probe, and a complete
  DPI-aware screenshot check.
- Normal-workspace Release SHA-256:
  `E5EE75DE0F62F91EF09F004889C616071B6E938E9B1F2060815BA283E1375CE2`.
  The feature and normal outputs were built in different absolute worktree
  paths, so executable hashes are recorded separately; both were built from
  the same implementation commit.
