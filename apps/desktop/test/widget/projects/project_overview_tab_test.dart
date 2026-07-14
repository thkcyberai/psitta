// Widget tests for the Project Overview tab (5c): stat figures compute from
// overridden providers, the Recent Documents Blueprint/Section column resolves
// from placements (Unassigned fallback), the adopt picker calls adoptBlueprint,
// and the tab builds under all 4 themes.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:psitta/core/theme/app_theme.dart';
import 'package:psitta/data/models/blueprint.dart';
import 'package:psitta/data/models/document.dart';
import 'package:psitta/data/models/project_detail.dart';
import 'package:psitta/data/providers/blueprint_providers.dart';
import 'package:psitta/data/providers/project_providers.dart';
import 'package:psitta/data/services/preferences_service.dart';
import 'package:psitta/features/projects/widgets/project_overview_tab.dart';
import 'package:psitta/l10n/app_localizations.dart';

class MockBlueprintActions extends Mock implements BlueprintActions {}

ProjectDetail _detail() => ProjectDetail.fromJson(const <String, dynamic>{
      'id': 'p1',
      'name': 'My First Book',
      'user_id': 'u1',
      'created_at': '2026-06-01T00:00:00Z',
      'updated_at': '2026-06-08T00:00:00Z',
      'document_count': 3,
      'blueprint_count': 1,
      'total_words': 1234,
    });

ProjectBlueprintOverview _overview() =>
    ProjectBlueprintOverview.fromJson(const <String, dynamic>{
      'progress': {'leaves_with_content': 1, 'total_leaves': 2, 'ratio': 0.5},
      'blueprints': [
        {
          'id': 'b1',
          'name': 'Nested',
          'description': null,
          'genre': 'Novel',
          'status': 'Draft',
          'is_system': false,
          'source_template_id': null,
          'is_primary': true,
          'adopted_at': '2026-06-08T12:00:00Z',
          'progress': {
            'leaves_with_content': 1,
            'total_leaves': 2,
            'ratio': 0.5,
          },
          'parts': [
            {
              'id': 'pt1',
              'name': 'Act I',
              'description': null,
              'sort_order': 1000.0,
              'document_count': 1,
              'has_content': true,
              'readiness': 'ready',
              'children': <dynamic>[],
            },
            {
              'id': 'pt2',
              'name': 'Act II',
              'description': null,
              'sort_order': 2000.0,
              'document_count': 1,
              'has_content': true,
              'readiness': 'ready',
              'children': <dynamic>[],
            },
          ],
        },
      ],
    });

Document _doc(String id, String title, String status) =>
    Document.fromJson(<String, dynamic>{
      'id': id,
      'title': title,
      'status': status,
      'source_type': 'docx',
      'page_count': 1,
      'word_count': 10,
      'project_id': 'p1',
      'cover_type': null,
      'cover_value': null,
      'created_at': '2026-06-01T00:00:00Z',
    });

List<Document> _docs() => [
      _doc('d1', 'Chapter One', 'ready'),
      _doc('d2', 'Chapter Two', 'ready'),
      _doc('d3', 'Old Draft', 'archived'),
    ];

ProjectPlacement _placement() => ProjectPlacement.fromJson(const <String, dynamic>{
      'document_id': 'd1',
      'blueprint_id': 'b1',
      'part_id': 'pt1',
      'blueprint_name': 'Nested',
      'part_name': 'Act I',
      'role': 'Main Content',
      'sort_order': 1000.0,
    });

List<Override> _base({List<Override> extra = const []}) => [
      projectDetailProvider('p1').overrideWith((ref) async => _detail()),
      projectBlueprintOverviewProvider('p1').overrideWith((ref) async => _overview()),
      projectDocumentsProvider('p1').overrideWith((ref) async => _docs()),
      projectPlacementsProvider('p1').overrideWith((ref) async => [_placement()]),
      ...extra,
    ];

Future<void> _pump(
  WidgetTester tester, {
  ThemeData? theme,
  List<Override> extra = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _base(extra: extra),
      child: MaterialApp(
        theme: theme ?? AppTheme.creatorStudioDark,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DefaultTabController(
          length: 4,
          child: Scaffold(body: ProjectOverviewTab(projectId: 'p1')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _statValue(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  setUpAll(() => registerFallbackValue(false));

  testWidgets('stat cards compute total / in-blueprints / unassigned / archived',
      (tester) async {
    await _pump(tester);
    expect(_statValue(tester, 'stat-documents-value'), '3');
    expect(_statValue(tester, 'stat-in-blueprints-value'), '2');
    expect(_statValue(tester, 'stat-unassigned-value'), '1'); // 3 - 2
    expect(_statValue(tester, 'stat-archived-value'), '1');
  });

  testWidgets('Blueprint/Section column resolves from placements with fallback',
      (tester) async {
    await _pump(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('doc-section-d1'))).data,
      'Nested / Act I',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('doc-section-d2'))).data,
      'Unassigned',
    );
  });

  testWidgets('adopted blueprint card shows Primary + counts', (tester) async {
    await _pump(tester);
    expect(find.text('Nested'), findsWidgets);
    expect(find.text('Primary'), findsOneWidget);
    expect(find.text('2 sections'), findsOneWidget);
  });

  testWidgets('Add Blueprint to Project picker adopts the chosen blueprint',
      (tester) async {
    final actions = MockBlueprintActions();
    when(() => actions.adoptBlueprint(any(), any(),
            isPrimary: any(named: 'isPrimary')))
        .thenAnswer((_) async => _overview().blueprints.first);

    BlueprintSummary summary(String id, String name, {bool isSystem = false}) =>
        BlueprintSummary.fromJson(<String, dynamic>{
          'id': id,
          'name': name,
          'description': null,
          'genre': 'Novel',
          'status': 'Draft',
          'is_system': isSystem,
          'source_template_id': null,
        });

    await _pump(tester, extra: [
      blueprintActionsProvider.overrideWithValue(actions),
      // b1 is already adopted (filtered out); b2 is the only candidate.
      blueprintsListProvider.overrideWith(
        (ref) async => [summary('b1', 'Nested'), summary('b2', 'Memoir BP')],
      ),
    ]);

    await tester.tap(
      find.byKey(const ValueKey('add-blueprint-to-project-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adopt-candidate-b2')));
    await tester.pumpAndSettle();

    verify(() => actions.adoptBlueprint('p1', 'b2', isPrimary: false)).called(1);
  });

  for (final themeName in ThemeNames.all) {
    testWidgets('builds under the "$themeName" theme', (tester) async {
      await _pump(tester, theme: AppTheme.forName(themeName));
      expect(tester.takeException(), isNull);
      expect(find.byType(ProjectOverviewTab), findsOneWidget);
    });
  }
}
