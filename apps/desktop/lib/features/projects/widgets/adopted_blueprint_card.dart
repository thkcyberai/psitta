import 'package:flutter/material.dart';

import '../../../core/theme/psitta_tokens.dart';
import '../../../data/models/blueprint.dart';

/// Recursive count of sections (parts) in a blueprint overview tree.
int countSections(List<PartOverviewNode> parts) =>
    parts.fold(0, (sum, p) => sum + 1 + countSections(p.children));

/// Recursive sum of documents placed across a blueprint overview tree. A
/// document is in at most one part, so summing across the whole tree (and across
/// all adopted blueprints) never double-counts.
int countDocuments(List<PartOverviewNode> parts) =>
    parts.fold(0, (sum, p) => sum + p.documentCount + countDocuments(p.children));

/// Card for one adopted blueprint (reused by the Overview and Blueprints tabs):
/// name, Primary badge, section + document counts, a progress bar from
/// ProgressInfo.ratio, and the description when present. [actions] renders
/// trailing per-card controls (e.g. the 5d menu).
class AdoptedBlueprintCard extends StatelessWidget {
  const AdoptedBlueprintCard({
    super.key,
    required this.overview,
    this.actions,
  });

  final BlueprintOverview overview;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final sections = countSections(overview.parts);
    final docs = countDocuments(overview.parts);
    final ratio = overview.progress.ratio;
    final description = overview.description;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(tokens.radius),
        border: Border.all(color: tokens.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  overview.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              if (overview.isPrimary) const _PrimaryBadge(),
              if (actions != null) ...[const SizedBox(width: 4), actions!],
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _Meta(
                icon: Icons.account_tree_outlined,
                label: '$sections section${sections == 1 ? '' : 's'}',
              ),
              const SizedBox(width: 16),
              _Meta(
                icon: Icons.description_outlined,
                label: '$docs document${docs == 1 ? '' : 's'}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio ?? 0,
                    minHeight: 6,
                    backgroundColor: tokens.inputFill,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                ratio == null ? '—' : '${(ratio * 100).round()}%',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrimaryBadge extends StatelessWidget {
  const _PrimaryBadge();

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.glow.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.glow.withOpacity(0.4)),
      ),
      child: Text(
        'Primary',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface.withOpacity(0.85),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: muted),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: muted)),
      ],
    );
  }
}
