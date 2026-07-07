import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'writing_session_tracking.dart';

import '../../data/providers/blueprint_providers.dart';
import '../../data/providers/providers.dart';
import '../../l10n/app_localizations.dart';

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
    final loc = AppLocalizations.of(context);
    final projectsAsync = ref.watch(projectsProvider);
    final docsAsync = ref.watch(documentsProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.navAnalytics,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(loc.analyticsSubtitle,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          Expanded(
            child: projectsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text(loc.analyticsLoadError)),
              data: (projects) => docsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text(loc.analyticsLoadError)),
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
    final loc = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          children: [
            _Card(
              icon: Icons.auto_graph_outlined,
              title: loc.analyticsGlance,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Wrap(
                  spacing: 30,
                  runSpacing: 16,
                  children: [
                    _Stat(value: fmt(lifetimeWords), label: loc.statLifetimeWords),
                    _Stat(value: '$totalDocs', label: loc.statDocuments),
                    _Stat(value: '$projectCount', label: loc.navProjects),
                    _Stat(value: '$docsThisMonth', label: loc.statNewThisMonth),
                    if (sinceYear != null)
                      _Stat(
                          value: loc.analyticsSince(sinceYear!),
                          label: loc.statWritingOnPsitta),
                  ],
                ),
              ),
            ),
            _Card(
              icon: Icons.folder_outlined,
              title: loc.analyticsProjectsInMotion,
              child: stats.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Text(
                        loc.analyticsNoProjects,
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

  static String ago(AppLocalizations loc, DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inDays >= 1) return loc.agoDays(d.inDays);
    if (d.inHours >= 1) return loc.agoHours(d.inHours);
    if (d.inMinutes >= 1) return loc.agoMinutes(d.inMinutes);
    return loc.agoJustNow;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final loc = AppLocalizations.of(context);
    final overview = ref.watch(projectBlueprintOverviewProvider(stat.id)).valueOrNull;
    double? ratio;
    final pr = overview?.progress;
    if (pr != null && pr.totalLeaves > 0) {
      ratio = pr.ratio ?? pr.leavesWithContent / pr.totalLeaves;
    }
    final pct = ratio != null ? (ratio * 100).round() : null;
    final last =
        stat.lastActivity != null ? ' · ${ago(loc, stat.lastActivity!)}' : '';

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
              '${loc.wordsCount(stat.words, _Dashboard.fmt(stat.words))} · ${loc.filesCount(stat.docs)}$last',
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
    final loc = AppLocalizations.of(context);
    final stats = ref.watch(writerStatsProvider).valueOrNull;
    if (stats == null || !stats.hasData) {
      return _Card(
        icon: Icons.local_fire_department_outlined,
        title: loc.analyticsActivityStreaks,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Text(
            loc.analyticsStreaksEmpty,
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
          icon: Icons.show_chart_outlined,
          title: loc.analyticsWeeklyTrend,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: _WeeklyTrend(weekly: stats.weeklyWords()),
          ),
        ),
        _Card(
          icon: Icons.local_fire_department_outlined,
          title: loc.analyticsWritingActivity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Wrap(
              spacing: 30,
              runSpacing: 16,
              children: [
                _Stat(value: '${stats.currentStreak}', label: loc.statDayStreak),
                _Stat(
                    value: '${stats.longestStreak}',
                    label: loc.statLongestStreak),
                _Stat(
                    value: '${stats.sessionsThisWeek}',
                    label: loc.statSessionsThisWeek),
                _Stat(value: '${stats.avgSessionMin}m', label: loc.statAvgSession),
                if (hour != null)
                  _Stat(value: hour, label: loc.statMostProductive),
                if (stats.typedPct != null)
                  _Stat(
                      value: '${stats.typedPct}%',
                      label: loc.statTypedVsPaste),
                if (stats.typedChars > 0 || stats.pastedChars > 0) ...[
                  _Stat(
                      value: _Dashboard.fmt(stats.typedChars),
                      label: loc.statKeystrokes),
                  _Stat(
                      value: _Dashboard.fmt(stats.pastedChars),
                      label: loc.statCharsPasted),
                ],
              ],
            ),
          ),
        ),
        _Card(
          icon: Icons.calendar_month_outlined,
          title: loc.analyticsWritingDays,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: _Heatmap(dailyWords: stats.dailyWords),
          ),
        ),
        _Card(
          icon: Icons.trending_up_outlined,
          title: loc.analyticsWordsWritten,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Wrap(
              spacing: 30,
              runSpacing: 16,
              children: [
                _Stat(
                    value: _Dashboard.fmt(stats.wordsToday),
                    label: loc.statToday),
                _Stat(
                    value: _Dashboard.fmt(stats.wordsThisWeek),
                    label: loc.analyticsThisWeek),
                _Stat(
                    value: _Dashboard.fmt(stats.wordsThisMonth),
                    label: loc.statThisMonth),
                _Stat(
                    value: _Dashboard.fmt(stats.wordsTracked),
                    label: loc.statTrackedTotal),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


/// A GitHub-style grid of writing days (last ~14 weeks). Intensity reflects
/// words written; reads the locally-recorded daily rollup.
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.dailyWords});
  final Map<String, int> dailyWords;

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const weeks = 14;
    final start = today.subtract(const Duration(days: weeks * 7 - 1));
    final startMonday = start.subtract(Duration(days: start.weekday - 1));
    final cols = <List<DateTime>>[];
    var cur = startMonday;
    while (!cur.isAfter(today)) {
      final wk = <DateTime>[];
      for (var i = 0; i < 7; i++) {
        wk.add(cur);
        cur = cur.add(const Duration(days: 1));
      }
      cols.add(wk);
    }
    Color cell(DateTime d) {
      if (d.isAfter(today)) return Colors.transparent;
      final w = dailyWords[_ymd(d)] ?? 0;
      if (w <= 0) return scheme.onSurface.withValues(alpha: 0.07);
      if (w < 100) return scheme.primary.withValues(alpha: 0.30);
      if (w < 500) return scheme.primary.withValues(alpha: 0.55);
      return scheme.primary.withValues(alpha: 0.90);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final wk in cols)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Column(
                children: [
                  for (final d in wk)
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(bottom: 3),
                      decoration: BoxDecoration(
                        color: cell(d),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


/// A lightweight line chart of total words per week (last ~8 weeks),
/// drawn with a CustomPainter so it needs no charting dependency. Fed by
/// the locally-recorded daily rollup via WriterStats.weeklyWords().
class _WeeklyTrend extends StatelessWidget {
  const _WeeklyTrend({required this.weekly});
  final List<int> weekly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final loc = AppLocalizations.of(context);
    final maxV = weekly.fold<int>(0, (m, v) => v > m ? v : m);
    if (maxV <= 0) {
      return Text(
        loc.analyticsTrendEmpty,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: scheme.onSurfaceVariant),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 132,
          width: double.infinity,
          child: CustomPaint(
            painter: _WeeklyTrendPainter(
              weekly: weekly,
              line: scheme.primary,
              fill: scheme.primary.withValues(alpha: 0.12),
              grid: scheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(loc.weeksAgo(weekly.length),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            Text(loc.chartWordsThisWeek(_Dashboard.fmt(weekly.last)),
                style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.primary, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

class _WeeklyTrendPainter extends CustomPainter {
  _WeeklyTrendPainter({
    required this.weekly,
    required this.line,
    required this.fill,
    required this.grid,
  });
  final List<int> weekly;
  final Color line;
  final Color fill;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final n = weekly.length;
    if (n == 0) return;
    final maxV = weekly.fold<int>(1, (m, v) => v > m ? v : m);
    const padL = 6.0, padR = 6.0, padT = 12.0, padB = 10.0;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;
    double xAt(int i) => padL + (n == 1 ? w / 2 : w * i / (n - 1));
    double yAt(int v) => padT + h - (v / maxV) * h;

    final gridP = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(padL, padT + h), Offset(padL + w, padT + h), gridP);

    final pts = <Offset>[
      for (var i = 0; i < n; i++) Offset(xAt(i), yAt(weekly[i])),
    ];

    final area = Path()..moveTo(pts.first.dx, padT + h);
    for (final p in pts) {
      area.lineTo(p.dx, p.dy);
    }
    area
      ..lineTo(pts.last.dx, padT + h)
      ..close();
    canvas.drawPath(area, Paint()..color = fill);

    final stroke = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < n; i++) {
      stroke.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(
      stroke,
      Paint()
        ..color = line
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < n; i++) {
      final isLast = i == n - 1;
      if (isLast) {
        canvas.drawCircle(
            pts[i], 7, Paint()..color = line.withValues(alpha: 0.18));
      }
      canvas.drawCircle(pts[i], isLast ? 4.5 : 2.8, Paint()..color = line);
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyTrendPainter old) => true;
}
