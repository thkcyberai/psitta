import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  }) async {
    state = state.copyWith(isSaving: true, error: null, successMessage: null);
    debugPrint(
        '[ChunkEditorNotifier.saveChunkTexts] documentId=$documentId count=${chunkTexts.length}');

    try {
      for (final entry in chunkTexts.entries) {
        debugPrint(
            '[ChunkEditorNotifier.saveChunkTexts] -> chunk_id=${entry.key} text=${entry.value}');
        await _repository.updateChunkText(
          documentId: documentId,
          chunkId: entry.key,
          text: entry.value,
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

  void clearStatus() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

final chunkEditorProvider =
    StateNotifierProvider<ChunkEditorNotifier, ChunkEditorState>((ref) {
  return ChunkEditorNotifier(ref.watch(documentEditorRepositoryProvider));
});
