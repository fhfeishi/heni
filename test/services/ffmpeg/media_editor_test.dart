import 'package:flutter_test/flutter_test.dart';
import 'package:heni/services/ffmpeg/ffmpeg_command_builder.dart';
import 'package:heni/services/ffmpeg/ffmpeg_job_runner.dart';
import 'package:heni/services/ffmpeg/media_editor.dart';

void main() {
  test('extractAudio delegates a structured command to the job executor', () async {
    final executor = _FakeExecutor();
    final editor = FfmpegMediaEditor(runner: executor);

    final events = await editor
        .extractAudio(
          const AudioExtractionRequest(
            inputPath: 'input.mp4',
            outputPath: 'voice.opus',
            codec: AudioOutputCodec.opus,
            timeout: Duration(seconds: 5),
          ),
        )
        .toList();

    expect(events.single, isA<FfmpegJobCompleted>());
    expect(executor.timeout, const Duration(seconds: 5));
    expect(executor.arguments, [
      '-hide_banner',
      '-n',
      '-i',
      'input.mp4',
      '-map',
      '0:a:0',
      '-vn',
      '-c:a',
      'libopus',
      '-b:a',
      '128k',
      'voice.opus',
    ]);
  });
}

class _FakeExecutor implements FfmpegJobExecutor {
  List<String>? arguments;
  Duration? timeout;

  @override
  Stream<FfmpegJobEvent> run(
    List<String> arguments, {
    Duration? timeout,
  }) async* {
    this.arguments = arguments;
    this.timeout = timeout;
    yield const FfmpegJobCompleted(
      exitCode: 0,
      timedOut: false,
      stderrTail: [],
    );
  }
}
