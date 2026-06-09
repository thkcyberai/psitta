import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/document.dart';
import '../models/project_detail.dart';
import 'providers.dart' show apiClientProvider, projectRepositoryProvider;

/// Providers for the Project screen's reads. Kept here (not file-local in the
/// screen) so the tabs share one source of truth.

/// Documents in a project (`GET /projects/{id}/documents`). Relocated from
/// project_detail_screen.dart for reuse across the Overview/Documents tabs.
final projectDocumentsProvider = FutureProvider.autoDispose
    .family<List<Document>, String>((ref, projectId) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.dio.get('/projects/$projectId/documents');
  return (response.data as List)
      .map((e) => Document.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Aggregated project detail (`GET /projects/{id}`).
final projectDetailProvider = FutureProvider.autoDispose
    .family<ProjectDetail, String>((ref, projectId) async {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.getProjectDetail(projectId);
});

/// Document→blueprint/part placements (`GET /projects/{id}/placements`).
final projectPlacementsProvider = FutureProvider.autoDispose
    .family<List<ProjectPlacement>, String>((ref, projectId) async {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.getProjectPlacements(projectId);
});
