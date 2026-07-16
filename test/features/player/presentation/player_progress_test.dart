import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heni/design/app_theme.dart';
import 'package:heni/domain/media/media_item.dart';
import 'package:heni/features/player/presentation/player_progress.dart';
import 'package:heni/services/media/playback_engine.dart';

void main() {
  testWidgets('narrow progress keeps the seek track without time overlap', (
    tester,
  ) async {
    final engine = _FakePlaybackEngine();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              child: PlayerProgressWithTime(
                engine: engine,
                palette: HeniPalette.cobalt,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('player-progress-track')), findsOneWidget);
    expect(find.text('00:30 / 04:00'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _FakePlaybackEngine implements PlaybackEngine {
  @override
  Stream<bool> get completed => const Stream.empty();

  @override
  double get currentVolume => 70;

  @override
  bool get currentPlaying => true;

  @override
  Stream<Duration> get duration => Stream.value(const Duration(minutes: 4));

  @override
  Stream<bool> get playing => Stream.value(true);

  @override
  Stream<Duration> get position => Stream.value(const Duration(seconds: 30));

  @override
  Stream<double> get volume => Stream.value(currentVolume);

  @override
  Future<void> dispose() async {}

  @override
  Future<void> openItem(MediaItem item, {bool play = false}) async {}

  @override
  Future<void> openPath(String path, {bool play = false}) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}
}
