# Adaptive Sidebar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add mature expanded and compact sidebar modes with persisted manual preference, width-driven temporary compaction, stable resize hysteresis, and labeled expanded navigation.

**Architecture:** A focused application module owns the two-value preference and pure responsive policy. A small stateful presentation frame applies hysteresis without delaying the first narrow render, while the existing expanded and compact sidebar widgets remain responsible for their visual content.

**Tech Stack:** Flutter, Dart, Riverpod, JSON persistence, `flutter_test`, Windows screenshot QA.

## Global Constraints

- The default `1280 × 720` window shows the expanded sidebar.
- Expanded mode shows destination icons, text labels, playlist names, and item counts.
- Compact mode is `72` logical pixels wide and uses icon navigation with tooltips.
- Width at or below `1040` enters forced compact mode.
- Width at or above `1140` leaves forced compact mode.
- The first layout below `1080` starts forced compact.
- Automatic compaction never overwrites the stored user preference.
- The full player retains its DPI-aware `900 × 620` minimum client size.
- Window height must not choose sidebar mode.

---

### Task 1: Sidebar preference and responsive policy

**Files:**
- Create: `lib/features/player/application/sidebar_mode.dart`
- Create: `test/features/player/application/sidebar_mode_test.dart`

**Interfaces:**
- Produces: `HeniSidebarMode`, `sidebarModeProvider`, `SidebarModeController`, and `resolveSidebarWidthForcedCompact`.
- Consumes: only Riverpod and a logical window width.

- [ ] **Step 1: Write failing policy and provider tests**

```dart
test('defaults to expanded and restores valid names', () {
  final container = ProviderContainer();
  addTearDown(container.dispose);

  expect(container.read(sidebarModeProvider), HeniSidebarMode.expanded);
  container
      .read(sidebarModeProvider.notifier)
      .restoreByName(HeniSidebarMode.compact.name);
  expect(container.read(sidebarModeProvider), HeniSidebarMode.compact);
});

test('uses hysteresis without changing preference', () {
  expect(
    resolveSidebarWidthForcedCompact(width: 1030, wasForcedCompact: false),
    isTrue,
  );
  expect(
    resolveSidebarWidthForcedCompact(width: 1090, wasForcedCompact: true),
    isTrue,
  );
  expect(
    resolveSidebarWidthForcedCompact(width: 1150, wasForcedCompact: true),
    isFalse,
  );
});
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
flutter test test/features/player/application/sidebar_mode_test.dart --reporter expanded
```

Expected: compilation failure because `sidebar_mode.dart` and its interfaces do not exist.

- [ ] **Step 3: Implement the minimal state and policy**

```dart
enum HeniSidebarMode { expanded, compact }

final sidebarModeProvider =
    NotifierProvider<SidebarModeController, HeniSidebarMode>(
      SidebarModeController.new,
    );

class SidebarModeController extends Notifier<HeniSidebarMode> {
  @override
  HeniSidebarMode build() => HeniSidebarMode.expanded;

  void select(HeniSidebarMode mode) => state = mode;

  void restoreByName(String? name) {
    state = HeniSidebarMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => HeniSidebarMode.expanded,
    );
  }
}

bool resolveSidebarWidthForcedCompact({
  required double width,
  required bool? wasForcedCompact,
}) {
  if (wasForcedCompact == null) {
    return width < 1080;
  }
  if (wasForcedCompact) {
    return width < 1140;
  }
  return width <= 1040;
}
```

- [ ] **Step 4: Run the focused test**

Run the Task 1 command again. Expected: test assertions pass when the local Flutter listener is available; compilation must succeed in all environments.

### Task 2: Persist the manual sidebar preference

**Files:**
- Modify: `lib/services/storage/heni_library_store.dart`
- Modify: `lib/features/player/application/playback_queue_controller.dart`
- Modify: `test/features/player/application/playback_queue_controller_test.dart`
- Create: `test/services/storage/heni_library_store_test.dart`

**Interfaces:**
- Consumes: `HeniSidebarMode` from Task 1.
- Produces: optional JSON field `sidebarMode` and `persistShellPreferences(sidebarMode: ...)`.

- [ ] **Step 1: Write failing JSON and controller persistence tests**

```dart
test('round trips the sidebar preference', () {
  final config = HeniLibraryConfig.fromJson(
    const {'sidebarMode': 'compact'},
  );
  expect(config.sidebarModeName, 'compact');
  expect(config.toJson()['sidebarMode'], 'compact');
});
```

Add a controller test that calls:

```dart
await controller.persistShellPreferences(
  sidebarMode: HeniSidebarMode.compact,
);
expect(store.latest?.sidebarModeName, 'compact');
```

Then restore the same store in a second container and expect
`sidebarModeProvider` to be `HeniSidebarMode.compact`.

- [ ] **Step 2: Run the focused tests and verify RED**

```powershell
flutter test test/services/storage/heni_library_store_test.dart test/features/player/application/playback_queue_controller_test.dart --reporter expanded
```

Expected: compilation failures for `sidebarModeName` and the new method parameter.

- [ ] **Step 3: Implement config and controller wiring**

Add `sidebarModeName` to the `HeniLibraryConfig` constructor, JSON parsing,
fields, `isEmpty`, and `toJson`. In `PlaybackQueueController`, retain
`_persistedSidebarModeName`, restore it through `sidebarModeProvider`, accept a
`HeniSidebarMode? sidebarMode` shell preference, and write it through
`_persistState`.

- [ ] **Step 4: Run the focused tests**

Run the Task 2 command again. Expected: tests pass when the listener is available and compilation succeeds.

### Task 3: Adaptive presentation frame and sidebar controls

**Files:**
- Create: `lib/features/player/presentation/adaptive_sidebar.dart`
- Create: `test/features/player/presentation/adaptive_sidebar_test.dart`
- Modify: `lib/features/player/presentation/player_screen.dart`

**Interfaces:**
- Consumes: logical available width and `HeniSidebarMode` preference.
- Produces: `HeniAdaptiveSidebar`, whose builder receives effective mode and `widthForcedCompact`.

- [ ] **Step 1: Write the failing adaptive frame widget test**

Pump `HeniAdaptiveSidebar` with a builder that emits keyed `Text` widgets.
Verify:

```dart
expect(find.text('expanded:false'), findsOneWidget);
```

at width `1280`, then rebuild at `1000` and expect `compact:true`, then rebuild
at `1180` and expect `expanded:false`. A wide compact preference must emit
`compact:false`.

- [ ] **Step 2: Run the focused test and verify RED**

```powershell
flutter test test/features/player/presentation/adaptive_sidebar_test.dart --reporter expanded
```

Expected: compilation failure because `adaptive_sidebar.dart` does not exist.

- [ ] **Step 3: Implement `HeniAdaptiveSidebar`**

Use a `StatefulWidget` that initializes and updates `_widthForcedCompact` with
`resolveSidebarWidthForcedCompact` in `initState` and `didUpdateWidget`. Build
the effective mode immediately and wrap the builder output in a
`KeyedSubtree(ValueKey(effectiveMode))` plus a `200ms` `AnimatedSize`.

- [ ] **Step 4: Integrate the effective mode into the player**

In `PlayerScreen`:

- watch `sidebarModeProvider`;
- wrap `_Sidebar` with `HeniAdaptiveSidebar(availableWidth: constraints.maxWidth, ...)`;
- on manual change, update `sidebarModeProvider` and call
  `persistShellPreferences(sidebarMode: mode)`.

In `_ShellLayout`:

- remove sidebar selection from `quiet`;
- keep height-based density for unrelated shell elements;
- expose `sidebarWidth(mode)` returning `224` expanded and `72` compact.

In `_Sidebar`:

- choose `_CompactSidebar` from the effective mode rather than `layout.quiet`;
- pass `onModeChanged` and `widthForcedCompact`;
- add a collapse button beside `浏览` in expanded mode;
- ensure expanded destinations retain their labels, names, and counts.

In `_CompactSidebar`:

- place the expand control first;
- disable it while width-forced;
- use tooltip `窗口宽度不足，拉宽后可展开` when blocked and `展开侧边栏` otherwise;
- retain `42 × 42` destination hit targets and `72`-pixel rail width.

- [ ] **Step 5: Run focused tests and analysis**

```powershell
flutter test test/features/player/application/sidebar_mode_test.dart test/features/player/presentation/adaptive_sidebar_test.dart --reporter expanded
flutter analyze
```

Expected: analysis reports no issues; tests pass when the local listener is available.

### Task 4: Windows resize and persistence verification

**Files:**
- Modify: `logs/request-log.md`
- Modify: `logs/windows.md`

**Interfaces:**
- Consumes: rebuilt Windows Debug executable and persisted Heni config.
- Produces: resize screenshots and recorded regression evidence.

- [ ] **Step 1: Run final automated checks**

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --reporter compact
flutter build windows --debug
git diff --check
```

Record the existing `127.0.0.1` Flutter listener timeout separately if it occurs before test assertions.

- [ ] **Step 2: Perform DPI-aware visual QA**

Capture the player at:

- default `1280 × 720`: expanded labels visible;
- width `1000`: compact rail visible;
- width `1180` after narrowing: expanded preference restored;
- minimum `900 × 620`: no overflow.

Also select compact manually at a wide width, narrow and re-expand the window,
and confirm the compact preference remains.

- [ ] **Step 3: Update logs and commit**

Document the root cause, two sidebar modes, hysteresis thresholds, persistence,
disabled forced-expand feedback, and validation results. Commit all source,
tests, and logs as:

```powershell
git commit -m "feat: add adaptive sidebar modes"
```
