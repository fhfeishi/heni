import 'package:heni/features/player/presentation/desktop_multi_selection.dart';
import 'package:test/test.dart';

void main() {
  const keys = ['alpha', 'beta', 'gamma', 'delta', 'epsilon'];

  test('plain click replaces the selection and moves the anchor', () {
    const initial = DesktopMultiSelection(selectedKeys: {'alpha', 'beta'});

    final next = initial.select(
      orderedKeys: keys,
      index: 2,
      intent: DesktopSelectionIntent.replace,
    );

    expect(next.selectedKeys, {'gamma'});
    expect(next.anchorIndex, 2);
  });

  test('toggle click adds and removes individual entries', () {
    const initial = DesktopMultiSelection(selectedKeys: {'alpha'});

    final added = initial.select(
      orderedKeys: keys,
      index: 1,
      intent: DesktopSelectionIntent.toggle,
    );
    final removed = added.select(
      orderedKeys: keys,
      index: 0,
      intent: DesktopSelectionIntent.toggle,
    );

    expect(added.selectedKeys, {'alpha', 'beta'});
    expect(removed.selectedKeys, {'beta'});
  });

  test('shift range selection works in both directions', () {
    final anchored = const DesktopMultiSelection().select(
      orderedKeys: keys,
      index: 3,
      intent: DesktopSelectionIntent.replace,
    );
    final ranged = anchored.select(
      orderedKeys: keys,
      index: 1,
      intent: DesktopSelectionIntent.range,
    );

    expect(ranged.selectedKeys, {'beta', 'gamma', 'delta'});
    expect(ranged.anchorIndex, 3);
  });

  test('additive range keeps entries selected outside the range', () {
    final initial = const DesktopMultiSelection(
      selectedKeys: {'epsilon'},
    ).select(
      orderedKeys: keys,
      index: 0,
      intent: DesktopSelectionIntent.toggle,
    );
    final ranged = initial.select(
      orderedKeys: keys,
      index: 2,
      intent: DesktopSelectionIntent.additiveRange,
    );

    expect(ranged.selectedKeys, {'alpha', 'beta', 'gamma', 'epsilon'});
    expect(ranged.anchorIndex, 0);
  });

  test('range without a valid anchor behaves as a single selection', () {
    const initial = DesktopMultiSelection(
      selectedKeys: {'alpha'},
      anchorIndex: 99,
    );

    final next = initial.select(
      orderedKeys: keys,
      index: 2,
      intent: DesktopSelectionIntent.range,
    );

    expect(next.selectedKeys, {'gamma'});
    expect(next.anchorIndex, 2);
  });
}
