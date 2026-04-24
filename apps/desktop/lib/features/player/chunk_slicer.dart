/// Fixed-window chunk slicer for the M13 unified DOCX editor.
///
/// The unified editor holds the whole document inside a single Quill
/// Document. At save time the flat block-dict list is mechanically
/// partitioned into ~500-word chunks so the existing per-chunk backend
/// storage and TTS synthesis pipeline continue to work unchanged.
///
/// M13.1a ships this slicer with a simple forward-greedy packer: fill the
/// current chunk until it crosses the target word count, then cut. M13.1b
/// will add chunk-preservation (content-hash + positional matching against
/// the pre-edit snapshot) so unchanged chunks keep their TTS audio cache.
library;

/// Target words per sliced chunk. ~500 words = ~3000 characters ≈ 2
/// minutes of synthesized speech, which matches the existing backend
/// ingest-time chunking cadence closely enough for TTS cache behavior.
const int kTargetChunkWords = 500;

/// A single chunk produced by [sliceBlocksIntoChunks].
///
/// Contains the block-dict slice (what the backend will store in
/// `formatted_content`), the concatenated plain text (what the backend
/// will store in `text_content`), and the word count used by the slicer
/// (useful for diagnostics and the M13.1b diff check).
class SlicedChunk {
  const SlicedChunk({
    required this.blockDicts,
    required this.plainText,
    required this.wordCount,
  });

  final List<Map<String, dynamic>> blockDicts;
  final String plainText;
  final int wordCount;
}

/// Document-level character offset range for a single chunk. Persisted
/// on `documents.chunk_positions` (JSONB) by the M13.1b save path and
/// read back by [DocumentAssembler] on subsequent loads so sentence
/// highlighting, navigation, and find-in-doc don't have to recompute
/// the offsets from scratch.
///
/// Offsets are character positions in the concatenated plain text
/// where chunks are joined by `"\n\n"`. [endOffset] is exclusive.
class ChunkPositionRange {
  const ChunkPositionRange({
    required this.chunkId,
    required this.startOffset,
    required this.endOffset,
  });

  factory ChunkPositionRange.fromJson(Map<String, dynamic> j) =>
      ChunkPositionRange(
        chunkId: (j['chunk_id'] ?? '') as String,
        startOffset: (j['start_offset'] as num).toInt(),
        endOffset: (j['end_offset'] as num).toInt(),
      );

  final String chunkId;
  final int startOffset;
  final int endOffset;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'chunk_id': chunkId,
        'start_offset': startOffset,
        'end_offset': endOffset,
      };
}

/// What the save path should do with a sliced chunk. Paired with the
/// chunk_id of the pre-edit chunk it matched (or null for inserts /
/// deletes' partner missing from the new sliced list).
enum ChunkAction { keep, update, insert, delete }

/// Result of [assignChunkIdsByContent] — one entry per (slicedChunk |
/// preEdit-chunk-being-deleted). The orchestrator consumes these in
/// action-order (updates first, inserts next, deletes last) to minimize
/// risk of the backend's UNIQUE (document_id, sequence_index)
/// constraint colliding during the fan-out.
class ChunkAssignment {
  const ChunkAssignment({
    required this.action,
    this.chunkId,
    this.slicedChunk,
    this.sequenceIndex,
  });

  final ChunkAction action;

  /// Pre-edit chunk id for [ChunkAction.keep], [ChunkAction.update],
  /// [ChunkAction.delete]. Null for [ChunkAction.insert] until the
  /// backend returns the new id on POST /chunks.
  final String? chunkId;

  /// The sliced chunk's payload — null only for DELETE entries (the
  /// pre-edit chunk is leaving the document so there is no new slice).
  final SlicedChunk? slicedChunk;

  /// Final desired sequence index in the post-save document. Null for
  /// DELETE entries. The backend's PATCH /documents/{id} reindex uses
  /// the ordering of [computePositionMap] output rather than this
  /// field, so [sequenceIndex] is an informational hint.
  final int? sequenceIndex;

  ChunkAssignment copyWith({
    ChunkAction? action,
    String? chunkId,
    SlicedChunk? slicedChunk,
    int? sequenceIndex,
  }) =>
      ChunkAssignment(
        action: action ?? this.action,
        chunkId: chunkId ?? this.chunkId,
        slicedChunk: slicedChunk ?? this.slicedChunk,
        sequenceIndex: sequenceIndex ?? this.sequenceIndex,
      );
}

String _normalizeForHash(String text) {
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Match post-edit sliced chunks to pre-edit chunk IDs by normalized
/// text equality. Preserves the TTS audio cache for any chunk whose
/// text round-trips unchanged.
///
/// Algorithm:
/// 1. Build a candidate map from normalized pre-edit text → list of
///    `(chunk_id, pre-edit sequence index)`.
/// 2. For each sliced chunk in order, look up unused candidates and
///    pick the one with the smallest `|preIndex - currentIndex|` (the
///    content-preserving positional tiebreaker).
/// 3. Any sliced chunk with no hash match AND whose same-position
///    pre-edit chunk is also unmatched degrades to [ChunkAction.update]
///    on the same-position chunk id — preserves the chunk slot (and
///    therefore its audit-log lineage) when the user made a small edit
///    that flipped the hash but kept the structure.
/// 4. Sliced chunks with no match: [ChunkAction.insert].
/// 5. Pre-edit chunk ids left unmatched after the walk: [ChunkAction.delete].
///
/// Returns the assignments in the order the orchestrator should emit
/// them: updates (which includes keeps) + inserts in new-document
/// order, followed by deletes.
List<ChunkAssignment> assignChunkIdsByContent(
  List<SlicedChunk> sliced,
  List<String> preEditChunkIds,
  Map<String, String> preEditChunkTextById,
) {
  // Step 1 — index pre-edit chunks by normalized text.
  final byHash = <String, List<_PreEditCandidate>>{};
  for (var i = 0; i < preEditChunkIds.length; i++) {
    final id = preEditChunkIds[i];
    final hash = _normalizeForHash(preEditChunkTextById[id] ?? '');
    byHash.putIfAbsent(hash, () => <_PreEditCandidate>[])
        .add(_PreEditCandidate(id, i));
  }
  final consumed = <String>{};

  // Step 2 & 3 — walk sliced chunks in order.
  final assignments = <ChunkAssignment>[];
  for (var i = 0; i < sliced.length; i++) {
    final s = sliced[i];
    final hash = _normalizeForHash(s.plainText);
    final candidates = byHash[hash];
    _PreEditCandidate? picked;
    if (candidates != null) {
      _PreEditCandidate? best;
      var bestDelta = 1 << 31;
      for (final c in candidates) {
        if (consumed.contains(c.id)) continue;
        final delta = (c.preIndex - i).abs();
        if (delta < bestDelta) {
          best = c;
          bestDelta = delta;
        }
      }
      picked = best;
    }
    if (picked != null) {
      consumed.add(picked.id);
      assignments.add(ChunkAssignment(
        action: ChunkAction.keep,
        chunkId: picked.id,
        slicedChunk: s,
        sequenceIndex: i,
      ));
      continue;
    }

    // Positional fallback: if the same-position pre-edit chunk is also
    // unmatched, the user likely edited in place — treat as UPDATE on
    // the existing chunk id so the audit trail is preserved.
    if (i < preEditChunkIds.length) {
      final posId = preEditChunkIds[i];
      if (!consumed.contains(posId)) {
        consumed.add(posId);
        assignments.add(ChunkAssignment(
          action: ChunkAction.update,
          chunkId: posId,
          slicedChunk: s,
          sequenceIndex: i,
        ));
        continue;
      }
    }

    // No match — new content.
    assignments.add(ChunkAssignment(
      action: ChunkAction.insert,
      slicedChunk: s,
      sequenceIndex: i,
    ));
  }

  // Step 5 — anything the walk didn't consume is a DELETE.
  for (final id in preEditChunkIds) {
    if (!consumed.contains(id)) {
      assignments.add(ChunkAssignment(
        action: ChunkAction.delete,
        chunkId: id,
      ));
    }
  }
  return assignments;
}

class _PreEditCandidate {
  const _PreEditCandidate(this.id, this.preIndex);
  final String id;
  final int preIndex;
}

/// Compute the authoritative chunk-position map from the final sliced
/// order. Input is the list of non-DELETE assignments in final
/// document order — the orchestrator is responsible for filling in
/// [ChunkAssignment.chunkId] with real ids for newly-inserted chunks
/// before calling this helper.
///
/// Offsets are character positions in the concatenated plain text
/// where chunks are joined by `"\n\n"`. [endOffset] is exclusive; the
/// gap between one chunk's [endOffset] and the next's [startOffset]
/// equals 2 (the separator length).
List<ChunkPositionRange> computePositionMap(
  List<ChunkAssignment> nonDeleteInOrder,
) {
  final out = <ChunkPositionRange>[];
  var cursor = 0;
  for (var i = 0; i < nonDeleteInOrder.length; i++) {
    final a = nonDeleteInOrder[i];
    final id = a.chunkId;
    final s = a.slicedChunk;
    if (id == null || s == null) continue;
    if (i > 0) cursor += 2; // "\n\n" separator
    final start = cursor;
    final end = start + s.plainText.length;
    out.add(ChunkPositionRange(
      chunkId: id,
      startOffset: start,
      endOffset: end,
    ));
    cursor = end;
  }
  return out;
}

/// Partition a flat block-dict list into ~[targetWords] chunks.
///
/// Cuts are block-aligned: a block is never split across chunks. The
/// final chunk may be under-full (typical). An empty document yields one
/// empty paragraph chunk so the backend's non-null text_content
/// invariant holds.
List<SlicedChunk> sliceBlocksIntoChunks(
  List<Map<String, dynamic>> blockDicts, {
  int targetWords = kTargetChunkWords,
}) {
  final chunks = <SlicedChunk>[];
  var currentBlocks = <Map<String, dynamic>>[];
  var currentWords = 0;
  final currentText = StringBuffer();

  for (final block in blockDicts) {
    final runs = (block['runs'] as List?) ?? const [];
    final blockText = runs
        .map((r) => ((r as Map)['text'] as String?) ?? '')
        .join();
    final blockWords = blockText
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;

    currentBlocks.add(block);
    currentWords += blockWords;
    if (currentText.isNotEmpty) currentText.write('\n\n');
    currentText.write(blockText);

    if (currentWords >= targetWords) {
      chunks.add(SlicedChunk(
        blockDicts: List<Map<String, dynamic>>.from(currentBlocks),
        plainText: currentText.toString(),
        wordCount: currentWords,
      ));
      currentBlocks = <Map<String, dynamic>>[];
      currentWords = 0;
      currentText.clear();
    }
  }

  if (currentBlocks.isNotEmpty) {
    chunks.add(SlicedChunk(
      blockDicts: currentBlocks,
      plainText: currentText.toString(),
      wordCount: currentWords,
    ));
  }

  // Empty-document guarantee: the backend's document_chunks row was
  // seeded with one empty paragraph, so a save after no edits must still
  // emit one chunk that round-trips to the same shape.
  if (chunks.isEmpty) {
    chunks.add(const SlicedChunk(
      blockDicts: [
        {
          'type': 'paragraph',
          'runs': [
            {'text': ''}
          ]
        }
      ],
      plainText: '',
      wordCount: 0,
    ));
  }

  return chunks;
}
