import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/home_screen.dart';
import '../../features/player/player_screen.dart';
import '../../features/voices/voice_selector_screen.dart';
import '../../features/settings/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(initialLocation: '/', routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/player/:documentId', builder: (context, state) =>
      PlayerScreen(documentId: state.pathParameters['documentId']!)),
    GoRoute(path: '/voices', builder: (context, state) => const VoiceSelectorScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
  ]);
});
