import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/theme/psitta_tokens.dart';
import '../../data/models/document.dart';
import '../../data/providers/providers.dart';

/// Whispers — voice notes surface. Record an idea straight from the mic,
/// listen back, or delete. Capture uses the `record` plugin (AAC/m4a on
/// Windows via MediaFoundation); the audio is uploaded to /documents/recording
/// and listed via [recordingsProvider].
class WhispersScreen extends ConsumerStatefulWidget {
  const WhispersScreen({super.key});

  @override
  ConsumerState<WhispersScreen> createState() => _WhispersScreenState();
}

class _WhispersScreenState extends ConsumerState<WhispersScreen> {
  final AudioPlayer _player = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();
  String? _playingId;
  StreamSubscription<PlayerState>? _playerSub;

  bool _isRecording = false;
  bool _isSaving = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  String? _activeRecordingPath;

  @override
  void dispose() {
    _timer?.cancel();
    _playerSub?.cancel();
    _player.dispose();
    _recorder.dispose();
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

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        _snack('Microphone access is blocked. Enable it in Windows settings.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = p.join(
        dir.path,
        'whisper_${DateTime.now().millisecondsSinceEpoch}.wav',
      );
      // WAV/PCM is the most reliable capture+playback format on Windows:
      // record_windows and just_audio both handle it natively with no codec
      // dependency (AAC/MediaFoundation playback proved flaky on replay).
      // Mono @ 22.05 kHz keeps voice-note files small.
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          numChannels: 1,
          sampleRate: 22050,
        ),
        path: path,
      );
      _activeRecordingPath = path;
      setState(() {
        _isRecording = true;
        _elapsed = Duration.zero;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      });
    } catch (e) {
      _snack('Couldn’t start recording.');
    }
  }

  Future<void> _stopAndSave() async {
    _timer?.cancel();
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = _activeRecordingPath;
    }
    setState(() => _isRecording = false);

    final filePath = path ?? _activeRecordingPath;
    if (filePath == null) {
      _activeRecordingPath = null;
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
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        setState(() => _isSaving = false);
        _snack('That recording was empty.');
        return;
      }
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
    final ctrl = TextEditingController();
    final fallback = _defaultTitle();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        String result() =>
            ctrl.text.trim().isEmpty ? fallback : ctrl.text.trim();
        return AlertDialog(
          title: const Text('Name this whisper'),
          content: SizedBox(
            width: 360,
            child: TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: fallback,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => Navigator.pop(ctx, result()),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, result()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    try {
      await _recorder.stop();
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
      await ref.read(documentRepositoryProvider).deleteDocument(doc.id);
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
    final async = ref.watch(recordingsProvider);

    return Container(
      color: tokens.surface,
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.graphic_eq, size: 26, color: scheme.onSurface),
              const SizedBox(width: 10),
              Text('Whispers',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Capture an idea by voice — listen back anytime.',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          _recorderBar(scheme, tokens),
          const SizedBox(height: 18),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Couldn’t load your recordings.',
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
                        Text('No whispers yet',
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
                          Expanded(
                            child: Text(doc.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
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
            child: Text('Saving your whisper…',
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
            child: Text('Recording…',
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: _cancelRecording,
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _stopAndSave,
            icon: const Icon(Icons.stop, size: 18),
            label: const Text('Stop & save'),
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
          child: Text('Tap record to capture a voice note.',
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
        FilledButton.icon(
          onPressed: _startRecording,
          icon: const Icon(Icons.mic, size: 18),
          label: const Text('Record'),
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
