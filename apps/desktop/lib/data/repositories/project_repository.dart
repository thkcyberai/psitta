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

  /// Document→blueprint/part placements for a project
  /// (`GET /projects/{id}/placements`).
  Future<List<ProjectPlacement>> getProjectPlacements(String id) async {
    final response = await _api.dio.get('/projects/$id/placements');
    return (response.data as List)
        .map((e) => ProjectPlacement.fromJson(e as Map<String, dynamic>))
        .toList();
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
