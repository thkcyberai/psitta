import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/shell/desktop_shell.dart';
import '../../features/library/library_screen.dart';
import '../../features/player/player_screen.dart';
import '../../features/player/player_landing_screen.dart';
import '../../features/projects/projects_screen.dart';
import '../../features/projects/project_detail_screen.dart';
import '../../features/settings/settings_screen.dart';

/// Desktop routing configuration.
///
/// Uses [ShellRoute] to maintain a persistent desktop shell
/// (sidebar + player bar) while swapping the main content area.
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
            path: '/player',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PlayerLandingScreen(),
            ),
          ),
          GoRoute(
            path: '/player/:documentId',
            pageBuilder: (context, state) => NoTransitionPage(
              child: PlayerScreen(
                documentId: state.pathParameters['documentId']!,
                originProjectId: state.uri.queryParameters['projectId'],
                originProjectName: state.uri.queryParameters['projectName'],
              ),
            ),
          ),
          GoRoute(
            path: '/projects',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProjectsScreen(),
            ),
            routes: [
              GoRoute(
                path: ':projectId',
                builder: (context, state) {
                  final projectId = state.pathParameters['projectId']!;
                  final projectName =
                      state.uri.queryParameters['projectName'] ?? 'Project';
                  return ProjectDetailScreen(
                    projectId: projectId,
                    projectName: projectName,
                  );
                },
              ),
            ],
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
