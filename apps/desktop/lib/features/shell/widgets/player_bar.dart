import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/theme/colors.dart';
import '../../../core/extensions.dart';
import '../../../data/services/audio_service.dart';

/// Shared state for current document info in the player bar.
final currentDocTitleProvider = StateProvider<String?>((ref) => null);
final currentChunkIndexProvider = StateProvider<int>((ref) => 0);
final totalChunksProvider = StateProvider<int>((ref) => 0);

/// Current document and chunk IDs for audio loading.
final activeDocumentIdProvider = StateProvider<String?>((ref) => null);
final activeChunkIdsProvider = StateProvider<List<String>>((ref) => []);

/// Player Bar with real audio playback via just_audio.
class PlayerBar extends ConsumerWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docTitle = ref.watch(currentDocTitleProvider);
    final chunkIndex = ref.watch(currentChunkIndexProvider);
    final totalChunks = ref.watch(totalChunksProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasActiveSession = docTitle != null;

    // Audio streams
    final isPlaying = ref.watch(audioPlayingProvider).valueOrNull ?? false;
    final position = ref.watch(audioPositionProvider).valueOrNull ?? Duration.zero;
    final duration = ref.watch(audioDurationProvider).valueOrNull ?? const Duration(minutes: 5);
    final audioService = ref.watch(audioServiceProvider);

    // Auto-advance to next chunk when current one finishes
    ref.listen<AsyncValue<PlayerState>>(audioPlayerStateProvider, (prev, next) {
      final state = next.valueOrNull;
      if (state != null &&
          state.processingState == ProcessingState.completed &&
          state.playing == false) {
        _skipForward(ref, audioService);
      }
    });

    return Container(
      color: isDark ? AppColors.playerBarDark : AppColors.playerBar,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Document info (left)
          SizedBox(
            width: 200,
            child: hasActiveSession
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        docTitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        totalChunks > 0
                            ? 'Chapter ${chunkIndex + 1} of $totalChunks'
                            : 'No chapters',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'No document playing',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
          ),

          // Playback controls (center)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous, size: 22),
                      onPressed: hasActiveSession
                          ? () => _skipBackward(ref, audioService)
                          : null,
                      tooltip: 'Previous chunk',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        size: 38,
                        color: hasActiveSession ? AppColors.primary : null,
                      ),
                      onPressed: hasActiveSession
                          ? () => audioService.togglePlayPause()
                          : null,
                      tooltip: 'Play/Pause (Space)',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.skip_next, size: 22),
                      onPressed: hasActiveSession
                          ? () => _skipForward(ref, audioService)
                          : null,
                      tooltip: 'Next chunk',
                    ),
                  ],
                ),
                SizedBox(
                  height: 20,
                  child: Row(
                    children: [
                      Text(
                        position.toPlayerTimestamp(),
                        style: theme.textTheme.labelSmall,
                      ),
                      Expanded(
                        child: Slider(
                          value: position.inMilliseconds
                              .toDouble()
                              .clamp(0, duration.inMilliseconds.toDouble()),
                          max: duration.inMilliseconds
                              .toDouble()
                              .clamp(1, double.infinity),
                          onChanged: hasActiveSession
                              ? (v) => audioService
                                  .seek(Duration(milliseconds: v.toInt()))
                              : null,
                        ),
                      ),
                      Text(
                        duration.toPlayerTimestamp(),
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Speed and volume (right)
          SizedBox(
            width: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: hasActiveSession ? () {} : null,
                  child: Text(
                    '1.0x',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up, size: 20),
                  onPressed: hasActiveSession ? () {} : null,
                  tooltip: 'Volume',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _skipForward(WidgetRef ref, AudioService audioService) {
    final chunkIds = ref.read(activeChunkIdsProvider);
    final current = ref.read(currentChunkIndexProvider);
    if (current < chunkIds.length - 1) {
      ref.read(currentChunkIndexProvider.notifier).state = current + 1;
      final docId = ref.read(activeDocumentIdProvider);
      if (docId != null) {
        audioService.playChunk(
          documentId: docId,
          chunkId: chunkIds[current + 1],
        );
      }
    }
  }

  void _skipBackward(WidgetRef ref, AudioService audioService) {
    final chunkIds = ref.read(activeChunkIdsProvider);
    final current = ref.read(currentChunkIndexProvider);
    if (current > 0) {
      ref.read(currentChunkIndexProvider.notifier).state = current - 1;
      final docId = ref.read(activeDocumentIdProvider);
      if (docId != null) {
        audioService.playChunk(
          documentId: docId,
          chunkId: chunkIds[current - 1],
        );
      }
    }
  }
}
