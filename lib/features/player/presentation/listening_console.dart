import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../design/app_theme.dart';
import '../../../domain/media/media_item.dart';
import '../../../domain/media/media_kind.dart';
import '../../../domain/media/media_probe.dart';

List<String> heniAudioDetailLabels(MediaProbe? probe) {
  final audio = probe?.primaryAudioStream;
  if (audio == null) {
    return const [];
  }

  final labels = <String>[];
  final codec = audio.codecName?.trim();
  final profile = audio.profile?.trim();
  if (codec != null && codec.isNotEmpty) {
    final upperCodec = codec.toUpperCase();
    final upperProfile = profile?.toUpperCase();
    labels.add(
      upperProfile == null ||
              upperProfile.isEmpty ||
              upperCodec.contains(upperProfile)
          ? upperCodec
          : '$upperCodec $upperProfile',
    );
  }

  final bitRate = audio.bitRate ?? probe?.bitRate;
  if (bitRate != null && bitRate > 0) {
    labels.add('${(bitRate / 1000).round()} kbps');
  }

  final sampleRate = audio.sampleRate;
  if (sampleRate != null && sampleRate > 0) {
    labels.add(
      sampleRate % 1000 == 0
          ? '${sampleRate ~/ 1000} kHz'
          : '${(sampleRate / 1000).toStringAsFixed(1)} kHz',
    );
  }

  final channels = audio.channels;
  if (channels != null && channels > 0) {
    labels.add(switch (channels) {
      1 => '单声道',
      2 => '双声道',
      _ => '$channels 声道',
    });
  }

  final normalizedCodec = codec?.toLowerCase();
  if (normalizedCodec == 'flac' ||
      normalizedCodec == 'alac' ||
      normalizedCodec == 'wavpack' ||
      (normalizedCodec?.startsWith('pcm_') ?? false)) {
    labels.add('无损');
  }

  return List.unmodifiable(labels);
}

class HeniListeningConsole extends StatelessWidget {
  const HeniListeningConsole({
    required this.palette,
    required this.currentMedia,
    required this.nextMedia,
    required this.mediaProbe,
    required this.isPlaying,
    required this.libraryItemCount,
    required this.libraryDirectoryCount,
    required this.statusMessage,
    required this.onLocateCurrent,
    required this.onOpenFileLocation,
    required this.onPickMedia,
    required this.onPickFolder,
    super.key,
  });

  final HeniPalette palette;
  final MediaItem? currentMedia;
  final MediaItem? nextMedia;
  final AsyncValue<MediaProbe?> mediaProbe;
  final bool isPlaying;
  final int libraryItemCount;
  final int libraryDirectoryCount;
  final String? statusMessage;
  final VoidCallback onLocateCurrent;
  final VoidCallback onOpenFileLocation;
  final VoidCallback onPickMedia;
  final VoidCallback onPickFolder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final current = currentMedia;
        if (current == null) {
          return _ListeningConsoleSurface(
            key: const ValueKey('listening-console-empty-state'),
            palette: palette,
            child: _EmptyListeningState(
              palette: palette,
              libraryItemCount: libraryItemCount,
              libraryDirectoryCount: libraryDirectoryCount,
              statusMessage: statusMessage,
              onPickMedia: onPickMedia,
              onPickFolder: onPickFolder,
            ),
          );
        }

        final wide = constraints.maxWidth >= 1050;
        final medium = constraints.maxWidth >= 760;
        final probe = mediaProbe.value;

        return _ListeningConsoleSurface(
          key: const ValueKey('listening-console'),
          palette: palette,
          child: Padding(
            padding: EdgeInsets.all(
              wide
                  ? 24
                  : medium
                  ? 20
                  : 16,
            ),
            child:
                wide
                    ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ConsoleArtwork(
                          palette: palette,
                          media: current,
                          isPlaying: isPlaying,
                          size: 190,
                        ),
                        const SizedBox(width: 26),
                        Expanded(
                          child: _CurrentMediaColumn(
                            key: const ValueKey(
                              'listening-console-current-media',
                            ),
                            palette: palette,
                            media: current,
                            probe: probe,
                            showPath: true,
                            onLocateCurrent: onLocateCurrent,
                            onOpenFileLocation: onOpenFileLocation,
                          ),
                        ),
                        const SizedBox(width: 22),
                        SizedBox(
                          key: const ValueKey('listening-console-side-panel'),
                          width: 260,
                          child: _ListeningSidePanel(
                            palette: palette,
                            probe: probe,
                            mediaProbe: mediaProbe,
                            nextMedia: nextMedia,
                          ),
                        ),
                      ],
                    )
                    : medium
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              _ConsoleArtwork(
                                palette: palette,
                                media: current,
                                isPlaying: isPlaying,
                                size: 148,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: _CurrentMediaColumn(
                                  key: const ValueKey(
                                    'listening-console-current-media',
                                  ),
                                  palette: palette,
                                  media: current,
                                  probe: probe,
                                  showPath: true,
                                  onLocateCurrent: onLocateCurrent,
                                  onOpenFileLocation: onOpenFileLocation,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _CompactMetadataStrip(
                          palette: palette,
                          mediaProbe: mediaProbe,
                          nextMedia: nextMedia,
                        ),
                      ],
                    )
                    : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _ConsoleArtwork(
                          palette: palette,
                          media: current,
                          isPlaying: isPlaying,
                          size: 104,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _CurrentMediaColumn(
                            key: const ValueKey(
                              'listening-console-current-media',
                            ),
                            palette: palette,
                            media: current,
                            probe: probe,
                            showPath: false,
                            compact: true,
                            onLocateCurrent: onLocateCurrent,
                            onOpenFileLocation: onOpenFileLocation,
                          ),
                        ),
                      ],
                    ),
          ),
        );
      },
    );
  }
}

class _ListeningConsoleSurface extends StatelessWidget {
  const _ListeningConsoleSurface({
    required this.palette,
    required this.child,
    super.key,
  });

  final HeniPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                palette.seed.withValues(alpha: 0.14),
                palette.surfaceAlt.withValues(alpha: 0.94),
              ),
              Color.alphaBlend(
                palette.seed.withValues(alpha: 0.07),
                palette.surface.withValues(alpha: 0.96),
              ),
              palette.surfaceAlt.withValues(alpha: 0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: Color.alphaBlend(
              palette.seed.withValues(alpha: 0.18),
              Colors.white.withValues(alpha: 0.055),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 30,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _ConsoleArtwork extends StatelessWidget {
  const _ConsoleArtwork({
    required this.palette,
    required this.media,
    required this.isPlaying,
    required this.size,
  });

  final HeniPalette palette;
  final MediaItem media;
  final bool isPlaying;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isVideo = media.kind == MediaKind.video;
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.085),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(palette.seed, palette.accent, 0.18)!,
              Color.alphaBlend(
                palette.seed.withValues(alpha: 0.28),
                palette.surfaceAlt,
              ),
              palette.surface,
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
          boxShadow: [
            BoxShadow(
              color: palette.seed.withValues(alpha: isPlaying ? 0.22 : 0.12),
              blurRadius: isPlaying ? 30 : 20,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child:
            isVideo
                ? Icon(
                  Icons.movie_outlined,
                  size: size * 0.38,
                  color: Colors.white.withValues(alpha: 0.78),
                )
                : _StudioDisc(palette: palette, size: size * 0.67),
      ),
    );
  }
}

class _StudioDisc extends StatelessWidget {
  const _StudioDisc({required this.palette, required this.size});

  final HeniPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [
            Color(0xFF252328),
            Color(0xFF0B0B0D),
            Color(0xFF19181C),
            Color(0xFF050506),
          ],
          stops: [0, 0.34, 0.36, 1],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Center(
        child: Container(
          width: size * 0.34,
          height: size * 0.34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Color.lerp(palette.accent, palette.seed, 0.28)!,
                palette.seed,
              ],
            ),
            border: Border.all(color: Colors.black.withValues(alpha: 0.38)),
          ),
          child: Center(
            child: Container(
              width: size * 0.055,
              height: size * 0.055,
              decoration: const BoxDecoration(
                color: Color(0xFF070708),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentMediaColumn extends StatelessWidget {
  const _CurrentMediaColumn({
    required this.palette,
    required this.media,
    required this.probe,
    required this.showPath,
    required this.onLocateCurrent,
    required this.onOpenFileLocation,
    this.compact = false,
    super.key,
  });

  final HeniPalette palette;
  final MediaItem media;
  final MediaProbe? probe;
  final bool showPath;
  final VoidCallback onLocateCurrent;
  final VoidCallback onOpenFileLocation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final artist = _mediaTag(probe, 'artist');
    final album = _mediaTag(probe, 'album');
    final subtitle = [
      if (artist != null) artist,
      if (album != null) album,
      if (artist == null && album == null) p.basename(p.dirname(media.path)),
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.accent,
                boxShadow: [
                  BoxShadow(
                    color: palette.accent.withValues(alpha: 0.34),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '正在播放',
              style: theme.textTheme.labelMedium?.copyWith(
                color: heniAccentOnGlass(palette.accent, alpha: 0.94),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 10 : 14),
        Text(
          media.title,
          maxLines: compact ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: compact ? 25 : 36,
            height: 1.06,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.55,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.58),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (showPath) ...[
          const SizedBox(height: 7),
          Text(
            media.path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.34),
            ),
          ),
        ],
        SizedBox(height: compact ? 14 : 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: onLocateCurrent,
              icon: const Icon(Icons.my_location_rounded, size: 17),
              label: const Text('定位当前曲目'),
              style: FilledButton.styleFrom(
                backgroundColor: palette.accent.withValues(alpha: 0.16),
                foregroundColor: heniAccentOnGlass(palette.accent),
                minimumSize: const Size(0, 38),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onOpenFileLocation,
              icon: const Icon(Icons.folder_open_rounded, size: 17),
              label: const Text('打开文件位置'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.74),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
                minimumSize: const Size(0, 38),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ListeningSidePanel extends StatelessWidget {
  const _ListeningSidePanel({
    required this.palette,
    required this.probe,
    required this.mediaProbe,
    required this.nextMedia,
  });

  final HeniPalette palette;
  final MediaProbe? probe;
  final AsyncValue<MediaProbe?> mediaProbe;
  final MediaItem? nextMedia;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _AudioMetadataCard(
            palette: palette,
            probe: probe,
            mediaProbe: mediaProbe,
          ),
        ),
        const SizedBox(height: 12),
        _NextMediaCard(palette: palette, media: nextMedia),
      ],
    );
  }
}

class _AudioMetadataCard extends StatelessWidget {
  const _AudioMetadataCard({
    required this.palette,
    required this.probe,
    required this.mediaProbe,
  });

  final HeniPalette palette;
  final MediaProbe? probe;
  final AsyncValue<MediaProbe?> mediaProbe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = heniAudioDetailLabels(probe);
    return _InsetConsoleCard(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '实际播放参数',
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.44),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 12),
          if (mediaProbe.isLoading)
            const LinearProgressIndicator(minHeight: 2)
          else if (labels.isEmpty)
            Text(
              '正在等待媒体参数',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.48),
              ),
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final label in labels)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: palette.seed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: palette.seed.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color:
                            label == '无损'
                                ? heniAccentOnGlass(palette.accent)
                                : Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          const Spacer(),
          Row(
            children: [
              Icon(
                Icons.verified_outlined,
                size: 14,
                color: palette.accent.withValues(alpha: 0.82),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '原始解码播放，不进行二次转码',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NextMediaCard extends StatelessWidget {
  const _NextMediaCard({required this.palette, required this.media});

  final HeniPalette palette;
  final MediaItem? media;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _InsetConsoleCard(
      palette: palette,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: [
                  palette.seed.withValues(alpha: 0.65),
                  palette.surfaceAlt,
                ],
              ),
            ),
            child: Icon(
              media?.kind == MediaKind.video
                  ? Icons.movie_outlined
                  : Icons.music_note_rounded,
              size: 20,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '下一首',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.38),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  media?.title ?? '播放列表已结束',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactMetadataStrip extends StatelessWidget {
  const _CompactMetadataStrip({
    required this.palette,
    required this.mediaProbe,
    required this.nextMedia,
  });

  final HeniPalette palette;
  final AsyncValue<MediaProbe?> mediaProbe;
  final MediaItem? nextMedia;

  @override
  Widget build(BuildContext context) {
    final labels = heniAudioDetailLabels(mediaProbe.value);
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final label in labels.take(4))
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.64),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          if (nextMedia != null) ...[
            const SizedBox(width: 10),
            Icon(
              Icons.skip_next_rounded,
              size: 16,
              color: palette.accent.withValues(alpha: 0.82),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                nextMedia!.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsetConsoleCard extends StatelessWidget {
  const _InsetConsoleCard({required this.palette, required this.child});

  final HeniPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          palette.seed.withValues(alpha: 0.055),
          Colors.black.withValues(alpha: 0.22),
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.065)),
      ),
      child: child,
    );
  }
}

class _EmptyListeningState extends StatelessWidget {
  const _EmptyListeningState({
    required this.palette,
    required this.libraryItemCount,
    required this.libraryDirectoryCount,
    required this.statusMessage,
    required this.onPickMedia,
    required this.onPickFolder,
  });

  final HeniPalette palette;
  final int libraryItemCount;
  final int libraryDirectoryCount;
  final String? statusMessage;
  final VoidCallback onPickMedia;
  final VoidCallback onPickFolder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      palette.seed.withValues(alpha: 0.38),
                      palette.surfaceAlt,
                    ],
                  ),
                  border: Border.all(
                    color: palette.seed.withValues(alpha: 0.24),
                  ),
                ),
                child: Icon(
                  Icons.library_music_rounded,
                  size: 34,
                  color: heniAccentOnGlass(palette.accent),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '从本地音乐开始',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$libraryItemCount 首内容 · $libraryDirectoryCount 个目录',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.56),
                ),
              ),
              if (statusMessage case final String status
                  when status.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  status,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: onPickMedia,
                    icon: const Icon(Icons.audio_file_rounded),
                    label: const Text('选择文件'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onPickFolder,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text('导入目录'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _mediaTag(MediaProbe? probe, String name) {
  final target = name.toLowerCase();
  for (final entry
      in probe?.tags.entries ?? const <MapEntry<String, String>>[]) {
    if (entry.key.toLowerCase() == target && entry.value.trim().isNotEmpty) {
      return entry.value.trim();
    }
  }
  for (final entry
      in probe?.primaryAudioStream?.tags.entries ??
          const <MapEntry<String, String>>[]) {
    if (entry.key.toLowerCase() == target && entry.value.trim().isNotEmpty) {
      return entry.value.trim();
    }
  }
  return null;
}
