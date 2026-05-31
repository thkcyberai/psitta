import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../data/services/audio_service.dart';

class _WordSpan {
  const _WordSpan(this.start, this.end);
  final int start;
  final int end;
}

/// Renders chunk text with the currently-spoken word highlighted.
/// Supports formatted content (headings, bold, italic) when available.
///
/// Falls back to plain SelectableText when:
///   - alignmentPayload has no 'alignment' key
///   - ElevenLabs was not the provider (alignment == null)
///   - Position maps to no recognisable character
class WordHighlightView extends ConsumerStatefulWidget {
  const WordHighlightView({
    super.key,
    required this.chunkText,
    required this.alignmentPayload,
    this.sentenceBoundaries,
    this.formattedContent,
    this.onActiveWordChanged,
    this.onActiveSentenceChanged,
    this.enableContextMenu = false,
    this.audioService,
  });

  final String chunkText;
  final Map<String, dynamic> alignmentPayload;
  final List<dynamic>? sentenceBoundaries;
  final List<dynamic>? formattedContent;
  final void Function(int wordIndex, int totalWords)? onActiveWordChanged;
  final void Function(GlobalKey sentenceKey)? onActiveSentenceChanged;
  final bool enableContextMenu;
  final AudioService? audioService;

  @override
  ConsumerState<WordHighlightView> createState() => _WordHighlightViewState();
}

class _WordHighlightViewState extends ConsumerState<WordHighlightView> {
  int _prevActiveWord = -1;
  int _lastSentenceIdx = 0;
  final Map<int, GlobalKey> _sentenceKeys = {};

  List<_WordSpan> _computeWordSpans(String text) {
    final spans = <_WordSpan>[];
    bool isWordChar(String ch) {
      final c = ch.codeUnitAt(0);
      final isAlphaNum = (c >= 48 && c <= 57) ||
          (c >= 65 && c <= 90) ||
          (c >= 97 && c <= 122);
      return isAlphaNum || ch == "'";
    }

    int i = 0;
    while (i < text.length) {
      while (i < text.length && !isWordChar(text[i])) { i++; }
      if (i >= text.length) break;
      final start = i;
      while (i < text.length && isWordChar(text[i])) { i++; }
      spans.add(_WordSpan(start, i));
    }
    return spans;
  }

  int? _charIndexAtMs(Map<dynamic, dynamic> alignmentBlock, int tMs) {
    final normalized = alignmentBlock['normalized_alignment'];
    if (normalized is! Map) return null;

    final chars = normalized['characters'];
    final starts = normalized['character_start_times_seconds'];
    final ends = normalized['character_end_times_seconds'];

    if (chars is! List || starts is! List || ends is! List) return null;
    if (chars.isEmpty ||
        starts.length != chars.length ||
        ends.length != chars.length) return null;

    final t = tMs / 1000.0;

    for (int i = 0; i < chars.length; i++) {
      final s = (starts[i] as num).toDouble();
      final e = (ends[i] as num).toDouble();
      if (t >= s && t <= e) return i;
    }

    final lastEnd = (ends.last as num).toDouble();
    if (t > lastEnd) return chars.length - 1;

    return null;
  }

  int _wordIndexFromCharIndex(List<_WordSpan> spans, int charIdx) {
    for (int i = 0; i < spans.length; i++) {
      final sp = spans[i];
      if (charIdx >= sp.start && charIdx < sp.end) return i;
      if (charIdx < sp.start) return (i - 1).clamp(0, spans.length - 1);
    }
    return (spans.length - 1).clamp(0, spans.length - 1);
  }

  int? _activeSentenceIndex(List<dynamic> boundaries, Duration position, Duration total) {
    if (total.inMilliseconds == 0) return null;
    final lookaheadMs = position.inMilliseconds.clamp(0, total.inMilliseconds);
    final ratio = lookaheadMs / total.inMilliseconds;
    final charOffset = (ratio * widget.chunkText.length).round().clamp(0, widget.chunkText.length - 1);
    for (int i = 0; i < boundaries.length; i++) {
      final b = boundaries[i];
      final start = (b[0] as num).toInt();
      final end = (b[1] as num).toInt();
      if (charOffset >= start && charOffset < end) return i;
    }
    return null;
  }

  /// Which sentence index does a given character offset fall in?
  int? _sentenceIndexForChar(int charOffset) {
    final boundaries = widget.sentenceBoundaries;
    if (boundaries == null) return null;
    for (int i = 0; i < boundaries.length; i++) {
      final b = boundaries[i];
      final start = (b[0] as num).toInt();
      final end = (b[1] as num).toInt();
      if (charOffset >= start && charOffset < end) return i;
    }
    return null;
  }

  // ── Context menu builder ───────────────────────────────────────────────────
  Widget _buildContextMenu(
      BuildContext ctx, EditableTextState editableTextState) {
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: [
        ContextMenuButtonItem(
          label: 'Listen from here',
          onPressed: () {
            ContextMenuController.removeAny();
            _seekToSelection(editableTextState);
          },
        ),
      ],
    );
  }

  // ── Formatted content rendering ────────────────────────────────────────────

  /// Build a Column of formatted paragraphs with sentence highlighting.
  /// Each sentence boundary gets a GlobalKey for scroll targeting.
  /// Uses SelectableText.rich per paragraph to keep context menus working.
  Widget _buildFormattedContent({
    required ThemeData theme,
    required int? activeSentenceIdx,
    required TextStyle? baseStyle,
    required TextStyle? sentenceHighlightStyle,
    required List<_WordSpan>? wordSpans,
    required int? activeWordIdx,
    required TextStyle? highlightStyle,
  }) {
    final formatted = widget.formattedContent!;
    final cmBuilder = widget.enableContextMenu ? _buildContextMenu : null;
    final paragraphs = <Widget>[];

    // Track char offset in chunkText as we walk through formatted blocks
    int charCursor = 0;

    for (final block in formatted) {
      final blockType = (block['type'] ?? 'paragraph') as String;
      final level = block['level'] as int?;
      final runs = (block['runs'] as List<dynamic>?) ?? [];

      // Compute plain text of this block to find its position in chunkText
      final blockPlain = runs.map((r) => (r['text'] ?? '') as String).join();
      if (blockPlain.isEmpty) continue;

      // Find this block's position in chunkText
      int blockStart = charCursor;
      final idx = widget.chunkText.indexOf(blockPlain, charCursor);
      if (idx >= 0) {
        blockStart = idx;
        charCursor = idx + blockPlain.length;
      } else {
        charCursor = (charCursor + blockPlain.length).clamp(0, widget.chunkText.length);
      }
      // Resolve paragraph-level TextStyle
      TextStyle paraStyle;
      switch (blockType) {
        case 'heading':
          switch (level) {
            case 1:
              paraStyle = theme.textTheme.headlineMedium ?? const TextStyle(fontSize: 24, fontWeight: FontWeight.bold);
            case 2:
              paraStyle = theme.textTheme.headlineSmall ?? const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
            case 3:
              paraStyle = theme.textTheme.titleLarge ?? const TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
            default:
              paraStyle = theme.textTheme.titleLarge ?? const TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
          }
          paraStyle = paraStyle.copyWith(height: 1.6);
        case 'list_item':
          paraStyle = baseStyle?.copyWith(height: 1.6) ?? const TextStyle(fontSize: 16, height: 1.6);
        default:
          paraStyle = baseStyle ?? const TextStyle(fontSize: 16, height: 1.8);
      }

      // Determine which sentence(s) this block overlaps
      final sentIdx = _sentenceIndexForChar(blockStart);

      // Ensure the sentence key exists for scroll targeting
      if (sentIdx != null) {
        _sentenceKeys[sentIdx] ??= GlobalKey();
      }

      // Build inline spans with run-level formatting + highlighting
      final inlineSpans = <TextSpan>[];
      int runCursor = blockStart;

      for (final run in runs) {
        final runText = (run['text'] ?? '') as String;
        if (runText.isEmpty) continue;
        final runStart = runCursor;
        final runEnd = runStart + runText.length;

        // Base style for this run (bold/italic/underline from formatted_content)
        TextStyle runStyle = paraStyle;
        if (run['bold'] == true) {
          runStyle = runStyle.copyWith(fontWeight: FontWeight.w700);
        }
        if (run['italic'] == true) {
          runStyle = runStyle.copyWith(fontStyle: FontStyle.italic);
        }
        if (run['underline'] == true) {
          runStyle = runStyle.copyWith(decoration: TextDecoration.underline);
        }

        // Apply sentence and word highlighting
        if (wordSpans != null && highlightStyle != null) {
          // With word-level alignment: split run into per-character spans for active word
          _addHighlightedSpans(
            inlineSpans: inlineSpans,
            text: runText,
            textStart: runStart,
            runStyle: runStyle,
            activeSentenceIdx: activeSentenceIdx,
            sentenceHighlightStyle: sentenceHighlightStyle,
            wordSpans: wordSpans,
            activeWordIdx: activeWordIdx,
            highlightStyle: highlightStyle,
          );
        } else {
          // Sentence-only highlighting
          final isInActiveSentence = activeSentenceIdx != null && sentIdx == activeSentenceIdx;
          inlineSpans.add(TextSpan(
            text: runText,
            style: isInActiveSentence
                ? runStyle.copyWith(backgroundColor: AppColors.primary.withOpacity(0.10))
                : runStyle,
          ));
        }

        runCursor = runEnd;
      }

      // Prefix list items with bullet
      if (blockType == 'list_item') {
        inlineSpans.insert(0, TextSpan(text: '  \u2022  ', style: paraStyle));
      }

      // Spacing between paragraphs
      final spacing = blockType == 'heading' ? 16.0 : 8.0;

      Widget paraWidget = Padding(
        padding: EdgeInsets.only(bottom: spacing),
        child: SelectableText.rich(
          TextSpan(children: inlineSpans),
          contextMenuBuilder: cmBuilder,
        ),
      );

      // Attach sentence key for scroll targeting (first block of each sentence)
      if (sentIdx != null && _sentenceKeys.containsKey(sentIdx)) {
        final key = _sentenceKeys[sentIdx]!;
        // Only attach key to the first paragraph that starts this sentence
        final sentStart = (widget.sentenceBoundaries![sentIdx][0] as num).toInt();
        if (blockStart <= sentStart + 1) {
          paragraphs.add(Container(key: key, child: paraWidget));
        } else {
          paragraphs.add(paraWidget);
        }
      } else {
        paragraphs.add(paraWidget);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs,
    );
  }

  /// Add TextSpans with word-level and sentence-level highlighting.
  void _addHighlightedSpans({
    required List<TextSpan> inlineSpans,
    required String text,
    required int textStart,
    required TextStyle runStyle,
    required int? activeSentenceIdx,
    required TextStyle? sentenceHighlightStyle,
    required List<_WordSpan> wordSpans,
    required int? activeWordIdx,
    required TextStyle? highlightStyle,
  }) {
    final textEnd = textStart + text.length;
    final sentIdx = _sentenceIndexForChar(textStart);
    final isInActiveSentence = activeSentenceIdx != null && sentIdx == activeSentenceIdx;

    // Find word spans that overlap this text range
    int cursor = textStart;
    for (int wi = 0; wi < wordSpans.length; wi++) {
      final wp = wordSpans[wi];
      if (wp.end <= textStart) continue;
      if (wp.start >= textEnd) break;

      final wStart = wp.start.clamp(textStart, textEnd);
      final wEnd = wp.end.clamp(textStart, textEnd);

      // Gap before word
      if (cursor < wStart) {
        final gapStyle = isInActiveSentence
            ? runStyle.copyWith(backgroundColor: AppColors.primary.withOpacity(0.10))
            : runStyle;
        inlineSpans.add(TextSpan(
          text: text.substring(cursor - textStart, wStart - textStart),
          style: gapStyle,
        ));
      }

      // The word itself
      final isActiveWord = wi == activeWordIdx;
      TextStyle wordStyle;
      if (isActiveWord) {
        wordStyle = highlightStyle ?? runStyle;
      } else if (isInActiveSentence) {
        wordStyle = runStyle.copyWith(backgroundColor: AppColors.primary.withOpacity(0.10));
      } else {
        wordStyle = runStyle;
      }
      inlineSpans.add(TextSpan(
        text: text.substring(wStart - textStart, wEnd - textStart),
        style: wordStyle,
      ));
      cursor = wEnd;
    }

    // Trailing text after last word
    if (cursor < textEnd) {
      final trailStyle = isInActiveSentence
          ? runStyle.copyWith(backgroundColor: AppColors.primary.withOpacity(0.10))
          : runStyle;
      inlineSpans.add(TextSpan(
        text: text.substring(cursor - textStart),
        style: trailStyle,
      ));
    }

    // If no word spans overlapped at all, add the whole text
    if (cursor == textStart) {
      final wholeStyle = isInActiveSentence
          ? runStyle.copyWith(backgroundColor: AppColors.primary.withOpacity(0.10))
          : runStyle;
      inlineSpans.add(TextSpan(text: text, style: wholeStyle));
    }
  }

  // ── Plain-text sentence highlight (SelectableText.rich) ────────────────────

  /// Render chunkText as SelectableText.rich with sentence + word highlighting.
  /// Preserves context menus and text selection.
  Widget _buildPlainHighlighted({
    required int? activeSentenceIdx,
    required TextStyle? baseStyle,
    required TextStyle? sentenceHighlightStyle,
    required List<_WordSpan>? wordSpans,
    required int? activeWordIdx,
    required TextStyle? highlightStyle,
  }) {
    final cmBuilder = widget.enableContextMenu ? _buildContextMenu : null;
    final boundaries = widget.sentenceBoundaries;

    if (boundaries == null || boundaries.isEmpty) {
      // No sentence data at all — plain text
      if (wordSpans != null && activeWordIdx != null && highlightStyle != null) {
        // Word highlight only (old docs with alignment but no sentences)
        return _buildWordOnlyHighlight(
          baseStyle: baseStyle,
          wordSpans: wordSpans,
          activeWordIdx: activeWordIdx,
          highlightStyle: highlightStyle,
          cmBuilder: cmBuilder,
        );
      }
      return SelectableText(
        widget.chunkText,
        style: baseStyle,
        contextMenuBuilder: cmBuilder,
      );
    }

    // Build SelectableText.rich with sentence-keyed WidgetSpans for scroll targeting
    // and inline TextSpans for highlighting.
    final children = <InlineSpan>[];
    int cursor = 0;

    for (int si = 0; si < boundaries.length; si++) {
      final b = boundaries[si];
      final sentStart = (b[0] as num).toInt();
      final sentEnd = (b[1] as num).toInt();
      final isActiveSentence = si == activeSentenceIdx;
      _sentenceKeys[si] ??= GlobalKey();

      // Gap before this sentence
      if (cursor < sentStart) {
        children.add(TextSpan(
          text: widget.chunkText.substring(cursor, sentStart),
          style: baseStyle,
        ));
      }

      // Build sentence content spans
      if (wordSpans != null && highlightStyle != null) {
        // Word-level highlighting within sentence
        int wCursor = sentStart;
        for (int wi = 0; wi < wordSpans.length; wi++) {
          final wp = wordSpans[wi];
          if (wp.end <= sentStart) continue;
          if (wp.start >= sentEnd) break;

          final wStart = wp.start.clamp(sentStart, sentEnd);
          final wEnd = wp.end.clamp(sentStart, sentEnd);

          if (wCursor < wStart) {
            children.add(TextSpan(
              text: widget.chunkText.substring(wCursor, wStart),
              style: isActiveSentence ? sentenceHighlightStyle : baseStyle,
            ));
          }

          final isActiveWord = wi == activeWordIdx;
          children.add(TextSpan(
            text: widget.chunkText.substring(wStart, wEnd),
            style: isActiveWord ? highlightStyle : (isActiveSentence ? sentenceHighlightStyle : baseStyle),
          ));
          wCursor = wEnd;
        }
        if (wCursor < sentEnd) {
          children.add(TextSpan(
            text: widget.chunkText.substring(wCursor, sentEnd),
            style: isActiveSentence ? sentenceHighlightStyle : baseStyle,
          ));
        }
      } else {
        // Sentence-only highlighting
        children.add(TextSpan(
          text: widget.chunkText.substring(sentStart, sentEnd),
          style: isActiveSentence ? sentenceHighlightStyle : baseStyle,
        ));
      }

      // WidgetSpan with sentence key for scroll targeting (zero-size anchor)
      children.add(WidgetSpan(
        child: SizedBox(key: _sentenceKeys[si], width: 0, height: 0),
      ));

      cursor = sentEnd;
    }

    // Trailing text after last sentence
    if (cursor < widget.chunkText.length) {
      children.add(TextSpan(
        text: widget.chunkText.substring(cursor),
        style: baseStyle,
      ));
    }

    return SelectableText.rich(
      TextSpan(children: children),
      contextMenuBuilder: cmBuilder,
    );
  }

  /// Fallback: alignment with word highlight but no sentence data.
  Widget _buildWordOnlyHighlight({
    required TextStyle? baseStyle,
    required List<_WordSpan> wordSpans,
    required int activeWordIdx,
    required TextStyle highlightStyle,
    required Widget Function(BuildContext, EditableTextState)? cmBuilder,
  }) {
    final children = <TextSpan>[];
    int cursor = 0;

    for (int i = 0; i < wordSpans.length; i++) {
      final sp = wordSpans[i];
      if (cursor < sp.start) {
        children.add(TextSpan(
          text: widget.chunkText.substring(cursor, sp.start),
          style: baseStyle,
        ));
      }
      children.add(TextSpan(
        text: widget.chunkText.substring(sp.start, sp.end),
        style: i == activeWordIdx ? highlightStyle : baseStyle,
      ));
      cursor = sp.end;
    }

    if (cursor < widget.chunkText.length) {
      children.add(TextSpan(
        text: widget.chunkText.substring(cursor),
        style: baseStyle,
      ));
    }

    return SelectableText.rich(
      TextSpan(children: children),
      contextMenuBuilder: cmBuilder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final position =
        ref.watch(audioPositionProvider).valueOrNull ?? Duration.zero;
    final duration = ref.watch(audioDurationProvider).valueOrNull ?? Duration.zero;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseStyle = theme.textTheme.bodyLarge?.copyWith(
      height: 1.8,
      fontSize: 16,
    );

    final activeSentenceIdx = (widget.sentenceBoundaries != null && widget.sentenceBoundaries!.isNotEmpty)
        ? _activeSentenceIndex(widget.sentenceBoundaries!, position, duration)
        : null;

    if (activeSentenceIdx != null &&
        activeSentenceIdx > 0 &&
        activeSentenceIdx != _lastSentenceIdx) {
      _lastSentenceIdx = activeSentenceIdx;
      _sentenceKeys[activeSentenceIdx] ??= GlobalKey();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onActiveSentenceChanged?.call(_sentenceKeys[activeSentenceIdx]!);
      });
    }

    final sentenceHighlightStyle = baseStyle?.copyWith(
      backgroundColor: AppColors.primary.withOpacity(0.10),
    );

    final alignmentBlock = widget.alignmentPayload['alignment'];
    final spans = _computeWordSpans(widget.chunkText);

    // ── Resolve active word (if alignment data exists) ──
    int? activeWord;
    TextStyle? highlightStyle;

    if (alignmentBlock is Map && spans.isNotEmpty) {
      final charIdx = _charIndexAtMs(alignmentBlock, position.inMilliseconds);
      if (charIdx != null) {
        activeWord = _wordIndexFromCharIndex(spans, charIdx);

        if (activeWord != _prevActiveWord) {
          _prevActiveWord = activeWord;
          if (widget.onActiveWordChanged != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onActiveWordChanged?.call(activeWord!, spans.length);
            });
          }
        }

        highlightStyle = baseStyle?.copyWith(
          backgroundColor: theme.colorScheme.primary.withOpacity(0.45),
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        );
      }
    } else if (alignmentBlock is! Map) {
      // No alignment: estimate word progress for scroll callback
      if (spans.isNotEmpty && widget.onActiveWordChanged != null) {
        final audio = widget.audioService;
        final durationMs = audio?.duration?.inMilliseconds ?? 0;
        final posMs = position.inMilliseconds;
        if (durationMs > 0) {
          final ratio = (posMs / durationMs).clamp(0.0, 1.0);
          final estimatedWord = (ratio * (spans.length - 1)).round();
          if (estimatedWord != _prevActiveWord) {
            _prevActiveWord = estimatedWord;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onActiveWordChanged?.call(estimatedWord, spans.length);
            });
          }
        }
      }
    }

    // ── Formatted content path ──
    if (widget.formattedContent != null && widget.formattedContent!.isNotEmpty) {
      return _buildFormattedContent(
        theme: theme,
        activeSentenceIdx: activeSentenceIdx,
        baseStyle: baseStyle,
        sentenceHighlightStyle: sentenceHighlightStyle,
        wordSpans: (activeWord != null) ? spans : null,
        activeWordIdx: activeWord,
        highlightStyle: highlightStyle,
      );
    }

    // ── Plain text path ──
    return _buildPlainHighlighted(
      activeSentenceIdx: activeSentenceIdx,
      baseStyle: baseStyle,
      sentenceHighlightStyle: sentenceHighlightStyle,
      wordSpans: (activeWord != null) ? spans : null,
      activeWordIdx: activeWord,
      highlightStyle: highlightStyle,
    );
  }

  void _seekToSelection(EditableTextState editableTextState) {
    final selection = editableTextState.currentTextEditingValue.selection;
    if (!selection.isValid) return;

    // Use start of selection (works for both cursor click and drag-select)
    final charIndex = selection.start;
    final audio = widget.audioService;
    if (audio == null) return;

    final alignmentBlock = widget.alignmentPayload['alignment'];

    if (alignmentBlock is Map) {
      // ── Alignment available (ElevenLabs): seek by character timestamp ──
      final normalized = alignmentBlock['normalized_alignment'];
      if (normalized is Map) {
        final startTimes = normalized['character_start_times_seconds'];
        if (startTimes is List && charIndex < startTimes.length) {
          final seconds = (startTimes[charIndex] as num).toDouble();
          final ms = (seconds * 1000).round();
          audio.pause();
          audio.seek(Duration(milliseconds: ms));
          audio.play();
          return;
        }
      }
    }

    // ── No alignment (Edge/Azure): estimate by character ratio ──────────
    final totalChars = widget.chunkText.length;
    if (totalChars == 0) return;
    final ratio = charIndex / totalChars;
    final durationMs = audio.duration?.inMilliseconds ?? 0;
    if (durationMs == 0) return;
    final ms = (ratio * durationMs).round();
    audio.pause();
    audio.seek(Duration(milliseconds: ms));
    audio.play();
  }
}
