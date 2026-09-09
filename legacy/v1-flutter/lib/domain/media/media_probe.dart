import 'media_kind.dart';

class MediaProbe {
  const MediaProbe({
    required this.sourcePath,
    required this.streams,
    required this.chapters,
    required this.tags,
    this.formatName,
    this.formatLongName,
    this.duration,
    this.sizeBytes,
    this.bitRate,
  });

  factory MediaProbe.fromFfprobeJson(
    Map<String, Object?> json, {
    required String sourcePath,
  }) {
    final format = _asMap(json['format']);
    final streamValues = _asList(json['streams']);
    final chapterValues = _asList(json['chapters']);

    return MediaProbe(
      sourcePath: sourcePath,
      formatName: _asString(format['format_name']),
      formatLongName: _asString(format['format_long_name']),
      duration: _parseDuration(format['duration']),
      sizeBytes: _asInt(format['size']),
      bitRate: _asInt(format['bit_rate']),
      streams: streamValues
          .map(_asMap)
          .where((stream) => stream.isNotEmpty)
          .map(MediaStreamProbe.fromFfprobeJson)
          .toList(growable: false),
      chapters: chapterValues
          .map(_asMap)
          .where((chapter) => chapter.isNotEmpty)
          .map(MediaChapterProbe.fromFfprobeJson)
          .toList(growable: false),
      tags: _stringMap(format['tags']),
    );
  }

  final String sourcePath;
  final String? formatName;
  final String? formatLongName;
  final Duration? duration;
  final int? sizeBytes;
  final int? bitRate;
  final List<MediaStreamProbe> streams;
  final List<MediaChapterProbe> chapters;
  final Map<String, String> tags;

  bool get hasAudio => streams.any((stream) => stream.kind == MediaKind.audio);
  bool get hasVideo => streams.any((stream) => stream.kind == MediaKind.video);

  MediaKind get primaryKind {
    if (hasVideo) {
      return MediaKind.video;
    }
    if (hasAudio) {
      return MediaKind.audio;
    }
    return MediaKind.unknown;
  }

  MediaStreamProbe? get primaryAudioStream {
    for (final stream in streams) {
      if (stream.kind == MediaKind.audio) {
        return stream;
      }
    }
    return null;
  }

  MediaStreamProbe? get primaryVideoStream {
    for (final stream in streams) {
      if (stream.kind == MediaKind.video) {
        return stream;
      }
    }
    return null;
  }
}

class MediaStreamProbe {
  const MediaStreamProbe({
    required this.index,
    required this.kind,
    required this.tags,
    this.codecName,
    this.codecLongName,
    this.profile,
    this.width,
    this.height,
    this.sampleRate,
    this.channels,
    this.duration,
    this.frameRate,
    this.bitRate,
  });

  factory MediaStreamProbe.fromFfprobeJson(Map<String, Object?> json) {
    return MediaStreamProbe(
      index: _asInt(json['index']) ?? -1,
      kind: MediaKind.fromFfprobeCodecType(_asString(json['codec_type'])),
      codecName: _asString(json['codec_name']),
      codecLongName: _asString(json['codec_long_name']),
      profile: _asString(json['profile']),
      width: _asInt(json['width']),
      height: _asInt(json['height']),
      sampleRate: _asInt(json['sample_rate']),
      channels: _asInt(json['channels']),
      duration: _parseDuration(json['duration']),
      frameRate: Rational.tryParse(_asString(json['avg_frame_rate'])),
      bitRate: _asInt(json['bit_rate']),
      tags: _stringMap(json['tags']),
    );
  }

  final int index;
  final MediaKind kind;
  final String? codecName;
  final String? codecLongName;
  final String? profile;
  final int? width;
  final int? height;
  final int? sampleRate;
  final int? channels;
  final Duration? duration;
  final Rational? frameRate;
  final int? bitRate;
  final Map<String, String> tags;

  String? get displaySize {
    final width = this.width;
    final height = this.height;
    if (width == null || height == null) {
      return null;
    }
    return '${width}x$height';
  }
}

class MediaChapterProbe {
  const MediaChapterProbe({
    required this.id,
    required this.start,
    required this.end,
    required this.tags,
  });

  factory MediaChapterProbe.fromFfprobeJson(Map<String, Object?> json) {
    return MediaChapterProbe(
      id: _asInt(json['id']) ?? -1,
      start: _parseDuration(json['start_time']) ?? Duration.zero,
      end: _parseDuration(json['end_time']) ?? Duration.zero,
      tags: _stringMap(json['tags']),
    );
  }

  final int id;
  final Duration start;
  final Duration end;
  final Map<String, String> tags;
}

class Rational {
  const Rational(this.numerator, this.denominator);

  static Rational? tryParse(String? value) {
    if (value == null || value.isEmpty || value == '0/0') {
      return null;
    }

    final pieces = value.split('/');
    if (pieces.length != 2) {
      return null;
    }

    final numerator = int.tryParse(pieces[0]);
    final denominator = int.tryParse(pieces[1]);
    if (numerator == null || denominator == null || denominator == 0) {
      return null;
    }

    return Rational(numerator, denominator);
  }

  final int numerator;
  final int denominator;

  double get value => numerator / denominator;

  @override
  String toString() => '$numerator/$denominator';
}

Map<String, Object?> _asMap(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        if (entry.key case final String key) key: entry.value,
    };
  }
  return const {};
}

List<Object?> _asList(Object? value) {
  if (value is List) {
    return value.cast<Object?>();
  }
  return const [];
}

String? _asString(Object? value) {
  return switch (value) {
    final String text when text.isNotEmpty => text,
    final num number => number.toString(),
    _ => null,
  };
}

int? _asInt(Object? value) {
  return switch (value) {
    final int integer => integer,
    final double decimal => decimal.round(),
    final String text => int.tryParse(text),
    _ => null,
  };
}

Duration? _parseDuration(Object? value) {
  final seconds = switch (value) {
    final int integer => integer.toDouble(),
    final double decimal => decimal,
    final String text => double.tryParse(text),
    _ => null,
  };

  if (seconds == null) {
    return null;
  }

  return Duration(microseconds: (seconds * Duration.microsecondsPerSecond).round());
}

Map<String, String> _stringMap(Object? value) {
  final map = _asMap(value);
  if (map.isEmpty) {
    return const {};
  }

  return {
    for (final entry in map.entries)
      if (_asString(entry.value) case final String text) entry.key: text,
  };
}
