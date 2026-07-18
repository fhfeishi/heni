import 'package:flutter_test/flutter_test.dart';
import 'package:heni/domain/playback/playback_mode.dart';
import 'package:heni/services/storage/heni_library_store.dart';

void main() {
  group('HeniLibraryConfig sidebar preference', () {
    test('round trips the compact sidebar mode', () {
      final config = HeniLibraryConfig.fromJson(const {
        'sidebarMode': 'compact',
      });

      expect(config.sidebarModeName, 'compact');
      expect(config.toJson()['sidebarMode'], 'compact');
      expect(config.isEmpty, isFalse);
    });

    test('keeps a missing sidebar mode optional', () {
      final config = HeniLibraryConfig.fromJson(const {});

      expect(config.sidebarModeName, isNull);
      expect(config.isEmpty, isTrue);
    });
  });

  group('HeniLibraryConfig playback mode migration', () {
    test('round trips independent repeat and shuffle fields', () {
      final config = HeniLibraryConfig.fromJson(const {
        'repeatModeName': 'one',
        'shuffleEnabled': true,
      });

      expect(config.repeatMode, HeniRepeatMode.one);
      expect(config.resolvedShuffle, isTrue);
      expect(config.toJson()['repeatModeName'], 'one');
      expect(config.toJson()['shuffleEnabled'], isTrue);
    });

    test('migrates the legacy random playback mode', () {
      final config = HeniLibraryConfig.fromJson(const {
        'playbackModeName': 'random',
      });

      expect(config.repeatMode, HeniRepeatMode.all);
      expect(config.resolvedShuffle, isTrue);
    });

    test('invalid modern playback values fall back to sequence', () {
      final config = HeniLibraryConfig.fromJson(const {
        'repeatModeName': 'invalid',
        'shuffleEnabled': 'yes',
      });

      expect(config.repeatMode, HeniRepeatMode.none);
      expect(config.resolvedShuffle, isFalse);
    });
  });
}
