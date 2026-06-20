import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/services/auth_service.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/plan_selection_screen.dart';
import '../../features/shell/desktop_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/library/archive_screen.dart';
import '../../features/library/scribbles_screen.dart';
import '../../features/library/trash_screen.dart';
import '../../features/library/whispers_screen.dart';
import '../../features/library/writing_library_screen.dart';
import '../../features/player/player_screen.dart';
import '../../features/player/player_landing_screen.dart';
import '../../features/projects/projects_screen.dart';
import '../../features/projects/project_detail_screen.dart';
import '../../features/blueprints/blueprints_screen.dart';
import '../../features/editor/document_editor_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/voices/voice_selector_screen.dart';
import '../../features/writing_desk/writing_desk_screen.dart';
import '../../features/help/help_screen.dart';
import '../../features/analytics/analytics_screen.dart';

/// A [ChangeNotifier] that bridges Riverpod [AuthState] to GoRouter.
///
/// GoRouter's [refreshListenable] requires a [Listenable].
/// This notifier watches [authStateProvider] and calls [notifyListeners]
/// whenever auth state changes, triggering GoRouter to re-evaluate redirects.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(this._ref) {
    _ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (previous?.status != next.status) {
        notifyListeners();
      }
    });
  }

  final Ref _ref;
}

/// Desktop routing configuration.
///
/// Uses [ShellRoute] to maintain a persistent desktop shell
/// (sidebar + player bar) while swapping the main content area.
/// The /login route sits outside the shell.
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifier(ref);

  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final path = state.uri.path;
      // SplashScreen handles its own post-delay navigation. Skip the
      // auth guard here so the splash renders on cold launch regardless
      // of auth state. Re-navigation to '/' is never triggered after
      // login/logout, so no loop is possible.
      if (path == '/') return null;

      final authState = ref.read(authStateProvider);
      final loggedIn = authState.status == AuthStatus.authenticated;
      final onLogin = path == '/login';

      // Not logged in and not already on login → go to login.
      if (!loggedIn && !onLogin) return '/login';
      // Logged in but on login page → go to library.
      if (loggedIn && onLogin) return '/library';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: LoginScreen(),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return DesktopShell(
            currentLocation: state.uri.path,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/plan',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PlanSelectionScreen(),
            ),
          ),
          GoRoute(
            path: '/library',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LibraryRoute(),
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
            path: '/blueprints',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BlueprintsScreen(),
            ),
          ),
          GoRoute(
            path: '/trash',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TrashScreen(),
            ),
          ),
          GoRoute(
            path: '/archive',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ArchiveScreen(),
            ),
          ),
          GoRoute(
            path: '/whispers',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: WhispersScreen(),
            ),
          ),
          GoRoute(
            path: '/scribbles',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ScribblesScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
          GoRoute(
            path: '/help',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HelpScreen(),
            ),
          ),
          GoRoute(
            path: '/voices',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: VoiceSelectorScreen(),
            ),
          ),
          GoRoute(
            path: '/analytics',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AnalyticsScreen(),
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
          GoRoute(
            path: '/writing-desk/:documentId',
            pageBuilder: (context, state) => NoTransitionPage(
              child: WritingDeskScreen(
                documentId: state.pathParameters['documentId']!,
                projectId: state.uri.queryParameters['projectId'],
                initialRead: state.uri.queryParameters['read'] == '1',
              ),
            ),
          ),
        ],
      ),
    ],
  );
});
