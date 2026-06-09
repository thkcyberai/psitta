// Widget tests for the read-only section-tree pane (slice 4b).
//
// blueprintDetailProvider is overridden with a multi-level fake tree; the
// selected blueprint id is seeded via a StateProvider override.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psitta/core/theme/app_theme.dart';
import 'package:psitta/data/models/blueprint.dart';
import 'package:psitta/data/providers/blueprint_providers.dart';
import 'package:psitta/features/blueprints/blueprint_screen_state.dart';
import 'package:psitta/features/blueprints/widgets/part_tree_pane.dart';

// Act I ─ Chapter 1 ─ Scene 1   (depths 0,1,2)
//       └ Chapter 2
BlueprintDetail _detail() => BlueprintDetail.fromJson(const <String, dynamic>{
      'id': 'bp1',
      'name': 'My Novel',
      'description': null,
      'genre': 'Novel',
      'status': 'Draft',
      'is_system': false,
      'source_template_id': null,
      'parts': [
        {
          'id': 'root',
          'name': 'Act I',
          'description': 'The setup',
          'sort_order': 1000.0,
          'children': [
            {
              'id': 'child',
              'name': 'Chapter 1',
              'description': null,
              'sort_order': 1000.0,
              'children': [
                {
                  'id': 'grand',
                  'name': 'Scene 1',
                  'description': null,
                  'sort_order': 1000.0,
                  'children': <dynamic>[],
                },
              ],
            },
            {
              'id': 'child2',
              'name': 'Chapter 2',
              'description': null,
              'sort_order': 2000.0,
              'children': <dynamic>[],
            },
          ],
        },
      ],
    });

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  String? selectedId = 'bp1',
  BlueprintDetail? detail,
}) async {
  final d = detail ?? _detail();
  final container = ProviderContainer(overrides: [
    selectedBlueprintIdProvider.overrideWith((ref) => selectedId),
    blueprintDetailProvider('bp1').overrideWith((ref) async => d),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.creatorStudioDark,
        home: const Scaffold(body: PartTreePane()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

double _leftPad(WidgetTester tester, String id) {
  final pad = tester.widget<Padding>(find.byKey(ValueKey('part-pad-$id')));
  return (pad.padding as EdgeInsets).left;
}

void main() {
  testWidgets('renders nested rows at increasing depth', (tester) async {
    await _pump(tester);

    expect(find.text('Act I'), findsOneWidget);
    expect(find.text('Chapter 1'), findsOneWidget);
    expect(find.text('Scene 1'), findsOneWidget);
    expect(find.text('Chapter 2'), findsOneWidget);
    expect(find.text('The setup'), findsOneWidget); // description rendered

    // Left indentation strictly increases with depth.
    expect(_leftPad(tester, 'child') > _leftPad(tester, 'root'), isTrue);
    expect(_leftPad(tester, 'grand') > _leftPad(tester, 'child'), isTrue);
  });

  testWidgets('caret collapses and expands a subtree', (tester) async {
    await _pump(tester);
    expect(find.text('Chapter 1'), findsOneWidget);

    // Collapse the root: its descendants disappear.
    await tester.tap(find.byKey(const ValueKey('part-caret-root')));
    await tester.pumpAndSettle();
    expect(find.text('Chapter 1'), findsNothing);
    expect(find.text('Scene 1'), findsNothing);

    // Expand again: they return.
    await tester.tap(find.byKey(const ValueKey('part-caret-root')));
    await tester.pumpAndSettle();
    expect(find.text('Chapter 1'), findsOneWidget);
  });

  testWidgets('tapping a row sets selectedPartIdProvider', (tester) async {
    final container = await _pump(tester);
    expect(container.read(selectedPartIdProvider), isNull);

    await tester.tap(find.text('Chapter 1'));
    await tester.pump();

    expect(container.read(selectedPartIdProvider), 'child');
  });

  testWidgets('shows placeholder when no blueprint is selected',
      (tester) async {
    await _pump(tester, selectedId: null);
    expect(find.text('Select a blueprint'), findsOneWidget);
  });

  testWidgets('shows "No sections yet" for an empty blueprint', (tester) async {
    final empty = BlueprintDetail.fromJson(const <String, dynamic>{
      'id': 'bp1',
      'name': 'Empty',
      'description': null,
      'genre': 'Novel',
      'status': 'Draft',
      'is_system': false,
      'source_template_id': null,
      'parts': <dynamic>[],
    });
    await _pump(tester, detail: empty);
    expect(find.text('No sections yet'), findsOneWidget);
  });
}
