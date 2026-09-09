import 'dart:io';

import 'package:image/image.dart' as img;

const _iconSizes = [16, 24, 32, 48, 256];
const _defaultSourcePath =
    'output/imagegen/snorlax-headphones-final-v7/app-icon-master.png';
const _outputPath = 'windows/runner/resources/app_icon.ico';

void main(List<String> arguments) {
  if (arguments.length > 2) {
    stderr.writeln(
      'Usage: dart run tool/generate_windows_icon.dart '
      '[source.png] [output.ico]',
    );
    exitCode = 64;
    return;
  }

  generateWindowsIcon(
    sourcePath: arguments.isEmpty ? _defaultSourcePath : arguments[0],
    outputPath: arguments.length < 2 ? _outputPath : arguments[1],
  );
}

void generateWindowsIcon({
  required String sourcePath,
  String outputPath = _outputPath,
}) {
  final sourceBytes = File(sourcePath).readAsBytesSync();
  final source = img.decodeImage(sourceBytes);
  if (source == null) {
    throw FormatException('Unable to decode icon source: $sourcePath');
  }

  final first = _resize(source, _iconSizes.first);
  for (final size in _iconSizes.skip(1)) {
    first.addFrame(_resize(source, size));
  }

  final encoded = img.IcoEncoder().encode(first);
  final output = File(outputPath);
  output.parent.createSync(recursive: true);
  output.writeAsBytesSync(encoded, flush: true);

  final bytes = output.readAsBytesSync();
  if (bytes.length < 6 || bytes[2] != 1) {
    throw StateError('Invalid ICO output: ${bytes.length} bytes');
  }
  final frameCount = bytes[4] | (bytes[5] << 8);
  if (frameCount != _iconSizes.length) {
    throw StateError(
      'Invalid ICO output: ${bytes.length} bytes, $frameCount frames',
    );
  }
  stdout.writeln(
    'Generated $outputPath with $frameCount frames from $sourcePath.',
  );
}

img.Image _resize(img.Image source, int size) {
  return img.copyResize(
    source,
    width: size,
    height: size,
    interpolation: img.Interpolation.average,
  );
}
