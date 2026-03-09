import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/audio_service.dart';
import 'document_editor_repository.dart';
import 'chunk_editor_widget.dart';
import 'chunk_editor_provider.dart';

/// Provider for fetching all chunks of a document.
final documentChunksProvider = FutureProvider.autoDispose.family<
    List<Map<String, dynamic>>, String>((ref, documentId) async {
  final repo = ref.watch(documentEditorRepositoryProvider);
  return repo.fetchChunks(documentId: documentId);
});

class DocumentEditorScreen extends ConsumerWidget {
  const DocumentEditorScreen({
    super.key,
    required this.documentId,
    this.documentTitle,
  });

  final String documentId;
  final String? documentTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final chunksAsync = ref.watch(documentChunksProvider(documentId));
    final editorState = ref.watch(chunkEditorProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Document',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600, color: cs.onSurface)),
            if (documentTitle != null)
              Text(documentTitle!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
        leading: BackButton(color: cs.onSurfaceVariant),
        actions: [
          if (editorState.editedChunkIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                label: Text(
                  '${editorState.editedChunkIds.length} edited',
                  style: TextStyle(fontSize: 11, color: cs.onTertiary),
                ),
                backgroundColor: cs.tertiary,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
      body: chunksAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: cs.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: cs.error, size: 40),
              const SizedBox(height: 12),
              Text('Failed to load chunks',
                  style: TextStyle(color: cs.error)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.invalidate(documentChunksProvider(documentId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (chunks) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: chunks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final chunk = chunks[index];
            final chunkId = chunk['id'] as String;
            final text = chunk['text_content'] as String? ?? '';
            final seqIndex = chunk['sequence_index'] as int? ?? index;
            final isEdited = chunk['is_edited'] as bool? ?? false;
            final wasEdited = editorState.editedChunkIds.contains(chunkId);

            return Card(
              elevation: 0,
              color: (isEdited || wasEdited)
                  ? cs.tertiaryContainer.withOpacity(0.3)
                  : cs.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: (isEdited || wasEdited)
                      ? cs.tertiary.withOpacity(0.4)
                      : Colors.transparent,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('${seqIndex + 1}',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onPrimaryContainer)),
                        ),
                        const SizedBox(width: 8),
                        if (isEdited || wasEdited)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.tertiaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Edited',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: cs.onTertiaryContainer)),
                          ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.edit_outlined,
                              size: 16, color: cs.primary),
                          tooltip: 'Edit this chunk',
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              _openEditor(context, ref, chunkId, text),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      text.length > 200
                          ? '${text.substring(0, 200)}...'
                          : text,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openEditor(
      BuildContext context, WidgetRef ref, String chunkId, String chunkText) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChunkEditorWidget(
        documentId: documentId,
        chunkId: chunkId,
        initialText: chunkText,
        voiceId: 'pNInz6obpgDQGcFmaJgB',
        onSaved: () {
          final audioService = ref.read(audioServiceProvider);
          audioService.invalidateChunkCache(chunkId);
          ref.invalidate(documentChunksProvider(documentId));
        },
      ),
    );
  }
}
