import '../../../domain/media/media_item.dart';

double playbackQueueDialogContentHeight(double availableHeight) {
  if (!availableHeight.isFinite) {
    return 550;
  }
  return availableHeight.clamp(0, 550);
}

enum CurrentTrackLocateState { visible, hiddenByFilter, unavailable }

bool mediaItemMatchesQuery(MediaItem item, String query) {
  final normalized = query.trim().toLowerCase();
  return normalized.isEmpty ||
      item.title.toLowerCase().contains(normalized) ||
      item.path.toLowerCase().contains(normalized);
}

int? currentTrackIndexInItems({
  required List<MediaItem> items,
  required MediaItem? currentItem,
  int? preferredIndex,
}) {
  if (currentItem == null) {
    return null;
  }
  final identity = _mediaIdentity(currentItem);
  if (preferredIndex != null &&
      preferredIndex >= 0 &&
      preferredIndex < items.length &&
      _mediaIdentity(items[preferredIndex]) == identity) {
    return preferredIndex;
  }
  final index = items.indexWhere((item) => _mediaIdentity(item) == identity);
  return index < 0 ? null : index;
}

CurrentTrackLocateState currentTrackLocateState({
  required List<MediaItem> items,
  required int currentIndex,
  required String query,
}) {
  if (currentIndex < 0 || currentIndex >= items.length) {
    return CurrentTrackLocateState.unavailable;
  }

  final current = items[currentIndex];
  return mediaItemMatchesQuery(current, query)
      ? CurrentTrackLocateState.visible
      : CurrentTrackLocateState.hiddenByFilter;
}

String _mediaIdentity(MediaItem item) =>
    item.path.trim().replaceAll('\\', '/').toLowerCase();
