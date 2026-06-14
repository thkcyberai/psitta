import 'package:flutter/gestures.dart'
    show kDoubleTapSlop, kDoubleTapTimeout, kPrimaryButton, kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../data/models/psitta_document.dart';
import '../spellcheck/spell_dictionary.dart';
import 'page_break_embed.dart';

/// Info surfaced when the user taps a squiggled (misspelled) word in the
/// unified editor: the word, its [start] document offset and [len], and
/// [anchorGlobal] — the global on-screen point just below the start of the
/// word, used to anchor the suggestions menu beside the word. SG4.
typedef SquiggleWordTap = void Function(
  ({String word, int start, int len, Offset anchorGlobal}) info,
);

class DocxDocumentEditor extends StatefulWidget {
  const DocxDocumentEditor({
    super.key,
    required this.document,
    this.controllers = const {},
    this.focusNodes = const {},
    this.unifiedController,
    this.unifiedFocusNode,
    this.unifiedEditorKey,
    this.error,
    this.isSaving = false,
    this.onChanged,
    this.onActiveControllerChanged,
    this.onSquiggleWordTap,
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

  /// Optional key on the unified editor's [EditorState] so external code
  /// (find-in-document) can reach `renderEditor.getLocalRectForCaret` to
  /// scroll a match into view. Unified mode only; null in per-paragraph mode.
  final GlobalKey<EditorState>? unifiedEditorKey;

  final String? error;
  final bool isSaving;
  final VoidCallback? onChanged;
  final ValueChanged<QuillController>? onActiveControllerChanged;

  /// SG4a: invoked when the user taps a squiggled (misspelled) word in the
  /// unified editor. Null in per-paragraph mode. The handler shows the
  /// suggestions menu; the editor still places the caret (onTapUp returns
  /// false).
  final SquiggleWordTap? onSquiggleWordTap;

  @override
  State<DocxDocumentEditor> createState() => _DocxDocumentEditorState();
}

class _DocxDocumentEditorState extends State<DocxDocumentEditor> {
  QuillController? _activeController;
  final Set<QuillController> _listening = {};

  // SG4a (Option B): pointer-down tracking to distinguish a left-click from a
  // selection-drag for the squiggle suggestions menu.
  Offset? _squiggleDownPos;
  bool _squiggleDownPrimary = false;
  // SG4 double-click gate: the previous qualifying tap's global position and
  // timestamp. The menu opens only on the SECOND tap of a double-click, so a
  // single click just places the caret (e.g. to split two run-together words).
  Offset? _lastTapPos;
  Duration? _lastTapTime;

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

  // ── SG4a (Option B): squiggle tap detection ─────────────────────────
  // flutter_quill 10.8.5 QuillEditor.basic strips the onTapUp config callback
  // via copyWith(), so taps are detected with a passive Listener over the
  // editor and hit-tested against the squiggle attribute here.
  void _onEditorPointerDown(PointerDownEvent event) {
    _squiggleDownPrimary = event.buttons == kPrimaryButton;
    _squiggleDownPos = event.position;
  }

  void _onEditorPointerUp(PointerUpEvent event) {
    final down = _squiggleDownPos;
    final primary = _squiggleDownPrimary;
    _squiggleDownPos = null;
    _squiggleDownPrimary = false;
    // Per-click qualification: a primary-button click that didn't move — a tap,
    // not a text-selection drag (which would otherwise pop the menu).
    if (!primary || down == null) return;
    if ((event.position - down).distance > kTouchSlop) return;

    // Double-click gate: only the SECOND qualifying tap (within the system
    // double-tap window + slop of the first) opens the menu. A single click
    // just places the caret. The editor's own double-tap word-selection still
    // happens via this passive Listener — the word highlight alongside the
    // menu is expected.
    final lastPos = _lastTapPos;
    final lastTime = _lastTapTime;
    final isDoubleTap = lastPos != null &&
        lastTime != null &&
        (event.timeStamp - lastTime) <= kDoubleTapTimeout &&
        (event.position - lastPos).distance <= kDoubleTapSlop;
    if (isDoubleTap) {
      _lastTapPos = null;
      _lastTapTime = null;
      _maybeHandleSquiggleTap(event.position);
    } else {
      _lastTapPos = event.position;
      _lastTapTime = event.timeStamp;
    }
  }

  /// Hit-test a tap at [globalPosition]; if it lands on a squiggled word,
  /// surface (word, range, global position) to the player via
  /// [DocxDocumentEditor.onSquiggleWordTap]. Reuses the SG4a gate + tokenizer.
  /// The editor still places the caret (the Listener never consumes events).
  void _maybeHandleSquiggleTap(Offset globalPosition) {
    final cb = widget.onSquiggleWordTap;
    final controller = widget.unifiedController;
    if (cb == null || controller == null) return;
    // RenderEditor.getPositionForOffset takes a GLOBAL offset and converts to
    // local itself (flutter_quill editor.dart:1251) — matching the editor's own
    // caret path. Do NOT pre-convert with globalToLocal (that double-converts).
    final renderEditor = widget.unifiedEditorKey?.currentState?.renderEditor;
    if (renderEditor == null) return; // editor not laid out yet
    final doc = controller.document;
    final plain = doc.toPlainText();
    final off = renderEditor.getPositionForOffset(globalPosition).offset;
    if (off < 0 || off >= plain.length) return;
    // Gate on the squiggle attribute. collectStyle(off, 0) reflects the char to
    // the LEFT of off, so a tap on a flagged word's first char can read clean —
    // also check the char AT off (len 1).
    final flagged =
        doc.collectStyle(off, 0).attributes.containsKey('squiggle') ||
            doc.collectStyle(off, 1).attributes.containsKey('squiggle');
    if (!flagged) return;
    // Expand to the exact word range via the tokenizer over the tapped line
    // (matches the ranges the spell pass flagged).
    final node = doc.queryChild(off).node;
    if (node is! Line) return;
    final lineStart = node.documentOffset;
    final lineEnd = (lineStart + node.length).clamp(0, plain.length);
    for (final tok in tokenizeWords(plain.substring(lineStart, lineEnd))) {
      final tokStart = lineStart + tok.start;
      if (off >= tokStart && off < tokStart + tok.len) {
        // Anchor the menu to the WORD, not the raw click point. The caret rect
        // for the word's start is in the render editor's local (scrolled)
        // content space; localToGlobal maps it to the actual screen position,
        // so a word lower in a scrolled document still anchors correctly (same
        // pattern as _revealEditMatch). bottomLeft = just under the word start.
        final caretRect =
            renderEditor.getLocalRectForCaret(TextPosition(offset: tokStart));
        final anchorGlobal = renderEditor.localToGlobal(caretRect.bottomLeft);
        cb((
          word: tok.word,
          start: tokStart,
          len: tok.len,
          anchorGlobal: anchorGlobal,
        ));
        break;
      }
    }
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
    final listStyle =
        theme.textTheme.bodyLarge?.copyWith(height: 1.6, fontSize: 16) ??
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

    final unifiedEditor = QuillEditor.basic(
      controller: controller,
      focusNode: focusNode,
      configurations: QuillEditorConfigurations(
        editorKey: widget.unifiedEditorKey,
        expands: false,
        padding: EdgeInsets.zero,
        scrollPhysics: const ClampingScrollPhysics(),
        placeholder: '',
        enableInteractiveSelection: true,
        // M13.5 scaffolding — embed builder registered ahead of the
        // toolbar customButton (which lives on spike/page-break-embed-validation
        // tag m13.5-pagebreak-spike) so any data containing a
        // page_break embed loads without the UnimplementedError that
        // flutter_quill raises for unknown embed types.
        embedBuilders: [PageBreakEmbedBuilder()],
        // SG3 spellcheck: the transient inline 'squiggle' attribute (applied
        // by the player's spell pass) maps to a red wavy underline. Every
        // other attribute returns an empty TextStyle so real run formatting
        // (bold/italic/size/color/…) is untouched — customStyleBuilder is
        // invoked per-attribute on each run and the results are merged.
        customStyleBuilder: (attribute) {
          if (attribute.key == 'squiggle') {
            return const TextStyle(
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.wavy,
              decorationColor: Colors.red,
            );
          }
          return const TextStyle();
        },
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
    );
    children.add(
      // SG4a (Option B): a passive Listener detects taps on squiggled words.
      // flutter_quill 10.8.5 QuillEditor.basic strips the onTapUp config via
      // copyWith(), so we hit-test here instead. Listener does NOT consume
      // pointer events, so the editor still handles its own caret/selection.
      Listener(
        onPointerDown: _onEditorPointerDown,
        onPointerUp: _onEditorPointerUp,
        child: unifiedEditor,
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
  bool multiRowsDisplay = false,
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
      // Curated to 6 fonts that ship with Microsoft Word on Windows.
      // Each is guaranteed installed at the OS level — Flutter's font
      // resolver finds them without any pubspec.yaml `fonts:` asset
      // registration, and they round-trip through /export to .docx
      // because Word ships with the same families.
      //
      // The default list flutter_quill 10.8.5 surfaces (Pacifico,
      // SquarePeg, Nunito, Ibarra Real Nova, Roboto Mono, plus generic
      // CSS keywords sans-serif/serif/monospace) is wrong for two
      // reasons: (1) none of those fonts are bundled as Flutter assets,
      // so picking them silently falls back to Segoe UI; (2) they're
      // web-design fonts, not the Word-document fonts our users expect.
      //
      // Hidden-bonus fix: _extract_formatted_docx (backend) reads
      // run.font.name from uploaded .docx files. Pre-fix, names like
      // "Calibri" or "Cambria" were technically preserved in storage
      // but rendered as Segoe UI in the editor. With these family
      // names recognized, uploaded fonts now render correctly.
      //
      // Cross-platform note: Mac and Linux ports must override this
      // with platform-installed fonts (e.g. Helvetica/Avenir/Menlo on
      // Mac). Adding a font here requires it to be installed on every
      // target system — OR registered as a Flutter font asset under
      // `flutter: fonts:` in pubspec.yaml.
      //
      // The 'Clear' entry is required by flutter_quill — it triggers
      // the "remove font attribute" path in font_family_button.dart.
      fontFamilyValues: const <String, String>{
        'Calibri': 'Calibri',
        'Arial': 'Arial',
        'Times New Roman': 'Times New Roman',
        'Georgia': 'Georgia',
        'Courier New': 'Courier New',
        'Cambria': 'Cambria',
        'Clear': 'Clear',
      },
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
      multiRowsDisplay: multiRowsDisplay,
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
        // M13.5 scaffolding — see _buildUnifiedEditor's matching
        // embedBuilders comment. Both editor instances must register
        // the builder so neither mode crashes on unknown-embed data.
        embedBuilders: [PageBreakEmbedBuilder()],
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
