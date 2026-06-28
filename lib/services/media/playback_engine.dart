import '../../domain/media/media_item.dart';

abstract interface class PlaybackEngine {
  Stream<bool> get completed;
  Stream<bool> get playing;
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<double> get volume;
  double get currentVolume;

  /// 当前是否正在播放的同步快照，用于界面重建时给 [playing] 流提供
  /// 正确的 initialData，避免重建后误显示为“未播放”。
  bool get currentPlaying;

  Future<void> openItem(MediaItem item, {bool play});
  Future<void> openPath(String path, {bool play});
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}
