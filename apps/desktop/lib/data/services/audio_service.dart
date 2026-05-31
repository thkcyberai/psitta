import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../api/api_client.dart';
import '../providers/providers.dart';
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
  AudioService(this._api);

  /// Shared HTTP client with the Cognito auth interceptor (Bearer token
  /// injection + one-shot 401 refresh+retry + onUnauthorized escalation).
  /// Audio fetch routes through here so the audio endpoint authenticates
  /// the same way every other API call does.
  final ApiClient _api;

  final AudioPlayer _player = AudioPlayer();

  // Tuned position stream for SWH word-highlight sync. just_audio's default
  // positionStream clamps emits to ~200ms for chunks longer than ~160s, which
  // is the visible-lag floor on Psitta's typical 250s+ chunks. Pinning
  // min==max==33ms gives ~30fps emits regardless of chunk length. Seek
  // immediacy is preserved natively via createPositionStream's playbackEvent
  // listener (just_audio 0.9.46 lib/just_audio.dart:674).
  late final Stream<Duration> _positionStream = _player.createPositionStream(
    steps: 10000,
    minPeriod: const Duration(milliseconds: 33),
    maxPeriod: const Duration(milliseconds: 33),
  );

  /// Broadcast stream for synthesizing state (true = downloading/synthesizing).
  final StreamController<bool> _synthesizingController =
      StreamController<bool>.broadcast();

  /// Local file cache: "chunkId_voiceId" -> local file path.
  final Map<String, String> _fileCache = {};

  /// In-flight prefetch futures to avoid duplicate downloads.
  final Map<String, Future<String?>> _inflight = {};
  String? _loadedDocumentId;
  String? _loadedChunkId;
  String? _loadedVoiceId;

  int _requestSeq = 0;

  AudioPlayer get player => _player;
  Stream<bool> get synthesizingStream => _synthesizingController.stream;

  int _nextToken() => ++_requestSeq;

  bool _isLatest(int token) => token == _requestSeq;

  void _logPdfPerf(String stage, String message) {
    debugPrint('[PDF PERF][$stage] $message');
  }

  bool hasPreparedChunk({
    required String documentId,
    required String chunkId,
    required String voiceId,
  }) {
    return _loadedDocumentId == documentId &&
        _loadedChunkId == chunkId &&
        _loadedVoiceId == voiceId &&
        _player.audioSource != null;
  }

  void _markLoadedSource({
    required String documentId,
    required String chunkId,
    required String voiceId,
  }) {
    _loadedDocumentId = documentId;
    _loadedChunkId = chunkId;
    _loadedVoiceId = voiceId;
  }

  void _clearLoadedSource() {
    _loadedDocumentId = null;
    _loadedChunkId = null;
    _loadedVoiceId = null;
  }

  Future<String> _tempPath(String chunkId, String voiceId) async {
    final tempDir = await getTemporaryDirectory();
    return '${tempDir.path}/psitta_${chunkId}_$voiceId.mp3';
  }

  String _audioPath(String documentId, String chunkId, String voiceId) =>
      '/documents/$documentId/chunks/$chunkId/audio?voice_id=$voiceId';

  Future<String?> _downloadToFile(
    String documentId,
    String chunkId,
    String voiceId,
  ) async {
    final cacheKey = '${chunkId}_$voiceId';
    final stopwatch = Stopwatch()..start();

    // Already cached on disk?
    if (_fileCache.containsKey(cacheKey)) {
      final f = File(_fileCache[cacheKey]!);
      if (await f.exists()) {
        stopwatch.stop();
        _logPdfPerf(
          'audio',
          'cache_file_hit doc=$documentId chunk=$chunkId voice=$voiceId elapsed=${stopwatch.elapsedMilliseconds}ms',
        );
        return _fileCache[cacheKey];
      }
    }

    final pathParam = _audioPath(documentId, chunkId, voiceId);
    _logPdfPerf(
      'audio',
      'request_start doc=$documentId chunk=$chunkId voice=$voiceId path=$pathParam',
    );
    try {
      // Route via shared ApiClient so the auth interceptor injects the
      // Cognito Bearer token, handles one-shot 401 refresh+retry, and
      // escalates to onUnauthorized on hard auth failure. TTS synthesis
      // can take 60+ seconds for long chunks, so the receive timeout is
      // overridden per-request.
      final response = await _api.dio.get<List<int>>(
        pathParam,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 90),
        ),
      );
      if (response.statusCode != 200 || response.data == null) return null;

      final path = await _tempPath(chunkId, voiceId);
      await File(path).writeAsBytes(response.data!);
      _fileCache[cacheKey] = path;
      stopwatch.stop();
      _logPdfPerf(
        'audio',
        'request_done doc=$documentId chunk=$chunkId voice=$voiceId status=${response.statusCode} bytes=${response.data!.length} elapsed=${stopwatch.elapsedMilliseconds}ms',
      );
      // ignore: avoid_print
      print('Downloaded: $cacheKey (${response.data!.length} bytes)');
      return path;
    } catch (e) {
      stopwatch.stop();
      _logPdfPerf(
        'audio',
        'request_error doc=$documentId chunk=$chunkId voice=$voiceId elapsed=${stopwatch.elapsedMilliseconds}ms error=$e',
      );
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
    final stopwatch = Stopwatch()..start();
    _logPdfPerf(
      'play',
      'playChunk_start doc=$documentId chunk=$chunkId voice=$voiceId token=$token',
    );

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
        _markLoadedSource(
          documentId: documentId,
          chunkId: chunkId,
          voiceId: voiceId,
        );

        // ignore: avoid_print
        print(
            'playChunk: speed=$speed playerSpeed=${_player.speed} cacheHit=true');

        if (!_isLatest(token)) return false;
        await _player.play();
        stopwatch.stop();
        _logPdfPerf(
          'play',
          'playChunk_started doc=$documentId chunk=$chunkId voice=$voiceId cache=hit elapsed=${stopwatch.elapsedMilliseconds}ms',
        );
        return true;
      }

      // 2) Not cached: show synthesizing + download (or await inflight).
      _synthesizingController.add(true);
      synthesizingSet = true;
      _logPdfPerf(
        'play',
        'playChunk_prepare_remote doc=$documentId chunk=$chunkId voice=$voiceId inflight=${_inflight.containsKey(cacheKey)}',
      );

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
      _markLoadedSource(
        documentId: documentId,
        chunkId: chunkId,
        voiceId: voiceId,
      );

      // ignore: avoid_print
      print(
          'playChunk: speed=$speed playerSpeed=${_player.speed} cacheHit=false');

      if (!_isLatest(token)) return false;
      await _player.play();
      stopwatch.stop();
      _logPdfPerf(
        'play',
        'playChunk_started doc=$documentId chunk=$chunkId voice=$voiceId cache=miss elapsed=${stopwatch.elapsedMilliseconds}ms',
      );
      return true;
    } catch (e) {
      stopwatch.stop();
      _logPdfPerf(
        'play',
        'playChunk_error doc=$documentId chunk=$chunkId voice=$voiceId elapsed=${stopwatch.elapsedMilliseconds}ms error=$e',
      );
      // ignore: avoid_print
      print('Audio not available: $e');
      try {
        await _player.stop();
      } catch (_) {}
      _clearLoadedSource();
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
    final stopwatch = Stopwatch()..start();
    _logPdfPerf(
      'play',
      'prepareChunk_start doc=$documentId chunk=$chunkId voice=$voiceId token=$token',
    );

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
        _markLoadedSource(
          documentId: documentId,
          chunkId: chunkId,
          voiceId: voiceId,
        );
        stopwatch.stop();
        _logPdfPerf(
          'play',
          'prepareChunk_ready doc=$documentId chunk=$chunkId voice=$voiceId cache=hit elapsed=${stopwatch.elapsedMilliseconds}ms',
        );
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
      _markLoadedSource(
        documentId: documentId,
        chunkId: chunkId,
        voiceId: voiceId,
      );
      stopwatch.stop();
      _logPdfPerf(
        'play',
        'prepareChunk_ready doc=$documentId chunk=$chunkId voice=$voiceId cache=miss elapsed=${stopwatch.elapsedMilliseconds}ms',
      );
      return true;
    } catch (e) {
      stopwatch.stop();
      _logPdfPerf(
        'play',
        'prepareChunk_error doc=$documentId chunk=$chunkId voice=$voiceId elapsed=${stopwatch.elapsedMilliseconds}ms error=$e',
      );
      // ignore: avoid_print
      print('Prepare chunk failed ($cacheKey): $e');
      try {
        await _player.stop();
      } catch (_) {}
      _clearLoadedSource();
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
    _clearLoadedSource();
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
    _clearLoadedSource();
  }

  /// User-switch reset: stops playback, zeroes position, and wipes
  /// the in-memory and on-disk audio caches so a different user cannot
  /// see or hear the previous user's data. Position tracking is cancelled
  /// WITHOUT a final persist flush — the previous session's token is
  /// already revoked by the time this runs, so a flush would 401.
  Future<void> clearUserSession() async {
    _nextToken();
    try {
      await _player.stop();
      await _player.seek(Duration.zero);
    } catch (_) {}
    _synthesizingController.add(false);
    _clearLoadedSource();

    _positionTimer?.cancel();
    _positionTimer = null;
    _activeSessionId = null;
    _activeChunkIndex = 0;
    _playbackRepo = null;

    _fileCache.clear();
    _inflight.clear();

    try {
      final tmpDir = await getTemporaryDirectory();
      final files = Directory(tmpDir.path)
          .listSync()
          .whereType<File>()
          .where((f) => path.basename(f.path).startsWith('psitta_'));
      for (final file in files) {
        try {
          await file.delete();
        } catch (_) {}
      }
    } catch (_) {
      // Best-effort — OS cleans tmpdir eventually
    }
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
    _clearLoadedSource();

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

  Stream<Duration> get positionStream => _positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
}

/// Singleton audio service provider.
///
/// Injects the shared [ApiClient] so audio fetch carries the Cognito
/// Bearer token via the standard auth interceptor — same path as every
/// other repository in the app.
final audioServiceProvider = Provider<AudioService>((ref) {
  final api = ref.watch(apiClientProvider);
  final service = AudioService(api);
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
