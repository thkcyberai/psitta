import 'package:flutter/material.dart';

import '../../../core/utils/text_sanitizer.dart';

/// Inline text editor that stays inside the DOCX document sheet.
///
/// The field grows with the document so the outer Player scroll view keeps
/// owning document-level scrolling, scrollbar behavior, and mouse interaction.
class InlineChunkEditor extends StatefulWidget {
  const InlineChunkEditor({
    super.key,
    required this.initialText,
    required this.controller,
    required this.focusNode,
    required this.onSave,
    required this.onDiscard,
    this.isSaving = false,
    this.error,
  });

  final String initialText;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSave;
  final VoidCallback onDiscard;
  final bool isSaving;
  final String? error;

  @override
  State<InlineChunkEditor> createState() => _InlineChunkEditorState();
}

class _InlineChunkEditorState extends State<InlineChunkEditor> {
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final changed = sanitizeForTts(widget.controller.text) !=
        sanitizeForTts(widget.initialText);
    if (changed != _hasChanges) {
      setState(() => _hasChanges = changed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Stack(
      children: [
        // ── Editable text field ──────────────────────────────────────
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          maxLines: null,
          minLines: 18,
          scrollPhysics: const NeverScrollableScrollPhysics(),
          enabled: !widget.isSaving,
          mouseCursor: SystemMouseCursors.text,
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.8,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
            contentPadding: EdgeInsets.only(
              bottom: _hasChanges ? 72 : 0,
            ),
          ),
        ),

        // ── Floating save/discard bar ────────────────────────────────
        if (_hasChanges)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                  top: BorderSide(color: cs.outlineVariant),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        widget.error!,
                        style: TextStyle(color: cs.error, fontSize: 12),
                      ),
                    ),
                  Row(
                    children: [
                      if (widget.isSaving) ...[
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Saving...',
                          style: TextStyle(color: cs.primary, fontSize: 12),
                        ),
                        const Spacer(),
                      ] else ...[
                        const Spacer(),
                        OutlinedButton(
                          onPressed: widget.onDiscard,
                          child: const Text('Discard'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: widget.onSave,
                          icon: const Icon(Icons.save, size: 16),
                          label: const Text('Save & Update Audio'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
