import 'dart:async';
import 'dart:convert';
import 'dart:io';

abstract interface class MediaProcessRunner {
  Future<MediaProcessResult> run(
    String executable,
    List<String> arguments, {
    Duration timeout,
  });
}

class SystemMediaProcessRunner implements MediaProcessRunner {
  const SystemMediaProcessRunner();

  @override
  Future<MediaProcessResult> run(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      runInShell: false,
    );
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();

    final exitCode = await process.exitCode.timeout(
      timeout,
      onTimeout: () {
        process.kill();
        throw MediaProcessTimeout(executable, arguments, timeout);
      },
    );

    return MediaProcessResult(
      exitCode: exitCode,
      stdout: await stdoutFuture,
      stderr: await stderrFuture,
    );
  }
}

class MediaProcessResult {
  const MediaProcessResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  bool get succeeded => exitCode == 0;
}

class MediaProcessTimeout implements Exception {
  const MediaProcessTimeout(this.executable, this.arguments, this.timeout);

  final String executable;
  final List<String> arguments;
  final Duration timeout;

  @override
  String toString() {
    return 'Media process timed out after $timeout: $executable $arguments';
  }
}
