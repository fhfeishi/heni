import 'package:heni/domain/media/media_item.dart';
import 'package:heni/domain/media/media_kind.dart';
import 'package:heni/features/player/presentation/playback_queue_location.dart';
import 'package:test/test.dart';

void main() {
  const items = [
    MediaItem(
      path: r'D:\music\alpha.mp3',
      title: 'Alpha',
      kind: MediaKind.audio,
    ),
    MediaItem(
      path: r'D:\music\beta.flac',
      title: 'Beta',
      kind: MediaKind.audio,
    ),
  ];

  test('reports when the current track is hidden by the active filter', () {
    expect(
      currentTrackLocateState(items: items, currentIndex: 1, query: 'alpha'),
      CurrentTrackLocateState.hiddenByFilter,
    );
  });

  test('reports when the current track is visible', () {
    expect(
      currentTrackLocateState(items: items, currentIndex: 1, query: 'beta'),
      CurrentTrackLocateState.visible,
    );
  });

  test('reports when there is no valid current track', () {
    expect(
      currentTrackLocateState(items: items, currentIndex: -1, query: 'alpha'),
      CurrentTrackLocateState.unavailable,
    );
  });

  test('queue dialog content uses the available short-window height', () {
    expect(playbackQueueDialogContentHeight(380), 380);
  });

  test('queue dialog content is capped on tall windows', () {
    expect(playbackQueueDialogContentHeight(720), 550);
    expect(playbackQueueDialogContentHeight(double.infinity), 550);
  });
}
