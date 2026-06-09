/// Pure conversion utilities between canonical block-dict lists and
/// [quill.Document] Delta format.
///
/// These functions are the sole bridge between the backend's
/// `formatted_content` JSON schema (block-dict lists) and the flutter_quill
/// Delta model. They are intentionally stateless free functions so they can be
/// used by the Player editor and the Writing Desk editor without duplicating
/// logic or risking render-path symmetry bugs.
///
/// ## Block-dict schema (backend `formatted_content`)
/// Each block is a `Map<String, dynamic>` with:
/// - `type`: `"paragraph"` | `"heading"` | `"list_item"` | `"page_break"`
/// - `runs`: `List<Map>` — inline text segments. Each run: `{text, bold?,
///   italic?, underline?, strike?, font_size?, color?, font_family?}`
/// - `level`: `int?` — heading level 1–6 (heading blocks only)
/// - `list_type`: `"bullet"` | `"numbered"` (list_item blocks only)
/// - `alignment`: `"left"` | `"center"` | `"right"` | `"justify"` (optional)
///
/// ## Quill Delta conventions (flutter_quill 10.8.5)
/// - Inline text runs: `{insert: text, attributes?: {...}}`
/// - Block terminator: `{insert: "\n", attributes?: {header?:int, list?:str,
///   align?:str}}`
/// - Empty document sentinel: `[{insert: "\n"}]`
library;

import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../data/models/psitta_document.dart' show DocBlockType;
import '../../features/player/widgets/page_break_embed.dart';

// ── Color normalisation ───────────────────────────────────────────────────────

/// Normalises a hex color string to lowercase 6-digit form without `#`.
///
/// Accepts `#RRGGBB`, `RRGGBB`, `#AARRGGBB`, or `AARRGGBB`. For 8-digit
/// inputs the leading alpha+red byte is stripped (correct AARRGGBB → RRGGBB;
/// avoids the AARRGGBB-kept-as-RRGGBB bug that caused red to render as yellow).
/// Returns `null` for malformed inputs (wrong length, non-hex chars, etc.).
String? normalizeHexColor(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  final body = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
  if (body.length != 6 && body.length != 8) return null;
  for (int i = 0; i < 6; i++) {
    final c = body.codeUnitAt(i);
    final isDigit = c >= 0x30 && c <= 0x39;
    final isHexLower = c >= 0x61 && c <= 0x66;
    final isHexUpper = c >= 0x41 && c <= 0x46;
    if (!isDigit && !isHexLower && !isHexUpper) return null;
  }
  return (body.length == 8 ? body.substring(2) : body).toLowerCase();
}

// ── Block-level attribute helpers ─────────────────────────────────────────────

/// Converts a canonical block dict's `type` to its wire string.
String blockTypeToString(DocBlockType type) {
  switch (type) {
    case DocBlockType.heading:
      return 'heading';
    case DocBlockType.listItem:
      return 'list_item';
    case DocBlockType.paragraph:
      return 'paragraph';
  }
}

/// Extracts the Quill block-level attribute map from a block dict.
///
/// Heading uses `{header: int}` (1–6); list items use
/// `{list: 'bullet'|'ordered'}`. Alignment (`left|center|right|justify`)
/// composes orthogonally — a centered heading is `{header:1, align:'center'}`.
Map<String, dynamic> blockLevelAttrs(Map<String, dynamic> block) {
  final attrs = <String, dynamic>{};
  final type = block['type'] as String?;
  if (type == 'heading') {
    final level = block['level'];
    if (level is int && level >= 1 && level <= 6) {
      attrs['header'] = level;
    }
  } else if (type == 'list_item') {
    // list_type: 'numbered' → Quill 'ordered'; default/missing/'bullet'
    // → Quill 'bullet'. Round-trips with quillDocumentToBlockDicts which
    // emits 'numbered' for Quill 'ordered' and 'bullet' for Quill 'bullet'.
    final listType = block['list_type'];
    attrs['list'] = (listType == 'numbered') ? 'ordered' : 'bullet';
  }
  final alignment = block['alignment'];
  if (alignment is String &&
      (alignment == 'left' ||
          alignment == 'center' ||
          alignment == 'right' ||
          alignment == 'justify')) {
    attrs['align'] = alignment;
  }
  return attrs;
}

/// Compare two Quill inline-attribute maps for run-grouping equality.
///
/// MUST list every inline attribute the formatted_content schema supports.
/// If an attribute is missing here, adjacent ops differing only in that
/// attribute will be incorrectly merged into one run on save, producing scope
/// spread or attribute loss. (See CLAUDE.md KL 2026-04-26 for the full bug
/// history — strike/color/font were omitted initially.)
bool attributesEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
  const keys = ['bold', 'italic', 'underline', 'size', 'strike', 'color', 'font'];
  for (final key in keys) {
    if ((a[key] ?? false) != (b[key] ?? false)) {
      if (a[key] == null && b[key] == null) continue;
      if (a[key] != b[key]) return false;
    }
  }
  return true;
}

// ── Block-dict ↔ Quill.Document converters ───────────────────────────────────

/// Convert a flat block-dict list into a [quill.Document].
///
/// Each block's runs become inline `insert` ops carrying the Phase 1
/// attribute set ({bold, italic, underline, size, strike, color, font}).
/// The block is terminated by a `\n` insert that carries block-level
/// attributes ({header, list, align}) — Quill's documented convention for
/// paragraph, heading, and list styling.
quill.Document blockDictsToQuillDocument(
  List<Map<String, dynamic>> blockDicts,
) {
  if (blockDicts.isEmpty) {
    return quill.Document.fromJson(<Map<String, dynamic>>[
      <String, dynamic>{'insert': '\n'}
    ]);
  }
  final ops = <Map<String, dynamic>>[];
  for (final block in blockDicts) {
    // M13.5 scaffolding — page_break blocks have no runs, no text,
    // no block-level attrs. Emit the BlockEmbed.custom op (which
    // serializes to {custom: '<jsonString>'} — the shape
    // text_line.dart:148 recognizes) + a trailing \n so the embed
    // owns its line per the single-child-line invariant.
    if (block['type'] == 'page_break') {
      ops.add(<String, dynamic>{
        'insert': quill.BlockEmbed.custom(const PageBreakEmbed()).toJson(),
      });
      ops.add(<String, dynamic>{'insert': '\n'});
      continue;
    }
    final runs = (block['runs'] as List?) ?? const [];
    for (final raw in runs) {
      if (raw is! Map) continue;
      final text = (raw['text'] ?? '') as String;
      if (text.isEmpty) continue;
      final attrs = <String, dynamic>{};
      if (raw['bold'] == true) attrs['bold'] = true;
      if (raw['italic'] == true) attrs['italic'] = true;
      if (raw['underline'] == true) attrs['underline'] = true;
      if (raw['strike'] == true) attrs['strike'] = true;
      final fontSize = raw['font_size'];
      if (fontSize != null) {
        // Emit whole-number sizes as integer strings ("20") to match
        // the toolbar dropdown's key format; emit fractional sizes with
        // their full decimal representation.
        final d = (fontSize as num).toDouble();
        final asInt = d.toInt();
        final isWhole = asInt.toDouble() == d;
        attrs['size'] = (isWhole ? asInt : d).toString();
      }
      // Color: stored as lowercase 6-digit hex without `#`. Quill's
      // ColorAttribute expects the `#`-prefixed form.
      final colorRaw = raw['color'];
      if (colorRaw is String && colorRaw.isNotEmpty) {
        attrs['color'] = colorRaw.startsWith('#') ? colorRaw : '#$colorRaw';
      }
      // Font family: stored as `font_family` (matching python-docx
      // run.font.name); Quill's FontAttribute uses the `font` key.
      final fontFamily = raw['font_family'];
      if (fontFamily is String && fontFamily.isNotEmpty) {
        attrs['font'] = fontFamily;
      }
      final op = <String, dynamic>{'insert': text};
      if (attrs.isNotEmpty) op['attributes'] = attrs;
      ops.add(op);
    }
    // Close the block with a `\n` carrying any block-level attrs.
    final bAttrs = blockLevelAttrs(block);
    final newlineOp = <String, dynamic>{'insert': '\n'};
    if (bAttrs.isNotEmpty) newlineOp['attributes'] = bAttrs;
    ops.add(newlineOp);
  }
  return quill.Document.fromJson(ops);
}

/// Convert a [quill.Document] back into a canonical block-dict list.
///
/// Groups consecutive inline inserts by identical attribute-set and splits
/// into multiple blocks on paragraph-break boundaries.
///
/// Paragraph-break demotion: the FIRST emitted block inherits [type] and
/// [level]; any additional blocks produced by a newline inside the document
/// use [DocBlockType.paragraph] with `level == null`. This matches Word's
/// behaviour — pressing Enter inside a heading splits off a plain body
/// paragraph, it does not clone the heading.
///
/// Phase 1 silently drops attributes outside the supported set — these are
/// also hidden from the toolbar so users cannot generate them in practice.
List<Map<String, dynamic>> quillDocumentToBlockDicts(
  quill.Document doc,
  DocBlockType type,
  int? level,
) {
  final outBlocks = <Map<String, dynamic>>[];
  var currentRuns = <Map<String, dynamic>>[];
  var currentType = type;
  int? currentLevel = level;
  String? currentListType;
  String? currentAlignment;
  Map<String, dynamic>? pendingAttrs;
  final pendingText = StringBuffer();

  void flush() {
    final text = pendingText.toString();
    if (text.isEmpty) return;
    final run = <String, dynamic>{'text': text};
    final attrs = pendingAttrs;
    if (attrs != null) {
      if (attrs['bold'] == true) run['bold'] = true;
      if (attrs['italic'] == true) run['italic'] = true;
      if (attrs['underline'] == true) run['underline'] = true;
      if (attrs['strike'] == true) run['strike'] = true;
      final size = attrs['size'];
      if (size != null) {
        final parsed = double.tryParse(size.toString());
        if (parsed != null) run['font_size'] = parsed;
      }
      // Color: flutter_quill emits `#RRGGBB`. Normalize to lowercase 6-digit
      // no-`#` so the export builder can hand it to RGBColor.from_string
      // without further coercion. Unparseable shapes are dropped silently.
      final rawColor = attrs['color'];
      if (rawColor is String) {
        final normalized = normalizeHexColor(rawColor);
        if (normalized != null) run['color'] = normalized;
      }
      // Font family: flutter_quill emits `font`. Stored as `font_family` to
      // match the python-docx run.font.name contract on the export side.
      final rawFont = attrs['font'];
      if (rawFont is String && rawFont.isNotEmpty) {
        run['font_family'] = rawFont;
      }
    }
    currentRuns.add(run);
    pendingText.clear();
  }

  void closeBlock() {
    if (currentRuns.isEmpty && outBlocks.isNotEmpty) {
      // Skip empty trailing blocks produced by the terminating newline
      // that every Quill document carries.
      currentType = DocBlockType.paragraph;
      currentLevel = null;
      currentListType = null;
      currentAlignment = null;
      return;
    }
    final runs = currentRuns.isEmpty
        ? <Map<String, dynamic>>[<String, dynamic>{'text': ''}]
        : currentRuns;
    final dict = <String, dynamic>{
      'type': blockTypeToString(currentType),
      'runs': runs,
    };
    if (currentLevel != null) dict['level'] = currentLevel;
    if (currentListType != null) dict['list_type'] = currentListType;
    if (currentAlignment != null) dict['alignment'] = currentAlignment;
    outBlocks.add(dict);
    currentRuns = <Map<String, dynamic>>[];
    // Paragraph-break demotion: subsequent blocks are plain paragraphs.
    currentType = DocBlockType.paragraph;
    currentLevel = null;
    currentListType = null;
    currentAlignment = null;
  }

  for (final op in doc.toDelta().toList()) {
    final data = op.data;
    // M13.5 scaffolding — detect a PageBreakEmbed serialized as
    // {insert: {custom: '{"page_break":""}'}}. We emit the page_break block
    // here so any data already containing one round-trips cleanly through
    // save.
    if (data is Map) {
      final customJson = data['custom'];
      if (customJson is String) {
        try {
          final inner = jsonDecode(customJson);
          if (inner is Map && inner.containsKey('page_break')) {
            flush();
            closeBlock();
            outBlocks.add(<String, dynamic>{
              'type': 'page_break',
              'runs': const <Map<String, dynamic>>[],
            });
          }
        } catch (_) {
          // malformed embed JSON — drop silently
        }
      }
      continue; // skip non-page-break embeds and the failed page_break
    }
    if (data is! String) continue;
    final chunks = data.split('\n');
    for (var i = 0; i < chunks.length; i++) {
      final fragment = chunks[i];
      if (fragment.isNotEmpty) {
        final attrs = op.attributes ?? const <String, dynamic>{};
        final current = pendingAttrs;
        if (current == null || !attributesEqual(current, attrs)) {
          flush();
          pendingAttrs = Map<String, dynamic>.from(attrs);
        }
        pendingText.write(fragment);
      }
      // Newline between fragments — close the current block and start a new
      // one. Read block-level attributes BEFORE closeBlock() so the emitted
      // dict has the correct type/level/list_type/alignment.
      if (i != chunks.length - 1) {
        flush();
        pendingAttrs = null;
        final blockAttrs = op.attributes ?? const <String, dynamic>{};
        final headerAttr = blockAttrs['header'];
        if (headerAttr is int && headerAttr >= 1 && headerAttr <= 6) {
          currentType = DocBlockType.heading;
          currentLevel = headerAttr;
          currentListType = null;
        } else {
          final listAttr = blockAttrs['list'];
          if (listAttr == 'bullet') {
            currentType = DocBlockType.listItem;
            currentLevel = null;
            currentListType = 'bullet';
          } else if (listAttr == 'ordered') {
            currentType = DocBlockType.listItem;
            currentLevel = null;
            currentListType = 'numbered';
          }
        }
        final alignAttr = blockAttrs['align'];
        if (alignAttr is String &&
            (alignAttr == 'left' ||
                alignAttr == 'center' ||
                alignAttr == 'right' ||
                alignAttr == 'justify')) {
          currentAlignment = alignAttr;
        }
        closeBlock();
      }
    }
  }
  flush();
  closeBlock();

  if (outBlocks.isEmpty) {
    outBlocks.add(<String, dynamic>{
      'type': blockTypeToString(type),
      'runs': <Map<String, dynamic>>[<String, dynamic>{'text': ''}],
      if (level != null) 'level': level,
    });
  }
  return outBlocks;
}
