import 'dart:convert';

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
import '../../data/services/audio_service.dart'
    show audioServiceProvider, audioPlayingProvider;
import '../../data/services/preferences_service.dart'
    show selectedVoiceIdProvider, selectedSpeedProvider, selectedVolumeProvider;
import '../../features/editor/chunk_editor_provider.dart';
import '../player/chunk_slicer.dart'
    show sliceBlocksIntoChunks, assignChunkIdsByContent, ChunkAction;
import '../player/widgets/docx_document_editor.dart' show buildDocxEditToolbar;
import '../player/widgets/docx_document_viewport.dart'
    show DocxDocumentViewport;
import '../player/widgets/docx_page_layout.dart'
    show buildDocxDocumentTheme, paginateDocxDocument, DocxPageLayoutPage;
import '../shell/widgets/player_bar.dart'
    show activeChunkIdsProvider, currentChunkIndexProvider;
import 'desk_providers.dart';

// Fast-start tuning lever: words per sliced chunk on Desk save. Smaller →
// the first chunk synthesizes sooner so listening starts faster (the rest
// synthesize ahead while it plays). The Player uses 500; the Writing Desk
// uses a smaller window so a never-played file starts quickly.
const int _kDeskChunkWords = 150;

const _kPaperColor = Color(0xFFFFFFFF);
const _kPaperInk = Color(0xFF1F2430);
const _kPaperInkMuted = Color(0xFF5B6470);
const _kPaperMaxWidth = 800.0;

/// Center pane for the Writing Desk.
///
/// Always-edit: a unified [quill.QuillEditor] backed by [deskDocumentProvider]
/// with the formatting toolbar fixed at the top. The header shows the file name
/// and a Save action; Save serialises the Quill Delta via [qcodec] and calls
/// [chunkEditorProvider.saveChunkTexts] without leaving the editor.
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
  quill.QuillController? _unifiedController;
  FocusNode? _focusNode;
  bool _isSaving = false;
  bool _sheetExpanded = false;
  String? _loadedDocId;

  // Edit ⟷ Read/Listen mode. Read mode renders the document through the same
  // DocumentReadingView the Reading Nook uses, so Synchronized Word Highlight,
  // Sentence Highlight, and "Listen from here" all come for free while the
  // bottom player bar drives playback. The editor controller is preserved
  // across the toggle so switching back keeps the cursor.
  bool _readMode = false;

  @override
  void dispose() {
    _unifiedController?.dispose();
    _focusNode?.dispose();
    super.dispose();
  }

  // Build the editor for [doc]. Called once per document load so the Writing
  // Desk is always editable with the toolbar showing.
  void _buildEditorFor(PsittaDocument doc) {
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
      _loadedDocId = widget.documentId;
    });
    ref.read(deskSaveStateProvider.notifier).state = DeskSaveState.editing;
  }

  Future<void> _save() async {
    final controller = _unifiedController;
    if (controller == null) return;

    setState(() => _isSaving = true);
    ref.read(deskSaveStateProvider.notifier).state = DeskSaveState.saving;

    try {
      // 1. Serialize the editor to a flat block-dict list.
      final flatBlocks = qcodec.quillDocumentToBlockDicts(
        controller.document,
        DocBlockType.paragraph,
        null,
      );

      // 2. Slice into small chunks so listening starts fast: the first small
      //    chunk synthesizes quickly and the player prefetches the next while
      //    it plays. Reuses the Player's M13 unified-save path verbatim so the
      //    Desk produces a properly multi-chunked document instead of one
      //    giant chunk. (Writing Nook only — the Player/Reading Nook is
      //    untouched.)
      final sliced =
          sliceBlocksIntoChunks(flatBlocks, targetWords: _kDeskChunkWords);

      // 3. Snapshot the pre-edit chunks (in sequence order) so unchanged
      //    chunks keep their TTS cache and edits map to the right rows.
      final rawData =
          await ref.read(chunksProvider(widget.documentId).future);
      final chunks = ((rawData['chunks'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList()
        ..sort((a, b) => ((a['sequence_index'] ?? 0) as int)
            .compareTo((b['sequence_index'] ?? 0) as int));

      final preEditChunkIds =
          chunks.map((c) => (c['id'] ?? '').toString()).toList();
      final preEditTexts = <String, String>{
        for (final c in chunks)
          (c['id'] ?? '').toString(): (c['text_content'] ?? '').toString(),
      };
      final preEditFormatted = <String, List<Map<String, dynamic>>>{
        for (final c in chunks)
          (c['id'] ?? '').toString():
              ((c['formatted_content'] as List<dynamic>?) ?? const [])
                  .whereType<Map<String, dynamic>>()
                  .toList(),
      };

      // 4. Content-preserving assignment (keep / update / insert / delete).
      final assignments =
          assignChunkIdsByContent(sliced, preEditChunkIds, preEditTexts);

      // 5. Promote keep→update for formatting-only edits (hash matches on
      //    plain text, so formatting changes would otherwise be dropped).
      for (var i = 0; i < assignments.length; i++) {
        final a = assignments[i];
        if (a.action != ChunkAction.keep) continue;
        final cid = a.chunkId;
        final s = a.slicedChunk;
        if (cid == null || s == null) continue;
        final prev = preEditFormatted[cid] ?? const <Map<String, dynamic>>[];
        if (jsonEncode(s.blockDicts) != jsonEncode(prev)) {
          assignments[i] = a.copyWith(action: ChunkAction.update);
        }
      }

      // 6. Fan out via the shared orchestrator.
      final ok = await ref.read(chunkEditorProvider.notifier).saveDocumentChunks(
            documentId: widget.documentId,
            assignments: assignments,
          );

      final hasWrites =
          assignments.any((a) => a.action != ChunkAction.keep);
      if (ok && hasWrites) {
        // Clear stale client-side audio for chunks whose text changed in place
        // (same id, new content) so the next Play re-synthesizes fresh audio
        // rather than replaying the pre-edit cache. Newly-inserted chunks have
        // fresh ids (no stale cache); deleted chunks are gone.
        final audioService = ref.read(audioServiceProvider);
        await audioService.reset();
        for (final a in assignments) {
          if (a.action == ChunkAction.update && a.chunkId != null) {
            await audioService.invalidateChunkCache(a.chunkId!);
          }
        }
        // Force a fresh chunk read so the reassembled document reflects the
        // just-saved chunks/formatting. (No batch pre-warm here: the streaming
        // play path starts fast on its own and caches on completion, so a
        // batch warm-up would double-synthesize the first chunk.)
        ref.invalidate(chunksProvider(widget.documentId));
        ref.invalidate(deskDocumentProvider(widget.documentId));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

  // Read/Listen surface — hosts the Reading Nook's production DocxDocumentViewport
  // (paginated rendering + SWH + Sentence Highlight + Listen-from-here).
  Widget _buildReadPaper(BuildContext context, PsittaDocument doc) {
    return _DeskReadView(
      key: ValueKey('desk-read-${widget.documentId}'),
      documentId: widget.documentId,
      document: doc,
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
      data: (doc) {
        // Read/Listen mode reuses the Reading Nook's DocumentReadingView so the
        // highlight experience is identical. The editor is still built (kept
        // alive) so toggling back to Edit is instant.
        if (_readMode && doc is PsittaDocument) {
          return _buildReadPaper(context, doc);
        }
        // Always-edit: build the editor once per document, then keep it so the
        // toolbar stays and saving doesn't reset the cursor.
        if (_unifiedController == null || _loadedDocId != widget.documentId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _buildEditorFor(doc);
          });
          return const Center(
            key: ValueKey('desk-center-preparing'),
            child: CircularProgressIndicator(),
          );
        }
        return _buildEditPaper(context);
      },
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

    final title = docAsync.valueOrNull?.title as String?;
    return ColoredBox(
      color: tokens.surface,
      child: Column(
        children: [
          _DeskCenterHeader(
            key: const ValueKey('desk-center-header'),
            title: (title == null || title.trim().isEmpty) ? 'New file' : title,
            isSaving: _isSaving,
            canSave: _unifiedController != null && !_readMode,
            onSave: _save,
            readMode: _readMode,
            onModeChanged: (read) => setState(() => _readMode = read),
          ),
          const Divider(height: 1),
          // The formatting toolbar is edit-only; Read mode hides it.
          if (!_readMode && _unifiedController != null) ...[
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
    required this.title,
    required this.isSaving,
    required this.canSave,
    required this.onSave,
    required this.readMode,
    required this.onModeChanged,
  });

  final String title;
  final bool isSaving;
  final bool canSave;
  final VoidCallback onSave;
  final bool readMode;
  final ValueChanged<bool> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
        child: Row(
          children: [
            Icon(Icons.description_outlined,
                size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                key: const ValueKey('desk-file-name'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _ModeToggle(readMode: readMode, onChanged: onModeChanged),
            const SizedBox(width: 8),
            if (isSaving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              TextButton.icon(
                key: const ValueKey('desk-save'),
                onPressed: canSave ? onSave : null,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Save'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Edit / Read mode toggle ───────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.readMode, required this.onChanged});

  final bool readMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 26,
      decoration: BoxDecoration(
        color: scheme.onSurface.withOpacity(0.06),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: scheme.outline.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg(context, label: 'Write', icon: Icons.edit_outlined,
              selected: !readMode, onTap: () => onChanged(false)),
          _seg(context, label: 'Read', icon: Icons.headphones_outlined,
              selected: readMode, onTap: () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _seg(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: ValueKey('desk-mode-${label.toLowerCase()}'),
      borderRadius: BorderRadius.circular(6),
      onTap: selected ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color:
                        selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
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
          // Headings default to full ink, not Quill's dimmed default, so the
          // file is never theme-tinted. The writer's own colour formatting
          // still overrides these at the run level.
          h1: quill.DefaultTextBlockStyle(
            (Theme.of(context).textTheme.headlineSmall ??
                    const TextStyle(fontSize: 26))
                .copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
            const quill.HorizontalSpacing(0, 0),
            const quill.VerticalSpacing(16, 8),
            quill.VerticalSpacing.zero,
            null,
          ),
          h2: quill.DefaultTextBlockStyle(
            (Theme.of(context).textTheme.titleLarge ??
                    const TextStyle(fontSize: 22))
                .copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
            const quill.HorizontalSpacing(0, 0),
            const quill.VerticalSpacing(12, 6),
            quill.VerticalSpacing.zero,
            null,
          ),
          h3: quill.DefaultTextBlockStyle(
            (Theme.of(context).textTheme.titleMedium ??
                    const TextStyle(fontSize: 18))
                .copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            const quill.HorizontalSpacing(0, 0),
            const quill.VerticalSpacing(8, 4),
            quill.VerticalSpacing.zero,
            null,
          ),
        ),
      ),
    );
  }
}

// ── Read / Listen view ────────────────────────────────────────────────────────
//
// Hosts the shared DocumentReadingView (the Reading Nook's reading canvas) in a
// scroll view, feeding it the active chunk's alignment so Synchronized Word
// Highlight and Sentence Highlight render while the bottom player bar plays.
// Auto-scroll follows the active sentence via Scrollable.ensureVisible.

class _DeskReadView extends ConsumerStatefulWidget {
  const _DeskReadView({
    super.key,
    required this.documentId,
    required this.document,
  });

  final String documentId;
  final PsittaDocument document;

  @override
  ConsumerState<_DeskReadView> createState() => _DeskReadViewState();
}

class _DeskReadViewState extends ConsumerState<_DeskReadView> {
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _blockKeys = {};
  final Map<int, GlobalKey> _pageKeys = {};

  // Chunk ids we have already primed alignment for, so we don't re-trigger on
  // every rebuild.
  final Set<String> _alignmentPrimed = {};

  GlobalKey _pageKey(int pageNumber) =>
      _pageKeys.putIfAbsent(pageNumber, () => GlobalKey());

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // Follow the voice: scroll the active sentence's block to ~22% from the top
  // so the line being read always has headroom and never sits above the frame.
  void _onActiveSentence(GlobalKey blockKey) {
    final ctx = blockKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.22,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // Click-to-listen: jump playback to the line the writer clicked. Finds the
  // chunk containing the document-level character offset, plays it on the
  // seekable (batch) path — streaming responses can't be scrubbed — and seeks
  // proportionally to the clicked position within that chunk.
  Future<void> _seekToDocOffset(int docOffset) async {
    final chunkMap = widget.document.chunkMap;
    final chunkIds = ref.read(activeChunkIdsProvider);
    if (chunkMap.isEmpty || chunkIds.isEmpty) return;

    var targetIdx = 0;
    for (var i = 0; i < chunkMap.length; i++) {
      final c = chunkMap[i];
      if (docOffset >= c.textOffset) targetIdx = i;
      if (docOffset >= c.textOffset &&
          docOffset < c.textOffset + c.textLength) {
        targetIdx = i;
        break;
      }
    }
    if (targetIdx >= chunkIds.length) return;

    final chunkId = chunkIds[targetIdx];
    final voiceId = ref.read(selectedVoiceIdProvider);
    final speed = ref.read(selectedSpeedProvider);
    final volume = ref.read(selectedVolumeProvider);
    final audioService = ref.read(audioServiceProvider);

    ref.read(currentChunkIndexProvider.notifier).state = targetIdx;
    await audioService.playChunk(
      documentId: widget.documentId,
      chunkId: chunkId,
      voiceId: voiceId,
      speed: speed,
      volume: volume,
    );

    final c = chunkMap[targetIdx];
    if (c.textLength <= 0) return;
    final charInChunk =
        (docOffset - c.textOffset).clamp(0, c.textLength).toInt();
    final frac = (charInChunk / c.textLength).clamp(0.0, 0.98);
    final dur = await audioService.player.durationStream
        .firstWhere((d) => d != null && d > Duration.zero)
        .timeout(const Duration(seconds: 12), onTimeout: () => null);
    if (dur != null) {
      await audioService.seek(
        Duration(milliseconds: (frac * dur.inMilliseconds).round()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chunkIds = ref.watch(activeChunkIdsProvider);
    final rawIndex = ref.watch(currentChunkIndexProvider);
    final voiceId = ref.watch(selectedVoiceIdProvider);
    final audioService = ref.watch(audioServiceProvider);

    final chunkCount = widget.document.chunkMap.length;
    final safeIndex = chunkCount == 0 ? 0 : rawIndex.clamp(0, chunkCount - 1);
    final activeChunkId =
        (rawIndex >= 0 && rawIndex < chunkIds.length) ? chunkIds[rawIndex] : '';

    // Alignment for the active chunk (matches the Player). It is fetched lazily;
    // the first fetch may resolve empty because the audio (and its alignment
    // sidecar) has not been synthesized yet — see the playing-listener below,
    // which invalidates the provider once the chunk's audio is ready so word
    // highlighting appears.
    final alignmentAsync = activeChunkId.isEmpty
        ? null
        : ref.watch(
            chunkAlignmentProvider(
              AlignmentKey(
                documentId: widget.documentId,
                chunkId: activeChunkId,
                voiceId: voiceId,
              ),
            ),
          );
    final alignmentPayload =
        alignmentAsync?.valueOrNull ?? const <String, dynamic>{};
    final isFetchingAlignment = alignmentAsync?.isLoading ?? false;

    // When the active chunk's audio starts playing, its alignment sidecar now
    // exists on the backend. Refresh the (previously-empty) alignment once so
    // Synchronized Word Highlight lights up.
    ref.listen<AsyncValue<bool>>(audioPlayingProvider, (prev, next) {
      if (next.valueOrNull != true) return;
      if (activeChunkId.isEmpty || _alignmentPrimed.contains(activeChunkId)) {
        return;
      }
      _alignmentPrimed.add(activeChunkId);
      ref.invalidate(
        chunkAlignmentProvider(
          AlignmentKey(
            documentId: widget.documentId,
            chunkId: activeChunkId,
            voiceId: voiceId,
          ),
        ),
      );
    });

    final pages = paginateDocxDocument(context, widget.document);

    return SingleChildScrollView(
      key: const ValueKey('desk-read-scroll'),
      controller: _scroll,
      child: DocxDocumentViewport(
        key: ValueKey('desk-reading-${widget.documentId}-$voiceId'),
        document: widget.document,
        pages: pages,
        activeChunkIndex: safeIndex,
        alignmentPayload: alignmentPayload,
        isFetchingAlignment: isFetchingAlignment,
        onActiveSentenceChanged: _onActiveSentence,
        // Click a line (or its margin play icon) to jump the voice there.
        onSentenceTap: _seekToDocOffset,
        onLinePlayTap: _seekToDocOffset,
        audioService: audioService,
        blockKeys: _blockKeys,
        pageKeys: {
          for (final DocxPageLayoutPage page in pages)
            page.pageNumber: _pageKey(page.pageNumber),
        },
      ),
    );
  }
}

// ── Paper helpers ─────────────────────────────────────────────────────────────

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
