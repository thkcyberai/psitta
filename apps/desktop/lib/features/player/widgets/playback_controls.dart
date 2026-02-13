import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

/// Playback controls widget — reusable transport controls.
///
/// Used by both the player screen and the player bar.
/// Desktop-optimized: keyboard shortcut tooltips on each button.
class PlaybackControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onSkipForward;
  final VoidCallback onSkipBackward;
  final double iconSize;

  const PlaybackControls({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSkipForward,
    required this.onSkipBackward,
    this.iconSize = 38,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous),
          iconSize: iconSize * 0.6,
          onPressed: onSkipBackward,
          tooltip: 'Previous chunk (Ctrl+←)',
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(
            isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: AppColors.primary,
          ),
          iconSize: iconSize,
          onPressed: onPlayPause,
          tooltip: 'Play/Pause (Space)',
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.skip_next),
          iconSize: iconSize * 0.6,
          onPressed: onSkipForward,
          tooltip: 'Next chunk (Ctrl+→)',
        ),
      ],
    );
  }
}
