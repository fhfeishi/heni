import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heni/design/app_theme.dart';

void main() {
  group('palette contrast', () {
    test('all palette accent surfaces keep readable primary foregrounds', () {
      for (final palette in HeniPalette.all) {
        final darkTheme = HeniTheme.dark(palette);
        final lightTheme = HeniTheme.light(palette);
        final expectedForeground = heniReadableForegroundOn(palette.accent);

        expect(
          darkTheme.colorScheme.primary,
          palette.accent,
          reason: 'dark primary should follow accent for ${palette.name}',
        );
        expect(
          darkTheme.colorScheme.onPrimary,
          expectedForeground,
          reason: 'dark onPrimary should follow helper for ${palette.name}',
        );
        expect(
          lightTheme.colorScheme.primary,
          palette.accent,
          reason: 'light primary should follow accent for ${palette.name}',
        );
        expect(
          lightTheme.colorScheme.onPrimary,
          expectedForeground,
          reason: 'light onPrimary should follow helper for ${palette.name}',
        );
        expect(
          _contrastRatio(palette.accent, expectedForeground),
          greaterThanOrEqualTo(4.5),
          reason:
              'accent foreground for ${palette.name} should remain readable',
        );
      }
    });

    test('all palette accent text stays visible on glass surfaces', () {
      for (final palette in HeniPalette.all) {
        final accentText = heniAccentOnGlass(palette.accent);
        final contrastOnSurface = _contrastRatio(accentText, palette.surface);
        final contrastOnSurfaceAlt = _contrastRatio(
          accentText,
          palette.surfaceAlt,
        );

        expect(
          contrastOnSurface,
          greaterThanOrEqualTo(3.2),
          reason: 'accent text on surface for ${palette.name} is too weak',
        );
        expect(
          contrastOnSurfaceAlt,
          greaterThanOrEqualTo(2.8),
          reason: 'accent text on surfaceAlt for ${palette.name} is too weak',
        );
      }
    });

    test(
      'white palette uses a visible accent instead of pure white controls',
      () {
        final palette = HeniPalette.snow;
        final theme = HeniTheme.dark(palette);

        expect(
          _contrastRatio(theme.colorScheme.primary, palette.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(
            theme.colorScheme.onPrimary,
            theme.colorScheme.primary,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(theme.colorScheme.primary, isNot(equals(Colors.white)));
      },
    );
  });
}

double _contrastRatio(Color foreground, Color background) {
  final lighter = _relativeLuminance(foreground) + 0.05;
  final darker = _relativeLuminance(background) + 0.05;
  return lighter > darker ? lighter / darker : darker / lighter;
}

double _relativeLuminance(Color color) {
  double channel(double value) {
    final normalized = value / 255.0;
    if (normalized <= 0.03928) {
      return normalized / 12.92;
    }
    return math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel((color.r * 255.0).roundToDouble()) +
      0.7152 * channel((color.g * 255.0).roundToDouble()) +
      0.0722 * channel((color.b * 255.0).roundToDouble());
}
