import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/editor/quill_codec.dart' as qcodec;
import '../../core/theme/psitta_tokens.dart';
import '../../data/models/document_assembler.dart';
import '../../data/models/psitta_document.dart';
import '../../data/providers/providers.dart';
import '../../features/editor/chunk_editor_provider.dart';
import '../player/widgets/document_reading_view.dart';
import 'desk_providers.dart';

/// Center pane for the Writing Desk.
///
/// Read mode: scrollable [DocumentReadingView] of the assembled document.
/// Edit mode: unified [quill.QuillEditor] backed by [deskDocumentProvider].
///
/// Toggle button in the header switches between modes. Switching from edit
/// back to read serialises the Quill Delta via [qcodec] and calls
/// [chunkEditorProvider.saveChunkTexts] before re-entering read mode.
class DeskCenterPane extends ConsumerStatefulWidget {
  const DeskCenterPane({
    super.key,
    required this.documentId,
  });

  final String documentId;

  @override
  ConsumerState<DeskCenterPane> createState() => _DeskCenterPaneState();
}

class _DeskCenterPaneState extends ConsumerState<DeskCenterPane> {
  bool _isEditing = false;
  quill.QuillController? _unifiedController;
  FocusNode? _focusNode;
  bool _isSaving = false;

  @override
  void dispose() {
    _unifiedController?.dispose();
    _focusNode?.dispose();
    super.dispose();
  }

  void _enterEditMode(PsittaDocument doc) {
    _unifiedController?.dispose();
    _focusNode?.dispose();

    final flatBlocks = DocumentAssembler.flatBlockDicts(doc);
    final quillDoc = qcodec.blockDictsToQuillDocument(flatBlocks);
    final controller = quill.QuillController(
      document: quillDoc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    final focusNode = FocusNode(debugLabel: 'desk-unified');

    setState(() {
      _unifiedController = controller;
      _focusNode = focusNode;
      _isEditing = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focusNode.requestFocus();
    });
  }

  Future<void> _saveAndExitEditMode() async {
    final controller = _unifiedController;
    if (controller == null) {
      setState(() => _isEditing = false);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final flatBlocks = qcodec.quillDocumentToBlockDicts(
        controller.document,
        DocBlockType.paragraph,
        null,
      );

      // Distribute serialised blocks back to their original chunks
      // proportionally (by pre-edit formatted_content block count).
      // M13.1b will replace this with content-hash matching; for WD-3
      // the proportional model is correct when the user has not inserted
      // or removed entire paragraphs near chunk boundaries.
      final rawData =
          await ref.read(chunksProvider(widget.documentId).future);
      final chunks = (rawData['chunks'] as List<dynamic>?) ?? [];
      final chunkTexts = <String, String>{};
      final chunkFormatted = <String, List<Map<String, dynamic>>>{};

      if (chunks.isNotEmpty && flatBlocks.isNotEmpty) {
        var blockOffset = 0;
        for (var i = 0; i < chunks.length; i++) {
          final chunk = chunks[i] as Map<String, dynamic>;
          final chunkId = (chunk['id'] ?? '').toString();
          if (chunkId.isEmpty) continue;

          final originalFc =
              chunk['formatted_content'] as List<dynamic>?;
          final originalCount =
              (originalFc?.length ?? 1).clamp(1, flatBlocks.length);
          final remaining = flatBlocks.length - blockOffset;
          final blockCount = (i == chunks.length - 1)
              ? remaining
              : originalCount.clamp(0, remaining);

          final end =
              (blockOffset + blockCount).clamp(0, flatBlocks.length);
          final chunkBlocks = blockOffset < flatBlocks.length
              ? flatBlocks.sublist(blockOffset, end)
              : <Map<String, dynamic>>[];
          blockOffset += blockCount;

          final text = chunkBlocks
              .map((b) =>
                  (b['runs'] as List<dynamic>?)
                      ?.whereType<Map>()
                      .map((r) => (r['text'] ?? '').toString())
                      .join() ??
                  '')
              .join('\n\n');
          chunkTexts[chunkId] = text;
          chunkFormatted[chunkId] = chunkBlocks;
        }
      }

      if (chunkTexts.isNotEmpty) {
        await ref.read(chunkEditorProvider.notifier).saveChunkTexts(
              documentId: widget.documentId,
              chunkTexts: chunkTexts,
              chunkFormatted: chunkFormatted,
            );
        ref.invalidate(deskDocumentProvider(widget.documentId));
      }
    } finally {
      if (mounted) {
        _unifiedController?.dispose();
        _focusNode?.dispose();
        setState(() {
          _unifiedController = null;
          _focusNode = null;
          _isEditing = false;
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final docAsync = ref.watch(deskDocumentProvider(widget.documentId));

    return ColoredBox(
      color: tokens.surface,
      child: Column(
        children: [
          _DeskCenterHeader(
            key: const ValueKey('desk-center-header'),
            isEditing: _isEditing,
            isSaving: _isSaving,
            canEdit: docAsync.hasValue,
            onToggle: () {
              if (_isEditing) {
                _saveAndExitEditMode();
              } else if (docAsync.hasValue) {
                _enterEditMode(docAsync.value!);
              }
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: docAsync.when(
              loading: () => const Center(
                key: ValueKey('desk-center-loading'),
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Failed to load document',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ),
              data: (doc) => _isEditing && _unifiedController != null
                  ? _DeskEditorBody(
                      key: const ValueKey('desk-editor-body'),
                      controller: _unifiedController!,
                      focusNode: _focusNode!,
                    )
                  : SingleChildScrollView(
                      child: DocumentReadingView(
                        key: const ValueKey('desk-reading-body'),
                        document: doc,
                        activeChunkIndex: 0,
                        alignmentPayload: const {},
                        enableContextMenu: false,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _DeskCenterHeader extends StatelessWidget {
  const _DeskCenterHeader({
    super.key,
    required this.isEditing,
    required this.isSaving,
    required this.canEdit,
    required this.onToggle,
  });

  final bool isEditing;
  final bool isSaving;
  final bool canEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isSaving)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              )
            else
              IconButton(
                key: ValueKey(
                    isEditing ? 'desk-toggle-read' : 'desk-toggle-edit'),
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                tooltip: isEditing ? 'Save & read' : 'Edit document',
                icon: Icon(
                  isEditing ? Icons.check_rounded : Icons.edit_outlined,
                  color: isEditing ? scheme.primary : scheme.outline,
                ),
                onPressed: (canEdit || isEditing) ? onToggle : null,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Editor body ───────────────────────────────────────────────────────────────

class _DeskEditorBody extends StatelessWidget {
  const _DeskEditorBody({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  final quill.QuillController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return quill.QuillEditor.basic(
      controller: controller,
      focusNode: focusNode,
      configurations: quill.QuillEditorConfigurations(
        expands: false,
        padding: const EdgeInsets.all(24),
        scrollPhysics: const ClampingScrollPhysics(),
        placeholder: 'Start writing…',
        customStyles: quill.DefaultStyles(
          paragraph: quill.DefaultTextBlockStyle(
            Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: scheme.onSurface,
                  height: 1.6,
                ),
            const quill.HorizontalSpacing(0, 0),
            const quill.VerticalSpacing(0, 8),
            quill.VerticalSpacing.zero,
            null,
          ),
        ),
      ),
    );
  }
}
