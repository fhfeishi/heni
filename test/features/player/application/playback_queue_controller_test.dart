import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heni/design/app_theme.dart';
import 'package:heni/domain/media/media_item.dart';
import 'package:heni/domain/media/media_kind.dart';
import 'package:heni/domain/media/media_probe.dart';
import 'package:heni/domain/playback/playback_mode.dart';
import 'package:heni/features/player/application/playback_queue_controller.dart';
import 'package:heni/features/player/application/sidebar_mode.dart';
import 'package:heni/services/ffmpeg/media_inspector.dart';
import 'package:heni/services/ffmpeg/media_inspector_provider.dart';
import 'package:heni/services/media/playback_engine.dart';
import 'package:heni/services/media/playback_providers.dart';
import 'package:heni/services/storage/heni_library_store.dart';

void main() {
  group('PlaybackQueueController', () {
    test('keeps the top songs tab distinct from the local library', () {
      final engine = _FakePlaybackEngine();
      final container = _container(engine);
      addTearDown(container.dispose);

      final state = container.read(playbackQueueControllerProvider);

      expect(HeniUiStyle.library.label, '歌曲');
      expect(state.library.name, '曲库');
    });

    test('reports a non-blocking shell status message', () {
      final engine = _FakePlaybackEngine();
      final container = _container(engine);
      addTearDown(container.dispose);

      container
          .read(playbackQueueControllerProvider.notifier)
          .reportStatus('已打开文件位置');

      final state = container.read(playbackQueueControllerProvider);
      expect(state.statusMessage, '已打开文件位置');
      expect(state.lastError, isNull);
    });

    test('previous and next follow the independent playback queue', () async {
      final engine = _FakePlaybackEngine();
      final container = _container(engine);
      addTearDown(container.dispose);

      final controller = container.read(
        playbackQueueControllerProvider.notifier,
      );
      await controller.addItems(_items, playFirst: true);

      await controller.playNext();
      await controller.playPrevious();

      expect(engine.opened.map((item) => item.title), ['A', 'B', 'A']);
    });

    test(
      'selecting or creating a playlist does not interrupt playback',
      () async {
        final engine = _FakePlaybackEngine();
        final container = _container(engine);
        addTearDown(container.dispose);

        final controller = container.read(
          playbackQueueControllerProvider.notifier,
        );
        await controller.addItems(_items, playFirst: true);
        await controller.createPlaylist('收藏');
        final stateAfterCreate = container.read(
          playbackQueueControllerProvider,
        );

        expect(stateAfterCreate.playlists.single.items, isEmpty);
        expect(stateAfterCreate.currentItem?.title, 'A');
        expect(engine.opened.map((item) => item.title), ['A']);

        controller.selectPlaylist(heniLibraryPlaylistId);
        final stateAfterSwitch = container.read(
          playbackQueueControllerProvider,
        );

        expect(stateAfterSwitch.activePlaylist.id, heniLibraryPlaylistId);
        expect(stateAfterSwitch.currentItem?.title, 'A');
        expect(engine.opened.map((item) => item.title), ['A']);
      },
    );

    test('adds library items to playlists as path references', () async {
      final engine = _FakePlaybackEngine();
      final store = _MemoryLibraryStore();
      final container = _container(engine, store: store);
      addTearDown(container.dispose);

      final controller = container.read(
        playbackQueueControllerProvider.notifier,
      );
      await controller.addItems(_items);
      await controller.createPlaylist('通勤');
      final playlistId =
          container.read(playbackQueueControllerProvider).playlists.single.id;

      controller.addItemToPlaylist(playlistId, _items[1]);

      final state = container.read(playbackQueueControllerProvider);
      expect(state.playlists.single.items.map((item) => item.path), [
        _items[1].path,
      ]);
      expect(store.latest?.playlists.single.itemPaths, [_items[1].path]);
    });

    test('renames playlists and persists descriptions', () async {
      final engine = _FakePlaybackEngine();
      final store = _MemoryLibraryStore();
      final container = _container(engine, store: store);
      addTearDown(container.dispose);

      final controller = container.read(
        playbackQueueControllerProvider.notifier,
      );
      await controller.createPlaylist('工作');
      final playlistId =
          container.read(playbackQueueControllerProvider).playlists.single.id;

      controller.renamePlaylist(playlistId, '夜跑');
      controller.updatePlaylistDescription(playlistId, '  晚上散步和跑步听  ');

      final state = container.read(playbackQueueControllerProvider);
      expect(state.playlists.single.name, '夜跑');
      expect(state.playlists.single.description, '晚上散步和跑步听');
      expect(store.latest?.playlists.single.name, '夜跑');
      expect(store.latest?.playlists.single.description, '晚上散步和跑步听');
    });

    test('persists playback mode across restore', () async {
      final engine = _FakePlaybackEngine();
      final store = _MemoryLibraryStore();
      final firstContainer = _container(engine, store: store);
      addTearDown(firstContainer.dispose);

      final firstController = firstContainer.read(
        playbackQueueControllerProvider.notifier,
      );
      firstController.setPlaybackMode(HeniPlaybackMode.random);

      expect(store.latest?.playbackModeName, HeniPlaybackMode.random.name);

      final restoredContainer = _container(_FakePlaybackEngine(), store: store);
      addTearDown(restoredContainer.dispose);
      restoredContainer.read(playbackQueueControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final restoredState = restoredContainer.read(
        playbackQueueControllerProvider,
      );
      expect(restoredState.playbackMode, HeniPlaybackMode.random);
      expect(restoredState.shuffle, isTrue);
      expect(restoredState.repeatMode, HeniRepeatMode.all);
    });

    test(
      'three playback modes cycle without changing the current track',
      () async {
        final engine = _FakePlaybackEngine();
        final store = _MemoryLibraryStore();
        final container = _container(engine, store: store);
        addTearDown(container.dispose);
        final controller = container.read(
          playbackQueueControllerProvider.notifier,
        );
        await controller.addItems(_items, playFirst: true);
        controller.setPlaybackMode(HeniPlaybackMode.listLoop);
        final currentPath =
            container.read(playbackQueueControllerProvider).currentItem?.path;

        controller.cyclePlaybackMode();

        var state = container.read(playbackQueueControllerProvider);
        expect(state.playbackMode, HeniPlaybackMode.singleLoop);
        expect(state.repeatMode, HeniRepeatMode.one);
        expect(state.shuffle, isFalse);
        expect(state.currentItem?.path, currentPath);

        controller.cyclePlaybackMode();

        state = container.read(playbackQueueControllerProvider);
        expect(state.playbackMode, HeniPlaybackMode.random);
        expect(state.repeatMode, HeniRepeatMode.all);
        expect(state.shuffle, isTrue);
        expect(state.currentItem?.path, currentPath);
        expect(store.latest?.playbackModeName, HeniPlaybackMode.random.name);
        expect(store.latest?.shuffleEnabled, isTrue);

        controller.cyclePlaybackMode();
        state = container.read(playbackQueueControllerProvider);
        expect(state.playbackMode, HeniPlaybackMode.listLoop);
        expect(state.currentItem?.path, currentPath);
      },
    );

    test('manual next still advances while single loop is active', () async {
      final container = _container(_FakePlaybackEngine());
      addTearDown(container.dispose);
      final controller = container.read(
        playbackQueueControllerProvider.notifier,
      );
      await controller.addItems(_items, playFirst: true);
      controller.setPlaybackMode(HeniPlaybackMode.singleLoop);

      await controller.playNext();
      expect(container.read(playbackQueueControllerProvider).currentIndex, 1);

      await controller.playIndex(0);
      await controller.playNext(advance: PlaybackAdvance.automatic);
      expect(container.read(playbackQueueControllerProvider).currentIndex, 0);
    });

    test('persists volume level across restore', () async {
      final engine = _FakePlaybackEngine();
      final store = _MemoryLibraryStore();
      final firstContainer = _container(engine, store: store);
      addTearDown(firstContainer.dispose);

      final firstController = firstContainer.read(
        playbackQueueControllerProvider.notifier,
      );
      await firstController.persistVolume(37);
      await Future<void>.delayed(const Duration(milliseconds: 260));

      expect(store.latest?.volumeLevel, 37);

      final restoredEngine = _FakePlaybackEngine();
      final restoredContainer = _container(restoredEngine, store: store);
      addTearDown(restoredContainer.dispose);
      restoredContainer.read(playbackQueueControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(restoredEngine.currentVolume, 37);
      expect(
        restoredContainer
            .read(playbackQueueControllerProvider)
            .lastAudibleVolume,
        37,
      );
    });

    test('muting does not overwrite the remembered audible volume', () async {
      final store = _MemoryLibraryStore();
      final container = _container(_FakePlaybackEngine(), store: store);
      addTearDown(container.dispose);
      final controller = container.read(
        playbackQueueControllerProvider.notifier,
      );

      await controller.persistVolume(64);
      await controller.persistVolume(0);
      await Future<void>.delayed(const Duration(milliseconds: 260));

      expect(
        container.read(playbackQueueControllerProvider).lastAudibleVolume,
        64,
      );
      expect(store.latest?.volumeLevel, 0);
      expect(store.latest?.lastAudibleVolume, 64);
    });

    test('persists and restores the sidebar preference', () async {
      final store = _MemoryLibraryStore();
      final firstContainer = _container(_FakePlaybackEngine(), store: store);
      addTearDown(firstContainer.dispose);

      final firstController = firstContainer.read(
        playbackQueueControllerProvider.notifier,
      );
      await firstController.persistShellPreferences(
        sidebarMode: HeniSidebarMode.compact,
      );

      expect(store.latest?.sidebarModeName, HeniSidebarMode.compact.name);

      final restoredContainer = _container(_FakePlaybackEngine(), store: store);
      addTearDown(restoredContainer.dispose);
      restoredContainer.read(playbackQueueControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        restoredContainer.read(sidebarModeProvider),
        HeniSidebarMode.compact,
      );
    });

    test(
      'removes songs from a user playlist without touching the library',
      () async {
        final engine = _FakePlaybackEngine();
        final store = _MemoryLibraryStore();
        final container = _container(engine, store: store);
        addTearDown(container.dispose);

        final controller = container.read(
          playbackQueueControllerProvider.notifier,
        );
        await controller.addItems(_items);
        await controller.createPlaylist('精选');
        final playlistId =
            container.read(playbackQueueControllerProvider).playlists.single.id;

        controller.addItemsToPlaylist(playlistId, [_items[0], _items[1]]);
        controller.removeItemsFromPlaylist(playlistId, [_items[0]]);

        final state = container.read(playbackQueueControllerProvider);
        expect(state.library.items, hasLength(3));
        expect(state.playlists.single.items.map((item) => item.title), ['B']);
        expect(store.latest?.playlists.single.itemPaths, [_items[1].path]);
      },
    );

    test(
      'removing the current playback item advances to the nearest remaining item',
      () async {
        final engine = _FakePlaybackEngine();
        final container = _container(engine);
        addTearDown(container.dispose);

        final controller = container.read(
          playbackQueueControllerProvider.notifier,
        );
        await controller.addItems(_items, playFirst: true);
        await controller.playNext();

        await controller.removePlaybackQueueItemAt(1);

        final state = container.read(playbackQueueControllerProvider);
        expect(state.playbackQueue.items.map((item) => item.title), ['A', 'C']);
        expect(state.currentItem?.title, 'C');
        expect(engine.opened.map((item) => item.title), ['A', 'B', 'C']);
      },
    );

    test(
      'deleting the active playlist returns browsing to the library',
      () async {
        final engine = _FakePlaybackEngine();
        final store = _MemoryLibraryStore();
        final container = _container(engine, store: store);
        addTearDown(container.dispose);

        final controller = container.read(
          playbackQueueControllerProvider.notifier,
        );
        await controller.addItems(_items);
        await controller.createPlaylist('临时');
        final playlistId =
            container.read(playbackQueueControllerProvider).playlists.single.id;

        controller.deletePlaylist(playlistId);

        final state = container.read(playbackQueueControllerProvider);
        expect(state.playlists, isEmpty);
        expect(state.activePlaylist.id, heniLibraryPlaylistId);
        expect(store.latest?.playlists, isEmpty);
      },
    );

    test('launch media paths are imported and played on startup', () async {
      final directory = await Directory.systemTemp.createTemp('heni-launch-');
      addTearDown(() => directory.delete(recursive: true));
      final launchFile = File(
        '${directory.path}${Platform.pathSeparator}launch.mp4',
      );
      await launchFile.writeAsBytes(const []);

      final engine = _FakePlaybackEngine();
      final container = _container(engine, launchMediaPaths: [launchFile.path]);
      addTearDown(container.dispose);

      container.read(playbackQueueControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final state = container.read(playbackQueueControllerProvider);
      expect(state.library.items.map((item) => item.path), [launchFile.path]);
      expect(state.currentItem?.path, launchFile.path);
      expect(state.libraryFilePaths, [launchFile.path]);
      expect(engine.opened.map((item) => item.path), [launchFile.path]);
    });

    test(
      'caches inspected media duration back into visible playlists',
      () async {
        final engine = _FakePlaybackEngine();
        final container = _container(
          engine,
          inspector: const _FakeMediaInspector(
            duration: Duration(minutes: 3, seconds: 42),
          ),
        );
        addTearDown(container.dispose);

        final controller = container.read(
          playbackQueueControllerProvider.notifier,
        );
        await controller.addItems(_items);
        await controller.createPlaylist('收藏');
        final playlistId =
            container.read(playbackQueueControllerProvider).playlists.single.id;
        controller.addItemToPlaylist(playlistId, _items.first);

        await controller.playIndex(0);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(playbackQueueControllerProvider);
        expect(
          state.library.items.first.duration,
          const Duration(seconds: 222),
        );
        expect(
          state.playlists.single.items.first.duration,
          const Duration(seconds: 222),
        );
        expect(
          state.playbackQueue.items.first.duration,
          const Duration(seconds: 222),
        );
        expect(state.currentItem?.duration, const Duration(seconds: 222));
      },
    );

    test(
      'restores persisted media durations into the visible library',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'heni-duration-restore-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final mediaFile = File(
          '${directory.path}${Platform.pathSeparator}a.mp3',
        );
        await mediaFile.writeAsBytes(const []);

        final engine = _FakePlaybackEngine();
        final store =
            _MemoryLibraryStore()
              ..latest = HeniLibraryConfig(
                libraryFiles: [mediaFile.path],
                mediaDurations: {
                  mediaFile.path:
                      const Duration(minutes: 4, seconds: 8).inMilliseconds,
                },
              );
        final container = _container(engine, store: store);
        addTearDown(container.dispose);

        container.read(playbackQueueControllerProvider.notifier);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final state = container.read(playbackQueueControllerProvider);
        expect(
          state.library.items.single.duration,
          const Duration(minutes: 4, seconds: 8),
        );
      },
    );
  });
}

ProviderContainer _container(
  _FakePlaybackEngine engine, {
  _MemoryLibraryStore? store,
  List<String> launchMediaPaths = const [],
  MediaInspector inspector = const _FakeMediaInspector(),
}) {
  return ProviderContainer(
    overrides: [
      playbackEngineProvider.overrideWithValue(engine),
      mediaInspectorProvider.overrideWithValue(inspector),
      heniLibraryStoreProvider.overrideWithValue(
        store ?? _MemoryLibraryStore(),
      ),
      launchMediaPathsProvider.overrideWithValue(launchMediaPaths),
    ],
  );
}

const _items = [
  MediaItem(path: r'D:\media\a.mp3', title: 'A', kind: MediaKind.audio),
  MediaItem(path: r'D:\media\b.mp3', title: 'B', kind: MediaKind.audio),
  MediaItem(path: r'D:\media\c.mp3', title: 'C', kind: MediaKind.audio),
];

class _FakePlaybackEngine implements PlaybackEngine {
  final opened = <MediaItem>[];
  double _volume = 100;

  @override
  Stream<bool> get completed => const Stream.empty();

  @override
  Duration get currentDuration => Duration.zero;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  double get currentVolume => _volume;

  @override
  bool get currentPlaying => false;

  @override
  Stream<Duration> get duration => Stream.value(Duration.zero);

  @override
  Stream<bool> get playing => Stream.value(false);

  @override
  Stream<Duration> get position => Stream.value(Duration.zero);

  @override
  Stream<double> get volume => Stream.value(_volume);

  @override
  Future<void> dispose() async {}

  @override
  Future<void> openItem(MediaItem item, {bool play = false}) async {
    opened.add(item);
  }

  @override
  Future<void> openPath(String path, {bool play = false}) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
  }

  @override
  Future<void> stop() async {}
}

class _FakeMediaInspector implements MediaInspector {
  const _FakeMediaInspector({this.duration});

  final Duration? duration;

  @override
  Future<MediaProbe> inspectPath(String path) async {
    return MediaProbe(
      sourcePath: path,
      streams: const [],
      chapters: const [],
      tags: const {},
      duration: duration,
    );
  }
}

class _MemoryLibraryStore implements HeniLibraryStore {
  HeniLibraryConfig? latest;

  @override
  Future<HeniLibraryConfig?> read() async => latest;

  @override
  Future<void> write(HeniLibraryConfig config) async {
    latest = config;
  }
}
