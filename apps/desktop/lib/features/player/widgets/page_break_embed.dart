// SPIKE — page break embed validation. NOT production code.
// Throwaway implementation to validate flutter_quill 10.8.5's
// BlockEmbed.custom + EmbedBuilder pipeline before committing to the
// full Ship 2 plan (~353 LoC).
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
    QuillController controller,
    Embed node,
    bool readOnly,
    bool inline,
    TextStyle textStyle,
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
