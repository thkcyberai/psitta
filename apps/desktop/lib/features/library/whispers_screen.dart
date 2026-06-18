import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/theme/psitta_tokens.dart';
import '../../data/models/document.dart';
import '../../data/providers/providers.dart';

/// Whispers — voice notes surface. Playback + list are live; mic capture is
/// deferred until the Flutter/Dart toolchain supports a working `record`
/// plugin (see pubspec note). The backend (/documents/recording) is ready, so
/// restoring capture later is a small change to the recorder bar below.
class WhispersScreen extends ConsumerStatefulWidget {
  const WhispersScreen({super.key});

  @override
  ConsumerState<WhispersScreen> createState() => _WhispersScreenState();
}

class _WhispersScreenState extends ConsumerState<WhispersScreen> {
  final AudioPlayer _player = AudioPlayer();
  String? _playingId;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play(Document doc) async {
    try {
      if (_playingId == doc.id) {
        await _player.stop();
        setState(() => _playingId = null);
        return;
      }
      final bytes =
          await ref.read(documentRepositoryProvider).downloadDocument(doc.id);
      final dir = await getTemporaryDirectory();
      final tmp = File(p.join(dir.path, 'play_${doc.id}.m4a'));
      await tmp.writeAsBytes(bytes);
      await _player.setFilePath(tmp.path);
      setState(() => _playingId = doc.id);
      await _player.play();
      _player.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed && mounted) {
          setState(() => _playingId = null);
        }
      });
    } catch (e) {
      _snack('Couldn’t play the recording.');
    }
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

  // Mic capture is temporarily deferred (toolchain limitation). The bar stays
  // so the surface is complete; restoring capture is a localized change.
  Widget _recorderBar(ColorScheme scheme, PsittaTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Icon(Icons.mic_none_outlined,
              color: scheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Voice recording is coming soon.',
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          FilledButton.icon(
            onPressed: () => _snack('Voice recording is coming soon.'),
            icon: const Icon(Icons.mic, size: 18),
            label: const Text('Record'),
          ),
        ],
      ),
    );
  }
}
