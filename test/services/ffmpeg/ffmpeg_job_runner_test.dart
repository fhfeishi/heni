import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heni/services/ffmpeg/ffmpeg_command_builder.dart';
import 'package:heni/services/ffmpeg/ffmpeg_job_runner.dart';

void main() {
  test('runs ffmpeg and emits progress events when ffmpeg is installed', () async {
    final availability = await Process.run('ffmpeg', ['-version']);
    if (availability.exitCode != 0) {
      markTestSkipped('ffmpeg is not available on PATH.');
      return;
    }

    final tempDir = await Directory.systemTemp.createTemp('heni_ffmpeg_job_');
    addTearDown(() => tempDir.delete(recursive: true));

    final outputPath = '${tempDir.path}${Platform.pathSeparator}sample.wav';
    final runner = const FfmpegJobRunner();
    final events = <FfmpegJobEvent>[];

    await for (final event in runner.run(
      [
        '-hide_banner',
        '-y',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:duration=1',
        '-c:a',
        'pcm_s16le',
        outputPath,
      ],
      timeout: const Duration(seconds: 20),
    )) {
      events.add(event);
    }

    expect(events.whereType<FfmpegJobStarted>(), isNotEmpty);
    expect(events.whereType<FfmpegJobProgress>(), isNotEmpty);
    expect(events.whereType<FfmpegJobCompleted>().single.succeeded, isTrue);
    expect(File(outputPath).existsSync(), isTrue);
  });

  test('command builder output can be used as job runner input', () {
    final args = FfmpegCommandBuilder.extractAudio(
      const FfmpegAudioExtractRequest(
        inputPath: 'input.mp4',
        outputPath: 'voice.flac',
      ),
    );

    expect(args, containsAllInOrder(['-i', 'input.mp4']));
    expect(args, containsAllInOrder(['-c:a', 'flac']));
  });
}
