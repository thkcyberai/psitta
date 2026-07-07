import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/plan_gate.dart';
import '../../core/i18n/working_language.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/psitta_tokens.dart';
import '../../data/providers/providers.dart';
import '../../data/services/preferences_service.dart';
import '../../widgets/voice_avatar.dart';

/// Voices — pick the default narration voice. Look-and-feel matches the rest
/// of the Writing Nook (Library / Scribbles / Whispers). All voices work via
/// the TTS fallback chain; premium voices are gated behind Pro.
class VoiceSelectorScreen extends ConsumerWidget {
  const VoiceSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final voicesAsync = ref.watch(voicesProvider);
    final selectedId = ref.watch(selectedVoiceIdProvider);
    final isPro = ref.watch(isProUserProvider);
    // Voices are language-locked: only the current working language's voices
    // are offered, so a writer can never pick (or narrate with) a voice from
    // another language. Exact BCP-47 match keeps pt-BR and pt-PT separate.
    final workingLang =
        WorkingLanguage.fromLocale(ref.watch(selectedLocaleProvider)) ??
            WorkingLanguage.englishUS;

    return Container(
      color: tokens.surface,
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.record_voice_over_outlined,
                  size: 26, color: scheme.onSurface),
              const SizedBox(width: 10),
              Text(loc.navVoices,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            loc.voicesSubtitle,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: voicesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(loc.voicesLoadError,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
              data: (allVoices) {
                final voices = allVoices
                    .where((v) => v.language == workingLang.bcp47)
                    .toList();
                if (voices.isEmpty) {
                  return Center(
                    child: Text(loc.voicesNone,
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  );
                }
                return GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 0.92,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: voices.length,
                  itemBuilder: (context, i) {
                    final v = voices[i];
                    final isSelected = v.id == selectedId;
                    final isLocked = !isPro && v.tier == 'premium';
                    return _VoiceCard(
                      displayName: v.displayName,
                      language: v.language,
                      gender: v.gender,
                      isSelected: isSelected,
                      isLocked: isLocked,
                      tokens: tokens,
                      onTap: () {
                        if (isLocked) {
                          showUpgradeSnackbar(
                            context,
                            featureName: loc.featPremiumVoices,
                          );
                          return;
                        }
                        ref
                            .read(selectedVoiceIdProvider.notifier)
                            .select(v.id);
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(
                            content: Text(loc.voicesDefaultSet(v.displayName)),
                          ));
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceCard extends StatelessWidget {
  const _VoiceCard({
    required this.displayName,
    required this.language,
    required this.gender,
    required this.isSelected,
    required this.isLocked,
    required this.tokens,
    required this.onTap,
  });

  final String displayName;
  final String language;
  final String gender;
  final bool isSelected;
  final bool isLocked;
  final PsittaTokens tokens;
  final VoidCallback onTap;

  String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

  String _genderLabel(AppLocalizations loc) {
    switch (gender.toLowerCase()) {
      case 'female':
        return loc.genderFemale;
      case 'male':
        return loc.genderMale;
      default:
        return _cap(gender);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final sub = [
      language,
      if (gender.isNotEmpty) _genderLabel(loc),
    ].where((s) => s.isNotEmpty).join(' · ');

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      decoration: BoxDecoration(
        color:
            isSelected ? tokens.glow.withValues(alpha: 0.10) : tokens.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? tokens.glow : tokens.border,
          width: isSelected ? 1.6 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: tokens.glow.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          VoiceAvatar(
            voiceName: displayName,
            size: 92,
            variant: VoiceAvatarVariant.big,
            ringWidth: isSelected ? 3 : 2,
            ringColor: isSelected ? tokens.glow : null,
          ),
          const SizedBox(height: 10),
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            Opacity(opacity: isLocked ? 0.55 : 1.0, child: card),
            if (isSelected && !isLocked)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration:
                      BoxDecoration(color: tokens.glow, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
            if (isLocked)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tokens.glow,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 11, color: Colors.white),
                      SizedBox(width: 3),
                      Text(
                        'Pro',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
