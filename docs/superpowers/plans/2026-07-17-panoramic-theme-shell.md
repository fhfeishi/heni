# Panoramic Theme Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Heni's flat gray shell with the approved edge-to-edge panoramic background, theme-derived window chrome, lowercase `heni` branding, and polished desktop interactions, then apply the verified build to the normal workspace Release.

**Architecture:** Add one immutable shell-theme value object derived from `HeniPalette`, then make the backdrop, frame, top bar, side rail, content surface, dock, volume control, and queue dialog consume those semantic values. Keep playback and scanning services untouched; UI state remains in existing Riverpod providers and the native `heni/window` method channel.

**Tech Stack:** Flutter 3 / Dart 3.7+, Riverpod 3, Material 3, Windows C++ runner, `media_kit`, Flutter widget tests, Dart `image` 4.8 for reproducible Windows icon generation.

## Global Constraints

- Windows-first desktop player; minimum logical client size remains exactly `900 × 620`.
- The selected background image covers the entire Flutter surface, including title bar and bottom dock.
- The brand shown in the shell and native icon is lowercase `heni`; do not render a round uppercase `H` or uppercase `HENI`.
- The selected `HeniPalette` remains the source of theme semantics; background images never overwrite the user's palette.
- Do not change the media playback path, add DSP, add lyrics, or restore FLAC/audio export.
- Preserve current queue, file-location, adaptive-sidebar, progress-seek, focus-mode, and native window behavior.
- Use TDD for every behavior change and commit each independently reviewable task.
- Implement inside `D:\codespace\fhfeishi\heni\.worktrees\studio-listening-console`; apply to the normal workspace only after verification.

---

## File Structure

- Create `lib/design/heni_shell_theme.dart`: semantic colors for canvas, chrome, rail, content, dock, border, and interaction states.
- Modify `lib/features/player/presentation/global_scenery_backdrop.dart`: approved playback/library image treatment and theme fallback.
- Create `lib/features/player/presentation/player_shell_frame.dart`: panoramic outer frame and reusable shell surface.
- Modify `lib/features/player/presentation/player_window_chrome.dart`: lowercase wordmark and theme-aware native controls.
- Modify `lib/features/player/presentation/player_screen.dart`: compose the panoramic shell and replace outer gray panels.
- Modify `lib/features/player/presentation/adaptive_sidebar.dart` and `lib/features/player/application/sidebar_mode.dart`: 1180 px restore threshold with stable hysteresis.
- Modify `lib/features/player/presentation/player_progress.dart`: preserve bounded track/time layout through resize.
- Create `lib/features/player/presentation/volume_control.dart`: testable volume popover with mute restore and deferred persistence.
- Modify `lib/features/player/presentation/playback_queue_location.dart` and `player_screen.dart`: locate without silently clearing a filter.
- Create `tool/generate_windows_icon.dart`: deterministic lowercase `heni` ICO generator.
- Modify `windows/runner/resources/app_icon.ico`: generated multi-resolution native icon.
- Add focused tests under matching `test/design` and `test/features/player/presentation` paths.
- Update `strata.md`, `logs/plan.md`, `logs/windows.md`, `logs/request-log.md`, and `README.md` only after verified Release behavior is known.

---

### Task 1: Semantic shell theme

**Files:**
- Create: `lib/design/heni_shell_theme.dart`
- Create: `test/design/heni_shell_theme_test.dart`

**Interfaces:**
- Consumes: `HeniPalette` from `lib/design/app_theme.dart`.
- Produces: `HeniShellTheme.fromPalette(HeniPalette)`, `HeniShellSurfaceRole`, and `HeniShellTheme.surfaceFor(HeniShellSurfaceRole)`.

- [ ] **Step 1: Write the failing semantic-theme test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heni/design/app_theme.dart';
import 'package:heni/design/heni_shell_theme.dart';

void main() {
  test('all palettes create translucent distinct shell layers', () {
    for (final palette in HeniPalette.all) {
      final shell = HeniShellTheme.fromPalette(palette);
      final layers = HeniShellSurfaceRole.values
          .map(shell.surfaceFor)
          .map((color) => color.toARGB32())
          .toSet();

      expect(shell.canvas.a, 1, reason: palette.name);
      expect(shell.chrome.a, inInclusiveRange(0.45, 0.70));
      expect(shell.rail.a, inInclusiveRange(0.30, 0.58));
      expect(shell.content.a, inInclusiveRange(0.36, 0.64));
      expect(shell.dock.a, inInclusiveRange(0.48, 0.72));
      expect(layers.length, HeniShellSurfaceRole.values.length);
      expect(shell.border.a, greaterThan(0.20));
      expect(shell.selected.a, greaterThan(shell.hover.a));
    }
  });

  test('shell colors change when the palette changes', () {
    final tide = HeniShellTheme.fromPalette(HeniPalette.tide);
    final ember = HeniShellTheme.fromPalette(HeniPalette.ember);

    expect(tide.border, isNot(ember.border));
    expect(tide.selected, isNot(ember.selected));
    expect(tide.chrome, isNot(ember.chrome));
  });
}
```

- [ ] **Step 2: Run the test and verify the missing API failure**

Run:

```powershell
flutter test test/design/heni_shell_theme_test.dart
```

Expected: compilation fails because `heni_shell_theme.dart` and `HeniShellTheme` do not exist.

- [ ] **Step 3: Implement the immutable semantic theme**

Create `lib/design/heni_shell_theme.dart` with this public API:

```dart
import 'package:flutter/material.dart';

import 'app_theme.dart';

enum HeniShellSurfaceRole { chrome, rail, content, dock }

@immutable
class HeniShellTheme {
  const HeniShellTheme({
    required this.canvas,
    required this.chrome,
    required this.rail,
    required this.content,
    required this.dock,
    required this.border,
    required this.hover,
    required this.pressed,
    required this.selected,
    required this.primaryText,
    required this.secondaryText,
  });

  factory HeniShellTheme.fromPalette(HeniPalette palette) {
    Color tinted(Color base, double seedMix, double alpha) =>
        Color.lerp(base, palette.seed, seedMix)!.withValues(alpha: alpha);

    return HeniShellTheme(
      canvas: Color.lerp(palette.surface, palette.seed, 0.08)!,
      chrome: tinted(palette.surfaceAlt, 0.14, 0.56),
      rail: tinted(palette.surface, 0.16, 0.42),
      content: tinted(palette.surface, 0.10, 0.50),
      dock: tinted(palette.surfaceAlt, 0.12, 0.60),
      border: Color.lerp(palette.seed, palette.accent, 0.24)!
          .withValues(alpha: 0.38),
      hover: palette.seed.withValues(alpha: 0.12),
      pressed: palette.seed.withValues(alpha: 0.17),
      selected: Color.lerp(palette.seed, palette.accent, 0.22)!
          .withValues(alpha: 0.20),
      primaryText: Colors.white.withValues(alpha: 0.94),
      secondaryText: Colors.white.withValues(alpha: 0.62),
    );
  }

  final Color canvas;
  final Color chrome;
  final Color rail;
  final Color content;
  final Color dock;
  final Color border;
  final Color hover;
  final Color pressed;
  final Color selected;
  final Color primaryText;
  final Color secondaryText;

  Color surfaceFor(HeniShellSurfaceRole role) => switch (role) {
        HeniShellSurfaceRole.chrome => chrome,
        HeniShellSurfaceRole.rail => rail,
        HeniShellSurfaceRole.content => content,
        HeniShellSurfaceRole.dock => dock,
      };
}
```

- [ ] **Step 4: Format and run the focused tests**

Run:

```powershell
dart format lib/design/heni_shell_theme.dart test/design/heni_shell_theme_test.dart
flutter test test/design/app_theme_test.dart test/design/heni_shell_theme_test.dart
```

Expected: both test files pass.

- [ ] **Step 5: Commit the semantic theme**

```powershell
git add lib/design/heni_shell_theme.dart test/design/heni_shell_theme_test.dart
git commit -m "feat: add panoramic shell theme tokens"
```

---

### Task 2: Panoramic scenery treatment

**Files:**
- Modify: `lib/features/player/presentation/global_scenery_backdrop.dart`
- Modify: `test/features/player/presentation/global_scenery_backdrop_test.dart`

**Interfaces:**
- Consumes: `HeniShellTheme` from Task 1.
- Produces: `GlobalSceneryBackdrop(..., shellTheme: HeniShellTheme, ...)` with exact playback and library treatments.

- [ ] **Step 1: Tighten the treatment tests before changing production values**

Add these expectations to `global_scenery_backdrop_test.dart` and pass `shellTheme: HeniShellTheme.fromPalette(HeniPalette.plum)` in the widget test:

```dart
expect(playback.blurSigma, inInclusiveRange(8, 12));
expect(playback.overlayOpacity, inInclusiveRange(0.26, 0.34));
expect(playback.saturation, inInclusiveRange(0.78, 0.88));
expect(library.blurSigma, inInclusiveRange(14, 18));
expect(library.overlayOpacity, inInclusiveRange(0.40, 0.50));
expect(library.saturation, inInclusiveRange(0.66, 0.76));
```

Also add:

```dart
testWidgets('invalid scenery paths fall back to the palette canvas', (
  tester,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: GlobalSceneryBackdrop(
        imagePaths: const [r'Z:\missing\heni-background.png'],
        palette: HeniPalette.tide,
        shellTheme: HeniShellTheme.fromPalette(HeniPalette.tide),
        mode: HeniBackdropMode.library,
      ),
    ),
  );

  expect(find.byKey(const ValueKey('global-scenery-fallback')), findsOneWidget);
  expect(tester.takeException(), isNull);
});
```

Add a pure reduced-motion assertion:

```dart
expect(
  heniBackdropTransitionDuration(disableAnimations: false),
  const Duration(milliseconds: 820),
);
expect(
  heniBackdropTransitionDuration(disableAnimations: true),
  Duration.zero,
);
```

- [ ] **Step 2: Run the tests and verify the constructor/value failures**

Run:

```powershell
flutter test test/features/player/presentation/global_scenery_backdrop_test.dart
```

Expected: failure because `shellTheme` is not accepted and the old library overlay is `0.68`.

- [ ] **Step 3: Implement the approved treatment and remove stacked darkness**

Use these exact treatment constants:

```dart
static const playback = HeniBackdropTreatment(
  blurSigma: 10,
  overlayOpacity: 0.30,
  saturation: 0.84,
  seedWashOpacity: 0.16,
);

static const library = HeniBackdropTreatment(
  blurSigma: 16,
  overlayOpacity: 0.46,
  saturation: 0.72,
  seedWashOpacity: 0.18,
);
```

Add `final HeniShellTheme shellTheme` to `GlobalSceneryBackdrop`, import `heni_shell_theme.dart`, and replace the black/surface overlay with one palette-derived veil:

```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 380),
  curve: Curves.easeOutCubic,
  color: widget.shellTheme.canvas.withValues(
    alpha: treatment.overlayOpacity,
  ),
),
```

Add and use this helper for the scenery `AnimatedSwitcher`, and keep the existing invalid-path fallback:

```dart
Duration heniBackdropTransitionDuration({required bool disableAnimations}) =>
    disableAnimations ? Duration.zero : const Duration(milliseconds: 820);
```

Resolve `disableAnimations` from `MediaQuery.maybeOf(context)?.disableAnimations ?? false` inside `build`.

- [ ] **Step 4: Run backdrop and theme tests**

Run:

```powershell
dart format lib/features/player/presentation/global_scenery_backdrop.dart test/features/player/presentation/global_scenery_backdrop_test.dart
flutter test test/design test/features/player/presentation/global_scenery_backdrop_test.dart
```

Expected: all tests pass; no widget exception is reported.

- [ ] **Step 5: Commit the panoramic backdrop**

```powershell
git add lib/features/player/presentation/global_scenery_backdrop.dart test/features/player/presentation/global_scenery_backdrop_test.dart
git commit -m "feat: reveal panoramic scenery across shell"
```

---

### Task 3: Theme frame, lowercase wordmark, and window chrome

**Files:**
- Create: `lib/features/player/presentation/player_shell_frame.dart`
- Modify: `lib/features/player/presentation/player_window_chrome.dart`
- Modify: `test/features/player/presentation/player_window_chrome_test.dart`
- Create: `test/features/player/presentation/player_shell_frame_test.dart`
- Modify: `lib/services/window/heni_window_controller.dart`
- Modify: `test/services/window/heni_window_controller_test.dart`

**Interfaces:**
- Consumes: `HeniShellTheme`, `HeniPalette`, and existing native window controller state.
- Produces: `HeniPanoramicShellFrame`, `HeniShellSurface`, and `HeniBrandWordmark`.

- [ ] **Step 1: Write failing frame and wordmark tests**

Create `player_shell_frame_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heni/design/app_theme.dart';
import 'package:heni/design/heni_shell_theme.dart';
import 'package:heni/features/player/presentation/player_shell_frame.dart';

void main() {
  testWidgets('restored shell keeps border while maximized shell is flush', (
    tester,
  ) async {
    final shell = HeniShellTheme.fromPalette(HeniPalette.nocturne);

    Future<void> pump(bool maximized) => tester.pumpWidget(
          MaterialApp(
            home: HeniPanoramicShellFrame(
              shellTheme: shell,
              isMaximized: maximized,
              child: const SizedBox.expand(),
            ),
          ),
        );

    await pump(false);
    expect(tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('heni-panoramic-frame')),
    ).padding, const EdgeInsets.all(1));

    await pump(true);
    expect(tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('heni-panoramic-frame')),
    ).padding, EdgeInsets.zero);
  });
}
```

Add to `player_window_chrome_test.dart`:

```dart
testWidgets('brand is lowercase heni without uppercase badge', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: HeniBrandWordmark())),
  );

  expect(find.text('heni'), findsOneWidget);
  expect(find.text('H'), findsNothing);
  expect(find.text('HENI'), findsNothing);
});
```

Add a native-controller failure test:

```dart
test('close reports a native channel failure', () async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'close') {
      throw PlatformException(code: 'close-failed');
    }
    if (call.method == 'isMaximized') return false;
    return null;
  });
  final container = ProviderContainer();
  addTearDown(container.dispose);

  final closed = await container
      .read(heniWindowControllerProvider.notifier)
      .close();
  expect(closed, isFalse);
});
```

- [ ] **Step 2: Run tests and verify missing widgets**

Run:

```powershell
flutter test test/features/player/presentation/player_shell_frame_test.dart test/features/player/presentation/player_window_chrome_test.dart
```

Expected: compilation fails because the three public widgets do not exist.

- [ ] **Step 3: Implement the frame and reusable surface**

Create `player_shell_frame.dart` with the following behavior:

```dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../design/heni_shell_theme.dart';

class HeniPanoramicShellFrame extends StatelessWidget {
  const HeniPanoramicShellFrame({
    required this.shellTheme,
    required this.isMaximized,
    required this.child,
    super.key,
  });

  final HeniShellTheme shellTheme;
  final bool isMaximized;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = isMaximized ? 0.0 : 14.0;
    return AnimatedContainer(
      key: const ValueKey('heni-panoramic-frame'),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: isMaximized ? EdgeInsets.zero : const EdgeInsets.all(1),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            shellTheme.border,
            Colors.white.withValues(alpha: 0.10),
            shellTheme.border.withValues(alpha: 0.60),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius == 0 ? 0 : radius - 1),
        child: child,
      ),
    );
  }
}

class HeniShellSurface extends StatelessWidget {
  const HeniShellSurface({
    required this.shellTheme,
    required this.role,
    required this.child,
    this.radius = 12,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final HeniShellTheme shellTheme;
  final HeniShellSurfaceRole role;
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: shellTheme.surfaceFor(role),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: shellTheme.border.withValues(alpha: 0.48)),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implement lowercase branding and semantic control states**

Add this public widget to `player_window_chrome.dart`:

```dart
class HeniBrandWordmark extends StatelessWidget {
  const HeniBrandWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'heni',
      key: const ValueKey('heni-brand-wordmark'),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.94),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
    );
  }
}
```

Change `HeniWindowControls` and `_WindowControlButton` to receive `HeniShellTheme shellTheme`; use `shellTheme.hover`, `shellTheme.pressed`, and `shellTheme.primaryText`. Keep the existing red close hover and exact native action calls.

Update the existing native-action widget test constructor to the new signature:

```dart
home: Scaffold(
  body: HeniWindowControls(
    shellTheme: HeniShellTheme.fromPalette(HeniPalette.plum),
  ),
),
```

Change only `close` to report success while keeping other controller methods as `Future<void>`:

```dart
Future<bool> close() => _invoke('close');

Future<bool> _invoke(String method) async {
  try {
    await _channel.invokeMethod<void>(method);
    return true;
  } on PlatformException catch (error) {
    debugPrint('Heni window action $method failed: $error');
    return false;
  } on MissingPluginException catch (error) {
    debugPrint('Heni window action $method unavailable: $error');
    return false;
  }
}
```

Make `minimize`, `beginDrag`, and `toggleMaximize` await `_invoke` without returning its bool. In the close button callback, await `controller.close()` and show a `SnackBar(content: Text('窗口暂时无法关闭'))` only when it returns false and the widget context remains mounted.

- [ ] **Step 5: Run frame/chrome tests**

Run:

```powershell
dart format lib/features/player/presentation/player_shell_frame.dart lib/features/player/presentation/player_window_chrome.dart lib/services/window/heni_window_controller.dart test/features/player/presentation/player_shell_frame_test.dart test/features/player/presentation/player_window_chrome_test.dart test/services/window/heni_window_controller_test.dart
flutter test test/features/player/presentation/player_shell_frame_test.dart test/features/player/presentation/player_window_chrome_test.dart test/services/window/heni_window_controller_test.dart
```

Expected: all tests pass and native method order remains unchanged.

- [ ] **Step 6: Commit frame and chrome**

```powershell
git add lib/features/player/presentation/player_shell_frame.dart lib/features/player/presentation/player_window_chrome.dart lib/services/window/heni_window_controller.dart test/features/player/presentation/player_shell_frame_test.dart test/features/player/presentation/player_window_chrome_test.dart test/services/window/heni_window_controller_test.dart
git commit -m "feat: integrate lowercase panoramic window chrome"
```

---

### Task 4: Compose the panoramic shell and stabilize responsive layout

**Files:**
- Modify: `lib/features/player/presentation/player_screen.dart`
- Modify: `lib/features/player/presentation/adaptive_sidebar.dart`
- Modify: `lib/features/player/application/sidebar_mode.dart`
- Modify: `test/features/player/presentation/adaptive_sidebar_test.dart`
- Modify: `test/features/player/presentation/player_progress_test.dart`
- Modify: `test/features/player/presentation/player_responsive_layout_test.dart`

**Interfaces:**
- Consumes: `HeniShellTheme`, `HeniPanoramicShellFrame`, `HeniShellSurface`, `HeniBrandWordmark`.
- Produces: edge-to-edge PlayerScreen composition, default expanded side rail at `>= 1180`, and bounded progress geometry.

- [ ] **Step 1: Update responsive tests first**

Change the adaptive-sidebar sequence to prove a 32 px restore band around 1180:

```dart
await pump(width: 1280, preference: HeniSidebarMode.expanded);
expect(find.text('expanded:false'), findsOneWidget);

await pump(width: 1147, preference: HeniSidebarMode.expanded);
expect(find.text('compact:true'), findsOneWidget);

await pump(width: 1179, preference: HeniSidebarMode.expanded);
expect(find.text('compact:true'), findsOneWidget);

await pump(width: 1180, preference: HeniSidebarMode.expanded);
expect(find.text('expanded:false'), findsOneWidget);
```

Add a separate-times geometry test to `player_progress_test.dart`:

```dart
testWidgets('wide progress keeps both times outside the seek track', (
  tester,
) async {
  final engine = _FakePlaybackEngine();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 240,
          child: PlayerProgressWithTime(
            engine: engine,
            palette: HeniPalette.cobalt,
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  final track = tester.getRect(find.byKey(const ValueKey('player-progress-track')));
  final position = tester.getRect(find.text('00:30'));
  final duration = tester.getRect(find.text('04:00'));
  expect(position.right, lessThanOrEqualTo(track.left));
  expect(duration.left, greaterThanOrEqualTo(track.right));
  expect(tester.takeException(), isNull);
});
```

Add a reduced-motion widget test to `adaptive_sidebar_test.dart`:

```dart
testWidgets('disables sidebar transitions when system motion is reduced', (
  tester,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: HeniAdaptiveSidebar(
          availableWidth: 1280,
          preference: HeniSidebarMode.expanded,
          builder: (context, mode, forced) => Text(mode.name),
        ),
      ),
    ),
  );

  expect(tester.widget<AnimatedSize>(find.byType(AnimatedSize)).duration,
      Duration.zero);
  expect(tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
      Duration.zero);
});
```

- [ ] **Step 2: Run the responsive tests and verify the old threshold failure**

Run:

```powershell
flutter test test/features/player/presentation/adaptive_sidebar_test.dart test/features/player/presentation/player_progress_test.dart test/features/player/presentation/player_responsive_layout_test.dart
```

Expected: adaptive-sidebar test fails at the new 1147/1180 boundary; progress test documents current geometry.

- [ ] **Step 3: Implement the exact sidebar hysteresis**

Replace `resolveSidebarWidthForcedCompact` with:

```dart
bool resolveSidebarWidthForcedCompact({
  required double width,
  required bool? wasForcedCompact,
}) {
  if (wasForcedCompact == null) {
    return width < 1148;
  }
  if (wasForcedCompact) {
    return width < 1180;
  }
  return width < 1148;
}
```

Keep `SidebarModeController.build()` returning `HeniSidebarMode.expanded`, so manual compact remains respected only when width does not force a mode.

In `HeniAdaptiveSidebar.build`, resolve the two transition durations once:

```dart
final disableAnimations =
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;
final sizeDuration = disableAnimations
    ? Duration.zero
    : const Duration(milliseconds: 240);
final switchDuration = disableAnimations
    ? Duration.zero
    : const Duration(milliseconds: 180);
```

Use `sizeDuration` on `AnimatedSize` and `switchDuration` on `AnimatedSwitcher`.

- [ ] **Step 4: Replace PlayerScreen's extra gray veil with the panoramic frame**

In `PlayerScreen.build`, derive the semantic theme and native state once:

```dart
final shellTheme = HeniShellTheme.fromPalette(palette);
final isMaximized = ref.watch(heniWindowControllerProvider);
```

Return a transparent scaffold whose body is structured as:

```dart
return Scaffold(
  backgroundColor: Colors.transparent,
  body: HeniPanoramicShellFrame(
    shellTheme: shellTheme,
    isMaximized: isMaximized,
    child: Stack(
      children: [
        Positioned.fill(
          child: GlobalSceneryBackdrop(
            imagePaths: sceneryImages,
            palette: palette,
            shellTheme: shellTheme,
            mode: uiStyle == HeniUiStyle.scenery
                ? HeniBackdropMode.playback
                : HeniBackdropMode.library,
          ),
        ),
      ],
    ),
  ),
);
```

Keep the current second `Positioned.fill` and toast as later children of that same `Stack`. In the second child, replace only the `AnimatedContainer(duration, curve, decoration, child: SafeArea(...))` wrapper with its existing `SafeArea(...)` child. This is a mechanical unwrap: the `LayoutBuilder` and its top/sidebar/content/dock `Stack` remain byte-for-byte unchanged. The removed `AnimatedContainer` is the `palette.surface` alpha `0.16/0.30` veil that currently darkens the complete UI a second time.

- [ ] **Step 5: Apply semantic surfaces to the four outer regions**

- Change `_TopNavigation` to use `HeniShellSurfaceRole.chrome`, zero top/side margin, and `HeniBrandWordmark` inside `HeniWindowDragRegion`.
- Change expanded and compact `_Sidebar` outer surfaces to `HeniShellSurfaceRole.rail` with 10–12 px radius and no shadow.
- Change the outer `_LibraryContent` list surface to `HeniShellSurfaceRole.content`; keep row separators but remove hover shadows.
- Change `_BottomPlayerBar` to `HeniShellSurfaceRole.dock`, 12 px radius when restored, and a single theme border.
- Pass the same `shellTheme` into both `HeniWindowControls` call sites.
- Keep all inner dialogs, focused playback stage, and playlist actions functionally unchanged.

Replace `_TopBrand`'s animated round badge and uppercase text with:

```dart
return SizedBox(
  width: layout.quiet ? 54 : 82,
  child: const Align(
    alignment: Alignment.centerLeft,
    child: HeniBrandWordmark(),
  ),
);
```

- [ ] **Step 6: Run formatting, analysis, and responsive tests**

Run:

```powershell
dart format lib/features/player/presentation/player_screen.dart lib/features/player/presentation/adaptive_sidebar.dart lib/features/player/application/sidebar_mode.dart test/features/player/presentation/adaptive_sidebar_test.dart test/features/player/presentation/player_progress_test.dart
flutter analyze
flutter test test/features/player/presentation/adaptive_sidebar_test.dart test/features/player/presentation/player_progress_test.dart test/features/player/presentation/player_responsive_layout_test.dart test/features/player/presentation/player_window_chrome_test.dart
```

Expected: analysis has no issues; all focused tests pass with no overflow exception.

- [ ] **Step 7: Commit shell composition**

```powershell
git add lib/features/player/presentation/player_screen.dart lib/features/player/presentation/adaptive_sidebar.dart lib/features/player/application/sidebar_mode.dart test/features/player/presentation/adaptive_sidebar_test.dart test/features/player/presentation/player_progress_test.dart test/features/player/presentation/player_responsive_layout_test.dart
git commit -m "feat: compose edge-to-edge panoramic player shell"
```

---

### Task 5: Extract and polish the volume interaction

**Files:**
- Create: `lib/features/player/presentation/volume_control.dart`
- Create: `test/features/player/presentation/volume_control_test.dart`
- Modify: `lib/features/player/presentation/player_screen.dart`

**Interfaces:**
- Consumes: `PlaybackEngine`, `HeniPalette`, `HeniShellTheme`.
- Produces: `HeniVolumeControl(onVolumeCommitted: ValueChanged<double>)`.

- [ ] **Step 1: Write failing volume behavior tests**

Create tests that open the popover and invoke the public Slider callbacks:

```dart
testWidgets('volume updates live and persists only when interaction ends', (
  tester,
) async {
  final engine = FakePlaybackEngine(volume: 70);
  final committed = <double>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HeniVolumeControl(
          engine: engine,
          palette: HeniPalette.nocturne,
          shellTheme: HeniShellTheme.fromPalette(HeniPalette.nocturne),
          onVolumeCommitted: committed.add,
        ),
      ),
    ),
  );

  await tester.tap(find.byTooltip('音量 70%'));
  await tester.pumpAndSettle();
  final slider = tester.widget<Slider>(find.byType(Slider));
  slider.onChanged!(35);
  await tester.pump();
  expect(engine.currentVolume, 35);
  expect(committed, isEmpty);

  slider.onChangeEnd!(35);
  expect(committed, [35]);
});

testWidgets('mute restores the last audible volume', (tester) async {
  final engine = FakePlaybackEngine(volume: 64);
  await pumpVolumeControl(tester, engine);
  await tester.tap(find.byTooltip('音量 64%'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('静音'));
  await tester.pump();
  expect(engine.currentVolume, 0);
  await tester.tap(find.byTooltip('恢复音量'));
  await tester.pump();
  expect(engine.currentVolume, 64);
});
```

The test file must define `FakePlaybackEngine` with a broadcast volume controller and a `pumpVolumeControl` helper that supplies `onVolumeCommitted: (_) {}`.

Use this complete test support code:

```dart
class FakePlaybackEngine implements PlaybackEngine {
  FakePlaybackEngine({required double volume}) : _volume = volume;

  final _volumeController = StreamController<double>.broadcast();
  double _volume;

  @override
  double get currentVolume => _volume;

  @override
  Stream<double> get volume => _volumeController.stream;

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
    _volumeController.add(volume);
  }

  @override
  Stream<bool> get completed => const Stream.empty();
  @override
  bool get currentPlaying => false;
  @override
  Stream<Duration> get duration => const Stream.empty();
  @override
  Stream<bool> get playing => const Stream.empty();
  @override
  Stream<Duration> get position => const Stream.empty();
  @override
  Future<void> dispose() => _volumeController.close();
  @override
  Future<void> openItem(MediaItem item, {bool play = false}) async {}
  @override
  Future<void> openPath(String path, {bool play = false}) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> stop() async {}
}

Future<void> pumpVolumeControl(
  WidgetTester tester,
  FakePlaybackEngine engine,
) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HeniVolumeControl(
          engine: engine,
          palette: HeniPalette.nocturne,
          shellTheme: HeniShellTheme.fromPalette(HeniPalette.nocturne),
          onVolumeCommitted: (_) {},
        ),
      ),
    ),
  );
}
```

- [ ] **Step 2: Run the test and verify the missing control**

Run:

```powershell
flutter test test/features/player/presentation/volume_control_test.dart
```

Expected: compilation fails because `HeniVolumeControl` does not exist.

- [ ] **Step 3: Implement the public volume control**

Implement `HeniVolumeControl` as a `MenuAnchor` with:

```dart
class HeniVolumeControl extends StatefulWidget {
  const HeniVolumeControl({
    required this.engine,
    required this.palette,
    required this.shellTheme,
    required this.onVolumeCommitted,
    super.key,
  });

  final PlaybackEngine engine;
  final HeniPalette palette;
  final HeniShellTheme shellTheme;
  final ValueChanged<double> onVolumeCommitted;

  @override
  State<HeniVolumeControl> createState() => _HeniVolumeControlState();
}
```

State rules:

```dart
void _setLive(double value) {
  final next = value.clamp(0.0, 100.0).toDouble();
  if (next > 0) _lastAudibleVolume = next;
  setState(() => _volume = next);
  unawaited(widget.engine.setVolume(next));
}

void _commit(double value) {
  final next = value.clamp(0.0, 100.0).toDouble();
  _setLive(next);
  widget.onVolumeCommitted(next);
}

void _toggleMute() {
  if (_volume > 0) {
    _lastAudibleVolume = _volume;
    _commit(0);
  } else {
    _commit(_lastAudibleVolume <= 0 ? 60 : _lastAudibleVolume);
  }
}
```

The 250 × 64 popover contains a mute IconButton, `Slider(value: _volume, onChanged: _setLive, onChangeEnd: _commit)`, and a fixed-width `Text('${_volume.round()}%')`. Wrap it in a `Listener`; a mouse-wheel notch changes volume by 2 and commits the resulting value. Use `shellTheme.dock` and `shellTheme.border`, not an opaque black pill.

- [ ] **Step 4: Replace both private volume-menu uses**

In `player_screen.dart`, replace `_VolumeMenuButton` in full and compact bottom bars with `HeniVolumeControl`, pass `HeniShellTheme.fromPalette(palette)`, and delete `_VolumeMenuButton`, `_VolumeBubble`, and `_VolumeBarPainter`.

- [ ] **Step 5: Run focused and persistence tests**

Run:

```powershell
dart format lib/features/player/presentation/volume_control.dart lib/features/player/presentation/player_screen.dart test/features/player/presentation/volume_control_test.dart
flutter test test/features/player/presentation/volume_control_test.dart test/features/player/application/playback_queue_controller_test.dart
flutter analyze
```

Expected: live engine updates, one persistence callback at interaction end, mute restore, and stored volume tests all pass.

- [ ] **Step 6: Commit the volume control**

```powershell
git add lib/features/player/presentation/volume_control.dart lib/features/player/presentation/player_screen.dart test/features/player/presentation/volume_control_test.dart
git commit -m "feat: polish volume popover interaction"
```

---

### Task 6: Locate the current queue track without destroying filters

**Files:**
- Modify: `lib/features/player/presentation/playback_queue_location.dart`
- Modify: `lib/features/player/presentation/player_screen.dart`
- Modify: `test/features/player/presentation/playback_queue_location_test.dart`

**Interfaces:**
- Produces: `CurrentTrackLocateState` and `currentTrackLocateState(...)`.
- Consumes: queue items, current index, and the existing query string.

- [ ] **Step 1: Replace query-mutating tests with explicit locate-state tests**

Use these assertions:

```dart
expect(
  currentTrackLocateState(items: items, currentIndex: 1, query: 'alpha'),
  CurrentTrackLocateState.hiddenByFilter,
);
expect(
  currentTrackLocateState(items: items, currentIndex: 1, query: 'beta'),
  CurrentTrackLocateState.visible,
);
expect(
  currentTrackLocateState(items: items, currentIndex: -1, query: 'alpha'),
  CurrentTrackLocateState.unavailable,
);
```

- [ ] **Step 2: Run the focused test and verify the missing enum**

Run:

```powershell
flutter test test/features/player/presentation/playback_queue_location_test.dart
```

Expected: compilation fails because `CurrentTrackLocateState` does not exist.

- [ ] **Step 3: Implement the pure locate-state function**

Replace `queryForLocatingCurrentTrack` with:

```dart
enum CurrentTrackLocateState { visible, hiddenByFilter, unavailable }

CurrentTrackLocateState currentTrackLocateState({
  required List<MediaItem> items,
  required int currentIndex,
  required String query,
}) {
  if (currentIndex < 0 || currentIndex >= items.length) {
    return CurrentTrackLocateState.unavailable;
  }
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return CurrentTrackLocateState.visible;
  }
  final current = items[currentIndex];
  final visible = current.title.toLowerCase().contains(normalized) ||
      current.path.toLowerCase().contains(normalized);
  return visible
      ? CurrentTrackLocateState.visible
      : CurrentTrackLocateState.hiddenByFilter;
}
```

- [ ] **Step 4: Update the queue dialog behavior**

Add `_locateMessage` and `_locateHighlight` state fields. At the start of `_locateCurrentTrack`, switch on `currentTrackLocateState`:

```dart
switch (currentTrackLocateState(
  items: queue.playbackQueue.items,
  currentIndex: queue.currentIndex,
  query: _query,
)) {
  case CurrentTrackLocateState.unavailable:
    setState(() => _locateMessage = '当前没有正在播放的歌曲');
    return;
  case CurrentTrackLocateState.hiddenByFilter:
    setState(() => _locateMessage = '当前歌曲不在筛选结果中');
    return;
  case CurrentTrackLocateState.visible:
    setState(() {
      _locateMessage = null;
      _locateHighlight = true;
    });
}
```

Keep the existing estimated scroll plus `Scrollable.ensureVisible`. After scrolling, wait `const Duration(milliseconds: 900)` and clear `_locateHighlight` if mounted. Show `_locateMessage` below the search row. Pass `locateHighlight: isCurrent && _locateHighlight` into `_PlaybackQueueRow`; use `AnimatedContainer` with `shellTheme.selected` for the one-shot flash. Do not change `_query` or `_searchController` inside the locate action.

- [ ] **Step 5: Run queue tests and analysis**

Run:

```powershell
dart format lib/features/player/presentation/playback_queue_location.dart lib/features/player/presentation/player_screen.dart test/features/player/presentation/playback_queue_location_test.dart
flutter test test/features/player/presentation/playback_queue_location_test.dart test/features/player/application/playback_queue_controller_test.dart
flutter analyze
```

Expected: locate-state tests pass and no stale reference to `queryForLocatingCurrentTrack` remains.

- [ ] **Step 6: Commit the queue locate polish**

```powershell
git add lib/features/player/presentation/playback_queue_location.dart lib/features/player/presentation/player_screen.dart test/features/player/presentation/playback_queue_location_test.dart
git commit -m "feat: preserve filters when locating current track"
```

---

### Task 7: Generate the lowercase native `heni` icon

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Create: `tool/generate_windows_icon.dart`
- Modify: `windows/runner/resources/app_icon.ico`

**Interfaces:**
- Consumes: Dart `image: ^4.8.0` as a development dependency.
- Produces: deterministic ICO frames at 16, 24, 32, 48, and 256 px.

- [ ] **Step 1: Add the direct icon-tool dependency**

Add under `dev_dependencies`:

```yaml
  image: ^4.8.0
```

Run `flutter pub get`; expected: `pubspec.lock` keeps `image` at a compatible 4.8.x release and changes its dependency classification to direct development.

- [ ] **Step 2: Create the deterministic generator**

Create `tool/generate_windows_icon.dart`:

```dart
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  const sizes = [16, 24, 32, 48, 256];
  final master = img.Image(width: 256, height: 256, numChannels: 4);
  img.fill(master, color: img.ColorRgba8(12, 24, 21, 255));
  img.drawRect(
    master,
    x1: 5,
    y1: 5,
    x2: 250,
    y2: 250,
    color: img.ColorRgba8(97, 198, 170, 255),
    thickness: 6,
  );
  img.drawString(
    master,
    'heni',
    font: img.arial48,
    color: img.ColorRgba8(242, 245, 232, 255),
  );

  final icon = img.copyResize(
    master,
    width: sizes.first,
    height: sizes.first,
    interpolation: img.Interpolation.average,
  );
  for (final size in sizes.skip(1)) {
    icon.addFrame(
      img.copyResize(
        master,
        width: size,
        height: size,
        interpolation: img.Interpolation.average,
      ),
    );
  }

  final output = File('windows/runner/resources/app_icon.ico');
  output.writeAsBytesSync(img.encodeIco(icon));
  stdout.writeln('${output.path}: ${output.lengthSync()} bytes');
}
```

- [ ] **Step 3: Generate and inspect the ICO container**

Run:

```powershell
dart run tool/generate_windows_icon.dart
$bytes = [IO.File]::ReadAllBytes('windows/runner/resources/app_icon.ico')
[pscustomobject]@{
  Reserved = [BitConverter]::ToUInt16($bytes, 0)
  Type = [BitConverter]::ToUInt16($bytes, 2)
  Frames = [BitConverter]::ToUInt16($bytes, 4)
}
```

Expected: `Reserved = 0`, `Type = 1`, and `Frames = 5`.

- [ ] **Step 4: Build the Windows runner to validate the resource**

Run:

```powershell
flutter build windows --debug
```

Expected: build succeeds and `Runner.rc` embeds the regenerated icon without a resource compiler error.

- [ ] **Step 5: Commit the reproducible brand asset**

```powershell
git add pubspec.yaml pubspec.lock tool/generate_windows_icon.dart windows/runner/resources/app_icon.ico
git commit -m "feat: add lowercase heni Windows icon"
```

---

### Task 8: Full verification, Strata maintenance, normal Release application, and push

**Files:**
- Modify: `strata.md`
- Modify: `logs/plan.md`
- Modify: `logs/windows.md`
- Modify: `logs/request-log.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: every implementation task and the exact feature/main workspace Release paths.
- Produces: verified feature Release, verified normal-workspace Release, project records, and pushed branches.

- [ ] **Step 1: Run the complete automated verification from the feature worktree**

Run:

```powershell
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
flutter build windows --debug
flutter build windows --release
git diff --check
```

Expected: every command exits 0. If a test or build fails, stop this task and repair it in the task that owns the regression before continuing.

- [ ] **Step 2: Perform the exact feature-Release smoke check**

Launch only:

```text
D:\codespace\fhfeishi\heni\.worktrees\studio-listening-console\build\windows\x64\runner\Release\heni.exe
```

Verify and capture evidence for:

- native style has no `WS_CAPTION`;
- outer background reaches all four edges;
- top bar contains lowercase `heni` and no round `H`/uppercase `HENI`;
- minimize, maximize/restore, close, drag, and double-click maximize work;
- restored minimum size cannot shrink below 900 × 620 logical pixels;
- dragging width across 1180 switches/restores the side rail without oscillation;
- progress times never overlap the seek track;
- volume live update, mute restore, and queue locate work;
- lyrics and FLAC export controls are absent.

- [ ] **Step 3: Read the Strata router and update exact project records**

Read `strata.md` completely, then the routed `logs/plan.md`, `logs/windows.md`, `logs/request-log.md`, and `README.md`. Record:

```markdown
- 2026-07-17: adopted the panoramic theme shell; scenery now covers native chrome, side rail, content, and playback dock.
- Branding is lowercase `heni`; uppercase badge/wordmark were removed.
- Queue locate preserves filters, volume persistence is deferred until interaction end, and the minimum client remains 900 × 620.
- Release claims require launching the exact normal-workspace executable and matching it to the delivered Git commit.
```

In `logs/windows.md`, include the observed feature executable SHA-256, timestamp, native style value, DPI, restored/minimum size, and screenshot path from Step 2. In `README.md`, update the UI summary and keep the existing no-lyrics/no-export boundary.

- [ ] **Step 4: Commit verified documentation**

Run:

```powershell
git add strata.md logs/plan.md logs/windows.md logs/request-log.md README.md
git diff --cached --check
git commit -m "docs: record panoramic shell release"
```

Expected: one documentation commit with no whitespace errors.

- [ ] **Step 5: Verify branch cleanliness and push the feature branch**

Run:

```powershell
git status --short --branch
git push origin codex/studio-listening-console
```

Expected: the worktree is clean and `origin/codex/studio-listening-console` advances to the verified commit.

- [ ] **Step 6: Fast-forward the normal workspace to the same commit**

From `D:\codespace\fhfeishi\heni`, first require a clean status, then run:

```powershell
git status --short --branch
git merge --ff-only codex/studio-listening-console
git rev-parse HEAD
git rev-parse codex/studio-listening-console
```

Expected: status is clean before the merge and both revision commands print the same commit after it. Do not use reset, checkout of individual files, or binary copying.

- [ ] **Step 7: Rebuild and verify the normal-workspace Release**

From `D:\codespace\fhfeishi\heni`, run:

```powershell
flutter pub get
flutter build windows --release
Get-FileHash -Algorithm SHA256 'build\windows\x64\runner\Release\heni.exe'
Get-Item 'build\windows\x64\runner\Release\heni.exe' | Select-Object FullName, Length, LastWriteTime
```

Launch only `D:\codespace\fhfeishi\heni\build\windows\x64\runner\Release\heni.exe` and repeat the outer-frame, lowercase wordmark, resize, progress, volume, queue-locate, and no-export smoke checks. Capture a normal-workspace screenshot and compare the Git commit and observed UI with the feature worktree.

- [ ] **Step 8: Push the normal workspace branch**

Run:

```powershell
git push -u origin codex/player-usability-upgrade
```

Expected: remote branch points to the same verified commit as `codex/studio-listening-console`.

- [ ] **Step 9: Final repository audit**

Run in both worktrees:

```powershell
git status --short --branch
git log -1 --oneline
```

Expected: both worktrees are clean, both branches report the same tip commit, both intended remote pushes succeeded, and no background Heni process remains from smoke testing.
