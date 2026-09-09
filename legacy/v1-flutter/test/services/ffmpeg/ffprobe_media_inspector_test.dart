import 'package:flutter_test/flutter_test.dart';
import 'package:heni/domain/media/media_kind.dart';
import 'package:heni/services/ffmpeg/ffprobe_media_inspector.dart';
import 'package:heni/services/ffmpeg/media_process_runner.dart';

void main() {
  test('parses ffprobe JSON into a typed media probe', () async {
    final runner = _FakeRunner(
      const MediaProcessResult(
        exitCode: 0,
        stderr: '',
        stdout: '''
{
  "streams": [
    {
      "index": 0,
      "codec_name": "h264",
      "codec_long_name": "H.264 / AVC",
      "codec_type": "video",
      "width": 1920,
      "height": 1080,
      "avg_frame_rate": "30000/1001",
      "duration": "12.500000"
    },
    {
      "index": 1,
      "codec_name": "aac",
      "codec_type": "audio",
      "sample_rate": "48000",
      "channels": 2,
      "duration": "12.500000"
    }
  ],
  "format": {
    "format_name": "mov,mp4,m4a,3gp,3g2,mj2",
    "duration": "12.500000",
    "size": "1234567",
    "bit_rate": "789000",
    "tags": {
      "title": "Sample"
    }
  }
}
''',
      ),
    );
    final inspector = FfprobeMediaInspector(runner: runner);

    final probe = await inspector.inspectPath('sample.mp4');

    expect(runner.executable, 'ffprobe');
    expect(runner.arguments, containsAll(['-show_streams', '-show_format']));
    expect(probe.sourcePath, 'sample.mp4');
    expect(probe.primaryKind, MediaKind.video);
    expect(probe.duration, const Duration(milliseconds: 12500));
    expect(probe.primaryVideoStream?.displaySize, '1920x1080');
    expect(probe.primaryVideoStream?.frameRate?.value, closeTo(29.97, 0.01));
    expect(probe.primaryAudioStream?.sampleRate, 48000);
    expect(probe.tags['title'], 'Sample');
  });

  test('throws a useful exception when ffprobe fails', () async {
    final inspector = FfprobeMediaInspector(
      runner: _FakeRunner(
        const MediaProcessResult(
          exitCode: 1,
          stdout: '',
          stderr: 'Invalid data found when processing input',
        ),
      ),
    );

    await expectLater(
      inspector.inspectPath('broken.mp4'),
      throwsA(isA<MediaProbeException>()),
    );
  });
}

class _FakeRunner implements MediaProcessRunner {
  _FakeRunner(this.result);

  final MediaProcessResult result;
  String? executable;
  List<String>? arguments;

  @override
  Future<MediaProcessResult> run(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    this.executable = executable;
    this.arguments = arguments;
    return result;
  }
}
