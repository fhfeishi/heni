import 'package:path/path.dart' as p;

import 'media_kind.dart';

const audioExtensions = {
  'aac',
  'aiff',
  'alac',
  'flac',
  'm4a',
  'mp3',
  'ogg',
  'opus',
  'wav',
  'wma',
};

const videoExtensions = {
  'avi',
  'flv',
  'm4v',
  'mkv',
  'mov',
  'mp4',
  'mpeg',
  'mpg',
  'ts',
  'webm',
  'wmv',
};

String extensionOfPath(String path) {
  final extension = p.extension(path).toLowerCase();
  if (extension.startsWith('.')) {
    return extension.substring(1);
  }
  return extension;
}

bool isSupportedMediaPath(String path, {bool includeVideo = true}) {
  final extension = extensionOfPath(path);
  return audioExtensions.contains(extension) ||
      (includeVideo && videoExtensions.contains(extension));
}

MediaKind mediaKindFromPath(String path) {
  final extension = extensionOfPath(path);
  if (audioExtensions.contains(extension)) {
    return MediaKind.audio;
  }
  if (videoExtensions.contains(extension)) {
    return MediaKind.video;
  }
  return MediaKind.unknown;
}
