import 'dart:io';

import 'package:image/image.dart' as img;

import 'generate_windows_icon.dart' as generator;

void main() {
  final tempDirectory = Directory.systemTemp.createTempSync(
    'heni-windows-icon-test-',
  );

  try {
    final sourcePath =
        '${tempDirectory.path}${Platform.pathSeparator}source.png';
    final outputPath = '${tempDirectory.path}${Platform.pathSeparator}app.ico';
    final source = img.Image(width: 512, height: 512, numChannels: 4);

    File(sourcePath).writeAsBytesSync(img.encodePng(source), flush: true);
    generator.generateWindowsIcon(
      sourcePath: sourcePath,
      outputPath: outputPath,
    );

    final bytes = File(outputPath).readAsBytesSync();
    final decoder = img.IcoDecoder();
    if (!decoder.isValidFile(bytes)) {
      throw StateError('Generated file is not a valid ICO.');
    }
    decoder.startDecode(bytes);

    final sizes = <int>[];
    for (var frameIndex = 0; frameIndex < decoder.numFrames(); frameIndex++) {
      final frame = decoder.decodeFrame(frameIndex);
      if (frame == null || frame.width != frame.height) {
        throw StateError('ICO frame $frameIndex is missing or not square.');
      }
      sizes.add(frame.width);
    }

    const expectedSizes = [16, 24, 32, 48, 256];
    if (sizes.length != expectedSizes.length ||
        !sizes.asMap().entries.every(
          (entry) => entry.value == expectedSizes[entry.key],
        )) {
      throw StateError(
        'Unexpected ICO frame sizes: $sizes; expected $expectedSizes.',
      );
    }

    stdout.writeln('Windows ICO generator verified: $sizes');
  } finally {
    tempDirectory.deleteSync(recursive: true);
  }
}
