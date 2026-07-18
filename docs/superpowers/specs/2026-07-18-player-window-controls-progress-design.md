# Heni Window, Playback Controls, And Progress Design

## Status

Approved interaction design for correcting the Windows player's initial sidebar
state, window-resize behavior, playback-mode controls, volume control, and
in-progress time display.

## Context And Root Causes

The current application can restore its full-player window at the supported
minimum `900 × 620` logical size. At that width, the responsive sidebar policy
forces compact mode and disables the expand action. The persisted sidebar
preference can still be `expanded`, which leaves the initial UI showing an
expand button that cannot fulfill the saved preference.

The lower-right playback controls also combine sequence, list repeat, single
repeat, and shuffle into one cycling button. This hides the current behavior,
requires unnecessary clicks, and prevents shuffle and repeat from being
controlled independently. Volume adjustment requires opening a popover before
the user can reach mute or the slider.

The progress component resolves fallback duration for the total-time label but
not for fill, hover, or seek calculations. When the playback duration stream is
temporarily zero or a rebuilt widget misses the last duration event, any
positive position is divided by a synthetic one-millisecond total and the track
can appear fully played while its label shows a valid duration.

## Product References

Heni adopts the stable desktop conventions shared by Apple Music and Spotify:

- shuffle and repeat are separate controls;
- active playback modes change color, while repeat-one uses a visible `1`;
- queue and volume remain utility controls instead of being combined with
  playback order;
- volume adjustment exposes a direct speaker/slider relationship;
- high-frequency actions have keyboard equivalents without requiring a menu.

References:

- <https://support.apple.com/en-mide/guide/music-windows/mus2989/windows>
- <https://support.spotify.com/md-en/article/now-playing/>
- <https://support.apple.com/en-gb/guide/music-windows/musa3fedf052/windows>
- <https://support.spotify.com/nl-en/article/keyboard-shortcuts/>

These references define interaction principles only. Heni retains its own
panoramic, theme-derived visual language.

## Goals

- Keep the full application window freely resizable within a usable range.
- Make sidebar expand and collapse actions available in every full-player
  state.
- Restore an expanded sidebar visibly instead of silently overriding it at
  startup.
- Separate shuffle and repeat into recognizable, direct controls.
- Make mute and volume adjustment reachable in one action.
- Use one coherent playback snapshot for progress text, fill, hover, drag, and
  seek.
- Preserve playback, queue, selection, and scroll state throughout layout
  changes.

## Non-Goals

- Freeform sidebar-width dragging.
- Raising the full-player minimum above `900 × 620`.
- Automatically shrinking the window when the sidebar collapses.
- Changing system volume, adding DSP, or adding an equalizer.
- Building a MiniPlayer as part of this change.
- Redesigning the queue dialog or the central play/pause button.

## Window And Sidebar Behavior

### Window Range And Restore

- Full-player minimum logical client size remains `900 × 620`.
- A new installation or invalid saved geometry uses `1280 × 720`, clamped to
  the current monitor work area when that area is smaller.
- The maximum usable size is the current monitor work area.
- Normal window position and size continue to be persisted.
- All thresholds and native resize requests use logical pixels and are scaled
  by the current monitor DPI at the Windows boundary.

### Responsive Policy

The sidebar keeps the existing two durable preferences:

```text
expanded
compact
```

Responsive compaction remains transient:

- enter forced compact mode at a client width of `1040` or less;
- release forced compact mode at a client width of `1140` or more;
- preserve the previous responsive state between those thresholds;
- on first layout, widths below `1080` begin compact and widths at or above
  `1080` use the saved preference.

Automatic compaction never overwrites the saved preference.

### Startup Reconciliation

Startup reconciliation waits for an explicit shell-preferences-restored signal;
the provider's in-memory default must not be treated as a hydrated user choice.
After persisted shell preferences are restored (including the no-config case):

- `compact` leaves the restored window size unchanged;
- `expanded` at `1140` or wider displays the expanded sidebar immediately;
- `expanded` below `1140` issues one request to enlarge the logical client
  width to at least `1140` before revealing the expanded sidebar.

This one-time reconciliation is guarded so provider rebuilds cannot trigger
repeated resize requests. Until it completes, the existing compact sidebar is
stable; no intermediate expanded overflow is painted.

### Manual Expand And Collapse

The expand control is never disabled.

When the user expands at a narrow width:

1. mark an expansion request as in progress and ignore repeated activation;
2. ask the Windows controller to ensure a client width of `1140` logical
   pixels;
3. clamp and reposition the resulting window inside the current monitor work
   area;
4. store the `expanded` preference and reveal the expanded sidebar after the
   native result returns.

If the channel fails or the monitor work area is narrower than `1140`, Heni
still honors the explicit expand action. A transient narrow-expansion override
bypasses forced compact mode, and the main workspace uses its existing compact
presentation. The override clears when the user collapses or when the window
reaches the normal release width.

Collapsing stores `compact` and changes only the sidebar. It never shrinks or
repositions the window.

Tooltips:

- normal compact state: `展开侧边栏`;
- narrow compact state: `展开侧边栏并调整窗口`;
- expanded state: `收起侧边栏`.

### Native Window Contract

`HeniWindowController` gains an operation equivalent to:

```dart
Future<HeniWindowResizeResult> ensureClientWidth(double logicalWidth)
```

The result reports the achieved logical client width and whether the requested
width was reached. Platform-channel errors return a failure result instead of
throwing into the widget tree.

The Windows runner scales the requested width for the current DPI, preserves
height, and chooses a horizontal position that keeps the complete window in
the nearest monitor work area. Existing minimum sizing, maximize state, drag,
Snap, and edge/corner resize behavior remain unchanged.

If the window is maximized, the runner does not restore it merely to satisfy an
expand request. It reports the existing client width; a narrow maximized work
area follows the explicit narrow-expansion fallback.

## Playback-Mode Controls

### Layout

Playback order moves into the central transport group:

```text
shuffle  previous  play/pause  next  repeat
```

The right utility group becomes:

```text
queue  volume
```

Shuffle and repeat use `38 × 38` logical hit targets. They have transparent
resting surfaces, a subtle circular hover/pressed fill, and no permanent
outlined capsule.

### State Presentation

- Disabled/unavailable: reduced-opacity secondary text color.
- Available but off: secondary text color.
- Active: the current palette accent plus a `3`-pixel state dot below the icon.
- Repeat-all: `repeat` icon in the active treatment.
- Repeat-one: `repeat_one` icon in the active treatment.
- State transitions use `120–160ms` ease-out color/opacity animation without
  bounce or layout movement.

Tooltips and semantics announce explicit state, for example `随机播放：已开启`,
`循环：关闭`, `循环：列表`, and `循环：单曲`. Mode changes do not create a
transient snackbar or other noisy overlay.

### State Model

Shuffle and repeat become independent operations:

- shuffle toggles `false ↔ true` and rebuilds playback order while preserving
  the current item and repeat mode;
- repeat cycles `none → all → one → none` while preserving shuffle and current
  order position;
- repeat-one takes precedence when the current item completes; shuffle remains
  enabled and becomes effective again when repeat leaves `one`.

The controls are disabled only when the playback queue is empty. Playback mode
state remains unchanged when the queue becomes empty.

### Persistence Compatibility

The library configuration gains optional independent fields for repeat mode and
shuffle. Valid new fields take priority. If they are absent, the existing
`playbackModeName` is migrated through the current four-value mapping. Invalid
values fall back to sequence playback without failing configuration restore.

Heni writes the new fields and retains the legacy derived field during the
compatibility period.

## Volume Interaction And Visual Design

### Inline Control

The full player replaces the menu-anchor popover with one quiet inline volume
cluster:

```text
speaker button  horizontal slider
```

- Speaker hit target: `38 × 38` logical pixels.
- Slider track: `88` logical pixels in normal layouts and no less than `64` in
  the supported compact full-player layout.
- Track height: `3` logical pixels.
- Resting thumb: `8` logical pixels; hover, focus, or drag thumb: `10`.
- The cluster has one low-contrast rounded background and no nested permanent
  borders.
- The active track uses the palette accent; the inactive track uses a quiet
  translucent neutral.
- Exact percentage appears in a small anchored tooltip while hovering,
  focusing, scrolling, or dragging. It does not occupy permanent dock width.

The inline slider remains present throughout the supported `900 × 620` full
window range. No second click is required to reveal it.

### Behavior

- Clicking the speaker toggles mute and restores the last audible volume.
- Dragging updates the engine live; releasing commits durable state.
- Mouse-wheel input over the cluster adjusts by `2` percentage points per
  notch.
- Keyboard arrow input while the slider is focused adjusts by `5` percentage
  points.
- `M` toggles mute when focus is not inside an editable text control.
- Values are clamped to `0–100`.

Volume state includes both current volume and last audible volume. Any value
above zero updates the last audible value. If no audible history exists, mute
restore uses `60`. Both values are persisted so restarting while muted does not
lose the restore target.

Wheel, keyboard, and drag interactions retain live feedback but use the
existing deferred persistence path to avoid rewriting configuration for every
intermediate value.

## Progress Data And Presentation

### Playback Snapshot

`PlaybackEngine` exposes synchronous current position and duration snapshots in
addition to its streams. `MediaKitPlaybackEngine` reads them from the current
player state, allowing newly mounted progress widgets to start from the actual
playback state instead of zero.

The progress component receives a media identity, the engine, and optional
metadata duration. It resolves a single snapshot:

```text
total = positive streamed duration
        else positive engine snapshot duration
        else positive metadata duration
        else unknown

position = streamed position or engine snapshot position
position = clamp(position, 0, total) when total is known
```

The same resolved `position` and `total` drive current-time text, total-time
text, fill fraction, hover time, drag preview, and seek target.

When total is unknown:

- the track remains unfilled rather than appearing complete;
- total text is `--:--`;
- hover and seek actions that require a duration are disabled;
- the current position may continue to display if it is known.

Changing media identity resets drag/hover state and prevents the previous
track's position or duration from painting for the new item.

### Dragging

During horizontal drag, a local fraction becomes the displayed source of
truth. Playback stream events continue to be observed but do not move the thumb
until drag end. Releasing performs one clamped seek and returns presentation to
the engine stream. Cancelling a drag discards the preview without seeking.

### Responsive Layout

Layout depends on the width received by the progress component:

- `280` or wider: fixed current time, flexible track, fixed total time;
- `180–279`: flexible track plus one fixed `current / total` label;
- below `180`: interactive track only, with hover/drag time feedback.

The thresholds reserve useful track width instead of switching merely because
time labels technically fit. Time text uses tabular figures and never paints
over the track.

## Component Boundaries

- `sidebar_mode.dart` owns pure responsive thresholds and transient override
  transitions.
- `adaptive_sidebar.dart` renders effective mode and dispatches explicit expand
  or collapse intent; it does not call the platform channel directly.
- `heni_window_controller.dart` owns safe logical-to-native window requests and
  failure results.
- `playback_queue_controller.dart` owns independent shuffle/repeat operations
  and durable mode persistence. It also exposes completion of persisted shell
  preference hydration so startup window reconciliation cannot run early.
- A focused playback-mode presentation component renders shuffle and repeat
  without owning queue state.
- `volume_control.dart` owns the inline interaction surface; durable volume
  state and persistence remain outside the widget.
- `player_progress.dart` owns snapshot resolution, responsive progress layout,
  and seek gestures.
- `player_screen.dart` composes these components and contains no new playback
  calculations.

## Error And Edge Handling

- A failed native resize never blocks sidebar expansion or playback.
- A monitor narrower than the preferred expansion width uses narrow expanded
  fallback without moving the window off-screen.
- Maximize/restore and DPI changes run through the same logical-width policy.
- Repeated expand clicks while resizing are ignored.
- Invalid persisted sidebar, repeat, shuffle, volume, or last-audible values use
  safe defaults.
- Playback stream errors preserve the last valid snapshot and leave the
  control usable when metadata duration is available.
- A missing duration never produces division by zero, a full progress bar, or
  an invalid seek.
- A zero-volume startup restores the persisted last audible value rather than
  an arbitrary widget-local value.

## Verification

### Automated

- Sidebar policy tests for initial width, hysteresis, explicit narrow expansion,
  and preference preservation.
- Window-controller channel tests for success, partial-width, and failure
  results.
- Widget tests proving the narrow expand button is enabled and dispatches a
  window-size request.
- Playback-controller tests proving shuffle preserves repeat, repeat preserves
  shuffle, current order position remains valid, and legacy persistence
  migrates correctly.
- Volume tests for direct mute/restore, persisted last-audible value, live drag,
  deferred commit, wheel clamping, and keyboard steps.
- Progress tests for synchronous snapshot seeding, metadata fallback, unknown
  duration, clamping, media reset, drag isolation, seek, and all three width
  layouts.
- Static analysis and Windows Debug and Release builds.

### Manual Windows QA

- Launch with no saved geometry and confirm `1280 × 720` with an expanded
  sidebar.
- Launch from a saved `900 × 620` window with expanded preference and confirm
  one automatic expansion to the safe width.
- Launch with compact preference and confirm the saved narrow size is retained.
- Shrink through both sidebar thresholds and confirm no flicker or preference
  loss.
- At minimum width, click expand and confirm the window grows and the sidebar
  opens; collapse must not shrink the window.
- Repeat the window checks at 100%, 150%, and 200% DPI and near monitor edges.
- Confirm shuffle and repeat are individually recognizable, clickable, and
  persistent across restart.
- Confirm the inline volume control works by click, drag, wheel, keyboard, and
  `M`, including restart while muted.
- Play, resize, switch tracks, and drag seek across known and initially unknown
  durations; the fill, times, tooltip, and actual seek target must agree.
- Confirm no overflow banners at `900 × 620` and no loss of queue, selection,
  sidebar scroll position, or active playback.

## Success Criteria

- The initial sidebar never presents an expansion action that is disabled by
  the restored window size.
- An explicit expand request always expands the sidebar and enlarges the window
  when the monitor allows it.
- Users can identify and change shuffle, list repeat, and single repeat without
  cycling through unrelated modes.
- Volume can be muted or adjusted directly from the dock without first opening
  a menu.
- Progress fill, labels, tooltip, drag preview, and seek target remain
  consistent for every track and supported window width.
- The result feels calmer and more legible than the current row of permanent
  glass capsules while remaining recognizably Heni.
