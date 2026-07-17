# Windows Full-Bleed Frame And Drag Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the six-pixel Windows non-client strip and add a deliberate wide-window drag spacer without stealing pointer interaction from search or controls.

**Architecture:** Keep the captionless `WS_THICKFRAME` top-level window, but make its client area fill the complete window through `WM_NCCALCSIZE` and suppress the DWM system border. Add a focused Flutter `HeniTopChromeCenter` layout component that caps the search width only when enough space exists and assigns the remainder to the existing native-backed drag widget.

**Tech Stack:** Flutter 3.41.9, Dart 3.11.5, Riverpod, Win32 C++, DWM, PowerShell native probes.

## Global Constraints

- Windows remains the active platform and the minimum full-player client size remains exactly `900 × 620` logical pixels.
- Keep `WS_THICKFRAME`, edge/corner resizing, snapping, minimize, maximize/restore, close, taskbar integration, and `Alt+F4`.
- Search, theme, settings, and window controls must never become drag targets.
- `heni` and the explicit wide-window spacer are drag targets and retain double-click maximize/restore.
- Only Heni's theme-derived one-pixel border may remain visible in windowed mode; maximized mode stays flush and square.
- Do not change playback, DSP, media opening, probing, storage, lyrics, or export behavior.
- Do not report the blocked Flutter widget suite as passing; record the host loopback limitation and use static analysis, Windows builds, and native probes.

---

## File Map

- Create `tool/verify_windows_chrome.ps1`: repeatable client-inset and pointer-drag runtime probe.
- Modify `windows/runner/win32_window.cpp`: full-client non-client sizing and DWM border suppression.
- Modify `lib/features/player/presentation/player_window_chrome.dart`: reusable responsive search/drag center layout.
- Modify `lib/features/player/presentation/player_screen.dart`: integrate the new center layout into `_TopNavigation`.
- Modify `lib/features/player/presentation/player_shell_frame.dart`: replace the decorative edge gradient with one semantic border color.
- Modify `test/features/player/presentation/player_window_chrome_test.dart`: specify wide drag spacer and narrow search behavior.
- Modify `test/features/player/presentation/player_shell_frame_test.dart`: specify the one-color windowed border.
- Modify `logs/windows.md` and `logs/request-log.md`: record the diagnosis, implementation, verification, and remaining test-environment limitation.

---

### Task 1: Make The Win32 Client Area Full-Bleed

**Files:**
- Create: `tool/verify_windows_chrome.ps1`
- Modify: `windows/runner/win32_window.cpp:15-35, 370-430, 550-570`

**Interfaces:**
- Consumes: top-level Heni `HWND`, existing `kHeniWindowStyle`, `WM_NCHITTEST`, and `GetDpiForWindow` behavior.
- Produces: zero logical inset between `GetWindowRect` and the client origin, with client width/height equal to outer width/height.

- [ ] **Step 1: Create the failing native frame probe**

Create `tool/verify_windows_chrome.ps1` with a Release/Debug executable parameter, launch Heni, wait for its top-level handle, size it to `1180 × 760`, and compare window and client geometry:

```powershell
param(
  [string]$Executable = (
    Join-Path $PSScriptRoot '..\build\windows\x64\runner\Debug\heni.exe'
  )
)

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class HeniChromeProbe {
  [StructLayout(LayoutKind.Sequential)]
  public struct RECT { public int Left, Top, Right, Bottom; }

  [StructLayout(LayoutKind.Sequential)]
  public struct POINT { public int X, Y; }

  [DllImport("user32.dll")]
  public static extern bool GetWindowRect(IntPtr window, out RECT rect);

  [DllImport("user32.dll")]
  public static extern bool GetClientRect(IntPtr window, out RECT rect);

  [DllImport("user32.dll")]
  public static extern bool ClientToScreen(IntPtr window, ref POINT point);

  [DllImport("user32.dll")]
  public static extern bool SetWindowPos(
    IntPtr window, IntPtr after, int x, int y, int width, int height, uint flags
  );
}
'@

$process = Start-Process -FilePath (Resolve-Path $Executable).Path -PassThru
try {
  $handle = [IntPtr]::Zero
  for ($attempt = 0; $attempt -lt 120; $attempt++) {
    Start-Sleep -Milliseconds 100
    $process.Refresh()
    if ($process.HasExited) {
      throw "Heni exited before creating a window: $($process.ExitCode)."
    }
    $handle = $process.MainWindowHandle
    if ($handle -ne [IntPtr]::Zero) { break }
  }
  if ($handle -eq [IntPtr]::Zero) { throw 'Heni window was not created.' }

  [HeniChromeProbe]::SetWindowPos(
    $handle, [IntPtr]::Zero, 50, 50, 1180, 760, 0x0040
  ) | Out-Null
  Start-Sleep -Seconds 2

  $windowRect = New-Object HeniChromeProbe+RECT
  $clientRect = New-Object HeniChromeProbe+RECT
  $origin = New-Object HeniChromeProbe+POINT
  [HeniChromeProbe]::GetWindowRect($handle, [ref]$windowRect) | Out-Null
  [HeniChromeProbe]::GetClientRect($handle, [ref]$clientRect) | Out-Null
  [HeniChromeProbe]::ClientToScreen($handle, [ref]$origin) | Out-Null

  $outerWidth = $windowRect.Right - $windowRect.Left
  $outerHeight = $windowRect.Bottom - $windowRect.Top
  $leftInset = $origin.X - $windowRect.Left
  $topInset = $origin.Y - $windowRect.Top
  Write-Output (
    "Heni chrome geometry: outer=${outerWidth}x${outerHeight} " +
    "client=$($clientRect.Right)x$($clientRect.Bottom) " +
    "inset=L${leftInset}/T${topInset}"
  )

  if (
    $leftInset -ne 0 -or $topInset -ne 0 -or
    $clientRect.Right -ne $outerWidth -or
    $clientRect.Bottom -ne $outerHeight
  ) {
    throw 'Heni client area does not fill the top-level window.'
  }
} finally {
  if (-not $process.HasExited) { Stop-Process -Id $process.Id }
}
```

- [ ] **Step 2: Run the probe and verify the existing Release fails**

Run:

```powershell
& tool/verify_windows_chrome.ps1 `
  -Executable build/windows/x64/runner/Release/heni.exe
```

Expected: FAIL with `inset=L6/T6` and `Heni client area does not fill the top-level window.`

- [ ] **Step 3: Add the minimal Win32 full-client behavior**

In `windows/runner/win32_window.cpp`, add SDK fallbacks:

```cpp
#ifndef DWMWA_BORDER_COLOR
#define DWMWA_BORDER_COLOR 34
#endif

#ifndef DWMWA_COLOR_NONE
#define DWMWA_COLOR_NONE 0xFFFFFFFE
#endif
```

Handle non-client calculation before `WM_DPICHANGED`, preserving the monitor
work area while maximized:

```cpp
case WM_NCCALCSIZE:
  if (wparam == TRUE) {
    if (IsZoomed(hwnd)) {
      auto* params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
      const HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
      MONITORINFO monitor_info{sizeof(MONITORINFO)};
      if (GetMonitorInfo(monitor, &monitor_info)) {
        params->rgrc[0] = monitor_info.rcWork;
      }
    }
    return 0;
  }
  break;
```

Because client and outer geometry are now identical in restored mode, replace
the `AdjustWindowRectExForDpi` branch in `EnsureMinimumClientSize` with:

```cpp
SetWindowPos(window, nullptr, 0, 0,
             std::max(client_width, minimum_width),
             std::max(client_height, minimum_height),
             SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
```

Likewise, replace the `WM_GETMINMAXINFO` adjusted-frame calculation with the
exact full-client tracking size:

```cpp
min_max_info->ptMinTrackSize.x =
    Scale(kMinimumLogicalClientWidth, scale_factor);
min_max_info->ptMinTrackSize.y =
    Scale(kMinimumLogicalClientHeight, scale_factor);
```

At the end of `Win32Window::UpdateTheme`, suppress the DWM stroke without
failing window creation on unsupported Windows versions:

```cpp
const COLORREF border_color = DWMWA_COLOR_NONE;
DwmSetWindowAttribute(window, DWMWA_BORDER_COLOR, &border_color,
                      sizeof(border_color));
```

Do not alter `kHeniWindowStyle` or the existing resize hit testing.

- [ ] **Step 4: Build Debug and verify the frame probe passes**

Run:

```powershell
flutter build windows --debug
& tool/verify_windows_chrome.ps1 `
  -Executable build/windows/x64/runner/Debug/heni.exe
```

Expected: build exit 0 and probe output `inset=L0/T0`, with client dimensions equal to outer dimensions.

- [ ] **Step 5: Re-run the existing minimum-size probe**

Run:

```powershell
& tool/verify_windows_minimum_size.ps1 `
  -Executable build/windows/x64/runner/Debug/heni.exe
```

Expected: `900 × 620` in the current DPI-virtualized probe and exit 0.

- [ ] **Step 6: Commit the native frame fix**

```powershell
git add tool/verify_windows_chrome.ps1 windows/runner/win32_window.cpp
git commit -m "fix: remove Windows non-client frame gap"
```

---

### Task 2: Add A Dedicated Responsive Drag Spacer

**Files:**
- Modify: `test/features/player/presentation/player_window_chrome_test.dart`
- Modify: `lib/features/player/presentation/player_window_chrome.dart`
- Modify: `lib/features/player/presentation/player_screen.dart:1740-1810`
- Modify: `tool/verify_windows_chrome.ps1`

**Interfaces:**
- Consumes: `HeniWindowDragRegion`, `_TopSearchField`, and the `heni/window` `beginDrag` method.
- Produces: `HeniTopChromeCenter({required Widget search})` and key `ValueKey('heni-top-chrome-drag-spacer')`.

- [ ] **Step 1: Write the failing wide/narrow widget specifications**

Append to `test/features/player/presentation/player_window_chrome_test.dart`:

```dart
testWidgets('wide top chrome exposes drag spacer without stealing search', (
  tester,
) async {
  final focusNode = FocusNode();
  addTearDown(focusNode.dispose);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Center(
          child: SizedBox(
            width: 800,
            height: 48,
            child: HeniTopChromeCenter(
              search: TextField(
                key: const ValueKey('chrome-search'),
                focusNode: focusNode,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  methods.clear();

  expect(
    find.byKey(const ValueKey('heni-top-chrome-drag-spacer')),
    findsOneWidget,
  );
  await tester.tap(find.byKey(const ValueKey('chrome-search')));
  await tester.pump();
  expect(focusNode.hasFocus, isTrue);
  expect(methods, isNot(contains('beginDrag')));

  await tester.drag(
    find.byKey(const ValueKey('heni-top-chrome-drag-spacer')),
    const Offset(40, 0),
  );
  await tester.pump();
  expect(methods, contains('beginDrag'));
});

testWidgets('narrow top chrome gives all center width to search', (
  tester,
) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(
        home: Center(
          child: SizedBox(
            width: 560,
            height: 48,
            child: HeniTopChromeCenter(
              search: SizedBox(key: ValueKey('chrome-search')),
            ),
          ),
        ),
      ),
    ),
  );

  expect(
    find.byKey(const ValueKey('heni-top-chrome-drag-spacer')),
    findsNothing,
  );
  expect(tester.getSize(find.byKey(const ValueKey('chrome-search'))).width, 560);
});
```

- [ ] **Step 2: Run the focused test and verify it fails for the missing widget**

Run:

```powershell
flutter test test/features/player/presentation/player_window_chrome_test.dart
```

Expected in a healthy Flutter test environment: compile failure because `HeniTopChromeCenter` is undefined. On this machine, record the known loopback failure if it occurs before compilation and additionally run `flutter analyze` after the test file is saved to confirm the missing API error.

- [ ] **Step 3: Implement the minimal center layout**

Add to `player_window_chrome.dart`:

```dart
class HeniTopChromeCenter extends StatelessWidget {
  const HeniTopChromeCenter({required this.search, super.key});

  static const dragSpacerBreakpoint = 720.0;
  static const searchMaxWidth = 640.0;
  static const minimumDragWidth = 84.0;
  static const searchToDragGap = 12.0;

  final Widget search;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        if (available < dragSpacerBreakpoint) {
          return SizedBox(width: available, child: search);
        }

        final searchWidth = (available - minimumDragWidth - searchToDragGap)
            .clamp(0.0, searchMaxWidth)
            .toDouble();
        return Row(
          children: [
            SizedBox(width: searchWidth, child: search),
            const SizedBox(width: searchToDragGap),
            const Expanded(
              child: HeniWindowDragRegion(
                key: ValueKey('heni-top-chrome-drag-spacer'),
                child: SizedBox.expand(),
              ),
            ),
          ],
        );
      },
    );
  }
}
```

In `_TopNavigation`, replace the expanded search block with:

```dart
Expanded(
  child: HeniTopChromeCenter(
    search: Padding(
      padding: EdgeInsets.only(
        left: layout.narrow ? 8 : 18,
        right: layout.narrow ? 8 : 12,
      ),
      child: _TopSearchField(layout: layout),
    ),
  ),
),
```

Keep the existing draggable `_TopBrand` and all action widgets outside this component.

- [ ] **Step 4: Run formatting and static analysis**

Run:

```powershell
dart format `
  lib/features/player/presentation/player_window_chrome.dart `
  lib/features/player/presentation/player_screen.dart `
  test/features/player/presentation/player_window_chrome_test.dart
flutter analyze
```

Expected: formatted files and `No issues found!`.

- [ ] **Step 5: Extend the native probe with input behavior**

Load the assemblies before `Add-Type`:

```powershell
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
```

Add these APIs inside the `HeniChromeProbe` C# type:

```csharp
[DllImport("user32.dll")]
public static extern bool SetForegroundWindow(IntPtr window);

[DllImport("user32.dll")]
public static extern void mouse_event(
  uint flags, uint x, uint y, uint data, UIntPtr extraInfo
);
```

Add this helper after the type definition:

```powershell
function Invoke-HeniDrag(
  [IntPtr]$Handle,
  [int]$RelativeX,
  [int]$RelativeY,
  [int]$DeltaX = 180,
  [int]$DeltaY = 90
) {
  $before = New-Object HeniChromeProbe+RECT
  [HeniChromeProbe]::GetWindowRect($Handle, [ref]$before) | Out-Null
  [HeniChromeProbe]::SetForegroundWindow($Handle) | Out-Null
  $startX = $before.Left + $RelativeX
  $startY = $before.Top + $RelativeY
  [System.Windows.Forms.Cursor]::Position =
    [System.Drawing.Point]::new($startX, $startY)
  [HeniChromeProbe]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  for ($step = 1; $step -le 12; $step++) {
    $x = [Math]::Round($startX + ($DeltaX * $step / 12))
    $y = [Math]::Round($startY + ($DeltaY * $step / 12))
    [System.Windows.Forms.Cursor]::Position =
      [System.Drawing.Point]::new($x, $y)
    Start-Sleep -Milliseconds 25
  }
  [HeniChromeProbe]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 600

  $after = New-Object HeniChromeProbe+RECT
  [HeniChromeProbe]::GetWindowRect($Handle, [ref]$after) | Out-Null
  return $after.Left -ne $before.Left -or $after.Top -ne $before.Top
}

function Reset-HeniWindow([IntPtr]$Handle) {
  [HeniChromeProbe]::SetWindowPos(
    $Handle, [IntPtr]::Zero, 50, 50, 1180, 760, 0x0040
  ) | Out-Null
  Start-Sleep -Milliseconds 500
}
```

After the zero-inset check, reset the window before each probe and verify these
logical points in the `1180 × 760` window:

```powershell
# Relative coordinates inside the Heni top chrome.
$brandPoint = [System.Drawing.Point]::new(42, 32)
$searchPoint = [System.Drawing.Point]::new(360, 32)
$spacerPoint = [System.Drawing.Point]::new(820, 32)

# Expected results after a 180x90 pointer drag:
# brand: window origin changes
# search: window origin remains (50, 50)
# spacer: window origin changes
```

Add the exact assertions:

```powershell
Reset-HeniWindow $handle
$brandMoved = Invoke-HeniDrag $handle $brandPoint.X $brandPoint.Y
Reset-HeniWindow $handle
$searchMoved = Invoke-HeniDrag $handle $searchPoint.X $searchPoint.Y
Reset-HeniWindow $handle
$spacerMoved = Invoke-HeniDrag $handle $spacerPoint.X $spacerPoint.Y
$searchProtected = -not $searchMoved

Write-Output (
  "Heni drag results: brand=$brandMoved " +
  "searchProtected=$searchProtected spacer=$spacerMoved"
)
if (-not $brandMoved -or -not $searchProtected -or -not $spacerMoved) {
  throw 'Heni top-chrome drag regions do not match the interaction contract.'
}
```

- [ ] **Step 6: Build Debug and run the complete chrome probe**

Run:

```powershell
flutter build windows --debug
& tool/verify_windows_chrome.ps1 `
  -Executable build/windows/x64/runner/Debug/heni.exe
```

Expected: zero inset plus `brand=True searchProtected=True spacer=True`.

- [ ] **Step 7: Commit the top-chrome drag layout**

```powershell
git add `
  lib/features/player/presentation/player_window_chrome.dart `
  lib/features/player/presentation/player_screen.dart `
  test/features/player/presentation/player_window_chrome_test.dart `
  tool/verify_windows_chrome.ps1
git commit -m "fix: add deliberate top chrome drag region"
```

---

### Task 3: Reduce The Flutter Frame To One Semantic Pixel

**Files:**
- Modify: `test/features/player/presentation/player_shell_frame_test.dart`
- Modify: `lib/features/player/presentation/player_shell_frame.dart`

**Interfaces:**
- Consumes: `HeniShellTheme.border` and `HeniPanoramicShellFrame.isMaximized`.
- Produces: a solid `shellTheme.border.withValues(alpha: 0.64)` outer pixel in windowed mode and zero padding when maximized.

- [ ] **Step 1: Write the failing border-presentation assertion**

After pumping the restored shell in `player_shell_frame_test.dart`, add:

```dart
final decoration = tester
    .widget<AnimatedContainer>(
      find.byKey(const ValueKey('heni-panoramic-frame')),
    )
    .decoration! as BoxDecoration;
expect(decoration.gradient, isNull);
expect(decoration.color, shell.border.withValues(alpha: 0.64));
```

- [ ] **Step 2: Run the focused test and verify the current gradient fails**

Run:

```powershell
flutter test test/features/player/presentation/player_shell_frame_test.dart
```

Expected in a healthy environment: FAIL because `decoration.gradient` is a `LinearGradient`. On this machine, if the harness fails first, run `flutter analyze` and retain the test as the executable regression specification.

- [ ] **Step 3: Replace the edge gradient with the semantic border color**

In `HeniPanoramicShellFrame.build`, change only the decoration:

```dart
decoration: BoxDecoration(
  color: shellTheme.border.withValues(alpha: 0.64),
  borderRadius: BorderRadius.circular(radius),
),
```

Keep the existing one-pixel padding, animated radius, inner clip radius, and maximized zero padding.

- [ ] **Step 4: Format, analyze, and build Debug**

Run:

```powershell
dart format `
  lib/features/player/presentation/player_shell_frame.dart `
  test/features/player/presentation/player_shell_frame_test.dart
flutter analyze
flutter build windows --debug
```

Expected: no analysis issues and a successful Debug executable.

- [ ] **Step 5: Commit the border polish**

```powershell
git add `
  lib/features/player/presentation/player_shell_frame.dart `
  test/features/player/presentation/player_shell_frame_test.dart
git commit -m "style: simplify panoramic window border"
```

---

### Task 4: Release Verification And Project Record

**Files:**
- Modify: `logs/windows.md`
- Modify: `logs/request-log.md`

**Interfaces:**
- Consumes: final Debug/Release executables and both PowerShell probes.
- Produces: normal-workspace Release evidence and a clean committed branch.

- [ ] **Step 1: Run all available automated gates**

Run:

```powershell
dart format --output=none --set-exit-if-changed lib test
dart test `
  test/services/files/local_file_actions_test.dart `
  test/features/player/presentation/playback_queue_location_test.dart
flutter analyze
flutter build windows --debug
flutter build windows --release
```

Expected: formatting exit 0, 8 pure-Dart tests pass, analysis has no issues, and both builds succeed.

- [ ] **Step 2: Run native frame, drag, and minimum-size probes on Release**

Run:

```powershell
& tool/verify_windows_chrome.ps1 `
  -Executable build/windows/x64/runner/Release/heni.exe
& tool/verify_windows_minimum_size.ps1 `
  -Executable build/windows/x64/runner/Release/heni.exe
```

Expected: zero client inset; brand and spacer drag; protected search; minimum result at least `900 × 620`.

- [ ] **Step 3: Verify remaining native interactions and capture screenshots**

Use the established DPI-aware `PrintWindow` probe to capture:

- `build/visual-check/final-full-bleed-frame-wide.png` at `1180 × 760`;
- `build/visual-check/final-full-bleed-frame-minimum.png` after requesting `220 × 300`.

Inspect both images for a continuous panoramic top edge, a single semantic
border, preserved search/actions, compact navigation at minimum width, and no
overflow banner. Simulate the custom maximize button and restore button and
require `IsZoomed` to change `false → true → false`. Manually drag each outer
edge and corner once, then drag the restored window to the screen edge and
confirm the Windows Snap preview appears without losing the Heni client frame.

- [ ] **Step 4: Update Strata execution records**

Append a dated `2026-07-17 - Full-Bleed Windows Frame And Drag Zones` entry to
both logs. Record:

- verified 6-pixel non-client root cause;
- `WM_NCCALCSIZE` full-client fix and best-effort DWM border suppression;
- explicit wide drag spacer and protected search behavior;
- simplified one-pixel theme border;
- exact static-analysis/build/native-probe results;
- the Flutter loopback limitation without claiming widget tests passed.

- [ ] **Step 5: Check the final diff and commit the verification record**

Run:

```powershell
git diff --check
git status --short
git diff --stat
git add logs/windows.md logs/request-log.md
git commit -m "docs: record full-bleed frame verification"
```

Expected: no whitespace errors, only intended files, and a successful commit. Do not push unless the user explicitly requests it.
