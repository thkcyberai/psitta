import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'document_editor_repository.dart';

class ChunkEditorState {
  const ChunkEditorState({
    this.isSaving = false,
    this.isResynthesizing = false,
    this.error,
    this.successMessage,
    this.editedChunkIds = const {},
  });

  final bool isSaving;
  final bool isResynthesizing;
  final String? error;
  final String? successMessage;
  final Set<String> editedChunkIds;

  ChunkEditorState copyWith({
    bool? isSaving,
    bool? isResynthesizing,
    String? error,
    String? successMessage,
    Set<String>? editedChunkIds,
  }) =>
      ChunkEditorState(
        isSaving: isSaving ?? this.isSaving,
        isResynthesizing: isResynthesizing ?? this.isResynthesizing,
        error: error,
        successMessage: successMessage,
        editedChunkIds: editedChunkIds ?? this.editedChunkIds,
      );
}

class ChunkEditorNotifier extends StateNotifier<ChunkEditorState> {
  ChunkEditorNotifier(this._repository) : super(const ChunkEditorState());

  final DocumentEditorRepository _repository;

  Future<bool> saveAndResynthesize({
    required String documentId,
    required String chunkId,
    required String plainText,
    required String voiceId,
    double speed = 1.0,
  }) async {
    state = state.copyWith(isSaving: true, error: null, successMessage: null);
    try {
      // 1. Patch text
      await _repository.updateChunkText(
        documentId: documentId,
        chunkId: chunkId,
        text: plainText,
      );

      state = state.copyWith(isSaving: false, isResynthesizing: true);

      // 2. Trigger re-synthesis (invalidates cache)
      await _repository.resynthesizeChunk(
        documentId: documentId,
        chunkId: chunkId,
        voiceId: voiceId,
        speed: speed,
      );

      final updated = Set<String>.from(state.editedChunkIds)..add(chunkId);
      state = state.copyWith(
        isResynthesizing: false,
        successMessage: 'Chunk updated and re-synthesized.',
        editedChunkIds: updated,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        isResynthesizing: false,
        error: 'Failed to save: $e',
      );
      return false;
    }
  }

  void clearStatus() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

final chunkEditorProvider =
    StateNotifierProvider<ChunkEditorNotifier, ChunkEditorState>((ref) {
  return ChunkEditorNotifier(ref.watch(documentEditorRepositoryProvider));
});
