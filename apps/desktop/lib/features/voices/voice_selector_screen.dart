import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../data/providers/providers.dart';
import '../../data/services/audio_service.dart';
import '../../data/services/preferences_service.dart';
import '../shell/widgets/player_bar.dart';
import 'widgets/voice_preview_card.dart';

class VoiceSelectorScreen extends ConsumerWidget {
  const VoiceSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final voicesAsync = ref.watch(voicesProvider);
    final selectedVoiceId = ref.watch(selectedVoiceIdProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Voices',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Choose a voice for document narration. Preview before selecting.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: voicesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text('Could not load voices', style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 4),
                    Text(error.toString(),
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(voicesProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (voices) => voices.isEmpty
                  ? Center(
                      child: Text('No voices available',
                          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = (constraints.maxWidth / 320).floor().clamp(1, 4);
                        return GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 2.8,
                          ),
                          itemCount: voices.length,
                          itemBuilder: (context, index) {
                            final v = voices[index];
                            return VoicePreviewCard(
                              voiceName: v.displayName,
                              voiceId: v.id,
                              language: v.language,
                              tier: v.tier,
                              gender: v.gender,
                              isSelected: v.id == selectedVoiceId,
                              onPreview: () {
                                // Preview: play a short sample with this voice
                                final audioService = ref.read(audioServiceProvider);
                                final docId = ref.read(activeDocumentIdProvider);
                                final chunkIds = ref.read(activeChunkIdsProvider);
                                if (docId != null && chunkIds.isNotEmpty) {
                                  audioService.playChunk(
                                    documentId: docId,
                                    chunkId: chunkIds.first,
                                    voiceId: v.id,
                                  );
                                }
                              },
                              onSelect: () {
                                ref.read(selectedVoiceIdProvider.notifier).select(v.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Voice set to ${v.displayName}'),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                    width: 280,
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
