import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../design/app_theme.dart';
import '../../../design/heni_shell_theme.dart';

enum HeniBackdropMode { playback, library }

@immutable
class HeniBackdropTreatment {
  const HeniBackdropTreatment({
    required this.blurSigma,
    required this.overlayOpacity,
    required this.saturation,
    required this.seedWashOpacity,
  });

  factory HeniBackdropTreatment.forMode(HeniBackdropMode mode) {
    return switch (mode) {
      HeniBackdropMode.playback => playback,
      HeniBackdropMode.library => library,
    };
  }

  static const playback = HeniBackdropTreatment(
    blurSigma: 10,
    overlayOpacity: 0.30,
    saturation: 0.84,
    seedWashOpacity: 0.16,
  );

  static const library = HeniBackdropTreatment(
    blurSigma: 16,
    overlayOpacity: 0.46,
    saturation: 0.72,
    seedWashOpacity: 0.18,
  );

  final double blurSigma;
  final double overlayOpacity;
  final double saturation;
  final double seedWashOpacity;
}

Duration heniBackdropTransitionDuration({required bool disableAnimations}) =>
    disableAnimations ? Duration.zero : const Duration(milliseconds: 820);

double heniBackdropImageOpacity(double opacity) =>
    opacity.clamp(0, 1).toDouble();

class GlobalSceneryBackdrop extends StatefulWidget {
  const GlobalSceneryBackdrop({
    required this.imagePaths,
    required this.palette,
    required this.shellTheme,
    required this.mode,
    this.imageOpacity = 1,
    super.key,
  });

  final List<String> imagePaths;
  final HeniPalette palette;
  final HeniShellTheme shellTheme;
  final HeniBackdropMode mode;
  final double imageOpacity;

  @override
  State<GlobalSceneryBackdrop> createState() => _GlobalSceneryBackdropState();
}

class _GlobalSceneryBackdropState extends State<GlobalSceneryBackdrop> {
  Timer? _timer;
  var _index = 0;

  List<String> get _validPaths => [
    for (final path in widget.imagePaths)
      if (File(path).existsSync()) path,
  ];

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant GlobalSceneryBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_samePaths(oldWidget.imagePaths, widget.imagePaths)) {
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
    final treatment = HeniBackdropTreatment.forMode(widget.mode);
    final paths = _validPaths;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        color: widget.shellTheme.canvas,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _PaletteBackdrop(
              key: const ValueKey('global-scenery-fallback'),
              palette: widget.palette,
            ),
            if (paths.isNotEmpty)
              AnimatedOpacity(
                key: const ValueKey('global-scenery-image-opacity'),
                opacity: heniBackdropImageOpacity(widget.imageOpacity),
                duration:
                    disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: AnimatedSwitcher(
                  duration: heniBackdropTransitionDuration(
                    disableAnimations: disableAnimations,
                  ),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  child: _SceneryImage(
                    key: ValueKey(paths[_index % paths.length]),
                    path: paths[_index % paths.length],
                    palette: widget.palette,
                    treatment: treatment,
                  ),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              color: widget.shellTheme.canvas.withValues(
                alpha: treatment.overlayOpacity,
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.72, -0.82),
                  radius: 1.12,
                  colors: [
                    widget.palette.seed.withValues(
                      alpha: treatment.seedWashOpacity,
                    ),
                    widget.palette.glow.withValues(
                      alpha: treatment.seedWashOpacity * 0.38,
                    ),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.42, 1],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.transparent,
                    Colors.black.withValues(
                      alpha:
                          widget.mode == HeniBackdropMode.library ? 0.28 : 0.18,
                    ),
                  ],
                  stops: const [0, 0.48, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _samePaths(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  void _restartTimer() {
    _timer?.cancel();
    final paths = _validPaths;
    if (paths.length <= 1) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 11), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _index = (_index + 1) % paths.length;
      });
    });
  }
}

class _SceneryImage extends StatelessWidget {
  const _SceneryImage({
    required this.path,
    required this.palette,
    required this.treatment,
    super.key,
  });

  final String path;
  final HeniPalette palette;
  final HeniBackdropTreatment treatment;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(
        sigmaX: treatment.blurSigma,
        sigmaY: treatment.blurSigma,
      ),
      child: Transform.scale(
        scale: 1.08,
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(
            _saturationMatrix(treatment.saturation),
          ),
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder:
                (context, error, stackTrace) =>
                    _PaletteBackdrop(palette: palette),
          ),
        ),
      ),
    );
  }
}

class _PaletteBackdrop extends StatelessWidget {
  const _PaletteBackdrop({required this.palette, super.key});

  final HeniPalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              palette.seed.withValues(alpha: 0.18),
              palette.surface,
            ),
            palette.surface,
            Color.alphaBlend(
              palette.glow.withValues(alpha: 0.24),
              palette.surfaceAlt,
            ),
          ],
        ),
      ),
    );
  }
}

List<double> _saturationMatrix(double saturation) {
  final inverse = 1 - saturation;
  final red = 0.213 * inverse;
  final green = 0.715 * inverse;
  final blue = 0.072 * inverse;
  return [
    red + saturation,
    green,
    blue,
    0,
    0,
    red,
    green + saturation,
    blue,
    0,
    0,
    red,
    green,
    blue + saturation,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}
