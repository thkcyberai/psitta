import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../data/models/psitta_document.dart';
import '../../../data/services/audio_service.dart';

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
    this.focusedSentenceIndex,
    this.onActiveSentenceChanged,
    this.onActiveWordChanged,
    this.onMarkerTap,
    this.audioService,
    this.enableContextMenu = true,
    this.markerModeEnabled = false,
    this.blockKeys,
  });

  final PsittaDocument document;

  /// Which chunk is currently playing (index into chunkMap).
  final int activeChunkIndex;

  /// Word-timing alignment from ElevenLabs (chunk-scoped).
  final Map<String, dynamic> alignmentPayload;
  final int? focusedSentenceIndex;

  final void Function(GlobalKey blockKey)? onActiveSentenceChanged;
  final void Function(int wordIndex, int totalWords)? onActiveWordChanged;
  final void Function(int docOffset)? onMarkerTap;
  final AudioService? audioService;
  final bool enableContextMenu;
  final bool markerModeEnabled;

  /// Shared block key registry — allows external code (e.g. outline sidebar)
  /// to look up GlobalKeys for specific blocks.
  final Map<String, GlobalKey>? blockKeys;

  @override
  ConsumerState<DocumentReadingView> createState() =>
      _DocumentReadingViewState();
}

class _DocumentReadingViewState extends ConsumerState<DocumentReadingView> {
  final Map<String, GlobalKey> _localBlockKeys = {};
  int _lastActiveSentenceIdx = 0;

  GlobalKey _keyForBlock(String blockId) {
    final registry = widget.blockKeys ?? _localBlockKeys;
    return registry.putIfAbsent(blockId, () => GlobalKey());
  }

  int _sentenceStartOffsetForTap(
    DocBlock block,
    Offset localPosition,
    Size size,
  ) {
    if (size.height <= 0) return block.textOffset;

    final blockEnd = block.textOffset + block.textLength;
    final blockSentences = widget.document.sentences
        .where((sentence) =>
            sentence.startOffset < blockEnd &&
            sentence.endOffset > block.textOffset &&
            sentence.blockIds.contains(block.blockId))
        .toList()
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));

    if (blockSentences.isEmpty) {
      return block.textOffset;
    }

    final ratio = (localPosition.dy / size.height).clamp(0.0, 0.999999);
    final sentenceIndex = (ratio * blockSentences.length)
        .floor()
        .clamp(0, blockSentences.length - 1);
    return blockSentences[sentenceIndex].startOffset;
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

    // Fire scroll callback when sentence changes
    if (audioSentenceIdx != null &&
        audioSentenceIdx > 0 &&
        audioSentenceIdx != _lastActiveSentenceIdx) {
      _lastActiveSentenceIdx = audioSentenceIdx;
      final sent = doc.sentences[audioSentenceIdx];
      if (sent.blockIds.isNotEmpty) {
        final key = _keyForBlock(sent.blockIds.first);
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
    final wordHighlightStyle = TextStyle(
      backgroundColor: AppColors.primary.withOpacity(isDark ? 0.35 : 0.22),
      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
      fontWeight: FontWeight.w700,
    );

    final cmBuilder = widget.enableContextMenu ? _buildContextMenu : null;

    // ── Render blocks ──
    final blockWidgets = <Widget>[];

    for (final block in doc.blocks) {
      final key = _keyForBlock(block.blockId);
      final blockStart = block.textOffset;

      // Determine block-level text style
      TextStyle blockStyle;
      switch (block.type) {
        case DocBlockType.heading:
          switch (block.level) {
            case 1:
              blockStyle = theme.textTheme.headlineMedium ??
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold);
            case 2:
              blockStyle = theme.textTheme.headlineSmall ??
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
            case 3:
              blockStyle = theme.textTheme.titleLarge ??
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
            default:
              blockStyle = theme.textTheme.titleLarge ??
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
          }
          blockStyle = blockStyle.copyWith(height: 1.6);
        case DocBlockType.listItem:
          blockStyle = theme.textTheme.bodyLarge?.copyWith(
                height: 1.6,
                fontSize: 16,
              ) ??
              const TextStyle(fontSize: 16, height: 1.6);
        case DocBlockType.paragraph:
          blockStyle = theme.textTheme.bodyLarge?.copyWith(
                height: 1.8,
                fontSize: 16,
              ) ??
              const TextStyle(fontSize: 16, height: 1.8);
      }

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
        if (run.underline) {
          runStyle = runStyle.copyWith(decoration: TextDecoration.underline);
        }

        // Check if this run overlaps the active sentence
        bool isInActiveSentence = false;
        if (activeSentenceIdx != null &&
            activeSentenceIdx < doc.sentences.length) {
          final sent = doc.sentences[activeSentenceIdx];
          isInActiveSentence =
              runStart < sent.endOffset && runEnd > sent.startOffset;
        }

        // Check if this run overlaps the active word
        if (activeWordDocOffset != null && activeWordDocEnd != null) {
          // Split run into sub-spans for word highlighting
          _addWordHighlightedSpans(
            spans: inlineSpans,
            text: runText,
            textDocStart: runStart,
            runStyle: runStyle,
            isInActiveSentence: isInActiveSentence,
            sentenceBg: sentenceBg,
            activeWordStart: activeWordDocOffset,
            activeWordEnd: activeWordDocEnd,
            wordHighlightStyle: wordHighlightStyle,
          );
        } else {
          // Sentence-only highlighting
          final style = isInActiveSentence
              ? runStyle.copyWith(backgroundColor: sentenceBg)
              : runStyle;
          inlineSpans.add(TextSpan(text: runText, style: style));
        }

        runCursor = runEnd;
      }

      // Prefix for list items
      if (block.type == DocBlockType.listItem) {
        inlineSpans.insert(0, TextSpan(text: '  \u2022  ', style: blockStyle));
      }

      final spacing = block.type == DocBlockType.heading ? 16.0 : 8.0;

      Widget blockChild = SelectableText.rich(
        TextSpan(children: inlineSpans),
        contextMenuBuilder: cmBuilder,
      );

      if (widget.markerModeEnabled) {
        blockChild = Stack(
          children: [
            IgnorePointer(
              ignoring: true,
              child: blockChild,
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final ctx = key.currentContext;
                  final box = ctx?.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final docOffset = _sentenceStartOffsetForTap(
                    block,
                    details.localPosition,
                    box.size,
                  );
                  widget.onMarkerTap?.call(docOffset);
                },
              ),
            ),
          ],
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
    required bool isInActiveSentence,
    required Color sentenceBg,
    required int activeWordStart,
    required int activeWordEnd,
    required TextStyle wordHighlightStyle,
  }) {
    final textDocEnd = textDocStart + text.length;

    // Does the active word overlap this run at all?
    if (activeWordEnd <= textDocStart || activeWordStart >= textDocEnd) {
      // No overlap — just sentence highlight
      final style = isInActiveSentence
          ? runStyle.copyWith(backgroundColor: sentenceBg)
          : runStyle;
      spans.add(TextSpan(text: text, style: style));
      return;
    }

    // Clamp word boundaries to run boundaries
    final wStart = activeWordStart.clamp(textDocStart, textDocEnd);
    final wEnd = activeWordEnd.clamp(textDocStart, textDocEnd);

    // Before word
    if (wStart > textDocStart) {
      final style = isInActiveSentence
          ? runStyle.copyWith(backgroundColor: sentenceBg)
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
      final style = isInActiveSentence
          ? runStyle.copyWith(backgroundColor: sentenceBg)
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
