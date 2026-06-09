import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/psitta_tokens.dart';
import '../../../data/models/blueprint.dart';
import '../../../data/models/document.dart';
import '../../../data/models/project_detail.dart';
import '../../../data/providers/blueprint_providers.dart';
import '../../../data/providers/project_providers.dart';
import 'adopt_blueprint_dialog.dart';
import 'adopted_blueprint_card.dart';

/// Overview tab: 4 stat cards, an in/out-of-blueprints summary, a Recent
/// Documents table (with a Blueprint/Section column resolved from placements),
/// and the adopted-blueprints section with an "Add Blueprint to Project" picker.
class ProjectOverviewTab extends ConsumerWidget {
  const ProjectOverviewTab({super.key, required this.projectId});

  final String projectId;

  static const int _recentLimit = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(projectDetailProvider(projectId)).valueOrNull;
    final overviewAsync = ref.watch(projectBlueprintOverviewProvider(projectId));
    final overview = overviewAsync.valueOrNull;
    final docs =
        ref.watch(projectDocumentsProvider(projectId)).valueOrNull ?? const [];
    final placements =
        ref.watch(projectPlacementsProvider(projectId)).valueOrNull ?? const [];

    final total = detail?.documentCount ?? docs.length;
    final inBlueprints = overview == null
        ? 0
        : overview.blueprints
            .fold<int>(0, (s, bp) => s + countDocuments(bp.parts));
    final unassigned = (total - inBlueprints) < 0 ? 0 : total - inBlueprints;
    final archived = docs.where((d) => d.status == 'archived').length;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _StatRow(
          total: total,
          inBlueprints: inBlueprints,
          unassigned: unassigned,
          archived: archived,
        ),
        const SizedBox(height: 12),
        _SummaryLine(total: total, inBlueprints: inBlueprints, unassigned: unassigned),
        const SizedBox(height: 24),
        _RecentDocumentsSection(docs: docs, placements: placements, limit: _recentLimit),
        const SizedBox(height: 24),
        _BlueprintsSection(projectId: projectId, overviewAsync: overviewAsync),
      ],
    );
  }
}

// ── Stat cards ───────────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.total,
    required this.inBlueprints,
    required this.unassigned,
    required this.archived,
  });

  final int total;
  final int inBlueprints;
  final int unassigned;
  final int archived;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            valueKey: 'stat-documents-value',
            icon: Icons.description_outlined,
            value: '$total',
            label: 'Documents',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            valueKey: 'stat-in-blueprints-value',
            icon: Icons.account_tree_outlined,
            value: '$inBlueprints',
            label: 'In Blueprints',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            valueKey: 'stat-unassigned-value',
            icon: Icons.help_outline,
            value: '$unassigned',
            label: 'Unassigned',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            valueKey: 'stat-archived-value',
            icon: Icons.archive_outlined,
            value: '$archived',
            label: 'Archived',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.valueKey,
    required this.icon,
    required this.value,
    required this.label,
  });

  final String valueKey;
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(tokens.radius),
        border: Border.all(color: tokens.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            value,
            key: ValueKey(valueKey),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.total,
    required this.inBlueprints,
    required this.unassigned,
  });

  final int total;
  final int inBlueprints;
  final int unassigned;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Text(
      '$inBlueprints of $total document${total == 1 ? '' : 's'} '
      'in blueprints · $unassigned not in blueprints',
      style: TextStyle(fontSize: 12, color: muted),
    );
  }
}

// ── Recent documents ─────────────────────────────────────────────────────────

class _RecentDocumentsSection extends StatelessWidget {
  const _RecentDocumentsSection({
    required this.docs,
    required this.placements,
    required this.limit,
  });

  final List<Document> docs;
  final List<ProjectPlacement> placements;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final sectionByDoc = <String, String>{
      for (final p in placements)
        p.documentId: '${p.blueprintName} / ${p.partName}',
    };
    final recent = docs.take(limit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent Documents',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () => DefaultTabController.maybeOf(context)?.animateTo(1),
              child: const Text('View all Documents'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          Text('No documents yet', style: TextStyle(color: muted))
        else
          Container(
            decoration: BoxDecoration(
              color: tokens.surface.withOpacity(0.4),
              borderRadius: BorderRadius.circular(tokens.radius),
              border: Border.all(color: tokens.border.withOpacity(0.5)),
            ),
            child: Column(
              children: [
                const _DocRow.header(),
                for (final doc in recent) ...[
                  Divider(height: 1, color: tokens.divider),
                  _DocRow(
                    doc: doc,
                    section: sectionByDoc[doc.id] ?? 'Unassigned',
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc, required this.section}) : isHeader = false;
  const _DocRow.header()
      : doc = null,
        section = '',
        isHeader = true;

  final Document? doc;
  final String section;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: muted,
    );

    Widget cell(int flex, Widget child) => Expanded(flex: flex, child: child);

    if (isHeader) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            cell(3, Text('Title', style: headerStyle)),
            cell(2, Text('Status', style: headerStyle)),
            cell(3, Text('Blueprint / Section', style: headerStyle)),
            cell(2, Text('Last edited', style: headerStyle)),
          ],
        ),
      );
    }

    final d = doc!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          cell(
            3,
            Text(d.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          cell(2, Text(d.status, style: TextStyle(fontSize: 12, color: muted))),
          cell(
            3,
            Text(
              section,
              key: ValueKey('doc-section-${d.id}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
          cell(
            2,
            Text(_fmtDate(d.createdAt),
                style: TextStyle(fontSize: 12, color: muted)),
          ),
        ],
      ),
    );
  }
}

// ── Blueprints in this project ───────────────────────────────────────────────

class _BlueprintsSection extends ConsumerWidget {
  const _BlueprintsSection({required this.projectId, required this.overviewAsync});

  final String projectId;
  final AsyncValue<ProjectBlueprintOverview> overviewAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final overview = overviewAsync.valueOrNull;
    final adoptedIds = overview == null
        ? <String>{}
        : {for (final bp in overview.blueprints) bp.id};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              key: const ValueKey('add-blueprint-to-project-button'),
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
        const SizedBox(height: 12),
        overviewAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
          data: (ov) {
            final blueprints = ov.blueprints;
            if (blueprints.isEmpty) {
              return Text(
                'No blueprints yet. Add one to structure this project.',
                style: TextStyle(color: muted),
              );
            }
            return Column(
              children: [
                for (final bp in blueprints) ...[
                  AdoptedBlueprintCard(overview: bp),
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

String _fmtDate(DateTime d) {
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)}';
}
