import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/heni_app.dart';
import 'domain/media/media_path.dart';
import 'features/player/application/playback_queue_controller.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final launchMediaPaths = [
    for (final path in args)
      if (File(path).existsSync() && isSupportedMediaPath(path)) path,
  ];

  runApp(
    ProviderScope(
      overrides: [launchMediaPathsProvider.overrideWithValue(launchMediaPaths)],
      child: const HeniApp(),
    ),
  );
}
