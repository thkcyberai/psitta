import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/concept_style.dart';
import '../../core/theme/psitta_tokens.dart';
import 'summarize_it_panel.dart';
import '../../data/models/blueprint.dart';
import '../../data/models/blueprint_enums.dart';
import '../../data/models/project_detail.dart';
import '../../data/providers/blueprint_providers.dart';
import '../../data/providers/project_providers.dart';
import '../../data/providers/providers.dart';

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: projectId == null
                    ? const _NullProjectGuard()
                    : _ContextPaneBody(
                        documentId: documentId,
                        projectId: projectId!,
                      ),
              ),
              const Divider(height: 1),
              // Bottom Summarize-It panel is height-bounded to at most half the
              // rail and scrolls internally, so a long summary can never push
              // past the viewport (fixes the 324px bottom overflow).
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.5,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SummarizeItPanel(documentId: documentId),
                ),
              ),
            ],
          );
        },
      ),
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
      key: const ValueKey('desk-context-null-guard'),
      color: tokens.surface2,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Text(
        'Open from a project to see context',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
        textAlign: TextAlign.center,
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        children: [
          // ── Progress card ────────────────────────────────────────────────
          overviewAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (overview) {
              final progress = overview.progress;
              if (progress == null) return const SizedBox.shrink();
              return _ProgressCard(progress: progress);
            },
          ),
          const SizedBox(height: 12),
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
              if (placement == null) return const _UnplacedHint();
              return _PlacementContextCard(
                placement: placement,
                overviewAsync: overviewAsync,
                projectId: projectId,
                documentId: documentId,
              );
            },
          ),
          const SizedBox(height: 12),
          // ── Quick actions card (WD-5) ────────────────────────────────────
          _QuickActionsCard(
            documentId: documentId,
            projectId: projectId,
            overviewAsync: overviewAsync,
          ),
        ],
      ),
    );
  }
}

// ── Progress card ─────────────────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});
  final ProgressInfo progress;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ratio = progress.ratio ?? 0.0;

    return _RailCard(
      key: const ValueKey('desk-progress-card'),
      tokens: tokens,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BLUEPRINT PROGRESS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.outline,
                  letterSpacing: 0.8,
                ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: scheme.outline.withOpacity(0.15),
              color: scheme.primary,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${progress.leavesWithContent} / ${progress.totalLeaves} sections with content',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Unplaced hint ─────────────────────────────────────────────────────────────

class _UnplacedHint extends StatelessWidget {
  const _UnplacedHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('desk-context-unplaced'),
      padding: const EdgeInsets.all(12),
      child: Text(
        'Not placed in a section.\n'
        'Use the navigator to assign it.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
        textAlign: TextAlign.center,
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
  bool _busy = false;

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
          Text(
            'PLACED IN',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.outline,
                  letterSpacing: 0.8,
                ),
          ),
          const SizedBox(height: 12),
          _PlacedRow(
            concept: DeskConcept.project,
            value: projectName ?? '—',
          ),
          const SizedBox(height: 10),
          _PlacedRow(
            concept: DeskConcept.blueprint,
            value: placement.blueprintName,
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
          const SizedBox(height: 12),
          // ── Actions ────────────────────────────────────────────────────
          if (_busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                TextButton(
                  key: const ValueKey('desk-placement-move'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => _moveSection(context),
                  child: const Text('Move section'),
                ),
                TextButton(
                  key: const ValueKey('desk-placement-change-role'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => _changeRole(context),
                  child: const Text('Change role'),
                ),
                TextButton(
                  key: const ValueKey('desk-placement-remove'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: scheme.error,
                  ),
                  onPressed: () => _removePlacement(context),
                  child: const Text('Remove'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _moveSection(BuildContext context) async {
    final overview = widget.overviewAsync.valueOrNull;
    if (overview == null) return;

    final flat = <PartOverviewNode>[];
    for (final bp in overview.blueprints) {
      _flattenParts(bp.parts, flat);
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
                  key: ValueKey('desk-move-section-${part.id}'),
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
            widget.placement.role,
            projectId: widget.projectId,
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeRole(BuildContext context) async {
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
                  selected: role == widget.placement.role,
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
            widget.placement.partId,
            chosen,
            projectId: widget.projectId,
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePlacement(BuildContext context) async {
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

  void _flattenParts(
      List<PartOverviewNode> nodes, List<PartOverviewNode> out) {
    for (final n in nodes) {
      out.add(n);
      _flattenParts(n.children, out);
    }
  }
}

// ── Quick actions card (WD-5) ─────────────────────────────────────────────────

class _QuickActionsCard extends ConsumerStatefulWidget {
  const _QuickActionsCard({
    required this.documentId,
    required this.projectId,
    required this.overviewAsync,
  });

  final String documentId;
  final String projectId;
  final AsyncValue<ProjectBlueprintOverview> overviewAsync;

  @override
  ConsumerState<_QuickActionsCard> createState() => _QuickActionsCardState();
}

class _QuickActionsCardState extends ConsumerState<_QuickActionsCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;

    return _RailCard(
      key: const ValueKey('desk-quick-actions-card'),
      tokens: tokens,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUICK ACTIONS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.outline,
                  letterSpacing: 0.8,
                ),
          ),
          const SizedBox(height: 8),
          if (_busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  key: const ValueKey('desk-quick-download'),
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Download'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => _download(context),
                ),
                TextButton.icon(
                  key: const ValueKey('desk-quick-delete'),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: scheme.error,
                  ),
                  onPressed: () => _delete(context),
                ),
                TextButton.icon(
                  key: const ValueKey('desk-quick-move'),
                  icon: const Icon(Icons.drive_file_move_outline, size: 16),
                  label: const Text('Move to section'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => _moveToSection(context),
                ),
                Tooltip(
                  message: 'Coming soon',
                  child: TextButton.icon(
                    key: const ValueKey('desk-quick-duplicate'),
                    icon: const Icon(Icons.content_copy_outlined, size: 16),
                    label: const Text('Duplicate'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: null,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
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
      final repo = ref.read(documentRepositoryProvider);
      await repo.deleteDocument(widget.documentId);
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
  });

  final DeskConcept concept;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
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
                      color: scheme.outline,
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
