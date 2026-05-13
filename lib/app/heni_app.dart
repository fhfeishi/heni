import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/app_theme.dart';
import 'router.dart';

class HeniApp extends ConsumerWidget {
  const HeniApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(activePaletteProvider);

    return MaterialApp.router(
      title: 'Heni',
      debugShowCheckedModeBanner: false,
      theme: HeniTheme.light(palette),
      darkTheme: HeniTheme.dark(palette),
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
