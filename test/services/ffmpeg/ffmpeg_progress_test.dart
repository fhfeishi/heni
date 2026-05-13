import 'package:flutter_test/flutter_test.dart';
import 'package:heni/services/ffmpeg/ffmpeg_progress.dart';

void main() {
  group('FfmpegProgressParser', () {
    test('emits progress when a progress line closes the block', () {
      final parser = FfmpegProgressParser();

      expect(parser.acceptLine('frame=42'), isNull);
      expect(parser.acceptLine('fps=29.97'), isNull);
      expect(parser.acceptLine('total_size=2048'), isNull);
      expect(parser.acceptLine('out_time_us=1500000'), isNull);
      expect(parser.acceptLine('bitrate= 128.0kbits/s'), isNull);
      expect(parser.acceptLine('speed= 1.25x'), isNull);

      final progress = parser.acceptLine('progress=continue');

      expect(progress, isNotNull);
      expect(progress?.frame, 42);
      expect(progress?.fps, 29.97);
      expect(progress?.totalSizeBytes, 2048);
      expect(progress?.outTime, const Duration(milliseconds: 1500));
      expect(progress?.bitrate, '128.0kbits/s');
      expect(progress?.speedMultiplier, 1.25);
      expect(progress?.isEnd, isFalse);
    });

    test('parses timestamp fallback and end status', () {
      final parser = FfmpegProgressParser();

      parser.acceptLine('out_time=00:02:03.456789');
      final progress = parser.acceptLine('progress=end');

      expect(progress?.outTime, const Duration(minutes: 2, seconds: 3, microseconds: 456789));
      expect(progress?.isEnd, isTrue);
    });

    test('ignores regular ffmpeg log lines', () {
      final parser = FfmpegProgressParser();

      expect(parser.acceptLine('Input #0, wav, from sample.wav:'), isNull);
      expect(parser.acceptLine('Stream mapping:'), isNull);
    });
  });
}
