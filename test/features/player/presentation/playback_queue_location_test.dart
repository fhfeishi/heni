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

  test('clears a query that hides the current track', () {
    expect(
      queryForLocatingCurrentTrack(
        items: items,
        currentIndex: 1,
        query: 'alpha',
      ),
      isEmpty,
    );
  });

  test('keeps a query that already includes the current track', () {
    expect(
      queryForLocatingCurrentTrack(
        items: items,
        currentIndex: 1,
        query: 'beta',
      ),
      'beta',
    );
  });

  test('keeps the query when there is no valid current track', () {
    expect(
      queryForLocatingCurrentTrack(
        items: items,
        currentIndex: -1,
        query: 'alpha',
      ),
      'alpha',
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
