import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/auth_service.dart';

/// A coalesced writing sitting (saves within 30 minutes), captured locally on
/// this device. "words" is the positive word-count growth; "typed"/"pasted" are
/// characters classified by edit-burst size (typing vs paste). Account-scoped;
/// never leaves the device.
class WritingSession {
  WritingSession({
    required this.start,
    required this.end,
    required this.words,
    required this.day,
    this.documentId,
    this.projectId,
    this.typed = 0,
    this.pasted = 0,
  });

  final DateTime start;
  final DateTime end;
  final int words;
  final String day; // local yyyy-mm-dd
  final String? documentId;
  final String? projectId;
  final int typed;
  final int pasted;

  int get durationS => end.difference(start).inSeconds;

  factory WritingSession.fromJson(Map<String, dynamic> j) => WritingSession(
        start: DateTime.tryParse(j['s'] as String? ?? '') ?? DateTime.now(),
        end: DateTime.tryParse(j['e'] as String? ?? '') ?? DateTime.now(),
        words: (j['w'] as num?)?.toInt() ?? 0,
        day: j['d'] as String? ?? '',
        documentId: j['doc'] as String?,
        projectId: j['proj'] as String?,
        typed: (j['t'] as num?)?.toInt() ?? 0,
        pasted: (j['p'] as num?)?.toInt() ?? 0,
      );
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class WritingSessionStore {
  static const Duration _gap = Duration(minutes: 30);
  static String _key(String uid) => 'user_${uid}_writing_sessions_v1';

  static Future<Map<String, dynamic>> _raw(SharedPreferences prefs, String uid) async {
    final s = prefs.getString(_key(uid));
    if (s == null) return {'sessions': <dynamic>[], 'base': <String, dynamic>{}};
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      m['sessions'] ??= <dynamic>[];
      m['base'] ??= <String, dynamic>{};
      return m;
    } catch (_) {
      return {'sessions': <dynamic>[], 'base': <String, dynamic>{}};
    }
  }

  static Future<List<WritingSession>> load(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final m = await _raw(prefs, uid);
    return (m['sessions'] as List)
        .whereType<Map<String, dynamic>>()
        .map(WritingSession.fromJson)
        .toList();
  }

  static Future<void> record(
    String uid, {
    required String documentId,
    String? projectId,
    required int wordCount,
    int typed = 0,
    int pasted = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final m = await _raw(prefs, uid);
    final base = (m['base'] as Map).cast<String, dynamic>();
    final prev = (base[documentId] as num?)?.toInt();
    final delta = (prev == null || wordCount <= prev) ? 0 : wordCount - prev;
    base[documentId] = wordCount;

    final now = DateTime.now();
    final sessions = (m['sessions'] as List).toList();
    var extended = false;
    if (sessions.isNotEmpty) {
      final last = sessions.last as Map<String, dynamic>;
      final lastEnd = DateTime.tryParse(last['e'] as String? ?? '');
      if (lastEnd != null && now.difference(lastEnd) <= _gap) {
        last['e'] = now.toIso8601String();
        last['w'] = ((last['w'] as num?)?.toInt() ?? 0) + delta;
        last['t'] = ((last['t'] as num?)?.toInt() ?? 0) + typed;
        last['p'] = ((last['p'] as num?)?.toInt() ?? 0) + pasted;
        extended = true;
      }
    }
    if (!extended) {
      sessions.add({
        's': now.toIso8601String(),
        'e': now.toIso8601String(),
        'w': delta,
        'd': _ymd(now),
        'doc': documentId,
        'proj': projectId,
        't': typed,
        'p': pasted,
      });
    }
    m['sessions'] = sessions;
    m['base'] = base;
    await prefs.setString(_key(uid), jsonEncode(m));
  }

  /// Seed a document's baseline once (at open) so the first save counts words.
  static Future<void> seed(String uid,
      {required String documentId, required int wordCount}) async {
    final prefs = await SharedPreferences.getInstance();
    final m = await _raw(prefs, uid);
    final base = (m['base'] as Map).cast<String, dynamic>();
    if (base.containsKey(documentId)) return;
    base[documentId] = wordCount;
    m['base'] = base;
    await prefs.setString(_key(uid), jsonEncode(m));
  }
}

/// Bumped on every recorded save so the Analytics summary recomputes live.
final writingSessionsRevisionProvider = StateProvider<int>((ref) => 0);

class WritingSessionTracker {
  WritingSessionTracker(this._ref);
  final Ref _ref;

  Future<void> recordSave({
    required String documentId,
    String? projectId,
    required int wordCount,
    int typed = 0,
    int pasted = 0,
  }) async {
    final uid = _ref.read(currentUserIdProvider);
    if (uid == null) return;
    await WritingSessionStore.record(uid,
        documentId: documentId,
        projectId: projectId,
        wordCount: wordCount,
        typed: typed,
        pasted: pasted);
    _ref.read(writingSessionsRevisionProvider.notifier).state++;
  }

  Future<void> seedBaseline(String documentId, int wordCount) async {
    final uid = _ref.read(currentUserIdProvider);
    if (uid == null) return;
    await WritingSessionStore.seed(uid,
        documentId: documentId, wordCount: wordCount);
  }
}

final writingSessionTrackerProvider =
    Provider<WritingSessionTracker>((ref) => WritingSessionTracker(ref));

class WriterStats {
  const WriterStats({
    required this.hasData,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalSessions,
    required this.sessionsThisWeek,
    required this.avgSessionMin,
    required this.wordsToday,
    required this.wordsThisWeek,
    required this.wordsThisMonth,
    required this.wordsTracked,
    required this.productiveHour,
    required this.productiveWeekday,
    required this.dailyWords,
    required this.typedChars,
    required this.pastedChars,
  });

  final bool hasData;
  final int currentStreak;
  final int longestStreak;
  final int totalSessions;
  final int sessionsThisWeek;
  final int avgSessionMin;
  final int wordsToday;
  final int wordsThisWeek;
  final int wordsThisMonth;
  final int wordsTracked;
  final int? productiveHour;
  final int? productiveWeekday;
  final Map<String, int> dailyWords;
  final int typedChars;
  final int pastedChars;

  static const empty = WriterStats(
    hasData: false, currentStreak: 0, longestStreak: 0, totalSessions: 0,
    sessionsThisWeek: 0, avgSessionMin: 0, wordsToday: 0, wordsThisWeek: 0,
    wordsThisMonth: 0, wordsTracked: 0, productiveHour: null, productiveWeekday: null,
    dailyWords: const {}, typedChars: 0, pastedChars: 0,
  );

  String? get productiveHourLabel {
    final h = productiveHour;
    if (h == null) return null;
    final am = h < 12;
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12 ${am ? 'AM' : 'PM'}';
  }

  String? get productiveWeekdayLabel {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final d = productiveWeekday;
    if (d == null || d < 1 || d > 7) return null;
    return names[d - 1];
  }

  /// Percent of characters typed vs pasted (null when nothing recorded yet).
  int? get typedPct {
    final total = typedChars + pastedChars;
    if (total == 0) return null;
    return (typedChars * 100 / total).round();
  }

  /// Total words per week for the last [weeks] weeks (oldest first, newest
  /// last). Buckets the locally-recorded daily rollup by 7-day windows
  /// ending today.
  List<int> weeklyWords([int weeks = 8]) {
    final out = List<int>.filled(weeks, 0);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    dailyWords.forEach((k, v) {
      final d = DateTime.tryParse(k);
      if (d == null) return;
      final daysAgo = start.difference(DateTime(d.year, d.month, d.day)).inDays;
      if (daysAgo < 0 || daysAgo >= weeks * 7) return;
      out[weeks - 1 - (daysAgo ~/ 7)] += v;
    });
    return out;
  }

  static int _streakEndingAt(Set<String> days, DateTime start) {
    var n = 0;
    var c = start;
    while (days.contains(_ymd(c))) {
      n++;
      c = c.subtract(const Duration(days: 1));
    }
    return n;
  }

  factory WriterStats.from(List<WritingSession> sessions) {
    if (sessions.isEmpty) return WriterStats.empty;
    final now = DateTime.now();
    final today = _ymd(now);
    final weekAgo = now.subtract(const Duration(days: 7));
    final days = sessions.map((s) => s.day).where((d) => d.isNotEmpty).toSet();

    final startDay = DateTime(now.year, now.month, now.day);
    var current = _streakEndingAt(days, startDay);
    if (current == 0) {
      current = _streakEndingAt(days, startDay.subtract(const Duration(days: 1)));
    }

    final sorted = days.toList()..sort();
    var longest = 0, run = 0;
    DateTime? prev;
    for (final d in sorted) {
      final dt = DateTime.tryParse(d);
      if (dt == null) continue;
      if (prev != null && dt.difference(prev).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
      prev = dt;
    }

    var wToday = 0, wWeek = 0, wMonth = 0, wAll = 0, sessWeek = 0, totalDur = 0;
    var typedC = 0, pastedC = 0;
    final hour = <int, int>{};
    final dow = <int, int>{};
    final daily = <String, int>{};
    for (final s in sessions) {
      wAll += s.words;
      typedC += s.typed;
      pastedC += s.pasted;
      if (s.day == today) wToday += s.words;
      if (s.start.isAfter(weekAgo)) {
        wWeek += s.words;
        sessWeek++;
      }
      if (s.start.year == now.year && s.start.month == now.month) {
        wMonth += s.words;
      }
      hour[s.start.hour] = (hour[s.start.hour] ?? 0) + 1;
      dow[s.start.weekday] = (dow[s.start.weekday] ?? 0) + 1;
      totalDur += s.durationS;
      daily[s.day] = (daily[s.day] ?? 0) + s.words;
    }
    int? mode(Map<int, int> m) => m.isEmpty
        ? null
        : (m.entries.reduce((a, b) => a.value >= b.value ? a : b).key);

    return WriterStats(
      hasData: true,
      currentStreak: current,
      longestStreak: longest,
      totalSessions: sessions.length,
      sessionsThisWeek: sessWeek,
      avgSessionMin: (totalDur / sessions.length / 60).round(),
      wordsToday: wToday,
      wordsThisWeek: wWeek,
      wordsThisMonth: wMonth,
      wordsTracked: wAll,
      productiveHour: mode(hour),
      productiveWeekday: mode(dow),
      dailyWords: daily,
      typedChars: typedC,
      pastedChars: pastedC,
    );
  }
}

final writerStatsProvider = FutureProvider.autoDispose<WriterStats>((ref) async {
  ref.watch(writingSessionsRevisionProvider);
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return WriterStats.empty;
  final sessions = await WritingSessionStore.load(uid);
  return WriterStats.from(sessions);
});
