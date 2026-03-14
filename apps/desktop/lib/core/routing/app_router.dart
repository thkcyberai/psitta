import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/services/auth_service.dart';
import '../../features/auth/login_screen.dart';
import '../../features/shell/desktop_shell.dart';
import '../../features/library/library_screen.dart';
import '../../features/player/player_screen.dart';
import '../../features/player/player_landing_screen.dart';
import '../../features/projects/projects_screen.dart';
import '../../features/projects/project_detail_screen.dart';
import '../../features/editor/document_editor_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/voices/voice_selector_screen.dart';

/// Desktop routing configuration.
///
/// Uses [ShellRoute] to maintain a persistent desktop shell
/// (sidebar + player bar) while swapping the main content area.
/// The /login route sits outside the shell.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: authState.status == AuthStatus.authenticated
        ? '/library'
        : '/login',
    redirect: (context, state) {
      final loggedIn = authState.status == AuthStatus.authenticated;
      final onLogin = state.uri.toString() == '/login';

      // Not logged in and not already on login → go to login.
      if (!loggedIn && !onLogin) return '/login';
      // Logged in but on login page → go to library.
      if (loggedIn && onLogin) return '/library';
      if (state.uri.toString() == '/') return '/library';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: LoginScreen(),
        ),
      ),
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
          GoRoute(
            path: '/voices',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: VoiceSelectorScreen(),
            ),
          ),
          GoRoute(
            path: '/editor/:documentId',
            pageBuilder: (context, state) {
              final documentId = state.pathParameters['documentId']!;
              final documentTitle =
                  state.uri.queryParameters['title'];
              return NoTransitionPage(
                child: DocumentEditorScreen(
                  documentId: documentId,
                  documentTitle: documentTitle,
                ),
              );
            },
          ),
        ],
      ),
    ],
  );
});
