import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';

/// Audio service with prefetch support for near-instant voice/section switching.
///
/// Strategy:
/// 1. Prefetch next chunk while current one plays
/// 2. Pre-synthesize on voice change before play
/// 3. Show synthesizing indicator during downloads
class AudioService {
  final AudioPlayer _player = AudioPlayer();

  /// Broadcast stream for synthesizing state (true = downloading/synthesizing).
  final StreamController<bool> _synthesizingController =
      StreamController<bool>.broadcast();

  /// Local file cache: "chunkId_voiceId" -> local file path.
  final Map<String, String> _fileCache = {};

  /// In-flight prefetch futures to avoid duplicate downloads.
  final Map<String, Future<String?>> _inflight = {};

  AudioPlayer get player => _player;
  Stream<bool> get synthesizingStream => _synthesizingController.stream;

  /// Get temp file path for a chunk+voice combo.
  Future<String> _tempPath(String chunkId, String voiceId) async {
    final tempDir = await getTemporaryDirectory();
    return '${tempDir.path}/psitta_${chunkId}_$voiceId.mp3';
  }

  /// Build API URL for a chunk's audio.
  String _audioUrl(String documentId, String chunkId, String voiceId) =>
      '${AppConstants.apiBaseUrl}/documents/$documentId/chunks/$chunkId/audio?voice_id=$voiceId';

  /// Download audio bytes from backend (triggers on-demand synthesis).
  Future<String?> _downloadToFile(
    String documentId,
    String chunkId,
    String voiceId,
  ) async {
    final cacheKey = '${chunkId}_$voiceId';

    // Already cached on disk?
    if (_fileCache.containsKey(cacheKey)) {
      final f = File(_fileCache[cacheKey]!);
      if (await f.exists()) return _fileCache[cacheKey];
    }

    final url = _audioUrl(documentId, chunkId, voiceId);
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: AppConstants.httpTimeout,
        receiveTimeout: const Duration(seconds: 90),
        responseType: ResponseType.bytes,
      ));
      final response = await dio.get<List<int>>(url);
      if (response.statusCode != 200 || response.data == null) return null;

      final path = await _tempPath(chunkId, voiceId);
      await File(path).writeAsBytes(response.data!);
      _fileCache[cacheKey] = path;
      print('Downloaded: $cacheKey (${response.data!.length} bytes)');
      return path;
    } catch (e) {
      print('Download failed ($cacheKey): $e');
      return null;
    }
  }

  /// Prefetch audio for a chunk without playing it.
  /// Safe to call multiple times — deduplicates in-flight requests.
  Future<String?> prefetchChunk({
    required String documentId,
    required String chunkId,
    String voiceId = '21m00Tcm4TlvDq8ikWAM',
  }) {
    final cacheKey = '${chunkId}_$voiceId';

    // Already in-flight? Return existing future.
    if (_inflight.containsKey(cacheKey)) {
      return _inflight[cacheKey]!;
    }

    // Already cached?
    if (_fileCache.containsKey(cacheKey)) {
      return Future.value(_fileCache[cacheKey]);
    }

    final future = _downloadToFile(documentId, chunkId, voiceId).whenComplete(
      () => _inflight.remove(cacheKey),
    );
    _inflight[cacheKey] = future;
    return future;
  }

  /// Play audio for a chunk. Uses local cache if available (instant).
  /// If not cached, shows synthesizing state while downloading.
  Future<bool> playChunk({
    required String documentId,
    required String chunkId,
    String voiceId = '21m00Tcm4TlvDq8ikWAM',
  }) async {
    try {
      // Stop current playback immediately
      try {
        await _player.stop();
      } catch (_) {}

      final cacheKey = '${chunkId}_$voiceId';
      String? filePath = _fileCache[cacheKey];

      // Check if cached file still exists on disk
      if (filePath != null && await File(filePath).exists()) {
        // Instant play from cache — no synthesizing indicator
        await _player.setFilePath(filePath);
        await _player.play();
        return true;
      }

      // Not cached — show synthesizing indicator
      _synthesizingController.add(true);

      // Check if there's an in-flight prefetch we can wait on
      if (_inflight.containsKey(cacheKey)) {
        filePath = await _inflight[cacheKey];
      } else {
        filePath = await _downloadToFile(documentId, chunkId, voiceId);
      }

      _synthesizingController.add(false);

      if (filePath == null || !await File(filePath).exists()) {
        print('Audio download failed for $cacheKey');
        return false;
      }

      // Play from local file
      await _player.setFilePath(filePath);
      await _player.play();
      return true;
    } catch (e) {
      _synthesizingController.add(false);
      print('Audio not available: $e');
      try {
        await _player.stop();
      } catch (_) {}
      return false;
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
    _synthesizingController.close();
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
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

/// Stream provider for synthesizing state.
final isSynthesizingProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(audioServiceProvider);
  return service.synthesizingStream;
});
