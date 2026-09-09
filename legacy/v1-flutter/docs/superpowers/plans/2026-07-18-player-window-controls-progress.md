# Player Window, Controls, And Progress Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the full Windows player resize safely, keep sidebar expansion actionable, replace the combined playback-mode button with mature shuffle/repeat controls, expose inline volume, and correct progress state calculations.

**Architecture:** Keep responsive policy and playback calculations in focused Dart units, use the existing Riverpod queue controller for durable preferences, and extend the existing `heni/window` channel for one DPI-aware window-width operation. `player_screen.dart` remains the composition root while new playback-mode UI and existing sidebar, volume, and progress components own their narrow presentation behavior.

**Tech Stack:** Flutter/Dart, Riverpod, `media_kit`, `flutter_test`, Windows Win32 C++, Flutter Windows method channels, PowerShell runtime verification.

## Global Constraints

- Full-player minimum logical client size remains `900 × 620`.
- New or invalid window geometry starts at `1280 × 720`, clamped to the monitor work area.
- Sidebar forced compact thresholds are `1040` enter, `1140` release, and `1080` initial.
- Sidebar expand is never disabled; failed or constrained native resizing still honors explicit expansion.
- Shuffle and repeat remain independent and preserve the current queue item.
- Volume remains clamped to `0–100`; mute restores the persisted last audible value, defaulting to `60` only when no history exists.
- Progress text, fill, hover, drag, and seek use the same resolved position and duration.
- Do not add dependencies, DSP, system-volume control, MiniPlayer work, or freeform sidebar resizing.
- Preserve current playback, queue, selected playlist, sidebar scroll position, custom frame behavior, and active theme.

---

## File Map

- `lib/services/window/heni_window_controller.dart`: typed Dart result and safe window-width request.
- `windows/runner/win32_window.h` / `windows/runner/win32_window.cpp`: DPI-aware client-width resizing constrained to the monitor work area.
- `windows/runner/flutter_window.cpp`: `ensureClientWidth` method-channel decoding and result encoding.
- `lib/features/player/application/sidebar_mode.dart`: sidebar thresholds and persisted-preference hydration signal.
- `lib/features/player/presentation/adaptive_sidebar.dart`: startup reconciliation, explicit expansion, and narrow fallback override.
- `lib/services/storage/heni_library_store.dart`: independent repeat/shuffle and last-audible-volume JSON fields with legacy migration.
- `lib/features/player/application/playback_queue_controller.dart`: independent mode transitions, volume memory, and restore completion.
- `lib/features/player/presentation/playback_mode_controls.dart`: focused shuffle/repeat visual component.
- `lib/features/player/presentation/volume_control.dart`: inline volume cluster.
- `lib/services/media/playback_engine.dart` / `lib/services/media/media_kit_playback_engine.dart`: synchronous position/duration snapshots.
- `lib/features/player/presentation/player_progress.dart`: coherent progress snapshot and three responsive layouts.
- `lib/features/player/presentation/player_screen.dart`: composition, `M` shortcut, and final dock ordering.

---

### Task 1: Typed DPI-Aware Window Width Request

**Files:**
- Modify: `test/services/window/heni_window_controller_test.dart`
- Modify: `lib/services/window/heni_window_controller.dart`
- Modify: `windows/runner/win32_window.h`
- Modify: `windows/runner/win32_window.cpp`
- Modify: `windows/runner/flutter_window.cpp`

**Interfaces:**
- Consumes: logical client width from Flutter and the nearest Win32 monitor work area.
- Produces: `HeniWindowResizeResult(achievedLogicalWidth, reachedRequestedWidth)` from `HeniWindowController.ensureClientWidth(double)`.

- [ ] **Step 1: Write failing Dart channel-result tests**

Add this mock handling and these assertions:

```dart
if (call.method == 'ensureClientWidth') {
  expect(call.arguments, {'logicalWidth': 1140.0});
  return <String, Object?>{
    'achievedLogicalWidth': 1140.0,
    'reachedRequestedWidth': true,
  };
}

final result = await controller.ensureClientWidth(1140);
expect(result.achievedLogicalWidth, 1140);
expect(result.reachedRequestedWidth, isTrue);
```

Add a second test whose channel throws `PlatformException`; expect
`HeniWindowResizeResult.failure` with `reachedRequestedWidth == false` and no
uncaught exception.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
flutter test test/services/window/heni_window_controller_test.dart --reporter expanded
```

Expected when the local Flutter listener is available: compilation fails because
`HeniWindowResizeResult` and `ensureClientWidth` do not exist. If Windows error
121 prevents suite loading, record that environment failure and run
`flutter analyze` after Step 3 to verify the same missing symbols before
continuing.

- [ ] **Step 3: Implement the Dart contract**

Add this public value type and controller operation:

```dart
class HeniWindowResizeResult {
  const HeniWindowResizeResult({
    required this.achievedLogicalWidth,
    required this.reachedRequestedWidth,
  });

  const HeniWindowResizeResult.failure()
    : achievedLogicalWidth = 0,
      reachedRequestedWidth = false;

  final double achievedLogicalWidth;
  final bool reachedRequestedWidth;
}

Future<HeniWindowResizeResult> ensureClientWidth(double logicalWidth) async {
  try {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'ensureClientWidth',
      <String, Object?>{'logicalWidth': logicalWidth},
    );
    return HeniWindowResizeResult(
      achievedLogicalWidth:
          (result?['achievedLogicalWidth'] as num?)?.toDouble() ?? 0,
      reachedRequestedWidth:
          result?['reachedRequestedWidth'] == true,
    );
  } on PlatformException catch (error) {
    debugPrint('Heni window resize failed: $error');
    return const HeniWindowResizeResult.failure();
  } on MissingPluginException catch (error) {
    debugPrint('Heni window resize unavailable: $error');
    return const HeniWindowResizeResult.failure();
  }
}
```

- [ ] **Step 4: Implement the native width operation**

Declare a protected result and method on `Win32Window`:

```cpp
struct ClientWidthResult {
  double achieved_logical_width = 0.0;
  bool reached_requested_width = false;
};

ClientWidthResult EnsureClientWidth(int logical_width);
```

Implement the method as:

```cpp
Win32Window::ClientWidthResult Win32Window::EnsureClientWidth(
    int logical_width) {
  ClientWidthResult result;
  if (window_handle_ == nullptr || logical_width <= 0) {
    return result;
  }

  const UINT dpi = GetDpiForWindow(window_handle_);
  const double scale = static_cast<double>(dpi) / 96.0;
  auto read_result = [&]() {
    RECT client{};
    if (!GetClientRect(window_handle_, &client)) {
      return ClientWidthResult{};
    }
    const double achieved =
        static_cast<double>(client.right - client.left) / scale;
    return ClientWidthResult{
        achieved, achieved + 0.5 >= static_cast<double>(logical_width)};
  };

  ClientWidthResult current = read_result();
  if (current.reached_requested_width || IsZoomed(window_handle_)) {
    return current;
  }

  RECT window_rect{};
  RECT client_rect{};
  if (!GetWindowRect(window_handle_, &window_rect) ||
      !GetClientRect(window_handle_, &client_rect)) {
    return current;
  }
  const HMONITOR monitor =
      MonitorFromWindow(window_handle_, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info{sizeof(MONITORINFO)};
  if (!GetMonitorInfo(monitor, &monitor_info)) {
    return current;
  }

  const int current_window_width = window_rect.right - window_rect.left;
  const int current_window_height = window_rect.bottom - window_rect.top;
  const int current_client_width = client_rect.right - client_rect.left;
  const int non_client_width = current_window_width - current_client_width;
  const int work_width =
      monitor_info.rcWork.right - monitor_info.rcWork.left;
  const int requested_window_width =
      Scale(logical_width, scale) + non_client_width;
  const int target_width = std::min(requested_window_width, work_width);
  const int latest_left = monitor_info.rcWork.right - target_width;
  const int target_left = std::clamp(
      window_rect.left, monitor_info.rcWork.left, latest_left);
  const int work_height =
      monitor_info.rcWork.bottom - monitor_info.rcWork.top;
  const int target_height = std::min(current_window_height, work_height);
  const int latest_top = monitor_info.rcWork.bottom - target_height;
  const int target_top = std::clamp(
      window_rect.top, monitor_info.rcWork.top, latest_top);

  SetWindowPos(window_handle_, nullptr, target_left, target_top,
               target_width, target_height,
               SWP_NOZORDER | SWP_NOACTIVATE);
  return read_result();
}
```

Decode `{'logicalWidth': number}` in `FlutterWindow::RegisterWindowChannel`, call
`EnsureClientWidth`, and return:

```cpp
flutter::EncodableMap response;
response[flutter::EncodableValue("achievedLogicalWidth")] =
    flutter::EncodableValue(resize.achieved_logical_width);
response[flutter::EncodableValue("reachedRequestedWidth")] =
    flutter::EncodableValue(resize.reached_requested_width);
result->Success(flutter::EncodableValue(response));
```

Reject a missing, non-numeric, or non-positive width with error code
`invalid-width`.

- [ ] **Step 5: Verify the Dart and native boundaries**

Run:

```powershell
dart format lib/services/window/heni_window_controller.dart test/services/window/heni_window_controller_test.dart
flutter analyze
flutter build windows --debug
```

Expected: formatting succeeds, analysis reports no issues, and the Windows
Debug build links the new channel handler.

- [ ] **Step 6: Commit Task 1**

```powershell
git add test/services/window/heni_window_controller_test.dart lib/services/window/heni_window_controller.dart windows/runner/win32_window.h windows/runner/win32_window.cpp windows/runner/flutter_window.cpp
git commit -m "feat: add safe window width requests"
```

---

### Task 2: Actionable Adaptive Sidebar And Startup Reconciliation

**Files:**
- Modify: `test/features/player/application/sidebar_mode_test.dart`
- Modify: `test/features/player/presentation/adaptive_sidebar_test.dart`
- Modify: `lib/features/player/application/sidebar_mode.dart`
- Modify: `lib/features/player/application/playback_queue_controller.dart`
- Modify: `lib/features/player/presentation/adaptive_sidebar.dart`
- Modify: `lib/features/player/presentation/player_screen.dart`

**Interfaces:**
- Consumes: `HeniWindowController.ensureClientWidth(1140)`, sidebar preference, available logical width, and a restore-complete signal.
- Produces: `SidebarPreferencesRestored`, `Future<bool> Function() requestExpandedWidth`, and an always-actionable sidebar mode callback.

- [ ] **Step 1: Add failing policy and hydration tests**

Keep the existing exact boundary assertions and add:

```dart
expect(
  resolveSidebarWidthForcedCompact(width: 1041, wasForcedCompact: false),
  isFalse,
);
expect(
  resolveSidebarWidthForcedCompact(width: 1139, wasForcedCompact: true),
  isTrue,
);

final container = ProviderContainer();
addTearDown(container.dispose);
expect(container.read(sidebarPreferencesRestoredProvider), isFalse);
container.read(sidebarPreferencesRestoredProvider.notifier).complete();
expect(container.read(sidebarPreferencesRestoredProvider), isTrue);
```

Replace adaptive-widget boundary expectations `1147/1179/1180` with
`1040/1139/1140` and add a narrow explicit-expansion test using this API:

```dart
var resizeRequests = 0;
HeniSidebarMode? selected;

HeniAdaptiveSidebar(
  availableWidth: 900,
  preference: HeniSidebarMode.expanded,
  preferencesRestored: true,
  requestExpandedWidth: () async {
    resizeRequests++;
    return false;
  },
  onPreferenceChanged: (mode) => selected = mode,
  builder: (context, mode, forced, selectMode) => TextButton(
    onPressed: () => selectMode(HeniSidebarMode.expanded),
    child: Text('${mode.name}:$forced'),
  ),
)
```

After settling, expect one startup resize request and visible `expanded:false`.
Pump a compact preference at width `900`, tap the button once, then expect one
request, `selected == expanded`, and an expanded render even when the request
returns false.

- [ ] **Step 2: Verify RED**

Run:

```powershell
flutter test test/features/player/application/sidebar_mode_test.dart test/features/player/presentation/adaptive_sidebar_test.dart --reporter expanded
```

Expected: current source fails the existing `1040/1140` assertions and does not
compile with the new coordinator parameters. Record Windows error 121 if the
test listener fails before assertions.

- [ ] **Step 3: Restore the intended policy and hydration signal**

Implement the exact thresholds:

```dart
if (wasForcedCompact == null) return width < 1080;
if (wasForcedCompact) return width < 1140;
return width <= 1040;
```

Add:

```dart
final sidebarPreferencesRestoredProvider =
    NotifierProvider<SidebarPreferencesRestored, bool>(
      SidebarPreferencesRestored.new,
    );

class SidebarPreferencesRestored extends Notifier<bool> {
  @override
  bool build() => false;
  void complete() => state = true;
}
```

In `_restorePersistedState`'s `finally`, call `complete()` before processing
launch media, including the empty-config and restore-error paths.

- [ ] **Step 4: Implement adaptive expansion coordination**

Change the builder typedef to:

```dart
typedef HeniSidebarModeCallback = Future<void> Function(HeniSidebarMode mode);
typedef HeniAdaptiveSidebarBuilder = Widget Function(
  BuildContext context,
  HeniSidebarMode effectiveMode,
  bool widthForcedCompact,
  HeniSidebarModeCallback selectMode,
);
```

Add widget inputs `preferencesRestored`, `requestExpandedWidth`, and
`onPreferenceChanged`. The state tracks `_narrowExpandedOverride`,
`_resizeInProgress`, and `_startupReconciled`.

Implement selection in this order:

```dart
if (mode == HeniSidebarMode.compact) {
  _narrowExpandedOverride = false;
  widget.onPreferenceChanged(mode);
  return;
}
if (_resizeInProgress) return;
if (_widthForcedCompact) {
  _resizeInProgress = true;
  final reached = await widget.requestExpandedWidth();
  if (!mounted) return;
  _narrowExpandedOverride = !reached;
  _resizeInProgress = false;
}
widget.onPreferenceChanged(HeniSidebarMode.expanded);
```

Schedule startup reconciliation once after `preferencesRestored` becomes true
and the saved preference is expanded while width is forced compact. Call only
`requestExpandedWidth`; do not rewrite the already-restored preference. If it
returns false, enable `_narrowExpandedOverride`.

Clear the override after width reaches `1140` or the user collapses. Effective
mode is expanded when the override is active, otherwise it follows the normal
forced/preference rule.

- [ ] **Step 5: Wire PlayerScreen and keep the compact button enabled**

Watch `sidebarPreferencesRestoredProvider`, pass a resize callback that returns
`result.reachedRequestedWidth`, and persist only manual preference changes.
Pass the adaptive `selectMode` callback into `_Sidebar`.

Replace the compact expand button behavior with:

```dart
tooltip: widthForcedCompact
    ? '展开侧边栏并调整窗口'
    : '展开侧边栏',
onPressed: () => unawaited(
  onModeChanged(HeniSidebarMode.expanded),
),
```

Keep collapse as an asynchronous compact selection and remove disabled colors
that no longer have a reachable state.

- [ ] **Step 6: Verify sidebar behavior**

Run:

```powershell
dart format lib/features/player/application/sidebar_mode.dart lib/features/player/application/playback_queue_controller.dart lib/features/player/presentation/adaptive_sidebar.dart lib/features/player/presentation/player_screen.dart test/features/player/application/sidebar_mode_test.dart test/features/player/presentation/adaptive_sidebar_test.dart
flutter analyze
flutter test test/features/player/application/sidebar_mode_test.dart test/features/player/presentation/adaptive_sidebar_test.dart --reporter expanded
```

Expected: analysis passes; focused tests pass when the Flutter listener is
available, or fail only at the documented listener connection when it is not.

- [ ] **Step 7: Commit Task 2**

```powershell
git add test/features/player/application/sidebar_mode_test.dart test/features/player/presentation/adaptive_sidebar_test.dart lib/features/player/application/sidebar_mode.dart lib/features/player/application/playback_queue_controller.dart lib/features/player/presentation/adaptive_sidebar.dart lib/features/player/presentation/player_screen.dart
git commit -m "fix: keep sidebar expansion actionable"
```

---

### Task 3: Independent Shuffle And Repeat State

**Files:**
- Modify: `test/services/storage/heni_library_store_test.dart`
- Modify: `test/features/player/application/playback_queue_controller_test.dart`
- Modify: `lib/services/storage/heni_library_store.dart`
- Modify: `lib/features/player/application/playback_queue_controller.dart`

**Interfaces:**
- Consumes: existing `PlaybackQueueState.repeatMode`, `shuffle`, and legacy `playbackModeName`.
- Produces: optional JSON `repeatModeName` and `shuffleEnabled`; `toggleShuffle()` and `cycleRepeatMode()` preserve each other's state.

- [ ] **Step 1: Write failing storage migration tests**

Add these cases:

```dart
final modern = HeniLibraryConfig.fromJson(const {
  'repeatModeName': 'one',
  'shuffleEnabled': true,
});
expect(modern.repeatMode, HeniRepeatMode.one);
expect(modern.resolvedShuffle, isTrue);

final legacy = HeniLibraryConfig.fromJson(const {
  'playbackModeName': 'random',
});
expect(legacy.repeatMode, HeniRepeatMode.all);
expect(legacy.resolvedShuffle, isTrue);

final invalid = HeniLibraryConfig.fromJson(const {
  'repeatModeName': 'invalid',
  'shuffleEnabled': 'yes',
});
expect(invalid.repeatMode, HeniRepeatMode.none);
expect(invalid.resolvedShuffle, isFalse);
```

Assert `toJson()` retains the legacy field and writes the two modern fields.

- [ ] **Step 2: Write failing controller independence tests**

Start with list repeat, toggle shuffle, and expect both list repeat and shuffle.
Then cycle repeat and expect single repeat while shuffle remains true. Verify the
current item path is unchanged and persisted config contains both values.

```dart
controller.setPlaybackMode(HeniPlaybackMode.listLoop);
controller.toggleShuffle();
expect(container.read(playbackQueueControllerProvider).repeatMode,
    HeniRepeatMode.all);
expect(container.read(playbackQueueControllerProvider).shuffle, isTrue);

controller.cycleRepeatMode();
expect(container.read(playbackQueueControllerProvider).repeatMode,
    HeniRepeatMode.one);
expect(container.read(playbackQueueControllerProvider).shuffle, isTrue);
```

- [ ] **Step 3: Run the focused tests and verify RED**

```powershell
flutter test test/services/storage/heni_library_store_test.dart test/features/player/application/playback_queue_controller_test.dart --reporter expanded
```

Expected: missing modern config accessors and the current toggle implementation
resetting the other mode cause failure.

- [ ] **Step 4: Implement backward-compatible storage**

Add constructor fields `repeatModeName` and `bool? shuffleEnabled`, parse the
two JSON keys, and expose:

```dart
HeniRepeatMode get repeatMode {
  if (repeatModeName case final String name) {
    return HeniRepeatMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => HeniRepeatMode.none,
    );
  }
  return playbackMode?.repeatMode ?? HeniRepeatMode.none;
}

bool get resolvedShuffle =>
    shuffleEnabled ?? playbackMode?.shuffle ?? false;
```

Name the boolean getter `resolvedShuffle` to distinguish it from the nullable
stored field. Include both modern values in `isEmpty` and `toJson()`.

- [ ] **Step 5: Implement independent controller transitions**

Restore from `config.repeatMode` and `config.resolvedShuffle`. Write
`repeatModeName: state.repeatMode.name` and
`shuffleEnabled: state.shuffle`, while retaining the legacy derived
`playbackModeName`.

Implement shuffle without changing repeat:

```dart
final enabled = !state.shuffle;
final currentIndex = state.currentIndex < 0 ? 0 : state.currentIndex;
state = state.copyWith(
  shuffle: enabled,
  order: _buildOrder(
    state.playbackQueue.items.length,
    currentIndex,
    shuffleOverride: enabled,
  ),
  statusMessage: enabled ? '随机播放已开启' : '随机播放已关闭',
  lastError: null,
);
unawaited(_persistState());
```

Implement repeat as `state.repeatMode.next` without changing shuffle or order.
Keep `setPlaybackMode` only for legacy restore/tests; remove UI use of
`cyclePlaybackMode` in Task 4.

- [ ] **Step 6: Verify and commit Task 3**

```powershell
dart format lib/services/storage/heni_library_store.dart lib/features/player/application/playback_queue_controller.dart test/services/storage/heni_library_store_test.dart test/features/player/application/playback_queue_controller_test.dart
flutter analyze
flutter test test/services/storage/heni_library_store_test.dart test/features/player/application/playback_queue_controller_test.dart --reporter expanded
git add lib/services/storage/heni_library_store.dart lib/features/player/application/playback_queue_controller.dart test/services/storage/heni_library_store_test.dart test/features/player/application/playback_queue_controller_test.dart
git commit -m "feat: separate shuffle and repeat state"
```

Expected: analysis passes and focused assertions pass when the listener is
available.

---

### Task 4: Mature Playback-Mode Presentation

**Files:**
- Create: `lib/features/player/presentation/playback_mode_controls.dart`
- Create: `test/features/player/presentation/playback_mode_controls_test.dart`
- Modify: `lib/features/player/presentation/player_screen.dart`

**Interfaces:**
- Consumes: `HeniRepeatMode`, `bool shuffle`, queue availability, palette, and two callbacks.
- Produces: `HeniPlaybackModeControls` with separate shuffle/repeat buttons.

- [ ] **Step 1: Write the failing component test**

Pump:

```dart
HeniPlaybackModeControls(
  palette: HeniPalette.nocturne,
  shuffle: true,
  repeatMode: HeniRepeatMode.one,
  enabled: true,
  onToggleShuffle: () => shuffleTaps++,
  onCycleRepeat: () => repeatTaps++,
)
```

Assert `shuffle_rounded` and `repeat_one_rounded` exist, tooltips read
`随机播放：已开启` and `循环：单曲`, two state-dot keys exist, and tapping each
button calls only its matching callback. Add a disabled test that taps both and
expects no callbacks.

- [ ] **Step 2: Verify RED**

```powershell
flutter test test/features/player/presentation/playback_mode_controls_test.dart --reporter expanded
```

Expected: compilation fails because the focused component does not exist.

- [ ] **Step 3: Implement `HeniPlaybackModeControls`**

Create a stateless row with two private mode buttons. Each button uses a
`38 × 38` `IconButton`, transparent resting background, subtle hover/pressed
fill, `AnimatedSwitcher` for the repeat glyph, and `AnimatedContainer` for the
`3`-pixel active dot. Use `palette.accent` through
`heniAccentOnGlass(palette.accent)` for active foreground and theme secondary
text for off state. Use `140ms` ease-out transitions.

Map repeat tooltip/icon exactly:

```dart
final (tooltip, icon) = switch (repeatMode) {
  HeniRepeatMode.none => ('循环：关闭', Icons.repeat_rounded),
  HeniRepeatMode.all => ('循环：列表', Icons.repeat_rounded),
  HeniRepeatMode.one => ('循环：单曲', Icons.repeat_one_rounded),
};
```

- [ ] **Step 4: Move the controls into transport composition**

Change `_TransportControls` to receive `shuffle`, `repeatMode`, `enabled`,
`onToggleShuffle`, and `onCycleRepeat`; render:

```text
shuffle | previous | play/pause | next | repeat
```

In the compact bottom row, render the same order around previous/play/next.
Remove `_PlaybackModeIconButton`, `_playbackModeIcon`, mode fields from
`_UtilityControls`, and the `onCyclePlaybackMode` callback chain. The utility
row becomes queue followed by volume.

Wire callbacks to `PlaybackQueueController.toggleShuffle()` and
`cycleRepeatMode()`. Set `enabled` from
`queue.playbackQueue.items.isNotEmpty`.

- [ ] **Step 5: Verify layout and commit Task 4**

```powershell
dart format lib/features/player/presentation/playback_mode_controls.dart lib/features/player/presentation/player_screen.dart test/features/player/presentation/playback_mode_controls_test.dart
flutter analyze
flutter test test/features/player/presentation/playback_mode_controls_test.dart --reporter expanded
git add lib/features/player/presentation/playback_mode_controls.dart lib/features/player/presentation/player_screen.dart test/features/player/presentation/playback_mode_controls_test.dart
git commit -m "feat: add separate playback mode controls"
```

Expected: no remaining reference to `onCyclePlaybackMode` or
`_PlaybackModeIconButton`; analysis passes.

---

### Task 5: Persisted Volume Memory And Inline Volume Cluster

**Files:**
- Modify: `test/services/storage/heni_library_store_test.dart`
- Modify: `test/features/player/application/playback_queue_controller_test.dart`
- Modify: `test/features/player/presentation/volume_control_test.dart`
- Modify: `lib/services/storage/heni_library_store.dart`
- Modify: `lib/features/player/application/playback_queue_controller.dart`
- Modify: `lib/features/player/presentation/volume_control.dart`
- Modify: `lib/features/player/presentation/player_screen.dart`

**Interfaces:**
- Consumes: engine volume stream/snapshot, `PlaybackQueueState.lastAudibleVolume`, and deferred `persistVolume`.
- Produces: inline `HeniVolumeControl`, `resolveMuteTarget`, persisted `lastAudibleVolume`, and `M` mute shortcut.

- [ ] **Step 1: Write failing volume-memory tests**

Add storage round-trip coverage for `lastAudibleVolume: 64.0`, invalid values,
and missing fallback. Add controller coverage:

```dart
await controller.persistVolume(64);
await controller.persistVolume(0);
await Future<void>.delayed(const Duration(milliseconds: 260));
expect(container.read(playbackQueueControllerProvider).lastAudibleVolume, 64);
expect(store.latest?.lastAudibleVolume, 64);
```

Add pure expectations:

```dart
expect(resolveMuteTarget(current: 70, lastAudible: 55), 0);
expect(resolveMuteTarget(current: 0, lastAudible: 55), 55);
expect(resolveMuteTarget(current: 0, lastAudible: 0), 60);
```

- [ ] **Step 2: Rewrite the widget tests for inline behavior**

Pump `HeniVolumeControl` with `lastAudibleVolume: 64`. Without opening a menu,
assert `find.byKey(ValueKey('heni-volume-slider'))` exists. Tap the speaker and
expect engine volume zero; tap again and expect `64`. Invoke slider
`onChanged(35)` and expect live engine volume without persistence, then invoke
`onChangeEnd(35)` and expect one commit. Send a pointer-scroll event and arrow
key input to verify `2` and `5` point steps and clamping.

- [ ] **Step 3: Verify RED**

```powershell
flutter test test/services/storage/heni_library_store_test.dart test/features/player/application/playback_queue_controller_test.dart test/features/player/presentation/volume_control_test.dart --reporter expanded
```

Expected: missing volume-memory fields and inline slider behavior fail.

- [ ] **Step 4: Add durable last-audible state**

Add optional `lastAudibleVolume` to `HeniLibraryConfig`, clamp valid restored
values to `1–100`, include it in JSON and `isEmpty`, and add
`lastAudibleVolume` to `PlaybackQueueState` with default `60`.

In `persistVolume`, update state and the stored last-audible value only when the
normalized volume is above zero. When restoring, use the valid stored value,
otherwise use restored positive `volumeLevel`, otherwise `60`.

Write both current volume and last audible volume from `_persistState`.

- [ ] **Step 5: Replace the popover with an inline control**

Remove `MenuAnchor` and `BackdropFilter`. Add a `compact` boolean input with a
default of `false`, then render one rounded container holding:

```dart
IconButton(
  tooltip: _volume > 0 ? '静音' : '恢复音量',
  onPressed: _toggleMute,
  // 38 × 38 target
),
SizedBox(
  width: compact ? 64 : 88,
  child: Slider(
    key: const ValueKey('heni-volume-slider'),
    value: _volume,
    min: 0,
    max: 100,
    onChanged: _setLive,
    onChangeEnd: _commit,
  ),
),
```

Pass `compact: true` from `_CompactBottomBar`; the wide utility control uses the
default. Use a `3`-pixel track, `8`-pixel resting thumb, `10`-pixel hovered/focused
thumb, palette accent active track, and one low-contrast shell-theme surface.
Wrap the cluster in a percentage tooltip and keep the existing wheel handling.
Handle left/right arrow keys at `5` points and return `KeyEventResult.handled`.

Initialize local last-audible memory from the new widget input when engine
volume is zero, and update it from positive live values.

- [ ] **Step 6: Add the guarded `M` shortcut and wire state**

Pass `queue.lastAudibleVolume` into every `HeniVolumeControl`. Wrap the player
scaffold in `CallbackShortcuts` with `CharacterActivator('m')`. Before muting,
inspect `FocusManager.instance.primaryFocus?.context`; return without action
when the focused widget is or descends from `EditableText`.

For non-editable focus, compute `resolveMuteTarget`, set engine volume, and call
`persistVolume` once. Do not create a snackbar.

- [ ] **Step 7: Verify and commit Task 5**

```powershell
dart format lib/services/storage/heni_library_store.dart lib/features/player/application/playback_queue_controller.dart lib/features/player/presentation/volume_control.dart lib/features/player/presentation/player_screen.dart test/services/storage/heni_library_store_test.dart test/features/player/application/playback_queue_controller_test.dart test/features/player/presentation/volume_control_test.dart
flutter analyze
flutter test test/features/player/presentation/volume_control_test.dart test/services/storage/heni_library_store_test.dart test/features/player/application/playback_queue_controller_test.dart --reporter expanded
git add lib/services/storage/heni_library_store.dart lib/features/player/application/playback_queue_controller.dart lib/features/player/presentation/volume_control.dart lib/features/player/presentation/player_screen.dart test/services/storage/heni_library_store_test.dart test/features/player/application/playback_queue_controller_test.dart test/features/player/presentation/volume_control_test.dart
git commit -m "feat: add inline persistent volume control"
```

---

### Task 6: Coherent Playback Progress Snapshot

**Files:**
- Modify: `lib/services/media/playback_engine.dart`
- Modify: `lib/services/media/media_kit_playback_engine.dart`
- Modify: `lib/features/player/presentation/player_progress.dart`
- Modify: `lib/features/player/presentation/player_screen.dart`
- Modify: `test/features/player/presentation/player_progress_test.dart`
- Modify: `test/features/player/presentation/volume_control_test.dart`
- Modify: `test/features/player/application/playback_queue_controller_test.dart`

**Interfaces:**
- Consumes: engine position/duration snapshots and streams, media identity, and metadata duration.
- Produces: `PlayerProgressSnapshot`, `resolvePlayerProgressSnapshot`, and consistent seek behavior.

- [ ] **Step 1: Write failing snapshot tests**

Add `currentPosition` and `currentDuration` to the fake engine and assert:

```dart
expect(
  resolvePlayerProgressSnapshot(
    streamedPosition: const Duration(seconds: 30),
    streamedDuration: Duration.zero,
    enginePosition: const Duration(seconds: 29),
    engineDuration: Duration.zero,
    fallbackDuration: const Duration(minutes: 4),
  ).fraction,
  closeTo(0.125, 0.0001),
);

final unknown = resolvePlayerProgressSnapshot(
  streamedPosition: const Duration(seconds: 30),
  streamedDuration: Duration.zero,
  enginePosition: const Duration(seconds: 30),
  engineDuration: Duration.zero,
  fallbackDuration: null,
);
expect(unknown.totalKnown, isFalse);
expect(unknown.fraction, 0);
expect(unknown.canSeek, isFalse);
```

Add a clamp test for position beyond total and widget layout tests keyed
`player-progress-wide`, `player-progress-compact`, and
`player-progress-narrow` at widths `320`, `220`, and `140`.

- [ ] **Step 2: Add failing media-change and drag tests**

Pump with media id `track-a`, emit progress, then repump with `track-b` and zero
duration; assert the old fill/tooltip is not retained. Drag halfway on a
four-minute track while emitting a conflicting position; expect the preview to
remain at `02:00` and exactly one `seek(Duration(minutes: 2))` on release.

- [ ] **Step 3: Verify RED**

```powershell
flutter test test/features/player/presentation/player_progress_test.dart --reporter expanded
```

Expected: missing snapshot getters, resolver, media id, and layout keys fail.

- [ ] **Step 4: Add synchronous engine snapshots**

Extend `PlaybackEngine`:

```dart
Duration get currentPosition;
Duration get currentDuration;
```

Implement with `_player.state.position` and `_player.state.duration`. Add exact
overrides to the three test fakes in player progress, volume control, and queue
controller tests.

- [ ] **Step 5: Implement one progress resolver**

Add an immutable public snapshot whose constructor is fed only through:

```dart
PlayerProgressSnapshot resolvePlayerProgressSnapshot({
  required Duration? streamedPosition,
  required Duration? streamedDuration,
  required Duration enginePosition,
  required Duration engineDuration,
  required Duration? fallbackDuration,
})
```

Choose the first positive duration from streamed, engine, fallback. Choose
streamed position when non-null, otherwise engine position. With known total,
clamp position and compute `position.inMicroseconds / total.inMicroseconds`.
With unknown total, keep a non-negative position but return fraction zero and
`canSeek == false`.

- [ ] **Step 6: Rebuild `PlayerProgressWithTime` around the snapshot**

Make it stateful with required `mediaId`, duration/position subscriptions,
last-valid streamed values, and local drag state. Seed subscriptions from
engine snapshots. On `mediaId` change, cancel/rebind subscriptions and clear
streamed, hover, and drag state before painting.

Use the resolved snapshot for labels, painter fraction, tooltip, drag preview,
and seek. Ignore playback-position repainting while dragging; seek once on drag
end and discard preview on cancel. Disable tap/drag seeking when `canSeek` is
false.

Render thresholds exactly:

```dart
if (constraints.maxWidth >= 280) return wideLayout;
if (constraints.maxWidth >= 180) return compactLayout;
return narrowTrackOnly;
```

The compact layout reserves one `current / total` label. The narrow layout
keeps the interactive track. Unknown total formats as `--:--` and never divides
by a synthetic millisecond.

- [ ] **Step 7: Pass media identity and verify**

Pass `currentMedia?.path ?? 'no-media'` into every bottom progress instance.

Run:

```powershell
dart format lib/services/media/playback_engine.dart lib/services/media/media_kit_playback_engine.dart lib/features/player/presentation/player_progress.dart lib/features/player/presentation/player_screen.dart test/features/player/presentation/player_progress_test.dart test/features/player/presentation/volume_control_test.dart test/features/player/application/playback_queue_controller_test.dart
flutter analyze
flutter test test/features/player/presentation/player_progress_test.dart --reporter expanded
```

Expected: analysis passes; all resolver and widget assertions pass when the
listener is available.

- [ ] **Step 8: Commit Task 6**

```powershell
git add lib/services/media/playback_engine.dart lib/services/media/media_kit_playback_engine.dart lib/features/player/presentation/player_progress.dart lib/features/player/presentation/player_screen.dart test/features/player/presentation/player_progress_test.dart test/features/player/presentation/volume_control_test.dart test/features/player/application/playback_queue_controller_test.dart
git commit -m "fix: unify player progress state"
```

---

### Task 7: Regression, Runtime QA, And Project Record

**Files:**
- Modify: `logs/request-log.md`
- Modify: `logs/windows.md`

**Interfaces:**
- Consumes: final Debug/Release executables and all focused tests.
- Produces: verification evidence for window resizing, sidebar behavior, playback modes, volume, and progress.

- [ ] **Step 1: Run source and test verification**

```powershell
flutter analyze
flutter test test/domain/playback/playback_order_test.dart test/services/storage/heni_library_store_test.dart test/features/player/application/sidebar_mode_test.dart test/features/player/application/playback_queue_controller_test.dart test/services/window/heni_window_controller_test.dart test/features/player/presentation/adaptive_sidebar_test.dart test/features/player/presentation/playback_mode_controls_test.dart test/features/player/presentation/volume_control_test.dart test/features/player/presentation/player_progress_test.dart --reporter expanded
git diff --check
```

Expected: analysis and whitespace checks pass. Tests pass when the local Flutter
listener connects; if Windows error 121 prevents loading, report it as an
environment limitation without calling the assertions passed.

- [ ] **Step 2: Build both Windows configurations**

```powershell
flutter build windows --debug
flutter build windows --release
```

Expected: both builds succeed.

- [ ] **Step 3: Perform manual interaction QA**

Verify these exact scenarios without terminating user-owned player processes:

- no saved geometry opens at `1280 × 720` with expanded sidebar;
- saved `900 × 620` plus expanded preference grows once to at least `1140`;
- saved compact preference does not grow;
- manual expand at minimum grows the window, while collapse does not shrink it;
- window-edge and constrained-monitor behavior remains on-screen;
- shuffle and repeat work independently and restore after restart;
- speaker click, slider, wheel, arrows, and `M` preserve mute memory;
- progress fill, labels, tooltip, drag preview, and seek agree before/after
  track changes and window resizing;
- no overflow banner appears at `900 × 620`.

- [ ] **Step 4: Update project records**

Append dated entries to both logs containing the root causes, changed behavior,
commands and outcomes, listener limitation if present, build configuration,
DPI/window sizes checked, and screenshot paths if screenshots are captured.

- [ ] **Step 5: Commit final verification records**

```powershell
git add logs/request-log.md logs/windows.md
git commit -m "docs: record player interaction verification"
```
