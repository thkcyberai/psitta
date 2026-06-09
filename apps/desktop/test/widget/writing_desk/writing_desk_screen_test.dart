// Widget tests for WD-1: WritingDeskScreen — route resolves to the screen,
// all three pane keys render, optional projectId is forwarded, and the screen
// builds under all 4 themes without exceptions.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:psitta/core/theme/app_theme.dart';
import 'package:psitta/data/models/blueprint.dart';
import 'package:psitta/data/models/document.dart';
import 'package:psitta/data/models/project_detail.dart';
import 'package:psitta/data/providers/blueprint_providers.dart';
import 'package:psitta/data/providers/project_providers.dart';
import 'package:psitta/data/services/preferences_service.dart';
import 'package:psitta/features/writing_desk/writing_desk_screen.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

GoRouter _router({String? projectId}) {
  final qs = projectId != null ? '?projectId=$projectId' : '';
  return GoRouter(
    initialLocation: '/writing-desk/doc-123$qs',
    routes: [
      GoRoute(
        path: '/writing-desk/:documentId',
        pageBuilder: (context, state) => NoTransitionPage(
          child: WritingDeskScreen(
            documentId: state.pathParameters['documentId']!,
            projectId: state.uri.queryParameters['projectId'],
          ),
        ),
      ),
    ],
  );
}

// Stub overrides for the navigator pane providers — return minimal empty data
// so the navigator renders without network calls.
List<Override> _stubNavigatorProviders(String? projectId) {
  if (projectId == null) return const [];
  final emptyOverview =
      ProjectBlueprintOverview.fromJson(<String, dynamic>{
    'progress': null,
    'blueprints': <dynamic>[],
  });
  return [
    projectBlueprintOverviewProvider(projectId)
        .overrideWith((ref) async => emptyOverview),
    projectDocumentsProvider(projectId)
        .overrideWith((ref) async => <Document>[]),
    projectPlacementsProvider(projectId)
        .overrideWith((ref) async => <ProjectPlacement>[]),
  ];
}

Future<void> _pump(
  WidgetTester tester, {
  ThemeData? theme,
  String? projectId,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _stubNavigatorProviders(projectId),
      child: MaterialApp.router(
        theme: theme ?? AppTheme.creatorStudioDark,
        routerConfig: _router(projectId: projectId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ── tests ─────────────────────────────────────────────────────────────────────

void main() {
  testWidgets('route resolves to WritingDeskScreen', (tester) async {
    await _pump(tester);
    expect(find.byType(WritingDeskScreen), findsOneWidget);
  });

  testWidgets('shell renders navigator, center and context panes',
      (tester) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('desk-navigator-pane')), findsOneWidget);
    expect(find.byKey(const ValueKey('desk-center-pane')), findsOneWidget);
    expect(find.byKey(const ValueKey('desk-context-pane')), findsOneWidget);
  });

  testWidgets('optional projectId is forwarded without error', (tester) async {
    await _pump(tester, projectId: 'p-xyz');
    expect(find.byType(WritingDeskScreen), findsOneWidget);
  });

  for (final themeName in ThemeNames.all) {
    testWidgets('builds under the "$themeName" theme', (tester) async {
      await _pump(tester, theme: AppTheme.forName(themeName));
      expect(tester.takeException(), isNull);
      expect(find.byType(WritingDeskScreen), findsOneWidget);
    });
  }
}
