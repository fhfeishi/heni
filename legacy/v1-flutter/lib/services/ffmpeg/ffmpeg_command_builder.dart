enum StreamMode {
  /// Fast and lossless, but boundaries may align to packets or keyframes.
  copy,

  /// Slower and can change quality, but better for precise edit boundaries.
  reencode,
}

class FfmpegTrimRequest {
  const FfmpegTrimRequest({
    required this.inputPath,
    required this.outputPath,
    this.start,
    this.end,
    this.mode = StreamMode.copy,
    this.accurateSeek = false,
    this.overwrite = false,
  }) : assert(
         start != null || end != null,
         'A trim request needs at least a start or end.',
       );

  final String inputPath;
  final String outputPath;
  final Duration? start;
  final Duration? end;
  final StreamMode mode;

  /// Puts `-ss` after the input for more accurate seeking.
  ///
  /// This is most useful when `mode` is [StreamMode.reencode]. Stream copying is
  /// still constrained by packet and keyframe boundaries.
  final bool accurateSeek;
  final bool overwrite;
}

class FfmpegCommandBuilder {
  const FfmpegCommandBuilder._();

  static List<String> trim(FfmpegTrimRequest request) {
    final args = <String>[
      '-hide_banner',
      if (request.overwrite) '-y' else '-n',
    ];

    if (!request.accurateSeek && request.start != null) {
      args.addAll(['-ss', _formatTimestamp(request.start!)]);
    }

    args.addAll(['-i', request.inputPath]);

    if (request.accurateSeek && request.start != null) {
      args.addAll(['-ss', _formatTimestamp(request.start!)]);
    }

    if (_durationFromRange(request) case final Duration duration) {
      args.addAll(['-t', _formatTimestamp(duration)]);
    } else if (request.end != null) {
      args.addAll(['-to', _formatTimestamp(request.end!)]);
    }

    args.addAll(['-map', '0']);

    switch (request.mode) {
      case StreamMode.copy:
        args.addAll(['-c', 'copy', '-avoid_negative_ts', 'make_zero']);
      case StreamMode.reencode:
        args.addAll([
          '-c:v',
          'libx264',
          '-preset',
          'medium',
          '-crf',
          '20',
          '-c:a',
          'aac',
          '-b:a',
          '192k',
        ]);
    }

    args.add(request.outputPath);
    return args;
  }

  static String _formatTimestamp(Duration duration) {
    final totalMicroseconds = duration.inMicroseconds;
    final sign = totalMicroseconds < 0 ? '-' : '';
    final absolute = totalMicroseconds.abs();
    final hours = absolute ~/ Duration.microsecondsPerHour;
    final minutes =
        (absolute % Duration.microsecondsPerHour) ~/
        Duration.microsecondsPerMinute;
    final seconds =
        (absolute % Duration.microsecondsPerMinute) ~/
        Duration.microsecondsPerSecond;
    final milliseconds =
        (absolute % Duration.microsecondsPerSecond) ~/
        Duration.microsecondsPerMillisecond;

    String twoDigits(int value) => value.toString().padLeft(2, '0');
    String threeDigits(int value) => value.toString().padLeft(3, '0');

    return '$sign${twoDigits(hours)}:${twoDigits(minutes)}:'
        '${twoDigits(seconds)}.${threeDigits(milliseconds)}';
  }

  static Duration? _durationFromRange(FfmpegTrimRequest request) {
    final start = request.start;
    final end = request.end;
    if (start == null || end == null || end <= start) {
      return null;
    }

    return end - start;
  }
}
