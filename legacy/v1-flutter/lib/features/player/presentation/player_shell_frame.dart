import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../design/heni_shell_theme.dart';

class HeniPanoramicShellFrame extends StatelessWidget {
  const HeniPanoramicShellFrame({
    required this.shellTheme,
    required this.child,
    super.key,
  });

  final HeniShellTheme shellTheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The native desktop window owns the outer silhouette. Keeping this layer
    // opaque and edge-to-edge prevents the transparent pixels outside a
    // Flutter ClipRRect from exposing the Win32 host at the four corners.
    return ColoredBox(
      key: const ValueKey('heni-panoramic-frame'),
      color: shellTheme.canvas,
      child: child,
    );
  }
}

class HeniShellSurface extends StatelessWidget {
  const HeniShellSurface({
    required this.shellTheme,
    required this.role,
    required this.child,
    this.radius = 12,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final HeniShellTheme shellTheme;
  final HeniShellSurfaceRole role;
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: shellTheme.surfaceFor(role),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: shellTheme.border.withValues(alpha: 0.48),
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
