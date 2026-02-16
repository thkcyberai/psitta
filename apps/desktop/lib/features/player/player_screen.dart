import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../data/providers/providers.dart';
import '../../data/services/audio_service.dart';
import '../shell/widgets/player_bar.dart';
import 'widgets/chunk_navigator.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String documentId;

  const PlayerScreen({super.key, required this.documentId});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentDocTitleProvider.notifier).state =
          "Document ${widget.documentId.substring(0, 8)}...";
      ref.read(activeDocumentIdProvider.notifier).state = widget.documentId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chunksAsync = ref.watch(chunksProvider(widget.documentId));
    final activeChunkIndex = ref.watch(currentChunkIndexProvider);

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
              onPressed: () => ref.invalidate(chunksProvider(widget.documentId)),
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
                const Icon(Icons.article_outlined, size: 48, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                Text("No content available", style: theme.textTheme.titleMedium),
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
        });

        final currentIndex = activeChunkIndex.clamp(0, chunks.length - 1);

        final chunkMaps = chunks.map<Map<String, String>>((c) {
          final m = c as Map<String, dynamic>;
          return {
            "title": (m["title"] ?? "Section ${(m["sequence_index"] ?? 0) + 1}").toString(),
            "preview": _truncate((m["text_content"] ?? "").toString(), 80),
          };
        }).toList();

        final activeChunk = chunks[currentIndex] as Map<String, dynamic>;
        final chunkTitle = (activeChunk["title"] ?? "Section ${currentIndex + 1}").toString();
        final chunkText = (activeChunk["text_content"] ?? "").toString();

        return Row(
          children: [
            SizedBox(
              width: 280,
              child: Container(
                color: isDark ? AppColors.sidebarDark : AppColors.sidebarLight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        "Chapters",
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ChunkNavigator(
                        chunks: chunkMaps,
                        activeIndex: currentIndex,
                        onChunkSelected: (index) {
                          ref.read(currentChunkIndexProvider.notifier).state = index;
                          final chunkIds = ref.read(activeChunkIdsProvider);
                          if (index < chunkIds.length) {
                            final audioService = ref.read(audioServiceProvider);
                            audioService.playChunk(
                              documentId: widget.documentId,
                              chunkId: chunkIds[index],
                            );
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
                        child: SelectableText(
                          chunkText,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.8,
                            fontSize: 16,
                          ),
                        ),
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
