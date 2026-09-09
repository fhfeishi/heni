import 'package:flutter_test/flutter_test.dart';
import 'package:heni/design/app_theme.dart';
import 'package:heni/design/heni_shell_theme.dart';

void main() {
  test('all palettes create translucent distinct shell layers', () {
    for (final palette in HeniPalette.all) {
      final shell = HeniShellTheme.fromPalette(palette);
      final layers =
          HeniShellSurfaceRole.values
              .map(shell.surfaceFor)
              .map((color) => color.toARGB32())
              .toSet();

      expect(shell.canvas.a, 1, reason: palette.name);
      expect(shell.chrome.a, inInclusiveRange(0.45, 0.70));
      expect(shell.rail.a, inInclusiveRange(0.30, 0.58));
      expect(shell.content.a, inInclusiveRange(0.36, 0.64));
      expect(shell.dock.a, inInclusiveRange(0.48, 0.72));
      expect(layers.length, HeniShellSurfaceRole.values.length);
      expect(shell.border.a, greaterThan(0.20));
      expect(shell.selected.a, greaterThan(shell.hover.a));
    }
  });

  test('shell colors change when the palette changes', () {
    final tide = HeniShellTheme.fromPalette(HeniPalette.tide);
    final ember = HeniShellTheme.fromPalette(HeniPalette.ember);

    expect(tide.border, isNot(ember.border));
    expect(tide.selected, isNot(ember.selected));
    expect(tide.chrome, isNot(ember.chrome));
  });
}
