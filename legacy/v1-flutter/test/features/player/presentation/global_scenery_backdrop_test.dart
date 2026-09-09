import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heni/design/app_theme.dart';
import 'package:heni/design/heni_shell_theme.dart';
import 'package:heni/features/player/presentation/global_scenery_backdrop.dart';

void main() {
  test('library treatment is darker and blurrier than playback', () {
    const playback = HeniBackdropTreatment.playback;
    const library = HeniBackdropTreatment.library;

    expect(library.overlayOpacity, greaterThan(playback.overlayOpacity));
    expect(library.blurSigma, greaterThan(playback.blurSigma));
    expect(library.seedWashOpacity, greaterThan(playback.seedWashOpacity));
    expect(library.saturation, lessThan(playback.saturation));
    expect(playback.blurSigma, inInclusiveRange(8, 12));
    expect(playback.overlayOpacity, inInclusiveRange(0.26, 0.34));
    expect(playback.saturation, inInclusiveRange(0.78, 0.88));
    expect(library.blurSigma, inInclusiveRange(14, 18));
    expect(library.overlayOpacity, inInclusiveRange(0.40, 0.50));
    expect(library.saturation, inInclusiveRange(0.66, 0.76));
  });

  test('scenery transitions respect reduced motion', () {
    expect(
      heniBackdropTransitionDuration(disableAnimations: false),
      const Duration(milliseconds: 820),
    );
    expect(
      heniBackdropTransitionDuration(disableAnimations: true),
      Duration.zero,
    );
  });

  test('scenery image opacity is normalized to a safe range', () {
    expect(heniBackdropImageOpacity(0.42), 0.42);
    expect(heniBackdropImageOpacity(-1), 0);
    expect(heniBackdropImageOpacity(4), 1);
  });

  testWidgets('uses palette fallback when no scenery path exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlobalSceneryBackdrop(
          imagePaths: [],
          palette: HeniPalette.plum,
          shellTheme: HeniShellTheme.fromPalette(HeniPalette.plum),
          mode: HeniBackdropMode.playback,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('global-scenery-fallback')),
      findsOneWidget,
    );
  });

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

    expect(
      find.byKey(const ValueKey('global-scenery-fallback')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
