import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/shell/desktop_shell.dart';
import '../../features/library/library_screen.dart';
import '../../features/player/player_screen.dart';
import '../../features/voices/voice_selector_screen.dart';
import '../../features/settings/settings_screen.dart';

/// Desktop routing configuration.
///
/// Uses [ShellRoute] to maintain a persistent desktop shell
/// (sidebar + player bar) while swapping the main content area.
/// This is the key desktop UX pattern — the shell never rebuilds
/// when navigating between library, player, voices, settings.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/library',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return DesktopShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/library',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LibraryScreen(),
            ),
          ),
          GoRoute(
            path: '/player/:documentId',
            pageBuilder: (context, state) => NoTransitionPage(
              child: PlayerScreen(
                documentId: state.pathParameters['documentId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/voices',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: VoiceSelectorScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});
