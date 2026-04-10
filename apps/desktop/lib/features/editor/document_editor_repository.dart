import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api/api_client.dart';
import '../../data/providers/providers.dart';

class DocumentEditorRepository {
  DocumentEditorRepository(this._api);

  final ApiClient _api;

  /// PATCH /documents/{docId}/chunks/{chunkId}
  Future<Map<String, dynamic>> updateChunkText({
    required String documentId,
    required String chunkId,
    required String text,
  }) async {
    final url = '/documents/$documentId/chunks/$chunkId';
    final payload = {'text': text};
    debugPrint(
        '[DocumentEditorRepository.updateChunkText] PATCH $url payload=$payload');
    final response = await _api.dio.patch(
      url,
      data: payload,
    );
    debugPrint(
        '[DocumentEditorRepository.updateChunkText] response status=${response.statusCode} data=${response.data}');
    return response.data as Map<String, dynamic>;
  }

  /// POST /documents/{docId}/chunks/{chunkId}/resynthesize
  Future<Map<String, dynamic>> resynthesizeChunk({
    required String documentId,
    required String chunkId,
    required String voiceId,
    double speed = 1.0,
  }) async {
    final response = await _api.dio.post(
      '/documents/$documentId/chunks/$chunkId/resynthesize',
      queryParameters: {'voice_id': voiceId, 'speed': speed},
    );
    return response.data as Map<String, dynamic>;
  }

  /// GET /documents/{docId}/chunks — fetch all chunks for editor screen
  Future<List<Map<String, dynamic>>> fetchChunks({
    required String documentId,
  }) async {
    final response = await _api.dio.get('/documents/$documentId/chunks');
    final data = response.data as Map<String, dynamic>;
    return (data['chunks'] as List).cast<Map<String, dynamic>>();
  }
}

// Provider
final documentEditorRepositoryProvider =
    Provider<DocumentEditorRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return DocumentEditorRepository(api);
});
