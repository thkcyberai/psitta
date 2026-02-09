import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/extensions.dart';

/// Playback state — shared across shell and player screen.
final isPlayingProvider = StateProvider<bool>((ref) => false);
final currentDocTitleProvider = StateProvider<String?>((ref) => null);
final playbackPositionProvider = StateProvider<Duration>((ref) => Duration.zero);
final playbackDurationProvider = StateProvider<Duration>(
  (ref) => const Duration(minutes: 5),
);

/// Player Bar — persistent audio controls at the bottom of the shell.
///
/// Always visible. Shows current document title, play/pause,
/// skip controls, progress slider, and speed indicator.
/// When nothing is playing, shows a muted "No document playing" state.
class PlayerBar extends ConsumerWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(isPlayingProvider);
    final docTitle = ref.watch(currentDocTitleProvider);
    final position = ref.watch(playbackPositionProvider);
    final duration = ref.watch(playbackDurationProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasActiveSession = docTitle != null;

    return Container(
      color: isDark ? AppColors.playerBarDark : AppColors.playerBar,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // ── Document info (left) ───────────────────────────
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
                        'Chapter 1 of 12',
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

          // ── Playback controls (center) ─────────────────────
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Controls row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous, size: 22),
                      onPressed: hasActiveSession ? () {} : null,
                      tooltip: 'Previous chunk (Ctrl+←)',
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
                          ? () => ref
                              .read(isPlayingProvider.notifier)
                              .state = !isPlaying
                          : null,
                      tooltip: 'Play/Pause (Space)',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.skip_next, size: 22),
                      onPressed: hasActiveSession ? () {} : null,
                      tooltip: 'Next chunk (Ctrl+→)',
                    ),
                  ],
                ),
                // Progress slider
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
                          value: position.inMilliseconds.toDouble(),
                          max: duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                          onChanged: hasActiveSession
                              ? (v) => ref
                                  .read(playbackPositionProvider.notifier)
                                  .state = Duration(milliseconds: v.toInt())
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

          // ── Speed & volume (right) ─────────────────────────
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
}
