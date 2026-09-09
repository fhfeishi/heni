# Heni Windows Full-Bleed Frame And Drag Design

## Goal

Remove the visible strip around the top of the captionless Windows window and
make window dragging discoverable across intentional, non-interactive parts of
the Heni top chrome. Search, theme, settings, and window-control interactions
must remain independent from dragging.

## Verified Root Cause

Runtime probing on the current Release window produced these results:

- outer window: `1180 × 760` logical pixels;
- client area: `1168 × 748` logical pixels;
- client origin: 6 logical pixels inside the window on the left and top;
- dragging the `heni` wordmark moved the window;
- dragging the search area did not move the window.

The 6-pixel strip is the standard non-client inset retained by
`WS_THICKFRAME`. Heni manually handles resize hit testing but does not currently
handle `WM_NCCALCSIZE`, so Flutter only paints the smaller client rectangle.
The drag behavior is limited because `_TopNavigation` wraps only the wordmark
with `HeniWindowDragRegion`; the search field consumes nearly all remaining
horizontal space.

## Selected Direction

Use a full-client custom frame with explicit Flutter drag zones.

Two alternatives were rejected:

- Merely hiding or recoloring the DWM border would leave the non-client inset
  and could still expose a strip during composition or DPI changes.
- Registering dynamic Flutter rectangles with native `WM_NCHITTEST` would give
  exact native caption hit testing, but adds cross-layer geometry state and is
  unnecessary while the existing native drag channel works reliably.

## Native Frame

The Win32 runner will:

- keep `WS_THICKFRAME`, minimize/maximize boxes, system menu, taskbar behavior,
  snapping, and the existing DPI-aware minimum size;
- handle `WM_NCCALCSIZE` so the client area fills the complete window bounds;
- retain the existing DPI-scaled `WM_NCHITTEST` edge and corner resize zones;
- suppress the DWM-drawn system border where supported, leaving Heni's own
  themed one-pixel border as the only visible frame;
- preserve the current maximized work-area behavior and remove the rounded
  Heni border while maximized.

The native fix is intentionally limited to non-client geometry. Playback,
storage, and media services do not change.

## Flutter Top Chrome

The top chrome will separate interactive and draggable regions:

- `heni` remains draggable and supports double-click maximize/restore.
- Search keeps pointer focus, text selection, and editing behavior.
- Theme, settings, minimize, maximize/restore, and close remain normal controls.
- At comfortable widths the search field receives a mature maximum width
  instead of expanding across every available pixel.
- Remaining horizontal chrome becomes a visible-by-layout but visually empty
  drag spacer using `HeniWindowDragRegion`.
- At narrow widths the spacer collapses before search or controls are removed;
  the `heni` wordmark remains the guaranteed drag target.

Dragging continues to enter the standard Win32 move loop through the existing
`beginDrag` platform call. No application content area below the top chrome
will move the window.

## Border Presentation

Windowed mode uses one restrained theme-derived pixel around the panoramic
canvas. The border will use the semantic shell border color without a separate
white/system stroke. Rounded clipping remains aligned with the Windows 11
window shape. Maximized mode uses square corners and no inset border.

## Failure Handling

- Unsupported DWM border attributes are best-effort and must not prevent window
  creation.
- If the drag platform call fails, playback and search continue to work; the
  existing controller error handling remains in place.
- Resize hit testing takes precedence over dragging at the outer edges and
  corners.

## Verification

Implementation is complete only after:

- a native regression probe fails before the fix when client and window bounds
  differ, then passes with zero client inset;
- a widget regression specification confirms wide chrome contains a dedicated
  drag spacer while narrow chrome preserves interactive controls;
- Flutter static analysis and Windows Debug/Release builds succeed;
- native input simulation moves the window from `heni` and the wide drag
  spacer, but not from the search field;
- edge/corner resize, Windows snapping, double-click maximize, custom maximize/
  restore, and the `900 × 620` minimum client size remain functional;
- DPI-aware screenshots at wide and minimum widths show no top strip, duplicate
  border, overflow banner, or clipped corner.

The local Flutter widget-test harness remains subject to the documented
loopback-listener limitation. Static analysis, build results, and native runtime
probes must be recorded without claiming the blocked suite passed.

## Scope

This change covers only the Windows non-client frame, the one-pixel panoramic
border, and top-chrome drag geometry. It does not redesign playback controls,
library content, themes, or audio behavior.
