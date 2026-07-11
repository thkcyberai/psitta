import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/theme/colors.dart';
import '../../../core/extensions.dart';
import '../../../core/i18n/working_language.dart';
import '../../../data/models/voice.dart';
import '../../../data/providers/providers.dart';
import '../../../data/services/audio_service.dart';
import '../../../data/services/preferences_service.dart';
import '../../../widgets/voice_avatar.dart';
import '../../../l10n/app_localizations.dart';

/// Shared state for current document info in the player bar.
final currentDocTitleProvider = StateProvider<String?>((ref) => null);
final currentChunkIndexProvider = StateProvider<int>((ref) => 0);
final totalChunksProvider = StateProvider<int>((ref) => 0);

/// Current document and chunk IDs for audio loading.
final activeDocumentIdProvider = StateProvider<String?>((ref) => null);
final activeChunkIdsProvider = StateProvider<List<String>>((ref) => []);

/// When true, the player bar streams the active chunk via the backend
/// /audio/stream endpoint (Writing Nook) so playback starts within ~1s. Default
/// false → batch playback (Reading Nook). The Writing Desk flips this on while
/// it is the active surface and off when it is torn down.
final streamingPlaybackProvider = StateProvider<bool>((ref) => false);

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
    // When a sentence playlist is active, just_audio's position/duration are
    // relative to the current sentence clip. Source the scrubber from the
    // chunk-level ("chapter") model instead so it reads as one timeline.
    final sentencePlaylistActive =
        ref.watch(sentencePlaylistActiveProvider).valueOrNull ?? false;
    final position = sentencePlaylistActive
        ? (ref.watch(chapterPositionProvider).valueOrNull ?? Duration.zero)
        : (ref.watch(audioPositionProvider).valueOrNull ?? Duration.zero);
    final duration = sentencePlaylistActive
        ? (ref.watch(chapterDurationProvider).valueOrNull ??
            const Duration(minutes: 5))
        : (ref.watch(audioDurationProvider).valueOrNull ??
            const Duration(minutes: 5));
    final audioService = ref.watch(audioServiceProvider);
    final isSynthesizing =
        ref.watch(isSynthesizingProvider).valueOrNull ?? false;
    final loc = AppLocalizations.of(context);
    final selectedVoiceId = ref.watch(selectedVoiceIdProvider);
    final voiceDisplayName = ref.watch(voicesProvider).whenOrNull(
      data: (voices) {
        for (final v in voices) {
          if (v.id == selectedVoiceId) return v.displayName;
        }
        return null;
      },
    );
    // Narrators for the CURRENT working language only (language-locked, same as
    // the Voices screen). Powers the inline narrator menu so the writer can
    // switch voice without leaving the reader.
    final workingLang =
        WorkingLanguage.fromLocale(ref.watch(selectedLocaleProvider)) ??
            WorkingLanguage.englishUS;
    final languageVoices = ref
            .watch(voicesProvider)
            .valueOrNull
            ?.where((v) => v.language == workingLang.bcp47)
            .toList() ??
        const <Voice>[];

    // On voice change: in sentence-playlist mode, keep the reading position and
    // relaunch the current chunk with the new voice at the same sentence.
    // Otherwise fall back to a full reset (single-file path).
    ref.listen<String>(selectedVoiceIdProvider, (previous, next) {
      if (previous != null && previous != next) {
        final sentenceActive =
            ref.read(sentencePlaylistActiveProvider).valueOrNull ?? false;
        if (sentenceActive) {
          audioService.changeVoicePreservingPosition(next);
        } else {
          audioService.reset();
        }
      }
    });

    // Auto-advance to next chunk when the current one finishes.
    // In sentence-playlist mode the raw "completed" can fire when a single clip
    // fails mid-playlist — advancing on that wrongly jumps a chapter. So there
    // we ignore the raw signal and advance only on chunkCompletedProvider,
    // which fires ONLY when the last sentence genuinely finished.
    ref.listen<AsyncValue<PlayerState>>(audioPlayerStateProvider, (prev, next) {
      final state = next.valueOrNull;
      if (state != null &&
          state.processingState == ProcessingState.completed &&
          state.playing == false) {
        final sentenceActive =
            ref.read(sentencePlaylistActiveProvider).valueOrNull ?? false;
        if (!sentenceActive) _skipForward(ref, audioService);
      }
    });
    // Sentence-playlist mode: advance only on a genuine end-of-chunk.
    ref.listen<AsyncValue<int>>(chunkCompletedProvider, (prev, next) {
      if (next.valueOrNull != null &&
          next.valueOrNull != prev?.valueOrNull) {
        _skipForward(ref, audioService);
      }
    });

    return Container(
      color: isDark ? AppColors.playerBarDark : AppColors.playerBar,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (hasActiveSession && voiceDisplayName != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: languageVoices.length > 1
                  ? PopupMenuButton<String>(
                      tooltip: loc.playerChangeNarrator,
                      offset: const Offset(0, -12),
                      itemBuilder: (context) => [
                        for (final v in languageVoices)
                          PopupMenuItem<String>(
                            value: v.id,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  v.id == selectedVoiceId
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  size: 16,
                                  color: v.id == selectedVoiceId
                                      ? AppColors.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 10),
                                Text(v.displayName),
                                const SizedBox(width: 8),
                                Text(
                                  v.gender == 'male' ? '♂' : '♀',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      onSelected: (id) {
                        if (id != selectedVoiceId) {
                          ref
                              .read(selectedVoiceIdProvider.notifier)
                              .select(id);
                        }
                      },
                      child: VoiceAvatar(
                        voiceName: voiceDisplayName,
                        size: 32,
                        variant: VoiceAvatarVariant.small,
                      ),
                    )
                  : VoiceAvatar(
                      voiceName: voiceDisplayName,
                      size: 32,
                      variant: VoiceAvatarVariant.small,
                    ),
            ),
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
                        [
                          if (voiceDisplayName != null) voiceDisplayName,
                          totalChunks > 0
                              ? loc.playerChapterOf(
                                  chunkIndex + 1, totalChunks)
                              : loc.playerNoChapters,
                        ].join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  )
                : Text(
                    loc.playerNoDocument,
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
                    Tooltip(
                      message: 'Skip Backward  Ctrl+\u2190',
                      waitDuration: const Duration(milliseconds: 600),
                      child: IconButton(
                        icon: const Icon(Icons.skip_previous, size: 22),
                        onPressed: hasActiveSession
                            ? () => _skipBackward(ref, audioService)
                            : null,
                      ),
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
                          : Tooltip(
                              message: isPlaying
                                  ? 'Pause  Space'
                                  : 'Play  Space',
                              waitDuration: const Duration(milliseconds: 600),
                              child: IconButton(
                                icon: Icon(
                                  isPlaying
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_filled,
                                  size: 38,
                                  color:
                                      hasActiveSession ? AppColors.primary : null,
                                ),
                                onPressed: hasActiveSession
                                    ? () {
                                        // Narration is a Read-mode action: if
                                        // the writer is editing in the Desk,
                                        // block play and ask them to switch to
                                        // Read mode.
                                        if (_blockNarrationInWriteMode(
                                            context, ref)) {
                                          return;
                                        }
                                        final chunkIds =
                                            ref.read(activeChunkIdsProvider);
                                        final docId =
                                            ref.read(activeDocumentIdProvider);
                                        final idx = ref
                                            .read(currentChunkIndexProvider);
                                        final voiceId =
                                            ref.read(selectedVoiceIdProvider);
                                        final activeChunkId = idx < chunkIds.length
                                            ? chunkIds[idx]
                                            : null;
                                        final chunksData = docId == null
                                            ? null
                                            : ref
                                                .read(chunksProvider(docId))
                                                .valueOrNull;
                                        final firstChunkTextLength =
                                            activeChunkId == null ||
                                                    chunksData == null
                                                ? null
                                                : ((chunksData['chunks']
                                                                as List<dynamic>?)
                                                            ?.elementAtOrNull(
                                                                idx)
                                                        as Map<String,
                                                            dynamic>?)?[
                                                    'text_content']
                                                ?.toString()
                                                .length;
                                        debugPrint(
                                          '[PDF PERF][play] ui_click doc=$docId chunkIndex=$idx chunkCount=${chunkIds.length} voice=$voiceId isPlaying=$isPlaying',
                                        );
                                        if (activeChunkId != null &&
                                            firstChunkTextLength != null) {
                                          debugPrint(
                                            '[PDF PERF][play] current_chunk_text_length doc=$docId chunk=$activeChunkId chars=$firstChunkTextLength',
                                          );
                                        }

                                        final shouldStartRequestedChunk =
                                            !isPlaying &&
                                                docId != null &&
                                                idx < chunkIds.length &&
                                                !audioService.hasPreparedChunk(
                                                  documentId: docId,
                                                  chunkId: chunkIds[idx],
                                                  voiceId: voiceId,
                                                );
                                        debugPrint(
                                          '[PDF PERF][play] ui_branch doc=$docId chunk=${idx < chunkIds.length ? chunkIds[idx] : 'out_of_range'} mode=${shouldStartRequestedChunk ? 'start_chunk' : 'resume_toggle'} prepared=${docId != null && idx < chunkIds.length ? audioService.hasPreparedChunk(documentId: docId, chunkId: chunkIds[idx], voiceId: voiceId) : false}',
                                        );

                                        if (shouldStartRequestedChunk) {
                                          final speed =
                                              ref.read(selectedSpeedProvider);
                                          final volume =
                                              ref.read(selectedVolumeProvider);
                                          _startChunk(
                                            ref,
                                            audioService,
                                            documentId: docId,
                                            chunkId: chunkIds[idx],
                                            voiceId: voiceId,
                                            speed: speed,
                                            volume: volume,
                                          );
                                        } else {
                                          audioService.togglePlayPause();
                                        }
                                      }
                                    : null,
                              ),
                            ),
                    ),

                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Skip Forward  Ctrl+\u2192',
                      waitDuration: const Duration(milliseconds: 600),
                      child: IconButton(
                        icon: const Icon(Icons.skip_next, size: 22),
                        onPressed: hasActiveSession
                            ? () => _skipForward(ref, audioService)
                            : null,
                      ),
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
                              ? (v) => sentencePlaylistActive
                                  ? audioService.seekChapter(
                                      Duration(milliseconds: v.toInt()))
                                  : audioService
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

  /// Narration is a Read-mode action. When the writer is in the Writing Desk's
  /// write mode ([isInlineEditingProvider]), block playback and tell them to
  /// switch to Read mode. Returns true when playback was blocked.
  bool _blockNarrationInWriteMode(BuildContext context, WidgetRef ref) {
    if (!ref.read(isInlineEditingProvider)) return false;
    final loc = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.readModeRequiredTitle),
        content: Text(loc.readModeRequiredBody),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.readModeRequiredOk),
          ),
        ],
      ),
    );
    return true;
  }

  /// Start a chunk via streaming (Writing Nook) or batch (Reading Nook) based
  /// on [streamingPlaybackProvider]. Single seam so all call sites pick the
  /// right path without duplicating the branch.
  Future<bool> _startChunk(
    WidgetRef ref,
    AudioService audioService, {
    required String documentId,
    required String chunkId,
    required String voiceId,
    required double speed,
    required double volume,
  }) {
    if (ref.read(streamingPlaybackProvider)) {
      return audioService.playChunkStreaming(
        documentId: documentId,
        chunkId: chunkId,
        voiceId: voiceId,
        speed: speed,
        volume: volume,
      );
    }
    return audioService.playChunk(
      documentId: documentId,
      chunkId: chunkId,
      voiceId: voiceId,
      speed: speed,
      volume: volume,
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
        _startChunk(
          ref,
          audioService,
          documentId: docId,
          chunkId: chunkIds[nextIdx],
          voiceId: voiceId,
          speed: speed,
          volume: volume,
        )
            .then((_) {
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
        _startChunk(
          ref,
          audioService,
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
  const _SpeedButton({
    required this.enabled,
    required this.ref,
    required this.audioService,
  });

  final bool enabled;
  final WidgetRef ref;
  final AudioService audioService;

  @override
  Widget build(BuildContext context) {
    final speed = ref.watch(selectedSpeedProvider);
    final theme = Theme.of(context);
    const speeds = [1.0, 1.5, 2.0];

    return PopupMenuButton<double>(
      enabled: enabled,
      tooltip: 'Playback Speed',
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
  const _VolumeButton({
    required this.enabled,
    required this.ref,
    required this.audioService,
  });

  final bool enabled;
  final WidgetRef ref;
  final AudioService audioService;

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
  const _VolumeSlider({
    required this.ref,
    required this.audioService,
    required this.onChanged,
  });

  final WidgetRef ref;
  final AudioService audioService;
  final VoidCallback onChanged;

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
