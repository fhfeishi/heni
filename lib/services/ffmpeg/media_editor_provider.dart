import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'media_editor.dart';

final mediaEditorProvider = Provider<FfmpegMediaEditor>((ref) {
  return const FfmpegMediaEditor();
});
