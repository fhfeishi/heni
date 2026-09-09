import 'dart:io';

import '../../domain/media/media_item.dart';
import '../../domain/media/media_path.dart';

class LocalMediaScanner {
  const LocalMediaScanner();

  Future<List<MediaItem>> scanDirectory(
    String directoryPath, {
    bool recursive = true,
    bool includeVideo = true,
  }) async {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      throw const FileSystemException('Directory does not exist');
    }

    final items = <MediaItem>[];
    await for (final entity in directory.list(
      recursive: recursive,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }

      final path = entity.path;
      if (!isSupportedMediaPath(path, includeVideo: includeVideo)) {
        continue;
      }

      items.add(MediaItem.fromPath(path, kind: mediaKindFromPath(path)));
    }

    items.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    return List.unmodifiable(items);
  }
}
