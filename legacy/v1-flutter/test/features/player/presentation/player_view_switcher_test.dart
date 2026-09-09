import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heni/features/player/presentation/player_view_switcher.dart';

void main() {
  testWidgets('switching views retains child state and blocks hidden input', (
    tester,
  ) async {
    final initCounts = <String, int>{};

    Widget app(int activeIndex) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 200,
            child: HeniRetainedViewStack(
              activeIndex: activeIndex,
              children: [
                _CounterProbe(
                  key: const ValueKey('probe-a-state'),
                  label: 'A',
                  onInit:
                      () => initCounts.update(
                        'A',
                        (count) => count + 1,
                        ifAbsent: () => 1,
                      ),
                ),
                _CounterProbe(
                  key: const ValueKey('probe-b-state'),
                  label: 'B',
                  onInit:
                      () => initCounts.update(
                        'B',
                        (count) => count + 1,
                        ifAbsent: () => 1,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(app(0));
    expect(initCounts, {'A': 1, 'B': 1});
    expect(
      tester
          .widget<IgnorePointer>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('heni-retained-view-1')),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('probe-a-button')));
    await tester.pump();
    expect(find.text('A:1'), findsOneWidget);

    await tester.pumpWidget(app(1));
    await tester.pump(const Duration(milliseconds: 220));
    expect(initCounts, {'A': 1, 'B': 1});
    expect(find.text('A:1'), findsOneWidget);
    expect(
      tester
          .widget<IgnorePointer>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('heni-retained-view-0')),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('probe-b-button')));
    await tester.pump();
    expect(find.text('B:1'), findsOneWidget);

    await tester.pumpWidget(app(0));
    await tester.pump(const Duration(milliseconds: 220));
    expect(initCounts, {'A': 1, 'B': 1});
    expect(find.text('A:1'), findsOneWidget);
    expect(find.text('B:1'), findsOneWidget);
  });

  testWidgets('reduced motion disables view transition duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: SizedBox(
            width: 400,
            height: 200,
            child: HeniRetainedViewStack(
              activeIndex: 0,
              children: const [Text('A'), Text('B')],
            ),
          ),
        ),
      ),
    );

    for (final opacity in tester.widgetList<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    )) {
      expect(opacity.duration, Duration.zero);
    }
    for (final slide in tester.widgetList<AnimatedSlide>(
      find.byType(AnimatedSlide),
    )) {
      expect(slide.duration, Duration.zero);
    }
  });
}

class _CounterProbe extends StatefulWidget {
  const _CounterProbe({required this.label, required this.onInit, super.key});

  final String label;
  final VoidCallback onInit;

  @override
  State<_CounterProbe> createState() => _CounterProbeState();
}

class _CounterProbeState extends State<_CounterProbe> {
  var _count = 0;

  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton(
        key: ValueKey('probe-${widget.label.toLowerCase()}-button'),
        onPressed: () => setState(() => _count += 1),
        child: Text('${widget.label}:$_count'),
      ),
    );
  }
}
