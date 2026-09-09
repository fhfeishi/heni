import 'package:flutter/material.dart';

import 'app_theme.dart';

enum HeniShellSurfaceRole { chrome, rail, content, dock }

@immutable
class HeniShellTheme {
  const HeniShellTheme({
    required this.canvas,
    required this.chrome,
    required this.rail,
    required this.content,
    required this.dock,
    required this.border,
    required this.hover,
    required this.pressed,
    required this.selected,
    required this.primaryText,
    required this.secondaryText,
  });

  factory HeniShellTheme.fromPalette(HeniPalette palette) {
    Color tinted(Color base, double seedMix, double alpha) =>
        Color.lerp(base, palette.seed, seedMix)!.withValues(alpha: alpha);

    return HeniShellTheme(
      canvas: Color.lerp(palette.surface, palette.seed, 0.08)!,
      chrome: tinted(palette.surfaceAlt, 0.14, 0.56),
      rail: tinted(palette.surface, 0.16, 0.42),
      content: tinted(palette.surface, 0.10, 0.50),
      dock: tinted(palette.surfaceAlt, 0.12, 0.60),
      border: Color.lerp(
        palette.seed,
        palette.accent,
        0.24,
      )!.withValues(alpha: 0.38),
      hover: palette.seed.withValues(alpha: 0.12),
      pressed: palette.seed.withValues(alpha: 0.17),
      selected: Color.lerp(
        palette.seed,
        palette.accent,
        0.22,
      )!.withValues(alpha: 0.20),
      primaryText: Colors.white.withValues(alpha: 0.94),
      secondaryText: Colors.white.withValues(alpha: 0.62),
    );
  }

  final Color canvas;
  final Color chrome;
  final Color rail;
  final Color content;
  final Color dock;
  final Color border;
  final Color hover;
  final Color pressed;
  final Color selected;
  final Color primaryText;
  final Color secondaryText;

  Color surfaceFor(HeniShellSurfaceRole role) => switch (role) {
    HeniShellSurfaceRole.chrome => chrome,
    HeniShellSurfaceRole.rail => rail,
    HeniShellSurfaceRole.content => content,
    HeniShellSurfaceRole.dock => dock,
  };
}
