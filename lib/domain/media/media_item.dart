import 'package:path/path.dart' as p;

import 'media_kind.dart';

class MediaItem {
  const MediaItem({
    required this.path,
    required this.title,
    required this.kind,
    this.duration,
  });

  factory MediaItem.fromPath(String path, {MediaKind kind = MediaKind.unknown}) {
    final basename = p.basenameWithoutExtension(path);

    return MediaItem(path: path, title: basename, kind: kind);
  }

  final String path;
  final String title;
  final MediaKind kind;
  final Duration? duration;

  MediaItem copyWith({
    String? path,
    String? title,
    MediaKind? kind,
    Duration? duration,
  }) {
    return MediaItem(
      path: path ?? this.path,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      duration: duration ?? this.duration,
    );
  }
}
