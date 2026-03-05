import '../api/api_client.dart';
import '../models/playback_session.dart';

/// Playback repository — session creation, position persistence, and resume.
class PlaybackRepository {
  final ApiClient _api;
  PlaybackRepository(this._api);

  /// Create or resume a playback session for a document.
  Future<PlaybackSession> createSession({
    required String documentId,
    String voiceId = '21m00Tcm4TlvDq8ikWAM',
    double speed = 1.0,
  }) async {
    final response = await _api.dio.post(
      '/playback/sessions/',
      queryParameters: {
        'document_id': documentId,
        'voice_id': voiceId,
        'speed': speed,
      },
    );
    return PlaybackSession.fromJson(response.data as Map<String, dynamic>);
  }

  /// Fetch last saved position for a document. Returns null if no session exists.
  Future<PlaybackSession?> getResumeSession(String documentId) async {
    try {
      final response = await _api.dio
          .get('/playback/sessions/resume/$documentId');
      return PlaybackSession.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Persist current chunk index and position within chunk.
  /// Called every 5 seconds during playback.
  Future<void> updatePosition({
    required String sessionId,
    required int chunkIndex,
    required int positionMs,
  }) async {
    await _api.dio.patch(
      '/playback/sessions/$sessionId/position/',
      queryParameters: {
        'chunk_index': chunkIndex,
        'position_ms': positionMs,
      },
    );
  }
}
