import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:heni/domain/playback/playback_mode.dart';
import 'package:heni/domain/playback/playback_order.dart';

void main() {
  group('PlaybackOrder', () {
    test('linear order advances until it stops', () {
      var order = PlaybackOrder.linear(3);

      var move = order.next(HeniRepeatMode.none);
      expect(move.shouldPlay, isTrue);
      expect(move.index, 1);
      order = move.order!;

      move = order.next(HeniRepeatMode.none);
      expect(move.index, 2);
      order = move.order!;

      move = order.next(HeniRepeatMode.none);
      expect(move.shouldPlay, isFalse);
    });

    test('repeat all wraps to the beginning', () {
      final order = PlaybackOrder.linear(2, currentIndex: 1);

      final move = order.next(HeniRepeatMode.all);

      expect(move.shouldPlay, isTrue);
      expect(move.index, 0);
    });

    test('repeat one keeps the same item', () {
      final order = PlaybackOrder.linear(4, currentIndex: 2);

      final move = order.next(HeniRepeatMode.one);

      expect(move.shouldPlay, isTrue);
      expect(move.index, 2);
    });

    test('shuffle keeps the current item first', () {
      final order = PlaybackOrder.shuffled(
        5,
        currentIndex: 3,
        random: Random(1),
      );

      expect(order.currentIndex, 3);
      expect(order.indices.toSet(), {0, 1, 2, 3, 4});
    });
  });
}
