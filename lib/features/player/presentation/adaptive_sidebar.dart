import 'dart:async';

import 'package:flutter/material.dart';

import '../application/sidebar_mode.dart';

typedef HeniSidebarModeCallback = Future<void> Function(HeniSidebarMode mode);
typedef HeniAdaptiveSidebarBuilder =
    Widget Function(
      BuildContext context,
      HeniSidebarMode effectiveMode,
      bool widthForcedCompact,
      HeniSidebarModeCallback selectMode,
    );

class HeniAdaptiveSidebar extends StatefulWidget {
  const HeniAdaptiveSidebar({
    super.key,
    required this.availableWidth,
    required this.preference,
    required this.preferencesRestored,
    required this.requestExpandedWidth,
    required this.onPreferenceChanged,
    required this.builder,
  });

  final double availableWidth;
  final HeniSidebarMode preference;
  final bool preferencesRestored;
  final Future<bool> Function() requestExpandedWidth;
  final ValueChanged<HeniSidebarMode> onPreferenceChanged;
  final HeniAdaptiveSidebarBuilder builder;

  @override
  State<HeniAdaptiveSidebar> createState() => _HeniAdaptiveSidebarState();
}

class _HeniAdaptiveSidebarState extends State<HeniAdaptiveSidebar> {
  late bool _widthForcedCompact;
  bool _narrowExpandedOverride = false;
  bool _resizeInProgress = false;
  bool _startupReconciled = false;
  bool _startupReconcileScheduled = false;

  @override
  void initState() {
    super.initState();
    _widthForcedCompact = resolveSidebarWidthForcedCompact(
      width: widget.availableWidth,
      wasForcedCompact: null,
    );
    _scheduleStartupReconciliation();
  }

  @override
  void didUpdateWidget(covariant HeniAdaptiveSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _widthForcedCompact = resolveSidebarWidthForcedCompact(
      width: widget.availableWidth,
      wasForcedCompact: _widthForcedCompact,
    );
    if (!_widthForcedCompact || widget.preference == HeniSidebarMode.compact) {
      _narrowExpandedOverride = false;
    }
    _scheduleStartupReconciliation();
  }

  void _scheduleStartupReconciliation() {
    if (_startupReconciled ||
        _startupReconcileScheduled ||
        !widget.preferencesRestored) {
      return;
    }
    if (widget.preference == HeniSidebarMode.compact || !_widthForcedCompact) {
      _startupReconciled = true;
      return;
    }

    _startupReconcileScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_reconcileStartup());
    });
  }

  Future<void> _reconcileStartup() async {
    _startupReconcileScheduled = false;
    if (_startupReconciled ||
        !widget.preferencesRestored ||
        widget.preference != HeniSidebarMode.expanded ||
        !_widthForcedCompact) {
      _startupReconciled = true;
      return;
    }

    _startupReconciled = true;
    final reached = await _requestExpandedWidth();
    if (!mounted) {
      return;
    }
    setState(() {
      _narrowExpandedOverride = !reached;
    });
  }

  Future<bool> _requestExpandedWidth() async {
    if (_resizeInProgress) {
      return false;
    }
    setState(() => _resizeInProgress = true);
    var reached = false;
    try {
      reached = await widget.requestExpandedWidth();
    } catch (_) {
      reached = false;
    }
    if (mounted) {
      setState(() => _resizeInProgress = false);
    }
    return reached;
  }

  Future<void> _selectMode(HeniSidebarMode mode) async {
    _startupReconciled = true;
    if (mode == HeniSidebarMode.compact) {
      if (_narrowExpandedOverride) {
        setState(() => _narrowExpandedOverride = false);
      }
      widget.onPreferenceChanged(mode);
      return;
    }
    if (_resizeInProgress) {
      return;
    }
    if (_widthForcedCompact) {
      final reached = await _requestExpandedWidth();
      if (!mounted) {
        return;
      }
      setState(() {
        _narrowExpandedOverride = !reached;
      });
    }
    widget.onPreferenceChanged(HeniSidebarMode.expanded);
  }

  @override
  Widget build(BuildContext context) {
    final presentationForcedCompact =
        _widthForcedCompact && !_narrowExpandedOverride;
    final effectiveMode =
        _narrowExpandedOverride
            ? HeniSidebarMode.expanded
            : presentationForcedCompact
            ? HeniSidebarMode.compact
            : widget.preference;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final sizeDuration =
        disableAnimations ? Duration.zero : const Duration(milliseconds: 240);
    final switchDuration =
        disableAnimations ? Duration.zero : const Duration(milliseconds: 180);

    return AnimatedSize(
      duration: sizeDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerLeft,
      child: AnimatedSwitcher(
        duration: switchDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey(effectiveMode),
          child: widget.builder(
            context,
            effectiveMode,
            presentationForcedCompact,
            _selectMode,
          ),
        ),
      ),
    );
  }
}
