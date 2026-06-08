// Unit tests for BlueprintRepository.
//
// The shared ApiClient and its Dio are faked with mocktail. Each test stubs the
// relevant Dio verb to return a success Response built from a 3a-style fixture,
// then asserts (a) the correct HTTP verb, path, and body reach Dio, and (b) the
// response parses into the correct 3a model. Also covers error propagation and
// the client-side guard that an `unknown`-valued enum write throws before any
// request is issued.
//
// Routes/bodies are the backend contract (api/v1/blueprints.py,
// api/v1/project_blueprints.py); response shapes mirror schemas/api.py.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:psitta/data/api/api_client.dart';
import 'package:psitta/data/models/blueprint.dart';
import 'package:psitta/data/models/blueprint_enums.dart';
import 'package:psitta/data/repositories/blueprint_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

/// A 200 response carrying [data] (the body the backend would return).
Response<dynamic> _resp(dynamic data) => Response<dynamic>(
      requestOptions: RequestOptions(path: '/'),
      data: data,
      statusCode: 200,
    );

// ── Fixtures (derived from the 3a model shapes / backend response_models) ─────

Map<String, dynamic> _summaryJson({
  String id = 'bp-1',
  String genre = 'Novel',
  bool isSystem = false,
  String? sourceTemplateId,
}) =>
    {
      'id': id,
      'name': 'My Book',
      'description': null,
      'genre': genre,
      'status': 'Draft',
      'is_system': isSystem,
      'source_template_id': sourceTemplateId,
    };

Map<String, dynamic> _detailJson() => {
      ..._summaryJson(id: 'bp-detail'),
      'parts': [
        {
          'id': 'p1',
          'name': 'Act I',
          'description': null,
          'sort_order': 1000.0,
          'children': [
            {
              'id': 'p1a',
              'name': 'Ch 1',
              'description': null,
              'sort_order': 1000.0,
              'children': <dynamic>[],
            },
          ],
        },
      ],
    };

Map<String, dynamic> _adoptedJson({bool isPrimary = true, String id = 'bp-adopt'}) =>
    {
      ..._summaryJson(id: id),
      'is_primary': isPrimary,
      'adopted_at': '2026-06-08T12:00:00Z',
    };

Map<String, dynamic> _partDetailJson({String? parent}) => {
      'id': 'part-1',
      'blueprint_id': 'bp-1',
      'parent_part_id': parent,
      'name': 'Act I',
      'description': null,
      'sort_order': 1000.0,
    };

Map<String, dynamic> _placementJson() => {
      'id': 'pl-1',
      'document_id': 'doc-1',
      'part_id': 'part-1',
      'blueprint_id': 'bp-1',
      'role': 'Main Content',
      'sort_order': 1000.0,
    };

Map<String, dynamic> _overviewJson() => {
      'progress': {'leaves_with_content': 2, 'total_leaves': 4, 'ratio': 0.5},
      'blueprints': [
        {
          ..._adoptedJson(),
          'progress': {
            'leaves_with_content': 2,
            'total_leaves': 4,
            'ratio': 0.5,
          },
          'parts': [
            {
              'id': 'a1',
              'name': 'Act I',
              'description': null,
              'sort_order': 1000.0,
              'document_count': 1,
              'has_content': true,
              'readiness': 'ready',
              'children': <dynamic>[],
            },
          ],
        },
      ],
    };

void main() {
  late MockApiClient api;
  late MockDio dio;
  late BlueprintRepository repo;

  setUp(() {
    api = MockApiClient();
    dio = MockDio();
    when(() => api.dio).thenReturn(dio);
    repo = BlueprintRepository(api);
  });

  // ── Blueprints ─────────────────────────────────────────────────────────

  group('listBlueprints', () {
    test('GETs /blueprints/ and parses a list of summaries', () async {
      when(() => dio.get(any())).thenAnswer(
        (_) async => _resp([_summaryJson(id: 'a'), _summaryJson(id: 'b')]),
      );

      final result = await repo.listBlueprints();

      verify(() => dio.get('/blueprints/')).called(1);
      expect(result, isA<List<BlueprintSummary>>());
      expect(result.map((b) => b.id), ['a', 'b']);
      expect(result.first.genre, Genre.novel);
    });
  });

  group('getBlueprint', () {
    test('GETs /blueprints/{id} and parses the nested detail', () async {
      when(() => dio.get(any())).thenAnswer((_) async => _resp(_detailJson()));

      final result = await repo.getBlueprint('bp-detail');

      verify(() => dio.get('/blueprints/bp-detail')).called(1);
      expect(result, isA<BlueprintDetail>());
      expect(result.parts.single.name, 'Act I');
      expect(result.parts.single.children.single.name, 'Ch 1');
    });
  });

  group('createBlueprint', () {
    test('POSTs /blueprints/ with the exact body and parses the summary',
        () async {
      when(() => dio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _resp(_summaryJson()));

      final result = await repo.createBlueprint(
        name: 'My Book',
        genre: Genre.novel,
        description: 'A draft',
        status: BlueprintStatus.draft,
      );

      final body = verify(
        () => dio.post('/blueprints/', data: captureAny(named: 'data')),
      ).captured.single;
      expect(body, {
        'name': 'My Book',
        'genre': 'Novel',
        'description': 'A draft',
        'status': 'Draft',
      });
      expect(result, isA<BlueprintSummary>());
      expect(result.genre, Genre.novel);
    });

    test('omits optional description/status when not provided', () async {
      when(() => dio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _resp(_summaryJson()));

      await repo.createBlueprint(name: 'Bare', genre: Genre.memoir);

      final body = verify(
        () => dio.post('/blueprints/', data: captureAny(named: 'data')),
      ).captured.single as Map<String, dynamic>;
      expect(body, {'name': 'Bare', 'genre': 'Memoir'});
      expect(body.containsKey('description'), isFalse);
      expect(body.containsKey('status'), isFalse);
    });
  });

  group('cloneBlueprint', () {
    test('POSTs /blueprints/{id}/clone/ with no body by default', () async {
      when(() => dio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _resp(_detailJson()));

      final result = await repo.cloneBlueprint('bp-1');

      final body = verify(
        () => dio.post('/blueprints/bp-1/clone/', data: captureAny(named: 'data')),
      ).captured.single;
      expect(body, isNull);
      expect(result, isA<BlueprintDetail>());
    });

    test('sends {name} when a name override is given', () async {
      when(() => dio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _resp(_detailJson()));

      await repo.cloneBlueprint('bp-1', name: 'Copy');

      final body = verify(
        () => dio.post('/blueprints/bp-1/clone/', data: captureAny(named: 'data')),
      ).captured.single;
      expect(body, {'name': 'Copy'});
    });
  });

  group('updateBlueprint', () {
    test('PATCHes /blueprints/{id}; description tri-state clears with null',
        () async {
      when(() => dio.patch(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _resp(_summaryJson()));

      await repo.updateBlueprint('bp-1', name: 'Renamed', description: null);

      final body = verify(
        () => dio.patch('/blueprints/bp-1', data: captureAny(named: 'data')),
      ).captured.single as Map<String, dynamic>;
      expect(body, {'name': 'Renamed', 'description': null});
      expect(body.containsKey('description'), isTrue); // present-and-null
    });

    test('omits description when left unset', () async {
      when(() => dio.patch(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _resp(_summaryJson()));

      await repo.updateBlueprint('bp-1', name: 'Renamed');

      final body = verify(
        () => dio.patch('/blueprints/bp-1', data: captureAny(named: 'data')),
      ).captured.single as Map<String, dynamic>;
      expect(body, {'name': 'Renamed'});
      expect(body.containsKey('description'), isFalse);
    });
  });

  group('deleteBlueprint', () {
    test('DELETEs /blueprints/{id}', () async {
      when(() => dio.delete(any())).thenAnswer((_) async => _resp(null));

      await repo.deleteBlueprint('bp-1');

      verify(() => dio.delete('/blueprints/bp-1')).called(1);
    });
  });

  // ── Parts ──────────────────────────────────────────────────────────────

  group('createPart', () {
    test('POSTs /blueprints/{id}/parts/ with parent_part_id and parses detail',
        () async {
      when(() => dio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _resp(_partDetailJson(parent: 'root-1')));

      final result = await repo.createPart(
        'bp-1',
        name: 'Act I',
        parentPartId: 'root-1',
      );

      final body = verify(
        () => dio.post('/blueprints/bp-1/parts/', data: captureAny(named: 'data')),
      ).captured.single;
      expect(body, {'name': 'Act I', 'parent_part_id': 'root-1'});
      expect(result, isA<PartDetail>());
      expect(result.parentPartId, 'root-1');
    });
  });

  group('updatePart', () {
    test('PATCHes the part; parent_part_id null = move to root, after = reorder',
        () async {
      when(() => dio.patch(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _resp(_partDetailJson()));

      await repo.updatePart(
        'bp-1',
        'part-1',
        parentPartId: null, // present-and-null => move to root
        afterPartId: 'sib-1',
      );

      final body = verify(
        () => dio.patch(
          '/blueprints/bp-1/parts/part-1',
          data: captureAny(named: 'data'),
        ),
      ).captured.single as Map<String, dynamic>;
      expect(body, {'parent_part_id': null, 'after_part_id': 'sib-1'});
      expect(body.containsKey('parent_part_id'), isTrue);
    });

    test('omits every field left unset', () async {
      when(() => dio.patch(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _resp(_partDetailJson()));

      await repo.updatePart('bp-1', 'part-1', name: 'Ch 2');

      final body = verify(
        () => dio.patch(
          '/blueprints/bp-1/parts/part-1',
          data: captureAny(named: 'data'),
        ),
      ).captured.single as Map<String, dynamic>;
      expect(body, {'name': 'Ch 2'});
      expect(body.containsKey('parent_part_id'), isFalse);
      expect(body.containsKey('after_part_id'), isFalse);
    });
  });

  group('deletePart', () {
    test('DELETEs /blueprints/{id}/parts/{partId}', () async {
      when(() => dio.delete(any())).thenAnswer((_) async => _resp(null));

      await repo.deletePart('bp-1', 'part-1');

      verify(() => dio.delete('/blueprints/bp-1/parts/part-1')).called(1);
    });
  });

  // ── Project ↔ blueprint adoption ─────────────────────────────────────────

  group('listAdoptedBlueprints', () {
    test('GETs /projects/{id}/blueprints/ and parses adopted blueprints',
        () async {
      when(() => dio.get(any())).thenAnswer(
        (_) async => _resp([_adoptedJson(isPrimary: true)]),
      );

      final result = await repo.listAdoptedBlueprints('proj-1');

      verify(() => dio.get('/projects/proj-1/blueprints/')).called(1);
      expect(result, isA<List<AdoptedBlueprint>>());
      expect(result.single.isPrimary, isTrue);
    });
  });

  group('adoptBlueprint', () {
    test('POSTs {blueprint_id} only by default', () async {
      when(() => dio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _resp(_adoptedJson()));

      final result = await repo.adoptBlueprint('proj-1', 'bp-1');

      final body = verify(
        () => dio.post(
          '/projects/proj-1/blueprints/',
          data: captureAny(named: 'data'),
        ),
      ).captured.single as Map<String, dynamic>;
      expect(body, {'blueprint_id': 'bp-1'});
      expect(body.containsKey('is_primary'), isFalse);
      expect(result, isA<AdoptedBlueprint>());
    });

    test('includes is_primary when adopting as primary', () async {
      when(() => dio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _resp(_adoptedJson()));

      await repo.adoptBlueprint('proj-1', 'bp-1', isPrimary: true);

      final body = verify(
        () => dio.post(
          '/projects/proj-1/blueprints/',
          data: captureAny(named: 'data'),
        ),
      ).captured.single;
      expect(body, {'blueprint_id': 'bp-1', 'is_primary': true});
    });
  });

  group('setPrimaryBlueprint', () {
    test('PATCHes {is_primary: true} and parses the adoption', () async {
      when(() => dio.patch(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _resp(_adoptedJson()));

      final result = await repo.setPrimaryBlueprint('proj-1', 'bp-1');

      final body = verify(
        () => dio.patch(
          '/projects/proj-1/blueprints/bp-1',
          data: captureAny(named: 'data'),
        ),
      ).captured.single;
      expect(body, {'is_primary': true});
      expect(result, isA<AdoptedBlueprint>());
    });

    test('PATCHes {is_primary: false} to clear primary', () async {
      when(() => dio.patch(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _resp(_adoptedJson(isPrimary: false)));

      await repo.setPrimaryBlueprint('proj-1', 'bp-1', isPrimary: false);

      final body = verify(
        () => dio.patch(
          '/projects/proj-1/blueprints/bp-1',
          data: captureAny(named: 'data'),
        ),
      ).captured.single;
      expect(body, {'is_primary': false});
    });
  });

  group('unadoptBlueprint', () {
    test('DELETEs /projects/{id}/blueprints/{blueprintId}', () async {
      when(() => dio.delete(any())).thenAnswer((_) async => _resp(null));

      await repo.unadoptBlueprint('proj-1', 'bp-1');

      verify(() => dio.delete('/projects/proj-1/blueprints/bp-1')).called(1);
    });
  });

  // ── Document placement ───────────────────────────────────────────────────

  group('setPlacement', () {
    test('PUTs {part_id, role} and parses the placement', () async {
      when(() => dio.put(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _resp(_placementJson()));

      final result =
          await repo.setPlacement('doc-1', 'part-1', Role.mainContent);

      final body = verify(
        () => dio.put('/documents/doc-1/placement', data: captureAny(named: 'data')),
      ).captured.single;
      expect(body, {'part_id': 'part-1', 'role': 'Main Content'});
      expect(result, isA<DocumentPlacement>());
      expect(result.role, Role.mainContent);
    });
  });

  group('getPlacement', () {
    test('GETs /documents/{id}/placement and parses', () async {
      when(() => dio.get(any())).thenAnswer((_) async => _resp(_placementJson()));

      final result = await repo.getPlacement('doc-1');

      verify(() => dio.get('/documents/doc-1/placement')).called(1);
      expect(result.documentId, 'doc-1');
    });
  });

  group('removePlacement', () {
    test('DELETEs /documents/{id}/placement', () async {
      when(() => dio.delete(any())).thenAnswer((_) async => _resp(null));

      await repo.removePlacement('doc-1');

      verify(() => dio.delete('/documents/doc-1/placement')).called(1);
    });
  });

  // ── Derived overview ─────────────────────────────────────────────────────

  group('getProjectBlueprintOverview', () {
    test('GETs /projects/{id}/blueprint-overview/ and parses', () async {
      when(() => dio.get(any())).thenAnswer((_) async => _resp(_overviewJson()));

      final result = await repo.getProjectBlueprintOverview('proj-1');

      verify(() => dio.get('/projects/proj-1/blueprint-overview/')).called(1);
      expect(result, isA<ProjectBlueprintOverview>());
      expect(result.progress!.ratio, 0.5);
      expect(result.blueprints.single.parts.single.readiness, Readiness.ready);
    });
  });

  // ── Error propagation ────────────────────────────────────────────────────

  group('error handling', () {
    test('propagates a DioException from the client (no swallowing)', () async {
      when(() => dio.get(any())).thenThrow(
        DioException(requestOptions: RequestOptions(path: '/blueprints/')),
      );

      await expectLater(repo.listBlueprints(), throwsA(isA<DioException>()));
    });
  });

  // ── Unknown-enum write guard (never hits the client) ─────────────────────

  group('unknown-enum write guard', () {
    test('setPlacement with Role.unknown throws ArgumentError, no request',
        () async {
      await expectLater(
        repo.setPlacement('doc-1', 'part-1', Role.unknown),
        throwsA(isA<ArgumentError>()),
      );
      verifyNever(() => dio.put(any(), data: any(named: 'data')));
    });

    test('createBlueprint with Genre.unknown throws ArgumentError, no request',
        () async {
      await expectLater(
        repo.createBlueprint(name: 'X', genre: Genre.unknown),
        throwsA(isA<ArgumentError>()),
      );
      verifyNever(() => dio.post(any(), data: any(named: 'data')));
    });

    test('updateBlueprint with BlueprintStatus.unknown throws, no request',
        () async {
      await expectLater(
        repo.updateBlueprint('bp-1', status: BlueprintStatus.unknown),
        throwsA(isA<ArgumentError>()),
      );
      verifyNever(() => dio.patch(any(), data: any(named: 'data')));
    });
  });
}
