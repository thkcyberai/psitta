import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/blueprint.dart';
import '../../../data/providers/blueprint_providers.dart';
import '../../blueprints/widgets/blueprint_dialogs.dart' show describeBlueprintError;

/// Shows the blueprint picker with two tabs — "My Blueprints" (your own) and
/// "Templates" (built-in starters) — and, on selection, adopts it into the
/// project via blueprintActionsProvider (which owns invalidation). System
/// templates cannot be adopted directly, so they are cloned into a user-owned
/// copy first and the clone is adopted. Errors surface via SnackBar. Reused by
/// the Overview and Blueprints tabs.
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
    if (context.mounted) _snack(context, 'Failed to load Book Structures: $e');
    return;
  }
  if (!context.mounted) return;

  // Templates already cloned into this project carry the template's id in
  // their sourceTemplateId. Hide those templates so picking the same one
  // twice can't create duplicate blueprints on the project.
  final usedTemplateIds = all
      .where((b) => adoptedIds.contains(b.id))
      .map((b) => b.sourceTemplateId)
      .whereType<String>()
      .toSet();

  final available = all.where((b) => !adoptedIds.contains(b.id)).toList();
  final own = available.where((b) => !b.isSystem).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  final templates = available
      .where((b) => b.isSystem && !usedTemplateIds.contains(b.id))
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  if (own.isEmpty && templates.isEmpty) {
    _snack(context,
        'No Book Structures to add. Create one in the Blueprints sector first.');
    return;
  }

  final chosen = await showDialog<BlueprintSummary>(
    context: context,
    builder: (ctx) => _BlueprintPickerDialog(own: own, templates: templates),
  );
  if (chosen == null || !context.mounted) return;

  try {
    final actions = ref.read(blueprintActionsProvider);
    // System templates must be cloned into a user-owned copy before adoption.
    final blueprintId = chosen.isSystem
        ? (await actions.cloneBlueprint(chosen.id)).id
        : chosen.id;
    await actions.adoptBlueprint(projectId, blueprintId);
  } catch (e) {
    if (context.mounted) _snack(context, describeBlueprintError(e));
  }
}

/// Tabbed picker: "My Blueprints" vs "Templates". Pops the chosen
/// [BlueprintSummary] (or null on Cancel).
class _BlueprintPickerDialog extends StatelessWidget {
  const _BlueprintPickerDialog({required this.own, required this.templates});

  final List<BlueprintSummary> own;
  final List<BlueprintSummary> templates;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Choose a Book Structure'),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: 380,
        height: 440,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                labelColor: scheme.primary,
                unselectedLabelColor: scheme.onSurfaceVariant,
                indicatorColor: scheme.primary,
                tabs: [
                  Tab(text: 'My Book Structures (${own.length})'),
                  Tab(text: 'Templates (${templates.length})'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _BlueprintList(
                      items: own,
                      emptyText: 'No Book Structures of your own yet.\n'
                          'Create one in the Blueprints sector, or start from a template.',
                    ),
                    _BlueprintList(
                      items: templates,
                      emptyText: 'No templates available.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _BlueprintList extends StatelessWidget {
  const _BlueprintList({required this.items, required this.emptyText});

  final List<BlueprintSummary> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final b = items[i];
        return ListTile(
          key: ValueKey('adopt-candidate-${b.id}'),
          leading: Icon(
            b.isSystem
                ? Icons.auto_stories_outlined
                : Icons.account_tree_outlined,
          ),
          title: Text(b.name),
          subtitle: Text(b.genre.wire),
          onTap: () => Navigator.of(context).pop(b),
        );
      },
    );
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}
