import 'dart:convert';

import '../../domain/media/media_probe.dart';
import 'media_inspector.dart';
import 'media_process_runner.dart';

class FfprobeMediaInspector implements MediaInspector {
  const FfprobeMediaInspector({
    this.ffprobeExecutable = 'ffprobe',
    this.runner = const SystemMediaProcessRunner(),
  });

  final String ffprobeExecutable;
  final MediaProcessRunner runner;

  @override
  Future<MediaProbe> inspectPath(String path) async {
    final result = await runner.run(
      ffprobeExecutable,
      [
        '-v',
        'error',
        '-print_format',
        'json',
        '-show_format',
        '-show_streams',
        '-show_chapters',
        path,
      ],
    );

    if (!result.succeeded) {
      throw MediaProbeException(
        path: path,
        message: result.stderr.trim().isEmpty
            ? 'ffprobe exited with ${result.exitCode}.'
            : result.stderr.trim(),
      );
    }

    final decoded = jsonDecode(result.stdout);
    if (decoded case final Map<String, Object?> json) {
      return MediaProbe.fromFfprobeJson(json, sourcePath: path);
    }

    throw MediaProbeException(
      path: path,
      message: 'ffprobe returned JSON that was not an object.',
    );
  }
}

class MediaProbeException implements Exception {
  const MediaProbeException({required this.path, required this.message});

  final String path;
  final String message;

  @override
  String toString() => 'Could not inspect "$path": $message';
}
