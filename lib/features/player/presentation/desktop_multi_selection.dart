enum DesktopSelectionIntent { replace, toggle, range, additiveRange }

class DesktopMultiSelection {
  const DesktopMultiSelection({
    this.selectedKeys = const <String>{},
    this.anchorIndex,
  });

  final Set<String> selectedKeys;
  final int? anchorIndex;

  DesktopMultiSelection select({
    required List<String> orderedKeys,
    required int index,
    required DesktopSelectionIntent intent,
  }) {
    if (index < 0 || index >= orderedKeys.length) {
      return this;
    }

    final key = orderedKeys[index];
    final next = <String>{...selectedKeys};

    switch (intent) {
      case DesktopSelectionIntent.replace:
        return DesktopMultiSelection(selectedKeys: {key}, anchorIndex: index);
      case DesktopSelectionIntent.toggle:
        if (!next.remove(key)) {
          next.add(key);
        }
        return DesktopMultiSelection(
          selectedKeys: Set.unmodifiable(next),
          anchorIndex: index,
        );
      case DesktopSelectionIntent.range:
      case DesktopSelectionIntent.additiveRange:
        final anchor = anchorIndex;
        if (anchor == null || anchor < 0 || anchor >= orderedKeys.length) {
          return DesktopMultiSelection(selectedKeys: {key}, anchorIndex: index);
        }

        final start = anchor < index ? anchor : index;
        final end = anchor > index ? anchor : index;
        final range = orderedKeys.sublist(start, end + 1);
        return DesktopMultiSelection(
          selectedKeys:
              intent == DesktopSelectionIntent.additiveRange
                  ? Set.unmodifiable({...next, ...range})
                  : Set.unmodifiable(range.toSet()),
          anchorIndex: anchor,
        );
    }
  }

  DesktopMultiSelection replaceWith(Iterable<String> keys) {
    return DesktopMultiSelection(selectedKeys: Set.unmodifiable(keys.toSet()));
  }

  DesktopMultiSelection resetAnchor() {
    return DesktopMultiSelection(selectedKeys: selectedKeys);
  }
}
