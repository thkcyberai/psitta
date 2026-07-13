import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/psitta_tokens.dart';
import '../../../data/models/blueprint.dart';
import '../../../data/models/document.dart';
import '../../../data/models/project_detail.dart';
import '../../../data/providers/blueprint_providers.dart';
import '../../../data/providers/project_providers.dart';
import '../../../l10n/app_localizations.dart';

/// The Project's Explorer-style "Book" tree: the primary Book Structure's
/// sections shown as collapsible folders, with the files placed in each section
/// nested inside, plus an "Unassigned" group for project files not yet placed.
///
/// Reads the live overview + placements + documents providers, so it stays in
/// sync (within the ~2s window) with any assembly done from any sector — the
/// single-source-of-truth spine. Click a file to open it in the Writing Desk.
/// (Drag-to-reorder / move-between-sections is the next slice.)
class ProjectBookTree extends ConsumerStatefulWidget {
  const ProjectBookTree({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ProjectBookTree> createState() => _ProjectBookTreeState();
}

class _ProjectBookTreeState extends ConsumerState<ProjectBookTree> {
  /// Collapsed part ids (default = expanded, Explorer-style).
  final Set<String> _collapsed = {};
  bool _unassignedCollapsed = false;

  void _toggle(String id) => setState(() {
        if (!_collapsed.remove(id)) _collapsed.add(id);
      });

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final overview =
        ref.watch(projectBlueprintOverviewProvider(widget.projectId));
    final placements =
        ref.watch(projectPlacementsProvider(widget.projectId)).valueOrNull ??
            const <ProjectPlacement>[];
    final docs =
        ref.watch(projectDocumentsProvider(widget.projectId)).valueOrNull ??
            const <Document>[];

    return overview.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text(loc.bookTreeLoadError,
          style: TextStyle(color: scheme.onSurfaceVariant)),
      data: (ov) {
        if (ov.blueprints.isEmpty) {
          return _empty(scheme, loc.bookTreeEmpty);
        }
        final bp = ov.blueprints.firstWhere((b) => b.isPrimary,
            orElse: () => ov.blueprints.first);

        final docById = {for (final d in docs) d.id: d};
        final byPart = <String, List<ProjectPlacement>>{};
        for (final p in placements) {
          if (p.blueprintId != bp.id) continue;
          (byPart[p.partId] ??= []).add(p);
        }
        for (final l in byPart.values) {
          l.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        }
        final placedIds = {for (final p in placements) p.documentId};
        final unassigned =
            docs.where((d) => !placedIds.contains(d.id)).toList();

        final rows = <Widget>[];
        for (final part in bp.parts) {
          _buildNode(rows, part, 0, byPart, docById, tokens, scheme);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _treeBar(scheme, bp.name),
            const SizedBox(height: 6),
            ...rows,
            const SizedBox(height: 10),
            _unassignedGroup(unassigned, tokens, scheme),
          ],
        );
      },
    );
  }

  void _buildNode(
    List<Widget> rows,
    PartOverviewNode part,
    int depth,
    Map<String, List<ProjectPlacement>> byPart,
    Map<String, Document> docById,
    PsittaTokens tokens,
    ColorScheme scheme,
  ) {
    final placed = byPart[part.id] ?? const <ProjectPlacement>[];
    final collapsed = _collapsed.contains(part.id);
    final hasChildren = part.children.isNotEmpty || placed.isNotEmpty;

    rows.add(_folderRow(part, depth, hasChildren, collapsed, tokens, scheme));
    if (collapsed) return;

    for (final pl in placed) {
      rows.add(_fileRow(
          docById[pl.documentId], pl, depth + 1, tokens, scheme));
    }
    for (final child in part.children) {
      _buildNode(rows, child, depth + 1, byPart, docById, tokens, scheme);
    }
  }

  Widget _treeBar(ColorScheme scheme, String name) => Row(
        children: [
          Icon(Icons.menu_book_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(AppLocalizations.of(context).bookTreePrimary,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary)),
          ),
        ],
      );

  Widget _folderRow(PartOverviewNode part, int depth, bool hasChildren,
      bool collapsed, PsittaTokens tokens, ColorScheme scheme) {
    return InkWell(
      onTap: hasChildren ? () => _toggle(part.id) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8.0 + depth * 18, 6, 8, 6),
        child: Row(
          children: [
            Icon(
              hasChildren
                  ? (collapsed
                      ? Icons.chevron_right_rounded
                      : Icons.keyboard_arrow_down_rounded)
                  : Icons.remove,
              size: 18,
              color: hasChildren
                  ? scheme.onSurfaceVariant
                  : Colors.transparent,
            ),
            const SizedBox(width: 2),
            Icon(Icons.folder_rounded, size: 18, color: tokens.glow),
            const SizedBox(width: 8),
            Expanded(
              child: Text(part.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
            if (part.documentCount > 0) ...[
              const SizedBox(width: 8),
              Text('${part.documentCount}',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fileRow(Document? doc, ProjectPlacement pl, int depth,
      PsittaTokens tokens, ColorScheme scheme) {
    final title = doc?.title ?? AppLocalizations.of(context).docUntitled;
    return InkWell(
      onTap: doc == null
          ? null
          : () => context.go(
              '/writing-desk/${doc.id}?projectId=${widget.projectId}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8.0 + depth * 18, 5, 8, 5),
        child: Row(
          children: [
            const SizedBox(width: 20),
            Icon(Icons.description_outlined,
                size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 8),
            _roleChip(pl.role.wire, scheme),
          ],
        ),
      ),
    );
  }

  Widget _roleChip(String label, ColorScheme scheme) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, color: scheme.onSurfaceVariant)),
      );

  Widget _unassignedGroup(
      List<Document> unassigned, PsittaTokens tokens, ColorScheme scheme) {
    if (unassigned.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () =>
              setState(() => _unassignedCollapsed = !_unassignedCollapsed),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(
              children: [
                Icon(
                    _unassignedCollapsed
                        ? Icons.chevron_right_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant),
                const SizedBox(width: 2),
                Icon(Icons.folder_off_outlined,
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(AppLocalizations.of(context).bookTreeUnassigned,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant)),
                ),
                Text('${unassigned.length}',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        if (!_unassignedCollapsed)
          for (final d in unassigned)
            _fileRowPlain(d, scheme),
      ],
    );
  }

  Widget _fileRowPlain(Document doc, ColorScheme scheme) => InkWell(
        onTap: () => context.go(
            '/writing-desk/${doc.id}?projectId=${widget.projectId}'),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 5, 8, 5),
          child: Row(
            children: [
              Icon(Icons.description_outlined,
                  size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(doc.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context).bookTreeNotPlaced,
                  style: TextStyle(
                      fontSize: 10, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      );

  Widget _empty(ColorScheme scheme, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(text,
            style: TextStyle(color: scheme.onSurfaceVariant)),
      );
}
