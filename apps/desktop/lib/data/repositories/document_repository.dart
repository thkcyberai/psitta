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
    return items.map((e) => Document.fromJson(e as Map<String, dynamic>)).toList();
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

  /// Get chunks for a document.
  Future<Map<String, dynamic>> getChunks(String documentId) async {
    final response = await _api.dio.get('/documents/$documentId/chunks');
    return response.data as Map<String, dynamic>;
  }

  /// Synthesize all chunks for a document with a specific voice.
  Future<Map<String, dynamic>> synthesizeDocument(String documentId, String voiceId) async {
    final response = await _api.dio.post(
      '/documents/$documentId/synthesize',
      queryParameters: {'voice_id': voiceId},
    );
    return response.data as Map<String, dynamic>;
  }
}
