# Heni Adaptive Sidebar Design

## Context

Heni currently derives sidebar presentation from the shared `_ShellLayout.quiet`
flag:

```text
quiet = width < 1120 || height < 740
```

The default Windows size is `1280 × 720`, so the height condition makes the
sidebar compact even though the window has enough horizontal room. The compact
rail is also only about `58` logical pixels wide, which makes the default shell
feel compressed.

The player already enforces a DPI-aware minimum full-player client size of
`900 × 620`. The sidebar should use that supported range intentionally instead
of compressing the full navigation into arbitrary widths.

## Reference Pattern

The interaction follows mature desktop navigation patterns:

- Spotify Desktop shows an expanded library by default, permits an explicit
  compact icon view, and treats the side area as a customizable desktop surface.
- Apple desktop applications expose an explicit sidebar show/hide control
  instead of making the state depend on an unrelated window dimension.

References:

- <https://newsroom.spotify.com/2023-06-20/spotify-desktop-experience-redesign-your-library-now-playing-views-customize/>
- <https://support.apple.com/en-euro/guide/music-windows/mus2d264e327/windows>
- <https://support.apple.com/en-gb/guide/devices-windows/glos58b4f054/windows>

Heni adopts the same core principle: expanded navigation is the comfortable
default, compact navigation is a deliberate alternative, and responsive
constraints temporarily override preference only when necessary.

## Goals

- Make the expanded sidebar the default at the normal `1280 × 720` window size.
- Provide exactly two visible sidebar modes: expanded and compact.
- Allow users to switch modes freely whenever the window is wide enough.
- Force compact mode only when the content area would otherwise become unsafe.
- Restore the user's remembered preference after a temporary narrow-window
  override ends.
- Avoid mode flicker while the resize handle moves around a breakpoint.
- Keep the full player above its existing `900 × 620` minimum client size.

## Non-Goals

- A third user-facing `Auto` mode.
- Freeform drag resizing of the sidebar.
- Changing focus mode, MiniPlayer behavior, playback state, or queue behavior.
- Reorganizing playlists or adding new navigation destinations.

## Sidebar State Model

### User Preference

Persist a two-value preference:

```text
expanded
compact
```

The default for missing, invalid, or legacy configuration is `expanded`.

Manual toggle actions update and persist only this preference.

### Responsive Override

Maintain a transient `widthForcedCompact` state:

- Enter forced compact mode at a window content width of `1040` or less.
- Leave forced compact mode at a width of `1140` or more.
- Between `1040` and `1140`, retain the previous forced/not-forced state.
- On first layout with no previous responsive state:
  - below `1080`: start forced compact;
  - at or above `1080`: use the user preference.

The separate enter and exit thresholds provide hysteresis, preventing the
sidebar from repeatedly opening and closing when the user drags near one
boundary.

### Effective Mode

```text
effectiveMode =
  widthForcedCompact
    ? compact
    : userPreference
```

Automatic resizing never overwrites the stored preference.

Examples:

| Preference | Width condition | Effective mode | After widening |
| --- | --- | --- | --- |
| Expanded | Wide | Expanded | Expanded |
| Expanded | Forced narrow | Compact | Expanded |
| Compact | Wide | Compact | Compact |
| Compact | Forced narrow | Compact | Compact |

## Interaction Design

### Expanded Sidebar

- Width: `224` logical pixels.
- Primary destinations display icon, text label, and item count.
- Playlist entries display their playlist name and item count; text must not be
  replaced by icon-only navigation while expanded.
- Add a compact collapse button to the right of the `浏览` heading.
- Tooltip: `收起侧边栏`.
- Activating it changes the user preference to `compact`.
- Existing destinations, playlist counts, playlist menus, and status content
  remain available.

### Compact Sidebar

- Width: `72` logical pixels.
- The first control is an expand-sidebar button, followed by a short divider and
  the existing navigation destinations.
- Tooltip when expansion is allowed: `展开侧边栏`.
- Activating it changes the user preference to `expanded`.
- Destination buttons retain at least `42 × 42` logical hit targets, selection
  indicators, counts in tooltips, and playlist access through the existing
  popup.

### Forced Compact Feedback

When width forces compact mode:

- The expand control remains visible so the mode is understandable.
- It is visually disabled and does not change the stored preference.
- Tooltip: `窗口宽度不足，拉宽后可展开`.
- No toast is shown for hover or ordinary clicks; the tooltip is sufficient and
  avoids noisy feedback during resize.

### Animation

- Animate sidebar width and content replacement over `200` milliseconds with an
  ease-out curve.
- Do not animate the entire page or playback bar.
- Preserve the active playlist, selection, playback state, and expanded-list
  scroll position across mode changes.
- Ignore repeated toggle activation while the transition is running.

## Responsive Layout Rules

- Sidebar mode depends only on horizontal content width.
- Window height may still select denser headers, bottom bars, or vertical
  spacing, but it must not decide sidebar mode.
- The default `1280 × 720` window uses the expanded sidebar.
- The minimum `900 × 620` full-player window uses the compact sidebar.
- Content width and sidebar width must be calculated independently from the
  existing broad `compact`, `quiet`, and `narrow` flags.
- The main content panel expands into the released sidebar space without a
  second abrupt breakpoint.

## Persistence

Extend `HeniLibraryConfig` with an optional sidebar preference string.

- JSON field: `sidebarMode`.
- Accepted values: `expanded`, `compact`.
- Missing or invalid values resolve to `expanded`.
- `PlaybackQueueController.persistShellPreferences` accepts and writes the
  sidebar preference alongside palette, UI style, scenery paths, and volume.
- Restoring the preference must not mark the current responsive override as a
  manual action.

## Component Boundaries

Add focused sidebar behavior types outside the oversized player screen:

- `sidebar_mode.dart`
  - `HeniSidebarMode`;
  - responsive policy and hysteresis transition function;
  - provider/notifier for preference and transient forced state.
- Existing expanded and compact sidebar widgets remain presentation components
  in the current player screen for this focused change.

The layout receives an effective sidebar mode rather than inferring it from
`_ShellLayout.quiet`.

## Error And Edge Handling

- Invalid persisted values fall back to expanded mode.
- At startup, restored preference may arrive after the first frame; applying it
  must not flash the expanded sidebar when the window is already narrow.
- Maximizing or restoring the window runs through the same responsive policy.
- DPI changes use logical Flutter width, so no separate DPI threshold is needed.
- Focus mode may hide or alter surrounding content, but it must preserve the
  sidebar preference for return to the normal shell.
- If persistence fails, the current in-memory choice remains active and the
  existing non-blocking persistence error handling is used.

## Verification

### Automated

- Policy tests:
  - default preference is expanded;
  - width at or below `1040` forces compact;
  - width at or above `1140` releases the override;
  - widths inside the hysteresis band retain the previous state;
  - forced compact never changes the manual preference.
- Persistence round-trip tests for `expanded`, `compact`, missing, and invalid
  values.
- Widget/layout tests:
  - `1280 × 720` shows the expanded sidebar;
  - `900 × 620` shows the compact sidebar;
  - manual compact at wide width remains compact;
  - narrow then wide restores expanded preference;
  - forced compact exposes disabled expansion feedback;
  - no overflow at supported minimum size.

### Manual Windows QA

- Launch at the default size and confirm the sidebar is expanded.
- Toggle expanded/compact repeatedly and confirm controls stay aligned.
- Resize slowly across both thresholds and confirm there is no rapid flicker.
- Choose compact manually, resize narrow and wide, and confirm compact is
  restored.
- Choose expanded manually, resize narrow and wide, and confirm expanded is
  restored.
- Restart Heni in both preferences and confirm persistence.
- Verify sidebar tooltips, keyboard focus, and minimum-size progress layout.

## Success Criteria

- Heni no longer opens with an unexpectedly tiny left navigation rail.
- The user can choose expanded or compact navigation at normal widths.
- Narrow windows protect the content area without erasing the user's choice.
- Returning to a comfortable width produces a predictable sidebar state.
- Resizing feels stable, with no sidebar flicker, progress overlap, or layout
  overflow.
