import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/document.dart';
import '../../../data/providers/document_actions.dart';
import '../../../data/providers/providers.dart' show documentsProvider;

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
  List<Document> all;
  try {
    all = await ref.read(documentsProvider.future);
  } catch (e) {
    if (context.mounted) _snack(context, 'Failed to load files: $e');
    return;
  }
  if (!context.mounted) return;

  final candidates = all.where((d) => d.projectId != projectId).toList()
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  if (candidates.isEmpty) {
    _snack(context, 'All your files are already in this project.');
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
      _snack(
        context,
        'Added ${chosen.length} file${chosen.length == 1 ? '' : 's'} '
        'to the project.',
      );
    }
  } catch (e) {
    if (context.mounted) _snack(context, 'Could not add files: $e');
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
    return AlertDialog(
      title: const Text('Add files to this project'),
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
                    ? '${d.sourceType.toUpperCase()} · moves from another project'
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: Text(_selected.isEmpty ? 'Add' : 'Add ${_selected.length}'),
        ),
      ],
    );
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
