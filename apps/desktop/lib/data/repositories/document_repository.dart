import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../models/document.dart';

/// Document repository — API communication for document operations.
class DocumentRepository {
  final ApiClient _api;

  DocumentRepository(this._api);

  /// List all documents for the current user.
  Future<List<Document>> listDocuments({int page = 1, int limit = 20}) async {
    final response = await _api.dio.get('/documents/', queryParameters: {
      'page': page,
      'limit': limit,
    });
    final items = response.data['items'] as List<dynamic>;
    return items
        .map((e) => Document.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Upload a document file.
  Future<Document> uploadDocument(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _api.dio.post('/documents/', data: formData);
    return Document.fromJson(response.data as Map<String, dynamic>);
  }

  /// Delete a document by ID.
  Future<void> deleteDocument(String id) async {
    await _api.dio.delete('/documents/$id');
  }

  /// Rename a document (title only).
  Future<Document> renameDocument(String id, String title) async {
    final response = await _api.dio.patch('/documents/$id', data: {
      'title': title,
    });
    return Document.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get chunks for a document.
  Future<Map<String, dynamic>> getChunks(String documentId) async {
    final response = await _api.dio.get('/documents/$documentId/chunks');
    return response.data as Map<String, dynamic>;
  }

  /// Fetch word-timing alignment for a specific chunk + voice.
  ///
  /// On first call per chunk: backend synthesises via ElevenLabs
  /// /with-timestamps, persists the mp3 + sidecar JSON, then returns the
  /// alignment payload. Subsequent calls hit the sidecar cache and are fast.
  ///
  /// The 120 s receiveTimeout is intentional — first-time ElevenLabs
  /// synthesis for a 1 500-char chunk can take up to 45 s.
  ///
  /// Returns an empty map on any failure so callers degrade gracefully
  /// to plain text — never throws.
  Future<Map<String, dynamic>> getChunkAlignment({
    required String documentId,
    required String chunkId,
    required String voiceId,
  }) async {
    try {
      final response = await _api.dio.get<Map<String, dynamic>>(
        '/documents/$documentId/chunks/$chunkId/alignment',
        queryParameters: {'voice_id': voiceId},
        options: Options(
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data!;
      }
      return {};
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[DocumentRepository] getChunkAlignment DioException: ${e.message}');
      return {};
    } catch (e) {
      // ignore: avoid_print
      print('[DocumentRepository] getChunkAlignment unexpected error: $e');
      return {};
    }
  }

  /// Synthesize all chunks for a document with a specific voice.
  Future<Map<String, dynamic>> synthesizeDocument(
      String documentId, String voiceId) async {
    final response = await _api.dio.post(
      '/documents/$documentId/synthesize',
      queryParameters: {'voice_id': voiceId},
    );
    return response.data as Map<String, dynamic>;
  }
}
