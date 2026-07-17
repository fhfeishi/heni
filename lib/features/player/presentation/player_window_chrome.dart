import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
