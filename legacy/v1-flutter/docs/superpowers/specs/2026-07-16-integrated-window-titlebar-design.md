# Heni Integrated Windows Title Bar Design

## Goal

Remove the visually disconnected white Windows title bar and integrate window
controls into Heni's existing top navigation band. The result should look like
one continuous player surface while retaining expected desktop window behavior.

## Selected Direction

Use a fully client-drawn title bar on Windows:

- Remove the native caption area while retaining the system window, resize
  frame, minimize/maximize capability, taskbar integration, and `Alt+F4`.
- Place minimize, maximize/restore, and close controls at the far right of the
  existing Heni top navigation.
- Do not add another title strip or repeat the application icon and `heni`
  window title above the player.

Two alternatives were considered and rejected:

- A separate dark title strip would match the palette but still divide the
  shell into an outer window and inner application.
- Merely enabling a dark native caption would be lower risk, but its geometry
  and control styling would remain visibly unrelated to Heni.

## Visual Design

The controls will share the top navigation's current matte-glass material and
spacing:

- Each control is an icon-only rectangular target sized consistently with the
  palette and settings controls.
- Minimize and maximize use quiet foreground colors and a subtle hover fill.
- Close uses the same quiet default state, changing to a restrained red surface
  only while hovered.
- The maximize icon changes to the restore icon whenever the window is
  maximized.
- A low-contrast divider separates application actions from window controls.
- Compact layouts keep all three controls visible and reduce surrounding gaps
  before shrinking the search field.

## Window Interaction

The custom frame must preserve these behaviors:

- Dragging non-interactive areas of the top navigation moves the window.
- Double-clicking the drag area toggles maximize and restore.
- The window remains resizable from all edges and corners.
- Minimize, maximize/restore, close, taskbar activation, and `Alt+F4` continue
  to work.
- Maximizing respects the active monitor work area and DPI.
- Search, palette, settings, and other top-navigation controls remain
  interactive and must not accidentally begin a window drag.

## Architecture

### Windows Runner

The existing Win32 runner will own non-client behavior:

- Create a captionless resizable window with the normal minimize, maximize,
  system-menu, and taskbar styles.
- Handle non-client sizing and hit testing so resize borders remain reliable at
  every DPI.
- Expose a small platform channel for minimize, maximize/restore, close,
  drag-start, and current maximized state.
- Notify Flutter when `WM_SIZE` changes the maximized state so the icon remains
  correct even when the change did not originate from the Flutter button.

This keeps Windows-specific behavior in the runner instead of spreading Win32
assumptions through the player UI.

### Flutter Layer

Add a focused Windows window-control service and widget:

- The service wraps platform-channel calls and exposes maximized state.
- The widget renders the three controls and owns hover/pressed presentation.
- The existing top navigation places the widget after palette/settings actions.
- A drag-region widget invokes the native drag operation only from
  non-interactive surface areas.
- On non-Windows platforms the control widget and native drag behavior are not
  rendered.

## Failure Handling

- Platform-channel failures must not crash playback or navigation.
- A failed window action is ignored after reporting a debug message.
- If maximized-state notification is unavailable, the service queries native
  state after a maximize/restore request so the icon can recover.
- The native runner continues to use the standard close path, ensuring window
  state persistence and player disposal remain intact.

## Verification

Implementation is complete only after:

- Flutter static analysis succeeds.
- A Windows Debug build succeeds.
- Minimize, maximize, restore, close, drag, double-click maximize, and edge/
  corner resize are manually verified.
- Search, palette, settings, and window buttons remain independently clickable.
- The title bar is inspected at normal and high DPI in both wide and compact
  layouts.
- Screenshot QA shows no native white caption, duplicated app title, clipping,
  overflow, or control overlap.
- The currently running user-owned Release process is not terminated during
  verification.

## Scope

This change covers only the outer Windows frame and its integration with the
existing Heni top navigation. It does not redesign the library workspace,
playback controls, or color palettes again.
