# Studio Matte Listening Console Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Heni's native white Windows caption and decorative playback stage with a deeply themed, captionless studio-matte shell and a practical listening console that shows trustworthy local-audio information without lyrics.

**Architecture:** The Win32 runner owns captionless resizing and window operations through one method channel. Flutter owns the themed title-bar controls, one global scenery background, responsive listening-console presentation, and local-file actions. `player_screen.dart` remains the composition root while new components live in focused files.

**Tech Stack:** Flutter 3 / Dart 3.7, Riverpod 3, Flutter Windows runner C++, Win32, Flutter method channels, `flutter_test`.

## Global Constraints

- Full-player minimum logical size remains exactly `900 × 620`.
- Do not add a second window-management dependency.
- Do not add lyrics, audio conversion, equalization, normalization, ReplayGain, or crossfade.
- Do not label MP4/M4A/MP3 sources as lossless or imply conversion to FLAC.
- Use one full-window scenery image layer only.
- Keep all three window controls visible at minimum width.
- Keep the existing playback engine, queue state, adaptive sidebar, and responsive progress behavior.
- Do not terminate a user-owned running Release process during verification.

---

## File Map

- Create `lib/services/window/heni_window_controller.dart`: method-channel wrapper and maximized state.
- Create `lib/features/player/presentation/player_window_chrome.dart`: drag region and window buttons.
- Modify `windows/runner/flutter_window.h`: own the window method channel.
- Modify `windows/runner/flutter_window.cpp`: handle window methods and maximized notifications.
- Modify `windows/runner/win32_window.cpp`: captionless style and DPI-aware edge/corner hit testing.
- Create `lib/features/player/presentation/global_scenery_backdrop.dart`: one adaptive full-window scenery layer.
- Create `lib/services/files/local_file_actions.dart`: reveal a media file in Explorer.
- Create `lib/features/player/presentation/listening_console.dart`: responsive playback/empty-state console.
- Modify `lib/features/player/application/player_state.dart`: delete lyrics state and parsing.
- Modify `lib/features/player/application/playback_queue_controller.dart`: remove lyrics load/clear calls and add non-blocking status reporting for file actions.
- Modify `lib/features/player/presentation/player_screen.dart`: compose the new frame, backdrop, console, and callbacks; remove legacy scenery/lyrics presentation.
- Create tests under `test/services/window`, `test/services/files`, and `test/features/player/presentation`.

---

### Task 1: Window Controller Contract

**Files:**
- Create: `lib/services/window/heni_window_controller.dart`
- Create: `test/services/window/heni_window_controller_test.dart`

**Interfaces:**
- Produces: `heniWindowControllerProvider`
- Produces: `HeniWindowController.minimize()`, `toggleMaximize()`, `close()`, `beginDrag()`
- Produces: provider state `bool`, where `true` means maximized

- [ ] **Step 1: Write the failing method-channel tests**

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heni/services/window/heni_window_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('heni/window');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'isMaximized') return false;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('sends the four native window actions', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(heniWindowControllerProvider.notifier);

    await controller.minimize();
    await controller.toggleMaximize();
    await controller.beginDrag();
    await controller.close();

    expect(
      calls.map((call) => call.method),
      containsAllInOrder(['isMaximized', 'minimize', 'toggleMaximize', 'beginDrag', 'close']),
    );
  });

  test('updates state from maximizedChanged', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(heniWindowControllerProvider);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'heni/window',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('maximizedChanged', true),
          ),
          (_) {},
        );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(heniWindowControllerProvider), isTrue);
  });
}
```

- [ ] **Step 2: Run the tests and verify RED**

Run:

```powershell
flutter test test/services/window/heni_window_controller_test.dart
```

Expected: FAIL because `heni_window_controller.dart` and its provider do not exist.

- [ ] **Step 3: Implement the minimal Riverpod controller**

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final heniWindowControllerProvider =
    NotifierProvider<HeniWindowController, bool>(HeniWindowController.new);

class HeniWindowController extends Notifier<bool> {
  static const MethodChannel _channel = MethodChannel('heni/window');

  @override
  bool build() {
    _channel.setMethodCallHandler(_handleNativeCall);
    ref.onDispose(() => _channel.setMethodCallHandler(null));
    unawaited(_readMaximized());
    return false;
  }

  Future<void> minimize() => _invoke('minimize');
  Future<void> close() => _invoke('close');
  Future<void> beginDrag() => _invoke('beginDrag');

  Future<void> toggleMaximize() async {
    await _invoke('toggleMaximize');
    await _readMaximized();
  }

  Future<void> _readMaximized() async {
    try {
      state = await _channel.invokeMethod<bool>('isMaximized') ?? false;
    } on PlatformException catch (error) {
      debugPrint('Heni window state unavailable: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Heni window channel unavailable: $error');
    }
  }

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException catch (error) {
      debugPrint('Heni window action $method failed: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Heni window action $method unavailable: $error');
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method == 'maximizedChanged') {
      state = call.arguments == true;
    }
  }
}
```

- [ ] **Step 4: Run the focused tests and verify GREEN**

Run:

```powershell
flutter test test/services/window/heni_window_controller_test.dart
```

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/services/window/heni_window_controller.dart test/services/window/heni_window_controller_test.dart
git commit -m "feat: add Windows window controller"
```

---

### Task 2: Captionless Native Window And Flutter Chrome

**Files:**
- Modify: `windows/runner/win32_window.cpp`
- Modify: `windows/runner/flutter_window.h`
- Modify: `windows/runner/flutter_window.cpp`
- Create: `lib/features/player/presentation/player_window_chrome.dart`
- Create: `test/features/player/presentation/player_window_chrome_test.dart`
- Modify: `lib/features/player/presentation/player_screen.dart:1705-1745`

**Interfaces:**
- Consumes: `heniWindowControllerProvider`
- Produces: `HeniWindowDragRegion`
- Produces: `HeniWindowControls`

- [ ] **Step 1: Write failing window-chrome widget tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heni/design/app_theme.dart';
import 'package:heni/features/player/presentation/player_window_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('heni/window');
  final methods = <String>[];

  setUp(() {
    methods.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          if (call.method == 'isMaximized') return false;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('window controls invoke native actions', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: HeniWindowControls(palette: HeniPalette.plum),
          ),
        ),
      ),
    );
    await tester.pump();
    methods.clear();

    await tester.tap(find.byTooltip('最小化'));
    await tester.tap(find.byTooltip('最大化'));
    await tester.tap(find.byTooltip('关闭'));
    await tester.pump();

    expect(methods, ['minimize', 'toggleMaximize', 'isMaximized', 'close']);
  });

  testWidgets('double-clicking drag region toggles maximize', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: HeniWindowDragRegion(
              child: SizedBox(width: 100, height: 40),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    methods.clear();

    await tester.tap(find.byType(HeniWindowDragRegion));
    await tester.tap(find.byType(HeniWindowDragRegion));
    await tester.pump();

    expect(methods, contains('toggleMaximize'));
  });
}
```

- [ ] **Step 2: Run the widget test and verify RED**

Run:

```powershell
flutter test test/features/player/presentation/player_window_chrome_test.dart
```

Expected: FAIL because the chrome widgets do not exist.

- [ ] **Step 3: Implement the Flutter chrome widgets**

`HeniWindowDragRegion` must:

```dart
GestureDetector(
  behavior: HitTestBehavior.opaque,
  onDoubleTap: () => ref
      .read(heniWindowControllerProvider.notifier)
      .toggleMaximize(),
  onPanStart: (_) => ref
      .read(heniWindowControllerProvider.notifier)
      .beginDrag(),
  child: child,
)
```

`HeniWindowControls` must render three `42 × 38` icon targets, use
`Icons.minimize_rounded`, switch between `Icons.crop_square_rounded` and
`Icons.filter_none_rounded`, and use a red fill only for close hover/press.

- [ ] **Step 4: Verify the Flutter chrome test is GREEN**

Run:

```powershell
flutter test test/features/player/presentation/player_window_chrome_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Add the native channel**

In `FlutterWindow::OnCreate`, create
`flutter::MethodChannel<flutter::EncodableValue>` named `heni/window` with the
standard codec. Handle:

```cpp
if (method == "minimize") {
  ShowWindow(GetHandle(), SW_MINIMIZE);
} else if (method == "toggleMaximize") {
  ShowWindow(GetHandle(), IsZoomed(GetHandle()) ? SW_RESTORE : SW_MAXIMIZE);
} else if (method == "close") {
  PostMessage(GetHandle(), WM_CLOSE, 0, 0);
} else if (method == "beginDrag") {
  ReleaseCapture();
  SendMessage(GetHandle(), WM_NCLBUTTONDOWN, HTCAPTION, 0);
} else if (method == "isMaximized") {
  result->Success(flutter::EncodableValue(IsZoomed(GetHandle()) != FALSE));
}
```

On `WM_SIZE`, invoke `maximizedChanged` with `IsZoomed(hwnd) != FALSE`.

- [ ] **Step 6: Remove the native caption and preserve resizing**

Create the window with:

```cpp
constexpr DWORD kHeniWindowStyle =
    WS_OVERLAPPEDWINDOW & ~WS_CAPTION;
```

Add `WM_NCHITTEST` handling that returns `HTTOPLEFT`, `HTTOP`, `HTTOPRIGHT`,
`HTLEFT`, `HTRIGHT`, `HTBOTTOMLEFT`, `HTBOTTOM`, or `HTBOTTOMRIGHT` inside an
8-logical-pixel DPI-scaled edge, and `HTCLIENT` when maximized or away from an
edge. Keep the existing `WM_GETMINMAXINFO` minimum-size code.

- [ ] **Step 7: Integrate chrome into `_TopNavigation`**

Wrap `_TopBrand` in `HeniWindowDragRegion`, keep search/palette/settings outside
the drag region, add a low-contrast divider, then append
`HeniWindowControls(palette: palette)`.

- [ ] **Step 8: Verify Flutter and Windows compilation**

Run:

```powershell
dart format lib/services/window lib/features/player/presentation/player_window_chrome.dart test/services/window test/features/player/presentation/player_window_chrome_test.dart
flutter test test/services/window/heni_window_controller_test.dart test/features/player/presentation/player_window_chrome_test.dart
flutter build windows --debug
```

Expected: tests pass and `build/windows/x64/runner/Debug/heni.exe` is produced.

- [ ] **Step 9: Commit**

```powershell
git add windows/runner lib/features/player/presentation/player_window_chrome.dart lib/features/player/presentation/player_screen.dart test/features/player/presentation/player_window_chrome_test.dart
git commit -m "feat: integrate themed Windows title bar"
```

---

### Task 3: One Global Deep-Tinted Scenery Backdrop

**Files:**
- Create: `lib/features/player/presentation/global_scenery_backdrop.dart`
- Create: `test/features/player/presentation/global_scenery_backdrop_test.dart`
- Modify: `lib/features/player/presentation/player_screen.dart:895-1060,1110-1310,3842-3980`

**Interfaces:**
- Produces: `HeniBackdropMode { playback, library }`
- Produces: `HeniBackdropTreatment.forMode(HeniBackdropMode mode)`
- Produces: `GlobalSceneryBackdrop`

- [ ] **Step 1: Write failing treatment tests**

```dart
test('library treatment is darker and blurrier than playback', () {
  final playback = HeniBackdropTreatment.forMode(HeniBackdropMode.playback);
  final library = HeniBackdropTreatment.forMode(HeniBackdropMode.library);

  expect(library.overlayOpacity, greaterThan(playback.overlayOpacity));
  expect(library.blurSigma, greaterThan(playback.blurSigma));
  expect(library.seedWashOpacity, greaterThan(playback.seedWashOpacity));
});
```

Add a widget test that pumps `GlobalSceneryBackdrop` with no paths and expects
`find.byKey(const ValueKey('global-scenery-fallback'))` once.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
flutter test test/features/player/presentation/global_scenery_backdrop_test.dart
```

Expected: FAIL because the backdrop types do not exist.

- [ ] **Step 3: Implement the treatment model and widget**

Use these exact treatment values:

```dart
static const playback = HeniBackdropTreatment(
  blurSigma: 12,
  overlayOpacity: 0.44,
  saturation: 0.72,
  seedWashOpacity: 0.18,
);

static const library = HeniBackdropTreatment(
  blurSigma: 24,
  overlayOpacity: 0.68,
  saturation: 0.52,
  seedWashOpacity: 0.24,
);
```

The widget:

- cycles valid paths every 11 seconds;
- crossfades over 1200 ms;
- uses `Image.file(..., fit: BoxFit.cover)`;
- applies one `ImageFiltered` blur;
- applies a grayscale/saturation color matrix;
- applies one dark overlay and one palette radial wash;
- uses a palette gradient fallback with the specified key.

- [ ] **Step 4: Integrate the global backdrop**

At the root of `PlayerScreen`, replace `_AmbientBackdrop` and `_CornerGlow`
with:

```dart
GlobalSceneryBackdrop(
  imagePaths: sceneryImages,
  palette: palette,
  mode: uiStyle == HeniUiStyle.scenery
      ? HeniBackdropMode.playback
      : HeniBackdropMode.library,
)
```

Remove the nested `SceneryStage` from `_SceneryContent` so playback view does
not create a second image layer.

- [ ] **Step 5: Verify RED/GREEN scope**

Run:

```powershell
dart format lib/features/player/presentation/global_scenery_backdrop.dart test/features/player/presentation/global_scenery_backdrop_test.dart lib/features/player/presentation/player_screen.dart
flutter test test/features/player/presentation/global_scenery_backdrop_test.dart test/features/player/presentation/adaptive_sidebar_test.dart test/features/player/presentation/player_progress_test.dart
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```powershell
git add lib/features/player/presentation/global_scenery_backdrop.dart lib/features/player/presentation/player_screen.dart test/features/player/presentation/global_scenery_backdrop_test.dart
git commit -m "feat: add full-window scenery backdrop"
```

---

### Task 4: Local File Reveal Action

**Files:**
- Create: `lib/services/files/local_file_actions.dart`
- Create: `test/services/files/local_file_actions_test.dart`
- Modify: `lib/features/player/application/playback_queue_controller.dart`
- Modify: `test/features/player/application/playback_queue_controller_test.dart`

**Interfaces:**
- Produces: `LocalFileActionResult`
- Produces: `LocalFileActions.revealInFileManager(String path)`
- Produces: `PlaybackQueueController.reportStatus(String message)`

- [ ] **Step 1: Write failing service tests**

Test three cases with injected `exists`, `isWindows`, and `runProcess`
callbacks:

```dart
expect(await actions.revealInFileManager(path), LocalFileActionResult.success);
expect(executable, 'explorer.exe');
expect(arguments, ['/select,$path']);
```

Also assert a missing path returns `missing` without running a process, and a
non-zero process exit returns `failed`.

- [ ] **Step 2: Run the service tests and verify RED**

Run:

```powershell
flutter test test/services/files/local_file_actions_test.dart
```

Expected: FAIL because the service does not exist.

- [ ] **Step 3: Implement the injected service**

```dart
enum LocalFileActionResult { success, missing, unsupported, failed }

class LocalFileActions {
  const LocalFileActions({
    this.exists = FileSystemEntity.isFileSync,
    this.isWindows = Platform.isWindows,
    this.runProcess = Process.run,
  });

  final bool Function(String path) exists;
  final bool isWindows;
  final Future<ProcessResult> Function(String, List<String>) runProcess;

  Future<LocalFileActionResult> revealInFileManager(String path) async {
    if (!exists(path)) return LocalFileActionResult.missing;
    if (!isWindows) return LocalFileActionResult.unsupported;
    try {
      final result = await runProcess('explorer.exe', ['/select,$path']);
      return result.exitCode == 0
          ? LocalFileActionResult.success
          : LocalFileActionResult.failed;
    } catch (_) {
      return LocalFileActionResult.failed;
    }
  }
}
```

- [ ] **Step 4: Add and test `reportStatus`**

Add a controller test that calls `reportStatus('已打开文件位置')` and expects
`state.statusMessage` to match with `lastError == null`. Implement:

```dart
void reportStatus(String message) {
  state = state.copyWith(statusMessage: message, lastError: null);
}
```

- [ ] **Step 5: Run focused tests and verify GREEN**

Run:

```powershell
dart format lib/services/files/local_file_actions.dart test/services/files/local_file_actions_test.dart lib/features/player/application/playback_queue_controller.dart test/features/player/application/playback_queue_controller_test.dart
flutter test test/services/files/local_file_actions_test.dart test/features/player/application/playback_queue_controller_test.dart
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```powershell
git add lib/services/files/local_file_actions.dart lib/features/player/application/playback_queue_controller.dart test/services/files/local_file_actions_test.dart test/features/player/application/playback_queue_controller_test.dart
git commit -m "feat: reveal current media in Explorer"
```

---

### Task 5: Responsive Listening Console

**Files:**
- Create: `lib/features/player/presentation/listening_console.dart`
- Create: `test/features/player/presentation/listening_console_test.dart`

**Interfaces:**
- Produces: `heniAudioDetailLabels(MediaProbe? probe)`
- Produces: `HeniListeningConsole`
- Consumes: `MediaItem? currentMedia`, `MediaItem? nextMedia`, `AsyncValue<MediaProbe?> mediaProbe`, palette, library counts, and callbacks

- [ ] **Step 1: Write failing audio-label tests**

Construct a `MediaProbe` with an AAC LC stream at `44100`, stereo, and
`256000` bit/s. Assert:

```dart
expect(
  heniAudioDetailLabels(probe),
  containsAll(['AAC LC', '256 kbps', '44.1 kHz', '双声道']),
);
```

Construct a FLAC stream and assert the list contains `FLAC` and `无损`. Assert
an AAC stream never contains `无损`.

- [ ] **Step 2: Write failing widget tests**

Pump the console at 1200 px and verify:

- current title;
- `实际播放参数`;
- `原始解码播放，不进行二次转码`;
- next-track title;
- `定位当前曲目`;
- `打开文件位置`.

Tap the two actions and verify callbacks. Pump at 700 px and verify the
right-side panel key `listening-console-side-panel` is absent. Pump with no
current media and verify `选择文件`, `导入目录`, and library counts appear while
audio/next cards do not.

- [ ] **Step 3: Run the tests and verify RED**

Run:

```powershell
flutter test test/features/player/presentation/listening_console_test.dart
```

Expected: FAIL because the formatter and widget do not exist.

- [ ] **Step 4: Implement the formatter**

The formatter must:

- use the primary audio stream;
- uppercase codec;
- append profile when it is non-empty and not already part of the codec label;
- use rounded kbps;
- display whole kHz or one decimal place;
- map 1 channel to `单声道`, 2 to `双声道`, and other values to `$n 声道`;
- append `无损` only for `flac`, `alac`, `wavpack`, and `pcm_*`.

- [ ] **Step 5: Implement the responsive console**

Use one `LayoutBuilder`:

- `maxWidth >= 1050`: three-column stage;
- `760 <= maxWidth < 1050`: artwork + information, metadata chips below;
- `< 760`: compact artwork/title/actions; hide path, next card, and side panel.

Use stable keys:

- `listening-console`;
- `listening-console-side-panel`;
- `listening-console-empty-state`;
- `listening-console-current-media`.

Do not subscribe to playback position. Only the artwork's existing playing
animation may animate continuously.

- [ ] **Step 6: Run the tests and verify GREEN**

Run:

```powershell
dart format lib/features/player/presentation/listening_console.dart test/features/player/presentation/listening_console_test.dart
flutter test test/features/player/presentation/listening_console_test.dart
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```powershell
git add lib/features/player/presentation/listening_console.dart test/features/player/presentation/listening_console_test.dart
git commit -m "feat: add responsive listening console"
```

---

### Task 6: Remove Lyrics And Integrate The Console

**Files:**
- Modify: `lib/features/player/application/player_state.dart`
- Modify: `lib/features/player/application/playback_queue_controller.dart`
- Modify: `lib/features/player/presentation/player_screen.dart`
- Modify: `test/features/player/application/playback_queue_controller_test.dart`
- Modify: `test/features/player/presentation/player_responsive_layout_test.dart`
- Modify: `test/features/player/presentation/adaptive_sidebar_test.dart`

**Interfaces:**
- Consumes: `HeniListeningConsole`
- Consumes: `LocalFileActions`
- Consumes: existing `_showPlaybackQueue`

- [ ] **Step 1: Add a failing playback-controller regression test**

Play a media item with the fake inspector and assert playback state changes
without requiring any lyric provider override or lyric file access. This test
must compile only after lyrics references are removed from the controller.

- [ ] **Step 2: Verify RED before removing production lyrics code**

Run:

```powershell
flutter test test/features/player/application/playback_queue_controller_test.dart
```

Expected: the new test fails to compile while it still references the desired
lyrics-free setup.

- [ ] **Step 3: Remove lyrics state and work**

Delete from `player_state.dart`:

- `currentLyricsProvider`;
- `LyricLine`;
- `LyricHeader`;
- `LyricsDocument`;
- `CurrentLyrics`;
- now-unused `dart:io` and `path` imports.

Delete `currentLyricsProvider.notifier.clear()` and `.loadFor()` calls from the
queue controller.

- [ ] **Step 4: Integrate `HeniListeningConsole`**

Remove `lyrics` parameters from `PlayerScreen`, `_ContentArea`, and
`_SceneryContent`. Delete `_LyricsPanel`, `_AudioHero`,
`_ListeningLoungeCard`, `_ListeningScopeLabel`, and `_ListeningTextColumn` after
their replacement is wired.

For audio:

```dart
HeniListeningConsole(
  palette: palette,
  currentMedia: currentMedia,
  nextMedia: queue.currentIndex >= 0 &&
          queue.currentIndex + 1 < queue.playbackQueue.items.length
      ? queue.playbackQueue.items[queue.currentIndex + 1]
      : null,
  mediaProbe: mediaProbe,
  isPlaying: isPlaying,
  libraryItemCount: queue.library.items.length,
  libraryDirectoryCount: queue.libraryDirectories.length,
  statusMessage: queue.statusMessage,
  onLocateCurrent: onShowPlaybackQueue,
  onOpenFileLocation: onOpenFileLocation,
  onPickMedia: onPickMedia,
  onPickFolder: onPickFolder,
)
```

Keep `_VideoStage` for video without any lyrics panel.

- [ ] **Step 5: Wire file reveal status**

Create one `LocalFileActions` instance in `PlayerScreen`. Map results to:

- success: `已打开文件位置`;
- missing: `文件不存在，未修改曲库`;
- unsupported: `当前平台不支持打开文件位置`;
- failed: `无法打开文件位置`.

Report through `PlaybackQueueController.reportStatus`.

- [ ] **Step 6: Apply deep-tinted matte shell colors**

Update `_shellGlassFill`, `_shellGlassBorder`, the root overlay, sidebar bands,
and bottom bar so `surface`, `surfaceAlt`, and `seed` use the approved blending
limits. Keep `accent` limited to progress, active state, primary action, and
small status badges.

- [ ] **Step 7: Run focused and full tests**

Run:

```powershell
dart format lib test
flutter test test/features/player/presentation/listening_console_test.dart test/features/player/presentation/global_scenery_backdrop_test.dart test/features/player/presentation/adaptive_sidebar_test.dart test/features/player/presentation/player_progress_test.dart test/features/player/application/playback_queue_controller_test.dart
flutter test
```

Expected: all focused tests and the full suite pass.

- [ ] **Step 8: Verify lyrics are gone**

Run:

```powershell
rg -n "currentLyricsProvider|LyricsDocument|LyricLine|_LyricsPanel|loadFor\\(" lib test
```

Expected: no matches.

- [ ] **Step 9: Commit**

```powershell
git add lib/features/player/application/player_state.dart lib/features/player/application/playback_queue_controller.dart lib/features/player/presentation/player_screen.dart test
git commit -m "feat: integrate studio listening console"
```

---

### Task 7: Final Verification And Windows QA

**Files:**
- Modify only files required by verification failures

**Interfaces:**
- Produces: verified Windows Debug build and regression evidence

- [ ] **Step 1: Run static analysis**

Run:

```powershell
flutter analyze
```

Expected: no issues.

- [ ] **Step 2: Run the complete test suite**

Run:

```powershell
flutter test
```

Expected: all tests pass with zero failures.

- [ ] **Step 3: Build Windows Debug**

Run:

```powershell
flutter build windows --debug
```

Expected: exit code 0 and
`build/windows/x64/runner/Debug/heni.exe` exists.

- [ ] **Step 4: Launch the Debug build without touching Release**

Start only the Debug executable and manually verify:

- no white native caption;
- drag and double-click maximize;
- minimize, maximize/restore, close, and `Alt+F4`;
- all resize edges/corners;
- minimum `900 × 620`;
- search/palette/settings remain independently clickable;
- black, tide, plum, citrus, coral, and ruby palettes are readable;
- scenery covers the complete shell;
- audio console wide/compact/minimum layouts;
- MP4/M4A, MP3, and FLAC property labels;
- queue locate opens centered on current media;
- no lyrics activity or UI.

- [ ] **Step 5: Inspect the final diff and requirements**

Run:

```powershell
git status --short
git diff --check
git diff --stat
```

Re-read
`docs/superpowers/specs/2026-07-16-studio-matte-listening-console-design.md`
and confirm every verification item is either automated or manually checked.

- [ ] **Step 6: Commit any verification fixes**

```powershell
git add windows/runner lib/services/window lib/services/files lib/features/player/application lib/features/player/presentation test
git commit -m "fix: polish studio player integration"
```

Skip this commit when `git status --short` shows no verification fixes.
