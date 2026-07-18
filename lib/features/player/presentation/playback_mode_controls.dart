import 'package:flutter/material.dart';

import '../../../design/app_theme.dart';
import '../../../domain/playback/playback_mode.dart';

class HeniPlaybackModeControls extends StatelessWidget {
  const HeniPlaybackModeControls({
    super.key,
    required this.palette,
    required this.shuffle,
    required this.repeatMode,
    required this.enabled,
    required this.onToggleShuffle,
    required this.onCycleRepeat,
    this.transport,
    this.size = 38,
    this.iconSize = 19,
    this.gap = 6,
  });

  final HeniPalette palette;
  final bool shuffle;
  final HeniRepeatMode repeatMode;
  final bool enabled;
  final VoidCallback onToggleShuffle;
  final VoidCallback onCycleRepeat;
  final Widget? transport;
  final double size;
  final double iconSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HeniShuffleModeButton(
          palette: palette,
          active: shuffle,
          enabled: enabled,
          onPressed: onToggleShuffle,
          size: size,
          iconSize: iconSize,
        ),
        SizedBox(width: gap),
        if (transport case final Widget child) ...[child, SizedBox(width: gap)],
        HeniRepeatModeButton(
          palette: palette,
          repeatMode: repeatMode,
          enabled: enabled,
          onPressed: onCycleRepeat,
          size: size,
          iconSize: iconSize,
        ),
      ],
    );
  }
}

class HeniShuffleModeButton extends StatelessWidget {
  const HeniShuffleModeButton({
    super.key,
    required this.palette,
    required this.active,
    required this.enabled,
    required this.onPressed,
    this.size = 38,
    this.iconSize = 19,
  });

  final HeniPalette palette;
  final bool active;
  final bool enabled;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return _ModeButton(
      palette: palette,
      tooltip: active ? '随机播放：已开启' : '随机播放：已关闭',
      icon: Icons.shuffle_rounded,
      iconKey: ValueKey(active),
      stateDotKey: const ValueKey('shuffle-mode-state-dot'),
      active: active,
      enabled: enabled,
      onPressed: onPressed,
      size: size,
      iconSize: iconSize,
    );
  }
}

class HeniRepeatModeButton extends StatelessWidget {
  const HeniRepeatModeButton({
    super.key,
    required this.palette,
    required this.repeatMode,
    required this.enabled,
    required this.onPressed,
    this.size = 38,
    this.iconSize = 19,
  });

  final HeniPalette palette;
  final HeniRepeatMode repeatMode;
  final bool enabled;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final (tooltip, icon) = switch (repeatMode) {
      HeniRepeatMode.none => ('循环：关闭', Icons.repeat_rounded),
      HeniRepeatMode.all => ('循环：列表', Icons.repeat_rounded),
      HeniRepeatMode.one => ('循环：单曲', Icons.repeat_one_rounded),
    };

    return _ModeButton(
      palette: palette,
      tooltip: tooltip,
      icon: icon,
      iconKey: ValueKey(repeatMode),
      stateDotKey: const ValueKey('repeat-mode-state-dot'),
      active: repeatMode != HeniRepeatMode.none,
      enabled: enabled,
      onPressed: onPressed,
      size: size,
      iconSize: iconSize,
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.palette,
    required this.tooltip,
    required this.icon,
    required this.iconKey,
    required this.stateDotKey,
    required this.active,
    required this.enabled,
    required this.onPressed,
    required this.size,
    required this.iconSize,
  });

  final HeniPalette palette;
  final String tooltip;
  final IconData icon;
  final Key iconKey;
  final Key stateDotKey;
  final bool active;
  final bool enabled;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = heniAccentOnGlass(palette.accent);
    final inactiveColor = theme.colorScheme.onSurfaceVariant.withValues(
      alpha: 0.72,
    );

    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: enabled ? onPressed : null,
              style: ButtonStyle(
                fixedSize: WidgetStatePropertyAll(Size.square(size)),
                padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) {
                    return inactiveColor.withValues(alpha: 0.34);
                  }
                  return active ? activeColor : inactiveColor;
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
                duration: const Duration(milliseconds: 140),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeOut,
                transitionBuilder:
                    (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                child: Icon(icon, key: iconKey, size: iconSize),
              ),
            ),
            Positioned(
              bottom: 2,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 140),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeOut,
                child:
                    active
                        ? Container(
                          key: stateDotKey,
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color:
                                enabled
                                    ? activeColor
                                    : activeColor.withValues(alpha: 0.34),
                            shape: BoxShape.circle,
                          ),
                        )
                        : const SizedBox(
                          key: ValueKey('inactive-mode-state-dot'),
                          width: 3,
                          height: 3,
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
