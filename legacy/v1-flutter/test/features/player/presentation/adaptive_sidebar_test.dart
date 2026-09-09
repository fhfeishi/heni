import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heni/features/player/application/sidebar_mode.dart';
import 'package:heni/features/player/presentation/adaptive_sidebar.dart';

void main() {
  testWidgets('adapts with hysteresis and restores expanded preference', (
    tester,
  ) async {
    Future<void> pump({
      required double width,
      required HeniSidebarMode preference,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HeniAdaptiveSidebar(
            availableWidth: width,
            preference: preference,
            preferencesRestored: false,
            requestExpandedWidth: () async => true,
            onPreferenceChanged: (_) {},
            builder: (context, effectiveMode, widthForcedCompact, selectMode) {
              return Text(
                '${effectiveMode.name}:$widthForcedCompact',
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      );
      await tester.pump();
    }

    await pump(width: 1280, preference: HeniSidebarMode.expanded);
    expect(find.text('expanded:false'), findsOneWidget);

    await pump(width: 1040, preference: HeniSidebarMode.expanded);
    expect(find.text('compact:true'), findsOneWidget);

    await pump(width: 1139, preference: HeniSidebarMode.expanded);
    expect(find.text('compact:true'), findsOneWidget);

    await pump(width: 1140, preference: HeniSidebarMode.expanded);
    expect(find.text('expanded:false'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps a manual compact preference at wide widths', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HeniAdaptiveSidebar(
          availableWidth: 1280,
          preference: HeniSidebarMode.compact,
          preferencesRestored: false,
          requestExpandedWidth: () async => true,
          onPreferenceChanged: (_) {},
          builder: (context, effectiveMode, widthForcedCompact, selectMode) {
            return Text(
              '${effectiveMode.name}:$widthForcedCompact',
              textDirection: TextDirection.ltr,
            );
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('compact:false'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disables sidebar transitions when system motion is reduced', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: HeniAdaptiveSidebar(
            availableWidth: 1280,
            preference: HeniSidebarMode.expanded,
            preferencesRestored: false,
            requestExpandedWidth: () async => true,
            onPreferenceChanged: (_) {},
            builder: (context, mode, forced, selectMode) => Text(mode.name),
          ),
        ),
      ),
    );

    expect(
      tester.widget<AnimatedSize>(find.byType(AnimatedSize)).duration,
      Duration.zero,
    );
    expect(
      tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
      Duration.zero,
    );
  });

  testWidgets('reconciles a restored expanded preference at startup', (
    tester,
  ) async {
    var resizeRequests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HeniAdaptiveSidebar(
          availableWidth: 900,
          preference: HeniSidebarMode.expanded,
          preferencesRestored: true,
          requestExpandedWidth: () async {
            resizeRequests++;
            return false;
          },
          onPreferenceChanged: (_) {},
          builder: (context, mode, forced, selectMode) {
            return Text('${mode.name}:$forced');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(resizeRequests, 1);
    expect(find.text('expanded:false'), findsOneWidget);
  });

  testWidgets('narrow compact mode can request explicit expansion', (
    tester,
  ) async {
    var resizeRequests = 0;
    HeniSidebarMode? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: HeniAdaptiveSidebar(
          availableWidth: 900,
          preference: HeniSidebarMode.compact,
          preferencesRestored: true,
          requestExpandedWidth: () async {
            resizeRequests++;
            return false;
          },
          onPreferenceChanged: (mode) => selected = mode,
          builder: (context, mode, forced, selectMode) {
            return Column(
              children: [
                Text('${mode.name}:$forced'),
                TextButton(
                  key: const ValueKey('request-sidebar-expansion'),
                  onPressed: () => selectMode(HeniSidebarMode.expanded),
                  child: const Text('expand'),
                ),
              ],
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('request-sidebar-expansion')));
    await tester.pumpAndSettle();

    expect(resizeRequests, 1);
    expect(selected, HeniSidebarMode.expanded);
    expect(find.text('expanded:false'), findsOneWidget);
  });
}
