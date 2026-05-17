import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../design/app_theme.dart';
import '../../../domain/media/media_item.dart';
import '../../../domain/media/media_path.dart';
import '../../../domain/playback/heni_playlist.dart';
import '../../../domain/playback/playback_mode.dart';
import '../../../domain/playback/playback_order.dart';
import '../../../services/media/local_media_scanner.dart';
import '../../../services/media/playback_providers.dart';
import '../../../services/storage/heni_library_store.dart';
import 'player_state.dart';

const heniLibraryPlaylistId = 'heni-library';
const heniPlaybackQueueId = 'heni-playback-queue';

String _pathKey(String path) => p.normalize(path).toLowerCase();

final localMediaScannerProvider = Provider<LocalMediaScanner>((ref) {
  return const LocalMediaScanner();
});

final playbackQueueControllerProvider =
    NotifierProvider<PlaybackQueueController, PlaybackQueueState>(
      PlaybackQueueController.new,
    );

class PlaybackQueueController extends Notifier<PlaybackQueueState> {
  StreamSubscription<bool>? _completedSubscription;
  Timer? _volumePersistTimer;
  final _random = Random();
  String? _persistedPaletteName;
  String? _persistedUiStyleName;
  List<String> _persistedSceneryImagePaths = const [];
  double? _persistedVolumeLevel;

  @override
  PlaybackQueueState build() {
    _completedSubscription = ref.read(playbackEngineProvider).completed.listen((
      completed,
    ) {
      if (completed) {
        unawaited(playNext(advance: PlaybackAdvance.automatic));
      }
    });
    ref.onDispose(() {
      _completedSubscription?.cancel();
      _volumePersistTimer?.cancel();
    });
    unawaited(_restorePersistedState());

    const library = HeniPlaylist(
      id: heniLibraryPlaylistId,
      name: '曲库',
      items: [],
    );
    const playbackQueue = HeniPlaylist(
      id: heniPlaybackQueueId,
      name: '当前播放',
      items: [],
    );

    return const PlaybackQueueState(
      library: library,
      playlists: [],
      activePlaylistId: heniLibraryPlaylistId,
      playbackQueue: playbackQueue,
      playbackSourceId: heniLibraryPlaylistId,
      currentIndex: -1,
      order: PlaybackOrder(indices: [], position: -1),
    );
  }

  Future<void> addItems(List<MediaItem> items, {bool playFirst = false}) async {
    if (items.isEmpty) {
      return;
    }

    final shouldStart = playFirst || state.currentItem == null;
    state = state.copyWith(
      library: _libraryWithMergedItems(items),
      libraryFilePaths: _libraryFilesWith(items.map((item) => item.path)),
      activePlaylistId: heniLibraryPlaylistId,
      statusMessage: '已加入曲库 ${items.length} 个媒体文件',
      lastError: null,
    );
    unawaited(_persistState());

    if (shouldStart) {
      await _playLibraryItemByPath(items.first.path);
    }
  }

  Future<void> createPlaylist(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final playlist = HeniPlaylist(id: _id(), name: trimmed, items: const []);

    state = state.copyWith(
      playlists: [...state.playlists, playlist],
      activePlaylistId: playlist.id,
      statusMessage: '已创建“$trimmed”，可从曲库加入歌曲',
      lastError: null,
    );
    unawaited(_persistState());
  }

  void renamePlaylist(String playlistId, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final playlist = _userPlaylistById(playlistId);
    if (playlist == null) {
      return;
    }

    final nextPlaylist = playlist.copyWith(name: trimmed);
    state = state.copyWith(
      playlists: [
        for (final existing in state.playlists)
          if (existing.id == playlistId) nextPlaylist else existing,
      ],
      statusMessage: '已重命名为“$trimmed”',
      lastError: null,
    );
    unawaited(_persistState());
  }

  void updatePlaylistDescription(String playlistId, String description) {
    final playlist = _userPlaylistById(playlistId);
    if (playlist == null) {
      return;
    }

    final nextPlaylist = playlist.copyWith(description: description.trim());
    state = state.copyWith(
      playlists: [
        for (final existing in state.playlists)
          if (existing.id == playlistId) nextPlaylist else existing,
      ],
      statusMessage: nextPlaylist.description.isEmpty ? '已清空歌单说明' : '已更新歌单说明',
      lastError: null,
    );
    unawaited(_persistState());
  }

  void deletePlaylist(String playlistId) {
    final playlist = _userPlaylistById(playlistId);
    if (playlist == null) {
      return;
    }

    state = state.copyWith(
      playlists: [
        for (final existing in state.playlists)
          if (existing.id != playlistId) existing,
      ],
      activePlaylistId:
          state.activePlaylistId == playlistId
              ? heniLibraryPlaylistId
              : state.activePlaylistId,
      statusMessage: '已删除“${playlist.name}”',
      lastError: null,
    );
    unawaited(_persistState());
  }

  HeniPlaylist? _userPlaylistById(String playlistId) {
    for (final playlist in state.playlists) {
      if (playlist.id == playlistId) {
        return playlist;
      }
    }
    return null;
  }

  Future<void> loadDirectory(String directoryPath) async {
    state = state.copyWith(
      isScanning: true,
      statusMessage: '正在扫描文件夹...',
      lastError: null,
    );

    try {
      final items = await ref
          .read(localMediaScannerProvider)
          .scanDirectory(
            directoryPath,
            recursive: state.recursiveScan,
            includeVideo: state.includeVideo,
          );
      final shouldStart = state.currentItem == null && state.autoplayOnLoad;

      state = state.copyWith(
        library: _libraryWithMergedItems(items),
        libraryDirectories: _libraryDirectoriesWith(directoryPath),
        activePlaylistId: heniLibraryPlaylistId,
        isScanning: false,
        statusMessage:
            items.isEmpty ? '未找到支持的音视频文件' : '已加入曲库 ${items.length} 个媒体文件',
        lastError: null,
      );
      unawaited(_persistState());

      if (items.isNotEmpty && shouldStart) {
        await _playLibraryItemByPath(items.first.path);
      }
    } catch (error) {
      state = state.copyWith(
        isScanning: false,
        statusMessage: '无法扫描文件夹',
        lastError: error.toString(),
      );
    }
  }

  Future<void> refreshLibrary() async {
    if (state.libraryDirectories.isEmpty && state.libraryFilePaths.isEmpty) {
      state = state.copyWith(statusMessage: '还没有可刷新的曲库来源', lastError: null);
      return;
    }

    state = state.copyWith(
      isScanning: true,
      statusMessage: '正在刷新曲库...',
      lastError: null,
    );

    try {
      final config = HeniLibraryConfig(
        libraryDirectories: state.libraryDirectories,
        libraryFiles: state.libraryFilePaths,
        playlists: [
          for (final playlist in state.playlists)
            HeniPlaylistConfig(
              id: playlist.id,
              name: playlist.name,
              description: playlist.description,
              itemPaths: playlist.items.map((item) => item.path).toList(),
            ),
        ],
        activePlaylistId: state.activePlaylistId,
        playbackModeName: state.playbackMode.name,
        recursiveScan: state.recursiveScan,
        includeVideo: state.includeVideo,
        autoplayOnLoad: state.autoplayOnLoad,
      );
      final libraryItems = await _scanConfiguredLibrary(config);
      final itemByPath = {
        for (final item in libraryItems) _pathKey(item.path): item,
      };
      final playlists = [
        for (final playlist in state.playlists)
          playlist.copyWith(
            items: [
              for (final item in playlist.items)
                if (itemByPath[_pathKey(item.path)]
                    case final MediaItem refreshed)
                  refreshed,
            ],
          ),
      ];

      state = state.copyWith(
        library: state.library.copyWith(items: libraryItems),
        playlists: playlists,
        isScanning: false,
        statusMessage:
            libraryItems.isEmpty
                ? '曲库已刷新，暂未找到媒体文件'
                : '曲库已刷新 ${libraryItems.length} 首',
        lastError: null,
      );
      unawaited(_persistState());
    } catch (error) {
      state = state.copyWith(
        isScanning: false,
        statusMessage: '曲库刷新失败',
        lastError: error.toString(),
      );
    }
  }

  Future<void> playIndex(int index) async {
    final source = state.activePlaylist;
    if (index < 0 || index >= source.items.length) {
      return;
    }

    final playbackQueue = source.copyWith(
      items: List<MediaItem>.of(source.items),
    );
    await _playQueueIndex(
      index,
      playbackQueue: playbackQueue,
      playbackSourceId: source.id,
      order: _buildOrder(source.items.length, index),
    );
  }

  Future<void> playNext({
    PlaybackAdvance advance = PlaybackAdvance.user,
  }) async {
    final move = state.order.next(state.repeatMode);
    if (!move.shouldPlay || move.index == null || move.order == null) {
      if (advance == PlaybackAdvance.automatic) {
        await ref.read(playbackEngineProvider).stop();
      }
      return;
    }

    await _playQueueIndex(move.index!, order: move.order);
  }

  Future<void> playPrevious() async {
    final move = state.order.previous(state.repeatMode);
    if (!move.shouldPlay || move.index == null || move.order == null) {
      return;
    }

    await _playQueueIndex(move.index!, order: move.order);
  }

  void selectPlaylist(String playlistId) {
    final playlist = state.playlistById(playlistId);
    state = state.copyWith(
      activePlaylistId: playlist.id,
      statusMessage: '正在浏览“${playlist.name}”',
      lastError: null,
    );
    unawaited(_persistState());
  }

  void addItemToPlaylist(String playlistId, MediaItem item) {
    addItemsToPlaylist(playlistId, [item]);
  }

  void addItemsToPlaylist(String playlistId, List<MediaItem> items) {
    if (items.isEmpty) {
      return;
    }

    final index = state.playlists.indexWhere(
      (playlist) => playlist.id == playlistId,
    );
    if (index < 0) {
      return;
    }

    final playlist = state.playlists[index];
    final seen = playlist.items.map((item) => _pathKey(item.path)).toSet();
    final additions = <MediaItem>[];

    for (final item in items) {
      if (seen.add(_pathKey(item.path))) {
        additions.add(item);
      }
    }

    if (additions.isEmpty) {
      state = state.copyWith(statusMessage: '“${playlist.name}”中已存在所选歌曲');
      return;
    }

    final nextPlaylist = playlist.copyWith(
      items: [...playlist.items, ...additions],
    );
    state = state.copyWith(
      playlists: [
        for (final existing in state.playlists)
          if (existing.id == nextPlaylist.id) nextPlaylist else existing,
      ],
      statusMessage: '已加入“${playlist.name}” ${additions.length} 首',
      lastError: null,
    );
    unawaited(_persistState());
  }

  void removeItemsFromPlaylist(String playlistId, Iterable<MediaItem> items) {
    if (playlistId == heniLibraryPlaylistId) {
      return;
    }

    final removals = {for (final item in items) _pathKey(item.path)};
    if (removals.isEmpty) {
      return;
    }

    final index = state.playlists.indexWhere(
      (playlist) => playlist.id == playlistId,
    );
    if (index < 0) {
      return;
    }

    final playlist = state.playlists[index];
    final nextItems = [
      for (final item in playlist.items)
        if (!removals.contains(_pathKey(item.path))) item,
    ];
    final removedCount = playlist.items.length - nextItems.length;
    if (removedCount <= 0) {
      return;
    }

    final nextPlaylist = playlist.copyWith(items: nextItems);
    state = state.copyWith(
      playlists: [
        for (final existing in state.playlists)
          if (existing.id == nextPlaylist.id) nextPlaylist else existing,
      ],
      statusMessage:
          removedCount == 1
              ? '已从“${playlist.name}”移除 1 首'
              : '已从“${playlist.name}”移除 $removedCount 首',
      lastError: null,
    );
    unawaited(_persistState());
  }

  Future<void> playQueueIndex(int index) async {
    await _playQueueIndex(index);
  }

  Future<void> removePlaybackQueueItemAt(int index) async {
    final items = List<MediaItem>.of(state.playbackQueue.items);
    if (index < 0 || index >= items.length) {
      return;
    }

    final removed = items.removeAt(index);
    final nextQueue = state.playbackQueue.copyWith(items: items);
    final message = '已从当前播放列表移除“${removed.title}”';

    if (items.isEmpty) {
      state = state.copyWith(
        playbackQueue: nextQueue,
        currentIndex: -1,
        order: const PlaybackOrder(indices: [], position: -1),
        statusMessage: message,
        lastError: null,
      );
      ref.read(currentMediaProvider.notifier).set(null);
      ref.read(currentMediaProbeProvider.notifier).clear();
      ref.read(currentLyricsProvider.notifier).clear();
      await ref.read(playbackEngineProvider).stop();
      return;
    }

    if (index == state.currentIndex) {
      final nextIndex = index >= items.length ? items.length - 1 : index;
      await _playQueueIndex(
        nextIndex,
        playbackQueue: nextQueue,
        playbackSourceId: state.playbackSourceId,
        order: _buildOrder(items.length, nextIndex),
      );
      state = state.copyWith(statusMessage: message, lastError: null);
      return;
    }

    final adjustedIndex =
        index < state.currentIndex
            ? state.currentIndex - 1
            : state.currentIndex;
    state = state.copyWith(
      playbackQueue: nextQueue,
      currentIndex: adjustedIndex,
      order: _buildOrder(items.length, adjustedIndex),
      statusMessage: message,
      lastError: null,
    );
  }

  void toggleShuffle() {
    setPlaybackMode(
      state.shuffle ? HeniPlaybackMode.sequence : HeniPlaybackMode.random,
    );
  }

  void cycleRepeatMode() {
    setPlaybackMode(
      HeniPlaybackMode.fromState(
        repeatMode: state.repeatMode.next,
        shuffle: false,
      ),
    );
  }

  void cyclePlaybackMode() {
    setPlaybackMode(state.playbackMode.next);
  }

  void setPlaybackMode(HeniPlaybackMode mode) {
    final currentIndex = state.currentIndex < 0 ? 0 : state.currentIndex;
    state = state.copyWith(
      repeatMode: mode.repeatMode,
      shuffle: mode.shuffle,
      order: _buildOrder(
        state.playbackQueue.items.length,
        currentIndex,
        shuffleOverride: mode.shuffle,
      ),
      statusMessage: '播放模式：${mode.label}',
      lastError: null,
    );
    unawaited(_persistState());
  }

  void setRecursiveScan(bool enabled) {
    state = state.copyWith(recursiveScan: enabled);
    unawaited(_persistState());
  }

  void setIncludeVideo(bool enabled) {
    state = state.copyWith(includeVideo: enabled);
    unawaited(_persistState());
  }

  void setAutoplayOnLoad(bool enabled) {
    state = state.copyWith(autoplayOnLoad: enabled);
    unawaited(_persistState());
  }

  Future<void> persistVolume(double volume) async {
    final normalized = volume.clamp(0, 100).toDouble();
    _persistedVolumeLevel = normalized;
    _volumePersistTimer?.cancel();
    _volumePersistTimer = Timer(const Duration(milliseconds: 220), () {
      unawaited(_persistState(volumeLevel: normalized));
    });
  }

  Future<void> persistShellPreferences({
    HeniPalette? palette,
    HeniUiStyle? uiStyle,
    List<String>? sceneryImagePaths,
  }) async {
    if (palette != null) {
      _persistedPaletteName = palette.name;
    }
    if (uiStyle != null) {
      _persistedUiStyleName = uiStyle.name;
    }
    if (sceneryImagePaths != null) {
      _persistedSceneryImagePaths = List.unmodifiable(sceneryImagePaths);
    }
    await _persistState(
      paletteName: _persistedPaletteName,
      uiStyleName: _persistedUiStyleName,
      sceneryImagePaths: _persistedSceneryImagePaths,
    );
  }

  Future<void> _restorePersistedState() async {
    try {
      final config = await ref.read(heniLibraryStoreProvider).read();
      if (!ref.mounted) {
        return;
      }
      if (config == null || config.isEmpty) {
        return;
      }

      state = state.copyWith(
        isScanning: config.libraryDirectories.isNotEmpty,
        repeatMode: config.playbackMode?.repeatMode ?? state.repeatMode,
        shuffle: config.playbackMode?.shuffle ?? state.shuffle,
        recursiveScan: config.recursiveScan,
        includeVideo: config.includeVideo,
        autoplayOnLoad: config.autoplayOnLoad,
        statusMessage:
            config.libraryDirectories.isEmpty ? '正在恢复曲库...' : '正在恢复曲库目录...',
        lastError: null,
      );
      if (config.activePaletteName case final String paletteName) {
        _persistedPaletteName = paletteName;
        ref.read(activePaletteProvider.notifier).restoreByName(paletteName);
      }
      if (config.activeUiStyle case final String uiStyleName) {
        _persistedUiStyleName = uiStyleName;
        ref.read(activeUiStyleProvider.notifier).restoreByName(uiStyleName);
      }
      _persistedVolumeLevel = config.volumeLevel?.clamp(0, 100).toDouble();
      _persistedSceneryImagePaths = List.unmodifiable(config.sceneryImagePaths);
      if (config.sceneryImagePaths.isNotEmpty) {
        ref
            .read(sceneryImagePathsProvider.notifier)
            .replaceAll(
              config.sceneryImagePaths
                  .where((path) => File(path).existsSync())
                  .toList(),
            );
      }
      if (_persistedVolumeLevel case final double volumeLevel) {
        await ref.read(playbackEngineProvider).setVolume(volumeLevel);
        if (!ref.mounted) {
          return;
        }
      }

      final libraryItems = await _scanConfiguredLibrary(config);
      if (!ref.mounted) {
        return;
      }
      final library = state.library.copyWith(items: libraryItems);
      final itemByPath = {
        for (final item in libraryItems) _pathKey(item.path): item,
      };
      final playlists = [
        for (final playlistConfig in config.playlists)
          if (playlistConfig.id.isNotEmpty)
            HeniPlaylist(
              id: playlistConfig.id,
              name: playlistConfig.name,
              description: playlistConfig.description,
              items: [
                for (final path in playlistConfig.itemPaths)
                  if (itemByPath[_pathKey(path)] case final MediaItem item)
                    item,
              ],
            ),
      ];
      final activePlaylistId = _validPlaylistId(
        config.activePlaylistId,
        playlists,
      );

      state = state.copyWith(
        library: library,
        libraryDirectories: config.libraryDirectories,
        libraryFilePaths: config.libraryFiles,
        playlists: playlists,
        activePlaylistId: activePlaylistId,
        isScanning: false,
        statusMessage:
            libraryItems.isEmpty
                ? '曲库已恢复，暂未找到媒体文件'
                : '曲库已恢复 ${libraryItems.length} 首',
        lastError: null,
      );
    } catch (error) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        isScanning: false,
        statusMessage: '曲库恢复失败',
        lastError: error.toString(),
      );
    }
  }

  Future<void> _playLibraryItemByPath(String path) async {
    final index = state.library.items.indexWhere(
      (item) => _pathKey(item.path) == _pathKey(path),
    );
    if (index >= 0) {
      await playIndex(index);
    }
  }

  Future<void> _playQueueIndex(
    int index, {
    HeniPlaylist? playbackQueue,
    String? playbackSourceId,
    PlaybackOrder? order,
  }) async {
    final queue = playbackQueue ?? state.playbackQueue;
    if (index < 0 || index >= queue.items.length) {
      return;
    }

    final item = queue.items[index];
    state = state.copyWith(
      playbackQueue: queue,
      playbackSourceId: playbackSourceId ?? state.playbackSourceId,
      currentIndex: index,
      order:
          order ??
          state.order.rebuild(
            length: queue.items.length,
            currentIndex: index,
            shuffle: state.shuffle,
            random: _random,
          ),
      statusMessage: null,
      lastError: null,
    );

    ref.read(currentMediaProvider.notifier).set(item);
    unawaited(ref.read(currentMediaProbeProvider.notifier).inspect(item.path));
    unawaited(ref.read(currentLyricsProvider.notifier).loadFor(item.path));
    await ref.read(playbackEngineProvider).openItem(item, play: true);
  }

  HeniPlaylist _libraryWithMergedItems(List<MediaItem> items) {
    final merged = List<MediaItem>.of(state.library.items);
    final seen = merged.map((item) => _pathKey(item.path)).toSet();

    for (final item in items) {
      if (seen.add(_pathKey(item.path))) {
        merged.add(item);
      }
    }

    return state.library.copyWith(items: merged);
  }

  List<String> _libraryFilesWith(Iterable<String> filePaths) {
    final files = List<String>.of(state.libraryFilePaths);
    final seen = files.map(_pathKey).toSet();
    for (final path in filePaths) {
      final normalized = p.normalize(path);
      if (seen.add(_pathKey(normalized))) {
        files.add(normalized);
      }
    }
    return files;
  }

  List<String> _libraryDirectoriesWith(String directoryPath) {
    final normalized = p.normalize(directoryPath);
    final directories = List<String>.of(state.libraryDirectories);
    final seen = directories.map(_pathKey).toSet();
    if (seen.add(_pathKey(normalized))) {
      directories.add(normalized);
    }
    return directories;
  }

  Future<List<MediaItem>> _scanConfiguredLibrary(
    HeniLibraryConfig config,
  ) async {
    final items = <MediaItem>[];
    final seen = <String>{};
    final scanner = ref.read(localMediaScannerProvider);

    for (final directory in config.libraryDirectories) {
      if (!Directory(directory).existsSync()) {
        continue;
      }

      final scanned = await scanner.scanDirectory(
        directory,
        recursive: config.recursiveScan,
        includeVideo: config.includeVideo,
      );
      _mergeItems(items, seen, scanned);
    }

    final restoredFiles = [
      for (final path in config.libraryFiles)
        if (File(path).existsSync() &&
            isSupportedMediaPath(path, includeVideo: config.includeVideo))
          MediaItem.fromPath(path, kind: mediaKindFromPath(path)),
    ];
    _mergeItems(items, seen, restoredFiles);
    items.sort((a, b) => _pathKey(a.path).compareTo(_pathKey(b.path)));
    return List.unmodifiable(items);
  }

  void _mergeItems(
    List<MediaItem> target,
    Set<String> seen,
    Iterable<MediaItem> items,
  ) {
    for (final item in items) {
      if (seen.add(_pathKey(item.path))) {
        target.add(item);
      }
    }
  }

  String _validPlaylistId(String? playlistId, List<HeniPlaylist> playlists) {
    if (playlistId == heniLibraryPlaylistId ||
        playlistId == heniPlaybackQueueId) {
      return playlistId!;
    }
    return playlists.any((playlist) => playlist.id == playlistId)
        ? playlistId!
        : heniLibraryPlaylistId;
  }

  Future<void> _persistState({
    String? paletteName,
    String? uiStyleName,
    List<String>? sceneryImagePaths,
    double? volumeLevel,
  }) async {
    final config = HeniLibraryConfig(
      libraryDirectories: state.libraryDirectories,
      libraryFiles: state.libraryFilePaths,
      playlists: [
        for (final playlist in state.playlists)
          HeniPlaylistConfig(
            id: playlist.id,
            name: playlist.name,
            description: playlist.description,
            itemPaths: playlist.items.map((item) => item.path).toList(),
          ),
      ],
      activePlaylistId: state.activePlaylistId,
      playbackModeName: state.playbackMode.name,
      recursiveScan: state.recursiveScan,
      includeVideo: state.includeVideo,
      autoplayOnLoad: state.autoplayOnLoad,
      activePaletteName: paletteName ?? _persistedPaletteName,
      activeUiStyle: uiStyleName ?? _persistedUiStyleName,
      sceneryImagePaths: sceneryImagePaths ?? _persistedSceneryImagePaths,
      volumeLevel: volumeLevel ?? _persistedVolumeLevel,
    );

    try {
      await ref.read(heniLibraryStoreProvider).write(config);
    } catch (error) {
      state = state.copyWith(
        statusMessage: '曲库配置保存失败',
        lastError: error.toString(),
      );
    }
  }

  PlaybackOrder _buildOrder(
    int length,
    int currentIndex, {
    bool? shuffleOverride,
  }) {
    final shuffle = shuffleOverride ?? state.shuffle;
    if (shuffle) {
      return PlaybackOrder.shuffled(
        length,
        currentIndex: currentIndex < 0 ? 0 : currentIndex,
        random: _random,
      );
    }
    return PlaybackOrder.linear(
      length,
      currentIndex: currentIndex < 0 ? 0 : currentIndex,
    );
  }

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();
}

class PlaybackQueueState {
  const PlaybackQueueState({
    required this.library,
    required this.playlists,
    required this.activePlaylistId,
    required this.playbackQueue,
    required this.playbackSourceId,
    required this.currentIndex,
    required this.order,
    this.libraryDirectories = const [],
    this.libraryFilePaths = const [],
    this.repeatMode = HeniRepeatMode.none,
    this.shuffle = false,
    this.recursiveScan = true,
    this.includeVideo = true,
    this.autoplayOnLoad = true,
    this.isScanning = false,
    this.statusMessage,
    this.lastError,
  });

  final HeniPlaylist library;
  final List<HeniPlaylist> playlists;
  final String activePlaylistId;
  final HeniPlaylist playbackQueue;
  final String playbackSourceId;
  final int currentIndex;
  final PlaybackOrder order;
  final List<String> libraryDirectories;
  final List<String> libraryFilePaths;
  final HeniRepeatMode repeatMode;
  final bool shuffle;
  final bool recursiveScan;
  final bool includeVideo;
  final bool autoplayOnLoad;
  final bool isScanning;
  final String? statusMessage;
  final String? lastError;

  HeniPlaylist get activePlaylist => playlistById(activePlaylistId);

  MediaItem? get currentItem {
    final items = playbackQueue.items;
    if (currentIndex < 0 || currentIndex >= items.length) {
      return null;
    }
    return items[currentIndex];
  }

  HeniPlaybackMode get playbackMode {
    return HeniPlaybackMode.fromState(repeatMode: repeatMode, shuffle: shuffle);
  }

  HeniPlaylist playlistById(String playlistId) {
    if (playlistId == library.id) {
      return library;
    }
    if (playlistId == playbackQueue.id) {
      return playbackQueue;
    }

    return playlists.firstWhere(
      (playlist) => playlist.id == playlistId,
      orElse: () => library,
    );
  }

  bool isCurrentItem(MediaItem item) {
    final current = currentItem;
    return current != null && _pathKey(current.path) == _pathKey(item.path);
  }

  PlaybackQueueState copyWith({
    HeniPlaylist? library,
    List<HeniPlaylist>? playlists,
    String? activePlaylistId,
    HeniPlaylist? playbackQueue,
    String? playbackSourceId,
    int? currentIndex,
    PlaybackOrder? order,
    List<String>? libraryDirectories,
    List<String>? libraryFilePaths,
    HeniRepeatMode? repeatMode,
    bool? shuffle,
    bool? recursiveScan,
    bool? includeVideo,
    bool? autoplayOnLoad,
    bool? isScanning,
    String? statusMessage,
    String? lastError,
  }) {
    return PlaybackQueueState(
      library: library ?? this.library,
      playlists: playlists ?? this.playlists,
      activePlaylistId: activePlaylistId ?? this.activePlaylistId,
      playbackQueue: playbackQueue ?? this.playbackQueue,
      playbackSourceId: playbackSourceId ?? this.playbackSourceId,
      currentIndex: currentIndex ?? this.currentIndex,
      order: order ?? this.order,
      libraryDirectories: libraryDirectories ?? this.libraryDirectories,
      libraryFilePaths: libraryFilePaths ?? this.libraryFilePaths,
      repeatMode: repeatMode ?? this.repeatMode,
      shuffle: shuffle ?? this.shuffle,
      recursiveScan: recursiveScan ?? this.recursiveScan,
      includeVideo: includeVideo ?? this.includeVideo,
      autoplayOnLoad: autoplayOnLoad ?? this.autoplayOnLoad,
      isScanning: isScanning ?? this.isScanning,
      statusMessage: statusMessage,
      lastError: lastError,
    );
  }
}
