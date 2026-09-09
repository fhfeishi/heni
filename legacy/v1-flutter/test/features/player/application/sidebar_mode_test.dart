import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heni/features/player/application/sidebar_mode.dart';

void main() {
  group('sidebar preference', () {
    test('defaults to expanded and restores valid names', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(sidebarModeProvider), HeniSidebarMode.expanded);

      container
          .read(sidebarModeProvider.notifier)
          .restoreByName(HeniSidebarMode.compact.name);

      expect(container.read(sidebarModeProvider), HeniSidebarMode.compact);
    });

    test('falls back to expanded for an invalid persisted name', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(sidebarModeProvider.notifier).restoreByName('unknown');

      expect(container.read(sidebarModeProvider), HeniSidebarMode.expanded);
    });

    test('reports when persisted sidebar preferences finish restoring', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(sidebarPreferencesRestoredProvider), isFalse);

      container.read(sidebarPreferencesRestoredProvider.notifier).complete();

      expect(container.read(sidebarPreferencesRestoredProvider), isTrue);
    });
  });

  group('sidebar width policy', () {
    test('uses the initial cutoff when there is no prior responsive state', () {
      expect(
        resolveSidebarWidthForcedCompact(width: 1079, wasForcedCompact: null),
        isTrue,
      );
      expect(
        resolveSidebarWidthForcedCompact(width: 1080, wasForcedCompact: null),
        isFalse,
      );
    });

    test('enters compact at the lower threshold', () {
      expect(
        resolveSidebarWidthForcedCompact(width: 1040, wasForcedCompact: false),
        isTrue,
      );
      expect(
        resolveSidebarWidthForcedCompact(width: 1041, wasForcedCompact: false),
        isFalse,
      );
    });

    test('holds the previous state inside the hysteresis band', () {
      expect(
        resolveSidebarWidthForcedCompact(width: 1090, wasForcedCompact: true),
        isTrue,
      );
      expect(
        resolveSidebarWidthForcedCompact(width: 1090, wasForcedCompact: false),
        isFalse,
      );
    });

    test('leaves forced compact at the upper threshold', () {
      expect(
        resolveSidebarWidthForcedCompact(width: 1139, wasForcedCompact: true),
        isTrue,
      );
      expect(
        resolveSidebarWidthForcedCompact(width: 1140, wasForcedCompact: true),
        isFalse,
      );
    });

    test('uses client width at the shell inset release boundary', () {
      final policyWidth = resolveSidebarPolicyWidth(
        windowWidth: 1140,
        contentWidth: 1138,
      );

      expect(policyWidth, 1140);
      expect(
        resolveSidebarWidthForcedCompact(
          width: policyWidth,
          wasForcedCompact: true,
        ),
        isFalse,
      );
    });
  });
}
