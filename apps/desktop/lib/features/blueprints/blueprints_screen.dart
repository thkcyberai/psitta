import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/psitta_tokens.dart';
import '../../data/models/blueprint.dart';
import '../../data/providers/blueprint_providers.dart';
import 'blueprint_screen_state.dart';
import 'widgets/part_tree_pane.dart';

/// Blueprints screen — three-pane layout (left: blueprint list, center: section
/// tree, right: deferred). This batch builds the left list and the center tree;
/// the right detail panel and per-section document counts are deferred.
///
/// "Section" is the user-facing term for a tree node; the code keeps the data
/// layer's "part" terminology throughout.
class BlueprintsScreen extends ConsumerWidget {
  const BlueprintsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: 320, child: _BlueprintListPane()),
          VerticalDivider(width: 1, color: tokens.divider),
          // Center pane: the selected blueprint's section tree.
          const Expanded(child: PartTreePane()),
        ],
      ),
    );
  }
}

// ── Left pane: blueprint list ────────────────────────────────────────────────

class _BlueprintListPane extends ConsumerWidget {
  const _BlueprintListPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(blueprintsListProvider);
    final selectedId = ref.watch(selectedBlueprintIdProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Blueprints',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Reusable structures for your writing.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) => list.isEmpty
                  ? _buildEmptyState(context)
                  : _buildList(context, ref, list, selectedId),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_tree_outlined,
              size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('No blueprints yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Templates and your own blueprints will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<BlueprintSummary> list,
    String? selectedId,
  ) {
    final templates = list.where((b) => b.isSystem).toList();
    final mine = list.where((b) => !b.isSystem).toList();
    // Display order = templates first, then the user's own. Auto-select the
    // first item when nothing is selected yet (post-frame to avoid mutating
    // provider state during build).
    final ordered = [...templates, ...mine];
    if (selectedId == null && ordered.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(selectedBlueprintIdProvider) == null) {
          ref.read(selectedBlueprintIdProvider.notifier).state =
              ordered.first.id;
        }
      });
    }

    return ListView(
      children: [
        if (templates.isNotEmpty) ...[
          const _GroupLabel('Templates'),
          ...templates.map(
            (b) => _BlueprintListCard(
              blueprint: b,
              isSelected: b.id == selectedId,
            ),
          ),
        ],
        if (mine.isNotEmpty) ...[
          if (templates.isNotEmpty) const SizedBox(height: 8),
          const _GroupLabel('My Blueprints'),
          ...mine.map(
            (b) => _BlueprintListCard(
              blueprint: b,
              isSelected: b.id == selectedId,
            ),
          ),
        ],
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _BlueprintListCard extends ConsumerWidget {
  const _BlueprintListCard({required this.blueprint, required this.isSelected});

  final BlueprintSummary blueprint;
  final bool isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: isSelected
            ? tokens.inputFill.withOpacity(0.55)
            : tokens.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(tokens.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (ref.read(selectedBlueprintIdProvider) != blueprint.id) {
              ref.read(selectedBlueprintIdProvider.notifier).state =
                  blueprint.id;
              // Section ids are per-blueprint; drop any stale selection.
              ref.read(selectedPartIdProvider.notifier).state = null;
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radius),
              border: Border.all(
                color: isSelected
                    ? tokens.glow.withOpacity(0.7)
                    : tokens.border.withOpacity(0.5),
                width: isSelected ? 1.4 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  blueprint.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _GenreChip(label: blueprint.genre.wire),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        blueprint.status.wire,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.glow.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.glow.withOpacity(0.35), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withOpacity(0.85),
        ),
      ),
    );
  }
}

