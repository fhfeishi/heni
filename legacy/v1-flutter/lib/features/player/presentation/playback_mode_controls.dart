import 'package:flutter/material.dart';

import '../../../design/app_theme.dart';
import '../../../domain/playback/playback_mode.dart';

class HeniPlaybackModeControls extends StatelessWidget {
  const HeniPlaybackModeControls({
    super.key,
    required this.palette,
    required this.mode,
    required this.enabled,
    required this.onCycleMode,
    required this.onModeSelected,
    this.transport,
    this.size = 38,
    this.iconSize = 19,
    this.gap = 6,
  });

  final HeniPalette palette;
  final HeniPlaybackMode mode;
  final bool enabled;
  final VoidCallback onCycleMode;
  final ValueChanged<HeniPlaybackMode> onModeSelected;
  final Widget? transport;
  final double size;
  final double iconSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (transport case final Widget child) ...[child, SizedBox(width: gap)],
        HeniPlaybackModeButton(
          palette: palette,
          mode: mode.normalized,
          enabled: enabled,
          onCycleMode: onCycleMode,
          onModeSelected: onModeSelected,
          size: size,
          iconSize: iconSize,
        ),
      ],
    );
  }
}

class HeniPlaybackModeButton extends StatelessWidget {
  const HeniPlaybackModeButton({
    super.key,
    required this.palette,
    required this.mode,
    required this.enabled,
    required this.onCycleMode,
    required this.onModeSelected,
    this.size = 38,
    this.iconSize = 19,
  });

  final HeniPalette palette;
  final HeniPlaybackMode mode;
  final bool enabled;
  final VoidCallback onCycleMode;
  final ValueChanged<HeniPlaybackMode> onModeSelected;
  final double size;
  final double iconSize;

  IconData _iconFor(HeniPlaybackMode value) => switch (value.normalized) {
    HeniPlaybackMode.listLoop => Icons.repeat_rounded,
    HeniPlaybackMode.singleLoop => Icons.repeat_one_rounded,
    HeniPlaybackMode.random => Icons.shuffle_rounded,
    HeniPlaybackMode.sequence => Icons.repeat_rounded,
  };

  Future<void> _showModeMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
    if (!enabled) {
      return;
    }
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final selected = await showMenu<HeniPlaybackMode>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final candidate in HeniPlaybackMode.selectableValues)
          PopupMenuItem<HeniPlaybackMode>(
            value: candidate,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child:
                      candidate == mode
                          ? const Icon(
                            Icons.check_rounded,
                            key: ValueKey('selected-playback-mode'),
                            size: 18,
                          )
                          : const SizedBox.shrink(),
                ),
                const SizedBox(width: 8),
                Icon(_iconFor(candidate), size: 18),
                const SizedBox(width: 10),
                Text(candidate.label),
              ],
            ),
          ),
      ],
    );
    if (context.mounted && selected != null && selected != mode) {
      onModeSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedMode = mode.normalized;
    final activeColor = heniAccentOnGlass(palette.accent);
    final inactiveColor = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72);
    final tooltip =
        enabled ? '播放模式：${normalizedMode.label}（单击切换，右键选择）' : '播放模式不可用';

    return Semantics(
      button: true,
      enabled: enabled,
      label: '播放模式：${normalizedMode.label}',
      hint: enabled ? '单击切换，右键或长按直接选择' : null,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapDown:
              enabled
                  ? (details) => _showModeMenu(context, details.globalPosition)
                  : null,
          onLongPressStart:
              enabled
                  ? (details) => _showModeMenu(context, details.globalPosition)
                  : null,
          child: IconButton(
            key: const ValueKey('playback-mode-button'),
            onPressed: enabled ? onCycleMode : null,
            style: ButtonStyle(
              fixedSize: WidgetStatePropertyAll(Size.square(size)),
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return inactiveColor.withValues(alpha: 0.34);
                }
                return activeColor;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return Colors.white.withValues(alpha: 0.10);
                }
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return Colors.white.withValues(alpha: 0.065);
                }
                return Colors.transparent;
              }),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            ),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeOut,
              transitionBuilder:
                  (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
              child: Icon(
                _iconFor(normalizedMode),
                key: ValueKey(normalizedMode),
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
