import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/blueprint.dart';
import '../../../data/providers/blueprint_providers.dart';
import '../../blueprints/widgets/blueprint_dialogs.dart' show describeBlueprintError;

/// Shows the adopt picker (owned, non-system blueprints not already adopted)
/// and, on selection, adopts it into the project via blueprintActionsProvider
/// (which owns invalidation). Reused by the Overview and Blueprints tabs.
/// Errors surface via SnackBar.
Future<void> adoptBlueprintFlow(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
  required Set<String> adoptedIds,
}) async {
  List<BlueprintSummary> all;
  try {
    all = await ref.read(blueprintsListProvider.future);
  } catch (e) {
    if (context.mounted) _snack(context, 'Failed to load blueprints: $e');
    return;
  }
  if (!context.mounted) return;

  final candidates =
      all.where((b) => !b.isSystem && !adoptedIds.contains(b.id)).toList();
  if (candidates.isEmpty) {
    _snack(context, 'No blueprints to add. Create one in Blueprints first.');
    return;
  }

  final chosen = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Add Blueprint to Project'),
      content: SizedBox(
        width: 360,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: candidates.length,
          itemBuilder: (_, i) {
            final b = candidates[i];
            return ListTile(
              key: ValueKey('adopt-candidate-${b.id}'),
              leading: const Icon(Icons.account_tree_outlined),
              title: Text(b.name),
              subtitle: Text(b.genre.wire),
              onTap: () => Navigator.of(ctx).pop(b.id),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
  if (chosen == null || !context.mounted) return;

  try {
    await ref.read(blueprintActionsProvider).adoptBlueprint(projectId, chosen);
  } catch (e) {
    if (context.mounted) _snack(context, describeBlueprintError(e));
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}
