import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/psitta_tokens.dart';
import '../../../data/models/document.dart';
import '../../../data/providers/project_providers.dart';
import '../../blueprints/narrative_structures.dart';
import 'scene_map_dialog.dart';

/// Project → Narrative tab.
///
/// Shows the story shape THIS book follows — the writer's saved pick (structure
/// + Best-For + the chosen beats). Read-only here; the writer chooses or changes
/// it from Blueprints → Narrative Structure ("Use this Structure"). This is also
/// where the AI Story-Coach will surface deviation nudges in a later phase.
class ProjectNarrativeTab extends ConsumerWidget {
  const ProjectNarrativeTab({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(projectDetailProvider(projectId));
    return detail.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load the narrative: $e')),
      data: (p) {
        final hasNarrative =
            p.narrativeVariant != null || p.narrativeStructureKey != null;
        if (!hasNarrative) return const _NarrativeEmpty();
        return _NarrativeView(
          projectId: projectId,
          structureKey: p.narrativeStructureKey,
          variant: p.narrativeVariant,
          beats: p.narrativeBeats ?? const [],
        );
      },
    );
  }
}

/// Map a stored catalog key back to its display name (e.g. 'hero_s_journey' →
/// "Hero's Journey"); falls back to a prettified slug if not found.
String _structureDisplayName(String? key) {
  if (key == null || key.isEmpty) return 'Narrative';
  for (final s in kNarrativeStructures) {
    if (s.key == key) return s.name;
  }
  return key
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

class _NarrativeView extends StatelessWidget {
  const _NarrativeView({
    required this.projectId,
    required this.structureKey,
    required this.variant,
    required this.beats,
  });

  final String projectId;
  final String? structureKey;
  final String? variant;
  final List<String> beats;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final name = _structureDisplayName(structureKey);

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
      children: [
        Row(
          children: [
            Icon(Icons.auto_stories_outlined, size: 22, color: tokens.glow),
            const SizedBox(width: 10),
            Text('This book follows',
                style: TextStyle(
                    fontSize: 13, color: scheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(name,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            if (variant != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: tokens.glow.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(variant!,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.glow)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${beats.length} beats chosen. Change this in Blueprints → Narrative '
          'Structure.',
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        Divider(height: 1, color: tokens.divider),
        const SizedBox(height: 14),
        Text('YOUR BEATS',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: scheme.onSurfaceVariant)),
        const SizedBox(height: 10),
        _YourBeats(projectId: projectId, beats: beats),
        const SizedBox(height: 22),
        Divider(height: 1, color: tokens.divider),
        const SizedBox(height: 14),
        _MapScenesButton(projectId: projectId, beats: beats),
      ],
    );
  }
}

/// Compact entry to the Scene Map dialog (the grouped "story spine"). Replaces
/// the per-file dropdown list so the beats aren't repeated on every row.
class _MapScenesButton extends ConsumerWidget {
  const _MapScenesButton({required this.projectId, required this.beats});

  final String projectId;
  final List<String> beats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final docs = ref.watch(projectDocumentsProvider(projectId)).valueOrNull;
    final covered = docs == null
        ? null
        : beats.where((b) => docs.any((d) => d.narrativeBeat == b)).length;

    return InkWell(
      onTap: () => showSceneMap(context, projectId: projectId),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: tokens.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          children: [
            Icon(Icons.hub_outlined, size: 20, color: tokens.glow),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Scene Map',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    covered == null
                        ? 'Map each file to the beat it covers.'
                        : '$covered of ${beats.length} beats covered · '
                            'tap to map your scenes',
                    style:
                        TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, size: 16, color: tokens.glow),
          ],
        ),
      ),
    );
  }
}

/// The chosen beats as the readable "spine": each beat with the file(s) mapped
/// to it underneath, clickable to open in the Writing Desk. Assigning happens in
/// the Scene Map dialog; this is the at-a-glance view.
class _YourBeats extends ConsumerWidget {
  const _YourBeats({required this.projectId, required this.beats});

  final String projectId;
  final List<String> beats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs =
        ref.watch(projectDocumentsProvider(projectId)).valueOrNull ??
            const <Document>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < beats.length; i++)
          _BeatRow(
            index: i,
            beat: beats[i],
            projectId: projectId,
            files: [
              for (final d in docs)
                if (d.narrativeBeat == beats[i]) d,
            ],
          ),
      ],
    );
  }
}

class _BeatRow extends StatelessWidget {
  const _BeatRow({
    required this.index,
    required this.beat,
    required this.files,
    required this.projectId,
  });

  final int index;
  final String beat;
  final List<Document> files;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final hasFiles = files.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hasFiles
                      ? tokens.glow.withValues(alpha: 0.16)
                      : scheme.onSurface.withValues(alpha: 0.07),
                  shape: BoxShape.circle,
                ),
                child: Text('${index + 1}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color:
                            hasFiles ? tokens.glow : scheme.onSurfaceVariant)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(beat,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
          for (final f in files)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 4),
              child: Tooltip(
                message: 'Open in the Writing Desk',
                child: InkWell(
                  onTap: () => context
                      .go('/writing-desk/${f.id}?projectId=$projectId'),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined,
                            size: 14, color: tokens.glow),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(f.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.glow)),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.north_east,
                            size: 12,
                            color: tokens.glow.withValues(alpha: 0.7)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NarrativeEmpty extends StatelessWidget {
  const _NarrativeEmpty();

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
              const Text('Narrative Structure',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'This book doesn\'t follow a narrative yet. Choose one in '
                'Blueprints → Narrative Structure and tap "Use this Structure" '
                'to attach it to this book — your Book Structure stays untouched.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, height: 1.5, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
