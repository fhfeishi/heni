import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/app_theme.dart';
import '../../../design/heni_shell_theme.dart';
import '../../../services/window/heni_window_controller.dart';

class HeniBrandWordmark extends StatelessWidget {
  const HeniBrandWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'heni',
      key: const ValueKey('heni-brand-wordmark'),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Colors.white.withValues(alpha: 0.94),
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }
}

class HeniWindowDragRegion extends ConsumerWidget {
  const HeniWindowDragRegion({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: () {
        unawaited(
          ref.read(heniWindowControllerProvider.notifier).toggleMaximize(),
        );
      },
      onPanStart: (_) {
        unawaited(ref.read(heniWindowControllerProvider.notifier).beginDrag());
      },
      child: child,
    );
  }
}

class HeniBrandViewSwitcher extends StatelessWidget {
  const HeniBrandViewSwitcher({
    required this.activeView,
    required this.shellTheme,
    required this.onToggleView,
    this.compact = false,
    super.key,
  });

  final HeniUiStyle activeView;
  final HeniShellTheme shellTheme;
  final VoidCallback onToggleView;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final showLibrary = activeView == HeniUiStyle.scenery;
    final tooltip = showLibrary ? '切换到歌曲列表' : '返回播放页面';
    final icon =
        showLibrary ? Icons.queue_music_rounded : Icons.graphic_eq_rounded;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HeniWindowDragRegion(
          child: SizedBox(
            key: const ValueKey('heni-brand-drag-region'),
            width: compact ? 52 : 68,
            height: double.infinity,
            child: const Align(
              alignment: Alignment.centerLeft,
              child: HeniBrandWordmark(),
            ),
          ),
        ),
        SizedBox(width: compact ? 2 : 4),
        Semantics(
          button: true,
          label: tooltip,
          child: Tooltip(
            message: tooltip,
            child: IconButton(
              key: const ValueKey('heni-view-switch-button'),
              onPressed: onToggleView,
              style: ButtonStyle(
                fixedSize: WidgetStatePropertyAll(
                  Size.square(compact ? 32 : 34),
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused)) {
                    return shellTheme.primaryText;
                  }
                  return shellTheme.secondaryText;
                }),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.pressed)) {
                    return shellTheme.pressed;
                  }
                  if (states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused)) {
                    return shellTheme.hover;
                  }
                  return Colors.white.withValues(alpha: 0.025);
                }),
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 190),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.18),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Icon(
                  icon,
                  key: ValueKey(activeView),
                  size: compact ? 17 : 18,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class HeniTopChromeCenter extends StatelessWidget {
  const HeniTopChromeCenter({required this.search, super.key});

  static const dragSpacerBreakpoint = 720.0;
  static const searchMaxWidth = 640.0;
  static const minimumDragWidth = 84.0;
  static const searchToDragGap = 12.0;

  final Widget search;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        if (available < dragSpacerBreakpoint) {
          return SizedBox(width: available, child: search);
        }

        final searchWidth =
            (available - minimumDragWidth - searchToDragGap)
                .clamp(0.0, searchMaxWidth)
                .toDouble();
        return Row(
          children: [
            SizedBox(width: searchWidth, child: search),
            const SizedBox(width: searchToDragGap),
            const Expanded(
              child: HeniWindowDragRegion(
                key: ValueKey('heni-top-chrome-drag-spacer'),
                child: SizedBox.expand(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class HeniWindowControls extends ConsumerWidget {
  const HeniWindowControls({required this.shellTheme, super.key});

  final HeniShellTheme shellTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maximized = ref.watch(heniWindowControllerProvider);
    final controller = ref.read(heniWindowControllerProvider.notifier);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowControlButton(
          tooltip: '最小化',
          icon: Icons.minimize_rounded,
          shellTheme: shellTheme,
          onPressed: () => unawaited(controller.minimize()),
        ),
        _WindowControlButton(
          tooltip: maximized ? '还原' : '最大化',
          icon:
              maximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
          shellTheme: shellTheme,
          onPressed: () => unawaited(controller.toggleMaximize()),
        ),
        _WindowControlButton(
          tooltip: '关闭',
          icon: Icons.close_rounded,
          shellTheme: shellTheme,
          destructive: true,
          onPressed: () async {
            final closed = await controller.close();
            if (!closed && context.mounted) {
              ScaffoldMessenger.maybeOf(
                context,
              )?.showSnackBar(const SnackBar(content: Text('窗口暂时无法关闭')));
            }
          },
        ),
      ],
    );
  }
}

class _WindowControlButton extends StatefulWidget {
  const _WindowControlButton({
    required this.tooltip,
    required this.icon,
    required this.shellTheme,
    required this.onPressed,
    this.destructive = false,
  });

  final String tooltip;
  final IconData icon;
  final HeniShellTheme shellTheme;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  var _hovered = false;
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _pressed;
    final fill =
        widget.destructive && active
            ? const Color(0xFFC84E5A).withValues(alpha: _pressed ? 0.94 : 0.82)
            : active
            ? _pressed
                ? widget.shellTheme.pressed
                : widget.shellTheme.hover
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) {
        setState(() {
          _hovered = false;
          _pressed = false;
        });
      },
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            width: 42,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              widget.icon,
              size: widget.icon == Icons.minimize_rounded ? 17 : 15,
              color:
                  active
                      ? widget.shellTheme.primaryText
                      : widget.shellTheme.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}
