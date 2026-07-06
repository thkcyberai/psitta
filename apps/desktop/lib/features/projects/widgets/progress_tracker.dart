import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/psitta_tokens.dart';
import '../../../data/models/document.dart';
import '../../../data/providers/project_providers.dart';
import '../../../data/providers/providers.dart' show projectsProvider;
import '../../blueprints/narrative_i18n.dart';
import '../../../l10n/app_localizations.dart';

bool _isCovered(List<Document> docs, String beat) =>
    docs.any((d) => d.narrativeBeat == beat);

/// Compact inline progress bar: one segment per beat, filled for covered beats,
/// with a "X of N beats covered · Y% mapped" readout. Reads the same Scene Map
/// data, so it fills in as the writer maps (and writes) their scenes.
class ProgressTrackerBar extends ConsumerWidget {
  const ProgressTrackerBar({
    super.key,
    required this.projectId,
    required this.beats,
  });

  final String projectId;
  final List<String> beats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (beats.isEmpty) return const SizedBox.shrink();

    final docs = ref.watch(projectDocumentsProvider(projectId)).valueOrNull ??
        const <Document>[];
    final covered = beats.where((b) => _isCovered(docs, b)).length;
    final pct = (covered * 100 / beats.length).round();
    final loc = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Cumulative fill: the first [covered] segments are lit and grow
            // left-to-right as more beats get covered (a running progress meter,
            // not a per-beat map — the checklist below shows which beats).
            for (var i = 0; i < beats.length; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOut,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i < covered
                        ? tokens.glow
                        : scheme.onSurface.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              if (i < beats.length - 1) const SizedBox(width: 4),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          loc.progressBeatsMapped(covered, beats.length, pct),
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Opens the Progress Tracker dialog for a project (bar + per-beat checklist).
Future<void> showProgressTracker(BuildContext context,
    {required String projectId}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ProgressDialog(projectId: projectId),
  );
}

/// Entry from the project-agnostic Blueprints gallery: pick a book, then show
/// its Progress Tracker. Auto-opens when there's exactly one project.
Future<void> pickProjectAndShowProgress(
    BuildContext context, WidgetRef ref) async {
  final dynamic projects;
  try {
    projects = await ref.read(projectsProvider.future);
  } catch (_) {
    return;
  }
  if (!context.mounted) return;
  final loc = AppLocalizations.of(context);

  if (projects.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.noProjectsYet),
        content: Text(loc.progressCreateProjectBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.actionOk)),
        ],
      ),
    );
    return;
  }

  String? chosen = projects.length == 1 ? projects.first.id as String : null;
  chosen ??= await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(loc.trackProgressWhichBook),
      children: [
        for (final p in projects)
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(p.id as String),
            child: Text(p.name as String),
          ),
      ],
    ),
  );

  if (chosen != null && context.mounted) {
    await showProgressTracker(context, projectId: chosen);
  }
}

class _ProgressDialog extends ConsumerWidget {
  const _ProgressDialog({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final detailAsync = ref.watch(projectDetailProvider(projectId));

    return Dialog(
      backgroundColor: tokens.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: detailAsync.when(
          loading: () => const SizedBox(
              height: 200, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text(loc.couldNotLoadProject,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          data: (p) {
            final beats = p.narrativeBeats ?? const <String>[];
            final docs =
                ref.watch(projectDocumentsProvider(projectId)).valueOrNull ??
                    const <Document>[];
            final covered = beats.where((b) => _isCovered(docs, b)).length;
            final pct = beats.isEmpty ? 0 : (covered * 100 / beats.length).round();

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.track_changes_outlined,
                          size: 22, color: tokens.glow),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.featureProgressTracker,
                                style: const TextStyle(
                                    fontSize: 19, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(loc.progressBeatsArc(covered, beats.length, pct),
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: loc.actionClose,
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: tokens.divider),
                if (beats.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      loc.progressNoNarrative,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, height: 1.45),
                    ),
                  )
                else
                  Flexible(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                      children: [
                        ProgressTrackerBar(projectId: projectId, beats: beats),
                        const SizedBox(height: 16),
                        for (var i = 0; i < beats.length; i++)
                          _BeatStatus(
                            index: i,
                            beat: beats[i],
                            done: _isCovered(docs, beats[i]),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BeatStatus extends StatelessWidget {
  const _BeatStatus({
    required this.index,
    required this.beat,
    required this.done,
  });

  final int index;
  final String beat;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: done ? tokens.glow : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Text('${index + 1}',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurfaceVariant)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(beatLabel(context, beat),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: done ? scheme.onSurface : scheme.onSurfaceVariant)),
          ),
          Text(done ? loc.statusCovered : loc.statusEmpty,
              style: TextStyle(
                  fontSize: 11.5,
                  color: done ? tokens.glow : scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
