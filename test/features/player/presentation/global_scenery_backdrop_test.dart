import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heni/design/app_theme.dart';
import 'package:heni/features/player/presentation/global_scenery_backdrop.dart';

void main() {
  test('library treatment is darker and blurrier than playback', () {
    const playback = HeniBackdropTreatment.playback;
    const library = HeniBackdropTreatment.library;

    expect(library.overlayOpacity, greaterThan(playback.overlayOpacity));
    expect(library.blurSigma, greaterThan(playback.blurSigma));
    expect(library.seedWashOpacity, greaterThan(playback.seedWashOpacity));
    expect(library.saturation, lessThan(playback.saturation));
  });

  testWidgets('uses palette fallback when no scenery path exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlobalSceneryBackdrop(
          imagePaths: [],
          palette: HeniPalette.plum,
          mode: HeniBackdropMode.playback,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('global-scenery-fallback')),
      findsOneWidget,
    );
  });
}
