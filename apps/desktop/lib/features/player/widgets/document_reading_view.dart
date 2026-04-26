import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../data/models/psitta_document.dart';
import '../../../data/services/audio_service.dart';

/// Parse a stored DocRun.color hex string into a Flutter Color. Accepts
/// `#RRGGBB`, `RRGGBB`, `#RRGGBBAA`, or `RRGGBBAA`, case-insensitive.
/// Returns null on any unparseable shape so the caller can skip the
/// `copyWith(color: ...)` call rather than rendering a wrong color.
/// 6-digit input is treated as opaque (alpha = 0xFF); 8-digit preserves
/// the embedded alpha.
Color? _parseHexColor(String? hex) {
  if (hex == null) return null;
  final s = hex.trim();
  final body = s.startsWith('#') ? s.substring(1) : s;
  if (body.length != 6 && body.length != 8) return null;
  final value = int.tryParse(body, radix: 16);
  if (value == null) return null;
  if (body.length == 6) return Color(0xFF000000 | value);
  return Color(value);
}

/// Map a stored DocBlock.alignment string to a Flutter [TextAlign].
/// Default is [TextAlign.start] (LTR-locale equivalent of `left` —
/// keeps behavior identical for null / unset / unknown values).
TextAlign _textAlignFor(String? alignment) {
  switch (alignment) {
    case 'center':
      return TextAlign.center;
    case 'right':
      return TextAlign.right;
    case 'justify':
      return TextAlign.justify;
    case 'left':
      return TextAlign.left;
    default:
      return TextAlign.start;
  }
}

/// Renders a [PsittaDocument] as a scrollable reading canvas with:
///   - structured block rendering (headings, paragraphs, lists)
///   - sentence highlighting driven by audio position
///   - word highlighting when alignment data exists
///   - right-click "Listen from here" context menu
///   - stable GlobalKey anchors per block for scroll targeting
///
/// This widget replaces the chunk-scoped WordHighlightView for documents
/// that have been assembled into the canonical model.
class DocumentReadingView extends ConsumerStatefulWidget {
  const DocumentReadingView({
    super.key,
    required this.document,
    required this.activeChunkIndex,
    required this.alignmentPayload,
    this.visibleBlocks,
    this.focusedSentenceIndex,
    this.onActiveSentenceChanged,
    this.onActiveWordChanged,
    this.onSentenceTap,
    this.audioService,
    this.enableContextMenu = true,
    this.enablePointerSentenceSelection = false,
    this.blockKeys,
    this.textScale = 1.0,
  });

  final PsittaDocument document;
  final List<DocBlock>? visibleBlocks;

  /// Which chunk is currently playing (index into chunkMap).
  final int activeChunkIndex;

  /// Word-timing alignment from ElevenLabs (chunk-scoped).
  final Map<String, dynamic> alignmentPayload;
  final int? focusedSentenceIndex;

  final void Function(GlobalKey blockKey)? onActiveSentenceChanged;
  final void Function(int wordIndex, int totalWords)? onActiveWordChanged;
  final void Function(int docOffset)? onSentenceTap;
  final AudioService? audioService;
  final bool enableContextMenu;
  final bool enablePointerSentenceSelection;

  /// Shared block key registry — allows external code (e.g. outline sidebar)
  /// to look up GlobalKeys for specific blocks.
  final Map<String, GlobalKey>? blockKeys;

  /// Text zoom factor driven by Ctrl+scroll. 1.0 = default size.
  final double textScale;

  @override
  ConsumerState<DocumentReadingView> createState() =>
      _DocumentReadingViewState();
}

class _DocumentReadingViewState extends ConsumerState<DocumentReadingView> {
  final Map<String, GlobalKey> _localBlockKeys = {};
  int _lastActiveSentenceIdx = 0;
  int? _hoveredSentenceIdx;

  GlobalKey _keyForBlock(String blockId) {
    final registry = widget.blockKeys ?? _localBlockKeys;
    return registry.putIfAbsent(blockId, () => GlobalKey());
  }

  DocSentence? _sentenceForPointer(
    DocBlock block,
    Offset localPosition,
    double maxWidth,
    TextSpan textSpan, {
    required int displayPrefixLength,
  }) {
    if (maxWidth <= 0 || block.textLength <= 0) return null;

    final painter = TextPainter(
      text: textSpan,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxWidth);

    if (painter.size.width <= 0 || painter.size.height <= 0) return null;
    if (localPosition.dx < 0 ||
        localPosition.dy < 0 ||
        localPosition.dx > painter.size.width ||
        localPosition.dy > painter.size.height) {
      return null;
    }

    final text = textSpan.toPlainText(includeSemanticsLabels: false);
    if (text.isEmpty) return null;

    final position = painter.getPositionForOffset(localPosition);
    var displayOffset = position.offset.clamp(0, text.length).toInt();
    if (displayOffset >= text.length) {
      displayOffset = text.length - 1;
    }

    final charStart = displayOffset.clamp(0, text.length - 1);
    final charEnd = (charStart + 1).clamp(0, text.length);
    final charBoxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: charStart, extentOffset: charEnd),
    );
    final onText = charBoxes.any((box) => box.toRect().inflate(1).contains(localPosition));
    if (!onText) return null;

    final textOffset =
        (displayOffset - displayPrefixLength).clamp(0, block.textLength - 1);
    final docOffset = block.textOffset + textOffset;

    final blockEnd = block.textOffset + block.textLength;
    final blockSentences = widget.document.sentences
        .where((sentence) =>
            sentence.startOffset < blockEnd &&
            sentence.endOffset > block.textOffset &&
            sentence.blockIds.contains(block.blockId))
        .toList()
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));

    if (blockSentences.isEmpty) {
      return null;
    }

    for (final sentence in blockSentences) {
      if (docOffset >= sentence.startOffset && docOffset < sentence.endOffset) {
        return sentence;
      }
    }

    return null;
  }

  // ── Active sentence detection ──────────────────────────────────────────────

  /// Map audio position to a document-level character offset, then find the
  /// active sentence.
  int? _activeSentenceIndex(Duration position, Duration total) {
    final doc = widget.document;
    if (doc.sentences.isEmpty) return null;

    // Get the active chunk's text range in document coordinates
    final chunkIdx = widget.activeChunkIndex.clamp(0, doc.chunkMap.length - 1);
    final chunk = doc.chunkMap[chunkIdx];

    int? chunkCharOffset;
    final alignmentBlock = widget.alignmentPayload['alignment'];
    if (alignmentBlock is Map) {
      chunkCharOffset = _charIndexAtMs(alignmentBlock, position.inMilliseconds);
    }

    if (chunkCharOffset == null) {
      if (total.inMilliseconds == 0) return null;
      final ratio =
          (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
      chunkCharOffset =
          (ratio * chunk.textLength).round().clamp(0, chunk.textLength - 1);
    }

    final docOffset = chunk.textOffset + chunkCharOffset;

    // Find which sentence contains this offset
    for (int i = 0; i < doc.sentences.length; i++) {
      final s = doc.sentences[i];
      if (docOffset >= s.startOffset && docOffset < s.endOffset) return i;
    }
    return null;
  }

  // ── Word alignment ─────────────────────────────────────────────────────────

  /// Find the character index within the active chunk at a given time.
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

  // ── Context menu ───────────────────────────────────────────────────────────

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

  void _seekToSelection(EditableTextState editableTextState) {
    final selection = editableTextState.currentTextEditingValue.selection;
    if (!selection.isValid) return;

    final charIndex = selection.start;
    final audio = widget.audioService;
    if (audio == null) return;

    final alignmentBlock = widget.alignmentPayload['alignment'];

    if (alignmentBlock is Map) {
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

    // Fallback: estimate by ratio within the active chunk
    final doc = widget.document;
    final chunkIdx = widget.activeChunkIndex.clamp(0, doc.chunkMap.length - 1);
    final chunk = doc.chunkMap[chunkIdx];
    if (chunk.textLength == 0) return;

    final ratio = charIndex / chunk.textLength;
    final durationMs = audio.duration?.inMilliseconds ?? 0;
    if (durationMs == 0) return;
    final ms = (ratio * durationMs).round();
    audio.pause();
    audio.seek(Duration(milliseconds: ms));
    audio.play();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final position =
        ref.watch(audioPositionProvider).valueOrNull ?? Duration.zero;
    final duration =
        ref.watch(audioDurationProvider).valueOrNull ?? Duration.zero;
    final isPlaying = ref.watch(audioPlayingProvider).valueOrNull ??
        widget.audioService?.isPlaying ??
        false;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final doc = widget.document;

    // ── Resolve active sentence ──
    final audioSentenceIdx = _activeSentenceIndex(position, duration);
    final activeSentenceIdx = !isPlaying && widget.focusedSentenceIndex != null
        ? widget.focusedSentenceIndex
        : audioSentenceIdx;
    final previewSentenceIdx = widget.enablePointerSentenceSelection
        ? _hoveredSentenceIdx
        : null;

    // Fire scroll callback when sentence changes
    if (audioSentenceIdx != null &&
        audioSentenceIdx > 0 &&
        audioSentenceIdx != _lastActiveSentenceIdx) {
      _lastActiveSentenceIdx = audioSentenceIdx;
      final sent = doc.sentences[audioSentenceIdx];
      final visibleBlockIds = (widget.visibleBlocks ?? doc.blocks)
          .map((block) => block.blockId)
          .toSet();
      final activeBlockId = sent.blockIds.isEmpty ? null : sent.blockIds.first;
      if (activeBlockId != null && visibleBlockIds.contains(activeBlockId)) {
        final key = _keyForBlock(activeBlockId);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onActiveSentenceChanged?.call(key);
        });
      }
    }

    // ── Resolve active word (document-level offset) ──
    int? activeWordDocOffset; // document-level char offset of active word start
    int? activeWordDocEnd;
    final alignmentBlock = widget.alignmentPayload['alignment'];

    if (alignmentBlock is Map) {
      final charIdx = _charIndexAtMs(alignmentBlock, position.inMilliseconds);
      if (charIdx != null) {
        // charIdx is chunk-scoped. Convert to document offset.
        final chunkIdx =
            widget.activeChunkIndex.clamp(0, doc.chunkMap.length - 1);
        final chunk = doc.chunkMap[chunkIdx];
        final docCharIdx = chunk.textOffset + charIdx;

        // Find the word boundaries around this character
        final text = doc.plainText;
        if (docCharIdx < text.length) {
          int wStart = docCharIdx;
          int wEnd = docCharIdx;
          // Expand to word boundaries
          while (wStart > 0 && _isWordChar(text[wStart - 1])) {
            wStart--;
          }
          while (wEnd < text.length && _isWordChar(text[wEnd])) {
            wEnd++;
          }
          if (wEnd > wStart) {
            activeWordDocOffset = wStart;
            activeWordDocEnd = wEnd;
          }
        }
      }
    }

    // ── Highlight styles ──
    final sentenceBg = AppColors.primary.withOpacity(0.10);
    final previewSentenceBg = AppColors.primary.withOpacity(0.16);
    final wordHighlightBg = AppColors.primary.withOpacity(isDark ? 0.35 : 0.22);

    final cmBuilder = widget.enableContextMenu ? _buildContextMenu : null;

    // ── Render blocks ──
    final blockWidgets = <Widget>[];

    final blocks = widget.visibleBlocks ?? doc.blocks;

    // Counter for numbered list items. Increments across consecutive
    // numbered list items and resets on any bullet item, paragraph, or
    // heading. Mirrors Word/Quill list-numbering semantics.
    int numberedCounter = 0;

    for (final block in blocks) {
      final key = _keyForBlock(block.blockId);
      final blockStart = block.textOffset;

      // Determine block-level text style
      TextStyle blockStyle;
      final scale = widget.textScale;
      switch (block.type) {
        case DocBlockType.heading:
          switch (block.level) {
            case 1:
              blockStyle = theme.textTheme.headlineMedium ??
                  TextStyle(fontSize: 24 * scale, fontWeight: FontWeight.bold);
            case 2:
              blockStyle = theme.textTheme.headlineSmall ??
                  TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.bold);
            case 3:
              blockStyle = theme.textTheme.titleLarge ??
                  TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.w600);
            default:
              blockStyle = theme.textTheme.titleLarge ??
                  TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.w600);
          }
          blockStyle = blockStyle.copyWith(
            height: 1.6,
            fontSize: (blockStyle.fontSize ?? 24) * scale,
          );
        case DocBlockType.listItem:
          blockStyle = theme.textTheme.bodyLarge?.copyWith(
                height: 1.6,
                fontSize: 16 * scale,
              ) ??
              TextStyle(fontSize: 16 * scale, height: 1.6);
        case DocBlockType.paragraph:
          blockStyle = theme.textTheme.bodyLarge?.copyWith(
                height: 1.8,
                fontSize: 16 * scale,
              ) ??
              TextStyle(fontSize: 16 * scale, height: 1.8);
      }

      // Word highlight style inherits block's fontSize/height
      final wordHighlightStyle = blockStyle.copyWith(
        backgroundColor: wordHighlightBg,
      );

      // Build inline spans with highlighting
      final inlineSpans = <TextSpan>[];
      int runCursor = blockStart;

      for (final run in block.runs) {
        final runText = run.text;
        if (runText.isEmpty) continue;
        final runStart = runCursor;
        final runEnd = runStart + runText.length;

        // Base style for this run
        TextStyle runStyle = blockStyle;
        if (run.bold) runStyle = runStyle.copyWith(fontWeight: FontWeight.w700);
        if (run.italic) {
          runStyle = runStyle.copyWith(fontStyle: FontStyle.italic);
        }
        // Underline + strike compose via TextDecoration.combine — applying
        // them as separate copyWith(decoration:) calls would overwrite
        // each other and silently drop one decoration. The combine list
        // omits TextDecoration.none entries; an empty list collapses to
        // null so an unstyled run carries no decoration.
        final decorations = <TextDecoration>[
          if (run.underline) TextDecoration.underline,
          if (run.strike) TextDecoration.lineThrough,
        ];
        if (decorations.isNotEmpty) {
          runStyle = runStyle.copyWith(
            decoration: decorations.length == 1
                ? decorations.first
                : TextDecoration.combine(decorations),
          );
        }
        if (run.fontSize != null) {
          runStyle = runStyle.copyWith(fontSize: run.fontSize);
        }
        final parsedColor = _parseHexColor(run.color);
        if (parsedColor != null) {
          runStyle = runStyle.copyWith(color: parsedColor);
        }
        if (run.fontFamily != null && run.fontFamily!.isNotEmpty) {
          runStyle = runStyle.copyWith(fontFamily: run.fontFamily);
        }

        // Per-run word-highlight style so the active word during TTS
        // playback inherits run.fontSize — without this the highlighted
        // word would flicker back to blockStyle's default fontSize.
        final runWordHighlightStyle = run.fontSize != null
            ? wordHighlightStyle.copyWith(fontSize: run.fontSize)
            : wordHighlightStyle;

        // Check if this run overlaps the active sentence
        bool isInActiveSentence = false;
        if (activeSentenceIdx != null &&
            activeSentenceIdx < doc.sentences.length) {
          final sent = doc.sentences[activeSentenceIdx];
          isInActiveSentence =
              runStart < sent.endOffset && runEnd > sent.startOffset;
        }

        bool isInPreviewSentence = false;
        if (previewSentenceIdx != null &&
            previewSentenceIdx < doc.sentences.length) {
          final sent = doc.sentences[previewSentenceIdx];
          isInPreviewSentence =
              runStart < sent.endOffset && runEnd > sent.startOffset;
        }

        // Check if this run overlaps the active word
        if (activeWordDocOffset != null && activeWordDocEnd != null) {
          final highlightBg = isInPreviewSentence
              ? previewSentenceBg
              : isInActiveSentence
                  ? sentenceBg
                  : null;
          // Split run into sub-spans for word highlighting
          _addWordHighlightedSpans(
            spans: inlineSpans,
            text: runText,
            textDocStart: runStart,
            runStyle: runStyle,
            sentenceHighlightBg: highlightBg,
            activeWordStart: activeWordDocOffset,
            activeWordEnd: activeWordDocEnd,
            wordHighlightStyle: runWordHighlightStyle,
          );
        } else {
          // Sentence-only highlighting
          final bgColor = isInPreviewSentence
              ? previewSentenceBg
              : isInActiveSentence
                  ? sentenceBg
                  : null;
          final style =
              bgColor != null ? runStyle.copyWith(backgroundColor: bgColor) : runStyle;
          inlineSpans.add(TextSpan(text: runText, style: style));
        }

        runCursor = runEnd;
      }

      // Prefix for list items: numbered \u2192 "  N.  ", bullet/null \u2192 "  \u2022  ".
      // listPrefix is captured into displayPrefixLength below so pointer
      // hit-testing stays in sync with the rendered prefix width
      // (including multi-digit numbers like "10. ", "100. ").
      String? listPrefix;
      if (block.type == DocBlockType.listItem) {
        if (block.listType == 'numbered') {
          numberedCounter++;
          listPrefix = '  $numberedCounter.  ';
        } else {
          numberedCounter = 0;
          listPrefix = '  \u2022  ';
        }
        inlineSpans.insert(0, TextSpan(text: listPrefix, style: blockStyle));
      } else {
        numberedCounter = 0;
      }

      final spacing = block.type == DocBlockType.heading ? 16.0 : 8.0;

      final textSpan = TextSpan(children: inlineSpans);
      Widget blockChild = SelectableText.rich(
        textSpan,
        contextMenuBuilder: cmBuilder,
        textAlign: _textAlignFor(block.alignment),
      );

      if (widget.enablePointerSentenceSelection) {
        final displayPrefixLength = listPrefix?.length ?? 0;
        final baseBlockChild = blockChild;
        blockChild = LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              IgnorePointer(
                ignoring: true,
                child: baseBlockChild,
              ),
              Positioned.fill(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onHover: (event) {
                    final sentence = _sentenceForPointer(
                      block,
                      event.localPosition,
                      constraints.maxWidth,
                      textSpan,
                      displayPrefixLength: displayPrefixLength,
                    );
                    final nextIndex = sentence?.index;
                    if (nextIndex != _hoveredSentenceIdx && mounted) {
                      setState(() {
                        _hoveredSentenceIdx = nextIndex;
                      });
                    }
                  },
                  onExit: (_) {
                    if (_hoveredSentenceIdx != null && mounted) {
                      setState(() {
                        _hoveredSentenceIdx = null;
                      });
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapUp: (details) {
                      final sentence = _sentenceForPointer(
                        block,
                        details.localPosition,
                        constraints.maxWidth,
                        textSpan,
                        displayPrefixLength: displayPrefixLength,
                      );
                      if (sentence == null) return;
                      if (_hoveredSentenceIdx != sentence.index && mounted) {
                        setState(() {
                          _hoveredSentenceIdx = sentence.index;
                        });
                      }
                      widget.onSentenceTap?.call(sentence.startOffset);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      }

      blockWidgets.add(Padding(
        key: key,
        padding: EdgeInsets.only(bottom: spacing),
        child: blockChild,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blockWidgets,
    );
  }

  /// Split a run into sub-spans to highlight the active word within it.
  void _addWordHighlightedSpans({
    required List<TextSpan> spans,
    required String text,
    required int textDocStart,
    required TextStyle runStyle,
    required Color? sentenceHighlightBg,
    required int activeWordStart,
    required int activeWordEnd,
    required TextStyle wordHighlightStyle,
  }) {
    final textDocEnd = textDocStart + text.length;

    // Does the active word overlap this run at all?
    if (activeWordEnd <= textDocStart || activeWordStart >= textDocEnd) {
      // No overlap — just sentence highlight
      final style = sentenceHighlightBg != null
          ? runStyle.copyWith(backgroundColor: sentenceHighlightBg)
          : runStyle;
      spans.add(TextSpan(text: text, style: style));
      return;
    }

    // Clamp word boundaries to run boundaries
    final wStart = activeWordStart.clamp(textDocStart, textDocEnd);
    final wEnd = activeWordEnd.clamp(textDocStart, textDocEnd);

    // Before word
    if (wStart > textDocStart) {
      final style = sentenceHighlightBg != null
          ? runStyle.copyWith(backgroundColor: sentenceHighlightBg)
          : runStyle;
      spans.add(TextSpan(
        text: text.substring(0, wStart - textDocStart),
        style: style,
      ));
    }

    // The word itself
    spans.add(TextSpan(
      text: text.substring(wStart - textDocStart, wEnd - textDocStart),
      style: wordHighlightStyle,
    ));

    // After word
    if (wEnd < textDocEnd) {
      final style = sentenceHighlightBg != null
          ? runStyle.copyWith(backgroundColor: sentenceHighlightBg)
          : runStyle;
      spans.add(TextSpan(
        text: text.substring(wEnd - textDocStart),
        style: style,
      ));
    }
  }

  bool _isWordChar(String ch) {
    final c = ch.codeUnitAt(0);
    final isAlphaNum =
        (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
    return isAlphaNum || ch == "'";
  }
}
