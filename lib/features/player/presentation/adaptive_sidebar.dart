import 'package:flutter/material.dart';

import '../application/sidebar_mode.dart';

typedef HeniAdaptiveSidebarBuilder =
    Widget Function(
      BuildContext context,
      HeniSidebarMode effectiveMode,
      bool widthForcedCompact,
    );

class HeniAdaptiveSidebar extends StatefulWidget {
  const HeniAdaptiveSidebar({
    super.key,
    required this.availableWidth,
    required this.preference,
    required this.builder,
  });

  final double availableWidth;
  final HeniSidebarMode preference;
  final HeniAdaptiveSidebarBuilder builder;

  @override
  State<HeniAdaptiveSidebar> createState() => _HeniAdaptiveSidebarState();
}

class _HeniAdaptiveSidebarState extends State<HeniAdaptiveSidebar> {
  late bool _widthForcedCompact;

  @override
  void initState() {
    super.initState();
    _widthForcedCompact = resolveSidebarWidthForcedCompact(
      width: widget.availableWidth,
      wasForcedCompact: null,
    );
  }

  @override
  void didUpdateWidget(covariant HeniAdaptiveSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _widthForcedCompact = resolveSidebarWidthForcedCompact(
      width: widget.availableWidth,
      wasForcedCompact: _widthForcedCompact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveMode =
        _widthForcedCompact ? HeniSidebarMode.compact : widget.preference;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerLeft,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey(effectiveMode),
          child: widget.builder(context, effectiveMode, _widthForcedCompact),
        ),
      ),
    );
  }
}
