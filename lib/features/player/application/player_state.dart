import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/media/media_item.dart';
import '../../../domain/media/media_probe.dart';
import '../../../services/ffmpeg/media_inspector_provider.dart';

final currentMediaProvider = NotifierProvider<CurrentMedia, MediaItem?>(
  CurrentMedia.new,
);

final sceneryImagePathsProvider =
    NotifierProvider<SceneryImagePaths, List<String>>(
  SceneryImagePaths.new,
);

final currentMediaProbeProvider =
    NotifierProvider<CurrentMediaProbe, AsyncValue<MediaProbe?>>(
  CurrentMediaProbe.new,
);

class CurrentMedia extends Notifier<MediaItem?> {
  @override
  MediaItem? build() => null;

  void set(MediaItem? media) {
    state = media;
  }
}

class SceneryImagePaths extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void replaceAll(List<String> paths) {
    state = List.unmodifiable(paths);
  }
}

class CurrentMediaProbe extends Notifier<AsyncValue<MediaProbe?>> {
  @override
  AsyncValue<MediaProbe?> build() => const AsyncData(null);

  Future<void> inspect(String path) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(mediaInspectorProvider).inspectPath(path);
    });
  }

  void clear() {
    state = const AsyncData(null);
  }
}
