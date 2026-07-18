import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heni/design/app_theme.dart';
import 'package:heni/domain/playback/playback_mode.dart';
import 'package:heni/features/player/presentation/playback_mode_controls.dart';

void main() {
  testWidgets('shuffle and repeat expose separate active states and actions', (
    tester,
  ) async {
    var shuffleTaps = 0;
    var repeatTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeniPlaybackModeControls(
            palette: HeniPalette.nocturne,
            shuffle: true,
            repeatMode: HeniRepeatMode.one,
            enabled: true,
            onToggleShuffle: () => shuffleTaps++,
            onCycleRepeat: () => repeatTaps++,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.repeat_one_rounded), findsOneWidget);
    expect(find.byTooltip('随机播放：已开启'), findsOneWidget);
    expect(find.byTooltip('循环：单曲'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('shuffle-mode-state-dot')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('repeat-mode-state-dot')), findsOneWidget);

    await tester.tap(find.byTooltip('随机播放：已开启'));
    await tester.tap(find.byTooltip('循环：单曲'));
    expect(shuffleTaps, 1);
    expect(repeatTaps, 1);
  });

  testWidgets('disabled playback modes ignore interaction', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeniPlaybackModeControls(
            palette: HeniPalette.nocturne,
            shuffle: false,
            repeatMode: HeniRepeatMode.none,
            enabled: false,
            onToggleShuffle: () => taps++,
            onCycleRepeat: () => taps++,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('随机播放：已关闭'));
    await tester.tap(find.byTooltip('循环：关闭'));
    expect(taps, 0);
  });
}
