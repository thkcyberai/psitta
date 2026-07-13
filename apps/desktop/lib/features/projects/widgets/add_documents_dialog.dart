import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/document.dart';
import '../../../data/providers/document_actions.dart';
import '../../../data/providers/providers.dart' show documentsProvider;
import '../../../l10n/app_localizations.dart';

/// Add existing Library files to a project.
///
/// Loads the writer's files, lets them pick the ones not already in this
/// project, and assigns each via [documentActionsProvider] — which fans the
/// change out to every sector (Library, Projects, Book Structure) so the
/// additions appear immediately. Mirrors adoptBlueprintFlow.
Future<void> addDocumentsToProjectFlow(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
}) async {
  final loc = AppLocalizations.of(context);
  List<Document> all;
  try {
    all = await ref.read(documentsProvider.future);
  } catch (e) {
    if (context.mounted) _snack(context, loc.addDocsLoadError('$e'));
    return;
  }
  if (!context.mounted) return;

  final candidates = all.where((d) => d.projectId != projectId).toList()
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  if (candidates.isEmpty) {
    _snack(context, loc.addDocsAllInProject);
    return;
  }

  final chosen = await showDialog<Set<String>>(
    context: context,
    builder: (ctx) => _AddDocumentsDialog(candidates: candidates),
  );
  if (chosen == null || chosen.isEmpty || !context.mounted) return;

  try {
    final actions = ref.read(documentActionsProvider);
    for (final id in chosen) {
      await actions.assignToProject(id, projectId);
    }
    if (context.mounted) {
      _snack(context, loc.addDocsAdded(chosen.length));
    }
  } catch (e) {
    if (context.mounted) _snack(context, loc.addDocsAddError('$e'));
  }
}

class _AddDocumentsDialog extends StatefulWidget {
  const _AddDocumentsDialog({required this.candidates});

  final List<Document> candidates;

  @override
  State<_AddDocumentsDialog> createState() => _AddDocumentsDialogState();
}

class _AddDocumentsDialogState extends State<_AddDocumentsDialog> {
  final Set<String> _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(loc.addDocsTitle),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: 440,
        height: 440,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.candidates.length,
          itemBuilder: (_, i) {
            final d = widget.candidates[i];
            final inOther = d.projectId != null;
            return CheckboxListTile(
              key: ValueKey('add-doc-${d.id}'),
              value: _selected.contains(d.id),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _selected.add(d.id);
                } else {
                  _selected.remove(d.id);
                }
              }),
              title: Text(
                d.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                inOther
                    ? '${d.sourceType.toUpperCase()} · ${loc.addDocsMovesFrom}'
                    : d.sourceType.toUpperCase(),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc.btnCancel),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: Text(_selected.isEmpty
              ? loc.btnAdd
              : loc.addDocsAddCount(_selected.length)),
        ),
      ],
    );
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
