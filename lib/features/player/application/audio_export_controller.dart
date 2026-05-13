import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/ffmpeg/ffmpeg_command_builder.dart';
import '../../../services/ffmpeg/ffmpeg_job_runner.dart';
import '../../../services/ffmpeg/ffmpeg_progress.dart';
import '../../../services/ffmpeg/media_editor.dart';
import '../../../services/ffmpeg/media_editor_provider.dart';

final audioExportControllerProvider =
    NotifierProvider<AudioExportController, AudioExportState>(
  AudioExportController.new,
);

class AudioExportController extends Notifier<AudioExportState> {
  StreamSubscription<FfmpegJobEvent>? _subscription;

  @override
  AudioExportState build() {
    ref.onDispose(() {
      _subscription?.cancel();
    });

    return const AudioExportState.idle();
  }

  Future<void> extractAudio({
    required String inputPath,
    required String outputPath,
    AudioOutputCodec codec = AudioOutputCodec.flac,
  }) async {
    await _subscription?.cancel();
    final editor = ref.read(mediaEditorProvider);
    final done = Completer<void>();

    state = AudioExportState.running(outputPath: outputPath);
    _subscription = editor
        .extractAudio(
          AudioExtractionRequest(
            inputPath: inputPath,
            outputPath: outputPath,
            codec: codec,
            overwrite: true,
            timeout: const Duration(hours: 2),
          ),
        )
        .listen(
      (event) {
        if (event is FfmpegJobProgress) {
          state = state.withProgress(event.progress);
        } else if (event is FfmpegJobCompleted) {
          state = event.succeeded
              ? AudioExportState.completed(outputPath: outputPath)
              : AudioExportState.failed(
                  outputPath: outputPath,
                  errorMessage: _failureMessage(event),
                );
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        state = AudioExportState.failed(
          outputPath: outputPath,
          errorMessage: error.toString(),
        );
        if (!done.isCompleted) {
          done.complete();
        }
      },
      onDone: () {
        if (!done.isCompleted) {
          done.complete();
        }
      },
      cancelOnError: true,
    );

    await done.future;
    _subscription = null;
  }

  Future<void> cancel() async {
    await _subscription?.cancel();
    _subscription = null;
    state = const AudioExportState.cancelled();
  }

  String _failureMessage(FfmpegJobCompleted event) {
    if (event.timedOut) {
      return 'FFmpeg timed out.';
    }
    if (event.stderrTail.isEmpty) {
      return 'FFmpeg exited with code ${event.exitCode}.';
    }
    return event.stderrTail.join('\n');
  }
}

class AudioExportState {
  const AudioExportState({
    required this.status,
    this.outputPath,
    this.progress,
    this.errorMessage,
  });

  const AudioExportState.idle()
      : this(status: AudioExportStatus.idle);

  const AudioExportState.running({required String outputPath})
      : this(status: AudioExportStatus.running, outputPath: outputPath);

  const AudioExportState.completed({required String outputPath})
      : this(status: AudioExportStatus.completed, outputPath: outputPath);

  const AudioExportState.failed({
    required String outputPath,
    required String errorMessage,
  }) : this(
          status: AudioExportStatus.failed,
          outputPath: outputPath,
          errorMessage: errorMessage,
        );

  const AudioExportState.cancelled()
      : this(status: AudioExportStatus.cancelled);

  final AudioExportStatus status;
  final String? outputPath;
  final FfmpegProgress? progress;
  final String? errorMessage;

  bool get isRunning => status == AudioExportStatus.running;

  AudioExportState withProgress(FfmpegProgress progress) {
    return AudioExportState(
      status: status,
      outputPath: outputPath,
      progress: progress,
      errorMessage: errorMessage,
    );
  }

  double? fraction(Duration? sourceDuration) {
    final sourceMicroseconds = sourceDuration?.inMicroseconds;
    final outMicroseconds = progress?.outTime?.inMicroseconds;
    if (sourceMicroseconds == null ||
        sourceMicroseconds <= 0 ||
        outMicroseconds == null) {
      return null;
    }

    return (outMicroseconds / sourceMicroseconds).clamp(0, 1).toDouble();
  }
}

enum AudioExportStatus {
  idle,
  running,
  completed,
  failed,
  cancelled,
}
