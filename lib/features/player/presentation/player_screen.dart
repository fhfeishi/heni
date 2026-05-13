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
import '../../../domain/playback/playback_mode.dart';
import '../../../services/media/playback_engine.dart';
import '../../../services/media/playback_providers.dart';
import '../../scenery/presentation/scenery_stage.dart';
import '../application/audio_export_controller.dart';
import '../application/playback_queue_controller.dart';
import '../application/player_state.dart';

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
    final audioExport = ref.watch(audioExportControllerProvider);
    final engine = ref.watch(playbackEngineProvider);
    final videoController = ref.watch(videoControllerProvider);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _PlaybackStage(
            imagePaths: sceneryImages,
            palette: palette,
            uiStyle: uiStyle,
            currentMedia: currentMedia,
            videoController: videoController,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(
                    currentMedia: currentMedia,
                    queue: queue,
                    uiStyle: uiStyle,
                    onPickMedia: () => _pickMedia(ref),
                    onPickFolder: () => _pickFolder(ref),
                    onPickScenery: () => _pickScenery(ref),
                    onCreatePlaylist: () => _createPlaylist(context, ref),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (uiStyle == HeniUiStyle.library) ...[
                          _LibraryPanel(
                            queue: queue,
                            onSelectPlaylist: (playlistId) {
                              ref
                                  .read(playbackQueueControllerProvider.notifier)
                                  .selectPlaylist(playlistId);
                            },
                            onPlayIndex: (index) {
                              unawaited(
                                ref
                                    .read(
                                      playbackQueueControllerProvider.notifier,
                                    )
                                    .playIndex(index),
                              );
                            },
                          ),
                          const SizedBox(width: 18),
                        ],
                        const Spacer(),
                      ],
                    ),
                  ),
                  _NowPlayingPanel(
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
                    onToggleShuffle: () {
                      ref
                          .read(playbackQueueControllerProvider.notifier)
                          .toggleShuffle();
                    },
                    onCycleRepeat: () {
                      ref
                          .read(playbackQueueControllerProvider.notifier)
                          .cycleRepeatMode();
                    },
                    onExtractAudio: currentMedia == null
                        ? null
                        : () => _extractAudio(ref, currentMedia),
                    onCancelAudioExport: () {
                      unawaited(
                        ref.read(audioExportControllerProvider.notifier).cancel(),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _PaletteStrip(active: palette),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMedia(WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: [...audioExtensions, ...videoExtensions],
    );
    final paths = result?.files
        .map((file) => file.path)
        .whereType<String>()
        .where(isSupportedMediaPath)
        .toList();
    if (paths == null || paths.isEmpty) {
      return;
    }

    await ref.read(playbackQueueControllerProvider.notifier).addItems(
          [
            for (final path in paths)
              MediaItem.fromPath(path, kind: mediaKindFromPath(path)),
          ],
          playFirst: true,
        );
  }

  Future<void> _pickFolder(WidgetRef ref) async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Open media folder',
      lockParentWindow: true,
    );
    if (path == null) {
      return;
    }

    await ref.read(playbackQueueControllerProvider.notifier).loadDirectory(path);
  }

  Future<void> _pickScenery(WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: const ['bmp', 'jpeg', 'jpg', 'png', 'webp'],
    );
    final paths = result?.files
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
      dialogTitle: 'Extract audio',
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
      ref.read(audioExportControllerProvider.notifier).extractAudio(
            inputPath: item.path,
            outputPath: outputPath,
          ),
    );
  }

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _CreatePlaylistDialog(),
    );
    if (name == null) {
      return;
    }

    await ref.read(playbackQueueControllerProvider.notifier).createPlaylist(name);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.currentMedia,
    required this.queue,
    required this.uiStyle,
    required this.onPickMedia,
    required this.onPickFolder,
    required this.onPickScenery,
    required this.onCreatePlaylist,
  });

  final MediaItem? currentMedia;
  final PlaybackQueueState queue;
  final HeniUiStyle uiStyle;
  final VoidCallback onPickMedia;
  final VoidCallback onPickFolder;
  final VoidCallback onPickScenery;
  final VoidCallback onCreatePlaylist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Heni',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                currentMedia?.title ?? 'Pick local media to begin',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
        Tooltip(
          message: 'Choose scenery images',
          child: IconButton.filledTonal(
            onPressed: onPickScenery,
            icon: const Icon(Icons.photo_library_outlined),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Create playlist',
          child: IconButton.filledTonal(
            onPressed: onCreatePlaylist,
            icon: const Icon(Icons.playlist_add_outlined),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Open media folder',
          child: IconButton.filledTonal(
            onPressed: onPickFolder,
            icon: const Icon(Icons.drive_folder_upload_outlined),
          ),
        ),
        const SizedBox(width: 8),
        _SettingsMenu(queue: queue, uiStyle: uiStyle),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Add audio or video files',
          child: FilledButton.icon(
            onPressed: onPickMedia,
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('Add files'),
          ),
        ),
      ],
    );
  }
}

class _PlaybackStage extends StatelessWidget {
  const _PlaybackStage({
    required this.imagePaths,
    required this.palette,
    required this.uiStyle,
    required this.currentMedia,
    required this.videoController,
  });

  final List<String> imagePaths;
  final HeniPalette palette;
  final HeniUiStyle uiStyle;
  final MediaItem? currentMedia;
  final VideoController videoController;

  @override
  Widget build(BuildContext context) {
    final isVideo = currentMedia?.kind == MediaKind.video;

    if (isVideo && uiStyle == HeniUiStyle.cinema) {
      return ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Video(
              controller: videoController,
              fit: BoxFit.contain,
              fill: Colors.black,
              controls: null,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.18),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.52),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        SceneryStage(imagePaths: imagePaths, palette: palette),
        if (isVideo)
          Center(
            child: FractionallySizedBox(
              widthFactor: uiStyle == HeniUiStyle.library ? 0.58 : 0.74,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Video(
                      controller: videoController,
                      fit: BoxFit.contain,
                      fill: Colors.black,
                      controls: null,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SettingsMenu extends ConsumerWidget {
  const _SettingsMenu({required this.queue, required this.uiStyle});

  final PlaybackQueueState queue;
  final HeniUiStyle uiStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Player settings',
      icon: const Icon(Icons.tune_outlined),
      onSelected: (value) {
        final queueController =
            ref.read(playbackQueueControllerProvider.notifier);
        switch (value) {
          case 'style:scenery':
            ref.read(activeUiStyleProvider.notifier).select(HeniUiStyle.scenery);
          case 'style:cinema':
            ref.read(activeUiStyleProvider.notifier).select(HeniUiStyle.cinema);
          case 'style:library':
            ref.read(activeUiStyleProvider.notifier).select(HeniUiStyle.library);
          case 'recursive':
            queueController.setRecursiveScan(!queue.recursiveScan);
          case 'includeVideo':
            queueController.setIncludeVideo(!queue.includeVideo);
          case 'autoplay':
            queueController.setAutoplayOnLoad(!queue.autoplayOnLoad);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          enabled: false,
          child: Text('UI style'),
        ),
        CheckedPopupMenuItem<String>(
          value: 'style:scenery',
          checked: uiStyle == HeniUiStyle.scenery,
          child: const Text('Scenery'),
        ),
        CheckedPopupMenuItem<String>(
          value: 'style:cinema',
          checked: uiStyle == HeniUiStyle.cinema,
          child: const Text('Cinema'),
        ),
        CheckedPopupMenuItem<String>(
          value: 'style:library',
          checked: uiStyle == HeniUiStyle.library,
          child: const Text('Library'),
        ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem<String>(
          value: 'recursive',
          checked: queue.recursiveScan,
          child: const Text('Scan folders recursively'),
        ),
        CheckedPopupMenuItem<String>(
          value: 'includeVideo',
          checked: queue.includeVideo,
          child: const Text('Include video files'),
        ),
        CheckedPopupMenuItem<String>(
          value: 'autoplay',
          checked: queue.autoplayOnLoad,
          child: const Text('Autoplay loaded media'),
        ),
      ],
    );
  }
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
      title: const Text('New playlist'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Playlist name'),
        onSubmitted: _submit,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _submit(_controller.text),
          child: const Text('Create'),
        ),
      ],
    );
  }

  void _submit(String value) {
    final name = value.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.of(context).pop(name);
  }
}

class _NowPlayingPanel extends StatelessWidget {
  const _NowPlayingPanel({
    required this.currentMedia,
    required this.mediaProbe,
    required this.audioExport,
    required this.queue,
    required this.engine,
    required this.onPreviousTrack,
    required this.onNextTrack,
    required this.onToggleShuffle,
    required this.onCycleRepeat,
    required this.onExtractAudio,
    required this.onCancelAudioExport,
  });

  final MediaItem? currentMedia;
  final AsyncValue<MediaProbe?> mediaProbe;
  final AudioExportState audioExport;
  final PlaybackQueueState queue;
  final PlaybackEngine engine;
  final VoidCallback onPreviousTrack;
  final VoidCallback onNextTrack;
  final VoidCallback onToggleShuffle;
  final VoidCallback onCycleRepeat;
  final VoidCallback? onExtractAudio;
  final VoidCallback onCancelAudioExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.44),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            blurRadius: 36,
            color: Colors.black.withValues(alpha: 0.24),
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    currentMedia?.kind == MediaKind.video
                        ? Icons.movie_outlined
                        : Icons.graphic_eq,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentMedia?.title ?? 'Nothing playing',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentMedia?.path ?? 'Open a local file when ready',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.58),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _MediaProbeDetails(probe: mediaProbe),
            const SizedBox(height: 18),
            _ProgressBar(engine: engine),
            const SizedBox(height: 8),
            _TransportControls(
              engine: engine,
              queue: queue,
              onPreviousTrack: onPreviousTrack,
              onNextTrack: onNextTrack,
              onToggleShuffle: onToggleShuffle,
              onCycleRepeat: onCycleRepeat,
            ),
            const SizedBox(height: 8),
            _AudioExportRow(
              state: audioExport,
              sourceDuration: mediaProbe.when(
                data: (probe) => probe?.duration,
                error: (error, stackTrace) => null,
                loading: () => null,
              ),
              onExtract: onExtractAudio,
              onCancel: onCancelAudioExport,
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryPanel extends StatelessWidget {
  const _LibraryPanel({
    required this.queue,
    required this.onSelectPlaylist,
    required this.onPlayIndex,
  });

  final PlaybackQueueState queue;
  final ValueChanged<String> onSelectPlaylist;
  final ValueChanged<int> onPlayIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = queue.activePlaylist.items;

    return SizedBox(
      width: 360,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Playlists',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final playlist in queue.playlists)
                    ChoiceChip(
                      label: Text(
                        playlist.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: playlist.id == queue.activePlaylistId,
                      onSelected: (_) => onSelectPlaylist(playlist.id),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      queue.activePlaylist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${items.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              if (queue.statusMessage != null) ...[
                const SizedBox(height: 6),
                Text(
                  queue.statusMessage!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.62),
                  ),
                ),
              ],
              if (queue.lastError != null) ...[
                const SizedBox(height: 6),
                Text(
                  queue.lastError!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Expanded(
                child: queue.isScanning
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                        ? const Center(child: Text('No media in this playlist'))
                        : ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final selected = index == queue.currentIndex;

                              return ListTile(
                                dense: true,
                                selected: selected,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                leading: Icon(
                                  item.kind == MediaKind.video
                                      ? Icons.movie_outlined
                                      : Icons.music_note_outlined,
                                  size: 20,
                                ),
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
                                onTap: () => onPlayIndex(index),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioExportRow extends StatelessWidget {
  const _AudioExportRow({
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

    return Row(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: switch (state.status) {
              AudioExportStatus.running => LinearProgressIndicator(
                  key: const ValueKey('running'),
                  value: progress,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(999),
                ),
              AudioExportStatus.completed => _StatusText(
                  key: const ValueKey('completed'),
                  icon: Icons.check_circle_outline,
                  text: 'Audio extracted',
                ),
              AudioExportStatus.failed => _StatusText(
                  key: const ValueKey('failed'),
                  icon: Icons.error_outline,
                  text: 'Export failed',
                  tooltip: state.errorMessage,
                ),
              AudioExportStatus.cancelled => const _StatusText(
                  key: ValueKey('cancelled'),
                  icon: Icons.cancel_outlined,
                  text: 'Export cancelled',
                ),
              AudioExportStatus.idle => const SizedBox(
                  key: ValueKey('idle'),
                  height: 6,
                ),
            },
          ),
        ),
        const SizedBox(width: 12),
        if (state.isRunning)
          Tooltip(
            message: 'Cancel export',
            child: IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.stop_circle_outlined),
            ),
          )
        else
          Tooltip(
            message: 'Extract audio as FLAC',
            child: OutlinedButton.icon(
              onPressed: onExtract,
              icon: const Icon(Icons.audio_file_outlined),
              label: const Text('Extract FLAC'),
            ),
          ),
      ],
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({
    required super.key,
    required this.icon,
    required this.text,
    this.tooltip,
  });

  final IconData icon;
  final String text;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      children: [
        Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.64)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.64),
                ),
          ),
        ),
      ],
    );

    if (tooltip == null) {
      return child;
    }

    return Tooltip(message: tooltip!, child: child);
  }
}

class _MediaProbeDetails extends StatelessWidget {
  const _MediaProbeDetails({required this.probe});

  final AsyncValue<MediaProbe?> probe;

  @override
  Widget build(BuildContext context) {
    return probe.when(
      data: (data) {
        if (data == null) {
          return _MetadataLine(
            icon: Icons.info_outline,
            text: 'Media details will appear here',
          );
        }

        final primaryVideo = data.primaryVideoStream;
        final primaryAudio = data.primaryAudioStream;
        final pieces = <String>[
          if (data.formatName != null) data.formatName!,
          if (primaryVideo?.codecName case final String codec) 'video $codec',
          if (primaryVideo?.displaySize case final String size) size,
          if (primaryAudio?.codecName case final String codec) 'audio $codec',
          if (primaryAudio?.sampleRate case final int sampleRate)
            '${sampleRate ~/ 1000} kHz',
          if (primaryAudio?.channels case final int channels)
            channels == 1 ? 'mono' : '$channels ch',
          if (data.duration case final Duration duration)
            _formatDurationLong(duration),
        ];

        return _MetadataLine(
          icon: data.hasVideo ? Icons.movie_filter_outlined : Icons.graphic_eq,
          text: pieces.isEmpty ? 'No stream metadata found' : pieces.join('  /  '),
        );
      },
      loading: () => const _MetadataLine(
        icon: Icons.manage_search_outlined,
        text: 'Reading container and stream metadata...',
      ),
      error: (error, stackTrace) => _MetadataLine(
        icon: Icons.warning_amber_outlined,
        text: 'Could not read media details',
        tooltip: error.toString(),
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
  });

  final IconData icon;
  final String text;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.64)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.64),
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
            final max = duration.inMilliseconds.toDouble().clamp(1, double.infinity);
            final value = position.inMilliseconds.clamp(0, max.toInt()).toDouble();

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: value,
                  max: max.toDouble(),
                  onChanged: (nextValue) {
                    engine.seek(Duration(milliseconds: nextValue.round()));
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(position)),
                    Text(_formatDuration(duration)),
                  ],
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
    required this.queue,
    required this.onPreviousTrack,
    required this.onNextTrack,
    required this.onToggleShuffle,
    required this.onCycleRepeat,
  });

  final PlaybackEngine engine;
  final PlaybackQueueState queue;
  final VoidCallback onPreviousTrack;
  final VoidCallback onNextTrack;
  final VoidCallback onToggleShuffle;
  final VoidCallback onCycleRepeat;

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
              message: queue.shuffle ? 'Shuffle on' : 'Shuffle off',
              child: IconButton(
                isSelected: queue.shuffle,
                onPressed: onToggleShuffle,
                icon: const Icon(Icons.shuffle),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'Previous item',
              child: IconButton(
                onPressed: onPreviousTrack,
                icon: const Icon(Icons.skip_previous),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'Back 10 seconds',
              child: IconButton(
                onPressed: () => _seekBy(const Duration(seconds: -10)),
                icon: const Icon(Icons.replay_10),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: playing ? 'Pause' : 'Play',
              child: IconButton.filled(
                onPressed: () {
                  if (playing) {
                    engine.pause();
                  } else {
                    engine.play();
                  }
                },
                iconSize: 30,
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Forward 30 seconds',
              child: IconButton(
                onPressed: () => _seekBy(const Duration(seconds: 30)),
                icon: const Icon(Icons.forward_30),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'Next item',
              child: IconButton(
                onPressed: onNextTrack,
                icon: const Icon(Icons.skip_next),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: queue.repeatMode.label,
              child: IconButton(
                isSelected: queue.repeatMode != HeniRepeatMode.none,
                onPressed: onCycleRepeat,
                icon: Icon(
                  queue.repeatMode == HeniRepeatMode.one
                      ? Icons.repeat_one
                      : Icons.repeat,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _seekBy(Duration delta) async {
    var latest = Duration.zero;
    final subscription = engine.position.listen((position) {
      latest = position;
    });
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    final next = latest + delta;
    await engine.seek(next < Duration.zero ? Duration.zero : next);
  }
}

class _PaletteStrip extends ConsumerWidget {
  const _PaletteStrip({required this.active});

  final HeniPalette active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.center,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.seed,
                          border: Border.all(
                            color: identical(active, palette)
                                ? palette.accent
                                : Colors.white.withValues(alpha: 0.22),
                            width: identical(active, palette) ? 2.4 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
