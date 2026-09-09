import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heni/design/app_theme.dart';
import 'package:heni/design/heni_shell_theme.dart';
import 'package:heni/features/player/presentation/player_shell_frame.dart';

void main() {
  testWidgets('outer shell paints edge-to-edge without Flutter clipping', (
    tester,
  ) async {
    final shell = HeniShellTheme.fromPalette(HeniPalette.nocturne);
    const contentKey = ValueKey('shell-content');

    await tester.pumpWidget(
      MaterialApp(
        home: HeniPanoramicShellFrame(
          shellTheme: shell,
          child: const SizedBox.expand(key: contentKey),
        ),
      ),
    );

    final frame = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('heni-panoramic-frame')),
    );
    expect(frame.color, shell.canvas);
    expect(find.byType(ClipRRect), findsNothing);
    expect(
      tester.getRect(find.byKey(contentKey)),
      tester.getRect(find.byKey(const ValueKey('heni-panoramic-frame'))),
    );
  });
}
