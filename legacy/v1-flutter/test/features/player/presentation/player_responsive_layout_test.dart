import 'package:flutter_test/flutter_test.dart';
import 'package:heni/features/player/presentation/player_responsive_layout.dart';

void main() {
  test('uses the compact bottom bar for short desktop windows', () {
    expect(
      shouldUseCompactBottomBar(
        windowWidth: 1280,
        focusMode: false,
        verticallyDense: true,
      ),
      isTrue,
    );
  });

  test('keeps the full bottom bar for a spacious desktop window', () {
    expect(
      shouldUseCompactBottomBar(
        windowWidth: 1440,
        focusMode: false,
        verticallyDense: false,
      ),
      isFalse,
    );
  });

  test('switches bottom layout at the 1180 logical-pixel boundary', () {
    expect(
      shouldUseCompactBottomBar(
        windowWidth: 1179,
        focusMode: false,
        verticallyDense: false,
      ),
      isTrue,
    );
    expect(
      shouldUseCompactBottomBar(
        windowWidth: 1180,
        focusMode: false,
        verticallyDense: false,
      ),
      isFalse,
    );
  });
}
