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
/// Only this widget rebuilds on position ticks — PlayerScreen stays still.
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
  });

  final String chunkText;
  final Map<String, dynamic> alignmentPayload;

  @override
  ConsumerState<WordHighlightView> createState() => _WordHighlightViewState();
}

class _WordHighlightViewState extends ConsumerState<WordHighlightView> {
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

  @override
  void initState() {
    super.initState();
    // Listen via addListener pattern is unsafe here; we use didChangeDependencies
  }

  @override
  Widget build(BuildContext context) {
    // Safe watch — ConsumerState guards against defunct element
    final position =
        ref.watch(audioPositionProvider).valueOrNull ?? Duration.zero;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseStyle = theme.textTheme.bodyLarge?.copyWith(
      height: 1.8,
      fontSize: 16,
    );

    final alignmentBlock = widget.alignmentPayload['alignment'];
    if (alignmentBlock is! Map) {
      return SelectableText(widget.chunkText, style: baseStyle);
    }

    final spans = _computeWordSpans(widget.chunkText);
    if (spans.isEmpty) {
      return SelectableText(widget.chunkText, style: baseStyle);
    }

    final charIdx = _charIndexAtMs(alignmentBlock, position.inMilliseconds);
    if (charIdx == null) {
      return SelectableText(widget.chunkText, style: baseStyle);
    }

    final activeWord = _wordIndexFromCharIndex(spans, charIdx);

    final highlightStyle = baseStyle?.copyWith(
      backgroundColor: AppColors.primary.withOpacity(isDark ? 0.35 : 0.22),
      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
      fontWeight: FontWeight.w700,
    );

    final children = <TextSpan>[];
    int cursor = 0;

    for (int i = 0; i < spans.length; i++) {
      final sp = spans[i];
      if (cursor < sp.start) {
        children.add(TextSpan(
          text: widget.chunkText.substring(cursor, sp.start),
          style: baseStyle,
        ));
      }
      children.add(TextSpan(
        text: widget.chunkText.substring(sp.start, sp.end),
        style: i == activeWord ? highlightStyle : baseStyle,
      ));
      cursor = sp.end;
    }

    if (cursor < widget.chunkText.length) {
      children.add(TextSpan(
        text: widget.chunkText.substring(cursor),
        style: baseStyle,
      ));
    }

    return SelectableText.rich(TextSpan(children: children));
  }
}
