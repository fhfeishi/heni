import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../design/heni_shell_theme.dart';

class HeniPanoramicShellFrame extends StatelessWidget {
  const HeniPanoramicShellFrame({
    required this.shellTheme,
    required this.isMaximized,
    required this.child,
    super.key,
  });

  final HeniShellTheme shellTheme;
  final bool isMaximized;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = isMaximized ? 0.0 : 14.0;
    return AnimatedContainer(
      key: const ValueKey('heni-panoramic-frame'),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: isMaximized ? EdgeInsets.zero : const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: shellTheme.border.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius == 0 ? 0 : radius - 1),
        child: child,
      ),
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
