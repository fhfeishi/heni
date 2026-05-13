import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final activePaletteProvider = NotifierProvider<ActivePalette, HeniPalette>(
  ActivePalette.new,
);

final activeUiStyleProvider = NotifierProvider<ActiveUiStyle, HeniUiStyle>(
  ActiveUiStyle.new,
);

class ActivePalette extends Notifier<HeniPalette> {
  @override
  HeniPalette build() => HeniPalette.nocturne;

  void select(HeniPalette palette) {
    state = palette;
  }
}

class ActiveUiStyle extends Notifier<HeniUiStyle> {
  @override
  HeniUiStyle build() => HeniUiStyle.scenery;

  void select(HeniUiStyle style) {
    state = style;
  }
}

enum HeniUiStyle {
  scenery('Scenery'),
  cinema('Cinema'),
  library('Library');

  const HeniUiStyle(this.label);

  final String label;
}

class HeniPalette {
  const HeniPalette({
    required this.name,
    required this.seed,
    required this.surface,
    required this.surfaceAlt,
    required this.accent,
    required this.glow,
  });

  final String name;
  final Color seed;
  final Color surface;
  final Color surfaceAlt;
  final Color accent;
  final Color glow;

  static const nocturne = HeniPalette(
    name: 'Nocturne',
    seed: Color(0xFF5EC8A7),
    surface: Color(0xFF101316),
    surfaceAlt: Color(0xFF182026),
    accent: Color(0xFFF0C66B),
    glow: Color(0xFF5EC8A7),
  );

  static const ember = HeniPalette(
    name: 'Ember',
    seed: Color(0xFFE86F52),
    surface: Color(0xFF16120F),
    surfaceAlt: Color(0xFF27201B),
    accent: Color(0xFF7FD1B9),
    glow: Color(0xFFE86F52),
  );

  static const tide = HeniPalette(
    name: 'Tide',
    seed: Color(0xFF4C8FD9),
    surface: Color(0xFF0F1519),
    surfaceAlt: Color(0xFF18242B),
    accent: Color(0xFFE4B363),
    glow: Color(0xFF4C8FD9),
  );

  static const plum = HeniPalette(
    name: 'Plum',
    seed: Color(0xFFA678D6),
    surface: Color(0xFF151219),
    surfaceAlt: Color(0xFF211B28),
    accent: Color(0xFF8ED6B1),
    glow: Color(0xFFA678D6),
  );

  static const forest = HeniPalette(
    name: 'Forest',
    seed: Color(0xFF74A66A),
    surface: Color(0xFF111510),
    surfaceAlt: Color(0xFF1B241A),
    accent: Color(0xFFE4C06A),
    glow: Color(0xFF74A66A),
  );

  static const all = [nocturne, ember, tide, plum, forest];
}

class HeniTheme {
  const HeniTheme._();

  static ThemeData dark(HeniPalette palette) {
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.seed,
      brightness: Brightness.dark,
    ).copyWith(surface: palette.surface);

    return _base(scheme, palette);
  }

  static ThemeData light(HeniPalette palette) {
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.seed,
      brightness: Brightness.light,
    );

    return _base(scheme, palette);
  }

  static ThemeData _base(ColorScheme scheme, HeniPalette palette) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: palette.surface,
      sliderTheme: SliderThemeData(
        activeTrackColor: palette.accent,
        thumbColor: palette.accent,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          fixedSize: const Size.square(46),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: Colors.black,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
