import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/psitta_tokens.dart';
import '../../../data/models/project_detail.dart' show ActivityEvent;
import '../../../data/providers/project_providers.dart';

/// Project → Activity feed: a reverse-chronological list of meaningful project
/// events from the backend (read-only).
///
/// [compact] renders a short preview for the right rail (first few events plus
/// a "View all" link that switches to the Activity tab); otherwise it renders
/// the full scrollable timeline for the Activity tab. Honest empty/loading
/// states — never fabricates events.
class ProjectActivityFeed extends ConsumerWidget {
  const ProjectActivityFeed({
    super.key,
    required this.projectId,
    this.compact = false,
  });

  final String projectId;
  final bool compact;

  static const int _compactMax = 5;
  static const int _activityTabIndex = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(projectActivityProvider(projectId));

    return async.when(
      loading: () => compact
          ? const _MutedLine(text: 'Loading activity…')
          : const Center(child: CircularProgressIndicator()),
      error: (e, _) => _MutedLine(
        text: 'Could not load activity.',
        padding: compact ? null : const EdgeInsets.all(24),
      ),
      data: (events) {
        if (events.isEmpty) return _EmptyActivity(compact: compact);

        final shown = compact ? events.take(_compactMax).toList() : events;
        final rows = <Widget>[
          for (final e in shown) _ActivityRow(event: e),
        ];

        if (compact) {
          final hasMore = events.length > shown.length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...rows,
              if (hasMore || events.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextButton(
                    onPressed: () =>
                        DefaultTabController.maybeOf(context)
                            ?.animateTo(_activityTabIndex),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      foregroundColor: scheme.primary,
                    ),
                    child: const Text('View all activity',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
            ],
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 2),
          itemBuilder: (_, i) => rows[i],
        );
      },
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.event});

  final ActivityEvent event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconFor(event.kind), size: 16, color: _colorFor(event.kind, context)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.summary,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _relativeTime(event.createdAt),
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.all(compact ? 2 : 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(Icons.history_outlined, size: compact ? 22 : 30, color: muted),
          const SizedBox(height: 8),
          Text('No activity yet', style: TextStyle(fontSize: 12, color: muted)),
          if (!compact) ...[
            const SizedBox(height: 4),
            Text(
              'Edits, file placements, and narrative changes will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, height: 1.4, color: muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _MutedLine extends StatelessWidget {
  const _MutedLine({required this.text, this.padding});

  final String text;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: TextStyle(fontSize: 12, color: muted)),
    );
  }
}

IconData _iconFor(String kind) {
  switch (kind) {
    case 'project':
      return Icons.folder_outlined;
    case 'narrative':
      return Icons.auto_stories_outlined;
    case 'document_add':
      return Icons.note_add_outlined;
    case 'document_edit':
      return Icons.edit_outlined;
    case 'document_remove':
      return Icons.delete_outline;
    case 'document_restore':
      return Icons.restore;
    case 'summary':
      return Icons.summarize_outlined;
    default:
      return Icons.history;
  }
}

Color _colorFor(String kind, BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final tokens = PsittaTokens.of(context);
  switch (kind) {
    case 'narrative':
      return tokens.glow;
    case 'document_remove':
      return scheme.error;
    case 'project':
      return scheme.primary;
    default:
      return scheme.onSurfaceVariant;
  }
}

String _relativeTime(DateTime t) {
  final local = t.toLocal();
  final d = DateTime.now().difference(local);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}
