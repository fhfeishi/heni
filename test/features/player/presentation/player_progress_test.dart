import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heni/design/app_theme.dart';
import 'package:heni/domain/media/media_item.dart';
import 'package:heni/features/player/presentation/player_progress.dart';
import 'package:heni/services/media/playback_engine.dart';

void main() {
  test('fallback duration drives every progress calculation', () {
    final snapshot = resolvePlayerProgressSnapshot(
      streamedPosition: const Duration(seconds: 30),
      streamedDuration: Duration.zero,
      enginePosition: const Duration(seconds: 29),
      engineDuration: Duration.zero,
      fallbackDuration: const Duration(minutes: 4),
    );

    expect(snapshot.position, const Duration(seconds: 30));
    expect(snapshot.total, const Duration(minutes: 4));
    expect(snapshot.fraction, closeTo(0.125, 0.0001));
    expect(snapshot.canSeek, isTrue);
  });

  test('unknown duration never creates a synthetic seek range', () {
    final snapshot = resolvePlayerProgressSnapshot(
      streamedPosition: const Duration(seconds: 30),
      streamedDuration: Duration.zero,
      enginePosition: const Duration(seconds: 30),
      engineDuration: Duration.zero,
      fallbackDuration: null,
    );

    expect(snapshot.totalKnown, isFalse);
    expect(snapshot.position, const Duration(seconds: 30));
    expect(snapshot.fraction, 0);
    expect(snapshot.canSeek, isFalse);
  });

  test('position is clamped to a known duration', () {
    final snapshot = resolvePlayerProgressSnapshot(
      streamedPosition: const Duration(minutes: 8),
      streamedDuration: const Duration(minutes: 4),
      enginePosition: Duration.zero,
      engineDuration: Duration.zero,
      fallbackDuration: null,
    );

    expect(snapshot.position, const Duration(minutes: 4));
    expect(snapshot.fraction, 1);
  });

  testWidgets('progress chooses wide compact and narrow layouts', (
    tester,
  ) async {
    final engine = _FakePlaybackEngine();
    addTearDown(engine.dispose);

    await _pumpProgress(tester, engine, width: 320);
    expect(find.byKey(const ValueKey('player-progress-wide')), findsOneWidget);

    await _pumpProgress(tester, engine, width: 220);
    expect(
      find.byKey(const ValueKey('player-progress-compact')),
      findsOneWidget,
    );

    await _pumpProgress(tester, engine, width: 140);
    expect(
      find.byKey(const ValueKey('player-progress-narrow')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('player-progress-track')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing media clears the previous progress snapshot', (
    tester,
  ) async {
    final engine = _FakePlaybackEngine();
    addTearDown(engine.dispose);

    await _pumpProgress(tester, engine, width: 320, mediaId: 'track-a');
    expect(find.text('00:30'), findsOneWidget);

    engine
      ..currentPositionValue = Duration.zero
      ..currentDurationValue = Duration.zero;
    await _pumpProgress(
      tester,
      engine,
      width: 320,
      mediaId: 'track-b',
      fallbackDuration: null,
    );
    await tester.pump();

    expect(find.text('00:30'), findsNothing);
    expect(find.text('--:--'), findsOneWidget);
  });

  testWidgets('drag preview ignores stream updates and seeks once on release', (
    tester,
  ) async {
    final engine = _FakePlaybackEngine();
    addTearDown(engine.dispose);
    await _pumpProgress(tester, engine, width: 320);

    final track = tester.getRect(
      find.byKey(const ValueKey('player-progress-track')),
    );
    final gesture = await tester.startGesture(
      Offset(track.left + track.width * 0.25, track.center.dy),
    );
    await gesture.moveTo(Offset(track.center.dx, track.center.dy));
    await tester.pump();
    engine.emitPosition(const Duration(seconds: 10));
    await tester.pump();

    expect(find.text('02:00'), findsWidgets);
    await gesture.up();
    await tester.pump();
    expect(engine.seeks, [const Duration(minutes: 2)]);
  });
}

Future<void> _pumpProgress(
  WidgetTester tester,
  _FakePlaybackEngine engine, {
  required double width,
  String mediaId = 'track-a',
  Duration? fallbackDuration = const Duration(minutes: 4),
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: PlayerProgressWithTime(
              engine: engine,
              palette: HeniPalette.cobalt,
              mediaId: mediaId,
              fallbackDuration: fallbackDuration,
            ),
          ),
        ),
      ),
    ),
  );
}

class _FakePlaybackEngine implements PlaybackEngine {
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final seeks = <Duration>[];

  Duration currentPositionValue = const Duration(seconds: 30);
  Duration currentDurationValue = const Duration(minutes: 4);

  void emitPosition(Duration value) {
    currentPositionValue = value;
    _positionController.add(value);
  }

  @override
  Stream<bool> get completed => const Stream.empty();

  @override
  Duration get currentDuration => currentDurationValue;

  @override
  Duration get currentPosition => currentPositionValue;

  @override
  double get currentVolume => 70;

  @override
  bool get currentPlaying => true;

  @override
  Stream<Duration> get duration => _durationController.stream;

  @override
  Stream<bool> get playing => Stream.value(true);

  @override
  Stream<Duration> get position => _positionController.stream;

  @override
  Stream<double> get volume => Stream.value(currentVolume);

  @override
  Future<void> dispose() async {
    await _positionController.close();
    await _durationController.close();
  }

  @override
  Future<void> openItem(MediaItem item, {bool play = false}) async {}

  @override
  Future<void> openPath(String path, {bool play = false}) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}
}
