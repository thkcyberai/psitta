import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/blueprint.dart';
import '../../../data/providers/blueprint_providers.dart';
import '../../blueprints/widgets/blueprint_dialogs.dart'
    show confirmDeleteDialog, describeBlueprintError;
import 'adopt_blueprint_dialog.dart';
import 'adopted_blueprint_card.dart';

/// Blueprints tab: the project's adopted blueprints (reusing
/// AdoptedBlueprintCard) with per-card Set-as-Primary / Remove-from-Project
/// actions and the shared adopt picker. All mutations go through
/// blueprintActionsProvider (which owns invalidation); errors surface via
/// SnackBar.
class ProjectBlueprintsTab extends ConsumerWidget {
  const ProjectBlueprintsTab({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(projectBlueprintOverviewProvider(projectId));
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final adoptedIds = overviewAsync.valueOrNull == null
        ? <String>{}
        : {for (final bp in overviewAsync.valueOrNull!.blueprints) bp.id};

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Blueprints in this Project',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.icon(
              key: const ValueKey('blueprints-tab-add-button'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Blueprint to Project'),
              onPressed: () => adoptBlueprintFlow(
                context,
                ref,
                projectId: projectId,
                adoptedIds: adoptedIds,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        overviewAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
          data: (ov) {
            if (ov.blueprints.isEmpty) {
              return Text(
                'No blueprints in this project yet. '
                'Add one to structure your work.',
                style: TextStyle(color: muted),
              );
            }
            return Column(
              children: [
                for (final bp in ov.blueprints) ...[
                  AdoptedBlueprintCard(
                    overview: bp,
                    actions: _BlueprintCardMenu(projectId: projectId, blueprint: bp),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _BlueprintCardMenu extends ConsumerWidget {
  const _BlueprintCardMenu({required this.projectId, required this.blueprint});

  final String projectId;
  final BlueprintOverview blueprint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = Theme.of(context).colorScheme.error;
    return PopupMenuButton<String>(
      key: ValueKey('bp-menu-${blueprint.id}'),
      icon: const Icon(Icons.more_vert, size: 18),
      tooltip: 'More',
      onSelected: (value) {
        switch (value) {
          case 'set_primary':
            _setPrimary(context, ref);
            break;
          case 'remove':
            _remove(context, ref);
            break;
        }
      },
      itemBuilder: (_) => [
        if (!blueprint.isPrimary)
          const PopupMenuItem(
            value: 'set_primary',
            child: Row(children: [
              Icon(Icons.star_outline, size: 18),
              SizedBox(width: 8),
              Flexible(child: Text('Set as Primary')),
            ]),
          ),
        PopupMenuItem(
          value: 'remove',
          child: Row(children: [
            Icon(Icons.link_off, size: 18, color: error),
            const SizedBox(width: 8),
            Flexible(
              child: Text('Remove from Project', style: TextStyle(color: error)),
            ),
          ]),
        ),
      ],
    );
  }

  Future<void> _setPrimary(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(blueprintActionsProvider)
          .setPrimaryBlueprint(projectId, blueprint.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeBlueprintError(e))),
        );
      }
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDeleteDialog(
      context,
      title: 'Remove from Project?',
      message:
          'Remove "${blueprint.name}" from this project? The blueprint itself '
          'is not deleted.',
      confirmLabel: 'Remove',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref
          .read(blueprintActionsProvider)
          .unadoptBlueprint(projectId, blueprint.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeBlueprintError(e))),
        );
      }
    }
  }
}
