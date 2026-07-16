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
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: HeniWindowControls(palette: HeniPalette.plum)),
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
  });
}
