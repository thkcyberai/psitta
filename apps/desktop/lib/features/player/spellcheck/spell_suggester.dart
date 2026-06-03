/// Offline spelling-suggestion generator (Norvig-style edit distance).
///
/// Produces ranked correction candidates for a misspelled word using only the
/// in-memory [SpellDictionary] set — no network, no API. Edit-distance-1
/// candidates (deletes / transposes / replaces / inserts) are filtered by set
/// membership; edit-distance-2 is generated (edits of the edit-1 strings, NOT a
/// full alphabet-squared sweep) only when edit-1 yields too few known words.
///
/// Ranking: edit-1 before edit-2; within a tier prefer a shared first letter,
/// then the smallest length delta from the input, then alphabetical. Capped at
/// [_maxSuggestions]. Case of the input is re-applied to suggestions.
library;

import 'spell_dictionary.dart';

const int _maxSuggestions = 7;
const String _alphabet = 'abcdefghijklmnopqrstuvwxyz';

/// Ranked offline spelling suggestions for [word] (best first), capped at 7.
///
/// Returns an empty list when nothing is found. [dictionary] defaults to the
/// process-wide [SpellDictionary] singleton (injectable for tests).
List<String> suggest(String word, {SpellDictionary? dictionary}) {
  final dict = dictionary ?? SpellDictionary.instance;
  final lower = word.toLowerCase();
  if (lower.isEmpty) return const <String>[];

  // Tier 1 — edits at distance 1 that are real words.
  final e1 = _edits1(lower);
  final known1 = <String>{};
  for (final e in e1) {
    if (e != lower && dict.knows(e)) known1.add(e);
  }

  // Tier 2 — edits of the edit-1 strings, only if tier 1 is thin (< 3).
  final known2 = <String>{};
  if (known1.length < 3) {
    for (final e in e1) {
      for (final e2 in _edits1(e)) {
        if (e2 != lower && !known1.contains(e2) && dict.knows(e2)) {
          known2.add(e2);
        }
      }
    }
  }

  final casing = _casingOf(word);
  final ranked = <String>[
    ..._rankTier(known1.toList(), lower),
    ..._rankTier(known2.toList(), lower),
  ];

  final out = <String>[];
  for (final candidate in ranked) {
    out.add(_recase(candidate, casing));
    if (out.length >= _maxSuggestions) break;
  }
  return out;
}

/// All strings one edit away from [w] (lowercased). Classic Norvig set:
/// deletes, transposes, single-character replaces, and inserts over a–z.
Set<String> _edits1(String w) {
  final result = <String>{};
  final n = w.length;
  for (var i = 0; i <= n; i++) {
    final left = w.substring(0, i);
    final right = w.substring(i);
    // delete
    if (right.isNotEmpty) result.add(left + right.substring(1));
    // transpose
    if (right.length > 1) {
      result.add(left + right[1] + right[0] + right.substring(2));
    }
    // replace
    if (right.isNotEmpty) {
      final rest = right.substring(1);
      for (var c = 0; c < 26; c++) {
        result.add(left + _alphabet[c] + rest);
      }
    }
    // insert
    for (var c = 0; c < 26; c++) {
      result.add(left + _alphabet[c] + right);
    }
  }
  return result;
}

/// Sort one tier in place by: shared first letter with [lower], then smallest
/// length delta from [lower], then alphabetical.
List<String> _rankTier(List<String> tier, String lower) {
  final firstChar = lower.isNotEmpty ? lower[0] : '';
  tier.sort((a, b) {
    final aShare = (a.isNotEmpty && a[0] == firstChar) ? 0 : 1;
    final bShare = (b.isNotEmpty && b[0] == firstChar) ? 0 : 1;
    if (aShare != bShare) return aShare - bShare;
    final aDelta = (a.length - lower.length).abs();
    final bDelta = (b.length - lower.length).abs();
    if (aDelta != bDelta) return aDelta - bDelta;
    return a.compareTo(b);
  });
  return tier;
}

enum _Casing { asIs, capitalized, upper }

/// Detect the input's casing so suggestions (always lowercased in the set) can
/// be re-cased to match. ALLCAPS → upper; Titlecase (leading capital + a
/// lowercase letter) → capitalized; otherwise leave as-is.
_Casing _casingOf(String word) {
  var hasLetter = false;
  var hasLower = false;
  for (final c in word.codeUnits) {
    if (c >= 0x61 && c <= 0x7A) {
      hasLower = true;
      hasLetter = true;
    } else if (c >= 0x41 && c <= 0x5A) {
      hasLetter = true;
    }
  }
  if (hasLetter && !hasLower) return _Casing.upper; // ALLCAPS
  if (word.isNotEmpty) {
    final f = word.codeUnitAt(0);
    if (f >= 0x41 && f <= 0x5A && hasLower) return _Casing.capitalized;
  }
  return _Casing.asIs;
}

String _recase(String candidate, _Casing casing) {
  switch (casing) {
    case _Casing.upper:
      return candidate.toUpperCase();
    case _Casing.capitalized:
      if (candidate.isEmpty) return candidate;
      return candidate[0].toUpperCase() + candidate.substring(1);
    case _Casing.asIs:
      return candidate;
  }
}
