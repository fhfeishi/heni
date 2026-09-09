enum MediaKind {
  audio,
  video,
  image,
  subtitle,
  data,
  unknown;

  static MediaKind fromFfprobeCodecType(String? codecType) {
    return switch (codecType) {
      'audio' => MediaKind.audio,
      'video' => MediaKind.video,
      'subtitle' => MediaKind.subtitle,
      'data' => MediaKind.data,
      'attachment' => MediaKind.image,
      _ => MediaKind.unknown,
    };
  }
}
