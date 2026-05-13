import 'ffmpeg_command_builder.dart';
import 'ffmpeg_job_runner.dart';

class FfmpegMediaEditor {
  const FfmpegMediaEditor({
    this.runner = const FfmpegJobRunner(),
  });

  final FfmpegJobExecutor runner;

  Stream<FfmpegJobEvent> extractAudio(
    AudioExtractionRequest request,
  ) {
    return runner.run(
      FfmpegCommandBuilder.extractAudio(
        FfmpegAudioExtractRequest(
          inputPath: request.inputPath,
          outputPath: request.outputPath,
          codec: request.codec,
          overwrite: request.overwrite,
        ),
      ),
      timeout: request.timeout,
    );
  }
}

class AudioExtractionRequest {
  const AudioExtractionRequest({
    required this.inputPath,
    required this.outputPath,
    this.codec = AudioOutputCodec.flac,
    this.overwrite = false,
    this.timeout,
  });

  final String inputPath;
  final String outputPath;
  final AudioOutputCodec codec;
  final bool overwrite;
  final Duration? timeout;
}
