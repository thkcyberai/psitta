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

  String _streamUrl(String documentId, String chunkId, String voiceId) {
    final base = _api.dio.options.baseUrl;
    return '$base/documents/$documentId/chunks/$chunkId/audio/stream'
        '?voice_id=$voiceId';
  }

  /// Streaming playback (Writing Nook): play the chunk from the backend
  /// /audio/stream endpoint so audio begins within ~1s while the rest is still
  /// synthesizing. Falls back to the on-disk cache when present (instant, zero
  /// credit). just_audio's URI source carries the Bearer header directly since
  /// it does not pass through the Dio interceptor. The Reading Nook keeps using
  /// [playChunk]; this method is additive.
  Future<bool> playChunkStreaming({
    required String documentId,
    required String chunkId,
    String voiceId = '21m00Tcm4TlvDq8ikWAM',
    double speed = 1.0,
    double volume = 1.0,
  }) async {
    // Dispatch to the gapless sentence playlist when enabled (instant
    // highlighting). Keeps every existing caller unchanged.
    if (_shouldUseSentencePlaylist(chunkId)) {
      return playChunkSentences(
        documentId: documentId,
        chunkId: chunkId,
        sentenceCount: _sentenceCountFor(chunkId),
        voiceId: voiceId,
        speed: speed,
        volume: volume,
      );
    }
    _sentenceActiveController.add(false);
    final token = _nextToken();
    final cacheKey = '${chunkId}_$voiceId';

    try {
      await _player.stop();
    } catch (_) {}

    // Fast path: a completed cache file exists (e.g. from a prior stream's
    // write-through) → play it directly, no streaming round-trip.
    final cachedPath = _fileCache[cacheKey];
    if (cachedPath != null && await File(cachedPath).exists()) {
      try {
        await _player.setFilePath(cachedPath);
        if (!_isLatest(token)) return false;
        await _player.setSpeed(speed);
        await _player.setVolume(volume);
        _markLoadedSource(
            documentId: documentId, chunkId: chunkId, voiceId: voiceId);
        await _player.play();
        return true;
      } catch (_) {
        // Fall through to streaming on any cache-playback error.
      }
    }

    _synthesizingController.add(true);
    try {
      final auth = await _api.accessToken();
      final headers = <String, String>{
        if (auth != null && auth.isNotEmpty) 'Authorization': 'Bearer $auth',
      };
      final source = AudioSource.uri(
        Uri.parse(_streamUrl(documentId, chunkId, voiceId)),
        headers: headers,
      );
      await _player.setAudioSource(source);
      if (!_isLatest(token)) {
        _synthesizingController.add(false);
        return false;
      }
      await _player.setSpeed(speed);
      await _player.setVolume(volume);
      _markLoadedSource(
          documentId: documentId, chunkId: chunkId, voiceId: voiceId);
      _synthesizingController.add(false);
      await _player.play();
      return true;
    } catch (e) {
      debugPrint('[AudioService] streaming play failed: $e');
      _synthesizingController.add(false);
      return false;
    }
  }

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
    if (_shouldUseSentencePlaylist(chunkId)) {
      return playChunkSentences(
        documentId: documentId,
        chunkId: chunkId,
        sentenceCount: _sentenceCountFor(chunkId),
        voiceId: voiceId,
        speed: speed,
        volume: volume,
      );
    }
    _sentenceActiveController.add(false);
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
    if (_shouldUseSentencePlaylist(chunkId)) {
      return playChunkSentences(
        documentId: documentId,
        chunkId: chunkId,
        sentenceCount: _sentenceCountFor(chunkId),
        voiceId: voiceId,
        speed: speed,
        volume: volume,
        autoplay: false,
      );
    }
    _sentenceActiveController.add(false);
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
    await _teardownPlaylistSubs();
    _clearPlaylistState();
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
    await _teardownPlaylistSubs();
    _clearPlaylistState();
  }

  /// Change narrator (voice) WITHOUT losing the reading position.
  ///
  /// When a sentence playlist is active, capture the current sentence + speed /
  /// volume / playing state, then relaunch the SAME chunk with the new voice
  /// starting at that sentence. The new voice's audio is a fresh synthesis, so
  /// the first sentence takes ~1–2s — but the reader resumes where they were
  /// instead of restarting from the top or skipping ahead. Falls back to a
  /// plain reset when no sentence playlist is active (single-file path).
  Future<void> changeVoicePreservingPosition(String newVoiceId) async {
    final doc = _playlistDocumentId;
    final chunk = _playlistChunkId;
    final count = _playlistSentenceCount;
    if (doc == null || chunk == null || count <= 0) {
      await reset();
      return;
    }
    final sentenceIdx = currentSentenceIndex; // authoritative (stream-tracked)
    final wasPlaying = _player.playing;
    final speed = _player.speed;
    final volume = _player.volume;
    await playChunkSentences(
      documentId: doc,
      chunkId: chunk,
      sentenceCount: count,
      voiceId: newVoiceId,
      speed: speed,
      volume: volume,
      initialSentence: sentenceIdx,
      autoplay: wasPlaying,
    );
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
    await _teardownPlaylistSubs();
    _clearPlaylistState();

    _positionTimer?.cancel();
    _positionTimer = null;
    _activeSessionId = null;
    _activeChunkIndex = 0;
    _playbackRepo = null;

    _fileCache.clear();
    _inflight.clear();
    _resumeSentenceByChunk.clear();

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

  // ───────────────────────────────────────────────────────────────────────
  // Sentence-playlist playback (instant word highlighting).
  //
  // Instead of one whole-chunk audio source, play the chunk as a gapless
  // ConcatenatingAudioSource of per-sentence clips. Each clip's audio and its
  // word timings come from ONE server-side synthesis (the /sentences/{i}/audio
  // endpoint), so the first sentence — and therefore the first highlight —
  // lands in ~1s while the rest of the chunk pipelines behind it.
  //
  // just_audio reports position/duration RELATIVE TO THE CURRENT ITEM for a
  // ConcatenatingAudioSource, and the active item via currentIndexStream. The
  // highlighter wants exactly that (sentence index + in-sentence ms). The
  // toolbar/seek want a CHUNK-level timeline, so we maintain a cumulative
  // per-sentence duration table and expose chapterPosition/chapterDuration on
  // top of the playlist. Everything here is additive; the single-file
  // playChunk / playChunkStreaming paths are untouched and remain the default.
  // ───────────────────────────────────────────────────────────────────────

  /// Known duration of each sentence clip in the active playlist, filled in as
  /// just_audio prepares/plays each item. `Duration.zero` == not yet known.
  List<Duration> _sentenceDurations = const [];
  String? _playlistDocumentId;
  String? _playlistChunkId;
  String? _playlistVoiceId;

  final StreamController<int> _sentenceIndexController =
      StreamController<int>.broadcast();
  final StreamController<Duration> _chapterPositionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _chapterDurationController =
      StreamController<Duration?>.broadcast();

  StreamSubscription<int?>? _plIndexSub;
  StreamSubscription<Duration>? _plPositionSub;
  StreamSubscription<Duration?>? _plDurationSub;

  // ── Playlist resilience ──────────────────────────────────────────────
  // A per-sentence clip can fail or stall to load (bad synthesis, timeout,
  // just_audio_windows hiccup). Unguarded, that ends the playlist early and the
  // toolbar's ProcessingState.completed listener treats it as "chapter
  // finished" → jumps to the next chunk (the "page 2 sentence 1" bug), or the
  // player wedges (the multi-minute hang). These guard that:
  //   • only signal chunk-complete when the LAST sentence really finished;
  //   • on a premature completion, skip to the next sentence instead;
  //   • a watchdog skips a clip stuck loading > _kStallSeconds;
  //   • recoveries are capped so a run of bad clips ends the chunk cleanly.
  int _playlistSentenceCount = 0;
  int _chunkCompleteSeq = 0;
  final StreamController<int> _chunkCompletedController =
      StreamController<int>.broadcast();
  StreamSubscription<PlayerState>? _plStateSub;
  Timer? _plWatchdog;
  DateTime _plLastProgressAt = DateTime.now();
  int _plLastIndex = 0;
  Duration _plLastPos = Duration.zero;
  int _plRecoveries = 0;
  static const int _kStallSeconds = 8;
  static const int _kMaxRecoveries = 3;

  /// The authoritative current sentence index, tracked from the currentIndex
  /// STREAM (reliable) rather than the player's synchronous currentIndex getter
  /// (which can read 0 right after a relaunch). Used to capture position on a
  /// voice change so a second change doesn't drop to the top.
  int _liveSentenceIdx = 0;

  /// Last sentence index actually reached, per chunk id. Lets pressing Play —
  /// after a voice change or leaving/returning to the reader — RESUME where the
  /// reader left off instead of restarting at sentence 0. Survives reset() and
  /// navigation; cleared on genuine chunk completion and on user switch.
  final Map<String, int> _resumeSentenceByChunk = {};

  /// Emits an incrementing token when the active sentence playlist genuinely
  /// finishes its LAST sentence (so the toolbar can advance to the next
  /// chapter). Does NOT emit on a mid-playlist clip failure — those are
  /// recovered by skipping ahead. The token increments so each end-of-chunk is
  /// a distinct event the listener won't dedupe.
  Stream<int> get chunkCompletedStream => _chunkCompletedController.stream;

  /// Whether the sentence-playlist path is enabled, and the sentence count per
  /// chunk id (from the chunk's sentence_boundaries). Set by the player screen
  /// via [setSentencePlan] when the flag is on. When enabled, the ordinary
  /// playChunk / playChunkStreaming / prepareChunk entry points transparently
  /// dispatch to [playChunkSentences] — so every existing call site gets
  /// instant highlighting without changing any of them.
  bool _sentenceModeEnabled = false;
  Map<String, int> _sentenceCounts = const {};

  /// Emits true when a sentence playlist becomes the active source, false when
  /// single-file playback is active or playback stops. The toolbar watches this
  /// to switch its scrubber between the chapter model and the plain player.
  final StreamController<bool> _sentenceActiveController =
      StreamController<bool>.broadcast();
  Stream<bool> get sentencePlaylistActiveStream =>
      _sentenceActiveController.stream;

  /// Configure the sentence-playlist dispatch. [counts] maps chunkId → number
  /// of sentences (chunk.sentence_boundaries.length).
  void setSentencePlan({required bool enabled, required Map<String, int> counts}) {
    _sentenceModeEnabled = enabled;
    _sentenceCounts = counts;
  }

  int _sentenceCountFor(String chunkId) => _sentenceCounts[chunkId] ?? 0;

  bool _shouldUseSentencePlaylist(String chunkId) =>
      _sentenceModeEnabled && _sentenceCountFor(chunkId) > 0;

  /// Active sentence index within the current chunk playlist (0-based).
  Stream<int> get sentenceIndexStream => _sentenceIndexController.stream;

  /// Chunk-level ("chapter") playback position, summed across sentence clips,
  /// so the toolbar scrubber reads as one continuous timeline.
  Stream<Duration> get chapterPositionStream =>
      _chapterPositionController.stream;

  /// Chunk-level total duration (sum of known sentence-clip durations). Grows
  /// as clips are prepared; becomes exact once every clip has been loaded.
  Stream<Duration?> get chapterDurationStream =>
      _chapterDurationController.stream;

  bool get hasSentencePlaylist => _playlistChunkId != null;

  int get currentSentenceIndex => _liveSentenceIdx;

  Duration _cumulativeBefore(int index) {
    var total = Duration.zero;
    final n = _sentenceDurations.length;
    for (var i = 0; i < index && i < n; i++) {
      total += _sentenceDurations[i];
    }
    return total;
  }

  Duration _knownChapterDuration() {
    var total = Duration.zero;
    for (final d in _sentenceDurations) {
      total += d;
    }
    return total;
  }

  void _emitChapterPosition() {
    final idx = _player.currentIndex ?? 0;
    _chapterPositionController.add(_cumulativeBefore(idx) + _player.position);
  }

  String _sentenceAudioUrl(
    String documentId,
    String chunkId,
    int sentenceIndex,
    String voiceId,
  ) {
    final base = _api.dio.options.baseUrl;
    return '$base/documents/$documentId/chunks/$chunkId'
        '/sentences/$sentenceIndex/audio?voice_id=$voiceId';
  }

  Future<void> _teardownPlaylistSubs() async {
    await _plIndexSub?.cancel();
    await _plPositionSub?.cancel();
    await _plDurationSub?.cancel();
    await _plStateSub?.cancel();
    _plWatchdog?.cancel();
    _plIndexSub = null;
    _plPositionSub = null;
    _plDurationSub = null;
    _plStateSub = null;
    _plWatchdog = null;
  }

  void _clearPlaylistState() {
    _playlistDocumentId = null;
    _playlistChunkId = null;
    _playlistVoiceId = null;
    _sentenceDurations = const [];
    _liveSentenceIdx = 0;
    if (!_sentenceActiveController.isClosed) {
      _sentenceActiveController.add(false);
    }
  }

  /// Play a chunk as a gapless per-sentence playlist. Additive: callers opt in
  /// (behind the sentence-highlight flag); the single-file paths are unchanged.
  ///
  /// [sentenceCount] is the number of entries in the chunk's
  /// `sentence_boundaries` (already delivered by GET /chunks). The backend
  /// slices sentence [i] from the identical boundaries, so index [i] here and
  /// server-side refer to the same span.
  Future<bool> playChunkSentences({
    required String documentId,
    required String chunkId,
    required int sentenceCount,
    String voiceId = '21m00Tcm4TlvDq8ikWAM',
    double speed = 1.0,
    double volume = 1.0,
    int initialSentence = 0,
    bool autoplay = true,
  }) async {
    if (sentenceCount <= 0) return false;
    final token = _nextToken();
    // ignore: avoid_print
    print('[SSP] sentence playlist ENGAGED chunk=$chunkId '
        'sentences=$sentenceCount voice=$voiceId');

    try {
      await _player.stop();
    } catch (_) {}
    await _teardownPlaylistSubs();

    _synthesizingController.add(true);
    try {
      final auth = await _api.accessToken();
      final headers = <String, String>{
        if (auth != null && auth.isNotEmpty) 'Authorization': 'Bearer $auth',
      };

      final children = <AudioSource>[
        for (var i = 0; i < sentenceCount; i++)
          AudioSource.uri(
            Uri.parse(_sentenceAudioUrl(documentId, chunkId, i, voiceId)),
            headers: headers,
          ),
      ];

      final playlist = ConcatenatingAudioSource(
        // Lazy preparation: prepare items just-in-time so the first sentence
        // starts fast instead of blocking on the whole chunk. just_audio
        // preloads the upcoming item to keep transitions gapless.
        useLazyPreparation: true,
        children: children,
      );

      _sentenceDurations =
          List<Duration>.filled(sentenceCount, Duration.zero, growable: false);
      _playlistDocumentId = documentId;
      _playlistChunkId = chunkId;
      _playlistVoiceId = voiceId;
      _playlistSentenceCount = sentenceCount;

      // Resume where the reader left off: if the caller didn't request a
      // specific sentence (initialSentence == 0) but we remember a position for
      // this chunk, resume from there instead of restarting at the top.
      var effectiveInitial = initialSentence;
      if (initialSentence == 0) {
        final saved = _resumeSentenceByChunk[chunkId] ?? 0;
        if (saved > 0 && saved < sentenceCount) effectiveInitial = saved;
      }
      _liveSentenceIdx = effectiveInitial.clamp(0, sentenceCount - 1);

      await _player.setAudioSource(
        playlist,
        initialIndex: effectiveInitial.clamp(0, sentenceCount - 1),
        initialPosition: Duration.zero,
      );
      if (!_isLatest(token)) {
        _synthesizingController.add(false);
        return false;
      }
      await _player.setSpeed(speed);
      await _player.setVolume(volume);

      // Wire the chapter/sentence model. currentIndex → sentence index +
      // recompute chapter position; per-item duration fills the table so the
      // cumulative timeline sharpens as clips load; position → chapter position.
      _plIndexSub = _player.currentIndexStream.listen((idx) {
        if (idx == null) return;
        _liveSentenceIdx = idx; // authoritative current sentence
        _sentenceIndexController.add(idx);
        _emitChapterPosition();
        // Remember how far we've read so Play resumes here after a voice change
        // or leaving/returning to the reader.
        final ch = _playlistChunkId;
        if (ch != null) _resumeSentenceByChunk[ch] = idx;
      });
      _plDurationSub = _player.durationStream.listen((d) {
        final idx = _player.currentIndex ?? 0;
        if (d != null && idx >= 0 && idx < _sentenceDurations.length) {
          _sentenceDurations[idx] = d;
          _chapterDurationController.add(_knownChapterDuration());
        }
      });
      // Use just_audio's built-in (broadcast) positionStream here — the tuned
      // _positionStream is single-subscription and already owned by
      // audioPositionProvider. Coarser cadence is fine for the scrubber; the
      // highlighter keeps the tuned stream for smooth in-sentence sync.
      _plPositionSub = _player.positionStream.listen((_) => _emitChapterPosition());
      // Resilience: catch a failed/premature completion and a stuck clip so a
      // bad sentence never jumps chapters or wedges the player.
      _plStateSub = _player.playerStateStream.listen(_onPlaylistState);
      _startPlaylistWatchdog();

      _markLoadedSource(
          documentId: documentId, chunkId: chunkId, voiceId: voiceId);
      _sentenceIndexController.add(effectiveInitial);
      _sentenceActiveController.add(true);
      _synthesizingController.add(false);
      if (autoplay) await _player.play();
      return true;
    } catch (e) {
      debugPrint('[AudioService] sentence-playlist play failed: $e');
      _synthesizingController.add(false);
      _clearPlaylistState();
      await _teardownPlaylistSubs();
      return false;
    }
  }

  /// Seek within the sentence playlist using a CHUNK-level position. Maps the
  /// chapter ms onto the sentence clip that contains it (via the cumulative
  /// duration table) and seeks to the in-sentence offset. Falls back to a plain
  /// seek when no playlist is active.
  Future<void> seekChapter(Duration chapterPosition) async {
    if (!hasSentencePlaylist || _sentenceDurations.isEmpty) {
      await _player.seek(chapterPosition);
      return;
    }
    var remaining = chapterPosition;
    for (var i = 0; i < _sentenceDurations.length; i++) {
      final d = _sentenceDurations[i];
      // Unknown (zero) durations can't bound a seek; stop here and land at the
      // clip start rather than overshoot.
      if (d == Duration.zero || remaining <= d) {
        await _player.seek(remaining < Duration.zero ? Duration.zero : remaining,
            index: i);
        _emitChapterPosition();
        return;
      }
      remaining -= d;
    }
    await _player.seek(Duration.zero,
        index: _sentenceDurations.length - 1);
    _emitChapterPosition();
  }

  /// Jump the active sentence playlist to a specific sentence (click-to-listen).
  /// No-op when no playlist is active.
  ///
  /// On just_audio_windows a seek to a clip that isn't prepared yet is
  /// sometimes dropped — which is why click-to-jump used to need 2–3 taps. So
  /// we re-issue the seek and confirm the player actually landed on the target
  /// clip, retrying briefly, so a SINGLE click is reliable.
  Future<void> seekToSentence(int index) async {
    if (!hasSentencePlaylist) return;
    final n = _sentenceDurations.length;
    final target = n > 0 ? index.clamp(0, n - 1) : 0;
    final token = _nextToken();

    for (var attempt = 0; attempt < 4; attempt++) {
      if (!_isLatest(token) || !hasSentencePlaylist) return;
      try {
        await _player.seek(Duration.zero, index: target);
      } catch (_) {}
      if (!_player.playing) {
        try {
          await _player.play();
        } catch (_) {}
      }
      // Give the player a beat to switch/prepare the target clip, then confirm.
      await Future.delayed(const Duration(milliseconds: 160));
      if ((_player.currentIndex ?? -1) == target) break;
    }
    if (!_isLatest(token)) return;
    _sentenceIndexController.add(target);
    _emitChapterPosition();
  }

  // React to the player finishing (or a clip failing) during a sentence
  // playlist. Only a genuine end-of-last-sentence advances the chapter.
  void _onPlaylistState(PlayerState s) {
    if (!hasSentencePlaylist) return;
    if (s.processingState != ProcessingState.completed) return;
    final idx = _player.currentIndex ?? 0;
    if (idx >= _playlistSentenceCount - 1) {
      // Chunk finished — drop its resume point so replaying it starts fresh.
      final ch = _playlistChunkId;
      if (ch != null) _resumeSentenceByChunk.remove(ch);
      if (!_chunkCompletedController.isClosed) {
        _chunkCompletedController.add(++_chunkCompleteSeq); // real end of the chunk
      }
    } else {
      // Premature end — a clip failed mid-playlist. Skip to the next sentence
      // rather than let the toolbar jump to the next chapter.
      unawaited(_recoverPlaylist('premature_complete'));
    }
  }

  void _startPlaylistWatchdog() {
    _plWatchdog?.cancel();
    _plLastProgressAt = DateTime.now();
    _plLastIndex = _player.currentIndex ?? 0;
    _plLastPos = _player.position;
    _plRecoveries = 0;
    _plWatchdog = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!hasSentencePlaylist) return;
      final idx = _player.currentIndex ?? 0;
      final pos = _player.position;
      if (idx != _plLastIndex || pos != _plLastPos) {
        _plLastIndex = idx;
        _plLastPos = pos;
        _plLastProgressAt = DateTime.now();
        _plRecoveries = 0;
        return;
      }
      final stalledFor = DateTime.now().difference(_plLastProgressAt).inSeconds;
      final st = _player.processingState;
      final loadingish =
          st == ProcessingState.loading || st == ProcessingState.buffering;
      // Only act on a clip that's trying to play but is stuck loading — never
      // on a legitimate pause or normal in-clip playback.
      if (_player.playing && loadingish && stalledFor >= _kStallSeconds) {
        unawaited(_recoverPlaylist('watchdog_stall'));
      }
    });
  }

  Future<void> _recoverPlaylist(String reason) async {
    if (!hasSentencePlaylist) return;
    final idx = _player.currentIndex ?? 0;
    _plRecoveries++;
    debugPrint('[SSP] recover ($reason) at sentence=$idx '
        'recoveries=$_plRecoveries/$_kMaxRecoveries');
    if (idx >= _playlistSentenceCount - 1 || _plRecoveries > _kMaxRecoveries) {
      // At/near the end, or too many consecutive failures → end the chunk
      // cleanly and let the toolbar move on (no wedge, no silent stall).
      if (!_chunkCompletedController.isClosed) {
        _chunkCompletedController.add(++_chunkCompleteSeq);
      }
      return;
    }
    try {
      await _player.seek(Duration.zero, index: idx + 1);
      _sentenceIndexController.add(idx + 1);
      _plLastProgressAt = DateTime.now();
      if (!_player.playing) await _player.play();
    } catch (_) {
      if (!_chunkCompletedController.isClosed) {
        _chunkCompletedController.add(++_chunkCompleteSeq);
      }
    }
  }

  void dispose() {
    _teardownPlaylistSubs();
    _chunkCompletedController.close();
    _sentenceIndexController.close();
    _chapterPositionController.close();
    _chapterDurationController.close();
    _sentenceActiveController.close();
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

/// Active sentence index within the current chunk's sentence playlist.
/// Only emits while a sentence playlist is active (instant-highlight path).
final activeSentenceIndexProvider = StreamProvider<int>((ref) {
  final service = ref.watch(audioServiceProvider);
  return service.sentenceIndexStream;
});

/// Chunk-level ("chapter") position, summed across sentence clips, for the
/// toolbar scrubber when the sentence playlist is active.
final chapterPositionProvider = StreamProvider<Duration>((ref) {
  final service = ref.watch(audioServiceProvider);
  return service.chapterPositionStream;
});

/// Chunk-level total duration (grows as sentence clips load) for the toolbar.
final chapterDurationProvider = StreamProvider<Duration?>((ref) {
  final service = ref.watch(audioServiceProvider);
  return service.chapterDurationStream;
});

/// True while a sentence playlist is the active audio source. The toolbar reads
/// this to source its scrubber position/duration from the chapter model and to
/// route seeks through [AudioService.seekChapter].
final sentencePlaylistActiveProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(audioServiceProvider);
  return service.sentencePlaylistActiveStream;
});

/// Emits when the active sentence playlist finishes its LAST sentence. The
/// toolbar advances to the next chapter on this — instead of the raw
/// ProcessingState.completed, which can fire on a mid-playlist clip failure and
/// wrongly skip a chapter.
final chunkCompletedProvider = StreamProvider<int>((ref) {
  final service = ref.watch(audioServiceProvider);
  return service.chunkCompletedStream;
});
