import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/psitta_tokens.dart';
import '../../../data/models/document.dart';
import '../../../data/providers/project_providers.dart';
import '../../../data/providers/providers.dart'
    show projectRepositoryProvider, projectsProvider;
import '../../blueprints/narrative_structures.dart' show kNarrativeStructures;

/// Opens the Scene Map for a project — the "story spine": each beat with the
/// files that cover it underneath, plus an Unassigned group. Files are moved
/// between beats via a per-file menu (the beats appear once, as the structure).
Future<void> showSceneMap(BuildContext context, {required String projectId}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SceneMapDialog(projectId: projectId),
  );
}

/// Entry point from a project-agnostic surface (the Blueprints gallery): pick a
/// book, then open its Scene Map. Auto-opens when there's exactly one project.
Future<void> pickProjectAndShowSceneMap(
    BuildContext context, WidgetRef ref) async {
  final dynamic projects;
  try {
    projects = await ref.read(projectsProvider.future);
  } catch (_) {
    return;
  }
  if (!context.mounted) return;

  if (projects.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('No projects yet'),
        content: const Text(
            'Create a project and attach a narrative, then you can map its '
            'scenes here.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK')),
        ],
      ),
    );
    return;
  }

  String? chosen = projects.length == 1 ? projects.first.id as String : null;
  chosen ??= await showDialog<String>(
    context: context,
    builder: (_) => SimpleDialog(
      title: const Text('Map scenes for which book?'),
      children: [
        for (final p in projects)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(p.id as String),
            child: Text(p.name as String),
          ),
      ],
    ),
  );

  if (chosen != null && context.mounted) {
    await showSceneMap(context, projectId: chosen);
  }
}

String _structureName(String? key) {
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

class _SceneMapDialog extends ConsumerWidget {
  const _SceneMapDialog({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final detailAsync = ref.watch(projectDetailProvider(projectId));

    return Dialog(
      backgroundColor: tokens.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: detailAsync.when(
          loading: () => const SizedBox(
              height: 220, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load the project.',
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          data: (p) {
            final beats = p.narrativeBeats ?? const <String>[];
            final docsAsync = ref.watch(projectDocumentsProvider(projectId));
            final docs = docsAsync.valueOrNull ?? const <Document>[];

            if (beats.isEmpty) {
              return _Shell(
                title: 'Scene Map',
                subtitle: null,
                onClose: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                  child: Text(
                    'This book has no narrative yet. Attach one in '
                    'Blueprints → Narrative Structure, then map your scenes here.',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, height: 1.45),
                  ),
                ),
              );
            }

            // Group files by beat; anything else is Unassigned.
            final byBeat = <String, List<Document>>{for (final b in beats) b: []};
            final unassigned = <Document>[];
            for (final d in docs) {
              final b = d.narrativeBeat;
              if (b != null && byBeat.containsKey(b)) {
                byBeat[b]!.add(d);
              } else {
                unassigned.add(d);
              }
            }
            final covered = beats.where((b) => byBeat[b]!.isNotEmpty).length;
            final name = _structureName(p.narrativeStructureKey);
            final variant = p.narrativeVariant;
            final subtitle =
                '${variant != null ? '$name · $variant' : name}  ·  '
                '$covered of ${beats.length} beats covered';

            return _Shell(
              title: 'Scene Map',
              subtitle: subtitle,
              onClose: () => Navigator.of(context).pop(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                children: [
                  for (var i = 0; i < beats.length; i++)
                    _BeatGroup(
                      index: i,
                      beat: beats[i],
                      files: byBeat[beats[i]]!,
                      projectId: projectId,
                      beats: beats,
                    ),
                  if (unassigned.isNotEmpty)
                    _BeatGroup(
                      index: null,
                      beat: 'Unassigned',
                      files: unassigned,
                      projectId: projectId,
                      beats: beats,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({
    required this.title,
    required this.subtitle,
    required this.onClose,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.hub_outlined, size: 22, color: tokens.glow),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w800)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: TextStyle(
                              fontSize: 12.5, color: scheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close, size: 20),
                onPressed: onClose,
              ),
            ],
          ),
        ),
        Divider(height: 1, color: tokens.divider),
        Flexible(child: child),
      ],
    );
  }
}

class _BeatGroup extends StatelessWidget {
  const _BeatGroup({
    required this.index,
    required this.beat,
    required this.files,
    required this.projectId,
    required this.beats,
  });

  /// 0-based beat index, or null for the "Unassigned" group.
  final int? index;
  final String beat;
  final List<Document> files;
  final String projectId;
  final List<String> beats;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isUnassigned = index == null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isUnassigned)
                Icon(Icons.inbox_outlined,
                    size: 18, color: scheme.onSurfaceVariant)
              else
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: files.isEmpty
                        ? scheme.onSurface.withValues(alpha: 0.10)
                        : tokens.glow.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Text('${index! + 1}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: files.isEmpty
                              ? scheme.onSurfaceVariant
                              : tokens.glow)),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(beat,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isUnassigned ? scheme.onSurfaceVariant : null)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (files.isEmpty && !isUnassigned)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 2, bottom: 2),
              child: Text('No file yet',
                  style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7))),
            )
          else
            for (final f in files)
              _FileRow(
                doc: f,
                projectId: projectId,
                beats: beats,
                currentBeat: isUnassigned ? null : beat,
              ),
        ],
      ),
    );
  }
}

class _FileRow extends ConsumerWidget {
  const _FileRow({
    required this.doc,
    required this.projectId,
    required this.beats,
    required this.currentBeat,
  });

  final Document doc;
  final String projectId;
  final List<String> beats;
  final String? currentBeat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;

    Future<void> assign(String? beat) async {
      try {
        await ref
            .read(projectRepositoryProvider)
            .setDocumentNarrativeBeat(projectId, doc.id, beat: beat);
        ref.invalidate(projectDocumentsProvider(projectId));
        ref.invalidate(projectActivityProvider(projectId));
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Couldn't save — check your connection and "
                  'try again.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(left: 32, top: 3, bottom: 3),
      child: Row(
        children: [
          Icon(Icons.description_outlined,
              size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(doc.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          PopupMenuButton<String?>(
            tooltip: 'Move to beat',
            position: PopupMenuPosition.under,
            onSelected: (v) => assign(v),
            itemBuilder: (_) => [
              CheckedPopupMenuItem<String?>(
                value: null,
                checked: currentBeat == null,
                child: const Text('Unassigned'),
              ),
              const PopupMenuDivider(),
              for (final b in beats)
                CheckedPopupMenuItem<String?>(
                  value: b,
                  checked: currentBeat == b,
                  child: Text(b, overflow: TextOverflow.ellipsis),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: tokens.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Move',
                      style: TextStyle(
                          fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down,
                      size: 16, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
