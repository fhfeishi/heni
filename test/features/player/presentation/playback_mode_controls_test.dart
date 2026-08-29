import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heni/design/app_theme.dart';
import 'package:heni/domain/playback/playback_mode.dart';
import 'package:heni/features/player/presentation/playback_mode_controls.dart';

void main() {
  Widget subject({
    HeniPlaybackMode mode = HeniPlaybackMode.listLoop,
    bool enabled = true,
    VoidCallback? onCycle,
    ValueChanged<HeniPlaybackMode>? onSelected,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: HeniPlaybackModeControls(
          palette: HeniPalette.nocturne,
          mode: mode,
          enabled: enabled,
          onCycleMode: onCycle ?? () {},
          onModeSelected: onSelected ?? (_) {},
        ),
      ),
    );
  }

  testWidgets('one button presents each player-facing mode', (tester) async {
    for (final (mode, icon) in [
      (HeniPlaybackMode.listLoop, Icons.repeat_rounded),
      (HeniPlaybackMode.singleLoop, Icons.repeat_one_rounded),
      (HeniPlaybackMode.random, Icons.shuffle_rounded),
    ]) {
      await tester.pumpWidget(subject(mode: mode));

      expect(
        find.byKey(const ValueKey('playback-mode-button')),
        findsOneWidget,
      );
      expect(find.byIcon(icon), findsOneWidget);
      expect(find.byTooltip('播放模式：${mode.label}（单击切换，右键选择）'), findsOneWidget);
    }
  });

  testWidgets('primary click cycles and secondary click selects directly', (
    tester,
  ) async {
    var cycles = 0;
    HeniPlaybackMode? selected;
    await tester.pumpWidget(
      subject(
        onCycle: () => cycles += 1,
        onSelected: (mode) => selected = mode,
      ),
    );

    final button = find.byKey(const ValueKey('playback-mode-button'));
    await tester.tap(button);
    expect(cycles, 1);

    await tester.tap(button, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('随机播放'), findsOneWidget);

    await tester.tap(find.text('随机播放'));
    await tester.pumpAndSettle();
    expect(selected, HeniPlaybackMode.random);
  });

  testWidgets('disabled playback mode ignores interaction', (tester) async {
    var cycles = 0;
    await tester.pumpWidget(
      subject(enabled: false, onCycle: () => cycles += 1),
    );

    expect(find.byTooltip('播放模式不可用'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('playback-mode-button')));
    expect(cycles, 0);
  });
}
