import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HeniSidebarMode { expanded, compact }

final sidebarModeProvider =
    NotifierProvider<SidebarModeController, HeniSidebarMode>(
      SidebarModeController.new,
    );

class SidebarModeController extends Notifier<HeniSidebarMode> {
  @override
  HeniSidebarMode build() => HeniSidebarMode.expanded;

  void select(HeniSidebarMode mode) {
    state = mode;
  }

  void restoreByName(String? name) {
    state = HeniSidebarMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => HeniSidebarMode.expanded,
    );
  }
}

bool resolveSidebarWidthForcedCompact({
  required double width,
  required bool? wasForcedCompact,
}) {
  if (wasForcedCompact == null) {
    return width < 1148;
  }
  if (wasForcedCompact) {
    return width < 1180;
  }
  return width < 1148;
}
