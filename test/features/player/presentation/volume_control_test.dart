import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heni/design/app_theme.dart';
import 'package:heni/design/heni_shell_theme.dart';
import 'package:heni/domain/media/media_item.dart';
import 'package:heni/features/player/presentation/volume_control.dart';
import 'package:heni/services/media/playback_engine.dart';

void main() {
  testWidgets('volume updates live and persists only when interaction ends', (
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
            onVolumeCommitted: committed.add,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('音量 70%'));
    await tester.pumpAndSettle();
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(35);
    await tester.pump();
    expect(engine.currentVolume, 35);
    expect(committed, isEmpty);

    slider.onChangeEnd!(35);
    expect(committed, [35]);
  });

  testWidgets('mute restores the last audible volume', (tester) async {
    final engine = FakePlaybackEngine(volume: 64);
    addTearDown(engine.dispose);
    await pumpVolumeControl(tester, engine);
    await tester.tap(find.byTooltip('音量 64%'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('静音'));
    await tester.pump();
    expect(engine.currentVolume, 0);
    await tester.tap(find.byTooltip('恢复音量'));
    await tester.pump();
    expect(engine.currentVolume, 64);
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

Future<void> pumpVolumeControl(WidgetTester tester, FakePlaybackEngine engine) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HeniVolumeControl(
          engine: engine,
          palette: HeniPalette.nocturne,
          shellTheme: HeniShellTheme.fromPalette(HeniPalette.nocturne),
          onVolumeCommitted: (_) {},
        ),
      ),
    ),
  );
}
