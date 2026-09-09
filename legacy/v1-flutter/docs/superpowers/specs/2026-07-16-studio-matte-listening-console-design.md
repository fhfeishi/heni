# Heni Studio Matte Listening Console Design

## Status

Approved on 2026-07-16 after visual comparison.

This specification extends:

- `2026-07-16-integrated-window-titlebar-design.md`;
- `2026-07-16-player-usability-upgrade-design.md`;
- `2026-07-16-adaptive-sidebar-design.md`.

Where the documents overlap, this specification defines the approved visual
direction and playback-stage information hierarchy. The earlier specifications
continue to define queue behavior, minimum sizing, and adaptive-sidebar
behavior.

## Goal

Make Heni feel like one coherent themed Windows music player instead of a
Flutter surface inside a default system frame. The playback page should become
a practical local-audio console that remains calm during long listening
sessions while exposing trustworthy source-quality information.

## Approved Direction

The selected direction combines:

- `录音室哑光`: stable, low-glare, information-first surfaces;
- `深度染色`: the active Heni palette visibly affects the outer frame, bars,
  panels, and background treatment;
- `播放控制台`: the static playback panel shows current media, actual inspected
  audio properties, upcoming media, and useful local-file actions;
- no lyrics surface or lyrics background work.

## Theme Mapping

Every existing `HeniPalette` continues to provide:

- `seed`: atmospheric tint and selected-surface color;
- `surface`: root matte base;
- `surfaceAlt`: title bar, sidebar, bottom bar, and raised-panel base;
- `accent`: progress, primary action, active navigation, and status emphasis;
- `glow`: restrained full-window ambient tint.

Deep tint does not mean placing the raw seed color behind all text. Theme
mapping follows these limits:

- Root and major bands blend the palette surface with seed at approximately
  `8–18%`.
- Raised panels blend `surfaceAlt` with seed at approximately `6–14%`.
- Decorative glow may reach `24%` opacity only in broad radial gradients.
- Text-bearing surfaces retain enough black or palette surface to meet readable
  contrast.
- `accent` is used directly only for small active controls, progress, and
  badges.
- Highly saturated palettes such as 柑橘, 珊瑚, 红宝, and 极光 use the same
  blending limits rather than custom one-off colors.
- The close button remains neutral normally and uses restrained red only on
  hover or press.

## Integrated Outer Frame

Windows uses a captionless resizable native window while preserving:

- taskbar and system-menu behavior;
- minimize, maximize/restore, close, and `Alt+F4`;
- edge and corner resize;
- DPI-aware `900 × 620` minimum full-player size;
- monitor work-area-aware maximize behavior;
- persisted normal geometry.

Flutter places the three window controls at the far right of the existing top
navigation. The top band itself is the drag surface:

- dragging an unoccupied top-band area moves the window;
- double-clicking the drag surface toggles maximize/restore;
- search, palette, settings, and window buttons never start dragging;
- maximize icon changes to restore when maximized;
- all three buttons remain visible at minimum width;
- the top bar uses the active palette's deeply tinted matte surface rather than
  a default Windows caption color.

The Windows runner exposes one narrow method channel:

- `minimize`;
- `toggleMaximize`;
- `close`;
- `beginDrag`;
- `isMaximized`.

It also notifies Flutter with `maximizedChanged` after native size-state
changes.

## Full-Window Background

The selected scenery image becomes the only full-window image layer behind the
complete shell.

- Playback view: moderate darkening, moderate desaturation, and lower blur so
  image character remains visible.
- Library and playlist views: stronger darkening, stronger blur, and deeper
  palette wash for row readability.
- No image: use a palette-derived matte gradient.
- Image changes crossfade slowly.
- Playback position does not drive the background.
- The content playback stage must not create a second full-window scenery image.

The root shell then places deeply tinted matte surfaces above this single
background layer:

- top navigation;
- adaptive sidebar;
- playback/library panels;
- bottom player.

## Listening Console

The audio playback stage uses a responsive `HeniListeningConsole`.

### Wide Layout

The primary panel contains:

- artwork or Heni vinyl fallback;
- `正在播放` state;
- media title;
- local source path;
- actual audio properties from `currentMediaProbeProvider`;
- `定位当前曲目`;
- `打开文件位置`;
- next-track preview.

Actual audio properties include available values only:

- codec/profile;
- bitrate;
- sample rate;
- channel count;
- lossless/high-bitrate quality tag where the existing probe logic can support
  it.

The console must never label a lossy MP4/M4A/MP3 source as lossless and must
never imply that playback converts the source to FLAC. A quiet note states that
Heni decodes the original source without application-level transcoding.

### Responsive Layout

- At `>= 1050` content width: artwork, media information, and right-side
  audio/next panels are visible.
- At `760–1049`: the right-side panels move below the main information or
  collapse into compact metadata chips.
- Below `760`: artwork and title remain; secondary path and next-track details
  hide before playback controls or progress.
- Existing adaptive sidebar behavior remains authoritative and may force the
  compact sidebar before the listening console reaches its narrowest state.
- No layout may overflow at the enforced `900 × 620` window minimum.

### Empty State

When nothing is selected, the same panel becomes a useful local-library start
surface:

- `选择文件`;
- `导入目录`;
- library item and directory counts;
- last scan state when available.

It must not display empty audio-quality or next-track cards.

### Video State

Video playback keeps the existing dedicated video surface. The listening
console's audio artwork layout is not placed over video. A compact media-info
block may remain below or beside the video without lyrics.

## Queue And File Actions

`定位当前曲目` opens the existing current-playback-list dialog. The dialog
already clears a blocking query and centers the current item, so the console
must reuse that behavior rather than implement a second scroll algorithm.

`打开文件位置`:

- uses Windows Explorer with the current media selected;
- is disabled when no media exists;
- reports a non-blocking status message if the path is missing or the action
  fails;
- does not remove missing files from the library.

The existing bottom queue control remains available.

## Lyrics Removal

Remove:

- `currentLyricsProvider`;
- lyric document, header, and line models;
- `.lrc`/`.txt` discovery and parsing;
- media-change lyric loading and clearing;
- `_LyricsPanel`;
- lyric-only playback-position subscriptions;
- lyrics parameters threaded through `PlayerScreen`, `_ContentArea`, and
  `_SceneryContent`.

No placeholder, toggle, or hidden lyric work remains.

## Motion And Interaction

- Major theme changes animate over `280–420 ms`.
- Hover transitions use `140–220 ms`.
- Background crossfades remain slow and calm.
- No panel continuously floats or pulses.
- The existing artwork/spectrum animation may continue only while playing.
- Secondary actions become clearer on hover but remain discoverable through
  tooltips.
- Window button hit targets are at least `42 × 38` logical pixels.

## Architecture

Create focused components instead of adding more private classes to the
already-large `player_screen.dart`:

- `services/window/heni_window_controller.dart`: platform-channel wrapper and
  maximized state;
- `features/player/presentation/player_window_chrome.dart`: drag surface and
  window buttons;
- `features/player/presentation/global_scenery_backdrop.dart`: one full-window
  image and adaptive treatment;
- `features/player/presentation/listening_console.dart`: responsive audio
  playback console;
- `services/files/local_file_actions.dart`: tested local-file shell actions.

`player_screen.dart` remains the composition root and passes narrow callbacks
and existing playback state into these components.

## Verification

### Automated

- Window-controller channel tests verify every method name and maximized-state
  notification.
- Window-chrome widget tests verify minimize, maximize/restore, close, and
  double-click behavior.
- Listening-console widget tests verify audio properties, queue locate, empty
  state, next-track selection, and narrow responsive behavior.
- Global-backdrop tests verify image/fallback selection and view-specific
  treatment.
- Local-file-action tests verify Explorer arguments and missing-path failure.
- Existing progress and adaptive-sidebar tests remain green.
- `flutter analyze` succeeds.
- `flutter test` succeeds.
- Windows Debug build succeeds.

### Manual Windows QA

- No native white title bar remains.
- Drag, double-click maximize, minimize, restore, close, `Alt+F4`, and all
  resize edges/corners work.
- Search, palette, settings, and window controls do not conflict with dragging.
- All existing palettes produce readable outer bands and controls.
- Playback and library views use one full-window scenery image.
- The listening console does not overflow at wide, compact, or `900 × 620`.
- MP4/M4A, MP3, and FLAC samples show accurate inspected properties.
- Queue locate opens centered on the current item.
- Lyrics never load or appear.
- User-owned running Release processes are not terminated during verification.
