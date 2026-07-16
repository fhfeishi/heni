import 'dart:io';

import 'package:heni/services/files/local_file_actions.dart';
import 'package:test/test.dart';

void main() {
  const path = r'D:\Music\Midnight Drive.m4a';

  test('reveals an existing Windows file with Explorer selection', () async {
    String? executable;
    List<String>? arguments;
    final actions = LocalFileActions(
      exists: (_) => true,
      isWindows: true,
      runProcess: (nextExecutable, nextArguments) async {
        executable = nextExecutable;
        arguments = nextArguments;
        return ProcessResult(1, 0, '', '');
      },
    );

    final result = await actions.revealInFileManager(path);

    expect(result, LocalFileActionResult.success);
    expect(executable, 'explorer.exe');
    expect(arguments, ['/select,$path']);
  });

  test('does not start Explorer when the file is missing', () async {
    var invoked = false;
    final actions = LocalFileActions(
      exists: (_) => false,
      isWindows: true,
      runProcess: (executable, arguments) async {
        invoked = true;
        return ProcessResult(1, 0, '', '');
      },
    );

    expect(
      await actions.revealInFileManager(path),
      LocalFileActionResult.missing,
    );
    expect(invoked, isFalse);
  });

  test('reports a failed Explorer process', () async {
    final actions = LocalFileActions(
      exists: (_) => true,
      isWindows: true,
      runProcess:
          (executable, arguments) async => ProcessResult(1, 1, '', 'failed'),
    );

    expect(
      await actions.revealInFileManager(path),
      LocalFileActionResult.failed,
    );
  });
}
