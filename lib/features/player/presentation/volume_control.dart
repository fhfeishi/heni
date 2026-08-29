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
    this.collapsed = false,
    super.key,
  });

  final PlaybackEngine engine;
  final HeniPalette palette;
  final HeniShellTheme shellTheme;
  final double lastAudibleVolume;
  final ValueChanged<double> onVolumeCommitted;
  final bool compact;
  final bool collapsed;

  @override
  State<HeniVolumeControl> createState() => _HeniVolumeControlState();
}

class _HeniVolumeControlState extends State<HeniVolumeControl> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'HeniVolumeControl');
  StreamSubscription<double>? _subscription;
  late double _volume;
  late double _lastAudibleVolume;
  var _hovering = false;
  var _dragging = false;
  var _focused = false;

  bool get _showThumb => _hovering || _dragging || _focused;

  @override
  void initState() {
    super.initState();
    _readEngineSnapshot();
    _listenToEngine();
    _focusNode.addListener(_handleFocusChange);
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
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() => _focused = _focusNode.hasFocus);
    }
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
    if (event.logicalKey == LogicalKeyboardKey.keyM) {
      _toggleMute();
      return KeyEventResult.handled;
    }
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.arrowDown => -5.0,
      LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.arrowUp => 5.0,
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

  Widget _buildSlider({required Key key, required double width}) {
    final accent = heniAccentOnGlass(widget.palette.accent);
    return SizedBox(
      width: width,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: accent,
          inactiveTrackColor: Colors.white.withValues(alpha: 0.14),
          disabledActiveTrackColor: accent.withValues(alpha: 0.4),
          thumbColor: accent,
          overlayColor: accent.withValues(alpha: 0.10),
          trackHeight: 2.5,
          thumbShape: RoundSliderThumbShape(
            enabledThumbRadius: _showThumb ? 4.5 : 2,
          ),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 9),
        ),
        child: Slider(
          key: key,
          value: _volume,
          min: 0,
          max: 100,
          onChangeStart: (_) => setState(() => _dragging = true),
          onChanged: _setLive,
          onChangeEnd: (value) {
            setState(() => _dragging = false);
            _commit(value);
          },
        ),
      ),
    );
  }

  Widget _buildVolumeButton({required VoidCallback onPressed}) {
    return IconButton(
      key: const ValueKey('heni-volume-button'),
      tooltip:
          widget.collapsed
              ? '音量 ${_volume.round()}%，单击调整，右键静音'
              : _volume > 0
              ? '静音'
              : '恢复音量',
      onPressed: onPressed,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 140),
        child: Icon(_volumeIcon, key: ValueKey(_volumeIcon), size: 19),
      ),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(38),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor:
            _volume > 0
                ? widget.shellTheme.primaryText
                : widget.shellTheme.secondaryText,
        hoverColor: widget.shellTheme.hover.withValues(alpha: 0.72),
        highlightColor: widget.shellTheme.pressed,
      ),
    );
  }

  Widget _buildCollapsedControl() {
    return MenuAnchor(
      alignmentOffset: const Offset(-126, -8),
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        ),
        backgroundColor: WidgetStatePropertyAll(widget.shellTheme.dock),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(5),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: widget.shellTheme.border.withValues(alpha: 0.75),
            ),
          ),
        ),
      ),
      menuChildren: [
        SizedBox(
          key: const ValueKey('heni-volume-popover'),
          width: 166,
          height: 42,
          child: Row(
            children: [
              Expanded(
                child: _buildSlider(
                  key: const ValueKey('heni-volume-slider-popover'),
                  width: 118,
                ),
              ),
              SizedBox(
                width: 34,
                child: Text(
                  '${_volume.round()}%',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: widget.shellTheme.secondaryText,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      builder: (context, controller, child) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTap: _toggleMute,
          child: _buildVolumeButton(
            onPressed: controller.isOpen ? controller.close : controller.open,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '音量 ${_volume.round()}%',
      child: Focus(
        key: const ValueKey('heni-volume-focus'),
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Listener(
          key: const ValueKey('heni-volume-shell'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _focusNode.requestFocus(),
          onPointerSignal: _handlePointerSignal,
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovering = true),
            onExit: (_) => setState(() => _hovering = false),
            child:
                widget.collapsed
                    ? _buildCollapsedControl()
                    : SizedBox(
                      key: const ValueKey('heni-volume-inline'),
                      height: 38,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildVolumeButton(onPressed: _toggleMute),
                          _buildSlider(
                            key: const ValueKey('heni-volume-slider'),
                            width: widget.compact ? 64 : 84,
                          ),
                        ],
                      ),
                    ),
          ),
        ),
      ),
    );
  }
}
