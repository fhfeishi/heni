import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ffprobe_media_inspector.dart';
import 'media_inspector.dart';

final mediaInspectorProvider = Provider<MediaInspector>((ref) {
  return const FfprobeMediaInspector();
});
