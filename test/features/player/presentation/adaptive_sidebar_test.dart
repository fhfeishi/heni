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
            builder: (context, effectiveMode, widthForcedCompact) {
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

    await pump(width: 1000, preference: HeniSidebarMode.expanded);
    expect(find.text('compact:true'), findsOneWidget);

    await pump(width: 1090, preference: HeniSidebarMode.expanded);
    expect(find.text('compact:true'), findsOneWidget);

    await pump(width: 1180, preference: HeniSidebarMode.expanded);
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
          builder: (context, effectiveMode, widthForcedCompact) {
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
}
