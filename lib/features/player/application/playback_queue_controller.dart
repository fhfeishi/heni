import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../domain/media/media_item.dart';
import '../../../domain/playback/heni_playlist.dart';
import '../../../domain/playback/playback_mode.dart';
import '../../../domain/playback/playback_order.dart';
import '../../../services/media/local_media_scanner.dart';
import '../../../services/media/playback_providers.dart';
import 'player_state.dart';

final localMediaScannerProvider = Provider<LocalMediaScanner>((ref) {
  return const LocalMediaScanner();
});

final playbackQueueControllerProvider =
    NotifierProvider<PlaybackQueueController, PlaybackQueueState>(
  PlaybackQueueController.new,
);

class PlaybackQueueController extends Notifier<PlaybackQueueState> {
  StreamSubscription<bool>? _completedSubscription;
  final _random = Random();

  @override
  PlaybackQueueState build() {
    _completedSubscription = ref.read(playbackEngineProvider).completed.listen(
      (completed) {
        if (completed) {
          unawaited(playNext(advance: PlaybackAdvance.automatic));
        }
      },
    );
    ref.onDispose(() {
      _completedSubscription?.cancel();
    });

    final playlist = HeniPlaylist(
      id: _id(),
      name: 'Now Playing',
      items: const [],
    );

    return PlaybackQueueState(
      playlists: [playlist],
      activePlaylistId: playlist.id,
      currentIndex: -1,
      order: const PlaybackOrder(indices: [], position: -1),
    );
  }

  Future<void> addItems(List<MediaItem> items, {bool playFirst = false}) async {
    if (items.isEmpty) {
      return;
    }

    final active = state.activePlaylist;
    final playlist = active.copyWith(items: [...active.items, ...items]);
    final shouldStart = playFirst || state.currentItem == null;
    final nextIndex = shouldStart ? active.items.length : state.currentIndex;

    _replacePlaylist(playlist);
    state = state.copyWith(
      currentIndex: nextIndex,
      order: _buildOrder(playlist.items.length, nextIndex),
      statusMessage: 'Added ${items.length} item${items.length == 1 ? '' : 's'}',
    );

    if (shouldStart) {
      await playIndex(nextIndex);
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
      currentIndex: -1,
      order: const PlaybackOrder(indices: [], position: -1),
      statusMessage: 'Created "$trimmed"',
    );
    await _clearCurrent();
  }

  Future<void> loadDirectory(String directoryPath) async {
    state = state.copyWith(isScanning: true, statusMessage: 'Scanning folder...');

    try {
      final items = await ref.read(localMediaScannerProvider).scanDirectory(
            directoryPath,
            recursive: state.recursiveScan,
            includeVideo: state.includeVideo,
          );
      final name = p.basename(directoryPath).trim().isEmpty
          ? directoryPath
          : p.basename(directoryPath);
      final playlist = HeniPlaylist(
        id: _id(),
        name: name,
        items: items,
        sourceDirectory: directoryPath,
      );

      state = state.copyWith(
        playlists: [...state.playlists, playlist],
        activePlaylistId: playlist.id,
        currentIndex: items.isEmpty ? -1 : 0,
        order: _buildOrder(items.length, 0),
        isScanning: false,
        statusMessage: items.isEmpty
            ? 'No supported media found'
            : 'Loaded ${items.length} item${items.length == 1 ? '' : 's'}',
      );

      if (items.isEmpty) {
        await _clearCurrent();
      } else if (state.autoplayOnLoad) {
        await playIndex(0);
      } else {
        await _setCurrentWithoutPlaying(0);
      }
    } catch (error) {
      state = state.copyWith(
        isScanning: false,
        statusMessage: 'Could not scan folder',
        lastError: error.toString(),
      );
    }
  }

  Future<void> playIndex(int index, {PlaybackOrder? order}) async {
    final items = state.activePlaylist.items;
    if (index < 0 || index >= items.length) {
      return;
    }

    final item = items[index];
    state = state.copyWith(
      currentIndex: index,
      order: order ??
          state.order.rebuild(
            length: items.length,
            currentIndex: index,
            shuffle: state.shuffle,
            random: _random,
          ),
      statusMessage: null,
      lastError: null,
    );

    ref.read(currentMediaProvider.notifier).set(item);
    unawaited(ref.read(currentMediaProbeProvider.notifier).inspect(item.path));
    await ref.read(playbackEngineProvider).openItem(item, play: true);
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

    await playIndex(move.index!, order: move.order);
  }

  Future<void> playPrevious() async {
    final move = state.order.previous(state.repeatMode);
    if (!move.shouldPlay || move.index == null || move.order == null) {
      return;
    }

    await playIndex(move.index!, order: move.order);
  }

  void selectPlaylist(String playlistId) {
    final playlist = state.playlists.firstWhere(
      (playlist) => playlist.id == playlistId,
      orElse: () => state.activePlaylist,
    );
    final nextIndex = playlist.items.isEmpty ? -1 : 0;

    state = state.copyWith(
      activePlaylistId: playlist.id,
      currentIndex: nextIndex,
      order: _buildOrder(playlist.items.length, nextIndex),
      statusMessage: 'Selected "${playlist.name}"',
    );

    if (nextIndex >= 0) {
      unawaited(_setCurrentWithoutPlaying(nextIndex));
    } else {
      unawaited(_clearCurrent());
    }
  }

  void toggleShuffle() {
    final enabled = !state.shuffle;
    final currentIndex = state.currentIndex < 0 ? 0 : state.currentIndex;
    state = state.copyWith(
      shuffle: enabled,
      order: _buildOrder(
        state.activePlaylist.items.length,
        currentIndex,
        shuffleOverride: enabled,
      ),
      statusMessage: enabled ? 'Shuffle on' : 'Shuffle off',
    );
  }

  void cycleRepeatMode() {
    final next = state.repeatMode.next;
    state = state.copyWith(repeatMode: next, statusMessage: next.label);
  }

  void setRecursiveScan(bool enabled) {
    state = state.copyWith(recursiveScan: enabled);
  }

  void setIncludeVideo(bool enabled) {
    state = state.copyWith(includeVideo: enabled);
  }

  void setAutoplayOnLoad(bool enabled) {
    state = state.copyWith(autoplayOnLoad: enabled);
  }

  Future<void> _setCurrentWithoutPlaying(int index) async {
    final items = state.activePlaylist.items;
    if (index < 0 || index >= items.length) {
      await _clearCurrent();
      return;
    }

    final item = items[index];
    ref.read(currentMediaProvider.notifier).set(item);
    unawaited(ref.read(currentMediaProbeProvider.notifier).inspect(item.path));
  }

  Future<void> _clearCurrent() async {
    ref.read(currentMediaProvider.notifier).set(null);
    ref.read(currentMediaProbeProvider.notifier).clear();
    await ref.read(playbackEngineProvider).stop();
  }

  void _replacePlaylist(HeniPlaylist playlist) {
    state = state.copyWith(
      playlists: [
        for (final existing in state.playlists)
          if (existing.id == playlist.id) playlist else existing,
      ],
    );
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
    required this.playlists,
    required this.activePlaylistId,
    required this.currentIndex,
    required this.order,
    this.repeatMode = HeniRepeatMode.none,
    this.shuffle = false,
    this.recursiveScan = true,
    this.includeVideo = true,
    this.autoplayOnLoad = true,
    this.isScanning = false,
    this.statusMessage,
    this.lastError,
  });

  final List<HeniPlaylist> playlists;
  final String activePlaylistId;
  final int currentIndex;
  final PlaybackOrder order;
  final HeniRepeatMode repeatMode;
  final bool shuffle;
  final bool recursiveScan;
  final bool includeVideo;
  final bool autoplayOnLoad;
  final bool isScanning;
  final String? statusMessage;
  final String? lastError;

  HeniPlaylist get activePlaylist {
    return playlists.firstWhere(
      (playlist) => playlist.id == activePlaylistId,
      orElse: () => playlists.first,
    );
  }

  MediaItem? get currentItem {
    final items = activePlaylist.items;
    if (currentIndex < 0 || currentIndex >= items.length) {
      return null;
    }
    return items[currentIndex];
  }

  PlaybackQueueState copyWith({
    List<HeniPlaylist>? playlists,
    String? activePlaylistId,
    int? currentIndex,
    PlaybackOrder? order,
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
      playlists: playlists ?? this.playlists,
      activePlaylistId: activePlaylistId ?? this.activePlaylistId,
      currentIndex: currentIndex ?? this.currentIndex,
      order: order ?? this.order,
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
