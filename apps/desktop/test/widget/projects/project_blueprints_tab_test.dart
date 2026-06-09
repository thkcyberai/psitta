// Widget tests for the Project Blueprints tab (5d): per-card Set-as-Primary and
// Remove-from-Project (with confirm) and the adopt picker all call the right
// blueprintActionsProvider methods; builds under all 4 themes.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:psitta/core/theme/app_theme.dart';
import 'package:psitta/data/models/blueprint.dart';
import 'package:psitta/data/providers/blueprint_providers.dart';
import 'package:psitta/data/services/preferences_service.dart';
import 'package:psitta/features/projects/widgets/project_blueprints_tab.dart';

class MockBlueprintActions extends Mock implements BlueprintActions {}

Map<String, dynamic> _blueprintJson({required bool isPrimary}) => {
      'id': 'b1',
      'name': 'Nested',
      'description': null,
      'genre': 'Novel',
      'status': 'Draft',
      'is_system': false,
      'source_template_id': null,
      'is_primary': isPrimary,
      'adopted_at': '2026-06-08T12:00:00Z',
      'progress': const {'leaves_with_content': 1, 'total_leaves': 2, 'ratio': 0.5},
      'parts': const [
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
      ],
    };

ProjectBlueprintOverview _overview({bool isPrimary = false}) =>
    ProjectBlueprintOverview.fromJson(<String, dynamic>{
      'progress': const {'leaves_with_content': 1, 'total_leaves': 2, 'ratio': 0.5},
      'blueprints': [_blueprintJson(isPrimary: isPrimary)],
    });

BlueprintOverview _anyBlueprint() =>
    BlueprintOverview.fromJson(_blueprintJson(isPrimary: true));

BlueprintSummary _summary(String id, String name) =>
    BlueprintSummary.fromJson(<String, dynamic>{
      'id': id,
      'name': name,
      'description': null,
      'genre': 'Novel',
      'status': 'Draft',
      'is_system': false,
      'source_template_id': null,
    });

Future<MockBlueprintActions> _pump(
  WidgetTester tester, {
  ThemeData? theme,
  bool primary = false,
  List<BlueprintSummary>? list,
}) async {
  final actions = MockBlueprintActions();
  when(() => actions.setPrimaryBlueprint(any(), any(),
      isPrimary: any(named: 'isPrimary'))).thenAnswer((_) async => _anyBlueprint());
  when(() => actions.unadoptBlueprint(any(), any())).thenAnswer((_) async {});
  when(() => actions.adoptBlueprint(any(), any(),
      isPrimary: any(named: 'isPrimary'))).thenAnswer((_) async => _anyBlueprint());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectBlueprintOverviewProvider('p1')
            .overrideWith((ref) async => _overview(isPrimary: primary)),
        blueprintActionsProvider.overrideWithValue(actions),
        blueprintsListProvider.overrideWith(
          (ref) async => list ?? [_summary('b1', 'Nested')],
        ),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.creatorStudioDark,
        home: const Scaffold(body: ProjectBlueprintsTab(projectId: 'p1')),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return actions;
}

void main() {
  setUpAll(() => registerFallbackValue(false));

  testWidgets('Set as Primary calls setPrimaryBlueprint', (tester) async {
    final actions = await _pump(tester); // b1 not primary → menu item shows

    await tester.tap(find.byKey(const ValueKey('bp-menu-b1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set as Primary'));
    await tester.pumpAndSettle();

    verify(() => actions.setPrimaryBlueprint('p1', 'b1', isPrimary: true))
        .called(1);
  });

  testWidgets('Remove from Project confirms then calls unadoptBlueprint',
      (tester) async {
    final actions = await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('bp-menu-b1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from Project'));
    await tester.pumpAndSettle();
    // Confirm dialog.
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    verify(() => actions.unadoptBlueprint('p1', 'b1')).called(1);
  });

  testWidgets('primary blueprint hides the Set as Primary action',
      (tester) async {
    await _pump(tester, primary: true);
    await tester.tap(find.byKey(const ValueKey('bp-menu-b1')));
    await tester.pumpAndSettle();
    expect(find.text('Set as Primary'), findsNothing);
    expect(find.text('Remove from Project'), findsOneWidget);
  });

  testWidgets('Add Blueprint to Project picker adopts the chosen blueprint',
      (tester) async {
    final actions = await _pump(
      tester,
      list: [_summary('b1', 'Nested'), _summary('b2', 'Memoir BP')],
    );

    await tester.tap(find.byKey(const ValueKey('blueprints-tab-add-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adopt-candidate-b2')));
    await tester.pumpAndSettle();

    verify(() => actions.adoptBlueprint('p1', 'b2', isPrimary: false)).called(1);
  });

  for (final themeName in ThemeNames.all) {
    testWidgets('builds under the "$themeName" theme', (tester) async {
      await _pump(tester, theme: AppTheme.forName(themeName));
      expect(tester.takeException(), isNull);
      expect(find.byType(ProjectBlueprintsTab), findsOneWidget);
    });
  }
}
