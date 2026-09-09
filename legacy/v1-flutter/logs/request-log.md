# Heni Request Log

This log records user requests, my interpretation, intended implementation, and
what was completed. Keep this file updated for every product or engineering
request that changes Heni.

## 2026-05-16 - Queue panel polish and in-table multi-select interaction

### User Request

- Continue refining the current playback list overlay itself so it feels more
  polished.
- Improve the song-table multi-select interaction so it feels more unified and
  natural.

### Understanding

- The current playback list already works functionally, but it still reads more
  like a generic dialog than a premium playback-control surface.
- Multi-select feels better when it can happen inside the songs table itself,
  instead of always forcing the user into a separate management dialog.
- The visual language should stay consistent across queue control, song
  selection, and removal actions.

### Should Do

- Refine the current playback queue dialog with clearer hierarchy, richer
  summary information, and search.
- Bring multi-select directly into the non-library songs table, with a clear
  selection mode and batch removal controls.
- Keep quick single-song removal intact for lightweight editing.
- Verify with formatting, analysis, tests, Windows release build, and a launch
  smoke test.

### Done

- Upgraded the current playback queue dialog with source/count summary pills,
  current-track emphasis, and queue search.
- Added in-table multi-select mode for custom playlists, including select all,
  batch remove, selected-count feedback, and checkbox-driven row interaction.
- Kept row-level single-song removal for faster light edits outside selection
  mode.
- Adjusted the songs table layout so multi-select mode still feels balanced.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-16 - Queue row feel and table-state hierarchy polish

### User Request

- Continue refining the most visible two polish points.
- Improve the feel of the row-level buttons inside the current playback list.
- Unify the hierarchy between hover, now-playing selection, and multi-select
  states in the songs table.

### Understanding

- At this stage the product already works; the next gain comes from making row
  states feel intentional rather than merely functional.
- The songs table needs clearer separation between "currently playing",
  "hovered", and "checked for batch editing" so those states do not blur
  together.
- The current playback queue should use the same restrained action language as
  the rest of the player, instead of falling back to plain icon buttons.

### Should Do

- Refine songs-table row backgrounds, borders, leading icons, and selection
  labels so play-state and batch-selection state are both readable.
- Replace queue row icon buttons with calmer inline action buttons and add
  hover-aware row treatment there too.
- Keep behavior unchanged and verify with formatting, analysis, tests, Windows
  release build, and a launch smoke test.

### Done

- Rebalanced songs-table row styling so hover, currently playing, and checked
  states now have clearer but still restrained differences in fill, border,
  icon color, and metadata emphasis.
- Turned the in-table multi-select label into a compact capsule so checked rows
  read as intentionally selected, not just temporarily marked.
- Added a reusable inline action-button style and applied it to row-level
  remove/play actions for calmer control rhythm.
- Reworked current playback queue rows with hover-aware lift, stronger current
  item emphasis, and the new inline action buttons for cleaner row-level feel.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-16 - Unified shell breathing and dialog framing

### User Request

- Continue refining two product-finish details.
- Unify the sense of rhythm between the top navigation band and the bottom
  playback band.
- Revisit the dialog system so radius, border treatment, and spacing feel more
  consistent throughout the app.

### Understanding

- The top and bottom bars already worked individually, but they still needed to
  feel like they belonged to one shared shell language.
- Dialogs had gradually improved feature by feature, but they were still using
  slightly inconsistent framing and padding.
- The goal here is not to add more decoration, but to make the product feel
  more coherent through repeated structural cues.

### Should Do

- Introduce a shared band wrapper for the top and bottom shell surfaces.
- Apply the same panel rhythm to both areas so the overall window breathes more
  evenly.
- Introduce a shared dialog frame and migrate the main player dialogs onto it.
- Verify with formatting, analysis, tests, Windows release build, and a launch
  smoke test.

### Done

- Added a shared shell-band wrapper with matched glow, subtle entrance motion,
  and more consistent framing for the top navigation and bottom player bands.
- Unified the top and bottom shell feel so they now read more clearly as one
  connected product frame.
- Added a shared dialog scaffold and moved the main player dialogs onto the
  same inset, padding, and action spacing language.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-16 - Deeper shell alignment and theme-level dialog consistency

### User Request

- Keep refining the same two finish-quality areas.
- Continue unifying the breathing feel of the top and bottom shell bands.
- Continue unifying dialog radius, borders, and spacing so the system feels
  more complete.

### Understanding

- The previous pass aligned these areas visually, but the shell and dialog
  systems still benefited from a slightly deeper structural unification.
- The top and bottom bands should not only look similar; they should also use
  mirrored highlight logic so they feel like two ends of one frame.
- Dialog consistency becomes more durable when part of it lives in shared theme
  definitions, not only per-dialog wrappers.

### Should Do

- Refine the shared shell-band component with mirrored highlight placement for
  top and bottom roles.
- Extend theme-level dialog and popup styling so shared spacing and shape are
  reinforced globally.
- Keep the existing dialog wrapper, but make it work with the improved shared
  shell and theme language.
- Verify with formatting, analysis, tests, Windows release build, and a launch
  smoke test.

### Done

- Added top/bottom-aware highlight placement to the shared shell-band wrapper
  so the navigation band and playback band now behave more clearly as opposite
  ends of the same product frame.
- Added an internal hairline rhythm to those shell bands for stronger visual
  continuity.
- Refined the theme-level dialog and popup styling with more unified radius,
  tint handling, text styling, and menu padding.
- Kept the shared dialog wrapper in place so the player dialogs now benefit
  from both local layout consistency and stronger theme-level consistency.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-16 - Sidebar-to-content transition and palette-control refinement

### User Request

- Continue refining two details that strongly affect product quality.
- Improve the visual transition between the left sidebar and the main content
  area.
- Increase the precision and finish quality of the top theme-color selector.

### Understanding

- The sidebar and content area already had good individual surfaces, but the
  seam between them still felt slightly abrupt.
- The palette selector worked functionally, but it still felt closer to a row
  of swatches than to a carefully designed control.
- The next gain comes from making these areas feel connected and intentional,
  not from adding more features.

### Should Do

- Add a softer visual bridge between the sidebar surface and the main content
  region.
- Refine the sidebar's right-edge glow/transition so the layout feels less
  mechanically split.
- Turn the active theme area into a richer control with a clearer active-color
  preview and better swatch proportions.
- Verify with formatting, analysis, tests, Windows release build, and a launch
  smoke test.

### Done

- Added a dedicated sidebar bridge and right-edge transition glow so the left
  navigation area now eases into the main content more naturally.
- Refined the top palette deck with a richer active-theme preview and more
  deliberate separator/spacing rhythm.
- Refined palette swatch sizing and internal highlight treatment so the active
  color reads more clearly and the control feels more precise.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-16 - Finer information hierarchy in header, sidebar, and now-playing

### User Request

- Start refining more detailed information hierarchy.
- Improve the hierarchy of the songs-view header summary on the right.
- Improve the wording/spacing hierarchy of the left sidebar status text.
- Improve the weight and whitespace rhythm of the bottom now-playing
  information block.

### Understanding

- The app already has the right information, but some high-frequency surfaces
  still present it too flatly.
- These areas benefit most from clearer eyebrow/main/supporting tiers rather
  than from more content.
- The goal is to make the player feel calmer and more legible through rhythm,
  not to add new controls.

### Should Do

- Add a clearer eyebrow/title/supporting-text hierarchy to the songs-view
  header.
- Turn the sidebar's loose status copy into a more deliberate small status
  block.
- Rebalance the bottom now-playing text stack so playback state, title, type,
  and technical details read in a steadier order.
- Verify with formatting, analysis, tests, Windows release build, and a launch
  smoke test.

### Done

- Added a clearer eyebrow and supporting-text layer to the content header so
  library and playlist views read more like structured product summaries.
- Turned the sidebar footer status into a compact status card with clearer
  label/body separation.
- Reworked the now-playing text hierarchy so playback state leads, title lands
  more firmly, and media-type/supporting details breathe better underneath.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-16 - Unified motion feel for hover, theme change, and track change

### User Request

- Start refining more detailed dynamic feel.
- Unify the rhythm of list hover states.
- Add more delicate feedback when switching the top theme color.
- Make the bottom playback area feel smoother when the current track changes.

### Understanding

- The player already had motion in several places, but the durations and feel
  still varied enough to make the UI feel less cohesive than it could.
- The strongest next step is to treat hover, theme switching, and now-playing
  transitions as members of one shared motion language.
- This should stay restrained; the goal is steadier polish, not flashier UI.

### Should Do

- Introduce shared motion constants for hover and content transitions.
- Apply that motion language to the main interactive list surfaces.
- Refine the top theme control so theme changes feel more graceful.
- Lengthen and soften the bottom now-playing content transition.
- Verify with formatting, analysis, tests, Windows release build, and a launch
  smoke test.

### Done

- Introduced shared motion constants so hover-aware surfaces and content
  transitions now move with a more unified rhythm.
- Applied that motion timing across playlist tiles, song rows, queue rows, and
  related inline controls for steadier hover feel.
- Refined the top theme deck so palette changes use a smoother content switch
  and a more polished active-theme emphasis.
- Smoothed the bottom now-playing content transition with a slightly gentler
  slide/fade rhythm and more deliberate spacing around the text stack.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-16 - Final polish for icon density, table spacing, and scenery breathing

### User Request

- Begin the final-polish pass.
- Unify the visual density of button icons.
- Fine-tune table column widths and whitespace.
- Improve the last bit of breathing room between the scenery page's lower
  information block and the background.

### Understanding

- At this stage the player's main structure is solid, so the next improvements
  are mostly about density, spacing, and compositional lightness.
- Button icons should feel like they come from the same optical grid, rather
  than each control choosing its own weight and padding.
- Table layout quality depends heavily on restrained column widths and cleaner
  right-side action spacing.
- The scenery info block should remain readable while feeling less like a heavy
  overlay placed on top of the background.

### Should Do

- Normalize common icon-button sizes and icon sizes across transport and
  utility actions.
- Tighten the songs-table source/action widths to improve whitespace rhythm.
- Lighten and slightly re-space the scenery page's lower information block and
  its placement relative to the background.
- Verify with formatting, analysis, tests, Windows release build, and a launch
  smoke test.

### Done

- Introduced more consistent icon sizing and padding across bottom utility
  actions, transport controls, and inline row actions.
- Tightened songs-table column/action widths for a cleaner right-side rhythm.
- Lightened the scenery info block's surface, reduced its visual weight, and
  gave the lower composition a bit more breathing room against the background.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-16 - Pre-release consistency pass for labels, spacing, and Windows smoke

### User Request

- Start the final "pre-release check" style cleanup.
- Unify button-label density.
- Clean up a few remaining spacing inconsistencies.
- Do a Windows-oriented final visual/smoke pass.

### Understanding

- At this point the remaining gains are mostly about consistency rather than
  capability.
- High-frequency action labels should feel like they belong to one compact
  product language instead of mixing longer and shorter phrasings without need.
- A final Windows-side pass should at least confirm clean analysis/build state
  and a healthy launch, even if this environment does not provide a true pixel
  screenshot workflow for the native app window.

### Should Do

- Tighten the wording of the most visible primary/secondary action buttons.
- Keep layout untouched except where label consistency helps reduce visual
  noise.
- Re-run formatting, analysis, release build, and a Windows launch smoke test.

### Done

- Tightened several high-frequency action labels so the top action groups and
  playlist menu read with more even density, including `导入目录` and
  `添加歌曲`.
- Re-ran the Windows-side release verification and launch smoke as a final
  pre-release sanity pass.
- Verified with `dart format`, `flutter analyze`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-16 - Softer refresh feedback, playlist removal, and current queue controls

### User Request

- Make library refresh feel gentler, with better loading feedback and result
  feedback.
- Allow non-library playlists to remove one or multiple songs from the current
  list.
- Add a current playback list control to the bottom-right utility area, ordered
  ahead of playback mode, volume, and FLAC export.
- Let the current playback list support starting playback from a chosen song
  and removing songs from the queue.
- Continue making the overall UI feel more lively and product-like.

### Understanding

- Refresh feedback should feel like a calm product state, not just a plain text
  status string.
- Playlist editing needs two levels: quick single-song removal in the main
  list, and a clearer multi-select removal flow for curating a custom playlist.
- The current playback queue should be treated as a first-class surface rather
  than hidden controller state, with direct play/remove actions that do not
  confuse it with the browsing playlist.
- Bottom utility actions should stay compact, but the new queue entry should
  read as an important, high-frequency control.

### Should Do

- Refine the songs-header refresh feedback into a gentler badge treatment.
- Add row-level removal for user playlists and a dedicated dialog for removing
  multiple songs from a custom playlist.
- Add a bottom utility entry for the current playback list and back it with a
  queue dialog that can play a chosen item or remove it.
- Extend the playback queue controller so queue removal and queue-index play are
  real supported actions.
- Verify with formatting, analysis, tests, Windows release build, and a launch
  smoke test.

### Done

- Replaced the raw refresh-state feel with calmer animated refresh badges in
  the songs header, covering both active refresh and refresh/restore results.
- Added playlist-song management for custom playlists: row-level remove actions
  inside the songs table plus a dedicated multi-select "管理歌曲" dialog.
- Added a current playback queue control to the bottom-right utility group,
  ahead of playback mode, volume, and FLAC export.
- Added a dedicated current-playback-list dialog that can jump playback to any
  queued song and remove songs from the active queue.
- Extended the controller with user-playlist removal, queue-index playback, and
  queue-item removal behavior that advances cleanly when the current item is
  removed.
- Added controller tests covering playlist removal and current-queue removal.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-16 - Lyric follow feel and gentler library refresh feedback

### User Request

- Continue with the two most valuable long-term experience details.
- Improve the lyric panel so it feels better for following along when lyrics
  exist.
- Make library refresh feel gentler, with better loading feedback and clearer
  result feedback.
- Do nothing extra when no lyrics are present.

### Understanding

- "完整歌词体验" at this stage means the panel should feel more musical and
  less like a static debug surface when timed lyrics are available.
- Refresh feedback should feel like a calm product state, not just a raw
  status string hidden elsewhere in the app.
- If lyrics do not exist, the UI should stay quiet instead of inventing filler.

### Should Do

- Improve the lyric panel's active-line emphasis and visible context so the
  user can follow along more naturally.
- Surface lyric metadata when it exists.
- Add more visible, but still restrained, refresh-state feedback in the songs
  header area and settings flow.
- Keep the no-lyrics behavior quiet.
- Verify with formatting, analysis, tests, Windows release build, and a launch
  smoke test.

### Done

- Expanded lyric parsing to expose richer metadata in the panel header.
- Reworked the lyric panel into a more follow-friendly layout with more visible
  context lines, stronger active-line emphasis, and gentler depth for nearby
  lines.
- Added compact status pills in the songs header for refresh-in-progress and
  refresh-complete feedback.
- Added an immediate refresh action inside the settings dialog so scanning
  changes can be applied more directly.
- Kept no-lyrics behavior quiet by continuing to hide the lyric panel when no
  usable lyric lines are available.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-16 - Lyrics, richer persistence, and smoother library refresh

### User Request

- Start improving the three areas that will matter most for long-term
  experience: a more complete lyric experience, more complete settings
  persistence, and a smoother library scan/refresh flow.

### Understanding

- The existing lyric support could show lines, but it was still lightweight in
  structure and persistence was incomplete for the UI shell.
- Current scan settings were persisted, but theme choice, UI mode, and scenery
  images were not yet part of the same durable experience.
- A mature local player needs an explicit refresh flow so users can rescan
  their library without re-importing everything by hand.

### Should Do

- Upgrade lyric parsing to understand richer `.lrc` structure.
- Persist more shell-level preferences such as theme, UI mode, and scenery
  image selection.
- Add a real refresh-library flow that respects current scan settings and keeps
  playlists aligned with refreshed library items.
- Surface refresh actions in the UI where they naturally belong.
- Verify with formatting, analysis, tests, Windows release build, and a launch
  smoke test.

### Done

- Extended lyric parsing to support common `.lrc` metadata such as title,
  artist, album, and offset, and upgraded the lyric panel to use that richer
  document structure.
- Extended the main config file schema so shell-level preferences can also be
  persisted alongside library and playlist state.
- Restored saved theme, UI mode, and scenery image choices during startup and
  persisted them when users change those preferences.
- Added a dedicated refresh-library flow that rescans configured sources with
  current scan settings and rehydrates playlist references from refreshed
  library items.
- Added refresh entry points in the songs header and the settings dialog.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-16 - Top-nav motion and now-playing transition polish

### User Request

- Continue refining two final polish details with strong payoff.
- Add subtle motion to the top navigation.
- Improve the information transition in the bottom playback area when changing
  tracks.

### Understanding

- The top bar should feel lightly alive, not static, but the motion must remain
  restrained enough to fit the rest of Heni's calm UI language.
- The bottom now-playing area is a high-attention region, so abrupt text swaps
  during track changes make the player feel less premium than it already is.

### Should Do

- Add restrained motion and emphasis to the top navigation brand area.
- Improve the bottom now-playing summary so title and metadata transition more
  smoothly when the current media changes.
- Verify with formatting, analysis, tests, Windows release build, and a launch
  smoke test.

### Done

- Added a gentle top-navigation entrance scale and a slightly more alive brand
  treatment, including subtle palette-responsive emphasis.
- Made the top brand text respond more gracefully to palette changes with a
  soft animated switch.
- Added animated content transitions to the bottom now-playing summary so track
  title and metadata no longer swap abruptly during media changes.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-16 - Product-finish pass for settings, empty states, and scenery layout

### User Request

- Continue refining player-finish details such as a more product-like settings
  experience, more polished empty states, and bringing back a stronger lyric
  experience.
- Move the static center bubble in scenery playback toward the lower-right area
  so it sits with the now-playing and song-information region.
- Further optimize that playback scenery layout for a more lively feel.

### Understanding

- The scenery page's center orb was no longer helping composition; it should
  become part of the lower information cluster instead of competing with the
  background.
- "Finish quality" here means elevating supporting surfaces too: settings,
  empty states, and lyrics should feel intentionally designed rather than just
  functional.

### Should Do

- Recompose the scenery page so the orb and the lower media information form a
  unified bottom cluster.
- Upgrade settings from a simple popup into a more product-like settings panel.
- Improve empty states in the songs view.
- Refine the lyric panel when lyrics exist.
- Verify with formatting, analysis, tests, Windows release build, and a launch
  smoke test.

### Done

- Moved the scenery orb out of the center and integrated it into the lower
  playback composition beside the media information block.
- Turned the settings entry into a real settings dialog with clearer grouped
  toggles and current library summary information.
- Replaced the plain songs-view empty text with a more deliberate empty-state
  card.
- Refined the lyric panel with a heading and softer current-line emphasis.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-16 - Icon unification and playlist count display fix

### User Request

- Unify the Heni player icon using `D:\Ddesktop\tututu\zzicons\d.ico`.
- Continue refining playback-page unity, especially around video-mode rhythm.
- Review the right-side playlist/library information area because the playlist
  and library song counts looked incorrectly identical when switching between
  them.

### Understanding

- The Windows app icon should be made consistent with the provided `.ico`
  asset.
- The count issue is likely a UI-state bug rather than a data corruption issue,
  because the switching logic itself still appeared to work.
- The playback page can keep improving through small spacing and balance
  adjustments in video mode.

### Should Do

- Replace the Windows runner icon with the provided `.ico` file.
- Audit the right-side content header count logic and make sure custom
  playlists show their own item counts while the library shows library-wide
  counts and directory information.
- Slightly refine video-mode left/right overlay spacing so the page feels more
  balanced.
- Verify with formatting, analysis, tests, Windows release build, and a launch
  smoke test.

### Done

- Replaced `windows/runner/resources/app_icon.ico` with the provided
  `D:\Ddesktop\tututu\zzicons\d.ico` asset for Windows builds.
- Fixed the right-side content header logic so only the real library view shows
  library-wide counts and directory totals; custom playlists now show their own
  song counts instead of mirroring the library count.
- Added a small "来自曲库" cue for custom playlists in the songs view.
- Nudged video-mode lower-left and lower-right overlay spacing so the info block
  and lyric block sit more comfortably together.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-16 - Scenery playback linkage and video/info balance

### User Request

- Continue refining two finer details.
- Add a sense of linkage between scenery/background state and the bottom
  playback status.
- Improve the spatial relationship between the lower-left info area and the
  lower-right lyric area in video mode.

### Understanding

- The player should feel like one coordinated surface: when playback is active,
  the scenery and bottom now-playing area should subtly breathe together.
- Video mode needs the same information quality as audio mode, but without
  letting the lower-left info block and lower-right lyric block crowd each
  other.

### Should Do

- Tie scenery ambience more closely to play/pause state.
- Add matching play-state emphasis to the bottom now-playing summary.
- Introduce a reusable scenery info block so video mode also gets a refined
  lower-left media panel.
- Compact that info block when lyrics are present so the left/right overlays
  stay balanced.
- Verify with formatting, analysis, tests, Windows release build, and a launch
  smoke test.

### Done

- Added play-state ambience to the scenery stage so the background glow becomes
  slightly more alive during active playback.
- Linked the bottom now-playing tile to the playback state with subtle glow,
  border, scale, and label emphasis changes.
- Reused the lower-left scenery info block in video mode so video playback no
  longer feels visually under-described compared with audio playback.
- Made the video-mode info block compact automatically when lyrics are present,
  improving the relationship between the left info region and the right lyric
  region.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-15 - Scenery page transition and media framing refinement

### User Request

- Continue refining the scenery playback page's quality.
- Improve background transitions, the typography hierarchy of the lower-left
  information area, and the boundary treatment around centered video playback.

### Understanding

- The scenery page now has the right structure, but the image transitions need
  to feel more cinematic and less mechanical.
- The lower-left media information should read like a small editorial block,
  with clearer hierarchy between status, title, media type, and metadata.
- Video playback should feel intentionally framed inside the scenic layout
  instead of simply being placed on top of it.

### Should Do

- Refine scenery image crossfades and motion timing.
- Improve the lower-left media information hierarchy and containment.
- Wrap video playback in a more deliberate framed surface.
- Verify with formatting, analysis, tests, Windows release build, and a launch
  smoke test.

### Done

- Smoothed scenery image changes with a longer crossfade, layered fade/scale
  transition, and a slower Ken Burns-style drift.
- Softened the scenery overlay gradient so the background stays rich while
  still supporting readable foreground content.
- Reworked the lower-left media information into a lighter editorial block with
  stronger title hierarchy and clearer media-type labeling.
- Framed centered video playback inside a softer rounded outer shell with
  spacing, border treatment, and shadow so it sits more naturally in the scene.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-15 - Scenery page cleanup and motion polish

### User Request

- Continue polishing three small but high-value areas: left playlist hover feel,
  the top 美景/歌曲 switcher details, and subtle motion in the bottom playback
  area.
- Improve the post-background-change playback scenery page, where some static
  information feels too rigid and some static visual blocks cover too much of
  the background.
- Ignore lyrics for now if they are missing, but make the page itself look
  better in that case.

### Understanding

- The scenery page should let the selected background breathe instead of placing
  a heavy static card right in the middle.
- When lyrics are unavailable, the UI should not reserve a distracting block
  for them.
- Small hover and motion refinements around navigation and playback can add a
  lot of product feel without adding complexity.

### Should Do

- Add hover refinement to sidebar playlist items.
- Refine the 美景/歌曲 switcher with clearer visual structure and icon support.
- Add subtle motion to the main playback control area.
- Rework the scenery playback page so the hero content is lighter, less
  obstructive, and more visually integrated with the background.
- Hide empty lyric presentation instead of showing a static placeholder panel.
- Verify with formatting, analysis, tests, Windows release build, and a launch
  smoke test.

### Done

- Turned sidebar playlist items into hover-aware cards with subtle lift,
  icon scale feedback, and calmer option-menu emphasis.
- Refined the top 美景/歌曲 switcher by placing it in a dedicated rounded shell
  and adding lightweight icons.
- Added subtle play/pause button motion through animated scale, glow strength,
  and icon transitions.
- Reworked the scenery playback page with a lighter ambient overlay and a more
  floating audio hero, moving the media information toward the lower-left so
  the background remains much more visible.
- Removed the empty lyric placeholder panel so missing lyrics no longer cover
  the background with a static block.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-15 - Top navigation and song list interaction polish

### User Request

- Continue.
- Keep recording the user's request, my understanding, execution, and the
  resulting effect while we keep building a premium-quality player together.

### Understanding

- The app now needs more interaction polish, not more feature breadth.
- The top bar should feel like a complete product header, especially around
  theme selection.
- The song list should react gracefully to mouse movement and selection so it
  feels more alive and desktop-native.

### Should Do

- Refine the top palette area so it reads as a designed theme control instead
  of a loose row of color chips.
- Add hover and selected-state nuance to song rows, especially around leading
  indicators and action visibility.
- Keep playback behavior unchanged and verify with formatting, analysis, tests,
  Windows release build, and a launch smoke test.

### Done

- Turned the palette selector into a fuller theme control with a title,
  currently active palette name, and a more deliberate grouped presentation.
- Corrected the song-list helper copy to match the actual click-to-play
  behavior.
- Reworked library/song rows into hover-aware interactive cards with animated
  leading indicators, stronger hover depth, and calmer selected-state feedback.
- Made row actions feel more intentional by tying their emphasis to hover and
  selection instead of leaving them visually flat at all times.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-15 - Bottom controls and dialog refinement

### User Request

- Continue refining the UI.
- Keep recording the user's request, my understanding, the execution, and the
  resulting effect.
- Build Heni together as a polished, premium product.

### Understanding

- The current shell is in a good place, so the next gains come from polishing
  the controls people look at and touch most often.
- The bottom player bar needs clearer visual hierarchy so the main play action,
  transport buttons, progress, and utility actions feel intentionally arranged.
- The add-from-library dialog should match the rest of the interface instead of
  reading like a default form overlay.

### Should Do

- Refine the bottom player bar with stronger now-playing hierarchy and calmer
  control grouping.
- Improve the transport controls and progress bar so they feel more precise and
  product-like.
- Polish the add-from-library dialog list items to better match the glass UI.
- Verify with formatting, analysis, tests, Windows release build, and a launch
  smoke test.

### Done

- Reworked the bottom player bar spacing and balance so the now-playing block,
  transport center, and utility actions feel more structured.
- Enhanced the now-playing summary with a clearer artwork tile, playback state
  line, and cleaner metadata stacking.
- Refined previous/play/next controls with softer surfaces, a stronger primary
  play button, and a more deliberate control rhythm.
- Wrapped the progress slider in a subtle pill track and softened both time
  labels for a cleaner transport area.
- Added dividers inside the right utility cluster so playback mode, volume, and
  export actions feel intentionally grouped instead of crowded together.
- Restyled add-from-library rows with rounded cards, selection tint, and media
  type chips to better match the rest of the player.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-15 - Ambient glass and refined product UI

### User Request

- Continue shaping Heni into a more lively, polished, delicate UI.
- Add a more fluid glass effect step by step.
- Push the product feel further through typography hierarchy, whitespace, and
  a more refined song list experience.

### Understanding

- The current UI already has the right structure, so the next step is not a
  redesign of features but a refinement of atmosphere and hierarchy.
- Theme colors need to feel more present across the whole screen, not only on
  buttons and small accents.
- The library view should read more like a product surface with metadata,
  rhythm, and cleaner row treatment instead of a plain list.

### Should Do

- Add ambient background lighting so palette changes affect the whole shell
  more visibly.
- Refine the top navigation and sidebar with calmer spacing and cleaner chips.
- Improve the library header and rows so the list feels closer to a mature
  desktop media player.
- Keep playback behavior untouched and verify with formatting, analysis, tests,
  Windows release build, and a launch smoke test.

### Done

- Added a subtle ambient backdrop with palette-tinted light fields behind the
  UI so theme changes read more clearly across the full window.
- Refined the top navigation with a compact logo tile, roomier spacing, and a
  more polished palette control.
- Added sidebar metric chips for library directories and item count, plus a
  friendlier empty-state card for playlists.
- Reworked playlist tiles with better count badges and calmer secondary text.
- Upgraded the library view into a more product-like table surface with summary
  pills, a softer header row, numbered items, stronger row grouping, and more
  refined source/type presentation.
- Added input and popup menu theming so dialogs and menus better match the new
  glass UI language.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-15 - Product-style glass UI refresh

### User Request

- The user updated the app icon.
- Running Flutter shows a yellow-black striped bar near the bottom UI.
- The overall interface still does not feel like a polished product.
- Refresh the UI more boldly toward a simpler, more lively, more transparent
  Apple-like direction.

### Understanding

- The bottom striped bar is a real layout overflow bug that needs to be fixed
  first, not just visually hidden.
- The player should feel more cohesive and product-like: fewer hard edges,
  lighter surfaces, cleaner hierarchy, and more intentional spacing.
- The current structure can stay, but the presentation layer should shift
  toward frosted panels, calmer controls, and a clearer layout rhythm.

### Should Do

- Fix the bottom overflow in the transport area.
- Refine the top navigation, sidebar, content surfaces, and bottom player bar
  into a more coherent glass-like product UI.
- Keep existing player logic intact while refreshing visual structure.
- Run formatting, analysis, tests, Windows release build, and a launch smoke
  test.

### Done

- Located the bottom yellow-black stripe as a real `RenderFlex` overflow in the
  bottom transport area's center column.
- Reworked the player shell toward a lighter product UI with rounded frosted
  panels for the top navigation, sidebar, content header, library view, lyric
  panel, and bottom player bar.
- Added a stronger glass treatment with layered highlights, softer shadows,
  clearer text hierarchy, roomier button spacing, and more refined playlist and
  library rows.
- Refined several controls to better fit the new surface language, including
  playlist navigation items, palette chips, and the bottom player layout.
- Reduced the bottom player's vertical pressure by switching the center control
  column to content-sized layout inside a fixed glass panel.
- Verified with `flutter analyze`, `flutter test`,
  `flutter build windows --debug`, `flutter build windows --release`, and a
  release launch smoke test.

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

## 2026-05-16 - Black Screen On Launch And Layout Crash

### Request

- The app opened to a black screen.
- Flutter reported:
  `Cannot hit test a render box that has never been laid out.`

### Understanding

- This looked like a top-level layout failure rather than a playback or codec
  issue.
- A black window plus hit-test errors usually means a root widget never
  completed layout, so the first priority was to restore bounded constraints in
  the shell UI before tuning visuals.

### Should Do

- Reproduce the crash with `flutter run -d windows`.
- Inspect the most recent shell/navigation changes for unbounded layout or
  overflow issues.
- Fix the root constraint problem first, then remove any secondary overflow in
  the top theme control.
- Re-run analysis, tests, build, and a Windows launch smoke check.

### Done

- Reproduced the launch failure and traced the root cause to `_ShellBand`
  being used by the top navigation without a fixed height, which caused an
  unbounded `Stack`.
- Fixed the black-screen root cause by giving the top shell band a stable
  height.
- Traced the follow-up overflow to `_TopPaletteDeck`, where an
  `AnimatedSwitcher` around the active theme label temporarily collapsed the
  available height.
- Replaced that label switcher with a steadier text-style animation so the top
  palette control keeps its polish without breaking layout.
- Verified with `dart format`,
  `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a Windows release launch smoke test.

### Result

- The app no longer opens to a black screen.
- The top bar now lays out stably and does not trigger the earlier hit-test
  crash path.

## 2026-05-17 - Playlist Detail Alignment, Hover Palette Labels, Breathing Layout

### Request

- Align the playlist detail area so the summary row and the table columns
  (`# / 歌曲 / 类型 / 来源`) feel properly lined up.
- Redesign the theme palette strip so the theme name does not stay visible all
  the time; show it only when hovering a swatch, and make the interaction feel
  lighter and more dynamic.
- Add a more product-like "breathing" response to window size changes so the
  top bar, sidebar, playlist rail, content header, scenery area, and bottom
  player can become quieter, tighter, or partially hidden and then recover
  quickly.

### Understanding

- The table issue was really a column-system problem: the header and row body
  were using different width logic, so the page felt visually crooked even
  though the data itself was correct.
- The palette area should behave more like a preview control than a labeled
  settings block.
- The responsive behavior should feel like a desktop player becoming calmer at
  smaller sizes, not like a phone layout taking over.

### Should Do

- Rebuild the songs table header and row layout so they share one column system.
- Replace the persistent theme text with hover-driven palette naming.
- Introduce a shell layout model that drives compact and quiet modes across the
  main UI bands.
- Keep the transitions animated so the layout compresses smoothly.
- Re-run analysis, tests, Windows release build, and a launch smoke check.

### Done

- Reworked the songs table header and row body to share aligned columns for
  `#`, song details, type, source, and actions.
- Simplified the top palette deck and turned the theme label into a hover-only
  floating capsule beside the active swatches.
- Added hover growth and lift to palette swatches for a more tactile theme
  picker.
- Added a shared `_ShellLayout` responsive model with compact and quiet modes.
- Used that layout model to tighten the top band, sidebar, content header,
  scenery hero, and bottom player when the window gets smaller.
- Hid lower-priority details such as the brand subtitle, sidebar status block,
  scenery orb, and some now-playing metadata in quieter states.
- Added animated size transitions to the shell bands and sidebar width so the
  UI compresses more gently.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a Windows release launch smoke test.

## 2026-05-17 - Table Finish And Theme Atmosphere Linkage

### Request

- Continue refining the songs table so it feels more premium.
- Make theme switching feel more connected to the whole page atmosphere rather
  than only changing a few controls.

### Understanding

- The table already aligned correctly after the previous pass, but it still
  needed more hierarchy and cadence to feel like a finished desktop player.
- Theme changes should wash through the window background, shell edge, and glow
  layers so changing palettes feels like changing the room light, not just a
  single accent color.

### Should Do

- Strengthen the songs table header with clearer hierarchy and a more deliberate
  surface treatment.
- Add more row rhythm through subtle striping, row sheen, and a cleaner active
  accent.
- Animate the main app backdrop and the top edge accent when palettes change.
- Keep the behavior lightweight and consistent with the current glass language.
- Re-run analysis, tests, Windows release build, and a launch smoke check.

### Done

- Upgraded the songs table header with a clearer border, top highlight, and
  stronger type hierarchy.
- Added subtle alternating row rhythm in the songs list, plus a more refined
  left accent rail and top sheen for hovered and active rows.
- Turned the ambient backdrop into an animated theme surface so palette changes
  now blend across the full window background.
- Added a second theme-linked glow wash and animated the top edge accent so the
  overall atmosphere responds more clearly to theme changes.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a Windows release launch smoke test.

## 2026-05-17 - Simplified Palette Strip And Stronger Glass Panels

### Request

- Remove the unnecessary blank area to the left of the top palette strip.
- Stop the odd hover flicker before reaching or hovering a palette swatch.
- Make the glass effect more transparent, dimensional, and convincing.

### Understanding

- The blank area and flicker came from the hover label system added in the
- previous pass: it reserved horizontal space and triggered layout changes while
- the pointer moved across the strip.
- The glass layer itself needed more depth from blur, layered highlights, and a
- better sense of front/back separation.

### Should Do

- Simplify the top palette strip back to a clean row of color swatches.
- Remove hover-driven layout changes from the palette chooser.
- Keep theme names available by tooltip only, without affecting layout.
- Strengthen the shared glass panel style with richer blur, layered fills, and
- more nuanced highlights and shadows.
- Re-run analysis, tests, Windows release build, and a launch smoke test.

### Done

- Removed the hover label area from the top palette chooser so only the color
  swatch strip remains.
- Removed hover-state width and lift changes that caused the earlier flicker in
  the palette strip.
- Kept palette names available through tooltip without reflowing the layout.
- Increased the glass blur and added layered highlight, soft shading, and a
  lower reflective edge to make panels feel more transparent and dimensional.
- Verified with `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a Windows release launch smoke test.

## 2026-05-17 - Unified Glass Material Pass

### Request

- Do a dedicated pass on glass-material consistency so the top bar, left
  sidebar, content area, and bottom player feel like the same material system.

### Understanding

- The UI already had better blur and reflection than before, but the four main
- bands still used slightly different transparency and border strength, which
- made the shell feel assembled from similar parts instead of one coherent
- surface family.

### Should Do

- Create a shared glass fill and border recipe for the main shell surfaces.
- Apply that recipe across top, left, content, and bottom containers while
- preserving only small hierarchy differences.
- Keep the center list surface compatible with the same look, even if it uses a
- more generic neutral version of the formula.
- Re-run analysis, tests, Windows release build, and a launch smoke test.

### Done

- Added shared shell-glass helper colors for fill and border balance.
- Unified the top shell band, sidebar shell, and content header shell around the
  same transparency and border recipe.
- Tuned the songs list panel toward the same material family with a neutral
  glass blend so it no longer feels flatter than the surrounding shell.
- Verified with `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a Windows release launch smoke test.

## 2026-05-17 - Content Hierarchy Inside Glass

### Request

- Unify the content hierarchy inside the glass UI: text contrast, icon contrast,
  button density, and internal spacing should all read more coherently and feel
  more premium.

### Understanding

- After the glass material itself became more coherent, the next quality step
  was to make the content sitting on top of that material speak the same visual
  language.
- This meant not only brighter or dimmer text, but a stable hierarchy:
  primary information, secondary support text, and tertiary labels should look
  consistently ranked across top, left, center, and bottom surfaces.

### Should Do

- Introduce shared text contrast helpers for primary, secondary, and tertiary
  glass content.
- Apply those helpers to high-visibility UI areas such as the top brand,
  sidebar section headers, pills, badges, empty states, and playlist rows.
- Tighten button density and label weight in the shared theme so outlined and
  filled controls feel consistent.
- Re-run analysis, tests, Windows release build, and a launch smoke test.

### Done

- Added shared contrast helpers for primary, secondary, and tertiary text on
  glass surfaces.
- Applied the new hierarchy to the top brand, sidebar section headers, pills,
  refresh badges, count badges, empty states, and playlist rows.
- Tightened button typography and horizontal padding in the shared theme so
  buttons and icon buttons read more consistently on translucent panels.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a Windows release launch smoke test.

## 2026-05-17 - Palette-Aware Text Visibility

### Request

- Continue the glass content hierarchy pass, but pay special attention to text
  visibility under different color themes because some palettes made parts of
  the UI nearly unreadable.

### Understanding

- The main issue was not just hierarchy but palette-aware contrast.
- Some places still used a theme color itself as a foreground text/icon color.
  That breaks down in very dark palettes such as black, where the decorative
  theme hue can become too dim to serve as readable content.

### Should Do

- Introduce a readable foreground rule for palette-driven accents.
- Use the readable accent foreground for filled controls, status badges, and
  currently-playing labels that sit on tinted surfaces.
- Make the shared theme's primary color align with the palette accent so
  high-visibility controls inherit a more readable base color.
- Re-run analysis, tests, Windows release build, and a launch smoke test.

### Done

- Added readable-foreground helpers for accent-colored surfaces.
- Updated the shared theme so `ColorScheme.primary` follows `palette.accent`,
  with `onPrimary` chosen from luminance instead of being hard-coded.
- Replaced several hard-coded dark foregrounds and direct `palette.seed` text
  colors in the player UI with readable accent-aware foregrounds.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a Windows release launch smoke test.

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

## 2026-05-17 - Multi-Theme Contrast Sweep

### User Request

- Do a real multi-theme visual cleanup pass and sweep away the remaining
  localized contrast issues across all palettes.
- Pay special attention to palettes where text was becoming nearly invisible.

### Understanding

- The remaining risk is not the overall layout but small foreground decisions:
  solid accent surfaces, faint accent-tinted glass chips, and accent labels on
  dark glass were still sharing the wrong contrast rules.
- The fix should become a reusable rule set so future UI tweaks do not
  reintroduce low-contrast text in bright or extreme themes.

### Should Do

- Split accent contrast handling into two rules: one for text placed on solid
  accent surfaces, and one for accent-colored text placed on dark glass.
- Audit the Windows player screen for labels, icons, and pills that still use a
  raw theme accent as foreground on translucent glass.
- Add a lightweight automated contrast check for all palettes.
- Re-run format, analysis, tests, and the Windows release build.

### Done

- Added shared theme helpers for palette-aware foreground selection on accent
  surfaces and accent text shown on dark glass.
- Updated the now-playing status labels, scenery status badge, playlist add
  button, selected-state chips, and active row icons to use the correct
  contrast rule for their actual background.
- Tuned helper copy such as the library hint text to the shared glass hierarchy
  instead of one-off low-alpha values.
- Added a theme test that checks every palette for readable `primary/onPrimary`
  contrast and for acceptable accent-on-glass contrast against the shell
  surfaces.
- Verified with `dart format`, `flutter analyze`, `flutter test`, and
  `flutter build windows --release`.

## 2026-05-17 - Persist Playback Mode

### User Request

- Stop requiring a manual playback-mode click after every restart; restore the
  last used playback mode automatically.

### Understanding

- Playback mode belongs with the rest of the persisted shell/player
  preferences. If we already remember theme, UI style, and scan settings, the
  player should also remember whether it was in sequence, list loop, single
  loop, or random mode.

### Should Do

- Save the current playback mode into the local Heni config file whenever it
  changes.
- Restore that mode during startup and map it back to `repeatMode + shuffle`
  correctly.
- Add a regression test so the mode survives a fresh controller restore.

### Done

- Added `playbackModeName` to the persisted Heni library config.
- Playback mode changes now trigger config persistence immediately.
- Startup restore now reapplies the saved playback mode before the library UI
  settles, so the mode button already reflects the last session.
- Added a controller test that saves `随机播放` and confirms it restores as
  `shuffle + 列表循环`.

## 2026-05-17 - Persist Volume And Window State

### User Request

- Also remember the last volume and the last window size/position so the app
  feels more complete on desktop.

### Understanding

- Volume is part of the player's personal state, so it belongs in the existing
  Heni config.
- Window bounds are a Windows-shell concern; the lightest reliable solution is
  to persist them natively in the runner rather than adding a new cross-platform
  window-management dependency right now.

### Should Do

- Persist the last volume in the local config and restore it during startup.
- Avoid hammering the config file while the user is dragging the volume slider.
- Persist the Windows window rectangle and maximized state, and restore them on
  next launch.
- Verify through analysis, tests, Windows release build, and a launch smoke
  test.

### Done

- Added `volumeLevel` to the persisted Heni config and restore flow.
- Volume slider changes now debounce config writes, so dragging remains smooth
  while the final volume still persists.
- Added a controller test that confirms volume survives a fresh restore.
- Added native Windows window-state persistence for position, size, and
  maximized state through the runner.
- Verified with `dart format`, `flutter analyze`, `flutter test`,
  `flutter build windows --release`, and a release launch smoke test.

## 2026-05-17 - Structure Refactor Round 1

### User Request

- Start the first real structure refactor instead of only polishing visuals, so
  Heni moves toward a mature local music-player product.

### Understanding

- The previous shell looked good but still mixed too many responsibilities:
  the top bar was handling page mode, the left bar was not yet a true browsing
  map, and the current playback queue still behaved like a tool popup instead of
  a first-class place in the app.
- This round should clarify hierarchy first: top for global actions, left for
  destinations, right for content and mode.

### Should Do

- Turn the top bar into a global work bar with brand, search, theme controls,
  and settings.
- Promote the current playback queue to a first-level destination in the left
  sidebar.
- Move the `歌曲 / 播放中` mode switch into the right content header so it belongs
  to the active content context instead of the app shell.
- Let songs views share better content-header logic for library, playlists, and
  current queue.

### Done

- Rebuilt the top bar into a global shell with brand, search, palette strip,
  quick library/queue counts, and settings.
- Added a real list-level search flow through the top bar, filtering the active
  songs view by title and path.
- Promoted `当前播放列表` into the left sidebar as a primary destination next to
  `曲库`.
- Moved the `歌曲 / 播放中` switch into the right content header and updated the
  header copy so library, playlists, queue, and playback stage each read like a
  clearer work context.
- Updated the songs table and empty states so the current playback queue is
  handled as its own view instead of pretending to be a regular playlist.

## 2026-05-17 - Content Workspace Round 2

### User Request

- Move into the second round and make the right songs workspace feel like a
  mature player work area rather than merely a usable list.

### Understanding

- The shell structure is clearer now, so the next bottleneck is the right pane:
  list density, table hierarchy, queue context, and sorting/search feedback all
  need to feel more deliberate.
- The biggest wins come from improving how the user reads and manipulates the
  active list, especially for the current playback queue.

### Should Do

- Add higher-value list signals such as sort mode and a more explicit queue
  context.
- Strengthen the songs table with another practical column and more professional
  list rhythm.
- Make the current playback queue view behave more like a dedicated queue page.
- Keep the upgrade Windows-first and verify through analysis, tests, and a
  release build.

### Done

- Added active-list search filtering via the top search bar to the songs
  workspace.
- Added a sort selector for songs views with queue order, title, type, and
  source sorting modes.
- Added a dedicated duration column to the songs table with stable tabular time
  formatting.
- Strengthened the queue context in the songs workspace with queue-specific
  labels, empty states, and a direct `回到播放中` action from the queue view.
- Refined the songs summary pills so search, sort, library, playlist, and queue
  contexts are easier to parse at a glance.

## 2026-05-17 - Adaptive Header And Resize Stability

### User Request

- Do not add extra browsing dimensions such as album, artist, or folder.
- Continue optimizing the UI from a professional designer angle so the visuals
  feel more harmonious and beautiful.
- Inspect and fix the yellow-black overflow warnings and range issues that
  appear while resizing the window.

### Understanding

- The next value is not more information architecture but better visual rhythm
  and stronger resize resilience.
- The biggest practical issue is that some high-density header and toolbar rows
  still assume wide desktop space and overflow when the window narrows.
- A good fix should also make the UI calmer: less forced one-line packing, more
  graceful stacking, and steadier theme controls.

### Should Do

- Convert resize-sensitive header/tool rows to adaptive multi-line layouts
  instead of leaving them as rigid single rows.
- Make the bottom player bar switch into a compact variant earlier on narrower
  Windows widths.
- Remove small visual jitter from the theme swatch picker so palette controls
  look more deliberate.
- Keep the Windows release build healthy and record the change in the logs.

### Done

- Rebuilt the right content header to use width-aware stacked layouts for both
  songs mode and playback-stage mode, which prevents action clusters from
  forcing overflow on narrow windows.
- Converted the songs workspace toolbar from a rigid row into an adaptive
  wrap/stack layout so search feedback, selection state, and actions stay
  readable during resize.
- Made the bottom player bar enter compact mode automatically on narrower
  window widths instead of waiting only for explicit focus mode.
- Changed the empty-state card to use a max-width constraint rather than a
  fixed width, which avoids one more narrow-window overflow case.
- Simplified theme swatch selection so the palette dots no longer change size
  when selected, making the color picker calmer and more refined.

## 2026-05-17 - Visual Hierarchy And Glass Quieting

### User Request

- Keep focusing on UI instead of adding more browsing dimensions.
- Specifically reduce the visual weight of the top bar, improve the hierarchy
  of the right content area, and refine contrast and spacing inside the glass
  material so the interface feels more harmonious and beautiful.

### Understanding

- The product already has enough structure for now; the next gain comes from
  taste and restraint.
- The top shell was still a little too assertive, and the right content area
  had too many mid-priority elements speaking at once.
- This round should not make the app flatter or duller; it should make the
  emphasis more selective so important content stands out better.

### Should Do

- Quiet the top shell by trimming its height, padding, glow, and brand weight.
- Soften the songs workspace materials so the list content carries more of the
  visual focus than the surrounding chrome.
- Make hero, chips, and small metadata badges feel lighter and more cohesive.
- Preserve readability and Windows stability across the existing palette system.

### Done

- Reduced the top bar’s visual presence by trimming shell spacing, lowering its
  emphasis, calming the search field focus glow, and tightening the brand mark.
- Unified the songs workspace glass fill with the shared shell material recipe
  instead of using a heavier custom dark panel.
- Softened the library hero banner by reducing gradient intensity, icon weight,
  shadow strength, and headline size so the banner supports the content instead
  of competing with it.
- Tuned heading chips and info pills to use lighter fills, quieter borders, and
  more restrained text contrast for a cleaner hierarchy inside the glass UI.

## 2026-05-17 - Sidebar/Table Balance And Bottom Density

### User Request

- Keep refining two high-value details: the quiet-vs-busy balance between the
  left playlist sidebar and the right songs table, and the information density
  of the bottom player.

### Understanding

- The app already feels coherent, but some areas still speak a little too
  loudly at the same time: the sidebar competes with the songs workspace, and
  the bottom player still carries a bit more visual mass than necessary.
- The goal is not to flatten the UI, but to let the browsing content own more
  of the attention while navigation and playback chrome become calmer.

### Should Do

- Reduce the visual weight of sidebar gradients, section headers, playlist tile
- hover/selected states, and count badges.
- Give the songs table header slightly clearer reading rhythm so the main
  content side feels more deliberate.
- Tighten the bottom player summary and utility cluster so it stays expressive
  but lighter.

### Done

- Softened the sidebar edge glow, status card, section headers, playlist tile
  hover/selected treatment, and badge styling so the left rail reads quieter.
- Slightly clarified the songs table header contrast and spacing so the right
  content area feels more anchored and readable.
- Reduced the visual mass of the bottom player by tightening now-playing width,
  lowering secondary text contrast, shrinking transport emphasis, and trimming
  spacing between utility controls.

## 2026-05-17 - Final Spacing Calibration

### User Request

- Do one last pure visual calibration pass focused on the songs-table row
  treatment, the bottom progress area, and the spacing relationship between the
  left sidebar sections.

### Understanding

- The product is already coherent; the remaining gains come from rhythm rather
  than structure.
- These three areas need to breathe on the same cadence so the whole app feels
  intentionally composed instead of merely well-styled.

### Should Do

- Rebalance sidebar section gaps and local spacing so the left rail feels
  quieter and more deliberate.
- Smooth the songs-table row rhythm through margin, radius, icon spacing, and
  typography micro-adjustments.
- Refine the progress strip with calmer timing labels and a slightly slimmer,
  steadier track/thumb treatment.

### Done

- Recalibrated left-sidebar section spacing so `浏览`, `我的歌单`, and the status
  area now breathe with a more even desktop rhythm.
- Smoothed the table row treatment through slightly softer shadows, cleaner row
  spacing, and tighter-but-airier content alignment inside each song row.
- Refined the bottom progress area with subtler time labels, a slimmer progress
  track, and a lighter hover thumb so the player footer feels more polished and
  less busy.

## 2026-05-17 - Windows Visual QA Sweep

### User Request

- Stop making structural changes and do a Windows real-machine-style visual QA
  sweep, checking consistency across different window sizes.

### Understanding

- At this stage the most useful work is not another redesign, but a careful
  review of how the existing UI behaves in wide, medium, compact, and narrow
  desktop sizes.
- The goal is to catch small inconsistencies in density, legibility, and visual
  balance before they become “that one annoying corner” in daily use.

### Should Do

- Launch the Windows build and inspect the UI across several window sizes.
- Look specifically at shell balance, list readability, and compact-state
- behavior under real resize conditions.
- Fix any small issues that show up during the sweep and record the result.

### Done

- Ran a Windows visual QA pass by launching the app and capturing screenshots in
  wide, medium, compact, and narrow window sizes.
- Verified that the current shell, sidebar, content header, and compact-state
  transitions now stay visually stable without new overflow regressions.
- Found one remaining polish issue during the narrow-width pass: the top search
  placeholder was too verbose, making the shell feel denser than necessary.
- Shortened the quiet-layout search hint to `搜索歌曲或路径`, improving narrow
  window balance without changing behavior.

## 2026-05-17 - Sidebar Centering And Row Breathing

### User Request

- Fine-tune two small UI details:
  the text/icon inside each left-sidebar playlist tile feels a little too high,
  and the song icon in the right songs table sits too close to the title.

### Understanding

- These are small alignment issues, but they directly affect polish because the
  eye catches them constantly during browsing.
- The fix should stay minimal: re-center the playlist tile content and give the
  songs table title a touch more breathing room without changing the overall
  density of the interface.

### Should Do

- Re-center sidebar playlist tile contents vertically.
- Add a subtle horizontal gap between the songs-table media icon cluster and the
  track title area.
- Re-run formatting and analysis to make sure the touch-up stays clean.

### Done

- Wrapped the sidebar playlist tile content in a centered layout and added a
  steadier text line-height so the icon and title sit more naturally on the
  vertical centerline.
- Added a small spacer between the songs-table lead cluster and the title block,
  which makes the icon/title relationship feel less cramped.

## 2026-05-24 - Modal Action Re-entry Guard

### User Request

- Clicking `添加歌曲` repeatedly currently executes the action repeatedly and
  can open several windows, which is unreasonable.

### Understanding

- This is a modal re-entry problem: actions that open dialogs or native file
  pickers should be mutually exclusive while one is already active.
- The fix should cover `添加歌曲` directly, and also protect nearby modal actions
  such as adding files, importing folders, changing scenery images, exporting
  audio, and playlist edit dialogs.

### Should Do

- Add a lightweight app-level modal action lock.
- Wrap dialog/file-picker entry points so repeated clicks are ignored until the
  active modal action finishes.
- Keep the behavior simple and invisible to the user: no extra prompt, no
  stacked windows.

### Done

- Added an `ActiveModalAction` notifier that tracks whether a modal/file-picker
  action is currently active.
- Wrapped `添加歌曲`, `添加文件`, `导入目录`, `更换背景`, `导出音频`, playlist creation,
  rename, description, deletion, management, and playback queue dialogs with the
  same modal guard.
- Added `lockParentWindow: true` to the file pickers that were missing it, so
  native picker behavior is better tied to the Heni window.

## 2026-05-25 - Duration Metadata And Songs Panel Refinement

### User Request

- Re-examine Heni's local music-player UI from the appearance/design angle and
  suggest how further beautification should proceed.
- Fix the bug where playlist/library song durations default to `--:--`, reset
  after refresh, and only become visible after a song has been played.
- Redesign the second right-side panel, making it more compact and more
  beautiful.

### Understanding

- Duration should behave as stable media metadata, not as a temporary playback
  side effect.
- The right-side songs panel was visually pleasant but still a bit tall and
  padded; it can become more mature by being denser, quieter, and better aligned.
- From an appearance standpoint, the next UI improvements should focus less on
  adding decoration and more on material hierarchy, list rhythm, and visual
  consistency across states.

### Should Do

- Persist detected media durations in the local library config.
- Restore duration metadata into library and playlist items during app startup
  and library refresh.
- Background-probe missing durations after adding files or scanning folders, so
  unplayed songs can still receive stable duration metadata.
- Tighten the right songs panel: lighter glass, smaller header/tool area,
  denser rows, and more restrained icon/title/path hierarchy.

### Done

- Added `mediaDurations` to the persisted Heni library config.
- Merged known durations back into scanned/restored media items so refresh and
  restart no longer discard duration metadata.
- Added a background duration inspection flow for missing durations after import,
  folder scan, restore, and refresh.
- Persist duration updates when playback or background inspection discovers
  them.
- Added a regression test proving persisted media durations restore into the
  visible library.
- Redesigned the right-side songs list panel with lighter glass, tighter toolbar
  spacing, a more compact table header, and slimmer song rows.

## 2026-05-25 - White Theme Contrast And Quiet UI Direction

### User Request

- In the white appearance mode, some button icons/patterns are nearly invisible.
- Adjust the color scheme to keep it beautiful while improving visibility.
- Continue the design direction of reducing decoration, strengthening content
  order, using theme color only for current/playback/selected states, and
  keeping Heni quiet, transparent, and durable.

### Understanding

- The white palette used a nearly pure-white accent, which made several filled
  or selected controls vulnerable to weak icon contrast.
- The fix should not make the white theme harsh; it should keep the clean white
  identity while giving interactive controls a readable accent color.
- Ordinary controls should stay calm and glass-like; theme color should be
  reserved for true state and emphasis.

### Should Do

- Replace the white theme's pure-white accent with a softer but visible accent.
- Make selected palette dots and high-frequency player controls choose explicit
  readable foreground colors instead of relying on defaults.
- Add a regression test for white-theme control contrast.

### Done

- Updated the white palette accent from pure white to a soft sage tone, keeping
  the white theme clean while making filled controls and icons readable.
- Added shared foreground helpers for accent controls and state icons on glass.
- Applied explicit foreground colors to palette swatches, playback mode,
  current queue, export, volume, and key songs-panel icon buttons.
- Added a theme test that prevents the white palette from regressing to pure
  white controls with weak icon contrast.

## 2026-07-16 - Playback Quality Audit And Editorial UI Redesign

### User Request

- Check whether playback contains incorrect compression or playback logic that
  lowers sound quality.
- Consider that part of the library comes from web-downloaded MP4 files.
- Substantially redesign the player UI because the existing interface still
  feels visually unsatisfying.

### Understanding

- Local playback should open the source file directly without an implicit
  FFmpeg conversion, equalizer, loudness normalizer, pitch filter, or volume
  boost.
- Perceived harshness can still come from low-bitrate AAC/MP3 sources and from
  rendering pressure caused by a continuously rebuilding, heavily blurred
  desktop shell.
- The UI needs fewer nested glass cards, pills, animated glows, and decorative
  motion; content hierarchy and reliable responsive layout should carry the
  visual identity.

### Should Do

- Make the neutral `media_kit` playback configuration explicit.
- Remove playback-position-driven full-window decoration updates and reduce
  full-screen blur/animation load.
- Surface codec, bitrate, sample rate, and basic source-quality hints in the
  now-playing area.
- Rebuild the desktop shell with a flatter editorial header, responsive icon
  rail, quieter library workspace, and a fixed bottom player dock.
- Verify wide and compact Windows layouts for clipping and overflow.

### Done

- Confirmed that playback opens the original local media path directly and does
  not pass through the FFmpeg export pipeline or any runtime audio filter.
- Added an explicit neutral player configuration with pitch control disabled,
  startup mute disabled, and no native on-screen controls.
- Removed the playback-position subscription from the full-window ambient
  backdrop and replaced continuously animated background decoration with a
  restrained static treatment.
- Added codec, bitrate, sample-rate, lossless, and low-bitrate source indicators
  to the playback metadata.
- Reworked the navigation, sidebar, playlist header, songs table, global
  materials, controls, and responsive breakpoints into a calmer editorial
  desktop layout.
- Anchored the player controls in a dedicated bottom dock so content cannot push
  them out of view.
- Corrected an 8-pixel overflow in the full desktop bottom-player layout found
  during DPI-aware Windows screenshot QA.

## 2026-07-16 - Queue Current-Track Locator And Export Removal

### User Request

- Verify why the previously discussed update did not appear in the player.
- Add a direct way to locate the currently playing track in the playback queue.
- Remove the FLAC/audio export feature because transcoding lossy sources to FLAC
  does not improve sound quality.
- Continue the usability work in the direction established by the earlier
  player redesign.

### Understanding

- The earlier queue/export discussion had only been recorded in design
  documents; it had not yet been applied to the running application.
- Locating the current item must work even when it is outside the lazily built
  portion of a long queue.
- A search query that hides the current item should be cleared when the user
  explicitly asks to locate that item.
- Removing audio export should remove its UI, controller, FFmpeg editor path,
  and obsolete tests without removing FLAC or Opus playback support.

### Done

- Added automatic current-track centering when the playback queue opens.
- Added an always-visible `定位当前歌曲` action beside queue search.
- Added two-stage queue scrolling so current tracks outside the currently built
  list rows can still be brought into view.
- Clear only a search query that blocks the current item; matching queries are
  preserved.
- Removed the player audio-export UI and the associated controller, FFmpeg
  editor, command-building API, provider, and export-only tests.
- Kept FLAC and Opus in the supported local playback extensions.
- Verified the source with `flutter analyze` and rebuilt the Windows Debug
  executable successfully.
- The full Flutter test suite could not load because every test runner listener
  connection to local `127.0.0.1` timed out before any test case executed.

## 2026-07-16 - Progress Resize Stability

### User Request

- Fix the bottom song progress display bug that appears while resizing the
  player horizontally.

### Root Cause

- The approved full-player minimum size had not been implemented in the Win32
  runner, so Windows allowed the full interface to shrink to arbitrary widths.
- At extreme widths the full shell produced multiple `RenderFlex overflow`
  errors and the progress component replaced the seek track with a combined
  time label.
- The seek tooltip also assumed a track width of at least 48 logical pixels.

### Done

- Added DPI-aware `WM_GETMINMAXINFO` handling for a minimum full-player client
  area of `900 × 620` logical pixels.
- Extracted the progress presentation into a focused, testable widget.
- Narrow progress layouts now always retain the interactive seek track and hide
  time labels that cannot fit instead of replacing the track with text.
- Hardened drag, hover, and tooltip calculations for zero-width and sub-48-pixel
  tracks.
- Added a narrow-width Flutter widget regression test and a Windows runtime
  minimum-size verification script.
- Verified the native test fails at `220 × 300` before the fix and reports a
  clamped `913 × 656` window after the fix on the current 200% DPI display.
- Screenshot QA at the minimum size shows separated time labels and seek track
  with no overflow banners.
- `flutter analyze` and the Windows Debug build pass. Flutter widget test
  execution remains blocked before assertions by the existing local
  `127.0.0.1` listener timeout.

## 2026-07-16 - Adaptive Expanded And Compact Sidebar

### User Request

- Prevent the full UI from shrinking into an unusable layout.
- Replace the always-small default sidebar with two intentional modes.
- Keep a labeled expanded sidebar for comfortable widths.
- Automatically use the compact rail when the window is narrow and restore the
  appropriate wide-window mode afterwards.
- Base the interaction on mature desktop music-player patterns.

### Root Cause

- Sidebar presentation was tied to the shared `quiet` layout flag:
  `width < 1120 || height < 740`.
- The default `1280 × 720` window therefore used the compact sidebar only
  because its height was 20 logical pixels below the unrelated density
  threshold.
- The previous compact content width was about 58 logical pixels and there was
  no manual preference, persistence, or resize hysteresis.

### Done

- Added explicit `expanded` and `compact` sidebar preferences, defaulting to
  expanded.
- Expanded mode is 224 logical pixels and retains destination labels, playlist
  names, icons, and counts.
- Compact mode is 72 logical pixels with icon destinations, tooltips, and a
  dedicated expand control.
- Added a collapse control beside the expanded `浏览` heading.
- Added width hysteresis: enter forced compact at 1040, release at 1140, and use
  1080 for the initial layout decision.
- Automatic narrow-window compaction never overwrites the stored manual
  preference.
- A forced compact expand control remains visible but disabled with the tooltip
  `窗口宽度不足，拉宽后可展开`.
- Persisted the manual preference as `sidebarMode` in the Heni library config.
- Verified manual compact/expanded changes write the config and that restart
  restores the expanded preference.
- Corrected a related default-size bottom overflow by using the compact bottom
  bar when vertical density is constrained.
- Screenshot QA confirms labeled expanded mode at 1280 × 720, forced compact at
  width 1000, compact retention in the hysteresis band, and expanded restoration
  at width 1180.
- Static analysis and the Windows Debug build pass. Flutter test execution
  remains blocked before assertions by the existing local listener timeout.

## 2026-07-16 - Studio-Matte Console, Project Docs, And Release Delivery

### User Request

- Continue the approved `录音室哑光` direction with deep theme tinting.
- Make the outer Windows UI match the theme instead of using the default frame.
- Improve static presentation and practical interaction details.
- After implementation, read/maintain the project Strata startup documentation.
- Confirm the update is present in the Release build and push it to the remote.

### Understanding

- The player should feel like one themed desktop object, including its native
  frame, background image, side navigation, playback stage, and bottom dock.
- Audio playback needs honest source metadata and useful actions, not lyrics or
  a misleading lossy-to-FLAC export.
- Current-track location must be available directly from the listening console
  and remain usable in a long queue and a short window.
- Documentation must distinguish locally verified behavior from environment
  limitations and from unverified bit-perfect claims.

### Done

- Integrated a captionless themed Windows frame with working drag, minimize,
  maximize/restore, close, DPI hit testing, state restore, and a logical
  `900 × 620` minimum client size.
- Added a full-window scenery backdrop and deeper active-palette material
  treatment.
- Added the responsive listening console with source path, real ffprobe codec/
  bitrate/sample-rate/channel metadata, conservative lossless labeling,
  next-track preview, queue location, and file-location actions.
- Removed the remaining lyric model/loading/UI path and kept user-facing audio
  export absent.
- Found and fixed a queue-dialog bottom overflow during real current-track
  location QA by making its list use the available dialog height.
- Added a short root `strata.md` router, a current `logs/plan.md`, and corrected
  architecture, project overview, media-quality, Windows, and request logs.
- Verified static analysis, 8 pure-Dart regression tests, Debug build, Release
  build, captionless Release style, minimum-size clamping, custom maximize/
  restore behavior, and DPI-aware Release screenshots.
- `flutter test` remains blocked before suite loading by the host
  `127.0.0.1` loopback failure; no widget assertion executed.

## 2026-07-17 - Panoramic Theme Canvas And Final Usability Pass

### User Request

- Make the outermost UI genuinely merge with the selected theme instead of
  looking like a default or rough product frame.
- Continue the approved option B panoramic design with lowercase `heni` as the
  only icon/wordmark treatment.
- Retain all earlier requirements: full-background imagery, mature two-mode
  sidebar behavior, usable minimum size, stable progress geometry, quick queue
  location, improved volume interaction, no lyrics, and no FLAC export.
- Maintain `strata.md` and project documentation, confirm the update appears in
  the normal-workspace Release build, and push the update to the remote.

### Understanding

- The background must be a shared canvas under every shell region, not an image
  trapped inside the playback content card.
- Theme matching is a semantic surface system: chrome, rail, workspace, dock,
  states, borders, and text need related but distinct opacity/contrast roles.
- Automatic responsive behavior must not erase a user's stored sidebar choice,
  and locator actions must not erase a user's queue search.
- Playback quality logic should remain neutral; this visual/usability change
  must not introduce processing or imply that a lossy source can be restored.

### Done

- Added the panoramic shell theme token model and applied one full-window
  scenery canvas across title bar, sidebar, workspace, and transport dock.
- Rebuilt the custom title-bar surfaces and controls around the active palette,
  with lowercase `heni` branding and a matching multi-resolution Windows icon.
- Finished the labeled expanded sidebar, forced compact narrow state, automatic
  wide restoration, minimum-size boundary, and responsive progress treatment.
- Added a theme-matched volume popover with mute/restore, wheel adjustment,
  percentage feedback, live engine updates, and persisted final values.
- Updated queue location to preserve active filters, explain hidden current
  tracks, center visible current tracks, and apply a short selection highlight.
- Kept lyrics and user-facing FLAC/audio export absent and left the playback
  engine/DSP path unchanged.
- Added focused regression specifications for shell tokens, panoramic backdrop,
  window chrome, sidebar behavior, progress geometry, queue location, volume,
  and the window controller. Widget execution remains blocked by the local
  Flutter listener environment; static analysis and native builds remain the
  authoritative executable checks for this machine.

## 2026-07-17 - Full-Bleed Windows Frame And Drag Zones

### User Request

- Remove the unexplained top whitespace and refine the outer border so it feels
  like part of Heni's selected theme.
- Make the window move like a normal desktop application while keeping search
  and controls usable.

### Done

- Removed the six-pixel native non-client frame inset with full-client
  `WM_NCCALCSIZE` handling and best-effort DWM border suppression, while
  retaining `WS_THICKFRAME` and native resize hit testing.
- Made `heni` and an explicit wide-title drag spacer movable targets; search,
  palette, settings, and window controls remain protected from drag handling.
- Simplified the outer treatment to one theme-derived pixel in restored state;
  maximized windows remain flush.
- Release probe evidence confirms zero inset, correct brand/search/spacer drag
  results, the exact `900 x 620` minimum, and custom maximize/restore from
  false to true to false.
- DPI-aware wide and minimum screenshots show the whole rendered window rather
  than the earlier DPI-virtualized top-left crop. They retain title controls,
  search, compact navigation, bottom player dock, and contain no overflow
  banner.

### Verification Limits

- Native edge/corner hit testing returns the expected resize codes, but host
  cursor automation did not move the window and Windows Snap preview has no
  queryable state; visual Snap-preview confirmation remains manual.
- The pure-Dart subset (8 tests), analysis, and Debug/Release builds pass.
  The broad Flutter widget harness still fails before assertions on the host
  `127.0.0.1` listener (Windows error 121), so it is not reported as passing.
- Every Dart file changed by this full-bleed implementation passes its
  individual formatter check. The repository-wide formatter still reports ten
  unrelated pre-existing files (router, media/domain, FFmpeg, and two existing
  FFmpeg/media tests) and exits 1, while Git status and whitespace checks stay
  clean outside this record; this is tracked as repository formatting debt,
  not silently reported as a clean whole-repository gate.

## 2026-07-18 - Resizable Sidebar And Player Control Usability

### User Request

- Keep the whole desktop app user-resizable within a practical minimum range,
  and make the sidebar expandable/collapsible even when the restored window is
  initially narrow.
- Improve shuffle, repeat, and volume behavior using mature desktop music
  player interaction patterns.
- Correct the playing-track progress bar so its fill, labels, hover preview,
  drag preview, and final seek all agree.

### Done

- Kept the DPI-aware `900 × 620` minimum and added a native safe-width request:
  expanding from a narrow window requests `1140` logical client pixels, stays
  on-screen, and never shrinks the window on collapse.
- Reconciled the restored sidebar preference after storage hydration. A saved
  expanded preference now grows a `900 × 620` window once and then renders the
  full labeled sidebar; a saved compact preference remains compact.
- Split shuffle and repeat into independent persisted states with backward
  migration from the former single playback-mode field. The transport order is
  now shuffle, previous, play/pause, next, repeat, with separate active colour,
  state dots, glyphs, and tooltips.
- Replaced the volume popover with an always-visible speaker plus slider. Click
  mutes/restores, wheel adjusts by 2 points, arrow keys by 5 points, and `M`
  toggles mute unless an editable field owns focus. The last audible level is
  persisted separately so saving zero does not lose the restore target.
- Rebuilt progress around one coherent snapshot sourced from streamed values,
  synchronous engine state, and metadata fallback in that order. Media changes
  clear stale progress, unknown durations cannot seek, drag preview ignores
  conflicting position updates, release seeks once, and `320/220/140` widths
  select wide/compact/track-only layouts.

### Verification

- Fresh `flutter analyze`: no issues.
- Windows Debug and Release builds completed successfully before runtime QA;
  Debug was rebuilt again after the `1140` shell-inset boundary correction.
- At 200% DPI, isolated Debug runtime checks confirmed compact `900 × 620`,
  default expanded `1280 × 720`, and restored-expanded `1140 × 620` layouts
  without a Flutter overflow banner. A 30-second silent WAV showed
  `00:24 / 00:30` with the fill at approximately 80%, matching the displayed
  time.
- DPI-aware screenshots are stored at
  `build/visual-check/player-controls-compact-900x620.png`,
  `build/visual-check/player-controls-expanded-1140x620.png`,
  `build/visual-check/player-controls-default-1280x720.png`, and
  `build/visual-check/player-progress-playing-30s.png`.
- The focused Flutter test targets compile, but the host test shell still fails
  before loading any suite because it cannot connect to its `127.0.0.1`
  listener (`SocketException`, Windows error 121). No test assertion is
  reported as passing.
