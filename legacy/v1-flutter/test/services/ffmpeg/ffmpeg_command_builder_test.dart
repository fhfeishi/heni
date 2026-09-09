import 'package:flutter_test/flutter_test.dart';
import 'package:heni/services/ffmpeg/ffmpeg_command_builder.dart';

void main() {
  group('FfmpegCommandBuilder', () {
    test('builds a stream-copy trim with safe argument boundaries', () {
      final args = FfmpegCommandBuilder.trim(
        const FfmpegTrimRequest(
          inputPath: r'D:\media\my song.mp4',
          outputPath: r'D:\media\clip.mp4',
          start: Duration(seconds: 10),
          end: Duration(seconds: 40),
          overwrite: true,
        ),
      );

      expect(args, containsAllInOrder(['-ss', '00:00:10.000']));
      expect(args, containsAllInOrder(['-i', r'D:\media\my song.mp4']));
      expect(args, containsAllInOrder(['-t', '00:00:30.000']));
      expect(args, containsAllInOrder(['-c', 'copy']));
      expect(args.last, r'D:\media\clip.mp4');
    });
  });
}
