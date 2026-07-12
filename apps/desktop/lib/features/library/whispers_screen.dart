import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_recorder/flutter_recorder.dart';

import '../../core/theme/psitta_tokens.dart';
import '../../data/models/document.dart';
import '../../widgets/library_breadcrumb.dart';
import '../../data/providers/providers.dart';

import '../../data/providers/document_actions.dart';
/// Whispers — voice notes surface. Record an idea straight from the mic,
/// listen back, or delete. Capture uses flutter_recorder (miniaudio/FFI; WASAPI
/// on Windows) recording 16-bit PCM WAV to a temp file; the audio is uploaded
/// to /documents/recording and listed via [recordingsProvider].
class WhispersScreen extends ConsumerStatefulWidget {
  const WhispersScreen({super.key});

  @override
  ConsumerState<WhispersScreen> createState() => _WhispersScreenState();
}

class _WhispersScreenState extends ConsumerState<WhispersScreen> {
  final AudioPlayer _player = AudioPlayer();
  final Recorder _recorder = Recorder.instance;
  bool _recorderInited = false;
  String? _playingId;
  StreamSubscription<PlayerState>? _playerSub;

  bool _isRecording = false;
  bool _isSaving = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  String? _activeRecordingPath;

  /// Cached amplitude profiles per recording id (normalized 0..1 per bar),
  /// computed from the WAV the first time a whisper is played. Idle rows fall
  /// back to a light placeholder until then.
  final Map<String, List<double>> _peaks = {};

  @override
  void dispose() {
    _timer?.cancel();
    _playerSub?.cancel();
    _player.dispose();
    if (_recorderInited) {
      try {
        _recorder.deinit();
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _play(Document doc) async {
    try {
      if (_playingId == doc.id) {
        await _player.stop();
        setState(() => _playingId = null);
        return;
      }
      // Release any prior source before loading a new one. just_audio on
      // Windows keeps the backing file open while loaded, so reusing a fixed
      // temp path (overwrite-while-open) intermittently fails on replay.
      await _player.stop();
      final bytes =
          await ref.read(documentRepositoryProvider).downloadDocument(doc.id);
      final dir = await getTemporaryDirectory();
      // Choose the temp extension from the audio's magic bytes so both new
      // WAV recordings and any legacy m4a ones decode reliably on Windows.
      final isWav = bytes.length >= 4 &&
          bytes[0] == 0x52 && // R
          bytes[1] == 0x49 && // I
          bytes[2] == 0x46 && // F
          bytes[3] == 0x46; // F
      final tmp = File(p.join(
        dir.path,
        'play_${doc.id}_${DateTime.now().millisecondsSinceEpoch}'
        '${isWav ? '.wav' : '.m4a'}',
      ));
      await tmp.writeAsBytes(bytes);
      // Decode the real amplitude profile so the row shows this recording's
      // actual shape (legacy m4a returns empty → keeps the placeholder).
      if (isWav) {
        final pk = _computePeaks(Uint8List.fromList(bytes));
        if (pk.isNotEmpty && mounted) {
          setState(() => _peaks[doc.id] = pk);
        }
      }
      await _player.setFilePath(tmp.path);
      setState(() => _playingId = doc.id);
      await _player.play();
      _playerSub?.cancel();
      _playerSub = _player.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed && mounted) {
          setState(() => _playingId = null);
        }
      });
    } catch (e) {
      debugPrint('[Whisper] play error: $e');
      _snack('Couldn’t play the recording.');
    }
  }

  // ── Mic capture ──────────────────────────────────────────────────────────

  /// Lazily initialize and start the miniaudio capture device. No mic
  /// permission call is needed on Windows desktop. Returns false if the device
  /// can't be opened.
  Future<bool> _ensureRecorder() async {
    try {
      if (!_recorderInited) {
        // Match the Windows capture device's native format (stereo, 16-bit,
        // 48 kHz). Requesting a format the device doesn't natively provide can
        // make the WASAPI capture callback never fire — the file gets a header
        // but no audio frames (vol stays at -100).
        await _recorder.init(
          format: PCMFormat.s16le,
          sampleRate: 48000,
          channels: RecorderChannels.stereo,
        );
        _recorderInited = true;
      }
      if (!_recorder.isDeviceStarted()) {
        _recorder.start();
      }
      debugPrint('[WhisperCap] inited=${_recorder.isDeviceInitialized()} '
          'started=${_recorder.isDeviceStarted()} '
          'devices=${_recorder.listCaptureDevices().length} '
          'vol=${_recorder.getVolumeDb()}');
      return true;
    } catch (e) {
      debugPrint('[WhisperFix] recorder init/start failed: $e');
      return false;
    }
  }

  Future<void> _startRecording() async {
    if (!await _ensureRecorder()) {
      _snack('Couldn’t start recording.');
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final path = p.join(
        dir.path,
        'whisper_${DateTime.now().millisecondsSinceEpoch}.wav',
      );
      // flutter_recorder writes a 16-bit PCM WAV directly to this path; just
      // audio plays it back natively (RIFF magic-byte detection in _play).
      _recorder.startRecording(completeFilePath: path);
      _activeRecordingPath = path;
      debugPrint('[WhisperFix] started file capture -> $path');
      // Probe mid-recording: does the WAV exist shortly after startRecording,
      // and is the mic delivering audio (volume above -100 dB)?
      Future<void>.delayed(const Duration(milliseconds: 500), () async {
        final f = File(path);
        final exists = await f.exists();
        debugPrint('[WhisperCap] 500ms in: exists=$exists '
            'len=${exists ? await f.length() : -1} '
            'started=${_recorder.isDeviceStarted()} '
            'vol=${_recorder.getVolumeDb()}');
      });
      setState(() {
        _isRecording = true;
        _elapsed = Duration.zero;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      });
    } catch (e) {
      debugPrint('[WhisperFix] start error: $e');
      _snack('Couldn’t start recording.');
    }
  }

  /// Waits for the recorder's WAV file to appear on disk with real audio in it.
  /// stopRecording() finalizes synchronously, but this poll is a safety net so
  /// we never read a half-written or header-only file. Poll until the file
  /// exists AND is larger than a bare 44-byte WAV header, up to [timeout].
  /// Returns the final byte length (0 if it never materialized).
  Future<int> _awaitFinalizedFile(
    String path, {
    Duration timeout = const Duration(seconds: 3),
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final file = File(path);
    final deadline = DateTime.now().add(timeout);
    var lastLen = 0;
    while (DateTime.now().isBefore(deadline)) {
      try {
        if (await file.exists()) {
          final len = await file.length();
          // Require more than a bare 44-byte WAV header so we don't upload an
          // empty stub the writer hasn't filled in yet.
          if (len > 44) {
            // One more short settle so a still-flushing writer can finish;
            // accept as soon as the size stops growing.
            if (len == lastLen) {
              debugPrint('[WhisperFix] file finalized: $len bytes');
              return len;
            }
            lastLen = len;
          }
        }
      } catch (_) {
        // File momentarily locked/unreadable while the writer closes it.
      }
      await Future<void>.delayed(interval);
    }
    // Timed out. Report whatever we last saw (0 if it never appeared).
    debugPrint('[WhisperFix] file NOT finalized within '
        '${timeout.inMilliseconds}ms (lastLen=$lastLen)');
    return lastLen;
  }

  /// Peak-normalizes 16-bit PCM WAV bytes to ~-1 dBFS. Laptop array mics (and
  /// the raw WASAPI capture path miniaudio uses) record well below line level
  /// with no hardware boost, so the saved WAV is faithfully quiet and plays
  /// back quiet at full volume. This lifts the clip to a usable level before
  /// upload. Pure Dart; returns the input unchanged if it can't be parsed,
  /// is silent, or is already loud enough — never blocks a save.
  static Uint8List _normalizeWav(Uint8List input) {
    try {
      final inView = ByteData.sublistView(input);
      // Locate the 'data' subchunk; don't assume a fixed 44-byte header.
      int dataStart = -1, dataLen = 0;
      int pos = 12; // skip 'RIFF' <size> 'WAVE'
      while (pos + 8 <= input.length) {
        final id = String.fromCharCodes(input, pos, pos + 4);
        final size = inView.getUint32(pos + 4, Endian.little);
        if (id == 'data') {
          dataStart = pos + 8;
          dataLen = size;
          break;
        }
        pos += 8 + size + (size & 1); // chunks are word-aligned
      }
      if (dataStart < 0) return input;
      final end =
          (dataStart + dataLen) > input.length ? input.length : dataStart + dataLen;

      // Pass 1: find the peak sample magnitude.
      int peak = 0;
      for (int i = dataStart; i + 1 < end; i += 2) {
        final s = inView.getInt16(i, Endian.little);
        final a = s < 0 ? -s : s;
        if (a > peak) peak = a;
      }
      if (peak == 0) return input; // silence — nothing to scale

      const targetPeak = 29205; // ~ -1 dBFS of 32767
      const maxGain = 16.0; // cap so near-silent clips don't blow up the noise
      double gain = targetPeak / peak;
      if (gain <= 1.0) return input; // already at/above target
      if (gain > maxGain) gain = maxGain;

      // Pass 2: apply gain on a copy, clipping-guarded.
      final out = Uint8List.fromList(input);
      final outView = ByteData.sublistView(out);
      for (int i = dataStart; i + 1 < end; i += 2) {
        int s = (outView.getInt16(i, Endian.little) * gain).round();
        if (s > 32767) s = 32767;
        if (s < -32768) s = -32768;
        outView.setInt16(i, s, Endian.little);
      }
      return out;
    } catch (_) {
      return input; // never fail a save over a normalization hiccup
    }
  }

  /// Returns a normalized (0..1) amplitude profile for a 16-bit PCM WAV by
  /// RMS-bucketing the samples into [buckets] bars — the real shape of the
  /// recording. Returns an empty list if the bytes can't be parsed (e.g. a
  /// legacy m4a), in which case the row keeps its placeholder.
  static List<double> _computePeaks(Uint8List wav, {int buckets = 360}) {
    try {
      final view = ByteData.sublistView(wav);
      int dataStart = -1, dataLen = 0, pos = 12;
      while (pos + 8 <= wav.length) {
        final id = String.fromCharCodes(wav, pos, pos + 4);
        final size = view.getUint32(pos + 4, Endian.little);
        if (id == 'data') {
          dataStart = pos + 8;
          dataLen = size;
          break;
        }
        pos += 8 + size + (size & 1);
      }
      if (dataStart < 0) return const [];
      final end =
          (dataStart + dataLen) > wav.length ? wav.length : dataStart + dataLen;
      final totalSamples = (end - dataStart) ~/ 2;
      if (totalSamples <= 0) return const [];
      final per = (totalSamples / buckets).ceil();
      final out = <double>[];
      double globalMax = 1.0;
      int idx = dataStart;
      for (int b = 0; b < buckets; b++) {
        double sumSq = 0;
        int count = 0;
        for (int j = 0; j < per && idx + 1 < end; j++, idx += 2) {
          final s = view.getInt16(idx, Endian.little).toDouble();
          sumSq += s * s;
          count++;
        }
        final rms = count > 0 ? math.sqrt(sumSq / count) : 0.0;
        out.add(rms);
        if (rms > globalMax) globalMax = rms;
      }
      // Normalize to the loudest bucket, with a gentle gamma so quiet detail
      // stays visible.
      for (int i = 0; i < out.length; i++) {
        out[i] =
            math.pow(out[i] / globalMax, 0.7).toDouble().clamp(0.0, 1.0).toDouble();
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// A stable, recording-specific placeholder profile for rows whose audio
  /// hasn't been decoded yet. Seeded by the id so it doesn't flicker on rebuild.
  static List<double> _placeholderPeaks(String id, {int buckets = 180}) {
    final rnd = math.Random(id.hashCode);
    return List<double>.generate(buckets, (_) => 0.22 + rnd.nextDouble() * 0.5);
  }

  List<double> _peaksFor(Document doc) =>
      _peaks[doc.id] ?? _placeholderPeaks(doc.id);

  Future<void> _stopAndSave() async {
    _timer?.cancel();
    try {
      // Only stop the recording — NOT the device. Stopping the capture device
      // here races/cancels miniaudio's WAV finalization (file never appears).
      // The device stays started; deinit() in dispose() releases it.
      _recorder.stopRecording();
    } catch (e) {
      debugPrint('[WhisperFix] stopRecording() threw: $e');
    }
    try {
      final f = File(_activeRecordingPath ?? '');
      final exists = await f.exists();
      debugPrint('[WhisperCap] right after stopRecording: exists=$exists '
          'len=${exists ? await f.length() : -1}');
    } catch (_) {}
    setState(() => _isRecording = false);

    final filePath = _activeRecordingPath;
    if (filePath == null) {
      _activeRecordingPath = null;
      _snack('That recording was empty.');
      return;
    }
    if (!mounted) return;

    // Ask the writer to name it. Blank keeps the timestamp default; Discard
    // drops the recording entirely.
    final title = await _promptName();
    if (title == null) {
      try {
        await File(filePath).delete();
      } catch (_) {}
      _activeRecordingPath = null;
      if (mounted) _snack('Recording discarded');
      return;
    }

    setState(() => _isSaving = true);
    try {
      // stopRecording() finalizes synchronously, but poll briefly as a safety
      // net so we never read a half-written or header-only WAV.
      final finalLen = await _awaitFinalizedFile(filePath);
      if (finalLen <= 44) {
        setState(() => _isSaving = false);
        _snack('That recording was empty.');
        try {
          await File(filePath).delete();
        } catch (_) {}
        _activeRecordingPath = null;
        return;
      }

      final file = File(filePath);
      final rawBytes = await file.readAsBytes();
      if (rawBytes.isEmpty) {
        setState(() => _isSaving = false);
        _snack('That recording was empty.');
        _activeRecordingPath = null;
        return;
      }
      // Lift the quiet raw mic capture to ~-1 dBFS so the whisper is audible
      // on playback without a separate gain stage. No-op if already loud.
      final bytes = _normalizeWav(rawBytes);
      debugPrint('[WhisperFix] uploading ${bytes.length} bytes '
          '(normalized from ${rawBytes.length}; ${p.basename(filePath)})');
      await ref.read(documentRepositoryProvider).uploadRecording(
            bytes,
            p.basename(filePath),
            title: title,
          );
      ref.invalidate(recordingsProvider);
      ref.invalidate(storageUsageProvider);
      try {
        await file.delete();
      } catch (_) {}
      if (mounted) {
        setState(() => _isSaving = false);
        _snack('Whisper saved');
      }
    } catch (e) {
      debugPrint('[WhisperFix] save error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        _snack('Couldn’t save the recording.');
      }
    } finally {
      _activeRecordingPath = null;
    }
  }

  /// Prompts for a whisper name. Returns the chosen title (blank falls back to
  /// the timestamp default), or null if the writer discards the recording.
  Future<String?> _promptName() async {
    final loc = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final fallback = _defaultTitle();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        String result() =>
            ctrl.text.trim().isEmpty ? fallback : ctrl.text.trim();
        return AlertDialog(
          title: Text(loc.whisperNameTitle),
          content: SizedBox(
            width: 360,
            child: TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: loc.whisperNameLabel,
                hintText: fallback,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => Navigator.pop(ctx, result()),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(loc.btnDiscard),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, result()),
              child: Text(loc.btnSave),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    try {
      _recorder.stopRecording();
    } catch (_) {}
    final path = _activeRecordingPath;
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    _activeRecordingPath = null;
    if (mounted) {
      setState(() {
        _isRecording = false;
        _elapsed = Duration.zero;
      });
    }
  }

  String _defaultTitle() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final ampm = now.hour < 12 ? 'AM' : 'PM';
    final mm = now.minute.toString().padLeft(2, '0');
    return 'Whisper · ${months[now.month - 1]} ${now.day}, $h12:$mm $ampm';
  }

  String _fmtElapsed(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _delete(Document doc) async {
    try {
      await ref.read(documentActionsProvider).deleteDocument(doc.id);
      ref.invalidate(recordingsProvider);
      ref.invalidate(storageUsageProvider);
      ref.invalidate(trashedDocumentsProvider);
      if (mounted) _snack('Moved to Trash');
    } catch (e) {
      _snack('Couldn’t delete the recording.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final async = ref.watch(recordingsProvider);

    return Container(
      color: tokens.surface,
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LibraryBreadcrumb(current: loc.whispersTitle),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.graphic_eq, size: 26, color: scheme.onSurface),
              const SizedBox(width: 10),
              Text(loc.whispersTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            loc.whispersSubtitle,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          _recorderBar(scheme, tokens),
          const SizedBox(height: 18),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(loc.whisperLoadError,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
              data: (docs) {
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mic_none_outlined,
                            size: 48,
                            color: scheme.onSurfaceVariant.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text(loc.noWhispersYet,
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => Divider(
                      height: 1, color: tokens.divider.withOpacity(0.4)),
                  itemBuilder: (_, i) {
                    final doc = docs[i];
                    final playing = _playingId == doc.id;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => _play(doc),
                            icon: Icon(playing
                                ? Icons.stop_circle_outlined
                                : Icons.play_circle_outline),
                            color: tokens.glow,
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 196,
                            child: Text(doc.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 30,
                              child: playing
                                  ? StreamBuilder<Duration>(
                                      stream: _player.positionStream,
                                      builder: (_, snap) {
                                        final dur =
                                            _player.duration ?? Duration.zero;
                                        final posn = snap.data ?? Duration.zero;
                                        final prog = dur.inMilliseconds == 0
                                            ? 0.0
                                            : (posn.inMilliseconds /
                                                    dur.inMilliseconds)
                                                .clamp(0.0, 1.0)
                                                .toDouble();
                                        return _WaveformBars(
                                          peaks: _peaksFor(doc),
                                          progress: prog,
                                          durationMs: dur.inMilliseconds,
                                          playedColor: tokens.glow,
                                          baseColor: scheme.onSurfaceVariant
                                              .withOpacity(0.30),
                                        );
                                      },
                                    )
                                  : _WaveformBars(
                                      peaks: _peaksFor(doc),
                                      progress: 0,
                                      durationMs: null,
                                      playedColor: tokens.glow,
                                      baseColor: scheme.onSurfaceVariant
                                          .withOpacity(0.30),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () => _delete(doc),
                            icon: const Icon(Icons.delete_outline, size: 20),
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _recorderBar(ColorScheme scheme, PsittaTokens tokens) {
    final loc = AppLocalizations.of(context);
    if (_isSaving) {
      return _bar(
        tokens,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(loc.whisperSaving,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
        ],
      );
    }

    if (_isRecording) {
      return _bar(
        tokens,
        borderColor: scheme.error,
        children: [
          Icon(Icons.fiber_manual_record, color: scheme.error, size: 16),
          const SizedBox(width: 10),
          Text(_fmtElapsed(_elapsed),
              style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(loc.whisperRecording,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: _cancelRecording,
            child: Text(loc.btnCancel),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _stopAndSave,
            icon: const Icon(Icons.stop, size: 18),
            label: Text(loc.whisperStopSave),
          ),
        ],
      );
    }

    return _bar(
      tokens,
      children: [
        Icon(Icons.mic_none_outlined, color: scheme.onSurfaceVariant, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(loc.tapRecord,
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
        FilledButton.icon(
          onPressed: _startRecording,
          icon: const Icon(Icons.mic, size: 18),
          label: Text(loc.btnRecord),
        ),
      ],
    );
  }

  Widget _bar(PsittaTokens tokens,
      {required List<Widget> children, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? tokens.border),
      ),
      child: Row(children: children),
    );
  }
}

/// Voice-note style waveform: amplitude bars that span the full available
/// width with a playback progress sweep. The bar count scales with the clip's
/// duration (longer audio → more, thinner bars) but always fills the space, so
/// the sweep travels edge-to-edge over the exact length of the audio. [peaks]
/// are normalized 0..1; bars left of [progress] render in [playedColor], the
/// rest in [baseColor].
class _WaveformBars extends StatelessWidget {
  const _WaveformBars({
    required this.peaks,
    required this.progress,
    required this.playedColor,
    required this.baseColor,
    this.durationMs,
  });

  final List<double> peaks;
  final double progress;
  final Color playedColor;
  final Color baseColor;
  final int? durationMs;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
        const gap = 1.5;
        const minBarW = 2.0;
        const maxBarW = 3.5;
        const barsPerSecond = 16.0;
        // Bar count that always fills the width: between maxBarW-wide bars
        // (fewest) and minBarW-wide bars (most). Duration nudges within that
        // range so longer clips render more, thinner bars.
        final maxN = math.max(1, ((width + gap) / (minBarW + gap)).floor());
        final minN =
            math.max(1, math.min(maxN, ((width + gap) / (maxBarW + gap)).ceil()));
        final desired = (durationMs != null && durationMs! > 0)
            ? (durationMs! / 1000.0 * barsPerSecond).round()
            : minN;
        final n = desired.clamp(minN, maxN).toInt();
        final bars = _resampleWave(peaks, n);
        return CustomPaint(
          size: Size(width, 30),
          painter: _WaveformPainter(
            peaks: bars,
            progress: progress,
            playedColor: playedColor,
            baseColor: baseColor,
            gap: gap,
          ),
        );
      },
    );
  }
}

/// Linearly resamples [src] to exactly [n] values so the bar count can match
/// the available width / duration without losing the overall shape.
List<double> _resampleWave(List<double> src, int n) {
  if (src.isEmpty || n <= 0) return const [];
  if (src.length == n) return src;
  if (n == 1) return [src.reduce((a, b) => a > b ? a : b)];
  final out = List<double>.filled(n, 0.0);
  final lastSrc = src.length - 1;
  for (int i = 0; i < n; i++) {
    final t = i * lastSrc / (n - 1);
    final lo = t.floor();
    final hi = lo + 1 <= lastSrc ? lo + 1 : lastSrc;
    final f = t - lo;
    out[i] = src[lo] * (1 - f) + src[hi] * f;
  }
  return out;
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.peaks,
    required this.progress,
    required this.playedColor,
    required this.baseColor,
    this.gap = 1.5,
  });

  final List<double> peaks;
  final double progress;
  final Color playedColor;
  final Color baseColor;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty || size.width <= 0) return;
    final n = peaks.length;
    final stride = size.width / n;
    final barW = math.max(1.0, stride - gap);
    final midY = size.height / 2;
    final progressX = size.width * progress.clamp(0.0, 1.0).toDouble();
    final played = Paint()
      ..color = playedColor
      ..style = PaintingStyle.fill;
    final base = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;
    for (int i = 0; i < n; i++) {
      final x = i * stride;
      double barH = (peaks[i].clamp(0.0, 1.0) * size.height).toDouble();
      if (barH < 2.0) barH = 2.0;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, midY - barH / 2, barW, barH),
        const Radius.circular(1.2),
      );
      canvas.drawRRect(rect, (x + barW) <= progressX ? played : base);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.peaks != peaks ||
      old.playedColor != playedColor ||
      old.baseColor != baseColor;
}
