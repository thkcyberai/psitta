import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api/api_client.dart';
import '../../data/providers/providers.dart';
import '../player/chunk_slicer.dart' show ChunkPositionRange;

class DocumentEditorRepository {
  DocumentEditorRepository(this._api);

  final ApiClient _api;

  /// PATCH /documents/{docId}/chunks/{chunkId}
  ///
  /// When [formattedContent] is supplied, it is sent verbatim as
  /// `formatted_content` in the JSON body and the backend persists it
  /// exactly as-is (the Phase 1 toolbar-persist path). When omitted, the
  /// backend falls back to its server-side rebuild heuristic.
  Future<Map<String, dynamic>> updateChunkText({
    required String documentId,
    required String chunkId,
    required String text,
    List<Map<String, dynamic>>? formattedContent,
  }) async {
    final url = '/documents/$documentId/chunks/$chunkId';
    final payload = <String, dynamic>{'text': text};
    if (formattedContent != null) {
      payload['formatted_content'] = formattedContent;
    }
    debugPrint(
        '[DocumentEditorRepository.updateChunkText] PATCH $url '
        'text.len=${text.length} fmt.blocks=${formattedContent?.length ?? 0}');
    final response = await _api.dio.patch(
      url,
      data: payload,
    );
    debugPrint(
        '[DocumentEditorRepository.updateChunkText] response status=${response.statusCode}');
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

  /// POST /documents/{docId}/chunks — insert a new chunk at [sequenceIndex].
  ///
  /// M13.1b save-path helper. The backend shifts occupied tail positions
  /// by +100 000 before inserting so the UNIQUE (document_id,
  /// sequence_index) index never collides; a subsequent
  /// [updateDocument] call with the authoritative `chunk_positions`
  /// list compacts the sequence_index back to 0..N-1 in one
  /// transaction. Returns the server-assigned chunk row (id, etc).
  Future<Map<String, dynamic>> insertChunk({
    required String documentId,
    required int sequenceIndex,
    required String text,
    List<Map<String, dynamic>>? formattedContent,
    int? pageNumber,
  }) async {
    final payload = <String, dynamic>{
      'sequence_index': sequenceIndex,
      'text': text,
    };
    if (formattedContent != null) {
      payload['formatted_content'] = formattedContent;
    }
    if (pageNumber != null) payload['page_number'] = pageNumber;
    debugPrint(
        '[DocumentEditorRepository.insertChunk] POST /documents/$documentId/chunks '
        'seq=$sequenceIndex text.len=${text.length} fmt.blocks=${formattedContent?.length ?? 0}');
    final response = await _api.dio.post(
      '/documents/$documentId/chunks',
      data: payload,
    );
    debugPrint(
        '[DocumentEditorRepository.insertChunk] response status=${response.statusCode}');
    return response.data as Map<String, dynamic>;
  }

  /// DELETE /documents/{docId}/chunks/{chunkId} — remove a chunk.
  ///
  /// Server-side invalidates the three-layer audio cache (S3 + /tmp +
  /// audio_segments DB rows) before the chunk row is deleted.
  Future<void> deleteChunk({
    required String documentId,
    required String chunkId,
  }) async {
    debugPrint(
        '[DocumentEditorRepository.deleteChunk] DELETE /documents/$documentId/chunks/$chunkId');
    await _api.dio.delete('/documents/$documentId/chunks/$chunkId');
  }

  /// PATCH /documents/{docId} — update top-level document fields. M13.1b
  /// uses this to persist the authoritative `chunk_positions` map and
  /// trigger the server-side sequence_index reindex in a single
  /// transaction (see backend update_document handler).
  ///
  /// Returns the updated document payload. When [chunkPositions] is
  /// supplied the backend validates it matches the current chunk rows
  /// (HTTP 422 on mismatch).
  Future<Map<String, dynamic>> updateDocument({
    required String documentId,
    List<ChunkPositionRange>? chunkPositions,
    int? chunkCount,
    String? title,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (chunkPositions != null) {
      payload['chunk_positions'] =
          chunkPositions.map((r) => r.toJson()).toList();
    }
    if (chunkCount != null) payload['chunk_count'] = chunkCount;
    if (payload.isEmpty) {
      debugPrint(
          '[DocumentEditorRepository.updateDocument] no fields — skipping');
      return const <String, dynamic>{};
    }
    debugPrint(
        '[DocumentEditorRepository.updateDocument] PATCH /documents/$documentId '
        'keys=${payload.keys.toList()} positions=${chunkPositions?.length ?? 0}');
    final response = await _api.dio.patch(
      '/documents/$documentId',
      data: payload,
    );
    debugPrint(
        '[DocumentEditorRepository.updateDocument] response status=${response.statusCode}');
    return response.data as Map<String, dynamic>;
  }
}

// Provider
final documentEditorRepositoryProvider =
    Provider<DocumentEditorRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return DocumentEditorRepository(api);
});
