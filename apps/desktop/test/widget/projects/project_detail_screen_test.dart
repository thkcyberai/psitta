// Widget tests for the Phase 5 tabbed Project screen (5b): tabs render/switch,
// the right-rail About card shows detail fields, the Documents tab lists from an
// overridden provider, and the screen builds under all 4 themes.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psitta/core/theme/app_theme.dart';
import 'package:psitta/data/models/blueprint.dart';
import 'package:psitta/data/models/document.dart';
import 'package:psitta/data/models/project_detail.dart';
import 'package:psitta/data/providers/blueprint_providers.dart';
import 'package:psitta/data/providers/project_providers.dart';
import 'package:psitta/data/services/preferences_service.dart';
import 'package:psitta/features/projects/project_detail_screen.dart';

ProjectDetail _detail() => ProjectDetail.fromJson(const <String, dynamic>{
      'id': 'p1',
      'name': 'My First Book',
      'user_id': 'u1',
      'created_at': '2026-06-01T00:00:00Z',
      'updated_at': '2026-06-08T00:00:00Z',
      'document_count': 1,
      'blueprint_count': 0,
      'total_words': 1234,
    });

Document _doc() => Document.fromJson(const <String, dynamic>{
      'id': 'd1',
      'title': 'Chapter One',
      'status': 'ready',
      'source_type': 'docx',
      'page_count': 1,
      'word_count': 1234,
      'project_id': 'p1',
      'cover_type': null,
      'cover_value': null,
      'created_at': '2026-06-01T00:00:00Z',
    });

ProjectBlueprintOverview _emptyOverview() =>
    ProjectBlueprintOverview.fromJson(
        const <String, dynamic>{'progress': null, 'blueprints': <dynamic>[]});

List<Override> _overrides({List<Document>? docs}) => [
      projectDetailProvider('p1').overrideWith((ref) async => _detail()),
      projectDocumentsProvider('p1')
          .overrideWith((ref) async => docs ?? [_doc()]),
      // Overview is the default tab; stub its blueprint/placement reads too.
      projectBlueprintOverviewProvider('p1')
          .overrideWith((ref) async => _emptyOverview()),
      projectPlacementsProvider('p1')
          .overrideWith((ref) async => const <ProjectPlacement>[]),
    ];

Future<void> _pump(
  WidgetTester tester, {
  ThemeData? theme,
  List<Document>? docs,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(docs: docs),
      child: MaterialApp(
        theme: theme ?? AppTheme.creatorStudioDark,
        home: const ProjectDetailScreen(
          projectId: 'p1',
          projectName: 'My First Book',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the four tabs and the project name', (tester) async {
    await _pump(tester);
    expect(find.widgetWithText(Tab, 'Overview'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Documents'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Blueprints'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Activity'), findsOneWidget);
    // Header shows the detail name.
    expect(find.text('My First Book'), findsWidgets);
  });

  testWidgets('About card shows created/updated/words/owner', (tester) async {
    await _pump(tester);
    expect(find.text('About this Project'), findsOneWidget);
    expect(find.text('Created'), findsOneWidget);
    expect(find.text('Last updated'), findsOneWidget);
    expect(find.text('Total words'), findsOneWidget);
    expect(find.text('1234'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
  });

  testWidgets('switching to Documents lists the project documents',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.widgetWithText(Tab, 'Documents'));
    await tester.pumpAndSettle();
    // The Documents tab lists the project's documents as ListTiles (distinct
    // from the Overview Recent Documents table's plain-text rows).
    expect(find.widgetWithText(ListTile, 'Chapter One'), findsOneWidget);
  });

  testWidgets('Activity tab shows an honest coming-soon state', (tester) async {
    await _pump(tester);
    await tester.tap(find.widgetWithText(Tab, 'Activity'));
    await tester.pumpAndSettle();
    // Both the rail card and the tab body render the coming-soon copy.
    expect(find.text('Activity feed coming soon'), findsWidgets);
  });

  for (final themeName in ThemeNames.all) {
    testWidgets('builds under the "$themeName" theme', (tester) async {
      await _pump(tester, theme: AppTheme.forName(themeName));
      expect(tester.takeException(), isNull);
      expect(find.byType(ProjectDetailScreen), findsOneWidget);
      expect(find.text('About this Project'), findsOneWidget);
    });
  }
}
