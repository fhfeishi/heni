import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heni/design/app_theme.dart';
import 'package:heni/domain/media/media_item.dart';
import 'package:heni/domain/media/media_kind.dart';
import 'package:heni/domain/media/media_probe.dart';
import 'package:heni/features/player/application/playback_queue_controller.dart';
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
  });
}

ProviderContainer _container(
  _FakePlaybackEngine engine, {
  _MemoryLibraryStore? store,
}) {
  return ProviderContainer(
    overrides: [
      playbackEngineProvider.overrideWithValue(engine),
      mediaInspectorProvider.overrideWithValue(const _FakeMediaInspector()),
      heniLibraryStoreProvider.overrideWithValue(
        store ?? _MemoryLibraryStore(),
      ),
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
  double get currentVolume => _volume;

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
  const _FakeMediaInspector();

  @override
  Future<MediaProbe> inspectPath(String path) async {
    return MediaProbe(
      sourcePath: path,
      streams: const [],
      chapters: const [],
      tags: const {},
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
