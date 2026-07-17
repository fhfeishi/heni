import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../design/app_theme.dart';
import '../../../design/heni_shell_theme.dart';
import '../../../services/media/playback_engine.dart';

class HeniVolumeControl extends StatefulWidget {
  const HeniVolumeControl({
    required this.engine,
    required this.palette,
    required this.shellTheme,
    required this.onVolumeCommitted,
    super.key,
  });

  final PlaybackEngine engine;
  final HeniPalette palette;
  final HeniShellTheme shellTheme;
  final ValueChanged<double> onVolumeCommitted;

  @override
  State<HeniVolumeControl> createState() => _HeniVolumeControlState();
}

class _HeniVolumeControlState extends State<HeniVolumeControl> {
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
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _readEngineSnapshot() {
    _volume = widget.engine.currentVolume.clamp(0, 100).toDouble();
    _lastAudibleVolume = _volume > 0 ? _volume : 60;
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
      _commit(0);
    } else {
      _commit(_lastAudibleVolume <= 0 ? 60 : _lastAudibleVolume);
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) {
      return;
    }
    final delta = event.scrollDelta.dy < 0 ? 2.0 : -2.0;
    _commit(_volume + delta);
  }

  IconData get _volumeIcon => switch (_volume.round()) {
    <= 0 => Icons.volume_off_rounded,
    < 50 => Icons.volume_down_rounded,
    _ => Icons.volume_up_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        minimumSize: WidgetStatePropertyAll(Size.zero),
        shadowColor: WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
      ),
      alignmentOffset: const Offset(-204, -76),
      menuChildren: [
        Listener(
          onPointerSignal: _handlePointerSignal,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                key: const ValueKey('heni-volume-popover'),
                width: 250,
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: widget.shellTheme.dock,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: widget.shellTheme.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: _volume > 0 ? '静音' : '恢复音量',
                      onPressed: _toggleMute,
                      icon: Icon(_volumeIcon, size: 19),
                      style: IconButton.styleFrom(
                        fixedSize: const Size.square(38),
                        padding: EdgeInsets.zero,
                        foregroundColor: widget.shellTheme.primaryText,
                        backgroundColor: widget.shellTheme.hover,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: widget.palette.seed,
                          inactiveTrackColor: Colors.white.withValues(
                            alpha: 0.12,
                          ),
                          thumbColor: widget.palette.accent,
                          overlayColor: widget.palette.seed.withValues(
                            alpha: 0.16,
                          ),
                          trackHeight: 3,
                        ),
                        child: Slider(
                          value: _volume,
                          min: 0,
                          max: 100,
                          onChanged: _setLive,
                          onChangeEnd: _commit,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 38,
                      child: Text(
                        '${_volume.round()}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: widget.shellTheme.primaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [ui.FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      builder: (context, controller, child) {
        return Listener(
          onPointerSignal: _handlePointerSignal,
          child: IconButton(
            tooltip: '音量 ${_volume.round()}%',
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            style: IconButton.styleFrom(
              foregroundColor: widget.shellTheme.secondaryText,
              hoverColor: widget.shellTheme.hover,
              highlightColor: widget.shellTheme.pressed,
            ),
            icon: Icon(_volumeIcon),
          ),
        );
      },
    );
  }
}
