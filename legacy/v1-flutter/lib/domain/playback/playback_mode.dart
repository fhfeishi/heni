enum HeniRepeatMode {
  none,
  all,
  one;

  HeniRepeatMode get next {
    return switch (this) {
      HeniRepeatMode.none => HeniRepeatMode.all,
      HeniRepeatMode.all => HeniRepeatMode.one,
      HeniRepeatMode.one => HeniRepeatMode.none,
    };
  }

  String get label {
    return switch (this) {
      HeniRepeatMode.none => '不循环',
      HeniRepeatMode.all => '列表循环',
      HeniRepeatMode.one => '单曲循环',
    };
  }
}

enum HeniPlaybackMode {
  /// Kept only so preferences written by older builds can still be read.
  sequence,
  listLoop,
  singleLoop,
  random;

  static const selectableValues = [listLoop, singleLoop, random];

  HeniPlaybackMode get normalized => switch (this) {
    HeniPlaybackMode.sequence => HeniPlaybackMode.listLoop,
    _ => this,
  };

  HeniPlaybackMode get next {
    return switch (this) {
      HeniPlaybackMode.sequence => HeniPlaybackMode.listLoop,
      HeniPlaybackMode.listLoop => HeniPlaybackMode.singleLoop,
      HeniPlaybackMode.singleLoop => HeniPlaybackMode.random,
      HeniPlaybackMode.random => HeniPlaybackMode.listLoop,
    };
  }

  String get label {
    return switch (this) {
      HeniPlaybackMode.sequence => '顺序播放',
      HeniPlaybackMode.listLoop => '列表循环',
      HeniPlaybackMode.singleLoop => '单曲循环',
      HeniPlaybackMode.random => '随机播放',
    };
  }

  HeniRepeatMode get repeatMode {
    return switch (this) {
      HeniPlaybackMode.sequence => HeniRepeatMode.none,
      HeniPlaybackMode.listLoop => HeniRepeatMode.all,
      HeniPlaybackMode.singleLoop => HeniRepeatMode.one,
      HeniPlaybackMode.random => HeniRepeatMode.all,
    };
  }

  bool get shuffle => this == HeniPlaybackMode.random;

  static HeniPlaybackMode fromState({
    required HeniRepeatMode repeatMode,
    required bool shuffle,
  }) {
    if (shuffle) {
      return HeniPlaybackMode.random;
    }

    return switch (repeatMode) {
      HeniRepeatMode.none => HeniPlaybackMode.listLoop,
      HeniRepeatMode.all => HeniPlaybackMode.listLoop,
      HeniRepeatMode.one => HeniPlaybackMode.singleLoop,
    };
  }
}

enum PlaybackAdvance { user, automatic }
