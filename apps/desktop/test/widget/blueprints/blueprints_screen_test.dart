// Widget tests for the Blueprints screen left list pane (slice 4a).
//
// blueprintRepositoryProvider is overridden with a mocktail fake so BOTH the
// list pane (listBlueprints) and the center tree pane (getBlueprint, fetched
// once a blueprint auto-selects) resolve without touching the network.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:psitta/core/theme/app_theme.dart';
import 'package:psitta/data/models/blueprint.dart';
import 'package:psitta/data/providers/blueprint_providers.dart';
import 'package:psitta/data/repositories/blueprint_repository.dart';
import 'package:psitta/features/blueprints/blueprint_screen_state.dart';
import 'package:psitta/features/blueprints/blueprints_screen.dart';

class MockBlueprintRepository extends Mock implements BlueprintRepository {}

BlueprintSummary _summary({
  required String id,
  required String name,
  required bool isSystem,
  String genre = 'Novel',
}) =>
    BlueprintSummary.fromJson({
      'id': id,
      'name': name,
      'description': null,
      'genre': genre,
      'status': 'Draft',
      'is_system': isSystem,
      'source_template_id': null,
    });

BlueprintDetail _detailStub(String id) =>
    BlueprintDetail.fromJson(<String, dynamic>{
      'id': id,
      'name': 'Detail',
      'description': null,
      'genre': 'Novel',
      'status': 'Draft',
      'is_system': false,
      'source_template_id': null,
      'parts': const <dynamic>[],
    });

Future<ProviderContainer> _pump(
  WidgetTester tester,
  List<BlueprintSummary> blueprints,
) async {
  final repo = MockBlueprintRepository();
  when(() => repo.listBlueprints()).thenAnswer((_) async => blueprints);
  when(() => repo.getBlueprint(any()))
      .thenAnswer((inv) async => _detailStub(inv.positionalArguments.first as String));

  final container = ProviderContainer(overrides: [
    blueprintRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.creatorStudioDark,
        home: const BlueprintsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('renders both groups from data', (tester) async {
    await _pump(tester, [
      _summary(id: 't1', name: 'Three-Act Novel', isSystem: true),
      _summary(id: 'm1', name: 'My First Book', isSystem: false, genre: 'Memoir'),
    ]);

    expect(find.text('Templates'), findsOneWidget);
    expect(find.text('My Blueprints'), findsOneWidget);
    expect(find.text('Three-Act Novel'), findsOneWidget);
    expect(find.text('My First Book'), findsOneWidget);
    // Genre chips render the wire value.
    expect(find.text('Novel'), findsOneWidget);
    expect(find.text('Memoir'), findsOneWidget);
  });

  testWidgets('auto-selects the first item when none selected', (tester) async {
    final container = await _pump(tester, [
      _summary(id: 't1', name: 'Three-Act Novel', isSystem: true),
      _summary(id: 'm1', name: 'My First Book', isSystem: false),
    ]);

    expect(container.read(selectedBlueprintIdProvider), 't1');
  });

  testWidgets('tapping a card updates selectedBlueprintIdProvider',
      (tester) async {
    final container = await _pump(tester, [
      _summary(id: 't1', name: 'Three-Act Novel', isSystem: true),
      _summary(id: 'm1', name: 'My First Book', isSystem: false),
    ]);

    await tester.tap(find.text('My First Book'));
    await tester.pumpAndSettle();

    expect(container.read(selectedBlueprintIdProvider), 'm1');
  });

  testWidgets('shows empty state when there are no blueprints', (tester) async {
    await _pump(tester, const []);
    expect(find.text('No blueprints yet'), findsOneWidget);
  });
}
