import 'dart:async';

import 'package:media_kit/media_kit.dart';

import '../../domain/media/media_item.dart';
import 'playback_engine.dart';

const heniPlayerConfiguration = PlayerConfiguration(
  title: 'Heni',
  osc: false,
  pitch: false,
  muted: false,
  vo: 'null',
);

class MediaKitPlaybackEngine implements PlaybackEngine {
  MediaKitPlaybackEngine({Player? player})
    : _player = player ?? Player(configuration: heniPlayerConfiguration) {
    _currentVolume = _player.state.volume.clamp(0, 100).toDouble();
    _volumeSubscription = _player.stream.volume.listen((volume) {
      _currentVolume = volume.clamp(0, 100).toDouble();
    });
  }

  final Player _player;
  late double _currentVolume;
  StreamSubscription<double>? _volumeSubscription;

  Player get player => _player;

  @override
  Stream<bool> get completed => _player.stream.completed;

  @override
  Duration get currentDuration => _player.state.duration;

  @override
  Duration get currentPosition => _player.state.position;

  @override
  Stream<Duration> get duration => _player.stream.duration;

  @override
  Stream<bool> get playing => _player.stream.playing;

  @override
  Stream<Duration> get position => _player.stream.position;

  @override
  Stream<double> get volume => _player.stream.volume;

  @override
  double get currentVolume => _currentVolume;

  @override
  bool get currentPlaying => _player.state.playing;

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
  Future<void> setVolume(double volume) {
    final nextVolume = volume.clamp(0, 100).toDouble();
    _currentVolume = nextVolume;
    return _player.setVolume(nextVolume);
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    await _volumeSubscription?.cancel();
    await _player.dispose();
  }
}
