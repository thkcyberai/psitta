import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';
import '../repositories/playback_repository.dart';

/// Audio service with prefetch support for near-instant voice/section switching.
///
/// Stability goals:
/// - Never leave synthesizing=true if a request is superseded or fails.
/// - Avoid race conditions when switching chunks quickly.
/// - Ensure only the latest play request may mutate player state.
///
/// Strategy:
/// - Use a monotonic request token to cancel superseded operations.
/// - Guard all state transitions (set source/play/synth indicator) by token.
class AudioService {
  final AudioPlayer _player = AudioPlayer();

  /// Broadcast stream for synthesizing state (true = downloading/synthesizing).
  final StreamController<bool> _synthesizingController =
      StreamController<bool>.broadcast();

  /// Local file cache: "chunkId_voiceId" -> local file path.
  final Map<String, String> _fileCache = {};

  /// In-flight prefetch futures to avoid duplicate downloads.
  final Map<String, Future<String?>> _inflight = {};

  int _requestSeq = 0;

  AudioPlayer get player => _player;
  Stream<bool> get synthesizingStream => _synthesizingController.stream;

  int _nextToken() => ++_requestSeq;

  bool _isLatest(int token) => token == _requestSeq;

  Future<String> _tempPath(String chunkId, String voiceId) async {
    final tempDir = await getTemporaryDirectory();
    return '${tempDir.path}/psitta_${chunkId}_$voiceId.mp3';
  }

  String _audioUrl(String documentId, String chunkId, String voiceId) =>
      '${AppConstants.apiBaseUrl}/documents/$documentId/chunks/$chunkId/audio?voice_id=$voiceId';

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
      final dio = Dio(
        BaseOptions(
          connectTimeout: AppConstants.httpTimeout,
          receiveTimeout: const Duration(seconds: 90),
          responseType: ResponseType.bytes,
        ),
      );
      final response = await dio.get<List<int>>(url);
      if (response.statusCode != 200 || response.data == null) return null;

      final path = await _tempPath(chunkId, voiceId);
      await File(path).writeAsBytes(response.data!);
      _fileCache[cacheKey] = path;
      // ignore: avoid_print
      print('Downloaded: $cacheKey (${response.data!.length} bytes)');
      return path;
    } catch (e) {
      // ignore: avoid_print
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

    if (_inflight.containsKey(cacheKey)) {
      return _inflight[cacheKey]!;
    }

    if (_fileCache.containsKey(cacheKey)) {
      return Future.value(_fileCache[cacheKey]);
    }

    final future = _downloadToFile(documentId, chunkId, voiceId).whenComplete(
      () => _inflight.remove(cacheKey),
    );
    _inflight[cacheKey] = future;
    return future;
  }

  /// Play audio for a chunk.
  /// Token-based cancellation ensures rapid switching cannot wedge UI state.
  Future<bool> playChunk({
    required String documentId,
    required String chunkId,
    String voiceId = '21m00Tcm4TlvDq8ikWAM',
    double speed = 1.0,
    double volume = 1.0,
  }) async {
    final token = _nextToken();
    final cacheKey = '${chunkId}_$voiceId';

    // Switching chunks should stop current playback immediately.
    try {
      await _player.stop();
    } catch (_) {}

    bool synthesizingSet = false;

    try {
      // 1) Cache hit: play immediately.
      final cachedPath = _fileCache[cacheKey];
      if (cachedPath != null && await File(cachedPath).exists()) {
        if (!_isLatest(token)) return false;

        await _player.setFilePath(cachedPath);
        await _player.setSpeed(speed);
        await _player.setVolume(volume);

        // ignore: avoid_print
        print(
            'playChunk: speed=$speed playerSpeed=${_player.speed} cacheHit=true');

        if (!_isLatest(token)) return false;
        await _player.play();
        return true;
      }

      // 2) Not cached: show synthesizing + download (or await inflight).
      _synthesizingController.add(true);
      synthesizingSet = true;

      String? filePath;
      if (_inflight.containsKey(cacheKey)) {
        filePath = await _inflight[cacheKey];
      } else {
        filePath = await _downloadToFile(documentId, chunkId, voiceId);
      }

      if (!_isLatest(token)) return false;

      if (filePath == null || !await File(filePath).exists()) {
        // ignore: avoid_print
        print('Audio download failed for $cacheKey');
        return false;
      }

      await _player.setFilePath(filePath);
      await _player.setSpeed(speed);
      await _player.setVolume(volume);

      // ignore: avoid_print
      print(
          'playChunk: speed=$speed playerSpeed=${_player.speed} cacheHit=false');

      if (!_isLatest(token)) return false;
      await _player.play();
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Audio not available: $e');
      try {
        await _player.stop();
      } catch (_) {}
      return false;
    } finally {
      // Only the latest request may clear the synthesizing indicator.
      if (_isLatest(token)) {
        _synthesizingController.add(false);
      } else {
        // If we set it but got superseded, let the latest request own the indicator.
        if (synthesizingSet) {
          // no-op by design
        }
      }
    }
  }

  /// Load a chunk into the player without starting playback.
  ///
  /// Used when the user intentionally jumps to a new reading position while
  /// paused. This preserves the expected "pending start point" behavior.
  Future<bool> prepareChunk({
    required String documentId,
    required String chunkId,
    String voiceId = '21m00Tcm4TlvDq8ikWAM',
    double speed = 1.0,
    double volume = 1.0,
  }) async {
    final token = _nextToken();
    final cacheKey = '${chunkId}_$voiceId';

    try {
      await _player.stop();
    } catch (_) {}

    _synthesizingController.add(true);

    try {
      final cachedPath = _fileCache[cacheKey];
      if (cachedPath != null && await File(cachedPath).exists()) {
        if (!_isLatest(token)) return false;
        await _player.setFilePath(cachedPath);
        await _player.setSpeed(speed);
        await _player.setVolume(volume);
        return true;
      }

      String? filePath;
      if (_inflight.containsKey(cacheKey)) {
        filePath = await _inflight[cacheKey];
      } else {
        filePath = await _downloadToFile(documentId, chunkId, voiceId);
      }

      if (!_isLatest(token)) return false;
      if (filePath == null || !await File(filePath).exists()) return false;

      await _player.setFilePath(filePath);
      await _player.setSpeed(speed);
      await _player.setVolume(volume);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Prepare chunk failed ($cacheKey): $e');
      try {
        await _player.stop();
      } catch (_) {}
      return false;
    } finally {
      if (_isLatest(token)) {
        _synthesizingController.add(false);
      }
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
    _nextToken(); // invalidate any in-flight play/download UI ownership
    await _player.stop();
    _synthesizingController.add(false);
  }

  /// Full reset — stops playback and clears player state.
  /// Use when switching voices or documents so next play loads fresh audio.
  Future<void> reset() async {
    _nextToken(); // invalidate in-flight work
    try {
      await _player.stop();
      await _player.seek(Duration.zero);
    } catch (_) {}
    _synthesizingController.add(false);
  }

  /// Removes a chunk from the in-memory cache and deletes its local temp file.
  /// Call after a chunk has been re-synthesized so next play fetches fresh audio.
  Future<void> invalidateChunkCache(String chunkId) async {
    _fileCache.removeWhere((key, _) => key.startsWith(chunkId));
    _inflight.removeWhere((key, _) => key.startsWith(chunkId));

    try {
      final tmpDir = await getTemporaryDirectory();
      final dir = Directory(tmpDir.path);
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => path.basename(f.path).startsWith('psitta_$chunkId'));
      for (final file in files) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort — in-memory eviction is enough
    }
  }

  /// Invalidates cache for a chunk then immediately re-downloads fresh audio.
  /// Call after re-synthesis to guarantee player gets updated audio.
  Future<void> forceReloadChunk({
    required String documentId,
    required String chunkId,
    required String voiceId,
  }) async {
    // 1. Stop player and clear its source so it releases the old file handle.
    try {
      await _player.stop();
      await _player.setAudioSource(AudioSource.uri(Uri.dataFromString('')));
    } catch (_) {}

    // 2. Clear specific cache key first
    final cacheKey = '${chunkId}_$voiceId';
    _fileCache.remove(cacheKey);
    unawaited(_inflight.remove(cacheKey));

    // 3. Delete temp file directly
    try {
      final tmpDir = await getTemporaryDirectory();
      final filePath = '${tmpDir.path}/psitta_${chunkId}_$voiceId.mp3';
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}

    // 4. Also run full invalidation for any other voice variants
    await invalidateChunkCache(chunkId);

    // 5. Now prefetch fresh audio
    await prefetchChunk(
      documentId: documentId,
      chunkId: chunkId,
      voiceId: voiceId,
    );
  }

  // Position Tracking
  Timer? _positionTimer;
  String? _activeSessionId;
  int _activeChunkIndex = 0;
  PlaybackRepository? _playbackRepo;

  void startPositionTracking({
    required String sessionId,
    required int chunkIndex,
    required PlaybackRepository repository,
  }) {
    _activeSessionId = sessionId;
    _activeChunkIndex = chunkIndex;
    _playbackRepo = repository;
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _persistPosition();
    });
  }

  void updateTrackingChunk(int chunkIndex) {
    _activeChunkIndex = chunkIndex;
  }

  void stopPositionTracking() {
    _positionTimer?.cancel();
    _positionTimer = null;
    _persistPosition();
  }

  void _persistPosition() {
    final sessionId = _activeSessionId;
    final repo = _playbackRepo;
    if (sessionId == null || repo == null) return;
    if (!_player.playing && _player.position == Duration.zero) return;
    repo
        .updatePosition(
      sessionId: sessionId,
      chunkIndex: _activeChunkIndex,
      positionMs: _player.position.inMilliseconds,
    )
        .catchError((Object e) {
      debugPrint('Position save failed: $e');
    });
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
