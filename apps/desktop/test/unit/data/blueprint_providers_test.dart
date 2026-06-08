// Unit tests for the Blueprint read providers and the BlueprintActions
// controller (slice 3c).
//
// A ProviderContainer is built with blueprintRepositoryProvider overridden by a
// mocktail fake. Read providers are asserted to call the right repo method and
// expose the parsed model (and documentPlacementProvider to yield null on 404).
//
// The controller's invalidation map is proven by: priming the providers in a
// mutation's set PLUS a control provider outside it (each repo read fires once),
// performing the mutation, then forcing the invalidated providers to refetch and
// asserting their repo call count incremented to 2 while the control stayed at 1.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:psitta/data/models/blueprint.dart';
import 'package:psitta/data/models/blueprint_enums.dart';
import 'package:psitta/data/providers/blueprint_providers.dart';
import 'package:psitta/data/repositories/blueprint_repository.dart';

class MockBlueprintRepository extends Mock implements BlueprintRepository {}

// ── Fixtures (3a models) ─────────────────────────────────────────────────────

BlueprintSummary _summary([String id = 'a']) => BlueprintSummary.fromJson({
      'id': id,
      'name': 'BP',
      'description': null,
      'genre': 'Novel',
      'status': 'Draft',
      'is_system': false,
      'source_template_id': null,
    });

BlueprintDetail _detail([String id = 'bp-1']) => BlueprintDetail.fromJson({
      'id': id,
      'name': 'BP',
      'description': null,
      'genre': 'Novel',
      'status': 'Draft',
      'is_system': false,
      'source_template_id': null,
      'parts': const <dynamic>[],
    });

AdoptedBlueprint _adopted([String id = 'bp-1']) => AdoptedBlueprint.fromJson({
      'id': id,
      'name': 'BP',
      'description': null,
      'genre': 'Novel',
      'status': 'Draft',
      'is_system': false,
      'source_template_id': null,
      'is_primary': true,
      'adopted_at': '2026-06-08T12:00:00Z',
    });

PartDetail _partDetail() => PartDetail.fromJson(const <String, dynamic>{
      'id': 'part-1',
      'blueprint_id': 'bp-1',
      'parent_part_id': null,
      'name': 'Act I',
      'description': null,
      'sort_order': 1000.0,
    });

DocumentPlacement _placement() => DocumentPlacement.fromJson(const <String, dynamic>{
      'id': 'pl-1',
      'document_id': 'doc-1',
      'part_id': 'part-1',
      'blueprint_id': 'bp-1',
      'role': 'Main Content',
      'sort_order': 1000.0,
    });

ProjectBlueprintOverview _overview() => ProjectBlueprintOverview.fromJson(
    const <String, dynamic>{'progress': null, 'blueprints': <dynamic>[]});

void main() {
  late MockBlueprintRepository repo;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(Genre.novel);
    registerFallbackValue(Role.mainContent);
  });

  setUp(() {
    repo = MockBlueprintRepository();

    // Read stubs.
    when(() => repo.listBlueprints()).thenAnswer((_) async => [_summary('a')]);
    when(() => repo.getBlueprint(any())).thenAnswer((_) async => _detail());
    when(() => repo.listAdoptedBlueprints(any()))
        .thenAnswer((_) async => [_adopted()]);
    when(() => repo.getProjectBlueprintOverview(any()))
        .thenAnswer((_) async => _overview());
    when(() => repo.getPlacement(any())).thenAnswer((_) async => _placement());

    // Mutation stubs.
    when(() => repo.createBlueprint(
          name: any(named: 'name'),
          genre: any(named: 'genre'),
          description: any(named: 'description'),
          status: any(named: 'status'),
        )).thenAnswer((_) async => _summary());
    when(() => repo.cloneBlueprint(any(), name: any(named: 'name')))
        .thenAnswer((_) async => _detail());
    when(() => repo.updateBlueprint(
          any(),
          name: any(named: 'name'),
          description: any(named: 'description'),
          genre: any(named: 'genre'),
          status: any(named: 'status'),
        )).thenAnswer((_) async => _summary());
    when(() => repo.deleteBlueprint(any())).thenAnswer((_) async {});
    when(() => repo.createPart(
          any(),
          name: any(named: 'name'),
          description: any(named: 'description'),
          parentPartId: any(named: 'parentPartId'),
          afterPartId: any(named: 'afterPartId'),
        )).thenAnswer((_) async => _partDetail());
    when(() => repo.updatePart(
          any(),
          any(),
          name: any(named: 'name'),
          description: any(named: 'description'),
          parentPartId: any(named: 'parentPartId'),
          afterPartId: any(named: 'afterPartId'),
        )).thenAnswer((_) async => _partDetail());
    when(() => repo.deletePart(any(), any())).thenAnswer((_) async {});
    when(() => repo.adoptBlueprint(any(), any(),
        isPrimary: any(named: 'isPrimary'))).thenAnswer((_) async => _adopted());
    when(() => repo.setPrimaryBlueprint(any(), any(),
        isPrimary: any(named: 'isPrimary'))).thenAnswer((_) async => _adopted());
    when(() => repo.unadoptBlueprint(any(), any())).thenAnswer((_) async {});
    when(() => repo.setPlacement(any(), any(), any()))
        .thenAnswer((_) async => _placement());
    when(() => repo.removePlacement(any())).thenAnswer((_) async {});

    container = ProviderContainer(overrides: [
      blueprintRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
  });

  BlueprintActions actions() => container.read(blueprintActionsProvider);

  /// Keep an autoDispose provider alive (a listener) and return its first value,
  /// so it can later be observed to refetch (or not) after an invalidation.
  Future<T> warm<T>(AutoDisposeFutureProvider<T> p) async {
    container.listen<AsyncValue<T>>(p, (_, __) {});
    return container.read(p.future);
  }

  // ── Read providers ─────────────────────────────────────────────────────

  group('read providers', () {
    test('blueprintsListProvider delegates to listBlueprints', () async {
      final result = await container.read(blueprintsListProvider.future);
      expect(result.single, isA<BlueprintSummary>());
      expect(result.single.id, 'a');
      verify(() => repo.listBlueprints()).called(1);
    });

    test('blueprintDetailProvider(id) delegates to getBlueprint(id)', () async {
      final result = await container.read(blueprintDetailProvider('bp-9').future);
      expect(result, isA<BlueprintDetail>());
      verify(() => repo.getBlueprint('bp-9')).called(1);
    });

    test('adoptedBlueprintsProvider(p) delegates to listAdoptedBlueprints(p)',
        () async {
      final result =
          await container.read(adoptedBlueprintsProvider('proj-9').future);
      expect(result.single, isA<AdoptedBlueprint>());
      verify(() => repo.listAdoptedBlueprints('proj-9')).called(1);
    });

    test('projectBlueprintOverviewProvider(p) delegates to overview(p)',
        () async {
      final result =
          await container.read(projectBlueprintOverviewProvider('proj-9').future);
      expect(result, isA<ProjectBlueprintOverview>());
      verify(() => repo.getProjectBlueprintOverview('proj-9')).called(1);
    });

    test('documentPlacementProvider(d) returns the placement on success',
        () async {
      final result =
          await container.read(documentPlacementProvider('doc-1').future);
      expect(result, isNotNull);
      expect(result!.documentId, 'doc-1');
      verify(() => repo.getPlacement('doc-1')).called(1);
    });

    test('documentPlacementProvider(d) maps a 404 to null', () async {
      when(() => repo.getPlacement('doc-x')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          response:
              Response(requestOptions: RequestOptions(path: '/'), statusCode: 404),
        ),
      );
      final result =
          await container.read(documentPlacementProvider('doc-x').future);
      expect(result, isNull);
    });

    test('documentPlacementProvider(d) rethrows a non-404 DioException',
        () async {
      when(() => repo.getPlacement('doc-e')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          response:
              Response(requestOptions: RequestOptions(path: '/'), statusCode: 500),
        ),
      );
      await expectLater(
        container.read(documentPlacementProvider('doc-e').future),
        throwsA(isA<DioException>()),
      );
    });
  });

  // ── Controller: invalidation map ───────────────────────────────────────

  group('createBlueprint', () {
    test('invalidates the list only', () async {
      await warm(blueprintsListProvider); // in set
      await warm(projectBlueprintOverviewProvider('proj-1')); // control

      await actions().createBlueprint(name: 'X', genre: Genre.novel);
      verify(() => repo.createBlueprint(name: 'X', genre: Genre.novel)).called(1);

      await container.read(blueprintsListProvider.future);
      verify(() => repo.listBlueprints()).called(2); // refetched
      verify(() => repo.getProjectBlueprintOverview('proj-1')).called(1); // not
    });
  });

  group('cloneBlueprint', () {
    test('invalidates the list only', () async {
      await warm(blueprintsListProvider); // in set
      await warm(blueprintDetailProvider('bp-1')); // control

      await actions().cloneBlueprint('src-1');
      verify(() => repo.cloneBlueprint('src-1')).called(1);

      await container.read(blueprintsListProvider.future);
      verify(() => repo.listBlueprints()).called(2);
      verify(() => repo.getBlueprint('bp-1')).called(1); // not
    });
  });

  group('updateBlueprint', () {
    test('invalidates list, detail(id), adopted family, overview family', () async {
      await warm(blueprintsListProvider);
      await warm(blueprintDetailProvider('bp-1'));
      await warm(adoptedBlueprintsProvider('proj-1'));
      await warm(projectBlueprintOverviewProvider('proj-1'));
      await warm(blueprintDetailProvider('bp-other')); // control (other id)
      await warm(documentPlacementProvider('doc-1')); // control

      await actions().updateBlueprint('bp-1', name: 'New');
      verify(() => repo.updateBlueprint('bp-1', name: 'New')).called(1);

      await container.read(blueprintsListProvider.future);
      await container.read(blueprintDetailProvider('bp-1').future);
      await container.read(adoptedBlueprintsProvider('proj-1').future);
      await container.read(projectBlueprintOverviewProvider('proj-1').future);

      verify(() => repo.listBlueprints()).called(2);
      verify(() => repo.getBlueprint('bp-1')).called(2);
      verify(() => repo.listAdoptedBlueprints('proj-1')).called(2);
      verify(() => repo.getProjectBlueprintOverview('proj-1')).called(2);
      // Controls untouched.
      verify(() => repo.getBlueprint('bp-other')).called(1);
      verify(() => repo.getPlacement('doc-1')).called(1);
    });

    test('forwards an omitted description as the unset sentinel (unchanged)',
        () async {
      await actions().updateBlueprint('bp-1', name: 'X');
      final captured = verify(() => repo.updateBlueprint(
            'bp-1',
            name: any(named: 'name'),
            description: captureAny(named: 'description'),
            genre: any(named: 'genre'),
            status: any(named: 'status'),
          )).captured;
      expect(identical(captured.single, const Object()), isTrue);
    });

    test('forwards an explicit null description as null (clear)', () async {
      await actions().updateBlueprint('bp-1', description: null);
      final captured = verify(() => repo.updateBlueprint(
            'bp-1',
            name: any(named: 'name'),
            description: captureAny(named: 'description'),
            genre: any(named: 'genre'),
            status: any(named: 'status'),
          )).captured;
      expect(captured.single, isNull);
    });

    test('propagates a repo ArgumentError without invalidating', () async {
      when(() => repo.updateBlueprint(any(),
              name: any(named: 'name'),
              description: any(named: 'description'),
              genre: any(named: 'genre'),
              status: any(named: 'status')))
          .thenThrow(ArgumentError('unknown'));
      await warm(blueprintsListProvider);

      await expectLater(
        actions().updateBlueprint('bp-1', name: 'X'),
        throwsA(isA<ArgumentError>()),
      );
      await container.read(blueprintsListProvider.future);
      verify(() => repo.listBlueprints()).called(1); // not invalidated
    });
  });

  group('deleteBlueprint', () {
    test('invalidates list, detail(id), adopted family, overview family', () async {
      await warm(blueprintsListProvider);
      await warm(blueprintDetailProvider('bp-1'));
      await warm(adoptedBlueprintsProvider('proj-1'));
      await warm(projectBlueprintOverviewProvider('proj-1'));
      await warm(documentPlacementProvider('doc-1')); // control

      await actions().deleteBlueprint('bp-1');
      verify(() => repo.deleteBlueprint('bp-1')).called(1);

      await container.read(blueprintsListProvider.future);
      await container.read(blueprintDetailProvider('bp-1').future);
      await container.read(adoptedBlueprintsProvider('proj-1').future);
      await container.read(projectBlueprintOverviewProvider('proj-1').future);

      verify(() => repo.listBlueprints()).called(2);
      verify(() => repo.getBlueprint('bp-1')).called(2);
      verify(() => repo.listAdoptedBlueprints('proj-1')).called(2);
      verify(() => repo.getProjectBlueprintOverview('proj-1')).called(2);
      verify(() => repo.getPlacement('doc-1')).called(1);
    });
  });

  group('part mutations', () {
    test('createPart invalidates detail(bp) + overview family, not list/adopted',
        () async {
      await warm(blueprintDetailProvider('bp-1')); // in set
      await warm(projectBlueprintOverviewProvider('proj-1')); // in set (family)
      await warm(blueprintsListProvider); // control
      await warm(adoptedBlueprintsProvider('proj-1')); // control

      await actions().createPart('bp-1', name: 'Act I');
      verify(() => repo.createPart('bp-1', name: 'Act I')).called(1);

      await container.read(blueprintDetailProvider('bp-1').future);
      await container.read(projectBlueprintOverviewProvider('proj-1').future);

      verify(() => repo.getBlueprint('bp-1')).called(2);
      verify(() => repo.getProjectBlueprintOverview('proj-1')).called(2);
      verify(() => repo.listBlueprints()).called(1);
      verify(() => repo.listAdoptedBlueprints('proj-1')).called(1);
    });

    test('updatePart invalidates detail(bp) + overview family', () async {
      await warm(blueprintDetailProvider('bp-1'));
      await warm(projectBlueprintOverviewProvider('proj-1'));
      await warm(blueprintsListProvider); // control

      await actions().updatePart('bp-1', 'part-1', name: 'Ch 2');
      verify(() => repo.updatePart('bp-1', 'part-1', name: 'Ch 2')).called(1);

      await container.read(blueprintDetailProvider('bp-1').future);
      await container.read(projectBlueprintOverviewProvider('proj-1').future);

      verify(() => repo.getBlueprint('bp-1')).called(2);
      verify(() => repo.getProjectBlueprintOverview('proj-1')).called(2);
      verify(() => repo.listBlueprints()).called(1);
    });

    test('updatePart forwards parentPartId tri-state (omit vs explicit null)',
        () async {
      await actions().updatePart('bp-1', 'part-1', name: 'X'); // omit parent
      var captured = verify(() => repo.updatePart('bp-1', 'part-1',
          name: any(named: 'name'),
          description: any(named: 'description'),
          parentPartId: captureAny(named: 'parentPartId'),
          afterPartId: any(named: 'afterPartId'))).captured;
      expect(identical(captured.single, const Object()), isTrue);

      await actions().updatePart('bp-1', 'part-1', parentPartId: null); // root
      captured = verify(() => repo.updatePart('bp-1', 'part-1',
          name: any(named: 'name'),
          description: any(named: 'description'),
          parentPartId: captureAny(named: 'parentPartId'),
          afterPartId: any(named: 'afterPartId'))).captured;
      expect(captured.single, isNull);
    });

    test('deletePart invalidates detail(bp) + overview family', () async {
      await warm(blueprintDetailProvider('bp-1'));
      await warm(projectBlueprintOverviewProvider('proj-1'));
      await warm(blueprintsListProvider); // control

      await actions().deletePart('bp-1', 'part-1');
      verify(() => repo.deletePart('bp-1', 'part-1')).called(1);

      await container.read(blueprintDetailProvider('bp-1').future);
      await container.read(projectBlueprintOverviewProvider('proj-1').future);

      verify(() => repo.getBlueprint('bp-1')).called(2);
      verify(() => repo.getProjectBlueprintOverview('proj-1')).called(2);
      verify(() => repo.listBlueprints()).called(1);
    });
  });

  group('adoption mutations', () {
    test('adoptBlueprint invalidates adopted(p) + overview(p) instances only',
        () async {
      await warm(adoptedBlueprintsProvider('proj-1')); // in set
      await warm(projectBlueprintOverviewProvider('proj-1')); // in set
      await warm(projectBlueprintOverviewProvider('proj-2')); // control (other p)
      await warm(blueprintsListProvider); // control

      await actions().adoptBlueprint('proj-1', 'bp-1');
      verify(() => repo.adoptBlueprint('proj-1', 'bp-1', isPrimary: false))
          .called(1);

      await container.read(adoptedBlueprintsProvider('proj-1').future);
      await container.read(projectBlueprintOverviewProvider('proj-1').future);

      verify(() => repo.listAdoptedBlueprints('proj-1')).called(2);
      verify(() => repo.getProjectBlueprintOverview('proj-1')).called(2);
      // Other project + unrelated provider untouched.
      verify(() => repo.getProjectBlueprintOverview('proj-2')).called(1);
      verify(() => repo.listBlueprints()).called(1);
    });

    test('adoptBlueprint(isPrimary: true) forwards the flag', () async {
      await actions().adoptBlueprint('proj-1', 'bp-1', isPrimary: true);
      verify(() => repo.adoptBlueprint('proj-1', 'bp-1', isPrimary: true))
          .called(1);
    });

    test('setPrimaryBlueprint invalidates adopted(p) + overview(p)', () async {
      await warm(adoptedBlueprintsProvider('proj-1'));
      await warm(projectBlueprintOverviewProvider('proj-1'));
      await warm(projectBlueprintOverviewProvider('proj-2')); // control

      await actions().setPrimaryBlueprint('proj-1', 'bp-1');
      verify(() => repo.setPrimaryBlueprint('proj-1', 'bp-1', isPrimary: true))
          .called(1);

      await container.read(adoptedBlueprintsProvider('proj-1').future);
      await container.read(projectBlueprintOverviewProvider('proj-1').future);

      verify(() => repo.listAdoptedBlueprints('proj-1')).called(2);
      verify(() => repo.getProjectBlueprintOverview('proj-1')).called(2);
      verify(() => repo.getProjectBlueprintOverview('proj-2')).called(1);
    });

    test('setPrimaryBlueprint(isPrimary: false) forwards the clear flag',
        () async {
      await actions().setPrimaryBlueprint('proj-1', 'bp-1', isPrimary: false);
      verify(() => repo.setPrimaryBlueprint('proj-1', 'bp-1', isPrimary: false))
          .called(1);
    });

    test('unadoptBlueprint invalidates adopted(p) + overview(p)', () async {
      await warm(adoptedBlueprintsProvider('proj-1'));
      await warm(projectBlueprintOverviewProvider('proj-1'));
      await warm(projectBlueprintOverviewProvider('proj-2')); // control

      await actions().unadoptBlueprint('proj-1', 'bp-1');
      verify(() => repo.unadoptBlueprint('proj-1', 'bp-1')).called(1);

      await container.read(adoptedBlueprintsProvider('proj-1').future);
      await container.read(projectBlueprintOverviewProvider('proj-1').future);

      verify(() => repo.listAdoptedBlueprints('proj-1')).called(2);
      verify(() => repo.getProjectBlueprintOverview('proj-1')).called(2);
      verify(() => repo.getProjectBlueprintOverview('proj-2')).called(1);
    });
  });

  group('placement mutations', () {
    test('setPlacement(projectId) invalidates overview(p) + placement(doc)',
        () async {
      await warm(projectBlueprintOverviewProvider('proj-1')); // in set
      await warm(documentPlacementProvider('doc-1')); // in set
      await warm(projectBlueprintOverviewProvider('proj-2')); // control

      await actions()
          .setPlacement('doc-1', 'part-1', Role.mainContent, projectId: 'proj-1');
      verify(() => repo.setPlacement('doc-1', 'part-1', Role.mainContent))
          .called(1);

      await container.read(projectBlueprintOverviewProvider('proj-1').future);
      await container.read(documentPlacementProvider('doc-1').future);

      verify(() => repo.getProjectBlueprintOverview('proj-1')).called(2);
      verify(() => repo.getPlacement('doc-1')).called(2);
      verify(() => repo.getProjectBlueprintOverview('proj-2')).called(1); // not
    });

    test('setPlacement without projectId invalidates the whole overview family',
        () async {
      await warm(projectBlueprintOverviewProvider('proj-1'));
      await warm(projectBlueprintOverviewProvider('proj-2'));
      await warm(documentPlacementProvider('doc-1'));

      await actions().setPlacement('doc-1', 'part-1', Role.mainContent);

      await container.read(projectBlueprintOverviewProvider('proj-1').future);
      await container.read(projectBlueprintOverviewProvider('proj-2').future);
      await container.read(documentPlacementProvider('doc-1').future);

      verify(() => repo.getProjectBlueprintOverview('proj-1')).called(2);
      verify(() => repo.getProjectBlueprintOverview('proj-2')).called(2);
      verify(() => repo.getPlacement('doc-1')).called(2);
    });

    test('removePlacement(projectId) invalidates overview(p) + placement(doc)',
        () async {
      await warm(projectBlueprintOverviewProvider('proj-1'));
      await warm(documentPlacementProvider('doc-1'));
      await warm(projectBlueprintOverviewProvider('proj-2')); // control

      await actions().removePlacement('doc-1', projectId: 'proj-1');
      verify(() => repo.removePlacement('doc-1')).called(1);

      await container.read(projectBlueprintOverviewProvider('proj-1').future);
      await container.read(documentPlacementProvider('doc-1').future);

      verify(() => repo.getProjectBlueprintOverview('proj-1')).called(2);
      verify(() => repo.getPlacement('doc-1')).called(2);
      verify(() => repo.getProjectBlueprintOverview('proj-2')).called(1);
    });
  });
}
