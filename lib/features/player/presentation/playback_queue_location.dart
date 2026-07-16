import '../../../domain/media/media_item.dart';

String queryForLocatingCurrentTrack({
  required List<MediaItem> items,
  required int currentIndex,
  required String query,
}) {
  if (currentIndex < 0 || currentIndex >= items.length) {
    return query;
  }

  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return '';
  }

  final current = items[currentIndex];
  final matches =
      current.title.toLowerCase().contains(normalized) ||
      current.path.toLowerCase().contains(normalized);
  return matches ? query : '';
}
