import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heni/design/app_theme.dart';
import 'package:heni/domain/media/media_item.dart';
import 'package:heni/domain/media/media_kind.dart';
import 'package:heni/domain/media/media_probe.dart';
import 'package:heni/features/player/presentation/listening_console.dart';

void main() {
  const current = MediaItem(
    path: r'D:\Music\Midnight Drive.m4a',
    title: 'Midnight Drive',
    kind: MediaKind.audio,
  );
  const next = MediaItem(
    path: r'D:\Music\Soft Static.flac',
    title: 'Soft Static',
    kind: MediaKind.audio,
  );
  const aacProbe = MediaProbe(
    sourcePath: r'D:\Music\Midnight Drive.m4a',
    streams: [
      MediaStreamProbe(
        index: 0,
        kind: MediaKind.audio,
        tags: {},
        codecName: 'aac',
        profile: 'LC',
        bitRate: 256000,
        sampleRate: 44100,
        channels: 2,
      ),
    ],
    chapters: [],
    tags: {},
  );

  test('formats actual audio properties without false lossless labels', () {
    expect(
      heniAudioDetailLabels(aacProbe),
      containsAll(['AAC LC', '256 kbps', '44.1 kHz', '双声道']),
    );
    expect(heniAudioDetailLabels(aacProbe), isNot(contains('无损')));
  });

  test('labels a FLAC stream as lossless', () {
    const flacProbe = MediaProbe(
      sourcePath: r'D:\Music\Lossless.flac',
      streams: [
        MediaStreamProbe(
          index: 0,
          kind: MediaKind.audio,
          tags: {},
          codecName: 'flac',
          sampleRate: 96000,
          channels: 2,
        ),
      ],
      chapters: [],
      tags: {},
    );

    expect(heniAudioDetailLabels(flacProbe), containsAll(['FLAC', '无损']));
  });

  testWidgets('shows useful current-track actions and next media when wide', (
    tester,
  ) async {
    var locateCount = 0;
    var revealCount = 0;

    await tester.pumpWidget(
      _host(
        width: 1200,
        child: HeniListeningConsole(
          palette: HeniPalette.plum,
          currentMedia: current,
          nextMedia: next,
          mediaProbe: const AsyncData(aacProbe),
          isPlaying: true,
          libraryItemCount: 286,
          libraryDirectoryCount: 3,
          statusMessage: null,
          onLocateCurrent: () => locateCount += 1,
          onOpenFileLocation: () => revealCount += 1,
          onPickMedia: () {},
          onPickFolder: () {},
        ),
      ),
    );

    expect(find.text('Midnight Drive'), findsOneWidget);
    expect(find.text('实际播放参数'), findsOneWidget);
    expect(find.text('原始解码播放，不进行二次转码'), findsOneWidget);
    expect(find.text('Soft Static'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('listening-console-side-panel')),
      findsOneWidget,
    );

    await tester.tap(find.text('定位当前曲目'));
    await tester.tap(find.text('打开文件位置'));

    expect(locateCount, 1);
    expect(revealCount, 1);
  });

  testWidgets('hides the side panel before the core controls at narrow width', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        width: 700,
        child: HeniListeningConsole(
          palette: HeniPalette.plum,
          currentMedia: current,
          nextMedia: next,
          mediaProbe: const AsyncData(aacProbe),
          isPlaying: false,
          libraryItemCount: 286,
          libraryDirectoryCount: 3,
          statusMessage: null,
          onLocateCurrent: () {},
          onOpenFileLocation: () {},
          onPickMedia: () {},
          onPickFolder: () {},
        ),
      ),
    );

    expect(find.text('Midnight Drive'), findsOneWidget);
    expect(find.text('定位当前曲目'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('listening-console-side-panel')),
      findsNothing,
    );
  });

  testWidgets('uses a practical library start state when nothing is playing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        width: 900,
        child: HeniListeningConsole(
          palette: HeniPalette.plum,
          currentMedia: null,
          nextMedia: null,
          mediaProbe: const AsyncData(null),
          isPlaying: false,
          libraryItemCount: 286,
          libraryDirectoryCount: 3,
          statusMessage: '曲库已就绪',
          onLocateCurrent: () {},
          onOpenFileLocation: () {},
          onPickMedia: () {},
          onPickFolder: () {},
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('listening-console-empty-state')),
      findsOneWidget,
    );
    expect(find.text('选择文件'), findsOneWidget);
    expect(find.text('导入目录'), findsOneWidget);
    expect(find.textContaining('286'), findsOneWidget);
    expect(find.text('实际播放参数'), findsNothing);
  });
}

Widget _host({required double width, required Widget child}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, height: 560, child: child),
      ),
    ),
  );
}
