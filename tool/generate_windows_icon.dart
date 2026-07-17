import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _iconSizes = [16, 24, 32, 48, 256];
const _outputPath = 'windows/runner/resources/app_icon.ico';

void main() {
  final source = _drawWordmarkIcon();
  final first = _resize(source, _iconSizes.first);
  for (final size in _iconSizes.skip(1)) {
    first.addFrame(_resize(source, size));
  }

  final encoded = img.IcoEncoder().encode(first);
  File(_outputPath).writeAsBytesSync(encoded, flush: true);

  final bytes = File(_outputPath).readAsBytesSync();
  final frameCount = bytes[4] | (bytes[5] << 8);
  if (bytes.length < 6 || bytes[2] != 1 || frameCount != _iconSizes.length) {
    throw StateError(
      'Invalid ICO output: ${bytes.length} bytes, $frameCount frames',
    );
  }
  stdout.writeln('Generated $_outputPath with $frameCount frames.');
}

img.Image _drawWordmarkIcon() {
  const size = 256;
  final icon = img.Image(width: size, height: size, numChannels: 4);

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final px = x + 0.5 - size / 2;
      final py = y + 0.5 - size / 2;
      final dx = math.max(px.abs() - 76, 0);
      final dy = math.max(py.abs() - 76, 0);
      final edgeDistance = math.sqrt(dx * dx + dy * dy);
      final coverage = (44.5 - edgeDistance).clamp(0.0, 1.0);
      if (coverage == 0) {
        icon.setPixelRgba(x, y, 0, 0, 0, 0);
        continue;
      }

      final diagonal = ((x + y) / (size * 2 - 2)).clamp(0.0, 1.0);
      final glow = math.max(0.0, 1 - math.sqrt(px * px + py * py) / 181);
      final red = _lerp(58, 148, diagonal) + (14 * glow).round();
      final green = _lerp(76, 82, diagonal) + (10 * glow).round();
      final blue = _lerp(218, 220, diagonal) + (18 * glow).round();
      icon.setPixelRgba(
        x,
        y,
        red.clamp(0, 255),
        green.clamp(0, 255),
        blue.clamp(0, 255),
        (coverage * 255).round(),
      );
    }
  }

  img.drawString(
    icon,
    'heni',
    font: img.arial48,
    color: img.ColorRgba8(255, 255, 255, 244),
  );
  return icon;
}

img.Image _resize(img.Image source, int size) {
  return img.copyResize(
    source,
    width: size,
    height: size,
    interpolation: img.Interpolation.average,
  );
}

int _lerp(int start, int end, double amount) {
  return (start + (end - start) * amount).round();
}
