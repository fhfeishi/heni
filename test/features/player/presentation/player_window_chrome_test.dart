import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heni/design/app_theme.dart';
import 'package:heni/design/heni_shell_theme.dart';
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
          if (call.method == 'isMaximized') {
            return false;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('window controls invoke native actions', (tester) async {
    final shellTheme = HeniShellTheme.fromPalette(HeniPalette.plum);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: HeniWindowControls(shellTheme: shellTheme)),
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

  testWidgets('brand is lowercase heni without uppercase badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HeniBrandWordmark())),
    );

    expect(find.text('heni'), findsOneWidget);
    expect(find.text('H'), findsNothing);
    expect(find.text('HENI'), findsNothing);
  });

  testWidgets('double-clicking drag region toggles maximize', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: HeniWindowDragRegion(child: SizedBox(width: 100, height: 40)),
          ),
        ),
      ),
    );
    await tester.pump();
    methods.clear();

    await tester.tap(find.byType(HeniWindowDragRegion));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.byType(HeniWindowDragRegion));
    await tester.pump();

    expect(methods, contains('toggleMaximize'));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('wide top chrome exposes drag spacer without stealing search', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Material(
            child: Center(
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
      ),
    );
    await tester.pump();
    methods.clear();

    expect(
      find.byKey(const ValueKey('heni-top-chrome-drag-spacer')),
      findsOneWidget,
    );
    final searchRect = tester.getRect(
      find.byKey(const ValueKey('chrome-search')),
    );
    final spacerRect = tester.getRect(
      find.byKey(const ValueKey('heni-top-chrome-drag-spacer')),
    );
    expect(searchRect.width, 640);
    expect(spacerRect.width, 148);
    expect(spacerRect.left - searchRect.right, 12);
    await tester.tap(find.byKey(const ValueKey('chrome-search')));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    expect(methods, isNot(contains('beginDrag')));

    await tester.drag(
      find.byKey(const ValueKey('heni-top-chrome-drag-spacer')),
      const Offset(40, 0),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(methods, contains('beginDrag'));
  });

  testWidgets('breakpoint top chrome reserves minimum drag spacer geometry', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Center(
            child: SizedBox(
              width: 720,
              height: 48,
              child: HeniTopChromeCenter(
                search: SizedBox(key: ValueKey('chrome-search')),
              ),
            ),
          ),
        ),
      ),
    );

    final searchRect = tester.getRect(
      find.byKey(const ValueKey('chrome-search')),
    );
    final spacerRect = tester.getRect(
      find.byKey(const ValueKey('heni-top-chrome-drag-spacer')),
    );
    expect(searchRect.width, 624);
    expect(spacerRect.width, 84);
    expect(spacerRect.left - searchRect.right, 12);
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
    expect(
      tester.getSize(find.byKey(const ValueKey('chrome-search'))).width,
      560,
    );
  });
}
