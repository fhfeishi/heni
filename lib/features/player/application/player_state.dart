import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../domain/media/media_item.dart';
import '../../../domain/media/media_probe.dart';
import '../../../services/ffmpeg/media_inspector_provider.dart';

final currentMediaProvider = NotifierProvider<CurrentMedia, MediaItem?>(
  CurrentMedia.new,
);

final sceneryImagePathsProvider =
    NotifierProvider<SceneryImagePaths, List<String>>(SceneryImagePaths.new);

final currentMediaProbeProvider =
    NotifierProvider<CurrentMediaProbe, AsyncValue<MediaProbe?>>(
      CurrentMediaProbe.new,
    );

final currentLyricsProvider =
    NotifierProvider<CurrentLyrics, AsyncValue<LyricsDocument>>(
      CurrentLyrics.new,
    );

class LyricLine {
  const LyricLine({required this.time, required this.text});

  final Duration? time;
  final String text;
}

class LyricHeader {
  const LyricHeader({this.title, this.artist, this.album, this.offset});

  final String? title;
  final String? artist;
  final String? album;
  final Duration? offset;
}

class LyricsDocument {
  const LyricsDocument({required this.header, required this.lines});

  final LyricHeader header;
  final List<LyricLine> lines;
}

class CurrentMedia extends Notifier<MediaItem?> {
  @override
  MediaItem? build() => null;

  void set(MediaItem? media) {
    state = media;
  }
}

class SceneryImagePaths extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void replaceAll(List<String> paths) {
    state = List.unmodifiable(paths);
  }
}

class CurrentMediaProbe extends Notifier<AsyncValue<MediaProbe?>> {
  @override
  AsyncValue<MediaProbe?> build() => const AsyncData(null);

  Future<MediaProbe?> inspect(String path) async {
    state = const AsyncLoading();
    try {
      final probe = await ref.read(mediaInspectorProvider).inspectPath(path);
      state = AsyncData(probe);
      return probe;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  void clear() {
    state = const AsyncData(null);
  }
}

class CurrentLyrics extends Notifier<AsyncValue<LyricsDocument>> {
  @override
  AsyncValue<LyricsDocument> build() =>
      const AsyncData(LyricsDocument(header: LyricHeader(), lines: []));

  Future<void> loadFor(String mediaPath) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final file = _findLyricsFile(mediaPath);
      if (file == null) {
        return const LyricsDocument(header: LyricHeader(), lines: []);
      }

      final text = await file.readAsString();
      return _parseLyrics(text);
    });
  }

  void clear() {
    state = const AsyncData(LyricsDocument(header: LyricHeader(), lines: []));
  }

  File? _findLyricsFile(String mediaPath) {
    final directory = p.dirname(mediaPath);
    final baseName = p.basenameWithoutExtension(mediaPath);
    for (final extension in const ['lrc', 'txt']) {
      final file = File(p.join(directory, '$baseName.$extension'));
      if (file.existsSync()) {
        return file;
      }
    }
    return null;
  }

  LyricsDocument _parseLyrics(String text) {
    final timestampPattern = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');
    final metadataPattern = RegExp(
      r'^\[(ti|ar|al|offset):(.*)\]$',
      caseSensitive: false,
    );
    final lines = <LyricLine>[];
    final plainLines = <String>[];
    String? title;
    String? artist;
    String? album;
    Duration? offset;

    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      final metadataMatch = metadataPattern.firstMatch(line);
      if (metadataMatch != null && !line.contains(RegExp(r'\[\d'))) {
        final key = (metadataMatch.group(1) ?? '').toLowerCase();
        final value = (metadataMatch.group(2) ?? '').trim();
        switch (key) {
          case 'ti':
            title = value.isEmpty ? title : value;
          case 'ar':
            artist = value.isEmpty ? artist : value;
          case 'al':
            album = value.isEmpty ? album : value;
          case 'offset':
            final milliseconds = int.tryParse(value);
            if (milliseconds != null) {
              offset = Duration(milliseconds: milliseconds);
            }
        }
        continue;
      }

      final matches = timestampPattern.allMatches(line).toList();
      final content = line.replaceAll(timestampPattern, '').trim();
      if (matches.isEmpty) {
        if (!line.startsWith('[')) {
          plainLines.add(line);
        }
        continue;
      }

      for (final match in matches) {
        final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
        final fraction = match.group(3) ?? '0';
        final milliseconds = switch (fraction.length) {
          1 => int.parse(fraction) * 100,
          2 => int.parse(fraction) * 10,
          _ => int.parse(fraction.padRight(3, '0').substring(0, 3)),
        };
        final shifted =
            Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: milliseconds,
            ) +
            (offset ?? Duration.zero);
        lines.add(
          LyricLine(
            time: shifted.isNegative ? Duration.zero : shifted,
            text: content.isEmpty ? '♪' : content,
          ),
        );
      }
    }

    if (lines.isNotEmpty) {
      lines.sort(
        (a, b) => (a.time ?? Duration.zero).compareTo(b.time ?? Duration.zero),
      );
      return LyricsDocument(
        header: LyricHeader(
          title: title,
          artist: artist,
          album: album,
          offset: offset,
        ),
        lines: List.unmodifiable(lines),
      );
    }

    return LyricsDocument(
      header: LyricHeader(
        title: title,
        artist: artist,
        album: album,
        offset: offset,
      ),
      lines: List.unmodifiable([
        for (final line in plainLines) LyricLine(time: null, text: line),
      ]),
    );
  }
}
