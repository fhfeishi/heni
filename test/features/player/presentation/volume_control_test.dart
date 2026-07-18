import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heni/design/app_theme.dart';
import 'package:heni/design/heni_shell_theme.dart';
import 'package:heni/domain/media/media_item.dart';
import 'package:heni/features/player/presentation/volume_control.dart';
import 'package:heni/services/media/playback_engine.dart';

void main() {
  test('mute target uses durable audible memory and a safe fallback', () {
    expect(resolveMuteTarget(current: 70, lastAudible: 55), 0);
    expect(resolveMuteTarget(current: 0, lastAudible: 55), 55);
    expect(resolveMuteTarget(current: 0, lastAudible: 0), 60);
  });

  testWidgets('inline volume updates live and commits when interaction ends', (
    tester,
  ) async {
    final engine = FakePlaybackEngine(volume: 70);
    addTearDown(engine.dispose);
    final committed = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeniVolumeControl(
            engine: engine,
            palette: HeniPalette.nocturne,
            shellTheme: HeniShellTheme.fromPalette(HeniPalette.nocturne),
            lastAudibleVolume: 64,
            onVolumeCommitted: committed.add,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('heni-volume-slider')), findsOneWidget);
    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('heni-volume-slider')),
    );
    slider.onChanged!(35);
    await tester.pump();
    expect(engine.currentVolume, 35);
    expect(committed, isEmpty);

    slider.onChangeEnd!(35);
    expect(committed, [35]);
  });

  testWidgets('mute restores the last audible volume', (tester) async {
    final engine = FakePlaybackEngine(volume: 0);
    addTearDown(engine.dispose);
    final committed = <double>[];
    await pumpVolumeControl(
      tester,
      engine,
      lastAudibleVolume: 64,
      onVolumeCommitted: committed.add,
    );

    await tester.tap(find.byTooltip('恢复音量'));
    await tester.pump();
    expect(engine.currentVolume, 64);
    await tester.tap(find.byTooltip('静音'));
    await tester.pump();
    expect(engine.currentVolume, 0);
    expect(committed, [64, 0]);
  });

  testWidgets('wheel and arrow keys adjust volume in desktop-sized steps', (
    tester,
  ) async {
    final engine = FakePlaybackEngine(volume: 50);
    addTearDown(engine.dispose);
    final committed = <double>[];
    await pumpVolumeControl(
      tester,
      engine,
      lastAudibleVolume: 50,
      onVolumeCommitted: committed.add,
    );

    final shell = find.byKey(const ValueKey('heni-volume-shell'));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(shell),
        scrollDelta: const Offset(0, -20),
      ),
    );
    await tester.pump();
    expect(engine.currentVolume, 52);

    final focus = tester.widget<Focus>(
      find.byKey(const ValueKey('heni-volume-focus')),
    );
    focus.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(engine.currentVolume, 57);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(engine.currentVolume, 52);
  });
}

class FakePlaybackEngine implements PlaybackEngine {
  FakePlaybackEngine({required double volume}) : _volume = volume;

  final _volumeController = StreamController<double>.broadcast();
  double _volume;

  @override
  double get currentVolume => _volume;

  @override
  Stream<double> get volume => _volumeController.stream;

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
    _volumeController.add(volume);
  }

  @override
  Stream<bool> get completed => const Stream.empty();

  @override
  bool get currentPlaying => false;

  @override
  Stream<Duration> get duration => const Stream.empty();

  @override
  Stream<bool> get playing => const Stream.empty();

  @override
  Stream<Duration> get position => const Stream.empty();

  @override
  Future<void> dispose() => _volumeController.close();

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
  Future<void> stop() async {}
}

Future<void> pumpVolumeControl(
  WidgetTester tester,
  FakePlaybackEngine engine, {
  double lastAudibleVolume = 60,
  ValueChanged<double>? onVolumeCommitted,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HeniVolumeControl(
          engine: engine,
          palette: HeniPalette.nocturne,
          shellTheme: HeniShellTheme.fromPalette(HeniPalette.nocturne),
          lastAudibleVolume: lastAudibleVolume,
          onVolumeCommitted: onVolumeCommitted ?? (_) {},
        ),
      ),
    ),
  );
}
