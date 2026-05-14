# Heni Request Log

This log records user requests, my interpretation, intended implementation, and
what was completed. Keep this file updated for every product or engineering
request that changes Heni.

## 2026-05-14 - Separate songs tab from library label

### User Request

- The intent was only to rename the top UI tab from "曲库" to "歌曲".
- The left sidebar should not become "歌曲 / 歌曲".
- The left-side library is the full local collection, while the top "歌曲"
  tab means the playlist/song-list view that includes the library and custom
  playlists.

### Understanding

- "歌曲" is a navigation/view label.
- "曲库" is a data collection label for all local media.
- These labels should remain separate in code and UI so renaming the top tab
  does not change library behavior or sidebar semantics.

### Should Do

- Keep `HeniUiStyle.library.label` as "歌曲".
- Restore the built-in library playlist name to "曲库".
- Rename the sidebar section heading to avoid duplicated "歌曲 / 歌曲" copy.
- Add a regression test that locks the distinction between the top songs tab
  and the local library collection.
- Run formatting, analysis, tests, Windows release build, and a launch smoke
  test.

### Done

- Kept the top UI style tab label as "歌曲".
- Restored the built-in all-media playlist name to "曲库".
- Renamed the left sidebar's first section heading to "本地音乐" so the first
  actual playlist item can clearly remain "曲库".
- Added a regression test that asserts the top "歌曲" tab and local "曲库"
  collection stay distinct.
- Verified with `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-14 - Stronger theme color and volume state

### User Request

- The vertical volume control still does not look good enough.
- Volume adjustment appears to start from 100% every time.
- Theme color changes are not visually obvious enough.
- Add black and white color swatches; the UI may be too opaque or too similar
  across palettes.

### Understanding

- The volume UI needs both better visual polish and a real current-volume
  starting point instead of a hard-coded 100% placeholder.
- Theme selection should affect larger UI surfaces, not only small controls, so
  switching colors feels meaningful.
- Black and white should be first-class choices in the palette strip.

### Should Do

- Cache and expose the playback engine's current volume so the slider opens at
  the real value.
- Replace the rotated Material slider with a custom bare vertical control that
  has a clearer active bar and thumb.
- Add black and white palettes.
- Apply the active palette more visibly to the top bar, sidebar, selected
  playlist rows, bottom bar, and utility controls.
- Run formatting, analysis, tests, Windows release build, and a launch smoke
  test.

### Done

- Added black and white palettes to the top color selector.
- Exposed a cached `currentVolume` from the playback engine and used it as the
  volume button/slider starting point instead of a hard-coded 100%.
- Replaced the rotated Material volume slider with a custom bare vertical
  control: colored active rail, larger hit area, and visible thumb.
- Expanded palette tinting to the top bar, sidebar, selected playlist rows,
  bottom bar, current-media tile, and utility control group.
- Verified with `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-14 - Solid swatches and bare volume slider

### User Request

- The top UI color blocks still do not read well as gradients; stop using
  gradient swatches and use simple solid color blocks instead.
- The speaker volume control should not open a colored/layered mini panel.
- Remove the extra Chinese prompt, percentage text, and background from the
  volume popup; keep only the control bar.

### Understanding

- The palette selector should be more direct and less decorative: a row of
  clean solid color choices.
- Volume should behave like a lightweight control attached to the speaker icon,
  with no visible settings-card treatment.

### Should Do

- Replace gradient palette chips with pure solid swatches.
- Make the swatch color match the vertical volume slider color.
- Strip the volume popup down to a transparent anchor containing only the
  vertical slider.
- Run formatting, analysis, tests, Windows release build, and a launch smoke
  test.

### Done

- Replaced the top palette gradients with simple solid color swatches.
- Matched the bare volume slider color to the selected swatch color.
- Removed the volume popup panel treatment, prompt text, percentage label, and
  inactive track background.
- Verified with `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-14 - Playlist menu, typography, lyrics, vertical volume

### User Request

- Adjust the left "我的歌单" list: each playlist item should have a vertical
  three-dot menu with rename, delete, description, and any other useful options.
- Rename the top "曲库" UI tab to "歌曲".
- Remove the black dot from the top color blocks.
- Unify Chinese and English typography, for example with Microsoft YaHei.
- Try showing lyrics, preferably around the right-middle/bottom area.
- Change volume into a vertical, colored 100% control that matches the selected
  palette color and is easier to adjust.

### Understanding

- Playlist management should move toward a mature-player interaction model:
  menus for secondary actions, descriptions as playlist metadata, and direct
  add-from-library actions.
- The UI should keep the existing dark style but reduce visual clutter and make
  interactive controls feel intentional.
- Lyrics can start with local same-name `.lrc` or `.txt` files and should be
  displayed gracefully even when no lyrics are found.

### Should Do

- Add playlist description to the model and JSON persistence.
- Add rename, edit description, delete, and add-from-library actions to the
  playlist item menu.
- Rename the top library tab to "歌曲" and clean up related visible copy.
- Remove the dark dot inside palette swatches.
- Set a unified font family in the app theme.
- Add a lightweight lyrics loader/parser and display panel.
- Restyle volume as a vertical palette-colored slider in a compact popup.
- Run analysis, tests, Windows release build, and a launch smoke test.

### Done

- Added playlist description to the domain model and local JSON persistence.
- Added a three-dot menu on user playlists with add-from-library, rename, edit
  description, and delete actions.
- Renamed the top library tab to "歌曲" while keeping "从曲库添加" for the
  add-from-library action.
- Removed the dark dot from palette swatches.
- Set the app font family to Microsoft YaHei with common desktop fallbacks.
- Added local lyric loading for same-name `.lrc` and `.txt` files and a compact
  lyric panel over the scenery stage.
- Restyled volume as a compact vertical popup slider using the current palette
  accent color.
- Added controller coverage for playlist rename and description persistence.
- Verified with `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-14 - Richer swatches and cleaner bottom bar

### User Request

- The top color blocks appear to have no color; make them actually colorful and
  richer.
- The bottom UI looks messy and not polished enough.
- The volume popup is not attractive, simple, or lively enough.
- Keep the UI style unified while making it feel more lively.

### Understanding

- The current palette selector is too subtle; the swatches need stronger visual
  signal and clearer selected state.
- The bottom bar needs clearer zones and alignment, with secondary controls
  grouped instead of scattered.
- Volume should remain icon-first, but the popup should look like a compact
  designed control instead of a raw menu.

### Should Do

- Redesign top palette swatches with visible gradient color chips and selected
  glow/ring.
- Re-layout the bottom bar into left now-playing, center transport/progress,
  and right utility cluster.
- Restyle the volume popup with a rounded floating surface, concise label, and
  tidy slider.
- Preserve current playback behavior and verify with analysis, tests, Windows
  release build, and a launch smoke test.

### Done

- Reworked top palette chips into visible gradient swatches with selected glow,
  a brighter multi-color body, and a subtle inner highlight.
- Reorganized the bottom bar into a cleaner left/center/right layout: current
  media on the left, playback/progress in the center, and a compact utility
  cluster on the right.
- Grouped playback mode, volume, and export into a single rounded utility
  surface.
- Restyled the volume popup as a compact rounded floating panel with a label,
  percent readout, and slider.
- Kept the UI style consistent with the existing dark, restrained player look
  while adding more motion and visual feedback through animated swatches and
  icon state changes.
- Verified with `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-14 - UI palette, playlist add flow, compact bottom bar

### User Request

- Maintain a stable development log for each user request: the request, the
  understanding, what should be done, and what was actually done.
- Make the top color selector richer and more useful for choosing UI color
  styles.
- In a newly created playlist, provide a clear way on the right side to add
  songs from the library.
- Compact the bottom bar: playback mode should be icon-only, volume should be
  speaker-only and reveal a slider on click, and mode/volume should move to the
  right.
- Further simplify and polish the layout.

### Understanding

- Heni should behave more like a mature local music player: the library is the
  source of truth, playlists reference library songs, and playlist pages should
  offer a direct "add from library" flow.
- Palette selection should remain quick from the top nav, but the presets need
  more visual richness and variety.
- The transport area should prioritize playback controls and progress, while
  secondary controls move to the right as compact icon actions.

### Should Do

- Create and maintain this request log.
- Add more preset palettes and redesign the top palette chooser as a richer
  swatch strip.
- Add a playlist-page action that opens a library selection dialog and adds
  selected songs to the active playlist by path reference.
- Convert playback mode and volume to icon-only right-side controls; show the
  volume slider in a popup menu anchored to the speaker icon.
- Run analysis, tests, Windows release build, and a launch smoke test.

### Done

- Created `logs/request-log.md` and updated `logs/README.md` so request logging
  remains part of the project workflow.
- Expanded the palette preset set and redesigned the top palette chooser as a
  compact multi-segment swatch strip.
- Added a playlist-page "从曲库添加" flow with search, multi-select, and bulk add
  from the library into the active playlist by path reference.
- Kept row-level "加入歌单" in the library for quick one-song additions.
- Moved playback mode and volume to the right side of the bottom bar as
  icon-only controls.
- Changed volume into a speaker icon that opens a popup slider on click.
- Removed playback mode text from the bottom bar; the icon tooltip still shows
  the current mode.
- Verified with `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.
