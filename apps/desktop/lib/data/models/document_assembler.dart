import '../../features/player/chunk_slicer.dart';
import 'psitta_document.dart';

/// Builds a [PsittaDocument] from the backend chunks API response.
///
/// Handles two cases:
///   1. Chunks with formatted_content -> structured blocks with formatting
///   2. Chunks without formatted_content -> synthetic paragraph blocks from plain text
///
/// In both cases, sentence boundaries are lifted from chunk-level offsets
/// to document-level offsets, and blocks get stable IDs and document-level
/// text offsets.
class DocumentAssembler {
  static String _normalizeVisibleText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _flattenFormattedContent(List<dynamic> formatted) {
    final blocks = <String>[];
    for (final entry in formatted) {
      if (entry is! Map<String, dynamic>) continue;
      final runs = (entry['runs'] as List<dynamic>?) ?? const [];
      final blockText = runs
          .whereType<Map<String, dynamic>>()
          .map((run) => (run['text'] ?? '').toString())
          .join()
          .trim();
      if (blockText.isNotEmpty) {
        blocks.add(blockText);
      }
    }
    return blocks.join('\n\n');
  }

  static bool _formattedContentMatchesChunkText(
    List<dynamic>? formatted,
    String chunkText,
  ) {
    if (formatted == null || formatted.isEmpty) return false;
    final formattedText = _flattenFormattedContent(formatted);
    if (formattedText.isEmpty) return false;
    return _normalizeVisibleText(formattedText) ==
        _normalizeVisibleText(chunkText);
  }

  /// Assemble a PsittaDocument from the chunks API response map.
  ///
  /// [data] is the raw response: `{ 'document_id': ..., 'chunks': [...] }`.
  /// [title] is the document title (from the Document model or first chunk).
  /// [sourceType] is the document's backend `source_type` (e.g. `'docx'`,
  /// `'pdf'`, `'blank'`). When `'docx'`, a blank document that would
  /// otherwise produce zero blocks (all runs empty) is given one synthetic
  /// empty paragraph so the player's DOCX pipeline has something to render
  /// instead of falling through to the legacy chunk editor.
  static PsittaDocument assemble({
    required Map<String, dynamic> data,
    required String title,
    String? sourceType,
  }) {
    final documentId = (data['document_id'] ?? '').toString();
    final rawChunks = (data['chunks'] as List<dynamic>?) ?? [];

    // M13.1b — parse the authoritative chunk-offset map from the
    // server response when present. Keyed by chunk_id for fast
    // per-chunk lookup during the assembly loop. Null/absent on
    // pre-M13.1b documents; we fall back to the computed cursor.
    final rawPositions = data['chunk_positions'];
    List<ChunkPositionRange>? chunkPositions;
    Map<String, ChunkPositionRange>? positionsById;
    if (rawPositions is List) {
      chunkPositions = rawPositions
          .whereType<Map>()
          .map((e) =>
              ChunkPositionRange.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      positionsById = <String, ChunkPositionRange>{
        for (final r in chunkPositions) r.chunkId: r,
      };
    }

    final blocks = <DocBlock>[];
    final sentences = <DocSentence>[];
    final chunkMapEntries = <ChunkRef>[];
    final plainTextBuf = StringBuffer();

    int blockIndex = 0;
    int docCharCursor = 0;
    int sentenceGlobalIndex = 0;

    for (final rawChunk in rawChunks) {
      final chunk = rawChunk as Map<String, dynamic>;
      final chunkId = (chunk['id'] ?? '').toString();
      final chunkIndex = (chunk['sequence_index'] ?? 0) as int;
      final chunkText = (chunk['text_content'] ?? '').toString();
      final formatted = chunk['formatted_content'] as List<dynamic>?;
      final sentBounds = chunk['sentence_boundaries'] as List<dynamic>?;
      final useFormatted =
          _formattedContentMatchesChunkText(formatted, chunkText);

      // Prefer the server-authoritative position map when present; fall
      // back to the running cursor for pre-M13.1b documents. The cursor
      // still advances in lockstep so it stays correct as a fallback on
      // any later chunk that may be missing from positionsById.
      final serverRange = positionsById?[chunkId];
      // Fix C-3: chunk's true start in plainTextBuf is the current buffer
      // length plus the inter-chunk "\n\n" separator (2 chars) that will be
      // written below when this isn't the first chunk. Forecasting it here
      // BEFORE the offset decision lets the fallback path match the actual
      // plainText position byte-for-byte (the value the probe logs as
      // `actualStart`). docCharCursor is left intact for the separator gate.
      final chunkPlainStart =
          plainTextBuf.length + (plainTextBuf.length > 0 ? 2 : 0);
      final chunkTextOffset = serverRange?.startOffset ?? chunkPlainStart;

      // ── Build blocks ──
      if (useFormatted) {
        // Structured content: walk formatted blocks and align to chunkText
        final formattedBlocks = formatted!;
        int fmtCursor = 0; // cursor within chunkText for formatted block alignment

        for (final fb in formattedBlocks) {
          final fBlock = fb as Map<String, dynamic>;
          final fType = (fBlock['type'] ?? 'paragraph') as String;
          final fLevel = fBlock['level'] as int?;
          final fListType = fBlock['list_type'] as String?;
          final fAlignment = fBlock['alignment'] is String
              ? fBlock['alignment'] as String
              : null;
          final fRuns = (fBlock['runs'] as List<dynamic>?) ?? [];

          final runs = fRuns.map((r) {
            final rm = r as Map<String, dynamic>;
            return DocRun.fromJson(rm);
          }).toList();

          final blockPlain = runs.map((r) => r.text).join();
          if (blockPlain.isEmpty) continue;

          // Find this block's position within chunkText
          int blockChunkOffset = fmtCursor;
          final idx = chunkText.indexOf(blockPlain, fmtCursor);
          if (idx >= 0) {
            blockChunkOffset = idx;
            fmtCursor = idx + blockPlain.length;
          } else {
            fmtCursor = (fmtCursor + blockPlain.length).clamp(0, chunkText.length);
          }

          final docOffset = chunkTextOffset + blockChunkOffset;
          final bid = 'b_$blockIndex';
          blockIndex++;

          DocBlockType btype;
          switch (fType) {
            case 'heading':
              btype = DocBlockType.heading;
            case 'list_item':
              btype = DocBlockType.listItem;
            default:
              btype = DocBlockType.paragraph;
          }

          blocks.add(DocBlock(
            blockId: bid,
            type: btype,
            level: fLevel,
            listType: fListType,
            alignment: fAlignment,
            runs: runs,
            textOffset: docOffset,
            textLength: blockPlain.length,
          ));
        }
      } else {
        // Plain text fallback: split on double newlines into paragraph blocks
        final paragraphs = chunkText.split(RegExp(r'\n\s*\n'));
        int paraCursor = 0;

        for (final para in paragraphs) {
          final trimmed = para.trim();
          if (trimmed.isEmpty) continue;

          // Find paragraph position in chunkText
          final paraIdx = chunkText.indexOf(trimmed, paraCursor);
          final paraChunkOffset = paraIdx >= 0 ? paraIdx : paraCursor;
          paraCursor = paraChunkOffset + trimmed.length;

          final docOffset = chunkTextOffset + paraChunkOffset;
          final bid = 'b_$blockIndex';
          blockIndex++;

          blocks.add(DocBlock(
            blockId: bid,
            type: DocBlockType.paragraph,
            runs: [DocRun(text: trimmed)],
            textOffset: docOffset,
            textLength: trimmed.length,
          ));
        }
      }

      // ── Build plain text (document-level) ──
      if (docCharCursor > 0) {
        // Separator between chunks for continuous plainText
        plainTextBuf.write('\n\n');
        docCharCursor += 2;
      }
      plainTextBuf.write(chunkText);

      // ── Chunk map ──
      chunkMapEntries.add(ChunkRef(
        chunkId: chunkId,
        chunkIndex: chunkIndex,
        textOffset: chunkTextOffset,
        textLength: chunkText.length,
      ));

      // ── Lift sentence boundaries to document-level ──
      if (sentBounds != null) {
        for (final sb in sentBounds) {
          final sList = sb as List<dynamic>;
          final chunkStart = (sList[0] as num).toInt();
          final chunkEnd = (sList[1] as num).toInt();
          final docStart = chunkTextOffset + chunkStart;
          final docEnd = chunkTextOffset + chunkEnd;

          // Find which blocks this sentence overlaps
          final overlapping = <String>[];
          for (final b in blocks) {
            final bEnd = b.textOffset + b.textLength;
            if (docStart < bEnd && docEnd > b.textOffset) {
              overlapping.add(b.blockId);
            }
          }

          sentences.add(DocSentence(
            index: sentenceGlobalIndex,
            startOffset: docStart,
            endOffset: docEnd,
            blockIds: overlapping,
          ));
          sentenceGlobalIndex++;
        }
      }

      docCharCursor = chunkTextOffset + chunkText.length;
    }

    // Blank DOCX guarantee: a newly-created DOCX (POST /documents/blank/)
    // persists one empty paragraph block, but the filters above drop empty
    // runs / empty trimmed paragraphs. Without a synthesized block,
    // `blocks.isEmpty` would be true and the player would fall through to
    // the legacy InlineChunkEditor path.
    if (blocks.isEmpty && sourceType?.toLowerCase() == 'docx') {
      blocks.add(const DocBlock(
        blockId: 'b_0',
        type: DocBlockType.paragraph,
        runs: [DocRun(text: '')],
        textOffset: 0,
        textLength: 0,
      ));
    }

    return PsittaDocument(
      id: documentId,
      title: title,
      blocks: blocks,
      plainText: plainTextBuf.toString(),
      sentences: sentences,
      chunkMap: chunkMapEntries,
      chunkPositions: chunkPositions,
      sourceType: sourceType,
    );
  }

  /// Flatten a [PsittaDocument] into the canonical block-dict list used by
  /// the unified-editor Delta builder. Each block dict has the same shape
  /// the save-path consumes (`{type, level?, runs:[{text, bold?, italic?,
  /// underline?, font_size?}]}`), so a load → edit → save round-trip is
  /// byte-identical when the user makes no changes.
  static List<Map<String, dynamic>> flatBlockDicts(PsittaDocument doc) {
    final out = <Map<String, dynamic>>[];
    for (final block in doc.blocks) {
      final runs = <Map<String, dynamic>>[];
      for (final run in block.runs) {
        if (run.text.isEmpty) continue;
        final entry = <String, dynamic>{'text': run.text};
        if (run.bold) entry['bold'] = true;
        if (run.italic) entry['italic'] = true;
        if (run.underline) entry['underline'] = true;
        if (run.strike) entry['strike'] = true;
        if (run.fontSize != null) entry['font_size'] = run.fontSize;
        if (run.color != null) entry['color'] = run.color;
        if (run.fontFamily != null) entry['font_family'] = run.fontFamily;
        runs.add(entry);
      }
      if (runs.isEmpty) {
        runs.add(<String, dynamic>{'text': ''});
      }
      final dict = <String, dynamic>{
        'type': _blockTypeToString(block.type),
        'runs': runs,
      };
      if (block.level != null) dict['level'] = block.level;
      if (block.listType != null) dict['list_type'] = block.listType;
      if (block.alignment != null) dict['alignment'] = block.alignment;
      out.add(dict);
    }
    return out;
  }

  static String _blockTypeToString(DocBlockType type) {
    switch (type) {
      case DocBlockType.heading:
        return 'heading';
      case DocBlockType.listItem:
        return 'list_item';
      case DocBlockType.paragraph:
        return 'paragraph';
    }
  }
}
