import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/concept_style.dart';
import '../../core/theme/psitta_tokens.dart';
import 'summarize_it_panel.dart';
import '../../data/models/blueprint.dart';
import '../../data/models/blueprint_enums.dart';
import '../../data/models/project_detail.dart';
import '../../data/providers/blueprint_providers.dart';
import '../../data/providers/project_providers.dart';
import '../../data/providers/providers.dart';
import '../../data/providers/document_actions.dart';
import '../projects/widgets/adopt_blueprint_dialog.dart';

/// Right-rail context pane for the Writing Desk.
///
/// Shows where the current document sits in the project's blueprint structure
/// (PlacementContextCard), the primary blueprint's progress (ProgressCard),
/// quick document actions (QuickActionsCard), and a Summarize It stub panel.
///
/// [projectId] may be null when the desk is opened without a project — the
/// null guard handles that case gracefully.
class DocumentContextPane extends ConsumerWidget {
  const DocumentContextPane({
    super.key,
    required this.documentId,
    this.projectId,
  });

  final String documentId;
  final String? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);
    return ColoredBox(
      color: tokens.surface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top context (progress + placement) is sized to its own content.
          if (projectId == null)
            ColoredBox(
              color: tokens.surface2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _UnplacedContextCard(documentId: documentId),
              ),
            )
          else
            _ContextPaneBody(
              documentId: documentId,
              projectId: projectId!,
            ),
          const Divider(height: 1),
          // Summarize-It claims the remaining rail space (the area freed when
          // the actions moved into the overflow menu). minHeight makes the card
          // fill the space; the scroll view keeps long summaries contained.
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 24).clamp(0, 4000),
                  ),
                  child: SummarizeItPanel(documentId: documentId),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Context pane body ─────────────────────────────────────────────────────────

class _ContextPaneBody extends ConsumerWidget {
  const _ContextPaneBody({
    required this.documentId,
    required this.projectId,
  });

  final String documentId;
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);
    final placementsAsync = ref.watch(projectPlacementsProvider(projectId));
    final overviewAsync =
        ref.watch(projectBlueprintOverviewProvider(projectId));

    return ColoredBox(
      key: const ValueKey('desk-context-pane-body'),
      color: tokens.surface2,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        children: [
          // ── Placement card ───────────────────────────────────────────────
          placementsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (placements) {
              final placement = placements
                  .where((p) => p.documentId == documentId)
                  .firstOrNull;
              if (placement == null) {
                return _UnplacedContextCard(
                  documentId: documentId,
                  projectId: projectId,
                  overviewAsync: overviewAsync,
                );
              }
              return _PlacementContextCard(
                placement: placement,
                overviewAsync: overviewAsync,
                projectId: projectId,
                documentId: documentId,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Placement context card ────────────────────────────────────────────────────

class _PlacementContextCard extends ConsumerStatefulWidget {
  const _PlacementContextCard({
    required this.placement,
    required this.overviewAsync,
    required this.projectId,
    required this.documentId,
  });

  final ProjectPlacement placement;
  final AsyncValue<ProjectBlueprintOverview> overviewAsync;
  final String projectId;
  final String documentId;

  @override
  ConsumerState<_PlacementContextCard> createState() =>
      _PlacementContextCardState();
}

class _PlacementContextCardState extends ConsumerState<_PlacementContextCard> {
  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final placement = widget.placement;
    final projectName =
        ref.watch(projectDetailProvider(widget.projectId)).valueOrNull?.name;

    return _RailCard(
      key: const ValueKey('desk-placement-card'),
      tokens: tokens,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  'PLACED IN',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                ),
              ),
              _DocActionsMenu(
                documentId: widget.documentId,
                projectId: widget.projectId,
                overviewAsync: widget.overviewAsync,
                placement: widget.placement,
              ),
            ],
          ),
          const SizedBox(height: 6),
          _PlacedRow(
            concept: DeskConcept.project,
            value: projectName ?? '—',
            onTap: () {
              final pn = projectName;
              context.go(pn != null
                  ? '/projects/${widget.projectId}'
                      '?projectName=${Uri.encodeComponent(pn)}'
                  : '/projects/${widget.projectId}');
            },
          ),
          const SizedBox(height: 10),
          _PlacedRow(
            concept: DeskConcept.blueprint,
            value: placement.blueprintName,
            onTap: () => context.go('/blueprints'),
          ),
          const SizedBox(height: 10),
          _PlacedRow(
            concept: DeskConcept.part,
            value: placement.partName,
            valueKey: const ValueKey('desk-placement-section-name'),
          ),
          const SizedBox(height: 10),
          _PlacedRow(
            concept: DeskConcept.role,
            value: placement.role.wire,
            valueKey: const ValueKey('desk-placement-role'),
          ),
        ],
      ),
    );
  }

}

// ── Unplaced / no-project context card ────────────────────────────────────────
//
// Mirrors the placed card's 4-row layout (Project / Blueprint / Part / Role) so
// the rail looks consistent even before a document is placed — unknown rows read
// "Not assigned". The actions menu shows only when the document is in a project.

class _UnplacedContextCard extends ConsumerWidget {
  const _UnplacedContextCard({
    required this.documentId,
    this.projectId,
    this.overviewAsync,
  });

  final String documentId;
  final String? projectId;
  final AsyncValue<ProjectBlueprintOverview>? overviewAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final pid = projectId;
    final inProject = pid != null;
    final projectName = inProject
        ? ref.watch(projectDetailProvider(pid)).valueOrNull?.name
        : null;
    // Adopted blueprint(s) + sections drive the guidance and the action.
    final overview = overviewAsync?.valueOrNull;
    final blueprintNames =
        overview?.blueprints.map((b) => b.name).toList() ?? const <String>[];
    final flatParts = <PartOverviewNode>[];
    if (overview != null) {
      for (final bp in overview.blueprints) {
        _flatten(bp.parts, flatParts);
      }
    }
    final hasSections = flatParts.isNotEmpty;

    void chooseBlueprint() => adoptBlueprintFlow(
          context,
          ref,
          projectId: pid!,
          adoptedIds:
              overview?.blueprints.map((b) => b.id).toSet() ?? const {},
        );

    final bodyStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        );

    return _RailCard(
      key: const ValueKey('desk-unplaced-card'),
      tokens: tokens,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'PLACED IN',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                ),
              ),
              if (inProject && overviewAsync != null)
                _DocActionsMenu(
                  documentId: documentId,
                  projectId: pid,
                  overviewAsync: overviewAsync!,
                ),
            ],
          ),
          const SizedBox(height: 6),
          _PlacedRow(
            concept: DeskConcept.project,
            value: projectName ?? (inProject ? '—' : 'Not in a project'),
            onTap: inProject
                ? () {
                    final pn = projectName;
                    context.go(pn != null
                        ? '/projects/$pid?projectName=${Uri.encodeComponent(pn)}'
                        : '/projects/$pid');
                  }
                : null,
          ),
          const SizedBox(height: 10),
          // This file is not placed in any blueprint, so its Blueprint link is
          // "Not assigned" — even when the PROJECT has adopted blueprints
          // (those are project-level, not this file's). The project's
          // blueprints still drive the placement guidance + action below.
          _PlacedRow(
            concept: DeskConcept.blueprint,
            value: 'Not assigned',
          ),
          const SizedBox(height: 10),
          _PlacedRow(
            concept: DeskConcept.part,
            value: 'Not assigned',
          ),
          const SizedBox(height: 10),
          _PlacedRow(
            concept: DeskConcept.role,
            value: 'Not assigned',
          ),
          const SizedBox(height: 12),
          if (!inProject)
            Text(
              'Not in a project yet. Add this file to a project to organize it.',
              style: bodyStyle,
            )
          else if (!hasSections) ...[
            Text(
              'Step 1 — choose a Book Structure for your book. '
              'Then you can place this file in one of its sections.',
              style: bodyStyle,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('desk-placedin-choose-blueprint'),
                onPressed: chooseBlueprint,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Choose a Book Structure'),
              ),
            ),
          ] else ...[
            Text(
              'Step 2 — this file isn\'t in a section yet. '
              'Place it in a ${blueprintNames.join(', ')} section to finish.',
              style: bodyStyle,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('desk-placedin-place-section'),
                onPressed: () => _placeInSection(context, ref, flatParts),
                icon: const Icon(Icons.playlist_add_check, size: 18),
                label: const Text('Place in a section'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static void _flatten(
      List<PartOverviewNode> nodes, List<PartOverviewNode> out) {
    for (final n in nodes) {
      out.add(n);
      _flatten(n.children, out);
    }
  }

  Future<void> _placeInSection(
    BuildContext context,
    WidgetRef ref,
    List<PartOverviewNode> parts,
  ) async {
    final chosen = await showDialog<PartOverviewNode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Place in a Section'),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final part in parts)
                ListTile(
                  key: ValueKey('desk-place-section-${part.id}'),
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
    final pid = projectId;
    if (chosen == null || pid == null || !context.mounted) return;
    await ref.read(blueprintActionsProvider).setPlacement(
          documentId,
          chosen.id,
          Role.mainContent,
          projectId: pid,
        );
  }
}

// ── Document actions overflow menu ────────────────────────────────────────────

class _DocActionsMenu extends ConsumerStatefulWidget {
  const _DocActionsMenu({
    required this.documentId,
    required this.projectId,
    required this.overviewAsync,
    this.placement,
  });

  final String documentId;
  final String projectId;
  final AsyncValue<ProjectBlueprintOverview> overviewAsync;
  final ProjectPlacement? placement;

  @override
  ConsumerState<_DocActionsMenu> createState() => _DocActionsMenuState();
}

class _DocActionsMenuState extends ConsumerState<_DocActionsMenu> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_busy) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return PopupMenuButton<String>(
      key: const ValueKey('desk-doc-actions-menu'),
      tooltip: 'Actions',
      icon: Icon(Icons.more_vert, size: 20, color: scheme.onSurfaceVariant),
      onSelected: (value) {
        switch (value) {
          case 'move':
            _moveSection(context);
          case 'role':
            _changeRole(context);
          case 'remove':
            _removePlacement(context);
          case 'movetosection':
            _moveToSection(context);
          case 'download':
            _download(context);
          case 'delete':
            _delete(context);
        }
      },
      itemBuilder: (context) => [
        if (widget.placement != null) ...[
          const PopupMenuItem(value: 'move', child: Text('Move section')),
          const PopupMenuItem(value: 'role', child: Text('Change role')),
          PopupMenuItem(
            value: 'remove',
            child: Text('Remove', style: TextStyle(color: scheme.error)),
          ),
          const PopupMenuDivider(),
        ] else ...[
          const PopupMenuItem(
            value: 'movetosection',
            child: Text('Move to section'),
          ),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem(value: 'download', child: Text('Download')),
        PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: scheme.error)),
        ),
      ],
    );
  }

  Future<void> _moveSection(BuildContext context) async {
    final overview = widget.overviewAsync.valueOrNull;
    final placement = widget.placement;
    if (overview == null || placement == null) return;

    if (overview.blueprints.isEmpty) return;

    final scheme = Theme.of(context).colorScheme;
    final chosen = await showDialog<PartOverviewNode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to Book Structure / section'),
        content: SizedBox(
          width: 340,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final bp in overview.blueprints) ...[
                // Blueprint group header.
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                  child: Row(
                    children: [
                      Icon(DeskConcept.blueprint.icon,
                          size: 16, color: DeskConcept.blueprint.color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          bp.name,
                          style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final part in _flattenedParts(bp.parts))
                  ListTile(
                    key: ValueKey('desk-move-section-${part.id}'),
                    dense: true,
                    contentPadding:
                        const EdgeInsets.only(left: 28, right: 12),
                    title: Text(part.name),
                    trailing: part.id == placement.partId
                        ? Icon(Icons.check, size: 18, color: scheme.primary)
                        : null,
                    onTap: () => Navigator.of(ctx).pop(part),
                  ),
              ],
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

    setState(() => _busy = true);
    try {
      await ref.read(blueprintActionsProvider).setPlacement(
            widget.documentId,
            chosen.id,
            placement.role,
            projectId: widget.projectId,
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<PartOverviewNode> _flattenedParts(List<PartOverviewNode> nodes) {
    final out = <PartOverviewNode>[];
    _flattenPartsQ(nodes, out);
    return out;
  }

  Future<void> _changeRole(BuildContext context) async {
    final placement = widget.placement;
    if (placement == null) return;
    final roles = Role.values.where((r) => r != Role.unknown).toList();

    final chosen = await showDialog<Role>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Role'),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final role in roles)
                ListTile(
                  key: ValueKey('desk-role-${role.wire}'),
                  title: Text(role.wire),
                  selected: role == placement.role,
                  onTap: () => Navigator.of(ctx).pop(role),
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

    setState(() => _busy = true);
    try {
      await ref.read(blueprintActionsProvider).setPlacement(
            widget.documentId,
            placement.partId,
            chosen,
            projectId: widget.projectId,
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePlacement(BuildContext context) async {
    if (widget.placement == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove placement'),
        content: const Text(
          'Remove this document from the section? '
          'The document itself is not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('desk-placement-remove-confirm'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(blueprintActionsProvider)
          .removePlacement(widget.documentId, projectId: widget.projectId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(BuildContext context) async {
    final docs = await ref.read(documentsProvider.future);
    final doc =
        docs.where((d) => d.id == widget.documentId).firstOrNull;
    if (doc == null) return;
    if (!context.mounted) return;

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Document',
      fileName: '${doc.title}.docx',
      type: FileType.custom,
      allowedExtensions: ['docx'],
    );
    if (savePath == null) return;
    if (!context.mounted) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(documentRepositoryProvider);
      final bytes = await repo.exportDocument(widget.documentId);
      final finalPath =
          savePath.endsWith('.docx') ? savePath : '$savePath.docx';
      await File(finalPath).writeAsBytes(bytes);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to ${File(finalPath).parent.path}'),
        ),
      );
    } on DioException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: ${e.response?.statusCode ?? e.message}'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Download failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document?'),
        content: const Text(
            'This document will be permanently deleted and cannot be recovered.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('desk-quick-delete-confirm'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(documentActionsProvider).deleteDocument(widget.documentId);
      ref.invalidate(documentsProvider);
      if (context.mounted) Navigator.of(context).maybePop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _moveToSection(BuildContext context) async {
    final overview = widget.overviewAsync.valueOrNull;
    if (overview == null) return;

    final flat = <PartOverviewNode>[];
    for (final bp in overview.blueprints) {
      _flattenPartsQ(bp.parts, flat);
    }
    if (flat.isEmpty) return;

    final chosen = await showDialog<PartOverviewNode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to Section'),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final part in flat)
                ListTile(
                  key: ValueKey('desk-quick-move-section-${part.id}'),
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

    setState(() => _busy = true);
    try {
      await ref.read(blueprintActionsProvider).setPlacement(
            widget.documentId,
            chosen.id,
            Role.mainContent,
            projectId: widget.projectId,
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _flattenPartsQ(
      List<PartOverviewNode> nodes, List<PartOverviewNode> out) {
    for (final n in nodes) {
      out.add(n);
      _flattenPartsQ(n.children, out);
    }
  }
}

// ── Placed-in labeled row (icon · label · value) ──────────────────────────────

class _PlacedRow extends StatelessWidget {
  const _PlacedRow({
    required this.concept,
    required this.value,
    this.valueKey,
    this.onTap,
  });

  final DeskConcept concept;
  final String value;
  final Key? valueKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(concept.icon, size: 16, color: concept.color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                concept.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 0.4,
                    ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                key: valueKey,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
    if (onTap == null) return row;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: row,
      ),
    );
  }
}

// ── Shared card shell ─────────────────────────────────────────────────────────

class _RailCard extends StatelessWidget {
  const _RailCard({
    super.key,
    required this.tokens,
    required this.child,
  });

  final PsittaTokens tokens;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(tokens.radius),
        border: Border.all(
          color: tokens.border.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}
