import 'package:media_kit/media_kit.dart';

import '../../domain/media/media_item.dart';
import 'playback_engine.dart';

class MediaKitPlaybackEngine implements PlaybackEngine {
  MediaKitPlaybackEngine({Player? player}) : _player = player ?? Player();

  final Player _player;

  Player get player => _player;

  @override
  Stream<bool> get completed => _player.stream.completed;

  @override
  Stream<Duration> get duration => _player.stream.duration;

  @override
  Stream<bool> get playing => _player.stream.playing;

  @override
  Stream<Duration> get position => _player.stream.position;

  @override
  Stream<double> get volume => _player.stream.volume;

  @override
  Future<void> openPath(String path, {bool play = false}) {
    return _player.open(Media(path), play: play);
  }

  @override
  Future<void> openItem(MediaItem item, {bool play = false}) {
    return openPath(item.path, play: play);
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
