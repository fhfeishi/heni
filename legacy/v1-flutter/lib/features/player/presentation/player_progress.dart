import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../design/app_theme.dart';
import '../../../services/media/playback_engine.dart';

class PlayerProgressSnapshot {
  const PlayerProgressSnapshot({
    required this.position,
    required this.total,
    required this.totalKnown,
    required this.fraction,
  });

  final Duration position;
  final Duration total;
  final bool totalKnown;
  final double fraction;

  bool get canSeek => totalKnown && total > Duration.zero;
}

PlayerProgressSnapshot resolvePlayerProgressSnapshot({
  required Duration? streamedPosition,
  required Duration? streamedDuration,
  required Duration enginePosition,
  required Duration engineDuration,
  required Duration? fallbackDuration,
}) {
  final total = [
    streamedDuration,
    engineDuration,
    fallbackDuration,
  ].whereType<Duration>().firstWhere(
    (duration) => duration > Duration.zero,
    orElse: () => Duration.zero,
  );
  final rawPosition = streamedPosition ?? enginePosition;
  final nonNegativePosition =
      rawPosition < Duration.zero ? Duration.zero : rawPosition;
  if (total <= Duration.zero) {
    return PlayerProgressSnapshot(
      position: nonNegativePosition,
      total: Duration.zero,
      totalKnown: false,
      fraction: 0,
    );
  }

  final position = nonNegativePosition > total ? total : nonNegativePosition;
  return PlayerProgressSnapshot(
    position: position,
    total: total,
    totalKnown: true,
    fraction: position.inMicroseconds / total.inMicroseconds,
  );
}

class PlayerProgressWithTime extends StatefulWidget {
  const PlayerProgressWithTime({
    super.key,
    required this.engine,
    required this.palette,
    required this.mediaId,
    this.fallbackDuration,
  });

  final PlaybackEngine engine;
  final HeniPalette palette;
  final String mediaId;
  final Duration? fallbackDuration;

  @override
  State<PlayerProgressWithTime> createState() => _PlayerProgressWithTimeState();
}

class _PlayerProgressWithTimeState extends State<PlayerProgressWithTime> {
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  Duration? _streamedPosition;
  Duration? _streamedDuration;
  bool _hovering = false;
  bool _dragging = false;
  double? _hoverFraction;
  double? _dragFraction;
  int _streamGeneration = 0;

  @override
  void initState() {
    super.initState();
    _bindStreams();
  }

  @override
  void didUpdateWidget(covariant PlayerProgressWithTime oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.engine != widget.engine ||
        oldWidget.mediaId != widget.mediaId) {
      _resetForMedia();
      _bindStreams();
    }
  }

  @override
  void dispose() {
    _streamGeneration++;
    unawaited(_positionSubscription?.cancel());
    unawaited(_durationSubscription?.cancel());
    super.dispose();
  }

  void _resetForMedia() {
    _streamGeneration++;
    unawaited(_positionSubscription?.cancel());
    unawaited(_durationSubscription?.cancel());
    _streamedPosition = null;
    _streamedDuration = null;
    _hovering = false;
    _dragging = false;
    _hoverFraction = null;
    _dragFraction = null;
  }

  void _bindStreams() {
    final generation = ++_streamGeneration;
    _positionSubscription = widget.engine.position.listen((position) {
      if (!mounted || generation != _streamGeneration || _dragging) {
        return;
      }
      setState(() => _streamedPosition = position);
    });
    _durationSubscription = widget.engine.duration.listen((duration) {
      if (!mounted || generation != _streamGeneration) {
        return;
      }
      setState(() => _streamedDuration = duration);
    });
  }

  PlayerProgressSnapshot get _snapshot {
    return resolvePlayerProgressSnapshot(
      streamedPosition: _streamedPosition,
      streamedDuration: _streamedDuration,
      enginePosition: widget.engine.currentPosition,
      engineDuration: widget.engine.currentDuration,
      fallbackDuration: widget.fallbackDuration,
    );
  }

  Duration _durationAtFraction(Duration total, double fraction) {
    return Duration(
      microseconds: (total.inMicroseconds * fraction.clamp(0, 1)).round(),
    );
  }

  void _seekToFraction(PlayerProgressSnapshot snapshot, double fraction) {
    if (!snapshot.canSeek) {
      return;
    }
    unawaited(
      widget.engine.seek(_durationAtFraction(snapshot.total, fraction)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final displayFraction =
        _dragging ? (_dragFraction ?? snapshot.fraction) : snapshot.fraction;
    final displayPosition =
        _dragging && snapshot.totalKnown
            ? _durationAtFraction(snapshot.total, displayFraction)
            : snapshot.position;
    final currentLabel = formatPlayerProgressTime(displayPosition);
    final totalLabel =
        snapshot.totalKnown
            ? formatPlayerProgressTime(snapshot.total)
            : '--:--';
    final timeStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: Colors.white.withValues(alpha: 0.48),
      fontFeatures: const [ui.FontFeature.tabularFigures()],
    );

    Widget track() {
      return _buildTrack(
        context,
        snapshot: snapshot,
        displayFraction: displayFraction,
        displayPosition: displayPosition,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 280) {
          return SizedBox(
            key: const ValueKey('player-progress-wide'),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 46,
                  child: _StableProgressTimeText(
                    text: currentLabel,
                    textAlign: TextAlign.right,
                    style: timeStyle.copyWith(
                      color: Colors.white.withValues(alpha: 0.70),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: track()),
                const SizedBox(width: 8),
                SizedBox(
                  width: 46,
                  child: _StableProgressTimeText(
                    text: totalLabel,
                    textAlign: TextAlign.left,
                    style: timeStyle,
                  ),
                ),
              ],
            ),
          );
        }

        if (constraints.maxWidth >= 180) {
          return SizedBox(
            key: const ValueKey('player-progress-compact'),
            child: Row(
              children: [
                Expanded(child: track()),
                const SizedBox(width: 8),
                SizedBox(
                  width: 84,
                  child: _StableProgressTimeText(
                    text: '$currentLabel / $totalLabel',
                    textAlign: TextAlign.right,
                    style: timeStyle,
                  ),
                ),
              ],
            ),
          );
        }

        return SizedBox(
          key: const ValueKey('player-progress-narrow'),
          child: track(),
        );
      },
    );
  }

  Widget _buildTrack(
    BuildContext context, {
    required PlayerProgressSnapshot snapshot,
    required double displayFraction,
    required Duration displayPosition,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth;
        final safeBarWidth = math.max(barWidth, 1);

        void updateDrag(double localX) {
          setState(() {
            _dragFraction = (localX / safeBarWidth).clamp(0, 1);
          });
        }

        final tooltipDuration =
            _dragging
                ? displayPosition
                : _hoverFraction != null && snapshot.totalKnown
                ? _durationAtFraction(snapshot.total, _hoverFraction!)
                : null;
        final tooltipFraction =
            _dragging ? displayFraction : (_hoverFraction ?? displayFraction);
        final tooltipCenter =
            barWidth <= 48
                ? barWidth / 2
                : (tooltipFraction * barWidth).clamp(24, barWidth - 24);

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            MouseRegion(
              cursor:
                  snapshot.canSeek
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
              onEnter: (_) => setState(() => _hovering = true),
              onExit:
                  (_) => setState(() {
                    _hovering = false;
                    _hoverFraction = null;
                  }),
              onHover: (event) {
                if (!snapshot.canSeek || _dragging) {
                  return;
                }
                setState(() {
                  _hoverFraction = (event.localPosition.dx / safeBarWidth)
                      .clamp(0, 1);
                });
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown:
                    snapshot.canSeek
                        ? (details) => _seekToFraction(
                          snapshot,
                          details.localPosition.dx / safeBarWidth,
                        )
                        : null,
                onHorizontalDragStart:
                    snapshot.canSeek
                        ? (details) {
                          setState(() => _dragging = true);
                          updateDrag(details.localPosition.dx);
                        }
                        : null,
                onHorizontalDragUpdate:
                    snapshot.canSeek
                        ? (details) => updateDrag(details.localPosition.dx)
                        : null,
                onHorizontalDragEnd:
                    snapshot.canSeek
                        ? (_) {
                          final fraction = _dragFraction;
                          if (fraction != null) {
                            _seekToFraction(snapshot, fraction);
                          }
                          setState(() {
                            _dragging = false;
                            _dragFraction = null;
                          });
                        }
                        : null,
                onHorizontalDragCancel:
                    snapshot.canSeek
                        ? () {
                          setState(() {
                            _dragging = false;
                            _dragFraction = null;
                          });
                        }
                        : null,
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
            if ((_hovering || _dragging) && tooltipDuration != null)
              Positioned(
                top: -34,
                left: tooltipCenter - 24,
                child: _PlayerProgressTimeTooltip(
                  duration: tooltipDuration,
                  seedColor: widget.palette.seed,
                ),
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
  final safeDuration = duration < Duration.zero ? Duration.zero : duration;
  final hours = safeDuration.inHours;
  final minutes = safeDuration.inMinutes.remainder(60);
  final seconds = safeDuration.inSeconds.remainder(60);
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
