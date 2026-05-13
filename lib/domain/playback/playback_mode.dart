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
      HeniRepeatMode.none => 'No repeat',
      HeniRepeatMode.all => 'Repeat all',
      HeniRepeatMode.one => 'Repeat one',
    };
  }
}

enum PlaybackAdvance {
  user,
  automatic,
}
