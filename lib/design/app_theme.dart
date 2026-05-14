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
  scenery('美景'),
  library('歌曲');

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

  static const ink = HeniPalette(
    name: '黑色',
    seed: Color(0xFF050505),
    surface: Color(0xFF050506),
    surfaceAlt: Color(0xFF111214),
    accent: Color(0xFFE8E8E8),
    glow: Color(0xFF050505),
  );

  static const snow = HeniPalette(
    name: '白色',
    seed: Color(0xFFF4F1EA),
    surface: Color(0xFF151515),
    surfaceAlt: Color(0xFF292823),
    accent: Color(0xFFFFFFFF),
    glow: Color(0xFFF4F1EA),
  );

  static const nocturne = HeniPalette(
    name: '深夜',
    seed: Color(0xFF5EC8A7),
    surface: Color(0xFF101316),
    surfaceAlt: Color(0xFF182026),
    accent: Color(0xFFF0C66B),
    glow: Color(0xFF5EC8A7),
  );

  static const ember = HeniPalette(
    name: '余烬',
    seed: Color(0xFFE86F52),
    surface: Color(0xFF16120F),
    surfaceAlt: Color(0xFF27201B),
    accent: Color(0xFF7FD1B9),
    glow: Color(0xFFE86F52),
  );

  static const tide = HeniPalette(
    name: '潮汐',
    seed: Color(0xFF4C8FD9),
    surface: Color(0xFF0F1519),
    surfaceAlt: Color(0xFF18242B),
    accent: Color(0xFFE4B363),
    glow: Color(0xFF4C8FD9),
  );

  static const plum = HeniPalette(
    name: '紫藤',
    seed: Color(0xFFA678D6),
    surface: Color(0xFF151219),
    surfaceAlt: Color(0xFF211B28),
    accent: Color(0xFF8ED6B1),
    glow: Color(0xFFA678D6),
  );

  static const forest = HeniPalette(
    name: '森林',
    seed: Color(0xFF74A66A),
    surface: Color(0xFF111510),
    surfaceAlt: Color(0xFF1B241A),
    accent: Color(0xFFE4C06A),
    glow: Color(0xFF74A66A),
  );

  static const graphite = HeniPalette(
    name: '石墨',
    seed: Color(0xFF9BA4B5),
    surface: Color(0xFF111216),
    surfaceAlt: Color(0xFF20232A),
    accent: Color(0xFFFFC857),
    glow: Color(0xFF9BA4B5),
  );

  static const coral = HeniPalette(
    name: '珊瑚',
    seed: Color(0xFFFF7A73),
    surface: Color(0xFF181113),
    surfaceAlt: Color(0xFF2B1C20),
    accent: Color(0xFF71E0CF),
    glow: Color(0xFFFF7A73),
  );

  static const lagoon = HeniPalette(
    name: '泻湖',
    seed: Color(0xFF2EC4B6),
    surface: Color(0xFF0D1517),
    surfaceAlt: Color(0xFF142629),
    accent: Color(0xFFFFD166),
    glow: Color(0xFF2EC4B6),
  );

  static const ruby = HeniPalette(
    name: '红宝',
    seed: Color(0xFFE63965),
    surface: Color(0xFF171014),
    surfaceAlt: Color(0xFF291822),
    accent: Color(0xFF8CE3FF),
    glow: Color(0xFFE63965),
  );

  static const aurora = HeniPalette(
    name: '极光',
    seed: Color(0xFF57E389),
    surface: Color(0xFF0D1412),
    surfaceAlt: Color(0xFF16241E),
    accent: Color(0xFFFF7AD9),
    glow: Color(0xFF57E389),
  );

  static const cobalt = HeniPalette(
    name: '钴蓝',
    seed: Color(0xFF4F7BFF),
    surface: Color(0xFF0E121A),
    surfaceAlt: Color(0xFF171E30),
    accent: Color(0xFFFFB86B),
    glow: Color(0xFF4F7BFF),
  );

  static const citrus = HeniPalette(
    name: '柑橘',
    seed: Color(0xFFFFB000),
    surface: Color(0xFF15130C),
    surfaceAlt: Color(0xFF252113),
    accent: Color(0xFF5CD6C8),
    glow: Color(0xFFFFB000),
  );

  static const all = [
    ink,
    snow,
    nocturne,
    ember,
    tide,
    plum,
    forest,
    graphite,
    coral,
    lagoon,
    ruby,
    aurora,
    cobalt,
    citrus,
  ];
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
      fontFamily: 'Microsoft YaHei',
      fontFamilyFallback: const ['Segoe UI', 'Arial', 'sans-serif'],
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
