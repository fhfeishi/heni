# Heni Player Usability Upgrade Design

## Status

Approved design for Heni's next usability-focused Windows release.

This specification incorporates the previously approved integrated title-bar
design in
`docs/superpowers/specs/2026-07-16-integrated-window-titlebar-design.md`.
Where the documents overlap, this specification defines the product scope and
the title-bar specification defines the detailed non-client window behavior.

## Product Direction

Heni is a personal local music player. The release should optimize for:

1. Fast access to the current song and playback queue.
2. A dependable full player and a genuinely useful MiniPlayer.
3. Clear, durable playback controls with no cramped responsive states.
4. An immersive scenery background that preserves readability and performance.
5. Direct, neutral playback without unnecessary audio processing.

The release should not compete with streaming services through recommendations,
social features, lyrics, or decorative feature volume.

## Design References

The design follows mature player patterns without copying their visual identity:

- Apple Music for Windows uses a dedicated MiniPlayer that retains progress,
  volume, and the upcoming queue while occupying little screen space.
- Apple Music and Spotify expose the queue as a directly manageable playback
  surface with reordering and removal.
- Heni keeps these interaction principles but retains its scenery-driven visual
  identity and local-file focus.

Reference documentation:

- https://support.apple.com/en-ca/guide/music-windows/mus71d7dcfce/windows
- https://support.apple.com/en-ie/guide/music-windows/musb1e6d1c76/windows
- https://support.spotify.com/gm/article/play-queue/

## Scope

### Included

- Integrated custom Windows title bar.
- Minimum size for the full player.
- Dedicated MiniPlayer mode with optional always-on-top behavior.
- Current-track location and follow-playback controls in the queue dialog.
- Queue reordering and confirmed queue clearing.
- Responsive progress presentation with no time-label overlap.
- Redesigned bottom utility controls and volume interaction.
- Full-window adaptive scenery background.
- Removal of lyrics and audio-export UI/application logic.
- Keyboard shortcuts.
- Open-containing-folder and copy-path song actions.
- Targeted decomposition of the oversized player presentation file.

### Excluded

- Lyrics display or lyrics-file parsing.
- Converting lossy audio into FLAC or another lossless format.
- Equalizers, pitch processing, automatic gain, loudness normalization, or
  ReplayGain.
- Crossfade, DJ transitions, recommendation engines, streaming integrations,
  social features, or online metadata services.
- A second playback engine or duplicated playback state for MiniPlayer.

## Window Modes

### Full Player

- Minimum logical size: `900 × 620`.
- The Win32 runner enforces the minimum through DPI-aware
  `WM_GETMINMAXINFO` handling.
- The full player retains the library, playlists, scenery view, queue access,
  and complete bottom playback bar.
- Window geometry continues to be persisted.

### MiniPlayer

- Default logical size: `620 × 190`.
- Minimum logical size: `560 × 180`.
- Height remains compact; width may grow while preserving the same information
  hierarchy.
- Shows:
  - artwork or Heni fallback disc;
  - title and source-quality summary;
  - previous, play/pause, and next;
  - responsive progress and compact time display;
  - queue, playback mode, volume, always-on-top, and return-to-full-player
    controls.
- Does not show the library, sidebar, search, lyrics, video surface, or playlist
  management.
- Can be toggled from the bottom bar, the integrated title-bar menu, or by
  selecting the now-playing artwork.
- Remembers its own normal position and size independently from the full player.
- Always-on-top is optional and persisted.

### Shared Playback State

Switching window modes changes only the presentation and window geometry.
`MediaKitPlaybackEngine`, the current queue, current index, position, volume, and
playback mode remain the same instances. No media file is reopened as part of a
mode change.

## Integrated Windows Frame

- Remove the white native caption.
- Place minimize, maximize/restore, and close buttons at the far right of Heni's
  existing top navigation in full-player mode.
- Use the MiniPlayer's compact top edge for drag and window controls.
- Preserve drag, double-click maximize/restore, edge/corner resize, taskbar
  activation, `Alt+F4`, DPI changes, and monitor work-area behavior.
- Use quiet hover states for minimize/maximize and a restrained red hover state
  for close.
- Do not duplicate the app icon or `heni` title outside the player surface.

## Playback Queue

### Locate Current Track

The current-playlist dialog receives a persistent `ScrollController` and a
current-row anchor strategy.

- Opening the queue initially centers the current track when no queue search is
  active.
- An always-visible `定位当前歌曲` button in the queue toolbar re-centers the
  current queue index at any time.
- If the current item is filtered out, locating clears the queue search first.
- If there is no current queue item, the action is disabled.
- The current row uses a clear theme-accent marker without changing its height.

### Follow Playback

- A `跟随播放` toggle is stored as a lightweight UI preference.
- While enabled and the dialog is open, a current-index change automatically
  scrolls the new current row into view.
- Manual scrolling is allowed; following resumes only on the next track change.

### Queue Management

- When no search filter is active, queue rows can be reordered by drag and drop.
- Reordering updates the queue and current index without reopening the track.
- Individual removal remains available.
- `清空待播队列` requires confirmation.
- Clearing upcoming items keeps the current track playing and reduces the queue
  to that track. When nothing is playing, it clears the queue completely.
- Search remains available but disables reordering until cleared.

## Bottom Playback Bar

### Structure

- Left: artwork, title, codec/bitrate/sample-rate summary.
- Center: previous, play/pause, next, and progress.
- Right: queue, playback mode, volume, and MiniPlayer.
- Audio export is removed from the permanent controls.
- Open-containing-folder and copy-path actions move to the song/now-playing
  context menu.

### Responsive Progress

The progress component has three explicit layouts:

1. Wide: current time, slider, total time.
2. Compact: slider plus a combined `current / total` label.
3. MiniPlayer: slider on its own row, compact time text below it.

The component switches layouts based on the width it actually receives rather
than global window breakpoints. Time regions use fixed reserved widths and the
slider never paints beneath them.

### Volume

- Clicking the speaker toggles mute and restores the last non-zero volume.
- Clicking the percentage/expander opens a compact horizontal volume surface.
- The surface contains a slider and an exact percentage.
- Mouse-wheel input over the volume cluster adjusts by two percentage points per
  notch.
- Keyboard volume shortcuts adjust by five percentage points.
- The popover automatically aligns inward at narrow window edges.
- Volume remains clamped to `0–100` and persists through the existing queue
  preference flow.

## Adaptive Full-Window Background

The scenery image becomes a single root-level visual layer behind the complete
application shell.

### Library And Playlist Views

- Use a stronger dark overlay and moderate blur.
- Panels use quiet translucent surfaces with enough opacity for text and row
  contrast.
- Theme color remains limited to active playlist, current track, playback
  state, and primary actions.

### Scenery Playback View

- Reduce blur and overlay strength to reveal more image detail.
- Keep media information and controls readable through localized gradient
  protection.
- Video playback remains inside its dedicated video surface; the scenery
  background does not replace or obscure it.

### Performance

- Render only one full-window image layer and one primary overlay.
- Avoid stacking multiple full-screen `BackdropFilter` layers.
- Cache decoded images at a resolution appropriate for the current window and
  DPI instead of always decoding at original size.
- Background changes use a restrained crossfade and do not subscribe to
  playback position.
- Missing or invalid image files fall back to the active theme gradient.

## Feature Removal

### Lyrics

Remove:

- lyrics provider/state;
- `.lrc`/`.txt` discovery and parsing;
- lyrics loading on media changes;
- lyrics panel widgets;
- playback-position subscriptions used only for synchronized lyrics.

No empty lyrics toggle or placeholder remains.

### Audio Export

Remove the audio-export feature from the player completely:

- FLAC/Opus extraction entry points;
- export dialogs;
- export progress/cancel controls;
- `AudioExportController` wiring that exists solely for the player UI.

FFmpeg media inspection remains. Audio-extraction requests, codecs, controller
paths, dialogs, and tests with no remaining consumer should be deleted rather
than hidden. No replacement "lossless conversion" action is introduced.

## Practical Additions

### Keyboard Shortcuts

When focus is not inside a text-editing control:

- `Space`: play/pause.
- `Left` / `Right`: seek backward/forward five seconds.
- `Ctrl+Left` / `Ctrl+Right`: previous/next track.
- `Ctrl+Up` / `Ctrl+Down`: volume up/down five percentage points.
- `Ctrl+Shift+M`: enter or leave MiniPlayer.
- `Q`: open the playback queue.

Shortcuts must not intercept typing or text-selection behavior in search fields.

### Local File Actions

Song and now-playing context menus add:

- `打开所在文件夹`, selecting the file when Windows supports it;
- `复制文件路径`.

Missing files disable or fail these actions with a concise non-blocking status
message.

## Architecture

### Windows

Extend the existing runner instead of adding a second window-management
dependency:

- captionless resizable window styles;
- DPI-aware minimum-size enforcement;
- non-client resize/hit testing;
- platform channel for minimize, maximize/restore, close, drag, MiniPlayer mode,
  always-on-top, geometry, and maximized state;
- separate persisted geometry for full and mini modes.

### Flutter Services

Add a focused Windows window controller that:

- wraps platform-channel calls;
- exposes full/mini mode, topmost state, and maximized state;
- degrades safely on non-Windows platforms or channel failure.

### Flutter Presentation

Extract bounded components from `player_screen.dart`:

- `player_window_shell.dart`;
- `global_scenery_backdrop.dart`;
- `bottom_player_bar.dart`;
- `mini_player.dart`;
- `playback_queue_dialog.dart`.

Each component receives playback/queue state through existing Riverpod providers
or narrow callbacks. No duplicate player or queue state is introduced.

### Application State

Extend queue/controller behavior with explicit operations:

- reorder queue item;
- clear queue;
- preserve current item/index across reorder;
- expose current-index changes to the queue dialog.

Persist only durable preferences:

- follow playback;
- MiniPlayer always-on-top;
- full and mini geometry;
- existing volume, palette, and shell preferences.

Transient dialog search and manual scroll position are not persisted.

## Error Handling

- A missing current track disables locate/follow behavior.
- A filtered current track is recovered by clearing the filter before locating.
- Invalid background images fall back to the theme gradient.
- Window-channel failures fall back to full-player presentation without stopping
  playback.
- MiniPlayer geometry outside the available monitor area is clamped to the
  nearest work area.
- Queue reorder and removal maintain a valid current index and playback order.
- Missing local files produce a non-blocking message; no destructive library
  cleanup occurs automatically.
- Volume restoration uses the last non-zero value, defaulting to a safe value
  when unavailable.

## Implementation Phases

1. Extract window shell and implement integrated title bar, minimum sizing, and
   MiniPlayer.
2. Add queue locate/follow/reorder/clear behaviors.
3. Extract and redesign bottom playback bar, responsive progress, and volume.
4. Move scenery to the root and implement adaptive background treatments.
5. Remove lyrics and player audio-export code.
6. Add shortcuts and local-file actions.
7. Run regression, build, interaction, DPI, and screenshot verification.

Each phase should leave the project buildable and should be verified before the
next phase begins.

## Verification

### Automated

- Playback queue tests for reorder, current-index preservation, removal, and
  clearing.
- Window-controller tests for state transitions using a mocked method channel.
- Progress-layout widget tests at wide, compact, and MiniPlayer widths.
- Volume tests for mute restoration, clamping, and step changes.
- Static analysis.
- Windows Debug build.

### Manual Windows QA

- Full player cannot shrink below `900 × 620`.
- MiniPlayer cannot shrink below `560 × 180`.
- Switching modes does not pause, reopen, or seek the current track.
- Full and mini geometry restore on the correct monitor.
- Always-on-top toggles correctly.
- Drag, double-click maximize, resize, minimize, maximize/restore, close, and
  `Alt+F4` work.
- Queue locate, follow, reorder, remove, and clear work with and without search.
- Progress times never overlap the slider or each other.
- Volume click, mute restore, popover, wheel, keyboard, and persistence work.
- Search fields retain normal keyboard behavior.
- Global background covers the complete shell and remains readable in library
  and scenery modes.
- Lyrics and audio-export controls and background tasks are absent.
- Wide, compact, minimum-full, MiniPlayer, and high-DPI screenshots contain no
  overflow, clipping, duplicated title bar, or unreadable controls.
- User-owned running Release processes are not terminated during verification.

## Success Criteria

The release is successful when Heni feels like one coherent Windows music
player rather than a full interface compressed into arbitrary window sizes:

- the current song is always easy to find;
- opening the queue or pressing its locate button immediately reveals the
  current song;
- the queue is directly manageable;
- full and mini modes are intentionally designed;
- progress and volume remain clear at every supported size;
- scenery supports the whole interface without dominating it;
- the player performs no misleading audio conversion or unnecessary playback
  processing;
- lyrics and audio-export controls or background tasks no longer consume
  attention or resources.
