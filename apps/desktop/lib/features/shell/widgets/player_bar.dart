import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/theme/colors.dart';
import '../../../core/extensions.dart';
import '../../../data/services/audio_service.dart';
import '../../../data/services/preferences_service.dart';

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
    final position =
        ref.watch(audioPositionProvider).valueOrNull ?? Duration.zero;
    final duration = ref.watch(audioDurationProvider).valueOrNull ??
        const Duration(minutes: 5);
    final audioService = ref.watch(audioServiceProvider);
    final isSynthesizing =
        ref.watch(isSynthesizingProvider).valueOrNull ?? false;

    // Reset audio when voice changes — forces reload with new voice
    ref.listen<String>(selectedVoiceIdProvider, (previous, next) {
      if (previous != null && previous != next) {
        audioService.reset();
      }
    });

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

                    // Play/Pause button — shows spinner when synthesizing
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: isSynthesizing
                          ? const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: Icon(
                                isPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                                size: 38,
                                color: hasActiveSession
                                    ? AppColors.primary
                                    : null,
                              ),
                              onPressed: hasActiveSession
                                  ? () {
                                      if (!isPlaying && (audioService.duration == null || audioService.position == Duration.zero)) {
                                        final chunkIds = ref
                                            .read(activeChunkIdsProvider);
                                        final docId = ref
                                            .read(activeDocumentIdProvider);
                                        final idx = ref.read(
                                            currentChunkIndexProvider);
                                        if (docId != null &&
                                            idx < chunkIds.length) {
                                          final voiceId = ref
                                              .read(selectedVoiceIdProvider);
                                          final speed = ref.read(selectedSpeedProvider);
                                          final volume = ref.read(selectedVolumeProvider);
                                          audioService.playChunk(
                                            documentId: docId,
                                            chunkId: chunkIds[idx],
                                            voiceId: voiceId,
                                            speed: speed,
                                            volume: volume,
                                          );
                                        }
                                      } else {
                                        audioService.togglePlayPause();
                                      }
                                    }
                                  : null,
                              tooltip: 'Play/Pause (Space)',
                            ),
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
                _SpeedButton(
                  enabled: hasActiveSession,
                  ref: ref,
                  audioService: audioService,
                ),
                _VolumeButton(
                  enabled: hasActiveSession,
                  ref: ref,
                  audioService: audioService,
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
      final nextIdx = current + 1;
      ref.read(currentChunkIndexProvider.notifier).state = nextIdx;
      final docId = ref.read(activeDocumentIdProvider);
      if (docId != null) {
        final voiceId = ref.read(selectedVoiceIdProvider);
        final speed = ref.read(selectedSpeedProvider);
        final volume = ref.read(selectedVolumeProvider);
        audioService.playChunk(
          documentId: docId,
          chunkId: chunkIds[nextIdx],
          voiceId: voiceId,
          speed: speed,
          volume: volume,
        ).then((_) {
          // Prefetch the chunk after next
          if (nextIdx + 1 < chunkIds.length) {
            audioService.prefetchChunk(
              documentId: docId,
              chunkId: chunkIds[nextIdx + 1],
              voiceId: voiceId,
            );
          }
        });
      }
    }
  }

  void _skipBackward(WidgetRef ref, AudioService audioService) {
    final chunkIds = ref.read(activeChunkIdsProvider);
    final current = ref.read(currentChunkIndexProvider);
    if (current > 0) {
      final prevIdx = current - 1;
      ref.read(currentChunkIndexProvider.notifier).state = prevIdx;
      final docId = ref.read(activeDocumentIdProvider);
      if (docId != null) {
        final voiceId = ref.read(selectedVoiceIdProvider);
        final speed = ref.read(selectedSpeedProvider);
        final volume = ref.read(selectedVolumeProvider);
        audioService.playChunk(
          documentId: docId,
          chunkId: chunkIds[prevIdx],
          voiceId: voiceId,
          speed: speed,
          volume: volume,
        );
      }
    }
  }
}

/// Speed selector button — tap to cycle, long-press for menu.
class _SpeedButton extends StatelessWidget {
  final bool enabled;
  final WidgetRef ref;
  final AudioService audioService;

  const _SpeedButton({
    required this.enabled,
    required this.ref,
    required this.audioService,
  });

  @override
  Widget build(BuildContext context) {
    final speed = ref.watch(selectedSpeedProvider);
    final theme = Theme.of(context);
    final speeds = const [1.0, 1.5, 2.0];

    return PopupMenuButton<double>(
      enabled: enabled,
      tooltip: 'Playback speed',
      offset: const Offset(0, -280),
      onSelected: (newSpeed) async {
        await ref.read(selectedSpeedProvider.notifier).select(newSpeed);
        await audioService.setSpeed(newSpeed);
      },
      itemBuilder: (context) => speeds
          .map(
            (s) => PopupMenuItem<double>(
              value: s,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    child: s == speed
                        ? const Icon(Icons.check,
                            size: 18, color: AppColors.primary)
                        : null,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${s}x',
                    style: TextStyle(
                      fontWeight:
                          s == speed ? FontWeight.bold : FontWeight.normal,
                      color: s == speed ? AppColors.primary : null,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '${speed}x',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: speed != 1.0 ? AppColors.primary : null,
          ),
        ),
      ),
    );
  }
}



/// Volume button with vertical slider popup.
class _VolumeButton extends StatefulWidget {
  final bool enabled;
  final WidgetRef ref;
  final AudioService audioService;

  const _VolumeButton({
    required this.enabled,
    required this.ref,
    required this.audioService,
  });

  @override
  State<_VolumeButton> createState() => _VolumeButtonState();
}

class _VolumeButtonState extends State<_VolumeButton> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  void _toggleOverlay() {
    if (_overlayEntry != null) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Tap anywhere to dismiss
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Volume slider positioned above the button
          CompositedTransformFollower(
            link: _layerLink,
            targetAnchor: Alignment.topCenter,
            followerAnchor: Alignment.bottomCenter,
            offset: const Offset(0, -8),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 48,
                height: 180,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.2),
                  ),
                ),
                child: _VolumeSlider(
                  ref: widget.ref,
                  audioService: widget.audioService,
                  onChanged: () {
                    // Update the icon when volume changes
                    if (mounted) setState(() {});
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final volume = widget.ref.watch(selectedVolumeProvider);
    IconData icon;
    if (volume <= 0.0) {
      icon = Icons.volume_off;
    } else if (volume < 0.5) {
      icon = Icons.volume_down;
    } else {
      icon = Icons.volume_up;
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: widget.enabled ? _toggleOverlay : null,
        tooltip: 'Volume',
      ),
    );
  }
}

/// Vertical volume slider used inside the overlay.
/// Uses Consumer to ensure rebuilds when volume state changes,
/// since OverlayEntry lives outside the normal Riverpod widget tree.
class _VolumeSlider extends StatefulWidget {
  final WidgetRef ref;
  final AudioService audioService;
  final VoidCallback onChanged;

  const _VolumeSlider({
    required this.ref,
    required this.audioService,
    required this.onChanged,
  });

  @override
  State<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<_VolumeSlider> {
  late double _localVolume;

  @override
  void initState() {
    super.initState();
    _localVolume = widget.ref.read(selectedVolumeProvider);
  }

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: 3,
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: 4,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          activeTrackColor: AppColors.primary,
          inactiveTrackColor: AppColors.primary.withOpacity(0.2),
          thumbColor: AppColors.primary,
        ),
        child: Slider(
          value: _localVolume,
          min: 0.0,
          max: 1.0,
          onChanged: (v) {
            setState(() => _localVolume = v);
            widget.ref.read(selectedVolumeProvider.notifier).set(v);
            widget.audioService.player.setVolume(v);
            widget.onChanged();
          },
        ),
      ),
    );
  }
}
