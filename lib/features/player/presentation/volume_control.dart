import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/app_theme.dart';
import '../../../design/heni_shell_theme.dart';
import '../../../services/media/playback_engine.dart';

double resolveMuteTarget({
  required double current,
  required double lastAudible,
}) {
  if (current > 0) {
    return 0;
  }
  return lastAudible > 0 ? lastAudible.clamp(1, 100).toDouble() : 60;
}

class HeniVolumeControl extends StatefulWidget {
  const HeniVolumeControl({
    required this.engine,
    required this.palette,
    required this.shellTheme,
    required this.lastAudibleVolume,
    required this.onVolumeCommitted,
    this.compact = false,
    super.key,
  });

  final PlaybackEngine engine;
  final HeniPalette palette;
  final HeniShellTheme shellTheme;
  final double lastAudibleVolume;
  final ValueChanged<double> onVolumeCommitted;
  final bool compact;

  @override
  State<HeniVolumeControl> createState() => _HeniVolumeControlState();
}

class _HeniVolumeControlState extends State<HeniVolumeControl> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'HeniVolumeControl');
  StreamSubscription<double>? _subscription;
  late double _volume;
  late double _lastAudibleVolume;

  @override
  void initState() {
    super.initState();
    _readEngineSnapshot();
    _listenToEngine();
  }

  @override
  void didUpdateWidget(covariant HeniVolumeControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.engine != widget.engine) {
      unawaited(_subscription?.cancel());
      _readEngineSnapshot();
      _listenToEngine();
      return;
    }
    if (oldWidget.lastAudibleVolume != widget.lastAudibleVolume &&
        widget.lastAudibleVolume > 0 &&
        _volume <= 0) {
      _lastAudibleVolume = widget.lastAudibleVolume.clamp(1, 100).toDouble();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _focusNode.dispose();
    super.dispose();
  }

  void _readEngineSnapshot() {
    _volume = widget.engine.currentVolume.clamp(0, 100).toDouble();
    _lastAudibleVolume =
        _volume > 0
            ? _volume
            : widget.lastAudibleVolume > 0
            ? widget.lastAudibleVolume.clamp(1, 100).toDouble()
            : 60;
  }

  void _listenToEngine() {
    _subscription = widget.engine.volume.listen((value) {
      if (!mounted) {
        return;
      }
      final next = value.clamp(0, 100).toDouble();
      setState(() {
        _volume = next;
        if (next > 0) {
          _lastAudibleVolume = next;
        }
      });
    });
  }

  void _setLive(double value) {
    final next = value.clamp(0.0, 100.0).toDouble();
    if (next > 0) {
      _lastAudibleVolume = next;
    }
    setState(() => _volume = next);
    unawaited(widget.engine.setVolume(next));
  }

  void _commit(double value) {
    final next = value.clamp(0.0, 100.0).toDouble();
    _setLive(next);
    widget.onVolumeCommitted(next);
  }

  void _toggleMute() {
    if (_volume > 0) {
      _lastAudibleVolume = _volume;
    }
    _commit(
      resolveMuteTarget(current: _volume, lastAudible: _lastAudibleVolume),
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) {
      return;
    }
    final delta = event.scrollDelta.dy < 0 ? 2.0 : -2.0;
    _commit(_volume + delta);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => -5.0,
      LogicalKeyboardKey.arrowRight => 5.0,
      _ => 0.0,
    };
    if (delta == 0) {
      return KeyEventResult.ignored;
    }
    _commit(_volume + delta);
    return KeyEventResult.handled;
  }

  IconData get _volumeIcon => switch (_volume.round()) {
    <= 0 => Icons.volume_off_rounded,
    < 50 => Icons.volume_down_rounded,
    _ => Icons.volume_up_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final accent = heniAccentOnGlass(widget.palette.accent);
    return Tooltip(
      message: '音量 ${_volume.round()}%',
      child: Focus(
        key: const ValueKey('heni-volume-focus'),
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Listener(
          key: const ValueKey('heni-volume-shell'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _focusNode.requestFocus(),
          onPointerSignal: _handlePointerSignal,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: widget.shellTheme.hover.withValues(alpha: 0.54),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: widget.shellTheme.border.withValues(alpha: 0.72),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: _volume > 0 ? '静音' : '恢复音量',
                  onPressed: _toggleMute,
                  icon: Icon(_volumeIcon, size: 19),
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(38),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor:
                        _volume > 0
                            ? widget.shellTheme.primaryText
                            : widget.shellTheme.secondaryText,
                    hoverColor: widget.shellTheme.hover,
                    highlightColor: widget.shellTheme.pressed,
                  ),
                ),
                SizedBox(
                  width: widget.compact ? 64 : 88,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: accent,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                      disabledActiveTrackColor: accent.withValues(alpha: 0.4),
                      thumbColor: accent,
                      overlayColor: accent.withValues(alpha: 0.12),
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 4,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 10,
                      ),
                    ),
                    child: Slider(
                      key: const ValueKey('heni-volume-slider'),
                      value: _volume,
                      min: 0,
                      max: 100,
                      onChanged: _setLive,
                      onChangeEnd: _commit,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
