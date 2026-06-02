import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// A tokenized word with its character range in the source string.
///
/// [start]/[len] are offsets into the string passed to [tokenizeWords].
/// For the unified DOCX editor that string is `document.toPlainText()`,
/// whose offsets are the same character indices `QuillController.formatText`
/// expects — so a token range can drive `formatText` directly.
typedef WordToken = ({int start, int len, String word});

/// Split [text] into word tokens. Matches runs of ASCII letters with
/// optional internal apostrophes (e.g. "don't", "O'Brien"). Digits,
/// punctuation, whitespace, and embed placeholders (U+FFFC, used by
/// flutter_quill for embeds like page breaks) are not matched, so they are
/// skipped naturally.
Iterable<WordToken> tokenizeWords(String text) sync* {
  for (final m in _wordRe.allMatches(text)) {
    yield (start: m.start, len: m.end - m.start, word: m.group(0)!);
  }
}

final RegExp _wordRe = RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)*");

/// Offline English spellcheck dictionary.
///
/// Loads a newline-delimited word-list asset exactly once, parsing it into a
/// lowercased `Set<String>` on a background isolate (via [compute]) so the
/// UI thread never janks. Membership is the spellcheck signal: a word whose
/// lowercased form is absent from the set is treated as misspelled.
///
/// Fail-safe by design: if the asset is missing or unreadable the dictionary
/// still becomes [ready] with an EMPTY set, and [isMisspelled] then returns
/// false for everything — no crash, no squiggles. A warning is logged.
class SpellDictionary {
  SpellDictionary._();

  /// Process-wide singleton. The loaded set survives editor open/close, so
  /// re-entering edit mode reuses the already-parsed dictionary.
  static final SpellDictionary instance = SpellDictionary._();

  static const String _assetPath = 'assets/dictionaries/scowl_en_US_60.txt';

  Set<String> _words = <String>{};
  Future<void>? _loading;

  /// Number of words currently loaded (0 until [ready] completes, or if the
  /// load failed safe). Exposed for diagnostics/logging.
  int get wordCount => _words.length;

  /// Completes when the dictionary has loaded (or failed safe). Idempotent:
  /// the asset is read at most once; concurrent callers share the future.
  Future<void> get ready => _loading ??= _load();

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(_assetPath);
      _words = await compute(_parseWordList, raw);
      debugPrint(
          '[SpellDictionary] loaded ${_words.length} words from $_assetPath');
    } catch (e) {
      debugPrint(
          '[SpellDictionary] WARNING: could not load $_assetPath — spellcheck '
          'disabled (empty dictionary, nothing flagged). error=$e');
      _words = <String>{};
    }
  }

  /// True when [word] should be flagged as misspelled.
  ///
  /// Returns false (not flagged) when the dictionary is empty (load failed),
  /// the word is shorter than 2 chars, is an all-caps acronym, or contains a
  /// digit. Otherwise flags when the lowercased word is not in the set.
  bool isMisspelled(String word) {
    if (_words.isEmpty) return false;
    if (word.length < 2) return false;
    if (_containsDigit(word)) return false;
    if (_isAllCaps(word)) return false;
    return !_words.contains(word.toLowerCase());
  }

  static bool _containsDigit(String s) {
    for (final c in s.codeUnits) {
      if (c >= 0x30 && c <= 0x39) return true; // '0'..'9'
    }
    return false;
  }

  /// All-caps = contains at least one ASCII letter and no lowercase letter
  /// (e.g. "USA", "PDF"). Used to skip acronyms.
  static bool _isAllCaps(String s) {
    var hasLetter = false;
    for (final c in s.codeUnits) {
      if (c >= 0x61 && c <= 0x7A) return false; // a lowercase letter present
      if (c >= 0x41 && c <= 0x5A) hasLetter = true; // 'A'..'Z'
    }
    return hasLetter;
  }
}

/// Parse a SCOWL-style word list into a lowercased `Set<String>`.
///
/// Top-level so it can run in a background isolate via [compute]. The file
/// opens with a header/copyright block terminated by a line whose trimmed
/// value is exactly "---"; everything up to and including that separator is
/// skipped, and each non-empty trimmed line after it is added (lowercased).
///
/// Defensive fallback: if no "---" separator is found, add only single-token
/// (whitespace-free) lines so the dictionary isn't silently empty — and log a
/// warning so the malformed asset is visible.
Set<String> _parseWordList(String raw) {
  final lines = const LineSplitter().convert(raw);

  var sepIndex = -1;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trim() == '---') {
      sepIndex = i;
      break;
    }
  }

  final out = <String>{};
  if (sepIndex >= 0) {
    for (var i = sepIndex + 1; i < lines.length; i++) {
      final w = lines[i].trim();
      if (w.isEmpty) continue;
      out.add(w.toLowerCase());
    }
  } else {
    debugPrint(
        '[SpellDictionary] WARNING: no "---" header separator found in word '
        'list — falling back to whitespace-free lines only.');
    for (final line in lines) {
      final w = line.trim();
      if (w.isEmpty || w.contains(_whitespaceRe)) continue;
      out.add(w.toLowerCase());
    }
  }
  return out;
}

final RegExp _whitespaceRe = RegExp(r'\s');
