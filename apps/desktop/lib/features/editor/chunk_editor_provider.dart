import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../player/chunk_slicer.dart';
import 'document_editor_repository.dart';

class ChunkEditorState {
  const ChunkEditorState({
    this.isSaving = false,
    this.error,
    this.successMessage,
    this.editedChunkIds = const {},
  });

  final bool isSaving;
  final String? error;
  final String? successMessage;
  final Set<String> editedChunkIds;

  ChunkEditorState copyWith({
    bool? isSaving,
    String? error,
    String? successMessage,
    Set<String>? editedChunkIds,
  }) =>
      ChunkEditorState(
        isSaving: isSaving ?? this.isSaving,
        error: error,
        successMessage: successMessage,
        editedChunkIds: editedChunkIds ?? this.editedChunkIds,
      );
}

class ChunkEditorNotifier extends StateNotifier<ChunkEditorState> {
  ChunkEditorNotifier(this._repository) : super(const ChunkEditorState());

  final DocumentEditorRepository _repository;

  /// Save edited chunk text via PATCH.
  /// The PATCH endpoint invalidates all backend audio/alignment caches.
  /// The caller is responsible for invalidating Flutter-side caches and
  /// Riverpod providers so the alignment provider re-fetches (triggering
  /// fresh TTS synthesis — the same path as first-time playback).
  Future<bool> saveChunkText({
    required String documentId,
    required String chunkId,
    required String plainText,
  }) async {
    state = state.copyWith(isSaving: true, error: null, successMessage: null);

    try {
      await _repository.updateChunkText(
        documentId: documentId,
        chunkId: chunkId,
        text: plainText,
      );
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to save: $e',
      );
      return false;
    }

    final updated = Set<String>.from(state.editedChunkIds)..add(chunkId);
    state = state.copyWith(
      isSaving: false,
      successMessage: 'Chunk saved. Audio will re-synthesize automatically.',
      editedChunkIds: updated,
    );
    return true;
  }

  Future<bool> saveChunkTexts({
    required String documentId,
    required Map<String, String> chunkTexts,
    Map<String, List<Map<String, dynamic>>>? chunkFormatted,
  }) async {
    state = state.copyWith(isSaving: true, error: null, successMessage: null);
    debugPrint(
        '[ChunkEditorNotifier.saveChunkTexts] documentId=$documentId '
        'count=${chunkTexts.length} fmt_count=${chunkFormatted?.length ?? 0}');

    try {
      for (final entry in chunkTexts.entries) {
        final fmt = chunkFormatted?[entry.key];
        debugPrint(
            '[ChunkEditorNotifier.saveChunkTexts] -> chunk_id=${entry.key} '
            'text.len=${entry.value.length} fmt.blocks=${fmt?.length ?? 0}');
        await _repository.updateChunkText(
          documentId: documentId,
          chunkId: entry.key,
          text: entry.value,
          formattedContent: fmt,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to save: $e',
      );
      return false;
    }

    final updated = Set<String>.from(state.editedChunkIds)
      ..addAll(chunkTexts.keys);
    state = state.copyWith(
      isSaving: false,
      successMessage: 'Document saved. Audio will re-synthesize automatically.',
      editedChunkIds: updated,
    );
    return true;
  }

  /// M13.1b — full-document unified save orchestrator.
  ///
  /// Fans out per-chunk UPDATE / INSERT / DELETE operations followed by
  /// a final PATCH /documents/{id} that persists the authoritative
  /// `chunk_positions` and triggers a server-side sequence_index
  /// reindex inside one DB transaction.
  ///
  /// Order of operations:
  ///   Phase A: UPDATEs (safe — no structural change).
  ///   Phase B: INSERTs at temp sequence_index = 10 000 + i to avoid
  ///            colliding with the UNIQUE (document_id, sequence_index)
  ///            constraint. Captures the new chunk_ids returned by the
  ///            backend for the subsequent position-map build.
  ///   Phase C: DELETEs. Backend invalidates audio cache + removes row;
  ///            FK CASCADE purges audio_segments.
  ///   Phase D: PATCH /documents/{id} with `chunk_positions` (list of
  ///            {chunk_id, start_offset, end_offset} in final order) and
  ///            `chunk_count`. Backend reindexes sequence_index
  ///            atomically.
  ///
  /// Error handling: partial failure → log, return false. The caller is
  /// expected to preserve in-memory state so the user can retry. Since
  /// [assignChunkIdsByContent] is content-hash based, a retry walks
  /// from the current DB state and produces a valid reconciling
  /// assignment (idempotent under partial failures).
  ///
  /// Returns true on full success; false on any per-call failure.
  Future<bool> saveDocumentChunks({
    required String documentId,
    required List<ChunkAssignment> assignments,
  }) async {
    state = state.copyWith(isSaving: true, error: null, successMessage: null);

    final updates = assignments
        .where((a) => a.action == ChunkAction.update)
        .toList(growable: false);
    final inserts = assignments
        .where((a) => a.action == ChunkAction.insert)
        .toList(growable: false);
    final deletes = assignments
        .where((a) => a.action == ChunkAction.delete)
        .toList(growable: false);
    final keeps =
        assignments.where((a) => a.action == ChunkAction.keep).length;

    debugPrint(
        '[saveDocumentChunks] doc=$documentId keeps=$keeps updates=${updates.length} '
        'inserts=${inserts.length} deletes=${deletes.length}');

    // ── Phase A: UPDATEs ───────────────────────────────────────────
    try {
      for (final a in updates) {
        final s = a.slicedChunk!;
        await _repository.updateChunkText(
          documentId: documentId,
          chunkId: a.chunkId!,
          text: s.plainText,
          formattedContent: s.blockDicts,
        );
      }
    } catch (e, st) {
      debugPrint('[saveDocumentChunks] UPDATE phase failed: $e\n$st');
      state = state.copyWith(
        isSaving: false,
        error: 'Save failed while updating chunks: $e',
      );
      return false;
    }

    // ── Phase B: INSERTs (at temp sequence indices) ────────────────
    // The returned chunk_ids populate [insertedIds] in the same order
    // as the inserts list; Phase D then stitches them back into the
    // authoritative position map.
    final insertedIds = <String>[];
    try {
      for (var i = 0; i < inserts.length; i++) {
        final s = inserts[i].slicedChunk!;
        final response = await _repository.insertChunk(
          documentId: documentId,
          sequenceIndex: 10000 + i,
          text: s.plainText,
          formattedContent: s.blockDicts,
        );
        insertedIds.add((response['id'] ?? '').toString());
      }
    } catch (e, st) {
      debugPrint('[saveDocumentChunks] INSERT phase failed: $e\n$st');
      state = state.copyWith(
        isSaving: false,
        error: 'Save failed while inserting chunks: $e',
      );
      return false;
    }

    // ── Phase C: DELETEs ───────────────────────────────────────────
    try {
      for (final a in deletes) {
        await _repository.deleteChunk(
          documentId: documentId,
          chunkId: a.chunkId!,
        );
      }
    } catch (e, st) {
      debugPrint('[saveDocumentChunks] DELETE phase failed: $e\n$st');
      state = state.copyWith(
        isSaving: false,
        error: 'Save failed while deleting chunks: $e',
      );
      return false;
    }

    // ── Phase D: Position map + reindex ────────────────────────────
    // Stitch real chunk_ids into insert assignments (in original
    // order) so [computePositionMap] sees the authoritative ordering.
    final finalInOrder = <ChunkAssignment>[];
    var insertCursor = 0;
    for (final a in assignments) {
      if (a.action == ChunkAction.delete) continue;
      if (a.action == ChunkAction.insert) {
        finalInOrder.add(a.copyWith(chunkId: insertedIds[insertCursor]));
        insertCursor++;
      } else {
        finalInOrder.add(a);
      }
    }
    final positionMap = computePositionMap(finalInOrder);

    try {
      await _repository.updateDocument(
        documentId: documentId,
        chunkPositions: positionMap,
        chunkCount: positionMap.length,
      );
    } catch (e, st) {
      debugPrint('[saveDocumentChunks] PATCH document failed: $e\n$st');
      state = state.copyWith(
        isSaving: false,
        error: 'Save failed while finalizing document: $e',
      );
      return false;
    }

    final nonDeleteCount = assignments.length - deletes.length;
    final preservedRatio =
        nonDeleteCount == 0 ? 0.0 : keeps / nonDeleteCount;
    debugPrint(
        '[saveDocumentChunks] success chunks_preserved_ratio='
        '${preservedRatio.toStringAsFixed(2)} '
        '($keeps/$nonDeleteCount)');

    state = state.copyWith(
      isSaving: false,
      successMessage:
          'Document saved. Audio will re-synthesize automatically.',
    );
    return true;
  }

  void clearStatus() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

final chunkEditorProvider =
    StateNotifierProvider<ChunkEditorNotifier, ChunkEditorState>((ref) {
  return ChunkEditorNotifier(ref.watch(documentEditorRepositoryProvider));
});
