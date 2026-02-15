import '../api/api_client.dart';
import '../models/playback_session.dart';

/// Playback repository — API communication for audio sessions.
class PlaybackRepository {
  final ApiClient _api;

  PlaybackRepository(this._api);

  /// Create a new playback session for a document.
  Future<PlaybackSession> createSession({
    required String documentId,
    String voiceId = 'en-US-AriaNeural',
    double speed = 1.0,
  }) async {
    final response = await _api.dio.post('/playback/sessions/', data: {
      'document_id': documentId,
      'voice_id': voiceId,
      'speed': speed,
    });
    return PlaybackSession.fromJson(response.data as Map<String, dynamic>);
  }

  /// Update playback position.
  Future<void> updatePosition({
    required String sessionId,
    required int chunkIndex,
    required int positionMs,
  }) async {
    await _api.dio.patch('/playback/sessions/$sessionId/position', data: {
      'chunk_index': chunkIndex,
      'position_ms': positionMs,
    });
  }
}
