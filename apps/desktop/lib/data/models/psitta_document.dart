import 'package:flutter/foundation.dart';

import '../../features/player/chunk_slicer.dart' show ChunkPositionRange;

/// Inline text run with optional formatting.
@immutable
class DocRun {
  const DocRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.fontSize,
    this.color,
    this.fontFamily,
  });

  factory DocRun.fromJson(Map<String, dynamic> j) => DocRun(
        text: (j['text'] ?? '') as String,
        bold: j['bold'] == true,
        italic: j['italic'] == true,
        underline: j['underline'] == true,
        strike: j['strike'] == true,
        fontSize: j['font_size'] != null ? (j['font_size'] as num).toDouble() : null,
        color: j['color'] is String ? j['color'] as String : null,
        fontFamily: j['font_family'] is String ? j['font_family'] as String : null,
      );

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final double? fontSize;

  /// Hex color string in lowercase 6-digit format without `#` (e.g. `ff0000`).
  /// Stored normalized at the save boundary; null if unset.
  final String? color;

  /// Font family name (e.g. `Arial`). Falls back to system default in
  /// renderers that don't have the font installed (R3 accepted behavior).
  final String? fontFamily;
}

/// Block types supported by the document model.
enum DocBlockType { heading, paragraph, listItem }

/// A structural block in the document (heading, paragraph, list item).
@immutable
class DocBlock {
  const DocBlock({
    required this.blockId,
    required this.type,
    required this.runs,
    required this.textOffset,
    required this.textLength,
    this.level,
    this.listType,
    this.alignment,
  });

  /// Stable identifier for this block (e.g. "b_0", "b_1").
  final String blockId;

  final DocBlockType type;

  /// Heading level (1-6). Only meaningful when type == heading.
  final int? level;

  /// List type ('bullet' or 'numbered'). Only meaningful when
  /// type == listItem. Round-trips through formatted_content as
  /// `list_type`; consumed by the editor load path
  /// (_blockLevelAttrs in player_screen.dart) to emit the correct
  /// Quill `list` attribute ('bullet' vs 'ordered').
  final String? listType;

  /// Block-level alignment ('left' | 'center' | 'right' | 'justify').
  /// Round-trips through formatted_content as `alignment`. Composes with
  /// heading and list_item — orthogonal to type/level/listType. Null means
  /// "inherit / default left start" so unset and explicit-left are
  /// distinguishable on the wire (matters for the Word style cascade).
  final String? alignment;

  /// Inline runs that compose this block's text.
  final List<DocRun> runs;

  /// Start character offset of this block's text within the document's plainText.
  final int textOffset;

  /// Length of this block's plain text.
  final int textLength;

  /// Convenience: the block's plain text.
  String get plainText => runs.map((r) => r.text).join();
}

/// A sentence span mapped to document-level offsets.
@immutable
class DocSentence {
  const DocSentence({
    required this.index,
    required this.startOffset,
    required this.endOffset,
    required this.blockIds,
  });

  final int index;

  /// Start character offset in the document's plainText.
  final int startOffset;

  /// End character offset (exclusive) in the document's plainText.
  final int endOffset;

  /// Which block IDs this sentence spans (usually one, occasionally two).
  final List<String> blockIds;
}

/// Maps a backend chunk to a range within the document's plainText.
@immutable
class ChunkRef {
  const ChunkRef({
    required this.chunkId,
    required this.chunkIndex,
    required this.textOffset,
    required this.textLength,
  });

  final String chunkId;
  final int chunkIndex;

  /// Start offset of this chunk's text within the document's plainText.
  final int textOffset;

  /// Length of this chunk's text content.
  final int textLength;
}

/// The canonical document model.
///
/// Assembles the visual layer (blocks with formatting) and semantic layer
/// (sentences, chunk mapping) into a single structure that both rendering
/// and reading intelligence operate on.
@immutable
class PsittaDocument {
  const PsittaDocument({
    required this.id,
    required this.title,
    required this.blocks,
    required this.plainText,
    required this.sentences,
    required this.chunkMap,
    this.chunkPositions,
    this.sourceType,
  });

  final String id;
  final String title;

  /// Backend `source_type` (e.g. `'docx'`, `'pdf'`, `'epub'`, `'txt'`).
  /// Drives read-only gating: PDF and EPUB open read-only in the Desk.
  final String? sourceType;

  /// True when this document type cannot be edited in the Writing Desk
  /// (read-only formats: PDF, EPUB).
  bool get isReadOnly {
    final s = sourceType?.toLowerCase();
    return s == 'pdf' || s == 'epub';
  }

  final List<DocBlock> blocks;

  /// Concatenated plain text of all blocks. Source of truth for offset math.
  final String plainText;

  /// Sentence spans in document-level offsets.
  final List<DocSentence> sentences;

  /// Maps backend chunks to document-level offset ranges.
  final List<ChunkRef> chunkMap;

  /// Authoritative chunk-offset map persisted on `documents.chunk_positions`
  /// by the M13.1b unified-editor save path. Null for pre-M13.1b documents
  /// (the client then falls back to [chunkMap] — lazy migration).
  final List<ChunkPositionRange>? chunkPositions;

  /// Find the chunk that contains a given document-level character offset.
  ChunkRef? chunkForOffset(int docOffset) {
    for (final c in chunkMap) {
      if (docOffset >= c.textOffset && docOffset < c.textOffset + c.textLength) {
        return c;
      }
    }
    return chunkMap.isNotEmpty ? chunkMap.last : null;
  }

  /// Convert a document-level offset to a chunk-level offset.
  int toChunkOffset(int docOffset, ChunkRef chunk) {
    return (docOffset - chunk.textOffset).clamp(0, chunk.textLength);
  }

  /// Find the block that contains a given document-level character offset.
  DocBlock? blockForOffset(int docOffset) {
    for (final b in blocks) {
      if (docOffset >= b.textOffset && docOffset < b.textOffset + b.textLength) {
        return b;
      }
    }
    return null;
  }

  /// Find the sentence that contains a given document-level character offset.
  DocSentence? sentenceForOffset(int docOffset) {
    for (final s in sentences) {
      if (docOffset >= s.startOffset && docOffset < s.endOffset) {
        return s;
      }
    }
    return null;
  }
}
