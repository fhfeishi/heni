import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'media_kit_playback_engine.dart';
import 'playback_engine.dart';

final mediaKitPlaybackEngineProvider = Provider<MediaKitPlaybackEngine>((ref) {
  final engine = MediaKitPlaybackEngine();
  ref.onDispose(engine.dispose);

  return engine;
});

final playbackEngineProvider = Provider<PlaybackEngine>((ref) {
  return ref.watch(mediaKitPlaybackEngineProvider);
});

final videoControllerProvider = Provider<VideoController>((ref) {
  final engine = ref.watch(mediaKitPlaybackEngineProvider);
  return VideoController(engine.player);
});
