import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import 'widgets/voice_preview_card.dart';

/// Voice Selector Screen — browse and preview available TTS voices.
///
/// Desktop layout: responsive grid with audio preview on hover/click.
/// Voices are grouped by language with tier badges (free/premium).
class VoiceSelectorScreen extends StatelessWidget {
  const VoiceSelectorScreen({super.key});

  // TODO: Replace with Riverpod provider + API data
  static const _voices = [
    {'name': 'Aria', 'id': 'en-US-AriaNeural', 'lang': 'English (US)', 'tier': 'free', 'gender': 'Female'},
    {'name': 'Guy', 'id': 'en-US-GuyNeural', 'lang': 'English (US)', 'tier': 'free', 'gender': 'Male'},
    {'name': 'Jenny', 'id': 'en-US-JennyNeural', 'lang': 'English (US)', 'tier': 'free', 'gender': 'Female'},
    {'name': 'Davis', 'id': 'en-US-DavisNeural', 'lang': 'English (US)', 'tier': 'premium', 'gender': 'Male'},
    {'name': 'Sonia', 'id': 'en-GB-SoniaNeural', 'lang': 'English (UK)', 'tier': 'free', 'gender': 'Female'},
    {'name': 'Ryan', 'id': 'en-GB-RyanNeural', 'lang': 'English (UK)', 'tier': 'free', 'gender': 'Male'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Voices',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a voice for document narration. Preview before selecting.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount =
                    (constraints.maxWidth / 320).floor().clamp(1, 4);
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.8,
                  ),
                  itemCount: _voices.length,
                  itemBuilder: (context, index) {
                    final v = _voices[index];
                    return VoicePreviewCard(
                      voiceName: v['name']!,
                      voiceId: v['id']!,
                      language: v['lang']!,
                      tier: v['tier']!,
                      gender: v['gender']!,
                      onPreview: () {},
                      onSelect: () {},
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
