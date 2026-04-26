import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../data/models/psitta_document.dart';

class DocxDocumentEditor extends StatefulWidget {
  const DocxDocumentEditor({
    super.key,
    required this.document,
    this.controllers = const {},
    this.focusNodes = const {},
    this.unifiedController,
    this.unifiedFocusNode,
    this.error,
    this.isSaving = false,
    this.onChanged,
    this.onActiveControllerChanged,
  });

  final PsittaDocument document;

  // ── Per-paragraph mode (legacy fallback) ────────────────────────────
  final Map<String, QuillController> controllers;

  /// Long-lived focus nodes keyed by blockId, owned by the parent so
  /// external callers (e.g. find-in-document) can request focus for a
  /// specific block's QuillEditor. Ignored in unified mode.
  final Map<String, FocusNode> focusNodes;

  // ── Unified mode (M13.1a) ───────────────────────────────────────────
  /// When non-null, the widget renders a single Quill editor bound to
  /// this controller instead of one editor per DocBlock. Cursor,
  /// selection, undo/redo, clipboard and keyboard shortcuts all flow
  /// across paragraphs natively.
  final QuillController? unifiedController;

  /// Long-lived focus node for the unified editor.
  final FocusNode? unifiedFocusNode;

  final String? error;
  final bool isSaving;
  final VoidCallback? onChanged;
  final ValueChanged<QuillController>? onActiveControllerChanged;

  @override
  State<DocxDocumentEditor> createState() => _DocxDocumentEditorState();
}

class _DocxDocumentEditorState extends State<DocxDocumentEditor> {
  QuillController? _activeController;
  final Set<QuillController> _listening = {};

  bool get _isUnifiedMode => widget.unifiedController != null;

  @override
  void initState() {
    super.initState();
    if (_isUnifiedMode) {
      _attachUnifiedListener(widget.unifiedController!);
      // Toolbar binds to the unified controller — notify the parent once
      // on first build so the sticky toolbar has a controller to paint.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onActiveControllerChanged?.call(widget.unifiedController!);
      });
    } else {
      _activeController = _firstController;
      _attachListeners();
      if (_activeController != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onActiveControllerChanged?.call(_activeController!);
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant DocxDocumentEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isUnifiedMode) {
      if (oldWidget.unifiedController != widget.unifiedController) {
        _detachListeners();
        _attachUnifiedListener(widget.unifiedController!);
        widget.onActiveControllerChanged?.call(widget.unifiedController!);
      }
      return;
    }
    // Per-paragraph mode: if the active controller was disposed (e.g.
    // edit mode re-entered), fall back to the first available one.
    if (_activeController == null ||
        !widget.controllers.containsValue(_activeController)) {
      _activeController = _firstController;
      if (_activeController != null) {
        widget.onActiveControllerChanged?.call(_activeController!);
      }
    }
    _attachListeners();
  }

  @override
  void dispose() {
    _detachListeners();
    super.dispose();
  }

  void _attachListeners() {
    for (final controller in widget.controllers.values) {
      if (_listening.add(controller)) {
        controller.addListener(_onAnyChange);
      }
    }
  }

  void _attachUnifiedListener(QuillController controller) {
    if (_listening.add(controller)) {
      controller.addListener(_onAnyChange);
    }
  }

  void _detachListeners() {
    for (final controller in _listening) {
      controller.removeListener(_onAnyChange);
    }
    _listening.clear();
  }

  void _onAnyChange() {
    widget.onChanged?.call();
  }

  QuillController? get _firstController {
    if (widget.document.blocks.isEmpty) return null;
    for (final block in widget.document.blocks) {
      final c = widget.controllers[block.blockId];
      if (c != null) return c;
    }
    return null;
  }

  void _onBlockFocused(QuillController controller) {
    if (_activeController != controller) {
      setState(() {
        _activeController = controller;
      });
      widget.onActiveControllerChanged?.call(controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnifiedMode) {
      return _buildUnifiedEditor(context);
    }
    return _buildPerParagraphEditor(context);
  }

  Widget _buildUnifiedEditor(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.unifiedController!;
    final focusNode = widget.unifiedFocusNode;

    final paragraphStyle = theme.textTheme.bodyLarge?.copyWith(
          height: 1.8,
          fontSize: 16,
        ) ??
        const TextStyle(fontSize: 16, height: 1.8);
    final h1Style = theme.textTheme.headlineMedium?.copyWith(height: 1.6) ??
        const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.6);
    final h2Style = theme.textTheme.headlineSmall?.copyWith(height: 1.6) ??
        const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.6);
    final h3Style = theme.textTheme.titleLarge?.copyWith(height: 1.6) ??
        const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.6);
    final listStyle = theme.textTheme.bodyLarge
            ?.copyWith(height: 1.6, fontSize: 16) ??
        const TextStyle(fontSize: 16, height: 1.6);

    final children = <Widget>[];
    if (widget.error != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            widget.error!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ),
      );
    }
    if (widget.isSaving) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Saving document...',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ],
          ),
        ),
      );
    }

    children.add(
      QuillEditor.basic(
        controller: controller,
        focusNode: focusNode,
        configurations: QuillEditorConfigurations(
          expands: false,
          padding: EdgeInsets.zero,
          scrollPhysics: const ClampingScrollPhysics(),
          placeholder: '',
          enableInteractiveSelection: true,
          customStyles: DefaultStyles(
            paragraph: DefaultTextBlockStyle(
              paragraphStyle,
              HorizontalSpacing.zero,
              const VerticalSpacing(0, 8),
              VerticalSpacing.zero,
              null,
            ),
            h1: DefaultTextBlockStyle(
              h1Style,
              HorizontalSpacing.zero,
              const VerticalSpacing(0, 16),
              VerticalSpacing.zero,
              null,
            ),
            h2: DefaultTextBlockStyle(
              h2Style,
              HorizontalSpacing.zero,
              const VerticalSpacing(0, 12),
              VerticalSpacing.zero,
              null,
            ),
            h3: DefaultTextBlockStyle(
              h3Style,
              HorizontalSpacing.zero,
              const VerticalSpacing(0, 12),
              VerticalSpacing.zero,
              null,
            ),
            lists: DefaultListBlockStyle(
              listStyle,
              HorizontalSpacing.zero,
              const VerticalSpacing(0, 8),
              VerticalSpacing.zero,
              null,
              null,
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildPerParagraphEditor(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];

    if (widget.error != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            widget.error!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      );
    }

    if (widget.isSaving) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Saving document...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    for (final block in widget.document.blocks) {
      final controller = widget.controllers[block.blockId];
      final focusNode = widget.focusNodes[block.blockId];
      if (controller == null || focusNode == null) continue;

      children.add(
        Padding(
          padding: EdgeInsets.only(
            bottom: block.type == DocBlockType.heading ? 16 : 8,
          ),
          child: _DocxEditableBlock(
            block: block,
            controller: controller,
            focusNode: focusNode,
            enabled: !widget.isSaving,
            onFocused: () => _onBlockFocused(controller),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// Builds the sticky QuillSimpleToolbar used for DOCX editing.
///
/// Extracted as a standalone builder so player_screen.dart can render it
/// outside the scrollable viewport (keeping it always visible).
Widget buildDocxEditToolbar({
  required QuillController controller,
  required ThemeData theme,
}) {
  return QuillSimpleToolbar(
    controller: controller,
    configurations: QuillSimpleToolbarConfigurations(
      showBoldButton: true,
      showItalicButton: true,
      showSmallButton: false,
      showUnderLineButton: true,
      // M13.4 Ship 1: strike, color, font family, and alignment all
      // round-trip end-to-end (Quill → save → DocBlock → reading view →
      // /export to Word). Background-color (highlight) stays hidden by
      // design — it's out of M13.4 scope and the schema does not carry
      // it. Page break ships in M13.4 Ship 2 as a custom toolbar button;
      // flutter_quill 10.8.4 has no native page-break flag.
      showFontFamily: true,
      showStrikeThrough: true,
      showInlineCode: false,
      showColorButton: true,
      showBackgroundColorButton: false,
      showListNumbers: true,
      showListBullets: true,
      showListCheck: false,
      showCodeBlock: false,
      showQuote: false,
      showIndent: false,
      showLink: false,
      showUndo: true,
      showRedo: true,
      showFontSize: true,
      // M13.1b font-size fix: override Quill's default Small/Large/Huge/Clear
      // dropdown with numeric sizes matching Word/Google Docs convention.
      // Quill applies {"size": <double>} on selection; _quillDocumentToBlockDicts
      // parses via double.tryParse → font_size double → backend stores as JSONB
      // number → round-trips end-to-end. The 'Clear' → '0' entry preserves
      // the SDK's "remove font size attribute" semantics (handler strips the
      // attribute when value == '0').
      fontSizesValues: const <String, String>{
        '10': '10',
        '12': '12',
        '14': '14',
        '16': '16',
        '18': '18',
        '20': '20',
        '24': '24',
        '28': '28',
        '32': '32',
        '36': '36',
        '48': '48',
        'Clear': '0',
      },
      showHeaderStyle: true,
      showAlignmentButtons: true,
      showDirection: false,
      showSearchButton: false,
      showSubscript: false,
      showSuperscript: false,
      showClipboardCut: false,
      showClipboardCopy: false,
      showClipboardPaste: false,
      toolbarIconAlignment: WrapAlignment.start,
      toolbarSectionSpacing: 2,
      multiRowsDisplay: false,
      color: theme.colorScheme.surface,
      buttonOptions: QuillSimpleToolbarButtonOptions(
        base: QuillToolbarBaseButtonOptions(
          iconSize: 18,
          iconTheme: QuillIconTheme(
            iconButtonSelectedData: IconButtonData(
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                padding: const EdgeInsets.all(4),
                minimumSize: const Size(32, 32),
              ),
            ),
            iconButtonUnselectedData: IconButtonData(
              style: IconButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                padding: const EdgeInsets.all(4),
                minimumSize: const Size(32, 32),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DocxEditableBlock extends StatelessWidget {
  const _DocxEditableBlock({
    required this.block,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    this.onFocused,
  });

  final DocBlock block;
  final QuillController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback? onFocused;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = _styleForBlock(theme, block);

    final editor = QuillEditor.basic(
      controller: controller,
      focusNode: focusNode,
      configurations: QuillEditorConfigurations(
        expands: false,
        padding: EdgeInsets.zero,
        scrollPhysics: const ClampingScrollPhysics(),
        placeholder: '',
        customStyles: DefaultStyles(
          paragraph: DefaultTextBlockStyle(
            _paragraphStyle(theme),
            HorizontalSpacing.zero,
            VerticalSpacing.zero,
            VerticalSpacing.zero,
            null,
          ),
          h1: DefaultTextBlockStyle(
            _h1Style(theme),
            HorizontalSpacing.zero,
            VerticalSpacing.zero,
            VerticalSpacing.zero,
            null,
          ),
          h2: DefaultTextBlockStyle(
            _h2Style(theme),
            HorizontalSpacing.zero,
            VerticalSpacing.zero,
            VerticalSpacing.zero,
            null,
          ),
          h3: DefaultTextBlockStyle(
            _h3Style(theme),
            HorizontalSpacing.zero,
            VerticalSpacing.zero,
            VerticalSpacing.zero,
            null,
          ),
          lists: DefaultListBlockStyle(
            _listStyle(theme),
            HorizontalSpacing.zero,
            VerticalSpacing.zero,
            VerticalSpacing.zero,
            null,
            null,
          ),
        ),
      ),
    );

    // Use Listener (not GestureDetector) so pointer events propagate
    // unimpeded to QuillEditor for drag-to-select.
    final wrapped = Listener(
      onPointerDown: (_) => onFocused?.call(),
      child: editor,
    );

    if (block.type == DocBlockType.listItem) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 2),
            child: Text(
              '\u2022',
              style: baseStyle,
            ),
          ),
          Expanded(child: wrapped),
        ],
      );
    }

    return wrapped;
  }

  TextStyle _styleForBlock(ThemeData theme, DocBlock block) {
    switch (block.type) {
      case DocBlockType.heading:
        switch (block.level) {
          case 1:
            return _h1Style(theme);
          case 2:
            return _h2Style(theme);
          default:
            return _h3Style(theme);
        }
      case DocBlockType.listItem:
        return _listStyle(theme);
      case DocBlockType.paragraph:
        return _paragraphStyle(theme);
    }
  }

  TextStyle _h1Style(ThemeData theme) =>
      theme.textTheme.headlineMedium?.copyWith(height: 1.6) ??
      const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.6,
      );

  TextStyle _h2Style(ThemeData theme) =>
      theme.textTheme.headlineSmall?.copyWith(height: 1.6) ??
      const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        height: 1.6,
      );

  TextStyle _h3Style(ThemeData theme) =>
      theme.textTheme.titleLarge?.copyWith(height: 1.6) ??
      const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.6,
      );

  TextStyle _listStyle(ThemeData theme) =>
      theme.textTheme.bodyLarge?.copyWith(
        height: 1.6,
        fontSize: 16,
      ) ??
      const TextStyle(fontSize: 16, height: 1.6);

  TextStyle _paragraphStyle(ThemeData theme) =>
      theme.textTheme.bodyLarge?.copyWith(
        height: 1.8,
        fontSize: 16,
      ) ??
      const TextStyle(fontSize: 16, height: 1.8);
}
