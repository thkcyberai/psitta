import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../api/api_client.dart';
import '../models/document.dart';

/// Document repository — API communication for document operations.
class DocumentRepository {
  DocumentRepository(this._api);

  final ApiClient _api;

  void _logPdfPerf(String stage, String message) {
    debugPrint('[PDF PERF][$stage] $message');
  }

  /// List all documents for the current user.
  Future<List<Document>> listDocuments(
      {int page = 1, int limit = 20, bool showArchived = false}) async {
    final response = await _api.dio.get('/documents/', queryParameters: {
      'page': page,
      'limit': limit,
      'show_archived': showArchived,
    });
    final items = response.data['items'] as List<dynamic>;
    return items
        .map((e) => Document.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Upload a document file.
  ///
  /// When [pageTexts] is provided the extracted page texts are sent alongside
  /// the file so the backend can skip server-side PDF parsing.
  Future<Document> uploadDocument(
    String filePath, {
    List<Map<String, dynamic>>? pageTexts,
  }) async {
    final map = <String, dynamic>{
      'file': await MultipartFile.fromFile(filePath),
    };
    if (pageTexts != null && pageTexts.isNotEmpty) {
      map['page_texts'] = jsonEncode(pageTexts);
    }
    final formData = FormData.fromMap(map);
    final response = await _api.dio.post('/documents/', data: formData);
    return Document.fromJson(response.data as Map<String, dynamic>);
  }

  /// Create a blank document for direct writing.
  /// Returns a map with 'id' and 'chunk_id'.
  Future<Map<String, String>> createBlankDocument() async {
    final response = await _api.dio.post('/documents/blank/');
    final data = response.data as Map<String, dynamic>;
    return {
      'id': data['id'] as String,
      'chunk_id': data['chunk_id'] as String,
    };
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
    final stopwatch = Stopwatch()..start();
    _logPdfPerf(
      'alignment',
      'start doc=$documentId chunk=$chunkId voice=$voiceId',
    );
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
        stopwatch.stop();
        _logPdfPerf(
          'alignment',
          'ready doc=$documentId chunk=$chunkId status=${response.statusCode} elapsed=${stopwatch.elapsedMilliseconds}ms',
        );
        return response.data!;
      }
      stopwatch.stop();
      _logPdfPerf(
        'alignment',
        'empty doc=$documentId chunk=$chunkId status=${response.statusCode} elapsed=${stopwatch.elapsedMilliseconds}ms',
      );
      return {};
    } on DioException catch (e) {
      stopwatch.stop();
      _logPdfPerf(
        'alignment',
        'dio_error doc=$documentId chunk=$chunkId elapsed=${stopwatch.elapsedMilliseconds}ms error=${e.message}',
      );
      // ignore: avoid_print
      print(
          '[DocumentRepository] getChunkAlignment DioException: ${e.message}');
      return {};
    } catch (e) {
      stopwatch.stop();
      _logPdfPerf(
        'alignment',
        'error doc=$documentId chunk=$chunkId elapsed=${stopwatch.elapsedMilliseconds}ms error=$e',
      );
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

  /// Archive or unarchive a document (toggles on backend).
  Future<void> archiveDocument(String id) async {
    await _api.dio.patch('/documents/$id/archive');
  }

  /// Assign or remove a document from a project.
  Future<void> assignToProject(String id, String? projectId) async {
    await _api.dio.patch(
      '/documents/$id/project',
      data: {'project_id': projectId},
    );
  }

  /// Download the original file. Returns the response bytes.
  Future<List<int>> downloadDocument(String id) async {
    final stopwatch = Stopwatch()..start();
    _logPdfPerf('download', 'request_start doc=$id');
    final response = await _api.dio.get<List<int>>(
      '/documents/$id/download',
      options: Options(responseType: ResponseType.bytes),
    );
    stopwatch.stop();
    _logPdfPerf(
      'download',
      'request_done doc=$id status=${response.statusCode} bytes=${response.data?.length ?? 0} elapsed=${stopwatch.elapsedMilliseconds}ms',
    );
    return response.data ?? [];
  }

  /// Download the original file and persist it to a stable temp path.
  ///
  /// This is used by native viewers that prefer a file path over in-memory
  /// bytes, such as the PDF viewport in the desktop Player.
  Future<File> downloadDocumentToTempFile(
    String id, {
    required String extension,
  }) async {
    final stopwatch = Stopwatch()..start();
    _logPdfPerf('open', 'tempfile_start doc=$id extension=$extension');
    final bytes = await downloadDocument(id);
    _logPdfPerf(
      'open',
      'bytes_ready doc=$id bytes=${bytes.length} elapsed=${stopwatch.elapsedMilliseconds}ms',
    );
    final tempDir = await getTemporaryDirectory();
    final docsDir = Directory(p.join(tempDir.path, 'psitta_documents'));
    if (!docsDir.existsSync()) {
      docsDir.createSync(recursive: true);
    }

    final normalizedExt = extension.startsWith('.')
        ? extension.toLowerCase()
        : '.${extension.toLowerCase()}';
    final file = File(p.join(docsDir.path, '$id$normalizedExt'));
    await file.writeAsBytes(bytes, flush: true);
    stopwatch.stop();
    _logPdfPerf(
      'open',
      'tempfile_ready doc=$id path=${file.path} elapsed=${stopwatch.elapsedMilliseconds}ms',
    );
    return file;
  }

  /// Export document as a branded DOCX. Returns the file bytes.
  Future<List<int>> exportDocument(
    String id, {
    bool includeCover = true,
    bool includeFooter = true,
  }) async {
    final response = await _api.dio.get<List<int>>(
      '/documents/$id/export',
      queryParameters: {
        'cover': includeCover,
        'footer': includeFooter,
      },
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  /// Update document cover to a built-in illustration.
  Future<Document> setCoverBuiltin(String id, String illustrationId) async {
    final response = await _api.dio.patch('/documents/$id', data: {
      'cover_type': 'builtin',
      'cover_value': illustrationId,
    });
    return Document.fromJson(response.data as Map<String, dynamic>);
  }

  /// Remove document cover.
  Future<Document> removeCover(String id) async {
    final response = await _api.dio.patch('/documents/$id', data: {
      'cover_type': null,
      'cover_value': null,
    });
    return Document.fromJson(response.data as Map<String, dynamic>);
  }

  /// Upload a custom cover image.
  Future<Document> uploadCover(String id, String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _api.dio.post(
      '/documents/$id/cover',
      data: formData,
    );
    return Document.fromJson(response.data as Map<String, dynamic>);
  }

  /// Clear audio cache for all chunks and queue re-synthesis.
  Future<void> resynthesizeDocument(String id) async {
    final response = await _api.dio.post('/documents/$id/resynthesize');
    if (response.statusCode != 200) {
      final msg = (response.data is Map && response.data['detail'] != null)
          ? response.data['detail'] as String
          : 'Failed to regenerate audio';
      throw Exception(msg);
    }
  }
}
