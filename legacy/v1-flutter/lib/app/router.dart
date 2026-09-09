import 'package:go_router/go_router.dart';

import '../features/player/presentation/player_screen.dart';

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const PlayerScreen(),
    ),
  ],
);
