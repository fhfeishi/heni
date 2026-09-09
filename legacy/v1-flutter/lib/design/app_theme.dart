import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Color heniReadableForegroundOn(Color color) {
  final blackContrast = _contrastRatio(Colors.black, color);
  final whiteContrast = _contrastRatio(Colors.white, color);
  return whiteContrast >= blackContrast ? Colors.white : Colors.black;
}

Color heniAccentOnGlass(Color color, {double alpha = 1}) {
  final luminance = color.computeLuminance();
  final lift =
      luminance < 0.58
          ? ((0.58 - luminance) / 0.58).clamp(0.0, 1.0) * 0.78
          : 0.0;
  return Color.lerp(color, Colors.white, lift)!.withValues(alpha: alpha);
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
    return pow((normalized + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel((color.r * 255.0).roundToDouble()) +
      0.7152 * channel((color.g * 255.0).roundToDouble()) +
      0.0722 * channel((color.b * 255.0).roundToDouble());
}

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

  void restoreByName(String name) {
    state = HeniPalette.all.firstWhere(
      (palette) => palette.name == name,
      orElse: () => HeniPalette.nocturne,
    );
  }
}

class ActiveUiStyle extends Notifier<HeniUiStyle> {
  @override
  HeniUiStyle build() => HeniUiStyle.scenery;

  void select(HeniUiStyle style) {
    state = style;
  }

  void restoreByName(String name) {
    state = HeniUiStyle.values.firstWhere(
      (style) => style.name == name,
      orElse: () => HeniUiStyle.scenery,
    );
  }
}

enum HeniUiStyle {
  scenery('播放中'),
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
    accent: Color(0xFFB7C79C),
    glow: Color(0xFFF4F1EA),
  );

  static const nocturne = HeniPalette(
    name: '深夜',
    seed: Color(0xFF4F8A78),
    surface: Color(0xFF0E1214),
    surfaceAlt: Color(0xFF161E22),
    accent: Color(0xFFD8BC7A),
    glow: Color(0xFF4F8A78),
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
    seed: Color(0xFF678E63),
    surface: Color(0xFF101410),
    surfaceAlt: Color(0xFF182019),
    accent: Color(0xFFD8B874),
    glow: Color(0xFF678E63),
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
    ).copyWith(
      surface: palette.surface,
      primary: palette.accent,
      onPrimary: heniReadableForegroundOn(palette.accent),
    );

    return _base(scheme, palette);
  }

  static ThemeData light(HeniPalette palette) {
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.seed,
      brightness: Brightness.light,
    ).copyWith(
      primary: palette.accent,
      onPrimary: heniReadableForegroundOn(palette.accent),
    );

    return _base(scheme, palette);
  }

  static ThemeData _base(ColorScheme scheme, HeniPalette palette) {
    final textTheme = Typography.whiteMountainView.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
      fontFamily: 'Microsoft YaHei',
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Microsoft YaHei',
      fontFamilyFallback: const ['Segoe UI', 'Arial', 'sans-serif'],
      scaffoldBackgroundColor: palette.surface,
      textTheme: textTheme.copyWith(
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          height: 1.1,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontSize: 23,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.15,
          height: 1.14,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.05,
        ),
        titleSmall: textTheme.titleSmall?.copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.06,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.08,
          height: 1.42,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          fontSize: 11.6,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.08,
          height: 1.34,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontSize: 11.8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.12,
        ),
        labelMedium: textTheme.labelMedium?.copyWith(
          fontSize: 10.8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.16,
        ),
      ),
      dividerColor: Colors.white.withValues(alpha: 0.08),
      sliderTheme: SliderThemeData(
        activeTrackColor: palette.accent,
        thumbColor: palette.accent,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          fixedSize: const Size.square(42),
          padding: EdgeInsets.zero,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(44, 38),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.08,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(44, 38),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.08,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        hintStyle: textTheme.bodySmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.42),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.seed.withValues(alpha: 0.42)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return palette.seed.withValues(alpha: 0.18);
            }
            return Colors.white.withValues(alpha: 0.03);
          }),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Color.alphaBlend(
          palette.surfaceAlt.withValues(alpha: 0.92),
          palette.surface,
        ),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.76),
          height: 1.45,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Color.alphaBlend(
          palette.surfaceAlt.withValues(alpha: 0.94),
          palette.surface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        menuPadding: const EdgeInsets.symmetric(vertical: 8),
        textStyle: textTheme.bodyMedium,
      ),
    );
  }
}
