import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';

/// Audio service wrapping just_audio for document narration playback.
class AudioService {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;

  /// Load and play audio for a specific chunk.
  Future<void> playChunk({
    required String documentId,
    required String chunkId,
    String voiceId = '21m00Tcm4TlvDq8ikWAM',
  }) async {
    final url =
        '${AppConstants.apiBaseUrl}/documents/$documentId/chunks/$chunkId/audio?voice_id=$voiceId';
    try {
      await _player.setUrl(url);
      await _player.play();
    } catch (e) {
      // Audio not yet synthesized — fail silently
      print('Audio not available: $e');
    }
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Future<void> stop() async {
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }

  /// Stream of current playback position.
  Stream<Duration> get positionStream => _player.positionStream;

  /// Stream of total duration.
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Stream of playing state.
  Stream<bool> get playingStream => _player.playingStream;

  /// Stream of player state (for completion detection).
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// Current playing state.
  bool get isPlaying => _player.playing;

  /// Current position.
  Duration get position => _player.position;

  /// Current duration.
  Duration? get duration => _player.duration;
}

/// Singleton audio service provider.
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream provider for playback position.
final audioPositionProvider = StreamProvider<Duration>((ref) {
  final service = ref.watch(audioServiceProvider);
  return service.positionStream;
});

/// Stream provider for duration.
final audioDurationProvider = StreamProvider<Duration?>((ref) {
  final service = ref.watch(audioServiceProvider);
  return service.durationStream;
});

/// Stream provider for playing state.
final audioPlayingProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(audioServiceProvider);
  return service.playingStream;
});

/// Stream provider for player state (completion detection).
final audioPlayerStateProvider = StreamProvider<PlayerState>((ref) {
  final service = ref.watch(audioServiceProvider);
  return service.playerStateStream;
});
