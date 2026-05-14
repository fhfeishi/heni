import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;

import '../../../design/app_theme.dart';
import '../../../domain/media/media_item.dart';
import '../../../domain/media/media_kind.dart';
import '../../../domain/media/media_path.dart';
import '../../../domain/media/media_probe.dart';
import '../../../domain/playback/heni_playlist.dart';
import '../../../domain/playback/playback_mode.dart';
import '../../../services/media/playback_engine.dart';
import '../../../services/media/playback_providers.dart';
import '../../scenery/presentation/scenery_stage.dart';
import '../application/audio_export_controller.dart';
import '../application/playback_queue_controller.dart';
import '../application/player_state.dart';

IconData _playbackModeIcon(HeniPlaybackMode mode) {
  return switch (mode) {
    HeniPlaybackMode.sequence => Icons.format_list_numbered,
    HeniPlaybackMode.listLoop => Icons.repeat,
    HeniPlaybackMode.singleLoop => Icons.repeat_one,
    HeniPlaybackMode.random => Icons.shuffle,
  };
}

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(activePaletteProvider);
    final uiStyle = ref.watch(activeUiStyleProvider);
    final sceneryImages = ref.watch(sceneryImagePathsProvider);
    final queue = ref.watch(playbackQueueControllerProvider);
    final currentMedia = queue.currentItem ?? ref.watch(currentMediaProvider);
    final mediaProbe = ref.watch(currentMediaProbeProvider);
    final lyrics = ref.watch(currentLyricsProvider);
    final audioExport = ref.watch(audioExportControllerProvider);
    final engine = ref.watch(playbackEngineProvider);
    final videoController = ref.watch(videoControllerProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.seed, width: 4)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _TopNavigation(palette: palette, queue: queue, uiStyle: uiStyle),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Sidebar(
                      palette: palette,
                      queue: queue,
                      onCreatePlaylist: () => _createPlaylist(context, ref),
                      onSelectPlaylist: (playlistId) {
                        ref
                            .read(playbackQueueControllerProvider.notifier)
                            .selectPlaylist(playlistId);
                      },
                      onAddFromLibrary: (playlistId) {
                        _addFromLibrary(context, ref, playlistId);
                      },
                      onRenamePlaylist: (playlist) {
                        _renamePlaylist(context, ref, playlist);
                      },
                      onEditDescription: (playlist) {
                        _editPlaylistDescription(context, ref, playlist);
                      },
                      onDeletePlaylist: (playlist) {
                        _confirmDeletePlaylist(context, ref, playlist);
                      },
                    ),
                    Expanded(
                      child: _ContentArea(
                        palette: palette,
                        uiStyle: uiStyle,
                        sceneryImages: sceneryImages,
                        queue: queue,
                        currentMedia: currentMedia,
                        mediaProbe: mediaProbe,
                        lyrics: lyrics,
                        engine: engine,
                        videoController: videoController,
                        onPickScenery: () => _pickScenery(ref),
                        onPickMedia: () => _pickMedia(ref),
                        onPickFolder: () => _pickFolder(ref),
                        onPlayIndex: (index) {
                          unawaited(
                            ref
                                .read(playbackQueueControllerProvider.notifier)
                                .playIndex(index),
                          );
                        },
                        onAddToPlaylist: (playlistId, item) {
                          ref
                              .read(playbackQueueControllerProvider.notifier)
                              .addItemToPlaylist(playlistId, item);
                        },
                        onAddFromLibrary: (playlistId) {
                          _addFromLibrary(context, ref, playlistId);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              _BottomPlayerBar(
                palette: palette,
                currentMedia: currentMedia,
                mediaProbe: mediaProbe,
                audioExport: audioExport,
                queue: queue,
                engine: engine,
                onPreviousTrack: () {
                  unawaited(
                    ref
                        .read(playbackQueueControllerProvider.notifier)
                        .playPrevious(),
                  );
                },
                onNextTrack: () {
                  unawaited(
                    ref
                        .read(playbackQueueControllerProvider.notifier)
                        .playNext(),
                  );
                },
                onCyclePlaybackMode: () {
                  ref
                      .read(playbackQueueControllerProvider.notifier)
                      .cyclePlaybackMode();
                },
                onExtractAudio:
                    currentMedia == null
                        ? null
                        : () => _extractAudio(ref, currentMedia),
                onCancelAudioExport: () {
                  unawaited(
                    ref.read(audioExportControllerProvider.notifier).cancel(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickMedia(WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: [...audioExtensions, ...videoExtensions],
      dialogTitle: '添加音视频文件',
    );
    final paths =
        result?.files
            .map((file) => file.path)
            .whereType<String>()
            .where(isSupportedMediaPath)
            .toList();
    if (paths == null || paths.isEmpty) {
      return;
    }

    await ref.read(playbackQueueControllerProvider.notifier).addItems([
      for (final path in paths)
        MediaItem.fromPath(path, kind: mediaKindFromPath(path)),
    ], playFirst: true);
  }

  Future<void> _pickFolder(WidgetRef ref) async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: '打开本地媒体文件夹',
      lockParentWindow: true,
    );
    if (path == null) {
      return;
    }

    await ref
        .read(playbackQueueControllerProvider.notifier)
        .loadDirectory(path);
  }

  Future<void> _pickScenery(WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: const ['bmp', 'jpeg', 'jpg', 'png', 'webp'],
      dialogTitle: '选择播放背景图片',
    );
    final paths =
        result?.files
            .map((file) => file.path)
            .whereType<String>()
            .where((path) => File(path).existsSync())
            .toList();

    if (paths == null || paths.isEmpty) {
      return;
    }

    ref.read(sceneryImagePathsProvider.notifier).replaceAll(paths);
  }

  Future<void> _extractAudio(WidgetRef ref, MediaItem item) async {
    final outputPath = await FilePicker.saveFile(
      dialogTitle: '导出音频',
      fileName: '${item.title}.flac',
      initialDirectory: p.dirname(item.path),
      type: FileType.custom,
      allowedExtensions: const ['flac'],
      lockParentWindow: true,
    );
    if (outputPath == null) {
      return;
    }

    unawaited(
      ref
          .read(audioExportControllerProvider.notifier)
          .extractAudio(inputPath: item.path, outputPath: outputPath),
    );
  }

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_CreatePlaylistResult>(
      context: context,
      builder: (context) => const _CreatePlaylistDialog(),
    );
    if (result == null) {
      return;
    }

    await ref
        .read(playbackQueueControllerProvider.notifier)
        .createPlaylist(result.name);
  }

  Future<void> _addFromLibrary(
    BuildContext context,
    WidgetRef ref,
    String playlistId,
  ) async {
    final queue = ref.read(playbackQueueControllerProvider);
    final items = await showDialog<List<MediaItem>>(
      context: context,
      builder: (context) => _AddFromLibraryDialog(queue: queue),
    );
    if (items == null || items.isEmpty) {
      return;
    }

    ref
        .read(playbackQueueControllerProvider.notifier)
        .addItemsToPlaylist(playlistId, items);
  }

  Future<void> _renamePlaylist(
    BuildContext context,
    WidgetRef ref,
    HeniPlaylist playlist,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder:
          (context) => _TextEditDialog(
            title: '重命名歌单',
            initialValue: playlist.name,
            hintText: '歌单名称',
            actionText: '保存',
          ),
    );
    if (name == null) {
      return;
    }

    ref
        .read(playbackQueueControllerProvider.notifier)
        .renamePlaylist(playlist.id, name);
  }

  Future<void> _editPlaylistDescription(
    BuildContext context,
    WidgetRef ref,
    HeniPlaylist playlist,
  ) async {
    final description = await showDialog<String>(
      context: context,
      builder:
          (context) => _TextEditDialog(
            title: '歌单说明',
            initialValue: playlist.description,
            hintText: '写一点关于这个歌单的说明',
            actionText: '保存',
            maxLines: 4,
          ),
    );
    if (description == null) {
      return;
    }

    ref
        .read(playbackQueueControllerProvider.notifier)
        .updatePlaylistDescription(playlist.id, description);
  }

  Future<void> _confirmDeletePlaylist(
    BuildContext context,
    WidgetRef ref,
    HeniPlaylist playlist,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('删除歌单'),
            content: Text('确定删除“${playlist.name}”吗？不会删除本地音频文件。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
    );
    if (confirmed != true) {
      return;
    }

    ref
        .read(playbackQueueControllerProvider.notifier)
        .deletePlaylist(playlist.id);
  }
}

class _TopNavigation extends ConsumerWidget {
  const _TopNavigation({
    required this.palette,
    required this.queue,
    required this.uiStyle,
  });

  final HeniPalette palette;
  final PlaybackQueueState queue;
  final HeniUiStyle uiStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          palette.seed.withValues(alpha: 0.14),
          palette.surface,
        ),
        border: Border(
          bottom: BorderSide(color: palette.seed.withValues(alpha: 0.28)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 176,
            child: Text(
              'Heni',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          _StyleTabs(active: uiStyle),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _TopPaletteChooser(active: palette),
              ),
            ),
          ),
          _SettingsMenu(queue: queue),
        ],
      ),
    );
  }
}

class _StyleTabs extends ConsumerWidget {
  const _StyleTabs({required this.active});

  final HeniUiStyle active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<HeniUiStyle>(
      segments: [
        for (final style in HeniUiStyle.values)
          ButtonSegment<HeniUiStyle>(value: style, label: Text(style.label)),
      ],
      selected: {active},
      onSelectionChanged: (selection) {
        ref.read(activeUiStyleProvider.notifier).select(selection.single);
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.palette,
    required this.queue,
    required this.onCreatePlaylist,
    required this.onSelectPlaylist,
    required this.onAddFromLibrary,
    required this.onRenamePlaylist,
    required this.onEditDescription,
    required this.onDeletePlaylist,
  });

  final HeniPalette palette;
  final PlaybackQueueState queue;
  final VoidCallback onCreatePlaylist;
  final ValueChanged<String> onSelectPlaylist;
  final ValueChanged<String> onAddFromLibrary;
  final ValueChanged<HeniPlaylist> onRenamePlaylist;
  final ValueChanged<HeniPlaylist> onEditDescription;
  final ValueChanged<HeniPlaylist> onDeletePlaylist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 248,
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          palette.seed.withValues(alpha: 0.1),
          palette.surface,
        ),
        border: Border(
          right: BorderSide(color: palette.seed.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SidebarSectionHeader(
            title: '本地音乐',
            trailingText: '${queue.library.items.length} 首',
          ),
          const SizedBox(height: 8),
          _PlaylistTile(
            palette: palette,
            playlist: queue.library,
            selected: queue.activePlaylistId == queue.library.id,
            onTap: () => onSelectPlaylist(queue.library.id),
          ),
          const SizedBox(height: 20),
          _SidebarSectionHeader(
            title: '我的歌单',
            action: IconButton(
              tooltip: '新建歌单',
              onPressed: onCreatePlaylist,
              icon: const Icon(Icons.add),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: 2,
            child:
                queue.playlists.isEmpty
                    ? Text(
                      '从曲库挑歌加入歌单。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.48),
                      ),
                    )
                    : ListView(
                      children: [
                        for (final playlist in queue.playlists)
                          _PlaylistTile(
                            palette: palette,
                            playlist: playlist,
                            selected: playlist.id == queue.activePlaylistId,
                            onTap: () => onSelectPlaylist(playlist.id),
                            onAddFromLibrary:
                                () => onAddFromLibrary(playlist.id),
                            onRename: () => onRenamePlaylist(playlist),
                            onEditDescription:
                                () => onEditDescription(playlist),
                            onDelete: () => onDeletePlaylist(playlist),
                          ),
                      ],
                    ),
          ),
          const Spacer(),
          if (queue.statusMessage != null) ...[
            Text(
              queue.statusMessage!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.58),
              ),
            ),
          ],
          if (queue.lastError != null) ...[
            const SizedBox(height: 8),
            Text(
              queue.lastError!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SidebarSectionHeader extends StatelessWidget {
  const _SidebarSectionHeader({
    required this.title,
    this.action,
    this.trailingText,
  });

  final String title;
  final Widget? action;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 34,
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          if (trailingText != null)
            Text(
              trailingText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.palette,
    required this.playlist,
    required this.selected,
    required this.onTap,
    this.onAddFromLibrary,
    this.onRename,
    this.onEditDescription,
    this.onDelete,
  });

  final HeniPalette palette;
  final HeniPlaylist playlist;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onAddFromLibrary;
  final VoidCallback? onRename;
  final VoidCallback? onEditDescription;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tint = palette.seed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Color.alphaBlend(
          tint.withValues(alpha: selected ? 0.26 : 0.07),
          selected ? palette.surfaceAlt : palette.surface,
        ),
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          dense: true,
          selected: selected,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text(
            playlist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle:
              playlist.description.isEmpty
                  ? null
                  : Text(
                    playlist.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          trailing:
              onDelete == null
                  ? Text('${playlist.items.length}')
                  : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${playlist.items.length}'),
                      const SizedBox(width: 4),
                      PopupMenuButton<_PlaylistAction>(
                        tooltip: '歌单选项',
                        icon: const Icon(Icons.more_vert, size: 18),
                        onSelected: (action) {
                          switch (action) {
                            case _PlaylistAction.addFromLibrary:
                              onAddFromLibrary?.call();
                            case _PlaylistAction.rename:
                              onRename?.call();
                            case _PlaylistAction.description:
                              onEditDescription?.call();
                            case _PlaylistAction.delete:
                              onDelete?.call();
                          }
                        },
                        itemBuilder:
                            (context) => const [
                              PopupMenuItem<_PlaylistAction>(
                                value: _PlaylistAction.addFromLibrary,
                                child: Text('从曲库添加'),
                              ),
                              PopupMenuItem<_PlaylistAction>(
                                value: _PlaylistAction.rename,
                                child: Text('重命名'),
                              ),
                              PopupMenuItem<_PlaylistAction>(
                                value: _PlaylistAction.description,
                                child: Text('编辑说明'),
                              ),
                              PopupMenuDivider(),
                              PopupMenuItem<_PlaylistAction>(
                                value: _PlaylistAction.delete,
                                child: Text('删除'),
                              ),
                            ],
                      ),
                    ],
                  ),
          onTap: onTap,
        ),
      ),
    );
  }
}

enum _PlaylistAction { addFromLibrary, rename, description, delete }

class _ContentArea extends StatelessWidget {
  const _ContentArea({
    required this.palette,
    required this.uiStyle,
    required this.sceneryImages,
    required this.queue,
    required this.currentMedia,
    required this.mediaProbe,
    required this.lyrics,
    required this.engine,
    required this.videoController,
    required this.onPickScenery,
    required this.onPickMedia,
    required this.onPickFolder,
    required this.onPlayIndex,
    required this.onAddToPlaylist,
    required this.onAddFromLibrary,
  });

  final HeniPalette palette;
  final HeniUiStyle uiStyle;
  final List<String> sceneryImages;
  final PlaybackQueueState queue;
  final MediaItem? currentMedia;
  final AsyncValue<MediaProbe?> mediaProbe;
  final AsyncValue<List<LyricLine>> lyrics;
  final PlaybackEngine engine;
  final VideoController videoController;
  final VoidCallback onPickScenery;
  final VoidCallback onPickMedia;
  final VoidCallback onPickFolder;
  final ValueChanged<int> onPlayIndex;
  final void Function(String playlistId, MediaItem item) onAddToPlaylist;
  final ValueChanged<String> onAddFromLibrary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ContentHeader(
            uiStyle: uiStyle,
            queue: queue,
            currentMedia: currentMedia,
            onPickScenery: onPickScenery,
            onPickMedia: onPickMedia,
            onPickFolder: onPickFolder,
            onAddFromLibrary: onAddFromLibrary,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: switch (uiStyle) {
              HeniUiStyle.library => _LibraryContent(
                queue: queue,
                onPlayIndex: onPlayIndex,
                onAddToPlaylist: onAddToPlaylist,
              ),
              _ => _SceneryContent(
                palette: palette,
                imagePaths: sceneryImages,
                currentMedia: currentMedia,
                mediaProbe: mediaProbe,
                lyrics: lyrics,
                engine: engine,
                videoController: videoController,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _ContentHeader extends StatelessWidget {
  const _ContentHeader({
    required this.uiStyle,
    required this.queue,
    required this.currentMedia,
    required this.onPickScenery,
    required this.onPickMedia,
    required this.onPickFolder,
    required this.onAddFromLibrary,
  });

  final HeniUiStyle uiStyle;
  final PlaybackQueueState queue;
  final MediaItem? currentMedia;
  final VoidCallback onPickScenery;
  final VoidCallback onPickMedia;
  final VoidCallback onPickFolder;
  final ValueChanged<String> onAddFromLibrary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              switch (uiStyle) {
                HeniUiStyle.scenery => '播放美景',
                HeniUiStyle.library => queue.activePlaylist.name,
              },
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              currentMedia?.path ?? '选择本地音视频文件夹，开始构建你的播放空间',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.56),
              ),
            ),
          ],
        ),
        const Spacer(),
        if (uiStyle == HeniUiStyle.scenery)
          OutlinedButton(onPressed: onPickScenery, child: const Text('更换背景'))
        else if (queue.activePlaylist.id == heniLibraryPlaylistId) ...[
          OutlinedButton(onPressed: onPickFolder, child: const Text('导入文件夹')),
          const SizedBox(width: 8),
          FilledButton(onPressed: onPickMedia, child: const Text('添加文件')),
        ] else ...[
          FilledButton(
            onPressed: () => onAddFromLibrary(queue.activePlaylist.id),
            child: const Text('从曲库添加'),
          ),
        ],
      ],
    );
  }
}

class _SceneryContent extends StatelessWidget {
  const _SceneryContent({
    required this.palette,
    required this.imagePaths,
    required this.currentMedia,
    required this.mediaProbe,
    required this.lyrics,
    required this.engine,
    required this.videoController,
  });

  final HeniPalette palette;
  final List<String> imagePaths;
  final MediaItem? currentMedia;
  final AsyncValue<MediaProbe?> mediaProbe;
  final AsyncValue<List<LyricLine>> lyrics;
  final PlaybackEngine engine;
  final VideoController videoController;

  @override
  Widget build(BuildContext context) {
    final isVideo = currentMedia?.kind == MediaKind.video;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          SceneryStage(imagePaths: imagePaths, palette: palette),
          if (isVideo)
            Align(
              alignment: Alignment.center,
              child: FractionallySizedBox(
                widthFactor: 0.72,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _VideoStage(videoController: videoController),
                ),
              ),
            )
          else
            _AudioHero(currentMedia: currentMedia, mediaProbe: mediaProbe),
          if (currentMedia != null)
            Positioned(
              right: 24,
              bottom: 24,
              child: _LyricsPanel(lyrics: lyrics, engine: engine),
            ),
        ],
      ),
    );
  }
}

class _LyricsPanel extends StatelessWidget {
  const _LyricsPanel({required this.lyrics, required this.engine});

  final AsyncValue<List<LyricLine>> lyrics;
  final PlaybackEngine engine;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: lyrics.when(
            data: (lines) {
              if (lines.isEmpty) {
                return const _LyricsEmptyState();
              }
              return StreamBuilder<Duration>(
                stream: engine.position,
                initialData: Duration.zero,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final currentIndex = _currentLyricIndex(lines, position);
                  final visible = _visibleLyrics(lines, currentIndex);

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final entry in visible)
                        Text(
                          entry.value.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color:
                                entry.key == currentIndex
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.white.withValues(alpha: 0.58),
                            fontWeight:
                                entry.key == currentIndex
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                          ),
                        ),
                    ],
                  );
                },
              );
            },
            loading: () => const Text('正在读取歌词...'),
            error: (error, stackTrace) => const _LyricsEmptyState(),
          ),
        ),
      ),
    );
  }

  int _currentLyricIndex(List<LyricLine> lines, Duration position) {
    if (lines.every((line) => line.time == null)) {
      return 0;
    }

    var index = 0;
    for (var i = 0; i < lines.length; i += 1) {
      final time = lines[i].time;
      if (time != null && time <= position) {
        index = i;
      }
    }
    return index;
  }

  List<MapEntry<int, LyricLine>> _visibleLyrics(
    List<LyricLine> lines,
    int currentIndex,
  ) {
    final start = (currentIndex - 1).clamp(0, lines.length - 1);
    final end = (currentIndex + 2).clamp(0, lines.length);
    return [for (var i = start; i < end; i += 1) MapEntry(i, lines[i])];
  }
}

class _LyricsEmptyState extends StatelessWidget {
  const _LyricsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Text(
      '暂无歌词\n可放置同名 .lrc 或 .txt',
      textAlign: TextAlign.right,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.white.withValues(alpha: 0.54),
      ),
    );
  }
}

class _VideoStage extends StatelessWidget {
  const _VideoStage({required this.videoController});

  final VideoController videoController;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Video(
          controller: videoController,
          fit: BoxFit.contain,
          fill: Colors.black,
          controls: null,
        ),
      ),
    );
  }
}

class _AudioHero extends StatelessWidget {
  const _AudioHero({required this.currentMedia, required this.mediaProbe});

  final MediaItem? currentMedia;
  final AsyncValue<MediaProbe?> mediaProbe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 180,
              height: 180,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.34),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: const Icon(Icons.graphic_eq, size: 68),
            ),
            const SizedBox(height: 28),
            Text(
              currentMedia?.title ?? '还没有播放内容',
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _MediaProbeDetails(probe: mediaProbe, centered: true),
          ],
        ),
      ),
    );
  }
}

class _LibraryContent extends StatelessWidget {
  const _LibraryContent({
    required this.queue,
    required this.onPlayIndex,
    required this.onAddToPlaylist,
  });

  final PlaybackQueueState queue;
  final ValueChanged<int> onPlayIndex;
  final void Function(String playlistId, MediaItem item) onAddToPlaylist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = queue.activePlaylist.items;
    final browsingLibrary = queue.activePlaylist.id == queue.library.id;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Row(
              children: [
                Expanded(child: Text('歌曲', style: theme.textTheme.labelLarge)),
                SizedBox(
                  width: 72,
                  child: Text('类型', style: theme.textTheme.labelLarge),
                ),
                SizedBox(
                  width: browsingLibrary ? 390 : 290,
                  child: Text('来源', style: theme.textTheme.labelLarge),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                items.isEmpty
                    ? Center(
                      child: Text(
                        browsingLibrary
                            ? '曲库还没有内容\n添加文件或导入文件夹开始整理'
                            : '这个歌单还没有歌曲\n回到曲库选择歌曲加入',
                        textAlign: TextAlign.center,
                      ),
                    )
                    : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final selected = queue.isCurrentItem(item);
                        return ListTile(
                          selected: selected,
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            item.path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: SizedBox(
                            width: browsingLibrary ? 430 : 320,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 72,
                                  child: Text(
                                    item.kind == MediaKind.video ? '视频' : '音频',
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    p.dirname(item.path),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (browsingLibrary) ...[
                                  const SizedBox(width: 12),
                                  _AddToPlaylistMenu(
                                    playlists: queue.playlists,
                                    onSelected:
                                        (playlistId) =>
                                            onAddToPlaylist(playlistId, item),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          onTap: () => onPlayIndex(index),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _AddToPlaylistMenu extends StatelessWidget {
  const _AddToPlaylistMenu({required this.playlists, required this.onSelected});

  final List<HeniPlaylist> playlists;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return Tooltip(
        message: '先新建歌单',
        child: OutlinedButton(onPressed: null, child: const Text('加入歌单')),
      );
    }

    return PopupMenuButton<String>(
      tooltip: '加入歌单',
      onSelected: onSelected,
      itemBuilder:
          (context) => [
            for (final playlist in playlists)
              PopupMenuItem<String>(
                value: playlist.id,
                child: Text(playlist.name),
              ),
          ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.36),
          ),
        ),
        child: Text(
          '加入歌单',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _AddFromLibraryDialog extends StatefulWidget {
  const _AddFromLibraryDialog({required this.queue});

  final PlaybackQueueState queue;

  @override
  State<_AddFromLibraryDialog> createState() => _AddFromLibraryDialogState();
}

class _AddFromLibraryDialogState extends State<_AddFromLibraryDialog> {
  final _queryController = TextEditingController();
  final _selectedPaths = <String>{};
  var _query = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.queue.activePlaylist;
    final existingPaths =
        target.items.map((item) => item.path.toLowerCase()).toSet();
    final query = _query.trim().toLowerCase();
    final candidates =
        widget.queue.library.items.where((item) {
          if (existingPaths.contains(item.path.toLowerCase())) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }
          return item.title.toLowerCase().contains(query) ||
              item.path.toLowerCase().contains(query);
        }).toList();

    return AlertDialog(
      title: Text('从曲库添加到“${target.name}”'),
      content: SizedBox(
        width: 720,
        height: 520,
        child: Column(
          children: [
            TextField(
              controller: _queryController,
              decoration: const InputDecoration(
                hintText: '搜索曲库',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child:
                  candidates.isEmpty
                      ? const Center(child: Text('没有可添加的歌曲'))
                      : ListView.builder(
                        itemCount: candidates.length,
                        itemBuilder: (context, index) {
                          final item = candidates[index];
                          final selected = _selectedPaths.contains(item.path);
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (value) {
                              setState(() {
                                if (value ?? false) {
                                  _selectedPaths.add(item.path);
                                } else {
                                  _selectedPaths.remove(item.path);
                                }
                              });
                            },
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              item.path,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            secondary: Text(
                              item.kind == MediaKind.video ? '视频' : '音频',
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              candidates.isEmpty
                  ? null
                  : () {
                    setState(() {
                      _selectedPaths
                        ..clear()
                        ..addAll(candidates.map((item) => item.path));
                    });
                  },
          child: const Text('全选当前列表'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed:
              _selectedPaths.isEmpty
                  ? null
                  : () {
                    final selectedItems = [
                      for (final item in widget.queue.library.items)
                        if (_selectedPaths.contains(item.path)) item,
                    ];
                    Navigator.of(context).pop(selectedItems);
                  },
          child: Text('添加 ${_selectedPaths.length} 首'),
        ),
      ],
    );
  }
}

class _BottomPlayerBar extends StatelessWidget {
  const _BottomPlayerBar({
    required this.palette,
    required this.currentMedia,
    required this.mediaProbe,
    required this.audioExport,
    required this.queue,
    required this.engine,
    required this.onPreviousTrack,
    required this.onNextTrack,
    required this.onCyclePlaybackMode,
    required this.onExtractAudio,
    required this.onCancelAudioExport,
  });

  final HeniPalette palette;
  final MediaItem? currentMedia;
  final AsyncValue<MediaProbe?> mediaProbe;
  final AudioExportState audioExport;
  final PlaybackQueueState queue;
  final PlaybackEngine engine;
  final VoidCallback onPreviousTrack;
  final VoidCallback onNextTrack;
  final VoidCallback onCyclePlaybackMode;
  final VoidCallback? onExtractAudio;
  final VoidCallback onCancelAudioExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 124,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              palette.seed.withValues(alpha: 0.18),
              palette.surfaceAlt,
            ),
            Color.alphaBlend(
              palette.seed.withValues(alpha: 0.08),
              palette.surface,
            ),
          ],
        ),
        border: Border(
          top: BorderSide(color: palette.seed.withValues(alpha: 0.28)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
        child: Row(
          children: [
            _NowPlayingSummary(
              palette: palette,
              currentMedia: currentMedia,
              mediaProbe: mediaProbe,
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TransportControls(
                    engine: engine,
                    onPreviousTrack: onPreviousTrack,
                    onNextTrack: onNextTrack,
                  ),
                  const SizedBox(height: 6),
                  _ProgressBar(engine: engine),
                ],
              ),
            ),
            const SizedBox(width: 24),
            _UtilityControls(
              palette: palette,
              mode: queue.playbackMode,
              engine: engine,
              state: audioExport,
              sourceDuration: mediaProbe.when(
                data: (probe) => probe?.duration,
                error: (error, stackTrace) => null,
                loading: () => null,
              ),
              onCyclePlaybackMode: onCyclePlaybackMode,
              onExtract: onExtractAudio,
              onCancel: onCancelAudioExport,
            ),
          ],
        ),
      ),
    );
  }
}

class _NowPlayingSummary extends StatelessWidget {
  const _NowPlayingSummary({
    required this.palette,
    required this.currentMedia,
    required this.mediaProbe,
  });

  final HeniPalette palette;
  final MediaItem? currentMedia;
  final AsyncValue<MediaProbe?> mediaProbe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 286,
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                palette.seed.withValues(alpha: 0.18),
                palette.surfaceAlt,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.seed.withValues(alpha: 0.32)),
            ),
            child: Icon(
              currentMedia?.kind == MediaKind.video
                  ? Icons.movie_outlined
                  : Icons.music_note_outlined,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentMedia?.title ?? '未播放',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                _MediaProbeDetails(probe: mediaProbe),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UtilityControls extends StatelessWidget {
  const _UtilityControls({
    required this.palette,
    required this.mode,
    required this.engine,
    required this.state,
    required this.sourceDuration,
    required this.onCyclePlaybackMode,
    required this.onExtract,
    required this.onCancel,
  });

  final HeniPalette palette;
  final HeniPlaybackMode mode;
  final PlaybackEngine engine;
  final AudioExportState state;
  final Duration? sourceDuration;
  final VoidCallback onCyclePlaybackMode;
  final VoidCallback? onExtract;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          palette.seed.withValues(alpha: 0.14),
          palette.surfaceAlt,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.seed.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlaybackModeIconButton(mode: mode, onPressed: onCyclePlaybackMode),
          _VolumeMenuButton(engine: engine, palette: palette),
          _ExportActions(
            state: state,
            sourceDuration: sourceDuration,
            onExtract: onExtract,
            onCancel: onCancel,
          ),
        ],
      ),
    );
  }
}

class _ExportActions extends StatelessWidget {
  const _ExportActions({
    required this.state,
    required this.sourceDuration,
    required this.onExtract,
    required this.onCancel,
  });

  final AudioExportState state;
  final Duration? sourceDuration;
  final VoidCallback? onExtract;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final progress = state.fraction(sourceDuration);

    if (state.isRunning) {
      return SizedBox(
        width: 92,
        child: Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            IconButton(
              tooltip: '取消导出',
              onPressed: onCancel,
              icon: const Icon(Icons.stop_circle_outlined),
            ),
          ],
        ),
      );
    }

    final statusIcon = switch (state.status) {
      AudioExportStatus.completed => Icons.check_circle_outline,
      AudioExportStatus.failed => Icons.error_outline,
      AudioExportStatus.cancelled => Icons.cancel_outlined,
      AudioExportStatus.idle => Icons.audio_file_outlined,
      AudioExportStatus.running => Icons.audio_file_outlined,
    };
    final tooltip = switch (state.status) {
      AudioExportStatus.completed => '音频已导出',
      AudioExportStatus.failed => state.errorMessage ?? '导出失败',
      AudioExportStatus.cancelled => '已取消导出',
      AudioExportStatus.idle => '导出 FLAC',
      AudioExportStatus.running => '导出中',
    };

    return IconButton(
      tooltip: tooltip,
      onPressed: state.status == AudioExportStatus.idle ? onExtract : null,
      icon: Icon(statusIcon),
    );
  }
}

class _VolumeMenuButton extends StatelessWidget {
  const _VolumeMenuButton({required this.engine, required this.palette});

  final PlaybackEngine engine;
  final HeniPalette palette;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        fixedSize: const WidgetStatePropertyAll(Size(44, 232)),
        minimumSize: const WidgetStatePropertyAll(Size.zero),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      alignmentOffset: const Offset(1, -10),
      menuChildren: [
        SizedBox(
          width: 44,
          height: 232,
          child: Center(child: _VolumeSlider(engine: engine, palette: palette)),
        ),
      ],
      builder: (context, controller, child) {
        return StreamBuilder<double>(
          stream: engine.volume,
          initialData: engine.currentVolume,
          builder: (context, snapshot) {
            final volume =
                (snapshot.data ?? engine.currentVolume)
                    .clamp(0, 100)
                    .toDouble();
            final icon = switch (volume.round()) {
              <= 0 => Icons.volume_off,
              < 50 => Icons.volume_down,
              _ => Icons.volume_up,
            };

            return IconButton(
              tooltip: '音量',
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              icon: Icon(icon),
            );
          },
        );
      },
    );
  }
}

class _VolumeSlider extends StatefulWidget {
  const _VolumeSlider({required this.engine, required this.palette});

  final PlaybackEngine engine;
  final HeniPalette palette;

  @override
  State<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<_VolumeSlider> {
  late double _volume;
  StreamSubscription<double>? _volumeSubscription;

  @override
  void initState() {
    super.initState();
    _volume = widget.engine.currentVolume.clamp(0, 100).toDouble();
    _listenToVolume();
  }

  @override
  void didUpdateWidget(covariant _VolumeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.engine != widget.engine) {
      unawaited(_volumeSubscription?.cancel());
      _volume = widget.engine.currentVolume.clamp(0, 100).toDouble();
      _listenToVolume();
    }
  }

  @override
  void dispose() {
    unawaited(_volumeSubscription?.cancel());
    super.dispose();
  }

  void _listenToVolume() {
    _volumeSubscription = widget.engine.volume.listen((volume) {
      if (!mounted) {
        return;
      }
      setState(() {
        _volume = volume.clamp(0, 100).toDouble();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 224,
      child: LayoutBuilder(
        builder: (context, constraints) {
          void updateFromLocalPosition(Offset localPosition) {
            final height = constraints.maxHeight;
            final dy = localPosition.dy.clamp(0.0, height);
            final nextVolume =
                ((1 - dy / height) * 100).clamp(0.0, 100.0).toDouble();
            setState(() {
              _volume = nextVolume;
            });
            unawaited(widget.engine.setVolume(nextVolume));
          }

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown:
                (details) => updateFromLocalPosition(details.localPosition),
            onVerticalDragDown:
                (details) => updateFromLocalPosition(details.localPosition),
            onVerticalDragUpdate:
                (details) => updateFromLocalPosition(details.localPosition),
            child: CustomPaint(
              painter: _VolumeRailPainter(
                volume: _volume,
                color: widget.palette.seed,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VolumeRailPainter extends CustomPainter {
  const _VolumeRailPainter({required this.volume, required this.color});

  final double volume;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final top = 14.0;
    final bottom = size.height - 14;
    final x = size.width / 2;
    final height = bottom - top;
    final normalized = (volume / 100).clamp(0.0, 1.0).toDouble();
    final thumbY = bottom - height * normalized;
    final thumbCenter = Offset(x, thumbY);
    final outlineColor =
        color.computeLuminance() > 0.62
            ? Colors.black.withValues(alpha: 0.42)
            : Colors.white.withValues(alpha: 0.48);

    final outlinePaint =
        Paint()
          ..color = outlineColor
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round;
    final glowPaint =
        Paint()
          ..color = color.withValues(alpha: 0.2)
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final barPaint =
        Paint()
          ..color = color
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round;

    if (normalized > 0) {
      final start = Offset(x, bottom);
      canvas.drawLine(start, thumbCenter, glowPaint);
      canvas.drawLine(start, thumbCenter, outlinePaint);
      canvas.drawLine(start, thumbCenter, barPaint);
    }

    final thumbOutline =
        Paint()
          ..color = outlineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    final thumbPaint = Paint()..color = color;
    canvas.drawCircle(thumbCenter, 10, thumbPaint);
    canvas.drawCircle(thumbCenter, 10, thumbOutline);
  }

  @override
  bool shouldRepaint(covariant _VolumeRailPainter oldDelegate) {
    return oldDelegate.volume != volume || oldDelegate.color != color;
  }
}

class _SettingsMenu extends ConsumerWidget {
  const _SettingsMenu({required this.queue});

  final PlaybackQueueState queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: '基础设置',
      icon: const Icon(Icons.tune_outlined),
      onSelected: (value) {
        final controller = ref.read(playbackQueueControllerProvider.notifier);
        switch (value) {
          case 'recursive':
            controller.setRecursiveScan(!queue.recursiveScan);
          case 'includeVideo':
            controller.setIncludeVideo(!queue.includeVideo);
          case 'autoplay':
            controller.setAutoplayOnLoad(!queue.autoplayOnLoad);
        }
      },
      itemBuilder:
          (context) => [
            CheckedPopupMenuItem<String>(
              value: 'recursive',
              checked: queue.recursiveScan,
              child: const Text('递归扫描文件夹'),
            ),
            CheckedPopupMenuItem<String>(
              value: 'includeVideo',
              checked: queue.includeVideo,
              child: const Text('包含视频文件'),
            ),
            CheckedPopupMenuItem<String>(
              value: 'autoplay',
              checked: queue.autoplayOnLoad,
              child: const Text('加载后自动播放'),
            ),
          ],
    );
  }
}

class _CreatePlaylistResult {
  const _CreatePlaylistResult({required this.name});

  final String name;
}

class _CreatePlaylistDialog extends StatefulWidget {
  const _CreatePlaylistDialog();

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建歌单'),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '歌单名称',
            helperText: '创建后可从曲库加入歌曲，不复制源文件',
          ),
          onSubmitted: _submit,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => _submit(_controller.text),
          child: const Text('创建'),
        ),
      ],
    );
  }

  void _submit(String value) {
    final name = value.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.of(context).pop(_CreatePlaylistResult(name: name));
  }
}

class _TextEditDialog extends StatefulWidget {
  const _TextEditDialog({
    required this.title,
    required this.initialValue,
    required this.hintText,
    required this.actionText,
    this.maxLines = 1,
  });

  final String title;
  final String initialValue;
  final String hintText;
  final String actionText;
  final int maxLines;

  @override
  State<_TextEditDialog> createState() => _TextEditDialogState();
}

class _TextEditDialogState extends State<_TextEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 390,
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: widget.maxLines,
          decoration: InputDecoration(hintText: widget.hintText),
          onSubmitted: widget.maxLines == 1 ? (_) => _submit() : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.actionText)),
      ],
    );
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }
}

class _MediaProbeDetails extends StatelessWidget {
  const _MediaProbeDetails({required this.probe, this.centered = false});

  final AsyncValue<MediaProbe?> probe;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return probe.when(
      data: (data) {
        if (data == null) {
          return _MetadataLine(
            icon: Icons.info_outline,
            text: '等待读取媒体信息',
            centered: centered,
          );
        }

        final primaryVideo = data.primaryVideoStream;
        final primaryAudio = data.primaryAudioStream;
        final pieces = <String>[
          if (data.formatName != null) data.formatName!,
          if (primaryVideo?.codecName case final String codec) '视频 $codec',
          if (primaryVideo?.displaySize case final String size) size,
          if (primaryAudio?.codecName case final String codec) '音频 $codec',
          if (primaryAudio?.sampleRate case final int sampleRate)
            '${sampleRate ~/ 1000} kHz',
          if (primaryAudio?.channels case final int channels)
            channels == 1 ? '单声道' : '$channels 声道',
          if (data.duration case final Duration duration)
            _formatDurationLong(duration),
        ];

        return _MetadataLine(
          icon: data.hasVideo ? Icons.movie_filter_outlined : Icons.graphic_eq,
          text: pieces.isEmpty ? '没有读取到流信息' : pieces.join(' / '),
          centered: centered,
        );
      },
      loading:
          () => _MetadataLine(
            icon: Icons.manage_search_outlined,
            text: '正在解析容器和编码信息...',
            centered: centered,
          ),
      error:
          (error, stackTrace) => _MetadataLine(
            icon: Icons.warning_amber_outlined,
            text: '媒体信息读取失败',
            tooltip: error.toString(),
            centered: centered,
          ),
    );
  }

  String _formatDurationLong(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _MetadataLine extends StatelessWidget {
  const _MetadataLine({
    required this.icon,
    required this.text,
    this.tooltip,
    this.centered = false,
  });

  final IconData icon;
  final String text;
  final String? tooltip;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment:
          centered ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: Colors.white.withValues(alpha: 0.62)),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.62),
            ),
          ),
        ),
      ],
    );

    if (tooltip == null) {
      return content;
    }

    return Tooltip(message: tooltip!, child: content);
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.engine});

  final PlaybackEngine engine;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: engine.duration,
      initialData: Duration.zero,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;

        return StreamBuilder<Duration>(
          stream: engine.position,
          initialData: Duration.zero,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final max = duration.inMilliseconds.toDouble().clamp(
              1,
              double.infinity,
            );
            final value =
                position.inMilliseconds.clamp(0, max.toInt()).toDouble();

            return Row(
              children: [
                SizedBox(width: 48, child: Text(_formatDuration(position))),
                Expanded(
                  child: Slider(
                    value: value,
                    max: max.toDouble(),
                    onChanged: (nextValue) {
                      engine.seek(Duration(milliseconds: nextValue.round()));
                    },
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    _formatDuration(duration),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({
    required this.engine,
    required this.onPreviousTrack,
    required this.onNextTrack,
  });

  final PlaybackEngine engine;
  final VoidCallback onPreviousTrack;
  final VoidCallback onNextTrack;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: engine.playing,
      initialData: false,
      builder: (context, snapshot) {
        final playing = snapshot.data ?? false;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Tooltip(
              message: '上一首',
              child: IconButton(
                onPressed: onPreviousTrack,
                icon: const Icon(Icons.skip_previous),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: IconButton.filled(
                tooltip: playing ? '暂停' : '播放',
                onPressed: () {
                  if (playing) {
                    engine.pause();
                  } else {
                    engine.play();
                  }
                },
                iconSize: 32,
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              ),
            ),
            Tooltip(
              message: '下一首',
              child: IconButton(
                onPressed: onNextTrack,
                icon: const Icon(Icons.skip_next),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlaybackModeIconButton extends StatelessWidget {
  const _PlaybackModeIconButton({required this.mode, required this.onPressed});

  final HeniPlaybackMode mode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = mode != HeniPlaybackMode.sequence;

    return Tooltip(
      message: '播放模式：${mode.label}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color:
              active
                  ? theme.colorScheme.primary.withValues(alpha: 0.16)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: IconButton(
          isSelected: active,
          onPressed: onPressed,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Icon(_playbackModeIcon(mode), key: ValueKey(mode)),
          ),
        ),
      ),
    );
  }
}

class _TopPaletteChooser extends ConsumerWidget {
  const _TopPaletteChooser({required this.active});

  final HeniPalette active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final palette in HeniPalette.all)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Tooltip(
                message: palette.name,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    ref.read(activePaletteProvider.notifier).select(palette);
                  },
                  child: _PaletteSwatch(
                    palette: palette,
                    selected: identical(active, palette),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({required this.palette, required this.selected});

  final HeniPalette palette;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: selected ? 34 : 26,
      height: 22,
      decoration: BoxDecoration(
        color: palette.seed,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.24),
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          if (selected)
            BoxShadow(
              color: palette.seed.withValues(alpha: 0.42),
              blurRadius: 10,
              spreadRadius: 1,
            ),
        ],
      ),
    );
  }
}
