import 'dart:io';

typedef FileExists = bool Function(String path);
typedef FileProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

enum LocalFileActionResult { success, missing, unsupported, failed }

class LocalFileActions {
  LocalFileActions({
    FileExists? exists,
    bool? isWindows,
    FileProcessRunner? runProcess,
  }) : exists = exists ?? FileSystemEntity.isFileSync,
       isWindows = isWindows ?? Platform.isWindows,
       runProcess = runProcess ?? _runProcess;

  final FileExists exists;
  final bool isWindows;
  final FileProcessRunner runProcess;

  Future<LocalFileActionResult> revealInFileManager(String path) async {
    if (!exists(path)) {
      return LocalFileActionResult.missing;
    }
    if (!isWindows) {
      return LocalFileActionResult.unsupported;
    }

    try {
      final result = await runProcess('explorer.exe', ['/select,$path']);
      return result.exitCode == 0
          ? LocalFileActionResult.success
          : LocalFileActionResult.failed;
    } on Object {
      return LocalFileActionResult.failed;
    }
  }

  static Future<ProcessResult> _runProcess(
    String executable,
    List<String> arguments,
  ) {
    return Process.run(executable, arguments);
  }
}
