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
    expect(
      tester
          .widget<AnimatedContainer>(
            find.byKey(const ValueKey('heni-panoramic-frame')),
          )
          .padding,
      const EdgeInsets.all(1),
    );

    await pump(true);
    expect(
      tester
          .widget<AnimatedContainer>(
            find.byKey(const ValueKey('heni-panoramic-frame')),
          )
          .padding,
      EdgeInsets.zero,
    );
  });
}
