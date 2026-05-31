import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/theme/psitta_tokens.dart';
import '../../../data/providers/providers.dart';
import '../../../data/services/audio_service.dart';

class PdfReadingHighlight {
  const PdfReadingHighlight({
    required this.pageNumber,
    required this.chunkIndex,
    required this.sentenceIndex,
    this.endSentenceIndex,
  });

  final int pageNumber;
  final int chunkIndex;
  final int sentenceIndex;
  final int? endSentenceIndex;
}

class PdfSentenceTarget {
  const PdfSentenceTarget({
    required this.pageNumber,
    required this.chunkIndex,
    required this.sentenceIndex,
  });

  final int pageNumber;
  final int chunkIndex;
  final int sentenceIndex;
}

class _ResolvedPdfSentence {
  const _ResolvedPdfSentence({
    required this.pageNumber,
    required this.chunkIndex,
    required this.sentenceIndex,
    required this.rects,
    required this.pageCharStart,
    required this.pageCharEnd,
  });

  final int pageNumber;
  final int chunkIndex;
  final int sentenceIndex;
  final List<PdfRect> rects;
  // PDF page-text char range this sentence occupies (in pageText.fullText
  // coordinates). Populated at cache-build time so per-tick word resolution
  // can scope its search to ONE sentence instead of the whole page.
  final int pageCharStart;
  final int pageCharEnd;

  bool contains(Offset offset) {
    for (final rect in rects) {
      if (rect.containsOffset(offset)) {
        return true;
      }
    }
    return false;
  }

  bool matchesHighlight(PdfReadingHighlight highlight) {
    return pageNumber == highlight.pageNumber &&
        chunkIndex == highlight.chunkIndex &&
        sentenceIndex == highlight.sentenceIndex;
  }

  bool matchesTarget(PdfSentenceTarget target) {
    return pageNumber == target.pageNumber &&
        chunkIndex == target.chunkIndex &&
        sentenceIndex == target.sentenceIndex;
  }
}

class _NormalizedPdfText {
  const _NormalizedPdfText({
    required this.text,
    required this.normalizedToOriginal,
  });

  final String text;
  final List<int> normalizedToOriginal;
}

bool _looksLikePdfPageNumberLine(String line, int? pageNumber) {
  var stripped = line.trim();
  stripped = stripped.replaceAll(
    RegExp(r'^[\s\[\](){}<>#*~.:|\-]+'),
    '',
  );
  stripped = stripped.replaceAll(
    RegExp(r'[\s\[\](){}<>#*~.:|\-]+$'),
    '',
  );
  if (stripped.isEmpty) return false;
  if (pageNumber != null) {
    if (stripped == '$pageNumber') return true;
    if (RegExp(
      '^page\\s+$pageNumber(?:\\s+of\\s+\\d+)?\$',
      caseSensitive: false,
    ).hasMatch(stripped)) {
      return true;
    }
    if (RegExp('^$pageNumber\\s*/\\s*\\d+\$').hasMatch(stripped)) {
      return true;
    }
  }
  if (RegExp(r'^page\s+[ivxlcdm]{1,8}$', caseSensitive: false)
      .hasMatch(stripped)) {
    return true;
  }
  if (RegExp(r'^[ivxlcdm]{2,8}$', caseSensitive: false).hasMatch(stripped)) {
    return true;
  }
  return RegExp(
    r'^page\s+\d+(?:\s+of\s+\d+)?$',
    caseSensitive: false,
  ).hasMatch(stripped);
}

/// Player-only viewport for rendering the original uploaded PDF as a
/// page-faithful vertical document stack inside the Psitta shell.
class PdfDocumentViewport extends ConsumerStatefulWidget {
  const PdfDocumentViewport({
    super.key,
    required this.documentId,
    required this.chunks,
    this.controller,
    this.onDocumentLoaded,
    this.onSentenceTap,
    this.onPageTap,
    this.highlight,
    this.alignmentPayload,
  });

  final String documentId;
  final List<dynamic> chunks;
  final PdfViewerController? controller;
  final void Function(
    PdfDocumentRef documentRef,
    List<PdfOutlineNode> outline,
  )? onDocumentLoaded;
  final void Function(PdfSentenceTarget target)? onSentenceTap;
  final void Function(PdfPageHitTestResult hitTest)? onPageTap;
  final PdfReadingHighlight? highlight;
  final Map<String, dynamic>? alignmentPayload;

  @override
  ConsumerState<PdfDocumentViewport> createState() =>
      _PdfDocumentViewportState();
}

class _PdfDocumentViewportState extends ConsumerState<PdfDocumentViewport> {
  late final Future<File> _pdfFileFuture;
  late final PdfViewerController _viewerController;
  late final Stopwatch _openStopwatch;
  final Map<int, PdfPageText> _pageTextCache = {};
  final Map<int, Future<PdfPageText?>> _pageTextFutures = {};
  final Map<int, List<_ResolvedPdfSentence>> _pageSentenceCache = {};
  final Map<int, Future<List<_ResolvedPdfSentence>>> _pageSentenceFutures = {};
  _ResolvedPdfSentence? _resolvedHighlight;
  PdfSentenceTarget? _hoveredSentence;
  String? _lastHighlightSignature;
  String? _lastAutoEnsuredHighlightSignature;
  int _highlightResolveSeq = 0;
  int _hoverResolveSeq = 0;
  bool _loggedFirstPagePaint = false;

  // Word-level highlight state
  List<PdfRect> _activeWordRects = const [];
  int? _activeWordPageNumber;

  void _logPdfPerf(String stage, String message) {
    debugPrint('[PDF PERF][$stage] $message');
  }

  Future<File> _loadPdfFile() async {
    _logPdfPerf(
      'open',
      'viewport_init doc=${widget.documentId}',
    );
    final file = await ref.read(documentRepositoryProvider).downloadDocumentToTempFile(
          widget.documentId,
          extension: '.pdf',
        );
    _logPdfPerf(
      'open',
      'viewport_file_ready doc=${widget.documentId} elapsed=${_openStopwatch.elapsedMilliseconds}ms path=${file.path}',
    );
    return file;
  }

  @override
  void initState() {
    super.initState();
    _viewerController = widget.controller ?? PdfViewerController();
    _openStopwatch = Stopwatch()..start();
    _pdfFileFuture = _loadPdfFile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _queueHighlightResolution(force: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant PdfDocumentViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.chunks, widget.chunks) ||
        oldWidget.documentId != widget.documentId) {
      _pageSentenceCache.clear();
      _pageSentenceFutures.clear();
      _resolvedHighlight = null;
      _hoveredSentence = null;
      _lastHighlightSignature = null;
      _lastAutoEnsuredHighlightSignature = null;
    }
    if (oldWidget.highlight != widget.highlight ||
        oldWidget.documentId != widget.documentId ||
        !identical(oldWidget.chunks, widget.chunks)) {
      _queueHighlightResolution(force: true);
    }
  }

  Future<void> _handleDocumentChanged(
    PdfDocumentRef documentRef,
    PdfDocument? document,
  ) async {
    _pageTextCache.clear();
    _pageTextFutures.clear();
    _pageSentenceCache.clear();
    _pageSentenceFutures.clear();
    _lastHighlightSignature = null;
    _lastAutoEnsuredHighlightSignature = null;
    _loggedFirstPagePaint = false;
    if (mounted) {
      setState(() {
        _resolvedHighlight = null;
        _hoveredSentence = null;
      });
    }
    _queueHighlightResolution(force: true);
    if (document == null || widget.onDocumentLoaded == null) {
      return;
    }
    _logPdfPerf(
      'open',
      'pdfrx_document_ready doc=${widget.documentId} elapsed=${_openStopwatch.elapsedMilliseconds}ms pages=${document.pages.length}',
    );
    final outlineStopwatch = Stopwatch()..start();
    final outline = await document.loadOutline();
    outlineStopwatch.stop();
    _logPdfPerf(
      'open',
      'outline_ready doc=${widget.documentId} elapsed=${_openStopwatch.elapsedMilliseconds}ms outlineElapsed=${outlineStopwatch.elapsedMilliseconds}ms items=${outline.length}',
    );
    if (!mounted) return;
    widget.onDocumentLoaded!(documentRef, outline);
  }

  String? _highlightSignature(PdfReadingHighlight? highlight) {
    if (highlight == null) return null;
    return [
      highlight.pageNumber,
      highlight.chunkIndex,
      highlight.sentenceIndex,
      highlight.endSentenceIndex,
    ].join(':');
  }

  Future<PdfPageText?> _loadPageText(int pageNumber) {
    final cached = _pageTextCache[pageNumber];
    if (cached != null) {
      return Future.value(cached);
    }
    return _pageTextFutures.putIfAbsent(pageNumber, () async {
      try {
        final pageText = await _viewerController.useDocument<PdfPageText?>(
          (document) async => document.pages[pageNumber - 1].loadText(),
        );
        if (pageText != null) {
          _pageTextCache[pageNumber] = pageText;
        }
        return pageText;
      } catch (_) {
        return null;
      }
    });
  }

  List<int> _pageChunkIndices(int pageNumber) {
    final indices = <int>[];
    for (var i = 0; i < widget.chunks.length; i++) {
      final chunk = widget.chunks[i] as Map<String, dynamic>;
      final chunkPage = (chunk['page_number'] as num?)?.toInt() ?? 1;
      if (chunkPage == pageNumber) {
        indices.add(i);
      }
    }
    return indices;
  }

  ({int start, int end, String text})? _trimmedSentenceRange(
    String chunkText,
    List<dynamic> boundary,
  ) {
    var start =
        (boundary[0] as num).toInt().clamp(0, chunkText.length).toInt();
    var end =
        (boundary[1] as num).toInt().clamp(start, chunkText.length).toInt();
    while (start < end && RegExp(r'\s').hasMatch(chunkText[start])) {
      start++;
    }
    while (end > start && RegExp(r'\s').hasMatch(chunkText[end - 1])) {
      end--;
    }
    if (start >= end) return null;
    return (
      start: start,
      end: end,
      text: chunkText.substring(start, end),
    );
  }

  _NormalizedPdfText _normalizePdfText(
    String source, {
    int? pageNumber,
    bool loose = false,
  }) {
    final text = StringBuffer();
    final normalizedToOriginal = <int>[];
    var pendingSpace = false;
    var pendingSpaceIndex = -1;
    var originalIndex = 0;

    void appendToken(String token, int sourceIndex) {
      if (token.isEmpty) return;
      if (token == ' ') {
        if (text.isNotEmpty) {
          pendingSpace = true;
          pendingSpaceIndex = sourceIndex;
        }
        return;
      }
      if (pendingSpace) {
        text.write(' ');
        normalizedToOriginal.add(pendingSpaceIndex);
        pendingSpace = false;
      }
      for (final rune in token.runes) {
        text.write(String.fromCharCode(rune));
        normalizedToOriginal.add(sourceIndex);
      }
    }

    String normalizeChar(String char) {
      switch (char) {
        case '\u2018':
        case '\u2019':
        case '\u2032':
          return "'";
        case '\u201C':
        case '\u201D':
        case '\u2033':
          return '"';
        case '\u2013':
        case '\u2014':
        case '\u2212':
          return '-';
        case '\u2026':
          return '...';
        case '\u00AD':
        case '\u200B':
        case '\u200C':
        case '\u200D':
        case '\uFEFF':
          return '';
        case '\uFB01':
          return 'fi';
        case '\uFB02':
          return 'fl';
      }
      if (RegExp(r'\s').hasMatch(char)) {
        return ' ';
      }
      final lower = char.toLowerCase();
      if (loose) {
        if (RegExp(r'[a-z0-9]').hasMatch(lower)) {
          return lower;
        }
        return '';
      }
      return lower;
    }

    for (final line in source.split('\n')) {
      final lineStartIndex = originalIndex;
      originalIndex += line.length + 1;
      if (_looksLikePdfPageNumberLine(line, pageNumber)) {
        continue;
      }
      for (var i = 0; i < line.length; i++) {
        appendToken(normalizeChar(line[i]), lineStartIndex + i);
      }
      appendToken(' ', lineStartIndex + line.length);
    }

    return _NormalizedPdfText(
      text: text.toString(),
      normalizedToOriginal: normalizedToOriginal,
    );
  }

  int _cursorForOriginalOffset(
    _NormalizedPdfText normalizedPage,
    int originalOffset,
  ) {
    final mapping = normalizedPage.normalizedToOriginal;
    var low = 0;
    var high = mapping.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (mapping[mid] < originalOffset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low.clamp(0, mapping.length).toInt();
  }

  ({int start, int end})? _findOrderedMatch(
    _NormalizedPdfText normalizedPage,
    String sentenceText,
    int cursor, {
    required bool loose,
  }) {
    final normalizedSentence = _normalizePdfText(
      sentenceText,
      loose: loose,
    ).text;
    if (normalizedSentence.isEmpty || normalizedPage.text.isEmpty) {
      return null;
    }

    final safeCursor = cursor.clamp(0, normalizedPage.text.length).toInt();
    final exactIndex = normalizedPage.text.indexOf(normalizedSentence, safeCursor);
    if (exactIndex >= 0) {
      return (start: exactIndex, end: exactIndex + normalizedSentence.length);
    }

    final lookback = math.min(96, normalizedSentence.length * 2);
    final fallbackStart = math.max(0, safeCursor - lookback);
    var searchIndex = normalizedPage.text.indexOf(normalizedSentence, fallbackStart);
    while (searchIndex >= 0) {
      if (searchIndex + normalizedSentence.length > safeCursor) {
        return (
          start: searchIndex,
          end: searchIndex + normalizedSentence.length,
        );
      }
      searchIndex = normalizedPage.text.indexOf(
        normalizedSentence,
        searchIndex + 1,
      );
    }
    return null;
  }

  ({int start, int end})? _findAnchoredLooseMatch(
    _NormalizedPdfText normalizedPage,
    String sentenceText,
    int cursor,
  ) {
    final normalizedSentence = _normalizePdfText(
      sentenceText,
      loose: true,
    ).text;
    if (normalizedSentence.length < 12 || normalizedPage.text.isEmpty) {
      return null;
    }

    final safeCursor = cursor.clamp(0, normalizedPage.text.length).toInt();
    final anchorLength = math.min(
      28,
      math.max(12, normalizedSentence.length ~/ 3),
    );
    final prefix = normalizedSentence.substring(0, anchorLength);
    final suffix = normalizedSentence.substring(
      normalizedSentence.length - anchorLength,
    );

    final prefixMatch = _findOrderedMatch(
      normalizedPage,
      prefix,
      safeCursor,
      loose: true,
    );
    if (prefixMatch == null) {
      return null;
    }

    final suffixCursor = math.max(prefixMatch.start + anchorLength, safeCursor)
        .clamp(0, normalizedPage.text.length)
        .toInt();
    final minLength = math.max(anchorLength * 2, normalizedSentence.length - 24);
    final maxLength = normalizedSentence.length + 40;
    var bestDelta = 1 << 30;
    ({int start, int end})? bestMatch;

    var suffixIndex = normalizedPage.text.indexOf(suffix, suffixCursor);
    while (suffixIndex >= 0) {
      final candidateEnd = suffixIndex + anchorLength;
      final candidateLength = candidateEnd - prefixMatch.start;
      if (candidateLength > maxLength) {
        break;
      }
      if (candidateLength >= minLength) {
        final delta = (candidateLength - normalizedSentence.length).abs();
        if (delta < bestDelta) {
          bestDelta = delta;
          bestMatch = (start: prefixMatch.start, end: candidateEnd);
          if (delta == 0) {
            break;
          }
        }
      }
      suffixIndex = normalizedPage.text.indexOf(suffix, suffixIndex + 1);
    }

    if (bestMatch == null || bestDelta > 18) {
      return null;
    }
    return bestMatch;
  }

  ({int start, int end}) _tightenSentenceRangeToWordEdges(
    String pageText,
    String sentenceText,
    int start,
    int end,
  ) {
    final wordMatches = RegExp(r"[A-Za-z0-9']+")
        .allMatches(sentenceText)
        .map((match) => match.group(0)!)
        .where((word) => word.length >= 2)
        .toList();
    if (wordMatches.isEmpty) {
      return (start: start, end: end);
    }

    final loweredWindow = pageText.toLowerCase();
    final firstWord = wordMatches.first.toLowerCase();
    final lastWord = wordMatches.last.toLowerCase();

    final windowStart = math.max(0, start - 32);
    final windowEnd = math.min(pageText.length, end + 64);
    final localText = loweredWindow.substring(windowStart, windowEnd);

    var tightenedStart = start;
    var bestStartDelta = 1 << 30;
    var firstIndex = localText.indexOf(firstWord);
    while (firstIndex >= 0) {
      final candidateStart = windowStart + firstIndex;
      final delta = (candidateStart - start).abs();
      if (candidateStart <= end && delta < bestStartDelta) {
        tightenedStart = candidateStart;
        bestStartDelta = delta;
      }
      firstIndex = localText.indexOf(firstWord, firstIndex + 1);
    }

    var tightenedEnd = end;
    var bestEndDelta = 1 << 30;
    var lastIndex = localText.indexOf(lastWord);
    while (lastIndex >= 0) {
      final candidateEnd = windowStart + lastIndex + lastWord.length;
      final delta = (candidateEnd - end).abs();
      if (candidateEnd >= tightenedStart && delta < bestEndDelta) {
        tightenedEnd = candidateEnd;
        bestEndDelta = delta;
      }
      lastIndex = localText.indexOf(lastWord, lastIndex + 1);
    }

    return (start: tightenedStart, end: tightenedEnd);
  }

  ({int start, int end}) _expandSentenceRangeToNaturalEdges(
    String pageText,
    int start,
    int end,
  ) {
    bool isLeadingDecoration(String char) {
      switch (char) {
        case '"':
        case '\'':
        case '\u201C':
        case '\u2018':
        case '(':
        case '[':
        case '{':
          return true;
      }
      return false;
    }

    bool isTrailingDecoration(String char) {
      switch (char) {
        case '"':
        case '\'':
        case '.':
        case '!':
        case '?':
        case ',':
        case ';':
        case ':':
        case ')':
        case ']':
        case '}':
        case '\u2026':
        case '\u201D':
        case '\u2019':
          return true;
      }
      return false;
    }

    var expandedStart = start.clamp(0, pageText.length).toInt();
    var expandedEnd = end.clamp(expandedStart, pageText.length).toInt();

    while (expandedStart > 0 &&
        isLeadingDecoration(pageText[expandedStart - 1])) {
      expandedStart--;
    }
    while (expandedEnd < pageText.length &&
        isTrailingDecoration(pageText[expandedEnd])) {
      expandedEnd++;
    }

    return (start: expandedStart, end: expandedEnd);
  }

  List<PdfRect> _mergeHighlightRects(List<PdfRect> rects) {
    if (rects.isEmpty) {
      return rects;
    }

    final sorted = [...rects]..sort((a, b) {
        final topDelta = (b.top - a.top).abs();
        if (topDelta > 1.5) {
          return b.top.compareTo(a.top);
        }
        return a.left.compareTo(b.left);
      });

    final merged = <PdfRect>[];
    for (final rect in sorted) {
      if (rect.isEmpty) {
        continue;
      }
      if (merged.isEmpty) {
        merged.add(rect);
        continue;
      }

      final last = merged.last;
      final verticalOverlap =
          math.min(last.top, rect.top) - math.max(last.bottom, rect.bottom);
      final sameLine = verticalOverlap >= -math.max(1.0, rect.height * 0.2);
      final gap = rect.left - last.right;
      final joinGap = math.max(last.height, rect.height) * 0.8;

      if (sameLine && gap <= joinGap) {
        merged[merged.length - 1] = PdfRect(
          math.min(last.left, rect.left),
          math.max(last.top, rect.top),
          math.max(last.right, rect.right),
          math.min(last.bottom, rect.bottom),
        );
      } else {
        merged.add(rect);
      }
    }

    return merged;
  }

  List<PdfRect> _rectsForTextRange(PdfTextRangeWithFragments range) {
    final rects = <PdfRect>[];
    for (var i = 0; i < range.fragments.length; i++) {
      final fragment = range.fragments[i];
      final localStart = i == 0 ? range.start : 0;
      final localEnd =
          i == range.fragments.length - 1 ? range.end : fragment.length;
      if (localStart >= localEnd) {
        continue;
      }
      final charRects = fragment.charRects;
      if (charRects != null && charRects.isNotEmpty) {
        final safeStart = localStart.clamp(0, charRects.length).toInt();
        final safeEnd = localEnd.clamp(safeStart, charRects.length).toInt();
        rects.addAll(charRects.sublist(safeStart, safeEnd));
      } else {
        rects.add(fragment.bounds);
      }
    }
    return _mergeHighlightRects(rects);
  }

  List<_ResolvedPdfSentence> _resolvePageSentences(
    PdfPageText pageText,
    int pageNumber,
  ) {
    final resolved = <_ResolvedPdfSentence>[];
    final normalizedPage = _normalizePdfText(
      pageText.fullText,
      pageNumber: pageNumber,
    );
    final loosePage = _normalizePdfText(
      pageText.fullText,
      pageNumber: pageNumber,
      loose: true,
    );
    var exactCursor = 0;
    var looseCursor = 0;

    for (final chunkIndex in _pageChunkIndices(pageNumber)) {
      final chunk = widget.chunks[chunkIndex] as Map<String, dynamic>;
      final chunkText = (chunk['text_content'] ?? '').toString();
      final sentenceBoundaries =
          chunk['sentence_boundaries'] as List<dynamic>? ?? const [];

      for (var sentenceIndex = 0;
          sentenceIndex < sentenceBoundaries.length;
          sentenceIndex++) {
        final boundary = sentenceBoundaries[sentenceIndex] as List<dynamic>;
        final trimmedRange = _trimmedSentenceRange(chunkText, boundary);
        if (trimmedRange == null) {
          continue;
        }

        final exactMatch = _findOrderedMatch(
          normalizedPage,
          trimmedRange.text,
          exactCursor,
          loose: false,
        );
        final looseMatch = exactMatch == null
            ? _findOrderedMatch(
                loosePage,
                trimmedRange.text,
                looseCursor,
                loose: true,
              )
            : null;
        final anchoredMatch = exactMatch == null && looseMatch == null
            ? _findAnchoredLooseMatch(
                loosePage,
                trimmedRange.text,
                looseCursor,
              )
            : null;
        final activePage = exactMatch != null ? normalizedPage : loosePage;
        final chosenMatch = exactMatch ?? looseMatch ?? anchoredMatch;
        if (chosenMatch == null ||
            chosenMatch.start < 0 ||
            chosenMatch.end <= chosenMatch.start ||
            chosenMatch.end > activePage.normalizedToOriginal.length) {
          continue;
        }

        final originalStart = activePage.normalizedToOriginal[chosenMatch.start];
        final originalEnd =
            activePage.normalizedToOriginal[chosenMatch.end - 1] + 1;
        final tightenedRange = _tightenSentenceRangeToWordEdges(
          pageText.fullText,
          trimmedRange.text,
          originalStart,
          originalEnd,
        );
        final expandedRange = _expandSentenceRangeToNaturalEdges(
          pageText.fullText,
          tightenedRange.start,
          tightenedRange.end,
        );
        final range = PdfTextRangeWithFragments.fromTextRange(
          pageText,
          expandedRange.start,
          expandedRange.end,
        );
        if (range == null) {
          continue;
        }

        final rects = _rectsForTextRange(range);
        if (rects.isEmpty) {
          continue;
        }

        resolved.add(
          _ResolvedPdfSentence(
            pageNumber: pageNumber,
            chunkIndex: chunkIndex,
            sentenceIndex: sentenceIndex,
            rects: rects,
            pageCharStart: expandedRange.start,
            pageCharEnd: expandedRange.end,
          ),
        );
        exactCursor =
            _cursorForOriginalOffset(normalizedPage, expandedRange.end);
        looseCursor = _cursorForOriginalOffset(loosePage, expandedRange.end);
      }
    }

    return resolved;
  }

  PdfRect? _boundingPdfRect(List<PdfRect> rects) {
    if (rects.isEmpty) {
      return null;
    }
    var merged = rects.first;
    for (final rect in rects.skip(1)) {
      merged = merged.merge(rect);
    }
    return merged;
  }

  void _scheduleEnsureHighlightedSentenceVisible(_ResolvedPdfSentence sentence) {
    if (!_viewerController.isReady) {
      return;
    }
    final signature =
        '${sentence.pageNumber}:${sentence.chunkIndex}:${sentence.sentenceIndex}';
    if (_lastAutoEnsuredHighlightSignature == signature) {
      return;
    }
    _lastAutoEnsuredHighlightSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_viewerController.isReady) {
        return;
      }

      final sentenceBounds = _boundingPdfRect(sentence.rects);
      if (sentenceBounds == null) {
        return;
      }
      final documentRect = _viewerController.calcRectForRectInsidePage(
        pageNumber: sentence.pageNumber,
        rect: sentenceBounds,
      );
      final visibleRect = _viewerController.visibleRect;
      final lowerTrigger = visibleRect.bottom - (visibleRect.height * 0.18);
      if (documentRect.bottom <= lowerTrigger) {
        return;
      }

      await _viewerController.ensureVisible(
        documentRect.inflate(24),
        duration: const Duration(milliseconds: 260),
        margin: 24,
      );
    });
  }

  Future<List<_ResolvedPdfSentence>> _loadPageSentences(int pageNumber) {
    final cached = _pageSentenceCache[pageNumber];
    if (cached != null) {
      return Future.value(cached);
    }
    return _pageSentenceFutures.putIfAbsent(pageNumber, () async {
      final pageText = await _loadPageText(pageNumber);
      if (pageText == null) {
        return const <_ResolvedPdfSentence>[];
      }
      final resolved = _resolvePageSentences(pageText, pageNumber);
      _pageSentenceCache[pageNumber] = resolved;
      return resolved;
    });
  }

  _ResolvedPdfSentence? _findResolvedSentence(
    List<_ResolvedPdfSentence> sentences,
    PdfReadingHighlight highlight,
  ) {
    final endIdx = highlight.endSentenceIndex ?? highlight.sentenceIndex;
    final combinedRects = <PdfRect>[];
    _ResolvedPdfSentence? primary;
    for (final sentence in sentences) {
      if (sentence.pageNumber == highlight.pageNumber &&
          sentence.chunkIndex == highlight.chunkIndex &&
          sentence.sentenceIndex >= highlight.sentenceIndex &&
          sentence.sentenceIndex <= endIdx) {
        if (primary == null) primary = sentence;
        combinedRects.addAll(sentence.rects);
      }
    }
    if (primary == null) return null;
    if (combinedRects.length == primary.rects.length) return primary;
    return _ResolvedPdfSentence(
      pageNumber: primary.pageNumber,
      chunkIndex: primary.chunkIndex,
      sentenceIndex: primary.sentenceIndex,
      rects: combinedRects,
      pageCharStart: primary.pageCharStart,
      pageCharEnd: primary.pageCharEnd,
    );
    return null;
  }

  Future<_ResolvedPdfSentence?> _sentenceAtViewerOffset(Offset viewerOffset) async {
    final hitTest = _viewerController.getPdfPageHitTestResult(
      viewerOffset,
      useDocumentLayoutCoordinates: false,
    );
    if (hitTest == null) {
      return null;
    }
    final pageSentences = await _loadPageSentences(hitTest.page.pageNumber);
    for (final sentence in pageSentences) {
      if (sentence.contains(hitTest.offset)) {
        return sentence;
      }
    }
    return null;
  }

  void _setHoveredSentence(PdfSentenceTarget? target) {
    final current = _hoveredSentence;
    final isSame = current?.pageNumber == target?.pageNumber &&
        current?.chunkIndex == target?.chunkIndex &&
        current?.sentenceIndex == target?.sentenceIndex;
    if (isSame) return;
    setState(() {
      _hoveredSentence = target;
    });
    if (_viewerController.isReady) {
      _viewerController.invalidate();
    }
  }

  Future<void> _updateHoverFromViewerOffset(Offset viewerOffset) async {
    final requestId = ++_hoverResolveSeq;
    final sentence = await _sentenceAtViewerOffset(viewerOffset);
    if (!mounted || requestId != _hoverResolveSeq) return;
    _setHoveredSentence(
      sentence == null
          ? null
          : PdfSentenceTarget(
              pageNumber: sentence.pageNumber,
              chunkIndex: sentence.chunkIndex,
              sentenceIndex: sentence.sentenceIndex,
            ),
    );
  }

  void _queueHighlightResolution({bool force = false}) {
    final highlight = widget.highlight;
    final signature = _highlightSignature(highlight);
    if (!force && signature == _lastHighlightSignature) {
      return;
    }
    _lastHighlightSignature = signature;

    if (highlight == null) {
      if (_resolvedHighlight != null) {
        setState(() {
          _resolvedHighlight = null;
        });
        if (_viewerController.isReady) {
          _viewerController.invalidate();
        }
      }
      return;
    }

    final cachedSentences = _pageSentenceCache[highlight.pageNumber];
    if (cachedSentences != null) {
      final resolved = _findResolvedSentence(cachedSentences, highlight);
      final shouldUpdate = resolved != null ||
          _resolvedHighlight == null ||
          _resolvedHighlight!.pageNumber != highlight.pageNumber;
      if (shouldUpdate && _resolvedHighlight != resolved) {
        setState(() {
          _resolvedHighlight = resolved;
        });
        if (_viewerController.isReady) {
          _viewerController.invalidate();
        }
        if (resolved != null) {
          _scheduleEnsureHighlightedSentenceVisible(resolved);
        }
      }
      return;
    }

    final requestId = ++_highlightResolveSeq;
    unawaited(() async {
      final pageSentences = await _loadPageSentences(highlight.pageNumber);
      if (!mounted || requestId != _highlightResolveSeq) return;

      final resolved = _findResolvedSentence(pageSentences, highlight);
      final shouldUpdate = resolved != null ||
          _resolvedHighlight == null ||
          _resolvedHighlight!.pageNumber != highlight.pageNumber;
      if (shouldUpdate) {
        setState(() {
          _resolvedHighlight = resolved;
        });
        if (_viewerController.isReady) {
          _viewerController.invalidate();
        }
        if (resolved != null) {
          _scheduleEnsureHighlightedSentenceVisible(resolved);
        }
      }
    }());
  }

  // ── Word-level highlight resolution ─────────────────────────────────────

  int? _charIndexAtMs(Map<String, dynamic>? payload, int tMs) {
    final alignment = payload?['alignment'];
    if (alignment is! Map) return null;
    final normalized = alignment['normalized_alignment'];
    if (normalized is! Map) return null;
    final starts = normalized['character_start_times_seconds'];
    final ends = normalized['character_end_times_seconds'];
    if (starts is! List || ends is! List) return null;
    if (starts.isEmpty || starts.length != ends.length) return null;

    final t = tMs / 1000.0;
    for (var i = 0; i < starts.length; i++) {
      final s = starts[i];
      final e = ends[i];
      if (s is! num || e is! num) return null;
      if (t >= s.toDouble() && t <= e.toDouble()) return i;
    }

    final lastEnd = (ends.last as num).toDouble();
    if (t > lastEnd) return starts.length - 1;
    return null;
  }

  bool _isWordChar(String ch) {
    final c = ch.codeUnitAt(0);
    final isAlphaNum =
        (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
    return isAlphaNum || ch == "'";
  }

  void _resolveWordHighlight(Duration position) {
    final payload = widget.alignmentPayload;
    final highlight = widget.highlight;
    if (payload == null || highlight == null) {
      if (_activeWordRects.isNotEmpty) {
        setState(() {
          _activeWordRects = const [];
          _activeWordPageNumber = null;
        });
        if (_viewerController.isReady) _viewerController.invalidate();
      }
      return;
    }

    final charIdx = _charIndexAtMs(payload, position.inMilliseconds);
    if (charIdx == null) {
      if (_activeWordRects.isNotEmpty) {
        setState(() {
          _activeWordRects = const [];
          _activeWordPageNumber = null;
        });
        if (_viewerController.isReady) _viewerController.invalidate();
      }
      return;
    }

    // Get chunk text to expand charIdx to word boundaries
    final chunkIndex = highlight.chunkIndex;
    if (chunkIndex < 0 || chunkIndex >= widget.chunks.length) return;
    final chunk = widget.chunks[chunkIndex] as Map<String, dynamic>;
    final chunkText = (chunk['text_content'] ?? '').toString();
    if (chunkText.isEmpty || charIdx >= chunkText.length) return;

    // Expand to word boundaries. An ASCII hyphen-minus '-' (U+002D) that
    // sits BETWEEN two word chars is treated as part of the word, so
    // hyphenated compounds like "self-awareness" expand as a single unit
    // instead of one half per tick. Em-dash (U+2014) and en-dash (U+2013)
    // are intentionally NOT included — those are sentence-level separators.
    // The bounds checks (wStart >= 2, wEnd + 1 < length) prevent a range
    // error when a hyphen sits at a sentence edge.
    var wStart = charIdx;
    var wEnd = charIdx;
    while (wStart > 0) {
      final prev = chunkText[wStart - 1];
      if (_isWordChar(prev)) {
        wStart--;
        continue;
      }
      if (prev == '-' &&
          wStart >= 2 &&
          _isWordChar(chunkText[wStart - 2])) {
        wStart -= 2;
        continue;
      }
      break;
    }
    while (wEnd < chunkText.length) {
      final cur = chunkText[wEnd];
      if (_isWordChar(cur)) {
        wEnd++;
        continue;
      }
      if (cur == '-' &&
          wEnd + 1 < chunkText.length &&
          _isWordChar(chunkText[wEnd + 1])) {
        wEnd += 2;
        continue;
      }
      break;
    }
    if (wEnd <= wStart) return;

    final wordText = chunkText.substring(wStart, wEnd);
    final pageNumber = highlight.pageNumber;
    final pageText = _pageTextCache[pageNumber];
    if (pageText == null) return;

    // Identify the active sentence by walking chunk sentence boundaries
    // (cheap arithmetic — no string search). Captures sentenceIndex `si`
    // and the sentence's start offset in chunk-text coordinates for use
    // as a forward search hint inside the sentence's PDF text.
    final sentenceBoundaries =
        chunk['sentence_boundaries'] as List<dynamic>? ?? const [];
    int? activeSi;
    int? sentChunkStart;
    for (var si = 0; si < sentenceBoundaries.length; si++) {
      final boundary = sentenceBoundaries[si] as List<dynamic>;
      final sStart = (boundary[0] as num).toInt();
      final sEnd = (boundary[1] as num).toInt();
      if (wStart >= sStart && wStart < sEnd) {
        activeSi = si;
        sentChunkStart = sStart;
        break;
      }
    }
    if (activeSi == null || sentChunkStart == null) return;

    // Cache-miss guard. If the page sentence cache hasn't built yet (or
    // doesn't carry this chunk/sentence), trigger a deduped build and
    // leave _activeWordRects unchanged for this tick. Never paint a
    // wrong rect from an incomplete cache.
    final cachedSentences = _pageSentenceCache[pageNumber];
    if (cachedSentences == null) {
      unawaited(_loadPageSentences(pageNumber));
      return;
    }
    _ResolvedPdfSentence? sent;
    for (final s in cachedSentences) {
      if (s.chunkIndex == chunkIndex && s.sentenceIndex == activeSi) {
        sent = s;
        break;
      }
    }
    if (sent == null) return;

    // Sentence-scoped resolution. The previous implementation re-normalized
    // the whole page and walked all preceding sentences each tick, then
    // indexOf'd the word into the WHOLE page — common words ("the", "and",
    // "is") latched onto the first occurrence in a 2×wordLen lookback
    // window, which drifted backward as accumulated cursor skew grew with
    // distance from page top. Scoping the search to ONE sentence (~100-400
    // chars) bounds duplicate ambiguity to within-sentence collisions and
    // eliminates the per-tick page-wide walk + normalization.
    final pageLen = pageText.fullText.length;
    final sStart = sent.pageCharStart.clamp(0, pageLen);
    final sEnd = sent.pageCharEnd.clamp(sStart, pageLen);
    if (sStart >= sEnd) return;
    final sentPdfText = pageText.fullText.substring(sStart, sEnd);
    if (sentPdfText.isEmpty) return;

    final normalizedSent = _normalizePdfText(sentPdfText);
    final normalizedWord = _normalizePdfText(wordText).text;
    if (normalizedWord.isEmpty) return;

    // wordOffsetInSentence is the chunk-text offset; we use it as a
    // forward search hint inside the normalized sentence. Doesn't need
    // to be exact — it just biases indexOf away from earlier duplicates.
    final wordOffsetInSentence =
        (wStart - sentChunkStart).clamp(0, normalizedSent.text.length);

    var matchPos = normalizedSent.text.indexOf(
      normalizedWord,
      wordOffsetInSentence,
    );
    if (matchPos < 0) {
      matchPos = normalizedSent.text.indexOf(normalizedWord);
    }

    if (matchPos < 0) {
      // Loose fallback, still scoped to this sentence — only kicks in
      // when normalization differences between chunk text and PDF text
      // prevent the primary match (e.g., aggressive ligature handling).
      final looseSent = _normalizePdfText(sentPdfText, loose: true);
      final looseWord = _normalizePdfText(wordText, loose: true).text;
      if (looseWord.isEmpty) return;
      final looseHint = wordOffsetInSentence.clamp(0, looseSent.text.length);
      var loosePos = looseSent.text.indexOf(looseWord, looseHint);
      if (loosePos < 0) loosePos = looseSent.text.indexOf(looseWord);
      if (loosePos < 0) return;
      if (loosePos + looseWord.length > looseSent.normalizedToOriginal.length) {
        return;
      }
      final origInSent = looseSent.normalizedToOriginal[loosePos];
      final origEndInSent =
          looseSent.normalizedToOriginal[loosePos + looseWord.length - 1] + 1;
      final origStart = sStart + origInSent;
      final origEnd = sStart + origEndInSent;
      final range = PdfTextRangeWithFragments.fromTextRange(
        pageText,
        origStart,
        origEnd,
      );
      if (range == null) return;
      final rects = _rectsForTextRange(range);
      if (rects.isEmpty) return;
      setState(() {
        _activeWordRects = rects;
        _activeWordPageNumber = pageNumber;
      });
      if (_viewerController.isReady) _viewerController.invalidate();
      return;
    }

    // Primary path — map sentence-local normalized match back to PDF
    // page-text offsets via the sentence's own normalizedToOriginal table,
    // then add sent.pageCharStart to lift to page coordinates.
    if (matchPos + normalizedWord.length >
        normalizedSent.normalizedToOriginal.length) {
      return;
    }
    final origInSent = normalizedSent.normalizedToOriginal[matchPos];
    final origEndInSent =
        normalizedSent.normalizedToOriginal[matchPos + normalizedWord.length - 1] +
            1;
    final origStart = sStart + origInSent;
    final origEnd = sStart + origEndInSent;

    final range =
        PdfTextRangeWithFragments.fromTextRange(pageText, origStart, origEnd);
    if (range == null) return;
    final rects = _rectsForTextRange(range);
    if (rects.isEmpty) return;

    setState(() {
      _activeWordRects = rects;
      _activeWordPageNumber = pageNumber;
    });
    if (_viewerController.isReady) _viewerController.invalidate();
  }

  @override
  Widget build(BuildContext context) {
    // Drive word highlight from audio position
    final audioPosition =
        ref.watch(audioPositionProvider).valueOrNull ?? Duration.zero;
    if (widget.alignmentPayload != null && widget.highlight != null) {
      // Schedule after frame to avoid setState-during-build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resolveWordHighlight(audioPosition);
      });
    } else if (_activeWordRects.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _activeWordRects = const [];
          _activeWordPageNumber = null;
        });
        if (_viewerController.isReady) _viewerController.invalidate();
      });
    }

    final theme = Theme.of(context);
    final tokens = PsittaTokens.of(context);
    final stageBackground =
        Color.alphaBlend(tokens.surface2, theme.scaffoldBackgroundColor);
    final highlightColor = theme.colorScheme.primary.withOpacity(0.18);
    final wordHighlightColor = theme.colorScheme.primary.withOpacity(0.45);
    final wordHighlightStrokeColor = theme.colorScheme.primary.withOpacity(0.55);
    final hoverFillColor = theme.colorScheme.primary.withOpacity(0.10);
    final hoverStrokeColor = theme.colorScheme.primary.withOpacity(0.32);
    final highlightStrokeColor = theme.colorScheme.primary.withOpacity(0.22);

    return Container(
      decoration: BoxDecoration(
        color: stageBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: tokens.border.withOpacity(0.7),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: FutureBuilder<File>(
          future: _pdfFileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _PdfViewportMessage(
                icon: Icons.picture_as_pdf_outlined,
                title: 'Loading PDF preview',
                subtitle: 'Preparing the original document pages for display.',
                showSpinner: true,
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return _PdfViewportMessage(
                icon: Icons.error_outline,
                title: 'Unable to load PDF',
                subtitle: snapshot.error?.toString() ??
                    'The original PDF could not be loaded into the Player viewport.',
                isError: true,
              );
            }

            final file = snapshot.data!;
            final documentRef = PdfDocumentRefFile(file.path);

            return ColoredBox(
              color: stageBackground,
              child: PdfViewer(
                documentRef,
                controller: _viewerController,
                params: PdfViewerParams(
                  margin: 28,
                  backgroundColor: stageBackground,
                  panAxis: PanAxis.vertical,
                  scrollByMouseWheel: 0.6,
                  layoutPages: _layoutCenteredVerticalPages,
                  onDocumentChanged: (document) {
                    unawaited(
                      _handleDocumentChanged(documentRef, document),
                    );
                  },
                  pagePaintCallbacks: [
                    (canvas, pageRect, page) {
                      if (!_loggedFirstPagePaint) {
                        _loggedFirstPagePaint = true;
                        _openStopwatch.stop();
                        _logPdfPerf(
                          'open',
                          'first_page_render_ready doc=${widget.documentId} page=${page.pageNumber} elapsed=${_openStopwatch.elapsedMilliseconds}ms',
                        );
                      }
                      final hoveredTarget = _hoveredSentence;
                      if (hoveredTarget != null &&
                          (widget.highlight == null ||
                              hoveredTarget.pageNumber !=
                                  widget.highlight!.pageNumber ||
                              hoveredTarget.chunkIndex !=
                                  widget.highlight!.chunkIndex ||
                              hoveredTarget.sentenceIndex !=
                                  widget.highlight!.sentenceIndex)) {
                        final hoveredSentences =
                            _pageSentenceCache[page.pageNumber] ??
                                const <_ResolvedPdfSentence>[];
                        for (final sentence in hoveredSentences) {
                          if (!sentence.matchesTarget(hoveredTarget)) {
                            continue;
                          }
                          for (final pdfRect in sentence.rects) {
                            final rect = pdfRect
                                .toRect(
                                  page: page,
                                  scaledPageSize: pageRect.size,
                                )
                                .translate(pageRect.left, pageRect.top)
                                .inflate(1.2);
                            if (rect.width <= 0 || rect.height <= 0) {
                              continue;
                            }
                            final rrect = RRect.fromRectAndRadius(
                              rect,
                              const Radius.circular(6),
                            );
                            canvas.drawRRect(
                              rrect,
                              Paint()..color = hoverFillColor,
                            );
                            canvas.drawRRect(
                              rrect,
                              Paint()
                                ..color = hoverStrokeColor
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 1.2,
                            );
                          }
                        }
                      }

                      final highlight = _resolvedHighlight;
                      if (highlight != null &&
                          highlight.pageNumber == page.pageNumber) {
                        for (final pdfRect in highlight.rects) {
                          final rect = pdfRect
                              .toRect(page: page, scaledPageSize: pageRect.size)
                              .translate(pageRect.left, pageRect.top)
                              .inflate(1.0);
                          if (rect.width <= 0 || rect.height <= 0) {
                            continue;
                          }
                          final rrect = RRect.fromRectAndRadius(
                            rect,
                            const Radius.circular(7),
                          );
                          canvas.drawRRect(
                            rrect,
                            Paint()..color = highlightColor,
                          );
                          canvas.drawRRect(
                            rrect,
                            Paint()
                              ..color = highlightStrokeColor
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 0.8,
                          );
                        }
                      }

                      // Word-level highlight (painted on top of sentence)
                      if (_activeWordRects.isNotEmpty &&
                          _activeWordPageNumber == page.pageNumber) {
                        for (final pdfRect in _activeWordRects) {
                          final rect = pdfRect
                              .toRect(page: page, scaledPageSize: pageRect.size)
                              .translate(pageRect.left, pageRect.top)
                              .inflate(0.8);
                          if (rect.width <= 0 || rect.height <= 0) {
                            continue;
                          }
                          final rrect = RRect.fromRectAndRadius(
                            rect,
                            const Radius.circular(5),
                          );
                          canvas.drawRRect(
                            rrect,
                            Paint()..color = wordHighlightColor,
                          );
                          canvas.drawRRect(
                            rrect,
                            Paint()
                              ..color = wordHighlightStrokeColor
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 0.8,
                          );
                        }
                      }
                    },
                  ],
                  viewerOverlayBuilder: (context, size, handleLinkTap) => [
                    MouseRegion(
                      onHover: (event) {
                        unawaited(
                          _updateHoverFromViewerOffset(event.localPosition),
                        );
                      },
                      onExit: (_) {
                        _hoverResolveSeq++;
                        _setHoveredSentence(null);
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapUp: (details) async {
                          final sentence =
                              await _sentenceAtViewerOffset(details.localPosition);
                          if (!mounted) return;
                          if (sentence != null) {
                            _setHoveredSentence(
                              PdfSentenceTarget(
                                pageNumber: sentence.pageNumber,
                                chunkIndex: sentence.chunkIndex,
                                sentenceIndex: sentence.sentenceIndex,
                              ),
                            );
                            widget.onSentenceTap?.call(
                              PdfSentenceTarget(
                                pageNumber: sentence.pageNumber,
                                chunkIndex: sentence.chunkIndex,
                                sentenceIndex: sentence.sentenceIndex,
                              ),
                            );
                            return;
                          }

                          handleLinkTap(details.localPosition);
                          final hitTest =
                              _viewerController.getPdfPageHitTestResult(
                            details.localPosition,
                            useDocumentLayoutCoordinates: false,
                          );
                          if (hitTest != null) {
                            widget.onPageTap?.call(hitTest);
                          }
                        },
                        child: IgnorePointer(
                          child: SizedBox(
                            width: size.width,
                            height: size.height,
                          ),
                        ),
                      ),
                    ),
                    PdfViewerScrollThumb(
                      controller: _viewerController,
                      orientation: ScrollbarOrientation.right,
                      thumbSize: const Size(46, 28),
                      thumbBuilder:
                          (context, thumbSize, pageNumber, controller) {
                        return Tooltip(
                          message: 'Drag to navigate pages',
                          preferBelow: false,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 10,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '$pageNumber',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static PdfPageLayout _layoutCenteredVerticalPages(
    List<PdfPage> pages,
    PdfViewerParams params,
  ) {
    final maxPageWidth =
        pages.fold(0.0, (prev, page) => math.max(prev, page.width));
    final pageLayouts = <Rect>[];
    double y = params.margin;

    for (final page in pages) {
      final x = params.margin + (maxPageWidth - page.width) / 2;
      pageLayouts.add(
        Rect.fromLTWH(x, y, page.width, page.height),
      );
      y += page.height + params.margin;
    }

    return PdfPageLayout(
      pageLayouts: pageLayouts,
      documentSize: Size(maxPageWidth + (params.margin * 2), y),
    );
  }
}

class _PdfViewportMessage extends StatelessWidget {
  const _PdfViewportMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isError = false,
    this.showSpinner = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isError;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        isError ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: color),
            if (showSpinner) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isError ? color : null,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
