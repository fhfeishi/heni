import 'dart:math';

import 'playback_mode.dart';

class PlaybackOrder {
  const PlaybackOrder({
    required this.indices,
    required this.position,
  });

  factory PlaybackOrder.linear(int length, {int currentIndex = 0}) {
    return PlaybackOrder(
      indices: [for (var index = 0; index < length; index += 1) index],
      position: length == 0 ? -1 : currentIndex.clamp(0, length - 1),
    );
  }

  factory PlaybackOrder.shuffled(
    int length, {
    required int currentIndex,
    Random? random,
  }) {
    if (length == 0) {
      return const PlaybackOrder(indices: [], position: -1);
    }

    final safeCurrent = currentIndex.clamp(0, length - 1);
    final rest = [
      for (var index = 0; index < length; index += 1)
        if (index != safeCurrent) index,
    ];
    rest.shuffle(random);

    return PlaybackOrder(indices: [safeCurrent, ...rest], position: 0);
  }

  final List<int> indices;
  final int position;

  int? get currentIndex {
    if (position < 0 || position >= indices.length) {
      return null;
    }
    return indices[position];
  }

  PlaybackOrder copyWith({
    List<int>? indices,
    int? position,
  }) {
    return PlaybackOrder(
      indices: indices ?? this.indices,
      position: position ?? this.position,
    );
  }

  PlaybackOrder rebuild({
    required int length,
    required int currentIndex,
    required bool shuffle,
    Random? random,
  }) {
    if (shuffle) {
      return PlaybackOrder.shuffled(
        length,
        currentIndex: currentIndex,
        random: random,
      );
    }

    return PlaybackOrder.linear(length, currentIndex: currentIndex);
  }

  PlaybackOrderMove next(HeniRepeatMode repeatMode) {
    if (indices.isEmpty || currentIndex == null) {
      return const PlaybackOrderMove.stop();
    }

    if (repeatMode == HeniRepeatMode.one) {
      return PlaybackOrderMove.play(copyWith(), currentIndex!);
    }

    final nextPosition = position + 1;
    if (nextPosition < indices.length) {
      return PlaybackOrderMove.play(
        copyWith(position: nextPosition),
        indices[nextPosition],
      );
    }

    if (repeatMode == HeniRepeatMode.all) {
      return PlaybackOrderMove.play(copyWith(position: 0), indices.first);
    }

    return const PlaybackOrderMove.stop();
  }

  PlaybackOrderMove previous(HeniRepeatMode repeatMode) {
    if (indices.isEmpty || currentIndex == null) {
      return const PlaybackOrderMove.stop();
    }

    final previousPosition = position - 1;
    if (previousPosition >= 0) {
      return PlaybackOrderMove.play(
        copyWith(position: previousPosition),
        indices[previousPosition],
      );
    }

    if (repeatMode == HeniRepeatMode.all) {
      return PlaybackOrderMove.play(
        copyWith(position: indices.length - 1),
        indices.last,
      );
    }

    return PlaybackOrderMove.play(copyWith(position: position), currentIndex!);
  }
}

class PlaybackOrderMove {
  const PlaybackOrderMove._({
    required this.shouldPlay,
    this.order,
    this.index,
  });

  const PlaybackOrderMove.stop()
      : this._(shouldPlay: false);

  const PlaybackOrderMove.play(PlaybackOrder order, int index)
      : this._(shouldPlay: true, order: order, index: index);

  final bool shouldPlay;
  final PlaybackOrder? order;
  final int? index;
}
