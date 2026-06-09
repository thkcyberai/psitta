// Widget tests for WD-2: ProjectNavigatorPane.
//
// Verifies: null-project guard, blueprint selector (multi-blueprint), section
// list names, placed-doc tiles, and the assign-to-section dialog calling
// blueprintActionsProvider.setPlacement.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:psitta/core/theme/app_theme.dart';
import 'package:psitta/data/models/blueprint.dart';
import 'package:psitta/data/models/blueprint_enums.dart';
import 'package:psitta/data/models/document.dart';
import 'package:psitta/data/models/project_detail.dart';
import 'package:psitta/data/providers/blueprint_providers.dart';
import 'package:psitta/data/providers/project_providers.dart';
import 'package:psitta/data/services/preferences_service.dart';
import 'package:psitta/features/writing_desk/project_navigator_pane.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockBlueprintActions extends Mock implements BlueprintActions {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

ProjectBlueprintOverview _overview({bool twoBlueprintsByDefault = false}) =>
    ProjectBlueprintOverview.fromJson(<String, dynamic>{
      'progress': {'leaves_with_content': 1, 'total_leaves': 2, 'ratio': 0.5},
      'blueprints': [
        {
          'id': 'b1',
          'name': 'Novel Blueprint',
          'description': null,
          'genre': 'Novel',
          'status': 'Draft',
          'is_system': false,
          'source_template_id': null,
          'is_primary': true,
          'adopted_at': '2026-06-01T00:00:00Z',
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
              'document_count': 0,
              'has_content': false,
              'readiness': 'empty',
              'children': <dynamic>[],
            },
          ],
        },
        if (twoBlueprintsByDefault) ...[
          {
            'id': 'b2',
            'name': 'Memoir Blueprint',
            'description': null,
            'genre': 'Memoir',
            'status': 'Draft',
            'is_system': false,
            'source_template_id': null,
            'is_primary': false,
            'adopted_at': '2026-06-02T00:00:00Z',
            'progress': {
              'leaves_with_content': 0,
              'total_leaves': 1,
              'ratio': 0.0,
            },
            'parts': <dynamic>[],
          },
        ],
      ],
    });

List<Document> _docs() => [
      Document.fromJson(<String, dynamic>{
        'id': 'd1',
        'title': 'Chapter One',
        'status': 'ready',
        'source_type': 'docx',
        'page_count': 1,
        'word_count': 100,
        'project_id': 'p1',
        'cover_type': null,
        'cover_value': null,
        'created_at': '2026-06-01T00:00:00Z',
      }),
      Document.fromJson(<String, dynamic>{
        'id': 'd2',
        'title': 'The Prologue',
        'status': 'ready',
        'source_type': 'docx',
        'page_count': 1,
        'word_count': 50,
        'project_id': 'p1',
        'cover_type': null,
        'cover_value': null,
        'created_at': '2026-06-02T00:00:00Z',
      }),
    ];

List<ProjectPlacement> _placements() => [
      ProjectPlacement.fromJson(const <String, dynamic>{
        'document_id': 'd1',
        'blueprint_id': 'b1',
        'part_id': 'pt1',
        'blueprint_name': 'Novel Blueprint',
        'part_name': 'Act I',
        'role': 'Main Content',
        'sort_order': 1000.0,
      }),
    ];

List<Override> _overrides({
  bool twoBlueprintsByDefault = false,
  List<Override> extra = const [],
}) =>
    [
      projectBlueprintOverviewProvider('p1')
          .overrideWith((ref) async => _overview(
                twoBlueprintsByDefault: twoBlueprintsByDefault,
              )),
      projectDocumentsProvider('p1').overrideWith((ref) async => _docs()),
      projectPlacementsProvider('p1')
          .overrideWith((ref) async => _placements()),
      ...extra,
    ];

Future<void> _pump(
  WidgetTester tester, {
  String? projectId = 'p1',
  ThemeData? theme,
  bool twoBlueprints = false,
  List<Override> extra = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(
        twoBlueprintsByDefault: twoBlueprints,
        extra: extra,
      ),
      child: MaterialApp(
        theme: theme ?? AppTheme.creatorStudioDark,
        home: Scaffold(
          body: ProjectNavigatorPane(
            documentId: 'doc-abc',
            projectId: projectId,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ── tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(Role.mainContent);
  });

  // ── Null-project guard ───────────────────────────────────────────────────
  testWidgets('null-project guard shows the correct message', (tester) async {
    await _pump(tester, projectId: null);
    expect(find.byKey(const ValueKey('desk-navigator-null-guard')),
        findsOneWidget);
    expect(find.text('Open from a project to see the structure'),
        findsOneWidget);
  });

  // ── Blueprint selector ───────────────────────────────────────────────────
  testWidgets('blueprint selector NOT shown for single blueprint',
      (tester) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('desk-blueprint-selector')), findsNothing);
  });

  testWidgets('blueprint selector shown when project has 2+ blueprints',
      (tester) async {
    await _pump(tester, twoBlueprints: true);
    expect(
        find.byKey(const ValueKey('desk-blueprint-selector')), findsOneWidget);
  });

  // ── Section list ─────────────────────────────────────────────────────────
  testWidgets('section names render from the blueprint parts', (tester) async {
    await _pump(tester);
    expect(
        find.byKey(const ValueKey('desk-section-name-pt1')), findsOneWidget);
    expect(find.text('Act I'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('desk-section-name-pt2')), findsOneWidget);
    expect(find.text('Act II'), findsOneWidget);
  });

  // ── Placed doc tiles ─────────────────────────────────────────────────────
  testWidgets('placed doc tile renders under its section', (tester) async {
    await _pump(tester);
    // d1 is placed in pt1 (Act I)
    expect(find.byKey(const ValueKey('desk-placed-doc-d1')), findsOneWidget);
  });

  testWidgets('unplaced doc has Assign button', (tester) async {
    await _pump(tester);
    // d2 is NOT in placements → shows assign button
    expect(find.byKey(const ValueKey('desk-assign-d2')), findsOneWidget);
  });

  // ── Assign dialog calls setPlacement ─────────────────────────────────────
  testWidgets('assign dialog calls setPlacement with correct args',
      (tester) async {
    final actions = MockBlueprintActions();
    when(() => actions.setPlacement(
          any(),
          any(),
          any(),
          projectId: any(named: 'projectId'),
        )).thenAnswer((_) async => DocumentPlacement.fromJson(const {
          'id': 'pl1',
          'document_id': 'd2',
          'part_id': 'pt1',
          'blueprint_id': 'b1',
          'role': 'Main Content',
          'sort_order': 2000.0,
        }));

    await _pump(tester, extra: [
      blueprintActionsProvider.overrideWithValue(actions),
    ]);

    // Tap the Assign button for d2 (unplaced doc).
    await tester.tap(find.byKey(const ValueKey('desk-assign-d2')));
    await tester.pumpAndSettle();

    // Dialog with section list should appear.
    expect(find.text('Assign to Section'), findsOneWidget);

    // Tap Act I (pt1) in the dialog.
    await tester.tap(find.byKey(const ValueKey('desk-assign-section-pt1')));
    await tester.pumpAndSettle();

    verify(() => actions.setPlacement(
          'd2',
          'pt1',
          Role.mainContent,
          projectId: 'p1',
        )).called(1);
  });

  // ── 4-skin build ─────────────────────────────────────────────────────────
  for (final themeName in ThemeNames.all) {
    testWidgets('builds under the "$themeName" theme', (tester) async {
      await _pump(tester, theme: AppTheme.forName(themeName));
      expect(tester.takeException(), isNull);
      expect(find.byType(ProjectNavigatorPane), findsOneWidget);
    });
  }
}
