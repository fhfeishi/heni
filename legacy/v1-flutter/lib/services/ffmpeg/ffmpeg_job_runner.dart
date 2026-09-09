import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ffmpeg_progress.dart';

abstract interface class FfmpegJobExecutor {
  Stream<FfmpegJobEvent> run(
    List<String> arguments, {
    Duration? timeout,
  });
}

class FfmpegJobRunner implements FfmpegJobExecutor {
  const FfmpegJobRunner({this.ffmpegExecutable = 'ffmpeg'});

  final String ffmpegExecutable;

  @override
  Stream<FfmpegJobEvent> run(
    List<String> arguments, {
    Duration? timeout,
  }) async* {
    final process = await Process.start(
      ffmpegExecutable,
      _withProgress(arguments),
      runInShell: false,
    );
    final controller = StreamController<FfmpegJobEvent>();
    final stderrTail = _LineTail(limit: 50);
    final progressParser = FfmpegProgressParser();
    Timer? timer;
    var timedOut = false;

    controller.add(FfmpegJobStarted(process.pid));

    if (timeout != null) {
      timer = Timer(timeout, () {
        timedOut = true;
        process.kill();
      });
    }

    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();

    final stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        final progress = progressParser.acceptLine(line);
        if (progress != null) {
          controller.add(FfmpegJobProgress(progress));
        }
      },
      onDone: stdoutDone.complete,
      onError: stdoutDone.completeError,
      cancelOnError: true,
    );

    final stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        stderrTail.add(line);
        controller.add(FfmpegJobLog(line));
      },
      onDone: stderrDone.complete,
      onError: stderrDone.completeError,
      cancelOnError: true,
    );

    unawaited(
      process.exitCode.then((exitCode) async {
        timer?.cancel();
        await Future.wait([stdoutDone.future, stderrDone.future]);
        controller.add(
          FfmpegJobCompleted(
            exitCode: exitCode,
            timedOut: timedOut,
            stderrTail: stderrTail.lines,
          ),
        );
        await controller.close();
      }).catchError((Object error, StackTrace stackTrace) async {
        controller.addError(error, stackTrace);
        await controller.close();
      }),
    );

    controller.onCancel = () async {
      timer?.cancel();
      process.kill();
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
    };

    yield* controller.stream;
  }

  List<String> _withProgress(List<String> arguments) {
    if (arguments.contains('-progress')) {
      return arguments;
    }

    final result = <String>[];
    var inserted = false;

    for (final argument in arguments) {
      result.add(argument);
      if (!inserted && argument == '-hide_banner') {
        result.addAll(['-progress', 'pipe:1', '-nostats']);
        inserted = true;
      }
    }

    if (!inserted) {
      result.insertAll(0, ['-progress', 'pipe:1', '-nostats']);
    }

    return result;
  }
}

sealed class FfmpegJobEvent {
  const FfmpegJobEvent();
}

class FfmpegJobStarted extends FfmpegJobEvent {
  const FfmpegJobStarted(this.pid);

  final int pid;
}

class FfmpegJobProgress extends FfmpegJobEvent {
  const FfmpegJobProgress(this.progress);

  final FfmpegProgress progress;
}

class FfmpegJobLog extends FfmpegJobEvent {
  const FfmpegJobLog(this.line);

  final String line;
}

class FfmpegJobCompleted extends FfmpegJobEvent {
  const FfmpegJobCompleted({
    required this.exitCode,
    required this.timedOut,
    required this.stderrTail,
  });

  final int exitCode;
  final bool timedOut;
  final List<String> stderrTail;

  bool get succeeded => exitCode == 0 && !timedOut;
}

class _LineTail {
  _LineTail({required this.limit});

  final int limit;
  final List<String> _lines = [];

  List<String> get lines => List.unmodifiable(_lines);

  void add(String line) {
    _lines.add(line);
    if (_lines.length > limit) {
      _lines.removeAt(0);
    }
  }
}
