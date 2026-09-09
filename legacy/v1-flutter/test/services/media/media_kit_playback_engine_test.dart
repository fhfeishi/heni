import 'package:flutter_test/flutter_test.dart';
import 'package:heni/services/media/media_kit_playback_engine.dart';

void main() {
  test('uses a neutral playback configuration', () {
    expect(heniPlayerConfiguration.title, 'Heni');
    expect(heniPlayerConfiguration.osc, isFalse);
    expect(heniPlayerConfiguration.pitch, isFalse);
    expect(heniPlayerConfiguration.muted, isFalse);
    expect(heniPlayerConfiguration.vo, 'null');
  });
}
