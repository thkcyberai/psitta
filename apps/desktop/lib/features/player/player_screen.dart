import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/state/now_reading.dart';
import '../../core/theme/colors.dart';
import '../../data/providers/providers.dart';
import '../../data/services/audio_service.dart';
import '../../data/services/preferences_service.dart';
import '../shell/widgets/player_bar.dart';
import 'widgets/chunk_navigator.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String documentId;

  const PlayerScreen({super.key, required this.documentId});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _hasAutoPlayed = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Look up real document title from documents provider
      final docs = ref.read(documentsProvider).valueOrNull;
      String docTitle = widget.documentId;
      if (docs != null) {
        for (final doc in docs) {
          if (doc.id == widget.documentId) {
            docTitle = doc.title;
            break;
          }
        }
      }
      ref.read(currentDocTitleProvider.notifier).state = docTitle;
      ref.read(activeDocumentIdProvider.notifier).state = widget.documentId;
    });

    // Debug: verify UI actually sees chunk index changes during playback.
    ref.listenManual<int>(currentChunkIndexProvider, (prev, next) {
      if (prev != next) {
        // ignore: avoid_print
        print('[PlayerScreen] currentChunkIndexProvider: $prev -> $next');
      }
    });

    // Listen for voice changes and re-play current chunk with new voice
    ref.listenManual<String>(selectedVoiceIdProvider, (previous, next) {
      if (previous != null && previous != next) {
        final ids = ref.read(activeChunkIdsProvider);
        final idx = ref.read(currentChunkIndexProvider);
        if (idx < ids.length) {
          _playAndPrefetch(ids, idx, next);
        }
      }
    });
  }

  @override
  void dispose() {
    // Clear wallboard when leaving player.
    ref.read(nowReadingTextProvider.notifier).state = '';
    super.dispose();
  }

  /// Play a chunk and prefetch the next one in the background.
  void _playAndPrefetch(List<String> chunkIds, int index, String voiceId) {
    final audioService = ref.read(audioServiceProvider);
    final speed = ref.read(selectedSpeedProvider);
    final volume = ref.read(selectedVolumeProvider);
    audioService
        .playChunk(
      documentId: widget.documentId,
      chunkId: chunkIds[index],
      voiceId: voiceId,
      speed: speed,
      volume: volume,
    )
        .then((_) {
      // Prefetch next chunk while current one plays
      if (index + 1 < chunkIds.length) {
        audioService.prefetchChunk(
          documentId: widget.documentId,
          chunkId: chunkIds[index + 1],
          voiceId: voiceId,
        );
      }
    });
  }

  /// Get display name for a voice ID from the voices provider.
  String _voiceName(WidgetRef ref) {
    final voicesAsync = ref.watch(voicesProvider);
    final selectedId = ref.watch(selectedVoiceIdProvider);
    String name =
        selectedId.length >= 8 ? selectedId.substring(0, 8) : selectedId;
    voicesAsync.whenData((voices) {
      for (final voice in voices) {
        if (voice.id == selectedId) {
          name = voice.displayName;
          break;
        }
      }
    });
    return name;
  }

  /// v1 wallboard text: chunk-level excerpt (no word timestamps yet).
  void _publishNowReading({
    required String chunkTitle,
    required String chunkText,
    required int currentIndex,
    required int total,
  }) {
    final excerpt = _truncate(chunkText, 140);
    final line = '$chunkTitle • ${currentIndex + 1}/$total • $excerpt';
    ref.read(nowReadingTextProvider.notifier).state = line;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chunksAsync = ref.watch(chunksProvider(widget.documentId));
    final activeChunkIndex = ref.watch(currentChunkIndexProvider);
    final isSynthesizing =
        ref.watch(isSynthesizingProvider).valueOrNull ?? false;

    final uri = GoRouterState.of(context).uri;
    final autoplayParam = uri.queryParameters['autoplay']?.toLowerCase().trim();
    final shouldAutoPlay = !(autoplayParam == '0' || autoplayParam == 'false');

    return chunksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text("Failed to load document", style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text("$err", style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  ref.invalidate(chunksProvider(widget.documentId)),
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ],
        ),
      ),
      data: (data) {
        final chunks = (data["chunks"] as List<dynamic>?) ?? [];
        if (chunks.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.article_outlined,
                    size: 48, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                Text("No content available",
                    style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }

        // Update player bar state
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final chunkIds = chunks.map<String>((c) {
            return ((c as Map<String, dynamic>)["id"] ?? "").toString();
          }).toList();
          ref.read(activeChunkIdsProvider.notifier).state = chunkIds;
          ref.read(totalChunksProvider.notifier).state = chunks.length;

          // Auto-play first chunk when document loads (unless autoplay disabled)
          if (_hasAutoPlayed == false && chunkIds.isNotEmpty) {
            _hasAutoPlayed = true;
            if (shouldAutoPlay) {
              final voiceId = ref.read(selectedVoiceIdProvider);
              _playAndPrefetch(chunkIds, 0, voiceId);
            }
          }
        });

        final currentIndex = activeChunkIndex.clamp(0, chunks.length - 1);

        final chunkMaps = chunks.map<Map<String, String>>((c) {
          final m = c as Map<String, dynamic>;
          return {
            "title": (m["title"] ?? "Section ${(m["sequence_index"] ?? 0) + 1}")
                .toString(),
            "preview": _truncate((m["text_content"] ?? "").toString(), 80),
          };
        }).toList();

        final activeChunk = chunks[currentIndex] as Map<String, dynamic>;
        final chunkTitle =
            (activeChunk["title"] ?? "Section ${currentIndex + 1}").toString();
        final chunkText = (activeChunk["text_content"] ?? "").toString();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _publishNowReading(
            chunkTitle: chunkTitle,
            chunkText: chunkText,
            currentIndex: currentIndex,
            total: chunks.length,
          );
        });

        return Stack(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 280,
                  child: Container(
                    color:
                        isDark ? AppColors.sidebarDark : AppColors.sidebarLight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Chapters",
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.record_voice_over,
                                    size: 14,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Voice: ${_voiceName(ref)}',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ChunkNavigator(
                            chunks: chunkMaps,
                            activeIndex: currentIndex,
                            onChunkSelected: (index) {
                              ref
                                  .read(currentChunkIndexProvider.notifier)
                                  .state = index;

                              final selected =
                                  chunks[index] as Map<String, dynamic>;
                              final t =
                                  (selected["title"] ?? "Section ${index + 1}")
                                      .toString();
                              final txt =
                                  (selected["text_content"] ?? "").toString();
                              _publishNowReading(
                                chunkTitle: t,
                                chunkText: txt,
                                currentIndex: index,
                                total: chunks.length,
                              );

                              final chunkIds = ref.read(activeChunkIdsProvider);
                              if (index < chunkIds.length) {
                                final voiceId =
                                    ref.read(selectedVoiceIdProvider);
                                _playAndPrefetch(chunkIds, index, voiceId);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chunkTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Chunk ${currentIndex + 1} of ${chunks.length}",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: SingleChildScrollView(
                            child: LayoutBuilder(
                              builder: (context, constraints) => SizedBox(
                                width: constraints.maxWidth,
                                child: SelectableText(
                                  chunkText,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    height: 1.8,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (isSynthesizing)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: AppColors.primary.withOpacity(0.9),
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Synthesizing audio...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _truncate(String text, int maxLen) {
    final clean = text.replaceAll('\n', ' ').trim();
    if (clean.length <= maxLen) return clean;
    return "${clean.substring(0, maxLen)}...";
  }
}
