import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HeniSidebarMode { expanded, compact }

const heniSidebarForceCompactWidth = 1040.0;
const heniSidebarInitialCompactWidth = 1080.0;
const heniSidebarExpandedSafeWidth = 1140.0;

final sidebarModeProvider =
    NotifierProvider<SidebarModeController, HeniSidebarMode>(
      SidebarModeController.new,
    );

final sidebarPreferencesRestoredProvider =
    NotifierProvider<SidebarPreferencesRestored, bool>(
      SidebarPreferencesRestored.new,
    );

class SidebarPreferencesRestored extends Notifier<bool> {
  @override
  bool build() => false;

  void complete() {
    state = true;
  }
}

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
    return width < heniSidebarInitialCompactWidth;
  }
  if (wasForcedCompact) {
    return width < heniSidebarExpandedSafeWidth;
  }
  return width <= heniSidebarForceCompactWidth;
}

double resolveSidebarPolicyWidth({
  required double windowWidth,
  required double contentWidth,
}) {
  return windowWidth > contentWidth ? windowWidth : contentWidth;
}
