# Progress Resize Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent bottom playback progress from disappearing, overlapping time labels, or entering an overflow state while the Windows player is resized.

**Architecture:** Enforce the already-approved `900 × 620` minimum full-player client size in the DPI-aware Win32 runner. Extract the progress presentation into a focused Flutter widget whose narrow policy always preserves the seek track and hides separate time labels when they cannot fit safely.

**Tech Stack:** Flutter/Dart, `flutter_test`, Windows Win32 C++, PowerShell runtime QA.

## Global Constraints

- Full-player minimum logical client size is `900 × 620`.
- Minimum sizing must scale with the current monitor DPI.
- The seek track remains interactive at every supported width.
- Time labels must never overlap the track or each other.
- Do not add a window-management dependency.
- Preserve current playback state and direct source playback.

---

### Task 1: Responsive progress widget

**Files:**
- Create: `lib/features/player/presentation/player_progress.dart`
- Create: `test/features/player/presentation/player_progress_test.dart`
- Modify: `lib/features/player/presentation/player_screen.dart`

**Interfaces:**
- Consumes: `PlaybackEngine`, `HeniPalette`, and an optional fallback `Duration`.
- Produces: `PlayerProgressWithTime`, with a keyed seek track for widget verification.

- [ ] **Step 1: Write the failing narrow-width widget test**

Pump `PlayerProgressWithTime` in a `120` logical-pixel box with a fake engine at
`00:30 / 04:00`. Assert that `ValueKey('player-progress-track')` exists and that
the combined compact time label is absent.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
flutter test test/features/player/presentation/player_progress_test.dart --reporter expanded
```

Expected: compilation failure because `player_progress.dart` and
`PlayerProgressWithTime` do not exist.

- [ ] **Step 3: Extract and implement the progress widget**

Move the progress stream handling, seek gestures, tooltip, formatting, and
painting into `player_progress.dart`. For widths below `150`, return only the
keyed interactive progress track. At wider sizes retain fixed stable time labels
on both sides of an `Expanded` track.

- [ ] **Step 4: Replace private player-screen progress usages**

Import `player_progress.dart`, replace both `_ProgressWithTime` instances with
`PlayerProgressWithTime`, and remove the extracted private progress classes and
helpers from `player_screen.dart`.

- [ ] **Step 5: Run the focused test and static analysis**

Run:

```powershell
flutter test test/features/player/presentation/player_progress_test.dart --reporter expanded
flutter analyze
```

Expected: focused test passes when the local Flutter listener is available;
analysis reports no issues.

### Task 2: DPI-aware native minimum size

**Files:**
- Create: `tool/verify_windows_minimum_size.ps1`
- Modify: `windows/runner/win32_window.cpp`

**Interfaces:**
- Consumes: the top-level Heni `HWND` and its current monitor DPI.
- Produces: Win32 minimum track dimensions whose client area is at least
  `900 × 620` logical pixels.

- [ ] **Step 1: Write and run the failing runtime check**

The PowerShell check launches the Debug executable, requests an extremely small
window through `SetWindowPos`, reads the resulting client rectangle, and exits
non-zero when its DPI-normalized width or height is below `900 × 620`.

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tool/verify_windows_minimum_size.ps1
```

Expected before the fix: FAIL because the current runner accepts an arbitrarily
small size.

- [ ] **Step 2: Handle `WM_GETMINMAXINFO`**

In `Win32Window::MessageHandler`, calculate a `900 × 620` logical client
rectangle at `GetDpiForWindow(hwnd)`, expand it with
`AdjustWindowRectExForDpi`, and assign the resulting dimensions to
`MINMAXINFO::ptMinTrackSize`.

- [ ] **Step 3: Rebuild and verify the native behavior**

Run:

```powershell
flutter build windows --debug
powershell -ExecutionPolicy Bypass -File tool/verify_windows_minimum_size.ps1
```

Expected: the build succeeds and the runtime check reports a client area of at
least `900 × 620` logical pixels.

### Task 3: Final regression and visual QA

**Files:**
- Modify: `logs/request-log.md`
- Modify: `logs/windows.md`

**Interfaces:**
- Consumes: the rebuilt Windows Debug executable.
- Produces: verification evidence and project history for the resize fix.

- [ ] **Step 1: Run final checks**

Run:

```powershell
flutter analyze
flutter test --reporter compact
flutter build windows --debug
git diff --check
```

Record any environment-level Flutter listener failure separately from test
assertion failures.

- [ ] **Step 2: Perform resize screenshot QA**

Attempt to resize below the minimum at the active monitor DPI, then capture the
minimum-sized player. Confirm there are no overflow banners and the progress
track and time labels remain separated.

- [ ] **Step 3: Update logs and commit**

Document the root cause, minimum-size enforcement, responsive progress fallback,
and verification results, then commit the source, tests, QA tool, and logs.
