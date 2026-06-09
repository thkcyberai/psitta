// Unit tests for the Phase 5 project reads: ProjectRepository.getProjectDetail
// / getProjectPlacements (parse + path via a mocktail Dio) and the
// projectDetail/projectPlacements/projectDocuments providers (delegation +
// word_count round-trip). Fixtures mirror the backend Phase 5 payloads.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:psitta/data/api/api_client.dart';
import 'package:psitta/data/models/blueprint_enums.dart';
import 'package:psitta/data/models/project_detail.dart';
import 'package:psitta/data/providers/project_providers.dart';
import 'package:psitta/data/providers/providers.dart';
import 'package:psitta/data/repositories/project_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

class MockProjectRepository extends Mock implements ProjectRepository {}

Response<dynamic> _resp(dynamic data) => Response<dynamic>(
      requestOptions: RequestOptions(path: '/'),
      data: data,
      statusCode: 200,
    );

Map<String, dynamic> _detailJson() => {
      'id': 'p1',
      'name': 'P5 Project',
      'user_id': 'u1',
      'created_at': '2026-06-09T00:00:00Z',
      'updated_at': '2026-06-09T01:00:00Z',
      'document_count': 2,
      'blueprint_count': 1,
      'total_words': 350,
    };

Map<String, dynamic> _placementJson() => {
      'document_id': 'd1',
      'blueprint_id': 'b1',
      'part_id': 'pt1',
      'blueprint_name': 'Nested',
      'part_name': 'Act I',
      'role': 'Main Content',
      'sort_order': 1000.0,
    };

Map<String, dynamic> _docJson() => {
      'id': 'd1',
      'title': 'Doc',
      'source_type': 'docx',
      'status': 'ready',
      'page_count': 1,
      'word_count': 100,
      'file_size_bytes': 10,
      'created_at': '2026-06-09T00:00:00Z',
      'project_id': 'p1',
      'cover_type': null,
      'cover_value': null,
    };

void main() {
  group('ProjectRepository', () {
    late MockApiClient api;
    late MockDio dio;
    late ProjectRepository repo;

    setUp(() {
      api = MockApiClient();
      dio = MockDio();
      when(() => api.dio).thenReturn(dio);
      repo = ProjectRepository(api);
    });

    test('getProjectDetail GETs /projects/{id} and parses', () async {
      when(() => dio.get(any())).thenAnswer((_) async => _resp(_detailJson()));

      final detail = await repo.getProjectDetail('p1');

      verify(() => dio.get('/projects/p1')).called(1);
      expect(detail, isA<ProjectDetail>());
      expect(detail.name, 'P5 Project');
      expect(detail.userId, 'u1');
      expect(detail.documentCount, 2);
      expect(detail.blueprintCount, 1);
      expect(detail.totalWords, 350);
      expect(detail.createdAt, DateTime.utc(2026, 6, 9, 0));
      expect(detail.updatedAt, DateTime.utc(2026, 6, 9, 1));
    });

    test('getProjectPlacements GETs /placements and parses the list', () async {
      when(() => dio.get(any()))
          .thenAnswer((_) async => _resp([_placementJson()]));

      final placements = await repo.getProjectPlacements('p1');

      verify(() => dio.get('/projects/p1/placements')).called(1);
      expect(placements, hasLength(1));
      final p = placements.single;
      expect(p.documentId, 'd1');
      expect(p.blueprintId, 'b1');
      expect(p.partId, 'pt1');
      expect(p.blueprintName, 'Nested');
      expect(p.partName, 'Act I');
      // WD-P0: role defaults to "Main Content"; sort_order is the first-append
      // position (blueprint_service._GAP = 1000), serialised as float.
      expect(p.role, Role.mainContent);
      expect(p.sortOrder, 1000.0);
    });

    test('getProjectPlacements returns an empty list', () async {
      when(() => dio.get(any())).thenAnswer((_) async => _resp(<dynamic>[]));
      expect(await repo.getProjectPlacements('p1'), isEmpty);
    });
  });

  group('providers', () {
    test('projectDetailProvider delegates to the repository', () async {
      final repo = MockProjectRepository();
      when(() => repo.getProjectDetail('p1')).thenAnswer(
        (_) async => ProjectDetail.fromJson(_detailJson()),
      );
      final container = ProviderContainer(
        overrides: [projectRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final detail = await container.read(projectDetailProvider('p1').future);
      expect(detail.name, 'P5 Project');
      verify(() => repo.getProjectDetail('p1')).called(1);
    });

    test('projectPlacementsProvider delegates to the repository', () async {
      final repo = MockProjectRepository();
      when(() => repo.getProjectPlacements('p1')).thenAnswer(
        (_) async => [ProjectPlacement.fromJson(_placementJson())],
      );
      final container = ProviderContainer(
        overrides: [projectRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final list = await container.read(projectPlacementsProvider('p1').future);
      expect(list.single.partName, 'Act I');
      expect(list.single.role, Role.mainContent);
      expect(list.single.sortOrder, 1000.0);
      verify(() => repo.getProjectPlacements('p1')).called(1);
    });

    test('projectDocumentsProvider hits the docs route and carries word_count',
        () async {
      final api = MockApiClient();
      final dio = MockDio();
      when(() => api.dio).thenReturn(dio);
      when(() => dio.get(any())).thenAnswer((_) async => _resp([_docJson()]));
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);

      final docs = await container.read(projectDocumentsProvider('p1').future);
      verify(() => dio.get('/projects/p1/documents')).called(1);
      expect(docs.single.wordCount, 100);
    });
  });
}
