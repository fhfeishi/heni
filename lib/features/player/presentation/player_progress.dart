import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../design/app_theme.dart';
import '../../../services/media/playback_engine.dart';

const _minimumWidthForSeparateTimes = 150.0;

class PlayerProgressWithTime extends StatelessWidget {
  const PlayerProgressWithTime({
    super.key,
    required this.engine,
    required this.palette,
    this.fallbackDuration,
  });

  final PlaybackEngine engine;
  final HeniPalette palette;
  final Duration? fallbackDuration;

  @override
  Widget build(BuildContext context) {
    final timeStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: Colors.white.withValues(alpha: 0.48),
      fontFeatures: const [ui.FontFeature.tabularFigures()],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final progress = _PlayerProgressBar(engine: engine, palette: palette);
        if (constraints.maxWidth < _minimumWidthForSeparateTimes) {
          return progress;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            StreamBuilder<Duration>(
              stream: engine.position,
              initialData: Duration.zero,
              builder: (context, snap) {
                return SizedBox(
                  width: 46,
                  child: _StableProgressTimeText(
                    text: formatPlayerProgressTime(snap.data ?? Duration.zero),
                    textAlign: TextAlign.right,
                    style: timeStyle.copyWith(
                      color: Colors.white.withValues(alpha: 0.70),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            Expanded(child: progress),
            const SizedBox(width: 8),
            StreamBuilder<Duration>(
              stream: engine.duration,
              initialData: fallbackDuration ?? Duration.zero,
              builder: (context, snap) {
                final duration = resolvePlayerDisplayDuration(
                  snap.data,
                  fallbackDuration,
                );
                return SizedBox(
                  width: 46,
                  child: _StableProgressTimeText(
                    text: formatPlayerProgressTime(duration),
                    textAlign: TextAlign.left,
                    style: timeStyle,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

Duration resolvePlayerDisplayDuration(Duration? streamed, Duration? fallback) {
  if (streamed != null && streamed > Duration.zero) {
    return streamed;
  }
  if (fallback != null && fallback > Duration.zero) {
    return fallback;
  }
  return Duration.zero;
}

String formatPlayerProgressTime(Duration duration) {
  if (duration == Duration.zero) {
    return '--:--';
  }
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

class _StableProgressTimeText extends StatelessWidget {
  const _StableProgressTimeText({
    required this.text,
    required this.textAlign,
    required this.style,
  });

  final String text;
  final TextAlign textAlign;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final alignment =
        textAlign == TextAlign.right
            ? Alignment.centerRight
            : Alignment.centerLeft;

    return Align(
      alignment: alignment,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(
          text,
          textAlign: textAlign,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: style,
        ),
      ),
    );
  }
}

class _PlayerProgressBar extends StatefulWidget {
  const _PlayerProgressBar({required this.engine, required this.palette});

  final PlaybackEngine engine;
  final HeniPalette palette;

  @override
  State<_PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<_PlayerProgressBar> {
  bool _hovering = false;
  bool _dragging = false;
  double? _hoverFraction;
  double? _dragFraction;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.engine.duration,
      initialData: Duration.zero,
      builder: (context, durationSnap) {
        final total = durationSnap.data ?? Duration.zero;

        return StreamBuilder<Duration>(
          stream: widget.engine.position,
          initialData: Duration.zero,
          builder: (context, positionSnap) {
            final position = positionSnap.data ?? Duration.zero;
            final totalMilliseconds = total.inMilliseconds.toDouble().clamp(
              1,
              double.infinity,
            );
            final positionMilliseconds =
                position.inMilliseconds
                    .clamp(0, totalMilliseconds.toInt())
                    .toDouble();
            final playbackFraction = positionMilliseconds / totalMilliseconds;
            final displayFraction =
                _dragging
                    ? (_dragFraction ?? playbackFraction)
                    : playbackFraction;

            return LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = constraints.maxWidth;
                final safeBarWidth = math.max(barWidth, 1);

                void seekToFraction(double fraction) {
                  final milliseconds =
                      (fraction.clamp(0, 1) * totalMilliseconds).round();
                  unawaited(
                    widget.engine.seek(Duration(milliseconds: milliseconds)),
                  );
                }

                void updateDrag(double localX) {
                  setState(() {
                    _dragFraction = (localX / safeBarWidth).clamp(0, 1);
                  });
                }

                final hoverDuration =
                    _hoverFraction == null
                        ? null
                        : Duration(
                          milliseconds:
                              (_hoverFraction! * totalMilliseconds).round(),
                        );
                final tooltipCenter =
                    barWidth <= 48
                        ? barWidth / 2
                        : ((_hoverFraction ?? displayFraction) * barWidth)
                            .clamp(24, barWidth - 24);

                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => _hovering = true),
                      onExit:
                          (_) => setState(() {
                            _hovering = false;
                            _hoverFraction = null;
                          }),
                      onHover: (event) {
                        setState(() {
                          _hoverFraction = (event.localPosition.dx /
                                  safeBarWidth)
                              .clamp(0, 1);
                        });
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown:
                            (details) => seekToFraction(
                              details.localPosition.dx / safeBarWidth,
                            ),
                        onHorizontalDragStart: (details) {
                          setState(() => _dragging = true);
                          updateDrag(details.localPosition.dx);
                        },
                        onHorizontalDragUpdate:
                            (details) => updateDrag(details.localPosition.dx),
                        onHorizontalDragEnd: (_) {
                          if (_dragFraction != null) {
                            seekToFraction(_dragFraction!);
                          }
                          setState(() {
                            _dragging = false;
                            _dragFraction = null;
                          });
                        },
                        child: SizedBox(
                          key: const ValueKey('player-progress-track'),
                          height: 26,
                          width: barWidth,
                          child: CustomPaint(
                            painter: _PlayerProgressBarPainter(
                              fraction: displayFraction,
                              hovering: _hovering || _dragging,
                              seedColor: widget.palette.seed,
                              accentColor: widget.palette.accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if ((_hovering || _dragging) && hoverDuration != null)
                      Positioned(
                        top: -34,
                        left: tooltipCenter - 24,
                        child: _PlayerProgressTimeTooltip(
                          duration: hoverDuration,
                          seedColor: widget.palette.seed,
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _PlayerProgressTimeTooltip extends StatelessWidget {
  const _PlayerProgressTimeTooltip({
    required this.duration,
    required this.seedColor,
  });

  final Duration duration;
  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          seedColor.withValues(alpha: 0.72),
          Colors.black.withValues(alpha: 0.26),
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        formatPlayerProgressTime(duration),
        style: TextStyle(
          fontSize: 10.6,
          fontWeight: FontWeight.w700,
          color: heniReadableForegroundOn(seedColor),
          fontFeatures: const [ui.FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _PlayerProgressBarPainter extends CustomPainter {
  const _PlayerProgressBarPainter({
    required this.fraction,
    required this.hovering,
    required this.seedColor,
    required this.accentColor,
  });

  final double fraction;
  final bool hovering;
  final Color seedColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    const trackHeight = 2.5;
    const hoverTrackHeight = 4.0;
    final height = hovering ? hoverTrackHeight : trackHeight;
    final centerY = size.height / 2;
    const radius = Radius.circular(6);

    final trackRect = Rect.fromLTWH(
      0,
      centerY - height / 2,
      size.width,
      height,
    );
    final trackRRect = RRect.fromRectAndRadius(trackRect, radius);
    canvas.drawRRect(
      trackRRect,
      Paint()..color = Colors.white.withValues(alpha: 0.085),
    );

    final resolvedFraction = fraction.clamp(0.0, 1.0);
    if (resolvedFraction > 0) {
      final fillWidth = size.width * resolvedFraction;
      final fillRect = Rect.fromLTWH(
        0,
        centerY - height / 2,
        fillWidth,
        height,
      );
      final blended = Color.lerp(seedColor, accentColor, 0.6)!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(fillRect, radius),
        Paint()
          ..shader = LinearGradient(
            colors: [
              seedColor.withValues(alpha: 0.88),
              blended.withValues(alpha: 0.92),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, height)),
      );
    }

    if (hovering) {
      final thumbX = (size.width * resolvedFraction).clamp(0.0, size.width);
      final center = Offset(thumbX, centerY);
      canvas.drawCircle(
        center,
        7.5,
        Paint()
          ..color = seedColor.withValues(alpha: 0.14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(center, 4.2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _PlayerProgressBarPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.hovering != hovering ||
        oldDelegate.seedColor != seedColor ||
        oldDelegate.accentColor != accentColor;
  }
}
