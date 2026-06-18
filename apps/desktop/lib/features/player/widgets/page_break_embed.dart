// Page break embed scaffolding (M13.5 backlog).
//
// This file lands on develop AHEAD of the user-visible toolbar button
// so that:
//   1. EmbedBuilder is registered on every QuillEditor instance — any
//      data already containing a page_break embed loads without the
//      UnimplementedError that flutter_quill raises for unknown embed
//      types (editor.dart:413).
//   2. The save and load paths in player_screen.dart can detect and
//      emit page_break blocks without crashing.
//
// The matching toolbar customButton + insert helper live ONLY on the
// spike branch `spike/page-break-embed-validation` (tag
// `m13.5-pagebreak-spike`). They land on develop alongside the
// "skip-next-newline state machine" save-path fix in M13.5.
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Inner type discriminator for the page-break custom embed. After
/// flutter_quill unwraps a BlockEmbed.custom via
/// `CustomBlockEmbed.fromJsonString` (text_line.dart:148-152), the
/// resulting node carries this string as its `value.type`, and the
/// editor's `_getEmbedBuilder` (editor.dart:397-419) uses it to
/// dispatch to [PageBreakEmbedBuilder].
const String kPageBreakInnerType = 'page_break';

/// CustomBlockEmbed for a page break. Carries no payload — the
/// presence of the type alone is the signal. JSON wire format:
///   outer: {"insert": {"custom": "<jsonString>"}}
///   inner: {"page_break": ""}
class PageBreakEmbed extends CustomBlockEmbed {
  const PageBreakEmbed() : super(kPageBreakInnerType, '');
}

/// Renders a PageBreakEmbed as a horizontal divider with a "Page Break"
/// label between two horizontal rules. Single-line block embed —
/// `expanded: true` causes flutter_quill's text_line.dart to replace
/// the whole line with this widget when the line contains exactly one
/// embed (the InsertEmbedsRule does NOT auto-wrap newlines around
/// custom embeds, so the inserter is responsible for surrounding \n).
class PageBreakEmbedBuilder extends EmbedBuilder {
  @override
  String get key => kPageBreakInnerType;

  @override
  bool get expanded => true;

  @override
  String toPlainText(Embed node) => '\n\f\n';

  @override
  Widget build(
    BuildContext context,
    EmbedContext embedContext,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Page Break',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          const Expanded(child: Divider(thickness: 1)),
        ],
      ),
    );
  }
}
