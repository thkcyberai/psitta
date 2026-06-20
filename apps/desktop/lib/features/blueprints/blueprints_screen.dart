import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/psitta_tokens.dart';
import '../../data/models/blueprint.dart';
import '../../data/providers/blueprint_providers.dart';
import '../../widgets/library_breadcrumb.dart';
import 'blueprint_screen_state.dart';
import 'narrative_structure_tab.dart';
import 'widgets/blueprint_dialogs.dart';
import 'widgets/blueprint_guide_dialog.dart';
import 'widgets/part_tree_pane.dart';
import 'widgets/section_detail_pane.dart';

/// Blueprints screen — a full-width Writing Nook header over a two-pane body
/// (left: blueprint list grouped into Templates / My Blueprints; center: the
/// selected blueprint's section tree). The right detail panel and per-section
/// document counts remain deferred.
///
/// "Section" is the user-facing term for a tree node; the code keeps the data
/// layer's "part" terminology throughout.
class BlueprintsScreen extends ConsumerWidget {
  const BlueprintsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      child: Container(
      color: tokens.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 14, 28, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: LibraryBreadcrumb(current: 'Blueprints'),
            ),
          ),
          // ── Header
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 12),
            child: Row(
              children: [
                Icon(Icons.account_tree_outlined,
                    size: 26, color: scheme.onSurface),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Blueprints',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        'Design the structure of your book, and the narrative structure.',
                        style: TextStyle(
                            fontSize: 13, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  key: const ValueKey('new-blueprint-button'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Book Structure'),
                  onPressed: () => _createBlueprint(context, ref),
                ),
              ],
            ),
          ),
          // ── Tabs
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Book Structure'),
              Tab(text: 'Narrative Structure'),
              Tab(text: 'Diagram'),
            ],
          ),
          Divider(height: 1, color: tokens.divider),
          const Expanded(
            child: TabBarView(
              children: [
                _MyBlueprintsBody(),
                NarrativeStructureTab(),
                BlueprintGuideTab(),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _createBlueprint(BuildContext context, WidgetRef ref) async {
    final result = await showBlueprintFormDialog(
      context,
      title: 'New Book Structure',
      submitLabel: 'Create',
    );
    if (result == null) return;
    if (!context.mounted) return;
    final created = await runBlueprintMutation(
      context,
      () => ref.read(blueprintActionsProvider).createBlueprint(
            name: result.name,
            genre: result.genre,
            status: result.status,
          ),
    );
    if (created != null) {
      ref.read(selectedBlueprintIdProvider.notifier).state = created.id;
      ref.read(selectedPartIdProvider.notifier).state = null;
    }
  }
}

/// The "My Blueprints" tab — the three-pane body (list → section tree →
/// section detail).
class _MyBlueprintsBody extends StatelessWidget {
  const _MyBlueprintsBody();

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(width: 300, child: _BlueprintListPane()),
        VerticalDivider(width: 1, color: tokens.divider),
        const Expanded(child: PartTreePane()),
        VerticalDivider(width: 1, color: tokens.divider),
        const SizedBox(width: 312, child: SectionDetailPane()),
      ],
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
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 10, 12),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Couldn’t load blueprints.',
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
        data: (list) => list.isEmpty
            ? _buildEmptyState(context)
            : _buildList(context, ref, list, selectedId),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_tree_outlined,
              size: 52, color: scheme.onSurfaceVariant),
          const SizedBox(height: 14),
          Text('No blueprints yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Templates and your own blueprints will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
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
        const SizedBox(height: 4),
        if (templates.isNotEmpty) ...[
          const _BlueprintGroupHeader(label: 'Templates'),
          for (final b in templates)
            _BlueprintListCard(
              blueprint: b,
              isSelected: b.id == selectedId,
            ),
        ],
        if (mine.isNotEmpty) ...[
          const SizedBox(height: 10),
          const _BlueprintGroupHeader(label: 'My Books'),
          for (final b in mine)
            _BlueprintListCard(
              blueprint: b,
              isSelected: b.id == selectedId,
            ),
        ],
      ],
    );
  }
}

/// Maps a blueprint genre (wire value) to an illustration in assets/covers/.
/// Falls back to a generic cover for any unmapped/unknown genre.
String _coverForGenre(String genreWire) {
  switch (genreWire) {
    case 'Novel':
      return 'assets/covers/novel.png';
    case 'Memoir':
      return 'assets/covers/my_memoir.png';
    case 'Non-Fiction':
      return 'assets/covers/non_fiction.png';
    case 'Biography':
      return 'assets/covers/biography.png';
    case "Children's Picture Book":
      return 'assets/covers/childrens_book.png';
    case 'Workbook/How-To':
      return 'assets/covers/writing_nook.jpg';
    case 'Business Book':
      return 'assets/covers/code_desk.jpg';
    default:
      return 'assets/covers/my_first_book.png';
  }
}

/// Group header in the blueprint list pane: 'Templates' (built-in) and
/// 'My Books' (the user's own structures). Visual only.
class _BlueprintGroupHeader extends StatelessWidget {
  const _BlueprintGroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
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
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            if (ref.read(selectedBlueprintIdProvider) != blueprint.id) {
              ref.read(selectedBlueprintIdProvider.notifier).state =
                  blueprint.id;
              // Section ids are per-blueprint; drop any stale selection.
              ref.read(selectedPartIdProvider.notifier).state = null;
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: tokens.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? tokens.glow : tokens.border,
                width: isSelected ? 1.8 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Genre illustration banner.
                SizedBox(
                  height: 80,
                  width: double.infinity,
                  child: Image.asset(
                    _coverForGenre(blueprint.genre.wire),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: tokens.glow.withValues(alpha: 0.14),
                      alignment: Alignment.center,
                      child: Icon(Icons.account_tree_outlined,
                          color: tokens.glow),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              blueprint.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          // Owned Book Structures can be deleted from here;
                          // templates (isSystem) cannot.
                          if (!blueprint.isSystem)
                            SizedBox(
                              height: 22,
                              width: 22,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 16,
                                tooltip: 'Delete Book Structure',
                                icon: Icon(Icons.delete_outline,
                                    color: scheme.error),
                                onPressed: () => _delete(context, ref),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 9),
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
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDeleteDialog(
      context,
      title: 'Delete Book Structure?',
      message:
          'Delete "${blueprint.name}"? Its sections are permanently removed. '
          'This does not delete any documents.',
      confirmLabel: 'Delete',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(blueprintActionsProvider).deleteBlueprint(blueprint.id);
      if (ref.read(selectedBlueprintIdProvider) == blueprint.id) {
        ref.read(selectedBlueprintIdProvider.notifier).state = null;
        ref.read(selectedPartIdProvider.notifier).state = null;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeBlueprintError(e))),
        );
      }
    }
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.glow.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.glow.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}


// Narrative Structure UI lives in narrative_structure_tab.dart.
