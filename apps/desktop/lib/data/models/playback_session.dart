/// PlaybackSession model — mirrors backend PlaybackSessionResponse.
///
/// TODO: Generate with freezed + json_serializable.
class PlaybackSession {
  final String id;
  final String documentId;
  final String voiceId;
  final double speed;
  final int currentChunkIndex;
  final int positionMs;

  const PlaybackSession({
    required this.id,
    required this.documentId,
    required this.voiceId,
    required this.speed,
    required this.currentChunkIndex,
    required this.positionMs,
  });

  factory PlaybackSession.fromJson(Map<String, dynamic> json) =>
      PlaybackSession(
        id: json['session_id'] as String,
        documentId: json['document_id'] as String,
        voiceId: json['voice_id'] as String,
        speed: (json['speed'] as num).toDouble(),
        currentChunkIndex: json['current_chunk_index'] as int,
        positionMs: json['position_ms'] as int,
      );
}
