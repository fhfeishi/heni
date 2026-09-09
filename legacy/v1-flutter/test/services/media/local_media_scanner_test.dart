import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heni/domain/media/media_kind.dart';
import 'package:heni/services/media/local_media_scanner.dart';

void main() {
  test('scans supported media files and respects includeVideo', () async {
    final root = await Directory.systemTemp.createTemp('heni_scan_');
    addTearDown(() => root.delete(recursive: true));

    await File('${root.path}${Platform.pathSeparator}voice.mp3').writeAsString('');
    await File('${root.path}${Platform.pathSeparator}movie.mkv').writeAsString('');
    await File('${root.path}${Platform.pathSeparator}notes.txt').writeAsString('');

    final scanner = const LocalMediaScanner();

    final all = await scanner.scanDirectory(root.path);
    expect(all.map((item) => item.kind), containsAll([MediaKind.audio, MediaKind.video]));
    expect(all.map((item) => item.title), containsAll(['voice', 'movie']));

    final audioOnly = await scanner.scanDirectory(root.path, includeVideo: false);
    expect(audioOnly, hasLength(1));
    expect(audioOnly.single.kind, MediaKind.audio);
  });

  test('recursive scanning can be disabled', () async {
    final root = await Directory.systemTemp.createTemp('heni_scan_recursive_');
    addTearDown(() => root.delete(recursive: true));

    final child = Directory('${root.path}${Platform.pathSeparator}child');
    await child.create();
    await File('${child.path}${Platform.pathSeparator}nested.flac').writeAsString('');

    final scanner = const LocalMediaScanner();

    final shallow = await scanner.scanDirectory(root.path, recursive: false);
    final recursive = await scanner.scanDirectory(root.path);

    expect(shallow, isEmpty);
    expect(recursive, hasLength(1));
  });
}
