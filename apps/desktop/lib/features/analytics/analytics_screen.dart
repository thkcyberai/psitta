import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'writing_session_tracking.dart';

import '../../data/providers/blueprint_providers.dart';
import '../../data/providers/providers.dart';

/// Analytics — the Writer Growth Dashboard (Phase 1 MVP).
///
/// Built entirely from data Psitta already stores: projects, documents, and
/// blueprint structure progress. Writing-activity metrics (streaks, sessions,
/// daily output) arrive in Phase 2 once writing sessions are recorded. All
/// reads are scoped to the authenticated account by the providers.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final projectsAsync = ref.watch(projectsProvider);
    final docsAsync = ref.watch(documentsProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Analytics',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Your Writer Growth Dashboard.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          Expanded(
            child: projectsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Could not load analytics: $e')),
              data: (projects) => docsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Could not load analytics: $e')),
                data: (docs) {
                  final lifetimeWords =
                      docs.fold<int>(0, (s, d) => s + (d.wordCount ?? 0));
                  final now = DateTime.now();
                  final docsThisMonth = docs
                      .where((d) =>
                          d.createdAt.year == now.year &&
                          d.createdAt.month == now.month)
                      .length;
                  DateTime? earliest;
                  for (final d in docs) {
                    if (earliest == null || d.createdAt.isBefore(earliest)) {
                      earliest = d.createdAt;
                    }
                  }
                  final byId = <String, _ProjectStat>{};
                  final stats = <_ProjectStat>[];
                  for (final p in projects) {
                    final s = _ProjectStat(id: p.id, name: p.name);
                    byId[p.id] = s;
                    stats.add(s);
                  }
                  for (final d in docs) {
                    final pid = d.projectId;
                    if (pid == null) continue;
                    final s = byId[pid];
                    if (s == null) continue;
                    s.words += d.wordCount ?? 0;
                    s.docs += 1;
                    final activity = d.updatedAt ?? d.createdAt;
                    if (s.lastActivity == null ||
                        activity.isAfter(s.lastActivity!)) {
                      s.lastActivity = activity;
                    }
                  }
                  stats.sort((a, b) {
                    final la = a.lastActivity;
                    final lb = b.lastActivity;
                    if (la == null && lb == null) return 0;
                    if (la == null) return 1;
                    if (lb == null) return -1;
                    return lb.compareTo(la);
                  });
                  return _Dashboard(
                    lifetimeWords: lifetimeWords,
                    totalDocs: docs.length,
                    projectCount: projects.length,
                    docsThisMonth: docsThisMonth,
                    sinceYear: earliest?.year,
                    stats: stats,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectStat {
  _ProjectStat({required this.id, required this.name});
  final String id;
  final String name;
  int words = 0;
  int docs = 0;
  DateTime? lastActivity;
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.lifetimeWords,
    required this.totalDocs,
    required this.projectCount,
    required this.docsThisMonth,
    required this.sinceYear,
    required this.stats,
  });

  final int lifetimeWords;
  final int totalDocs;
  final int projectCount;
  final int docsThisMonth;
  final int? sinceYear;
  final List<_ProjectStat> stats;

  static String fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          children: [
            _Card(
              icon: Icons.auto_graph_outlined,
              title: 'Your writing at a glance',
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Wrap(
                  spacing: 30,
                  runSpacing: 16,
                  children: [
                    _Stat(value: fmt(lifetimeWords), label: 'Lifetime words'),
                    _Stat(value: '$totalDocs', label: 'Documents'),
                    _Stat(value: '$projectCount', label: 'Projects'),
                    _Stat(value: '$docsThisMonth', label: 'New this month'),
                    if (sinceYear != null)
                      _Stat(
                          value: 'Since $sinceYear',
                          label: 'Writing on Psitta'),
                  ],
                ),
              ),
            ),
            _Card(
              icon: Icons.folder_outlined,
              title: 'Projects in motion',
              child: stats.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Text(
                        'Create a project to start tracking your book progress.',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : Column(
                      children: [
                        for (final s in stats) _ProjectStatCard(stat: s),
                      ],
                    ),
            ),
            const _ActivityOutput(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
        const SizedBox(height: 2),
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _ProjectStatCard extends ConsumerWidget {
  const _ProjectStatCard({required this.stat});
  final _ProjectStat stat;

  static String ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inDays >= 1) return '${d.inDays}d ago';
    if (d.inHours >= 1) return '${d.inHours}h ago';
    if (d.inMinutes >= 1) return '${d.inMinutes}m ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final overview = ref.watch(projectBlueprintOverviewProvider(stat.id)).valueOrNull;
    double? ratio;
    final pr = overview?.progress;
    if (pr != null && pr.totalLeaves > 0) {
      ratio = pr.ratio ?? pr.leavesWithContent / pr.totalLeaves;
    }
    final pct = ratio != null ? (ratio * 100).round() : null;
    final files = stat.docs == 1 ? 'file' : 'files';
    final last = stat.lastActivity != null ? ' · ${ago(stat.lastActivity!)}' : '';

    return InkWell(
      onTap: () => context.go(
          '/projects/${stat.id}?projectName=${Uri.encodeComponent(stat.name)}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(stat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (pct != null)
                  Text('$pct%',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700, color: scheme.primary)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_Dashboard.fmt(stat.words)} words · ${stat.docs} $files$last',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (ratio != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 5,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: scheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.title, required this.child});
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 10),
                Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outline.withValues(alpha: 0.14)),
          child,
        ],
      ),
    );
  }
}


/// Live writing activity + output, from locally-recorded sessions.
class _ActivityOutput extends ConsumerWidget {
  const _ActivityOutput();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(writerStatsProvider).valueOrNull;
    if (stats == null || !stats.hasData) {
      return _Card(
        icon: Icons.local_fire_department_outlined,
        title: 'Writing activity & streaks',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Text(
            'Your first saved writing will start your streak. Streaks, sessions, '
            'and word trends build automatically as you write in the Desk.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    final hour = stats.productiveHourLabel;
    return Column(
      children: [
        _Card(
          icon: Icons.local_fire_department_outlined,
          title: 'Writing activity',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Wrap(
              spacing: 30,
              runSpacing: 16,
              children: [
                _Stat(value: '${stats.currentStreak}', label: 'Day streak'),
                _Stat(value: '${stats.longestStreak}', label: 'Longest streak'),
                _Stat(
                    value: '${stats.sessionsThisWeek}',
                    label: 'Sessions this week'),
                _Stat(value: '${stats.avgSessionMin}m', label: 'Avg session'),
                if (hour != null) _Stat(value: hour, label: 'Most productive'),
              ],
            ),
          ),
        ),
        _Card(
          icon: Icons.trending_up_outlined,
          title: 'Words written',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Wrap(
              spacing: 30,
              runSpacing: 16,
              children: [
                _Stat(value: _Dashboard.fmt(stats.wordsToday), label: 'Today'),
                _Stat(
                    value: _Dashboard.fmt(stats.wordsThisWeek),
                    label: 'This week'),
                _Stat(
                    value: _Dashboard.fmt(stats.wordsThisMonth),
                    label: 'This month'),
                _Stat(
                    value: _Dashboard.fmt(stats.wordsTracked),
                    label: 'Tracked total'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
