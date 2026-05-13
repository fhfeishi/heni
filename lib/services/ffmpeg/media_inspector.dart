import '../../domain/media/media_probe.dart';

abstract interface class MediaInspector {
  Future<MediaProbe> inspectPath(String path);
}
