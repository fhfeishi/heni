import '../../../domain/media/media_item.dart';

double playbackQueueDialogContentHeight(double availableHeight) {
  if (!availableHeight.isFinite) {
    return 550;
  }
  return availableHeight.clamp(0, 550);
}

enum CurrentTrackLocateState { visible, hiddenByFilter, unavailable }

CurrentTrackLocateState currentTrackLocateState({
  required List<MediaItem> items,
  required int currentIndex,
  required String query,
}) {
  if (currentIndex < 0 || currentIndex >= items.length) {
    return CurrentTrackLocateState.unavailable;
  }

  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return CurrentTrackLocateState.visible;
  }

  final current = items[currentIndex];
  final matches =
      current.title.toLowerCase().contains(normalized) ||
      current.path.toLowerCase().contains(normalized);
  return matches
      ? CurrentTrackLocateState.visible
      : CurrentTrackLocateState.hiddenByFilter;
}
