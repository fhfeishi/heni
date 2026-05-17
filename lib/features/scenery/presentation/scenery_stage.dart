import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../design/app_theme.dart';

class SceneryStage extends StatefulWidget {
  const SceneryStage({
    required this.imagePaths,
    required this.palette,
    this.isPlaying = false,
    super.key,
  });

  final List<String> imagePaths;
  final HeniPalette palette;
  final bool isPlaying;

  @override
  State<SceneryStage> createState() => _SceneryStageState();
}

class _SceneryStageState extends State<SceneryStage> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant SceneryStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePaths.length != widget.imagePaths.length ||
        oldWidget.imagePaths.join('|') != widget.imagePaths.join('|')) {
      _index = 0;
      _restartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imagePaths.isEmpty) {
      return _FallbackScenery(palette: widget.palette);
    }

    final path = widget.imagePaths[_index % widget.imagePaths.length];
    final file = File(path);

    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Transform.scale(
            scale: 1.08,
            child: Image.file(file, fit: BoxFit.cover),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 1600),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          transitionBuilder: (child, animation) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 1.02, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              fit: StackFit.expand,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          child: TweenAnimationBuilder<double>(
            key: ValueKey(path),
            duration: const Duration(seconds: 11),
            tween: Tween(begin: 1.02, end: 1.075),
            curve: Curves.easeInOutCubic,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Image.file(file, fit: BoxFit.cover),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.24),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.52),
              ],
              stops: const [0.0, 0.46, 1.0],
            ),
          ),
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 600),
          opacity: widget.isPlaying ? 1 : 0.55,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0.72),
                radius: 0.92,
                colors: [
                  widget.palette.seed.withValues(alpha: 0.12),
                  widget.palette.seed.withValues(alpha: 0.04),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.38, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.imagePaths.length <= 1) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 11), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _index = (_index + 1) % widget.imagePaths.length;
      });
    });
  }
}

class _FallbackScenery extends StatelessWidget {
  const _FallbackScenery({required this.palette});

  final HeniPalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.surface,
            palette.surfaceAlt,
            Color.alphaBlend(
              palette.glow.withValues(alpha: 0.28),
              palette.surface,
            ),
          ],
        ),
      ),
      child: CustomPaint(painter: _FallbackSceneryPainter(palette)),
    );
  }
}

class _FallbackSceneryPainter extends CustomPainter {
  const _FallbackSceneryPainter(this.palette);

  final HeniPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = palette.accent.withValues(alpha: 0.2);

    for (var index = 0; index < 9; index += 1) {
      final top = size.height * (0.16 + index * 0.075);
      final path =
          Path()
            ..moveTo(0, top)
            ..cubicTo(
              size.width * 0.28,
              top - 34,
              size.width * 0.62,
              top + 40,
              size.width,
              top - 8,
            );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FallbackSceneryPainter oldDelegate) {
    return oldDelegate.palette != palette;
  }
}
