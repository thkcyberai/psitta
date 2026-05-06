import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/plan_gate.dart';
import '../../data/providers/providers.dart';
import '../../data/services/preferences_service.dart';
import '../../widgets/voice_avatar.dart';

class VoiceSelectorScreen extends ConsumerWidget {
  const VoiceSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voicesAsync = ref.watch(voicesProvider);
    final selectedId = ref.watch(selectedVoiceIdProvider);
    final isPro = ref.watch(isProUserProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Settings'),
                  onPressed: () => context.go('/settings'),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Default Voice',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Select the voice used for new documents.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: voicesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (voices) => voices.isEmpty
                    ? const Center(child: Text('No voices available'))
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 1.1,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: voices.length,
                        itemBuilder: (context, i) {
                          final v = voices[i];
                          final isSelected = v.id == selectedId;
                          final isLocked =
                              !isPro && v.tier == 'premium';
                          return _VoiceCell(
                            displayName: v.displayName,
                            language: v.language,
                            gender: v.gender,
                            isSelected: isSelected,
                            isLocked: isLocked,
                            onTap: () {
                              if (isLocked) {
                                showUpgradeSnackbar(
                                  context,
                                  featureName: 'Premium voices',
                                );
                                return;
                              }
                              ref
                                  .read(selectedVoiceIdProvider.notifier)
                                  .select(v.id);
                              context.go('/settings');
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceCell extends StatelessWidget {
  const _VoiceCell({
    required this.displayName,
    required this.language,
    required this.gender,
    required this.isSelected,
    required this.isLocked,
    required this.onTap,
  });

  final String displayName;
  final String language;
  final String gender;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final cell = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isSelected
            ? cs.primaryContainer.withOpacity(0.6)
            : cs.surfaceContainerHighest.withOpacity(0.5),
        border: isSelected
            ? Border.all(color: cs.primary, width: 1)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          VoiceAvatar(
            voiceName: displayName,
            size: 110,
            variant: VoiceAvatarVariant.big,
            ringWidth: isSelected ? 3 : 2,
            ringColor: isSelected ? cs.primary : null,
          ),
          const SizedBox(height: 6),
          Text(
            displayName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            language,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Stack(
        children: [
          Opacity(opacity: isLocked ? 0.55 : 1.0, child: cell),
          if (isLocked)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline,
                        size: 11, color: cs.onPrimary),
                    const SizedBox(width: 3),
                    Text(
                      'Pro',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
