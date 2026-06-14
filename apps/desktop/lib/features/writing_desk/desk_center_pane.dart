import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/editor/quill_codec.dart' as qcodec;
import '../../core/theme/psitta_tokens.dart';
import '../../data/models/document_assembler.dart';
import '../../data/models/psitta_document.dart';
import '../../data/providers/providers.dart';
import '../../features/editor/chunk_editor_provider.dart';
import '../player/widgets/docx_document_editor.dart' show buildDocxEditToolbar;
import '../player/widgets/docx_page_layout.dart' show buildDocxDocumentTheme;
import '../player/widgets/document_reading_view.dart';
import 'desk_providers.dart';

const _kPaperColor = Color(0xFFFFFFFF);
const _kPaperInk = Color(0xFF1F2430);
const _kPaperInkMuted = Color(0xFF5B6470);
const _kPaperMaxWidth = 800.0;

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
    this.projectId,
  });

  final String documentId;
  final String? projectId;

  @override
  ConsumerState<DeskCenterPane> createState() => _DeskCenterPaneState();
}

class _DeskCenterPaneState extends ConsumerState<DeskCenterPane> {
  bool _isEditing = false;
  quill.QuillController? _unifiedController;
  FocusNode? _focusNode;
  bool _isSaving = false;
  bool _sheetExpanded = false;

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
    ref.read(deskSaveStateProvider.notifier).state = DeskSaveState.editing;

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
    ref.read(deskSaveStateProvider.notifier).state = DeskSaveState.saving;

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
        // Force a fresh chunk read so the reassembled document reflects the
        // just-saved formatting. deskDocumentProvider rebuilds from
        // chunksProvider; invalidating only deskDocumentProvider would re-read
        // the stale cached chunks and revert the edit.
        ref.invalidate(chunksProvider(widget.documentId));
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
      ref.read(deskSaveStateProvider.notifier).state = DeskSaveState.saved;
    }
  }

  Widget _buildEditPaper(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = constraints.maxWidth < _kPaperMaxWidth
            ? (constraints.maxWidth - 32).clamp(0.0, _kPaperMaxWidth)
            : _kPaperMaxWidth;
        final pageHeight = constraints.maxHeight - 56;
        return Center(
          child: SizedBox(
            width: pageWidth,
            height: pageHeight > 0 ? pageHeight : constraints.maxHeight,
            child: Container(
              decoration: _paperDecoration(),
              clipBehavior: Clip.antiAlias,
              child: Theme(
                data: buildDocxDocumentTheme(Theme.of(context)),
                child: _DeskEditorBody(
                  key: const ValueKey('desk-editor-body'),
                  controller: _unifiedController!,
                  focusNode: _focusNode!,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCenterBody(BuildContext context, PsittaTokens tokens,
      AsyncValue<dynamic> docAsync) {
    final sheet = docAsync.when(
      loading: () => const Center(
        key: ValueKey('desk-center-loading'),
        child: CircularProgressIndicator(),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.menu_book_outlined,
                size: 40,
                color: _kPaperInkMuted,
              ),
              const SizedBox(height: 12),
              Text(
                'No document open',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _kPaperInk,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Start a new document below, or open one from your Library.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _kPaperInkMuted,
                    ),
              ),
            ],
          ),
        ),
      ),
      data: (doc) => _isEditing && _unifiedController != null
          ? _buildEditPaper(context)
          : SingleChildScrollView(
              child: _PaperSurface(
                child: DocumentReadingView(
                  key: const ValueKey('desk-reading-body'),
                  document: doc,
                  activeChunkIndex: 0,
                  alignmentPayload: const {},
                  enableContextMenu: false,
                ),
              ),
            ),
    );
    const cardsHeight = 168.0;
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: cardsHeight,
          child: _ThreeWaysPanel(
            documentId: widget.documentId,
            projectId: widget.projectId,
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          left: 0,
          right: 0,
          top: 0,
          bottom: _sheetExpanded ? 0 : cardsHeight,
          child: ColoredBox(color: tokens.surface, child: sheet),
        ),
        Positioned(
          top: 6,
          right: 14,
          child: IconButton(
            key: const ValueKey('desk-sheet-expand'),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip:
                _sheetExpanded ? 'Show add-content panel' : 'Expand sheet',
            icon: Icon(
              _sheetExpanded ? Icons.fullscreen_exit : Icons.fullscreen,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () =>
                setState(() => _sheetExpanded = !_sheetExpanded),
          ),
        ),
      ],
    );
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
          if (_isEditing && _unifiedController != null) ...[
            buildDocxEditToolbar(
              controller: _unifiedController!,
              theme: Theme.of(context),
              multiRowsDisplay: true,
            ),
            const Divider(height: 1),
          ],
          Expanded(child: _buildCenterBody(context, tokens, docAsync)),
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
                  color: isEditing ? scheme.primary : scheme.onSurfaceVariant,
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
        expands: true,
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
        scrollPhysics: const ClampingScrollPhysics(),
        placeholder: 'Start writing…',
        enableInteractiveSelection: true,
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

// ── Paper helpers ─────────────────────────────────────────────────────────────

ThemeData _paperThemeOf(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      surface: _kPaperColor,
      onSurface: _kPaperInk,
      onSurfaceVariant: _kPaperInkMuted,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: _kPaperInk,
      displayColor: _kPaperInk,
    ),
  );
}

BoxDecoration _paperDecoration() => BoxDecoration(
      color: _kPaperColor,
      borderRadius: BorderRadius.circular(6),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF000000).withOpacity(0.10),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );

// ── Paper surface ─────────────────────────────────────────────────────────────

class _PaperSurface extends StatelessWidget {
  const _PaperSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kPaperMaxWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 64),
          decoration: _paperDecoration(),
          child: Theme(
            data: _paperThemeOf(context),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: _kPaperInk),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Three Ways Panel ──────────────────────────────────────────────────────────

class _ThreeWaysPanel extends ConsumerWidget {
  const _ThreeWaysPanel({
    required this.documentId,
    required this.projectId,
  });

  final String documentId;
  final String? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: tokens.surface2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Three ways to add content to your project',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _AddCard(
                      index: '1',
                      accent: _AddCardAccent.primary,
                      title: 'Start New Document',
                      body:
                          'Create a new document and choose where it lives.',
                      cta: 'New Document',
                      buttonKey: 'desk-add-new-doc',
                      onPressed: () => _newDocument(context, ref),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AddCard(
                      index: '2',
                      accent: _AddCardAccent.secondary,
                      title: 'Add from Library',
                      body:
                          'Choose an existing document from your library.',
                      cta: 'Browse Library',
                      buttonKey: 'desk-add-from-library',
                      onPressed: () => context.go('/library'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AddCard(
                      index: '3',
                      accent: _AddCardAccent.tertiary,
                      title: 'Create Project First',
                      body:
                          'Set up your project and blueprint structure first.',
                      cta: 'Create New Project',
                      buttonKey: 'desk-add-create-project',
                      onPressed: () => _createProject(context, ref),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card actions ────────────────────────────────────────────────────────────

  /// Create a blank document and open it in the Writing Desk, carrying the
  /// current project context when present.
  Future<void> _newDocument(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(documentRepositoryProvider);
      final result = await repo.createBlankDocument();
      final docId = result['id'];
      ref.invalidate(documentsProvider);
      if (docId == null || !context.mounted) return;
      final q = projectId != null ? '?projectId=$projectId' : '';
      context.go('/writing-desk/$docId$q');
    } on DioException catch (e) {
      if (!context.mounted) return;
      final msg = e.response?.statusCode == 402
          ? 'Document limit reached for this month — upgrade in Settings.'
          : 'Could not create document: ${e.message ?? e}';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create document: $e')),
      );
    }
  }

  /// Prompt for a name, create the project, then open it.
  Future<void> _createProject(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Project'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Project name',
            hintText: 'e.g. My Memoir',
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    final name = controller.text.trim();
    controller.dispose();
    if (confirmed != true || name.isEmpty || !context.mounted) return;

    try {
      final repo = ref.read(projectRepositoryProvider);
      final project = await repo.createProject(name);
      if (!context.mounted) return;
      context.go(
        '/projects/${project.id}?projectName=${Uri.encodeComponent(project.name)}',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create project: $e')),
      );
    }
  }
}

// ── Add Card ──────────────────────────────────────────────────────────────────

enum _AddCardAccent { primary, secondary, tertiary }

class _AddCard extends StatelessWidget {
  const _AddCard({
    required this.index,
    required this.accent,
    required this.title,
    required this.body,
    required this.cta,
    required this.buttonKey,
    required this.onPressed,
  });

  final String index;
  final _AddCardAccent accent;
  final String title;
  final String body;
  final String cta;
  final String buttonKey;
  final VoidCallback onPressed;

  Color _accentColor(ColorScheme scheme) => switch (accent) {
        _AddCardAccent.primary => scheme.primary,
        _AddCardAccent.secondary => scheme.secondary,
        _AddCardAccent.tertiary => scheme.tertiary,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accentColor = _accentColor(scheme);
    return Container(
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withOpacity(0.30), width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Text(
                  index,
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              body,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 28,
            child: FilledButton(
              key: ValueKey(buttonKey),
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: scheme.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                textStyle: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: onPressed,
              child: Text(cta),
            ),
          ),
        ],
      ),
    );
  }
}
