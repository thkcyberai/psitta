import '../api/api_client.dart';
import '../models/project_detail.dart';

class Project {
  const Project({
    required this.id,
    required this.name,
    required this.documentCount,
    required this.createdAt,
    this.coverDocumentId,
    this.coverType,
    this.coverValue,
  });

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        name: json['name'] as String,
        documentCount: (json['document_count'] as num?)?.toInt() ?? 0,
        createdAt: json['created_at'] as String? ?? '',
        coverDocumentId: json['cover_document_id'] as String?,
        coverType: json['cover_type'] as String?,
        coverValue: json['cover_value'] as String?,
      );

  final String id;
  final String name;
  final int documentCount;
  final String createdAt;
  final String? coverDocumentId;
  final String? coverType;
  final String? coverValue;
}

/// AI Story-Coach verdict for one passage (`POST /projects/{id}/narrative/check`).
class NarrativeCheckResult {
  const NarrativeCheckResult({
    required this.aligned,
    required this.message,
    required this.suspectedBeat,
  });

  factory NarrativeCheckResult.fromJson(Map<String, dynamic> json) =>
      NarrativeCheckResult(
        aligned: json['aligned'] as bool? ?? true,
        message: (json['message'] as String?) ?? '',
        suspectedBeat: (json['suspected_beat'] as String?) ?? '',
      );

  /// True when the passage fits the project's chosen arc. Defaults true so a
  /// malformed response never raises a false alarm.
  final bool aligned;
  final String message;
  final String suspectedBeat;
}

class ProjectRepository {
  ProjectRepository(this._api);
  final ApiClient _api;

  Future<List<Project>> listProjects() async {
    final response = await _api.dio.get('/projects/');
    return (response.data as List)
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Project> createProject(String name) async {
    final response = await _api.dio.post('/projects/', data: {'name': name});
    return Project.fromJson(response.data as Map<String, dynamic>);
  }

  /// Aggregated detail for one project (`GET /projects/{id}`).
  Future<ProjectDetail> getProjectDetail(String id) async {
    final response = await _api.dio.get('/projects/$id');
    return ProjectDetail.fromJson(response.data as Map<String, dynamic>);
  }

  /// Set (or clear) the project's chosen narrative
  /// (`PUT /projects/{id}/narrative`). Returns the refreshed detail.
  Future<ProjectDetail> setProjectNarrative(
    String id, {
    required String? structureKey,
    required String? variant,
    required List<String>? beats,
  }) async {
    final response = await _api.dio.put('/projects/$id/narrative', data: {
      'narrative_structure_key': structureKey,
      'narrative_variant': variant,
      'narrative_beats': beats,
    });
    return ProjectDetail.fromJson(response.data as Map<String, dynamic>);
  }

  /// Curated, reverse-chronological Activity feed for a project
  /// (`GET /projects/{id}/activity`).
  Future<List<ActivityEvent>> getProjectActivity(String id,
      {int limit = 50}) async {
    final response = await _api.dio.get(
      '/projects/$id/activity',
      queryParameters: {'limit': limit},
    );
    return (response.data as List)
        .map((e) => ActivityEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Scene Mapper: set (or clear with null) which narrative beat a document
  /// covers (`PUT /projects/{id}/documents/{docId}/beat`).
  Future<void> setDocumentNarrativeBeat(
    String projectId,
    String documentId, {
    required String? beat,
  }) async {
    await _api.dio.put(
      '/projects/$projectId/documents/$documentId/beat',
      data: {'beat': beat},
    );
  }

  /// Document→blueprint/part placements for a project
  /// (`GET /projects/{id}/placements`).
  Future<List<ProjectPlacement>> getProjectPlacements(String id) async {
    final response = await _api.dio.get('/projects/$id/placements');
    return (response.data as List)
        .map((e) => ProjectPlacement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// AI Story-Coach: ask whether [passage] fits the project's committed
  /// narrative (`POST /projects/{id}/narrative/check`).
  ///
  /// Fail-quiet by design — returns null on ANY error (no LLM plan → 403,
  /// quota exhausted → 402, no narrative → 422, network/5xx/timeout), so the
  /// caller can simply skip showing a nudge and never surfaces an error.
  Future<NarrativeCheckResult?> checkNarrative(
    String projectId, {
    required String passage,
  }) async {
    try {
      final response = await _api.dio.post(
        '/projects/$projectId/narrative/check',
        data: {'passage': passage},
      );
      return NarrativeCheckResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> renameProject(String id, String name) async {
    await _api.dio.patch('/projects/$id', data: {'name': name});
  }

  Future<void> deleteProject(String id) async {
    await _api.dio.delete('/projects/$id');
  }

  Future<void> assignToProject(String documentId, String? projectId) async {
    await _api.dio.patch(
      '/documents/$documentId/project',
      data: {'project_id': projectId},
    );
  }

  /// Set or remove the project cover document.
  Future<void> setProjectCover(String projectId, String? documentId) async {
    await _api.dio.patch(
      '/projects/$projectId',
      data: {'cover_document_id': documentId},
    );
  }
}
