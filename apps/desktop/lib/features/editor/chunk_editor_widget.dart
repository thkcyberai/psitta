import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/text_sanitizer.dart';
import 'chunk_editor_provider.dart';

class ChunkEditorWidget extends ConsumerStatefulWidget {
  const ChunkEditorWidget({
    super.key,
    required this.documentId,
    required this.chunkId,
    required this.initialText,
    required this.voiceId,
    this.speed = 1.0,
    this.onSaved,
  });

  final String documentId;
  final String chunkId;
  final String initialText;
  final String voiceId;
  final double speed;
  final VoidCallback? onSaved;

  @override
  ConsumerState<ChunkEditorWidget> createState() => _ChunkEditorWidgetState();
}

class _ChunkEditorWidgetState extends ConsumerState<ChunkEditorWidget> {
  late QuillController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final doc = Document()..insert(0, widget.initialText);
    _controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _plainText {
    return sanitizeForTts(_controller.document.toPlainText());
  }

  Future<void> _onSave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Audio'),
        content: const Text(
          'Saving this change will regenerate the audio for this chunk, '
          'which will use TTS credits. You will need to replay from the '
          'beginning of this chunk to hear the updated audio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final notifier = ref.read(chunkEditorProvider.notifier);
    final success = await notifier.saveChunkText(
      documentId: widget.documentId,
      chunkId: widget.chunkId,
      plainText: _plainText,
    );
    if (success && mounted) {
      widget.onSaved?.call();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(chunkEditorProvider);

    final isLoading = state.isSaving;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // ── Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Edit Chunk',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: cs.onSurface, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                  onPressed:
                      isLoading ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // ── Quill toolbar
          QuillSimpleToolbar(
            controller: _controller,
            configurations: QuillSimpleToolbarConfigurations(
              showBoldButton: false,
              showItalicButton: false,
              showSmallButton: false,
              showUnderLineButton: false,
              showStrikeThrough: false,
              showInlineCode: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              showListNumbers: false,
              showListBullets: false,
              showListCheck: false,
              showCodeBlock: false,
              showQuote: false,
              showIndent: false,
              showLink: false,
              showUndo: true,
              showRedo: true,
              showFontSize: false,
              showHeaderStyle: false,
              showAlignmentButtons: false,
              showDirection: false,
              showSearchButton: false,
              showSubscript: false,
              showSuperscript: false,
              showClipboardCut: false,
              showClipboardCopy: false,
              showClipboardPaste: false,
              toolbarIconAlignment: WrapAlignment.start,
              toolbarSectionSpacing: 4,
              color: cs.surface,
              buttonOptions: QuillSimpleToolbarButtonOptions(
                base: QuillToolbarBaseButtonOptions(
                  iconTheme: QuillIconTheme(
                    iconButtonSelectedData: IconButtonData(
                      style: IconButton.styleFrom(
                        backgroundColor: cs.primaryContainer,
                        foregroundColor: cs.onPrimaryContainer,
                      ),
                    ),
                    iconButtonUnselectedData: IconButtonData(
                      style: IconButton.styleFrom(
                        foregroundColor: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // ── Editor
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: QuillEditor.basic(
                controller: _controller,
                focusNode: _focusNode,
                configurations: QuillEditorConfigurations(
                  placeholder: 'Edit chunk text here...',
                  expands: true,
                  padding: EdgeInsets.zero,
                  customStyles: DefaultStyles(
                    paragraph: DefaultTextBlockStyle(
                      Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: cs.onSurface, height: 1.6),
                      HorizontalSpacing.zero,
                      VerticalSpacing.zero,
                      VerticalSpacing.zero,
                      null,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Status message
          if (state.error != null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(state.error!,
                  style: TextStyle(color: cs.error, fontSize: 12)),
            ),
          if (isLoading)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: cs.primary),
                ),
                const SizedBox(width: 8),
                Text('Saving changes...',
                    style: TextStyle(color: cs.primary, fontSize: 12)),
              ]),
            ),

          // ── Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: isLoading ? null : _onSave,
                    icon: isLoading
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: cs.onPrimary),
                          )
                        : const Icon(Icons.save, size: 16),
                    label: Text(
                        isLoading ? 'Saving...' : 'Save & Update Audio'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
