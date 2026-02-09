import 'package:flutter/material.dart';

class PlaybackControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onSkipForward;
  final VoidCallback onSkipBackward;
  const PlaybackControls({super.key, required this.isPlaying,
    required this.onPlayPause, required this.onSkipForward, required this.onSkipBackward});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton(icon: const Icon(Icons.skip_previous), onPressed: onSkipBackward),
      IconButton(icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
        iconSize: 64, onPressed: onPlayPause),
      IconButton(icon: const Icon(Icons.skip_next), onPressed: onSkipForward),
    ]);
  }
}
