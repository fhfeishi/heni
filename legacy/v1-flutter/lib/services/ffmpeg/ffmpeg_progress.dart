class FfmpegProgress {
  const FfmpegProgress({
    required this.status,
    this.frame,
    this.fps,
    this.totalSizeBytes,
    this.outTime,
    this.bitrate,
    this.speedMultiplier,
  });

  factory FfmpegProgress.fromFields(Map<String, String> fields) {
    return FfmpegProgress(
      status: fields['progress'] ?? 'continue',
      frame: _tryParseInt(fields['frame']),
      fps: _tryParseDouble(fields['fps']),
      totalSizeBytes: _tryParseInt(fields['total_size']),
      outTime: _parseOutTime(fields),
      bitrate: fields['bitrate']?.trim(),
      speedMultiplier: _parseSpeed(fields['speed']),
    );
  }

  final String status;
  final int? frame;
  final double? fps;
  final int? totalSizeBytes;
  final Duration? outTime;
  final String? bitrate;
  final double? speedMultiplier;

  bool get isEnd => status == 'end';
}

class FfmpegProgressParser {
  final Map<String, String> _fields = {};

  FfmpegProgress? acceptLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final separator = trimmed.indexOf('=');
    if (separator <= 0) {
      return null;
    }

    final key = trimmed.substring(0, separator).trim();
    final value = trimmed.substring(separator + 1).trim();
    _fields[key] = value;

    if (key != 'progress') {
      return null;
    }

    final progress = FfmpegProgress.fromFields(_fields);
    _fields.clear();
    return progress;
  }
}

Duration? _parseOutTime(Map<String, String> fields) {
  final microseconds = _tryParseInt(fields['out_time_us']) ??
      _tryParseInt(fields['out_time_ms']);
  if (microseconds != null) {
    return Duration(microseconds: microseconds);
  }

  return _parseTimestamp(fields['out_time']);
}

Duration? _parseTimestamp(String? value) {
  if (value == null || value.isEmpty || value == 'N/A') {
    return null;
  }

  final parts = value.split(':');
  if (parts.length != 3) {
    return null;
  }

  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  final seconds = double.tryParse(parts[2]);
  if (hours == null || minutes == null || seconds == null) {
    return null;
  }

  return Duration(
    hours: hours,
    minutes: minutes,
    microseconds: (seconds * Duration.microsecondsPerSecond).round(),
  );
}

double? _parseSpeed(String? value) {
  if (value == null) {
    return null;
  }

  return _tryParseDouble(value.replaceAll('x', '').trim());
}

int? _tryParseInt(String? value) {
  if (value == null || value.isEmpty || value == 'N/A') {
    return null;
  }

  return int.tryParse(value.trim());
}

double? _tryParseDouble(String? value) {
  if (value == null || value.isEmpty || value == 'N/A') {
    return null;
  }

  return double.tryParse(value.trim());
}
