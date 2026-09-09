import 'package:flutter/material.dart';

class HeniRetainedViewStack extends StatelessWidget {
  const HeniRetainedViewStack({
    required this.activeIndex,
    required this.children,
    this.duration = const Duration(milliseconds: 200),
    super.key,
  }) : assert(children.length > 1),
       assert(activeIndex >= 0 && activeIndex < children.length);

  final int activeIndex;
  final List<Widget> children;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final effectiveDuration = reduceMotion ? Duration.zero : duration;

    return Stack(
      fit: StackFit.expand,
      children: [
        for (var index = 0; index < children.length; index++)
          _HeniRetainedViewPane(
            key: ValueKey('heni-retained-view-$index'),
            visible: index == activeIndex,
            hiddenOffset: Offset(index < activeIndex ? -0.018 : 0.018, 0),
            duration: effectiveDuration,
            child: children[index],
          ),
      ],
    );
  }
}

class _HeniRetainedViewPane extends StatelessWidget {
  const _HeniRetainedViewPane({
    required this.visible,
    required this.hiddenOffset,
    required this.duration,
    required this.child,
    super.key,
  });

  final bool visible;
  final Offset hiddenOffset;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : hiddenOffset,
          duration: duration,
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: duration,
            curve: Curves.easeOutCubic,
            child: TickerMode(enabled: visible, child: child),
          ),
        ),
      ),
    );
  }
}
