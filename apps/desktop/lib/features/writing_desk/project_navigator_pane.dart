import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/psitta_tokens.dart';
import '../../data/models/blueprint.dart';
import '../../data/models/blueprint_enums.dart';
import '../../data/models/document.dart';
import '../../data/models/project_detail.dart';
import '../../data/providers/blueprint_providers.dart';
import '../../data/providers/project_providers.dart';

/// Left-rail navigator for the Writing Desk.
///
/// Shows the project's blueprint structure alongside placed and unplaced
/// documents. The user can assign unplaced docs to sections directly from
/// here. [projectId] may be null when the screen is opened outside a project
/// context — the guard state handles that gracefully.
class ProjectNavigatorPane extends ConsumerStatefulWidget {
  const ProjectNavigatorPane({
    super.key,
    required this.documentId,
    this.projectId,
  });

  final String documentId;
  final String? projectId;

  @override
  ConsumerState<ProjectNavigatorPane> createState() =>
      _ProjectNavigatorPaneState();
}

class _ProjectNavigatorPaneState extends ConsumerState<ProjectNavigatorPane> {
  String? _selectedBlueprintId;

  @override
  Widget build(BuildContext context) {
    if (widget.projectId == null) {
      return const _NullProjectGuard();
    }
    return _ProjectNavigatorBody(
      projectId: widget.projectId!,
      documentId: widget.documentId,
      selectedBlueprintId: _selectedBlueprintId,
      onBlueprintSelected: (id) => setState(() => _selectedBlueprintId = id),
    );
  }
}

// ── Null-project guard ────────────────────────────────────────────────────────

class _NullProjectGuard extends StatelessWidget {
  const _NullProjectGuard();

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    return Container(
      color: tokens.surface2,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Text(
        'Open from a project to see the structure',
        key: const ValueKey('desk-navigator-null-guard'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Project navigator body ─────────────────────────────────────────────────────

class _ProjectNavigatorBody extends ConsumerWidget {
  const _ProjectNavigatorBody({
    required this.projectId,
    required this.documentId,
    required this.selectedBlueprintId,
    required this.onBlueprintSelected,
  });

  final String projectId;
  final String documentId;
  final String? selectedBlueprintId;
  final void Function(String?) onBlueprintSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync =
        ref.watch(projectBlueprintOverviewProvider(projectId));
    final docsAsync = ref.watch(projectDocumentsProvider(projectId));
    final placementsAsync = ref.watch(projectPlacementsProvider(projectId));

    // Merge the three async values: only render the content when all are data.
    return overviewAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (overview) => docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (docs) => placementsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (placements) =>
              _buildContent(context, ref, overview, docs, placements),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ProjectBlueprintOverview overview,
    List<Document> docs,
    List<ProjectPlacement> placements,
  ) {
    final tokens = PsittaTokens.of(context);
    final blueprints = overview.blueprints;

    // Resolve the active blueprint — default to primary, fallback to first.
    BlueprintOverview? selected;
    if (blueprints.isNotEmpty) {
      selected = blueprints.firstWhere(
        (b) => b.id == selectedBlueprintId,
        orElse: () => blueprints.firstWhere(
          (b) => b.isPrimary,
          orElse: () => blueprints.first,
        ),
      );
    }

    final placedDocIds = placements.map((p) => p.documentId).toSet();
    final unplacedDocs =
        docs.where((d) => !placedDocIds.contains(d.id)).toList();

    return ColoredBox(
      color: tokens.surface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Blueprint selector (only when 2+ blueprints) ────────────────
          if (blueprints.length > 1)
            _BlueprintSelector(
              blueprints: blueprints,
              selectedId: selected?.id,
              onChanged: onBlueprintSelected,
            ),
          // ── Part tree or empty hint ────────────────────────────────────
          Expanded(
            child: selected == null
                ? _NoBlueprintsHint()
                : _PartTree(
                    parts: selected.parts,
                    placements: placements,
                    docs: docs,
                    unplacedDocs: unplacedDocs,
                    projectId: projectId,
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Blueprint selector ────────────────────────────────────────────────────────

class _BlueprintSelector extends StatelessWidget {
  const _BlueprintSelector({
    required this.blueprints,
    required this.selectedId,
    required this.onChanged,
  });

  final List<BlueprintOverview> blueprints;
  final String? selectedId;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: DropdownButtonFormField<String>(
        key: const ValueKey('desk-blueprint-selector'),
        value: selectedId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Blueprint',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(),
        ),
        items: blueprints
            .map((b) => DropdownMenuItem(
                  value: b.id,
                  child: Text(b.name, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

// ── No-blueprints hint ────────────────────────────────────────────────────────

class _NoBlueprintsHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No blueprints adopted.\nAdd one in the Blueprints tab.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ── Part tree ─────────────────────────────────────────────────────────────────

class _PartTree extends StatelessWidget {
  const _PartTree({
    required this.parts,
    required this.placements,
    required this.docs,
    required this.unplacedDocs,
    required this.projectId,
  });

  final List<PartOverviewNode> parts;
  final List<ProjectPlacement> placements;
  final List<Document> docs;
  final List<Document> unplacedDocs;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    _flatten(context, parts, items, 0);

    if (unplacedDocs.isNotEmpty) {
      items.add(const _SectionHeader(
        key: ValueKey('desk-unassigned-header'),
        label: 'Unassigned documents',
      ));
      for (final doc in unplacedDocs) {
        items.add(_UnplacedDocTile(
          key: ValueKey('desk-unplaced-${doc.id}'),
          doc: doc,
          parts: parts,
          projectId: projectId,
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      children: items,
    );
  }

  void _flatten(
    BuildContext context,
    List<PartOverviewNode> nodes,
    List<Widget> out,
    int depth,
  ) {
    for (final part in nodes) {
      final partPlacements =
          placements.where((p) => p.partId == part.id).toList();
      final partDocs = docs
          .where((d) => partPlacements.any((p) => p.documentId == d.id))
          .toList();
      out.add(_SectionTile(
        part: part,
        depth: depth,
        placements: partPlacements,
        docs: partDocs,
      ));
      _flatten(context, part.children, out, depth + 1);
    }
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

// ── Section tile ──────────────────────────────────────────────────────────────

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.part,
    required this.depth,
    required this.placements,
    required this.docs,
  });

  final PartOverviewNode part;
  final int depth;
  final List<ProjectPlacement> placements;
  final List<Document> docs;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('desk-section-${part.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: 12.0 + depth * 16.0,
            right: 12,
            top: 5,
            bottom: 5,
          ),
          child: Row(
            children: [
              _ReadinessDot(readiness: part.readiness),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  part.name,
                  key: ValueKey('desk-section-name-${part.id}'),
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (part.documentCount > 0)
                Text(
                  '${part.documentCount}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
            ],
          ),
        ),
        // Inline placed-doc sublist.
        for (final doc in docs)
          _PlacedDocTile(
            key: ValueKey('desk-placed-doc-${doc.id}'),
            doc: doc,
            placement:
                placements.firstWhere((p) => p.documentId == doc.id),
            indent: 12.0 + depth * 16.0 + 24,
          ),
      ],
    );
  }
}

// ── Readiness dot — derived from theme; no hardcoded decorative colors ────────

class _ReadinessDot extends StatelessWidget {
  const _ReadinessDot({required this.readiness});
  final Readiness readiness;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (readiness) {
      Readiness.ready => scheme.primary,
      Readiness.inProgress => scheme.secondary,
      Readiness.empty => scheme.outline.withOpacity(0.35),
      Readiness.unknown => scheme.outline.withOpacity(0.15),
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ── Placed doc tile ───────────────────────────────────────────────────────────

class _PlacedDocTile extends StatelessWidget {
  const _PlacedDocTile({
    super.key,
    required this.doc,
    required this.placement,
    required this.indent,
  });

  final Document doc;
  final ProjectPlacement placement;
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: indent, right: 12, top: 2, bottom: 2),
      child: Row(
        children: [
          Icon(Icons.article_outlined,
              size: 14,
              color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              doc.title,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            placement.role.wire,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Unplaced doc tile ─────────────────────────────────────────────────────────

class _UnplacedDocTile extends ConsumerWidget {
  const _UnplacedDocTile({
    super.key,
    required this.doc,
    required this.parts,
    required this.projectId,
  });

  final Document doc;
  final List<PartOverviewNode> parts;
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Icon(Icons.article_outlined,
              size: 14,
              color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              doc.title,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            key: ValueKey('desk-assign-${doc.id}'),
            onPressed: () =>
                _showAssignDialog(context, ref),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignDialog(
      BuildContext context, WidgetRef ref) async {
    final flat = <PartOverviewNode>[];
    _flattenParts(parts, flat);

    final chosen = await showDialog<PartOverviewNode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign to Section'),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final part in flat)
                ListTile(
                  key: ValueKey('desk-assign-section-${part.id}'),
                  title: Text(part.name),
                  onTap: () => Navigator.of(ctx).pop(part),
                ),
            ],
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

    if (chosen == null) return;
    if (!context.mounted) return;

    final actions = ref.read(blueprintActionsProvider);
    await actions.setPlacement(
      doc.id,
      chosen.id,
      Role.mainContent,
      projectId: projectId,
    );
  }

  void _flattenParts(List<PartOverviewNode> nodes, List<PartOverviewNode> out) {
    for (final n in nodes) {
      out.add(n);
      _flattenParts(n.children, out);
    }
  }
}
