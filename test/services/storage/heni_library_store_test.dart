import 'package:flutter_test/flutter_test.dart';
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
}
