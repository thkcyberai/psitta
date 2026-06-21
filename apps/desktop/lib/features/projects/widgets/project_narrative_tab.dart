import 'package:flutter/material.dart';

import '../../../core/theme/psitta_tokens.dart';

/// Project → Narrative tab.
///
/// The home for the story shape *this book* follows — the chosen structure
/// (e.g. the Hero's Journey), its audience (Best For), and the beats. The pick
/// + attach flow and its persisted, project-scoped data land with the
/// project-narrative backend work; until then this is the honest placeholder so
/// the surface lives exactly where writers expect it, beside Book Structure.
class ProjectNarrativeTab extends StatelessWidget {
  const ProjectNarrativeTab({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_stories_outlined, size: 40, color: tokens.glow),
              const SizedBox(height: 14),
              const Text(
                'Narrative Structure',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'The story shape this book follows will live here — the '
                'structure (e.g. the Hero\'s Journey), its audience, and the '
                'beats. Browse and choose one in Blueprints → Narrative '
                'Structure. Linking it to your book arrives soon.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, height: 1.5, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: tokens.glow.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Coming soon',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: tokens.glow),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
