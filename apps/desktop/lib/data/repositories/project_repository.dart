import '../api/api_client.dart';

class Project {
  final String id;
  final String name;
  final int documentCount;
  final String createdAt;

  const Project({
    required this.id,
    required this.name,
    required this.documentCount,
    required this.createdAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        name: json['name'] as String,
        documentCount: (json['document_count'] as num?)?.toInt() ?? 0,
        createdAt: json['created_at'] as String? ?? '',
      );
}

class ProjectRepository {
  final ApiClient _api;
  ProjectRepository(this._api);

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
}
