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
    NotifierProvider<CurrentLyrics, AsyncValue<List<LyricLine>>>(
      CurrentLyrics.new,
    );

class LyricLine {
  const LyricLine({required this.time, required this.text});

  final Duration? time;
  final String text;
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

  Future<void> inspect(String path) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(mediaInspectorProvider).inspectPath(path);
    });
  }

  void clear() {
    state = const AsyncData(null);
  }
}

class CurrentLyrics extends Notifier<AsyncValue<List<LyricLine>>> {
  @override
  AsyncValue<List<LyricLine>> build() => const AsyncData([]);

  Future<void> loadFor(String mediaPath) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final file = _findLyricsFile(mediaPath);
      if (file == null) {
        return const <LyricLine>[];
      }

      final text = await file.readAsString();
      final lines = _parseLyrics(text);
      return lines;
    });
  }

  void clear() {
    state = const AsyncData([]);
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

  List<LyricLine> _parseLyrics(String text) {
    final timestampPattern = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');
    final lines = <LyricLine>[];
    final plainLines = <String>[];

    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) {
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
        lines.add(
          LyricLine(
            time: Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: milliseconds,
            ),
            text: content.isEmpty ? '♪' : content,
          ),
        );
      }
    }

    if (lines.isNotEmpty) {
      lines.sort(
        (a, b) => (a.time ?? Duration.zero).compareTo(b.time ?? Duration.zero),
      );
      return List.unmodifiable(lines);
    }

    return List.unmodifiable([
      for (final line in plainLines) LyricLine(time: null, text: line),
    ]);
  }
}
