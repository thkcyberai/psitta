import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../player/spellcheck/spell_dictionary.dart'
    show SpellDictionary, tokenizeWords;
import '../player/spellcheck/spell_suggester.dart' show suggest;
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
    this.initialRead = false,
  });

  final String documentId;
  final String? projectId;

  /// When true, the Desk opens directly in Read/Listen mode (used by the
  /// Library's "Read" action).
  final bool initialRead;

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

  // ── Find / Replace (Write mode) ─────────────────────────────────────────────
  bool _showFind = false;
  bool _showReplace = false;
  bool _findCaseSensitive = false;
  final TextEditingController _findCtrl = TextEditingController();
  final TextEditingController _replaceCtrl = TextEditingController();
  final FocusNode _findFocus = FocusNode(debugLabel: 'desk-find');
  List<int> _findMatches = const [];
  int _findIndex = -1;

  // ── Spell & Grammar (on-device spell check) ─────────────────────────────────
  // Red wavy squiggles under misspelled words via the 'squiggle' Quill
  // attribute (not persisted — the codec whitelist drops it on save). Reuses the
  // Reading Nook's offline SCOWL dictionary + edit-distance suggester.
  Timer? _spellDebounce;
  bool _squiggleInFlight = false;
  String? _lastSpellPlainText;


  @override
  void initState() {
    super.initState();
    _readMode = widget.initialRead;
    HardwareKeyboard.instance.addHandler(_handleFindKey);
  }

  @override
  void dispose() {
    _spellDebounce?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleFindKey);
    _findCtrl.dispose();
    _replaceCtrl.dispose();
    _findFocus.dispose();
    _unifiedController?.dispose();
    _focusNode?.dispose();
    super.dispose();
  }

  // Recompute squiggles ~350ms after the writer stops typing (paragraph-scoped).
  void _onEditorChanged() {
    if (_squiggleInFlight) return;
    _spellDebounce?.cancel();
    _spellDebounce = Timer(const Duration(milliseconds: 350), _spellTick);
  }

  void _spellTick() {
    if (!mounted) return;
    final controller = _unifiedController;
    if (controller == null) return;
    final plain = controller.document.toPlainText();
    if (plain.isEmpty) {
      _lastSpellPlainText = plain;
      return;
    }
    // Attribute-only change (squiggle pass, bold toggle, cursor move) — skip.
    if (plain == _lastSpellPlainText) return;

    final offset = controller.selection.baseOffset.clamp(0, plain.length - 1);
    final node = controller.document.queryChild(offset).node;
    if (node is! quill.Line) {
      _lastSpellPlainText = plain;
      return;
    }
    final start = node.documentOffset;
    final end = start + node.length;

    _squiggleInFlight = true;
    try {
      // Re-scan the previous line too on an Enter-split / paste at line start.
      if (offset == start && start > 0) {
        final prev = controller.document.queryChild(start - 1).node;
        if (prev is quill.Line) {
          _runSpellPass(
            start: prev.documentOffset,
            end: prev.documentOffset + prev.length,
          );
        }
      }
      _runSpellPass(start: start, end: end);
    } finally {
      _squiggleInFlight = false;
    }
    _lastSpellPlainText = plain;
  }

  // Paint red wavy squiggles under misspelled words. Undo-safe (ignoreChange)
  // and non-persistent (the 'squiggle' attribute isn't in the codec whitelist).
  void _runSpellPass({int? start, int? end}) {
    final controller = _unifiedController;
    if (controller == null) return;
    final plain = controller.document.toPlainText();
    final rangeStart = (start ?? 0).clamp(0, plain.length);
    final rangeEnd = (end ?? plain.length).clamp(rangeStart, plain.length);
    final rangeLen = rangeEnd - rangeStart;
    if (rangeLen <= 0) return;

    final bad = <({int start, int len})>[];
    for (final tok in tokenizeWords(plain.substring(rangeStart, rangeEnd))) {
      if (SpellDictionary.instance.isMisspelled(tok.word)) {
        bad.add((start: rangeStart + tok.start, len: tok.len));
      }
    }

    final history = controller.document.history;
    final priorIgnore = history.ignoreChange;
    history.ignoreChange = true;
    try {
      controller.formatText(
        rangeStart,
        rangeLen,
        const quill.Attribute('squiggle', quill.AttributeScope.inline, null),
        shouldNotifyListeners: bad.isEmpty,
      );
      for (var i = 0; i < bad.length; i++) {
        controller.formatText(
          bad[i].start,
          bad[i].len,
          const quill.Attribute('squiggle', quill.AttributeScope.inline, true),
          shouldNotifyListeners: i == bad.length - 1,
        );
      }
    } finally {
      history.ignoreChange = priorIgnore;
    }
  }

  // Ctrl+F opens the find bar (Write mode only); Esc closes it. Uses a global
  // HardwareKeyboard handler so it fires even when the Quill editor holds focus.
  bool _handleFindKey(KeyEvent e) {
    if (e is! KeyDownEvent) return false;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    if (ctrl &&
        e.logicalKey == LogicalKeyboardKey.keyF &&
        !_readMode &&
        _unifiedController != null) {
      _openFind();
      return true;
    }
    if (e.logicalKey == LogicalKeyboardKey.escape && _showFind) {
      _closeFind();
      return true;
    }
    return false;
  }

  void _openFind() {
    final controller = _unifiedController;
    String? seed;
    if (controller != null) {
      final sel = controller.selection;
      if (sel.isValid && !sel.isCollapsed) {
        final plain = controller.document.toPlainText();
        final start = sel.start.clamp(0, plain.length);
        final end = sel.end.clamp(0, plain.length);
        final s = plain.substring(start, end);
        if (!s.contains('\n')) seed = s;
      }
    }
    setState(() => _showFind = true);
    if (seed != null && seed.isNotEmpty) {
      _findCtrl.text = seed;
      _runFind();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _findFocus.requestFocus();
      _findCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _findCtrl.text.length,
      );
    });
  }

  void _closeFind() {
    setState(() {
      _showFind = false;
      _findMatches = const [];
      _findIndex = -1;
    });
    _focusNode?.requestFocus();
  }

  void _runFind() {
    final controller = _unifiedController;
    final query = _findCtrl.text;
    if (controller == null || query.isEmpty) {
      setState(() {
        _findMatches = const [];
        _findIndex = -1;
      });
      return;
    }
    final matches =
        controller.document.search(query, caseSensitive: _findCaseSensitive);
    setState(() {
      _findMatches = matches;
      _findIndex = matches.isEmpty ? -1 : 0;
    });
    if (matches.isNotEmpty) _revealMatch(0);
  }

  // Select the match so the editor brings it into view, then return focus to
  // the find field so the writer can keep navigating.
  void _revealMatch(int i) {
    final controller = _unifiedController;
    if (controller == null || i < 0 || i >= _findMatches.length) return;
    final off = _findMatches[i];
    final len = _findCtrl.text.length;
    _focusNode?.requestFocus();
    controller.updateSelection(
      TextSelection(baseOffset: off, extentOffset: off + len),
      quill.ChangeSource.local,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showFind) _findFocus.requestFocus();
    });
  }

  void _findNext() {
    if (_findMatches.isEmpty) return;
    setState(() => _findIndex = (_findIndex + 1) % _findMatches.length);
    _revealMatch(_findIndex);
  }

  void _findPrev() {
    if (_findMatches.isEmpty) return;
    setState(() => _findIndex =
        (_findIndex - 1 + _findMatches.length) % _findMatches.length);
    _revealMatch(_findIndex);
  }

  void _replaceCurrent() {
    final controller = _unifiedController;
    if (controller == null ||
        _findIndex < 0 ||
        _findIndex >= _findMatches.length) {
      return;
    }
    final off = _findMatches[_findIndex];
    final qlen = _findCtrl.text.length;
    final rep = _replaceCtrl.text;
    controller.replaceText(
      off,
      qlen,
      rep,
      TextSelection.collapsed(offset: off + rep.length),
    );
    // Offsets shifted — re-search and advance past the replacement.
    final matches = controller.document
        .search(_findCtrl.text, caseSensitive: _findCaseSensitive);
    var nextIdx = -1;
    for (var k = 0; k < matches.length; k++) {
      if (matches[k] >= off + rep.length) {
        nextIdx = k;
        break;
      }
    }
    if (nextIdx == -1 && matches.isNotEmpty) nextIdx = 0;
    setState(() {
      _findMatches = matches;
      _findIndex = nextIdx;
    });
    if (nextIdx >= 0) _revealMatch(nextIdx);
  }

  void _replaceAll() {
    final controller = _unifiedController;
    final query = _findCtrl.text;
    if (controller == null || query.isEmpty) return;
    final rep = _replaceCtrl.text;
    final matches =
        controller.document.search(query, caseSensitive: _findCaseSensitive);
    // Replace from the end so earlier offsets remain valid.
    for (var k = matches.length - 1; k >= 0; k--) {
      controller.replaceText(matches[k], query.length, rep, null);
    }
    setState(() {
      _findMatches = const [];
      _findIndex = -1;
    });
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

    // Spell & Grammar: re-spell on edits (debounced), and run a one-shot pass
    // once the dictionary is ready (whichever is later).
    _lastSpellPlainText = null;
    controller.addListener(_onEditorChanged);
    SpellDictionary.instance.ready.then((_) {
      if (!mounted || _unifiedController != controller) return;
      _squiggleInFlight = true;
      try {
        _runSpellPass();
      } finally {
        _squiggleInFlight = false;
      }
      _lastSpellPlainText = controller.document.toPlainText();
    });

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
        // PDF/EPUB are read-only formats: always render the read paper, never
        // build the editor for them.
        if ((_readMode || (doc is PsittaDocument && doc.isReadOnly)) &&
            doc is PsittaDocument) {
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

  Widget _buildFindBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = _findMatches.length;
    final countText =
        total == 0 ? 'No results' : '${_findIndex + 1} of $total';
    const fieldDecoration = InputDecoration(
      isDense: true,
      border: OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
    return Container(
      color: scheme.onSurface.withOpacity(0.04),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.search, size: 16),
              const SizedBox(width: 6),
              SizedBox(
                width: 230,
                child: TextField(
                  key: const ValueKey('desk-find-field'),
                  controller: _findCtrl,
                  focusNode: _findFocus,
                  decoration: fieldDecoration.copyWith(hintText: 'Find'),
                  // Don't search while typing — wait for Enter. Clear stale
                  // matches so the counter doesn't react to a half-typed word.
                  onChanged: (_) {
                    if (_findMatches.isNotEmpty || _findIndex != -1) {
                      setState(() {
                        _findMatches = const [];
                        _findIndex = -1;
                      });
                    }
                  },
                  // Enter runs the search; Enter again cycles to the next match.
                  onSubmitted: (_) =>
                      _findMatches.isEmpty ? _runFind() : _findNext(),
                ),
              ),
              const SizedBox(width: 8),
              Text(countText,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      )),
              const Spacer(),
              _findToggle(
                tooltip: 'Match case',
                selected: _findCaseSensitive,
                label: 'Aa',
                onTap: () {
                  setState(() => _findCaseSensitive = !_findCaseSensitive);
                  _runFind();
                },
              ),
              IconButton(
                tooltip: 'Previous',
                iconSize: 18,
                icon: const Icon(Icons.keyboard_arrow_up),
                onPressed: _findMatches.isEmpty ? null : _findPrev,
              ),
              IconButton(
                tooltip: 'Next',
                iconSize: 18,
                icon: const Icon(Icons.keyboard_arrow_down),
                onPressed: _findMatches.isEmpty ? null : _findNext,
              ),
              IconButton(
                tooltip: _showReplace ? 'Hide replace' : 'Replace',
                iconSize: 18,
                icon: Icon(
                    _showReplace ? Icons.expand_less : Icons.find_replace),
                onPressed: () => setState(() => _showReplace = !_showReplace),
              ),
              IconButton(
                tooltip: 'Close (Esc)',
                iconSize: 18,
                icon: const Icon(Icons.close),
                onPressed: _closeFind,
              ),
            ],
          ),
          if (_showReplace) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.edit_outlined, size: 16),
                const SizedBox(width: 6),
                SizedBox(
                  width: 230,
                  child: TextField(
                    key: const ValueKey('desk-replace-field'),
                    controller: _replaceCtrl,
                    decoration:
                        fieldDecoration.copyWith(hintText: 'Replace with'),
                    onSubmitted: (_) => _replaceCurrent(),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  key: const ValueKey('desk-replace-one'),
                  onPressed: _findMatches.isEmpty ? null : _replaceCurrent,
                  child: const Text('Replace'),
                ),
                TextButton(
                  key: const ValueKey('desk-replace-all'),
                  onPressed: _findMatches.isEmpty ? null : _replaceAll,
                  child: const Text('Replace all'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _findToggle({
    required String tooltip,
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withOpacity(0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final docAsync = ref.watch(deskDocumentProvider(widget.documentId));

    final title = docAsync.valueOrNull?.title as String?;
    // PDF and EPUB are read-only formats — no Write mode, no editor, no save.
    final isReadOnly = docAsync.valueOrNull?.isReadOnly ?? false;
    // Effective read state: forced on for read-only docs, otherwise the toggle.
    final readMode = _readMode || isReadOnly;
    return ColoredBox(
      color: tokens.surface,
      child: Column(
        children: [
          _DeskCenterHeader(
            key: const ValueKey('desk-center-header'),
            title: (title == null || title.trim().isEmpty) ? 'New file' : title,
            isSaving: _isSaving,
            canSave: _unifiedController != null && !readMode && !isReadOnly,
            onSave: _save,
            readMode: readMode,
            readOnly: isReadOnly,
            onModeChanged: (read) => setState(() => _readMode = read),
            onFind: (!readMode && _unifiedController != null) ? _openFind : null,
          ),
          const Divider(height: 1),
          // The formatting toolbar is edit-only; Read mode hides it.
          if (!readMode && _unifiedController != null) ...[
            buildDocxEditToolbar(
              controller: _unifiedController!,
              theme: Theme.of(context),
              multiRowsDisplay: true,
            ),
            const Divider(height: 1),
          ],
          if (!readMode && _showFind && _unifiedController != null) ...[
            _buildFindBar(context),
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
    this.readOnly = false,
    this.onFind,
  });

  final String title;
  final bool isSaving;
  final bool canSave;
  final VoidCallback onSave;
  final bool readMode;
  final ValueChanged<bool> onModeChanged;

  /// When true the document type cannot be edited (PDF/EPUB): the Write↔Read
  /// toggle is replaced by a static "Read only" chip.
  final bool readOnly;
  final VoidCallback? onFind;

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
            if (onFind != null)
              IconButton(
                key: const ValueKey('desk-find-btn'),
                tooltip: 'Find & Replace (Ctrl+F)',
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.search),
                onPressed: onFind,
              ),
            if (readOnly)
              const _ReadOnlyChip()
            else
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

/// Static badge shown in place of the Write/Read toggle for read-only
/// formats (PDF, EPUB): these open in Read/Listen only.
class _ReadOnlyChip extends StatelessWidget {
  const _ReadOnlyChip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: scheme.onSurface.withOpacity(0.06),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: scheme.outline.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.headphones_outlined,
              size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            'Read only',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

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
        // Spell & Grammar: right-click a misspelled word for suggestions, shown
        // above the editor's default Copy/Cut/Paste menu.
        contextMenuBuilder: _buildSpellContextMenu,
        // Render the transient 'squiggle' attribute as a red wavy underline.
        customStyleBuilder: (attribute) {
          if (attribute.key == 'squiggle') {
            return const TextStyle(
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.wavy,
              decorationColor: Color(0xFFE53935),
            );
          }
          return const TextStyle();
        },
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

  // Editor right-click menu. If the click lands on a misspelled word, suppress
  // the editor's own toolbar and instead pop our own modal suggestions menu
  // (post-frame). The replace then runs AFTER that menu closes — the same path
  // the Reading Nook uses successfully. Applying the edit from inside the
  // editor's own toolbar button gets reverted during overlay teardown.
  Widget _buildSpellContextMenu(
    BuildContext context,
    quill.QuillRawEditorState rawEditorState,
  ) {
    final ctrl = rawEditorState.controller;
    final sel = ctrl.selection;
    if (sel.isValid) {
      final plain = ctrl.document.toPlainText();
      if (plain.isNotEmpty) {
        final off = sel.baseOffset.clamp(0, plain.length - 1);
        final node = ctrl.document.queryChild(off).node;
        if (node is quill.Line) {
          final lineStart = node.documentOffset;
          final lineEnd = (lineStart + node.length).clamp(0, plain.length);
          for (final tok in tokenizeWords(plain.substring(lineStart, lineEnd))) {
            final tokStart = lineStart + tok.start;
            if (off >= tokStart && off <= tokStart + tok.len) {
              if (SpellDictionary.instance.isMisspelled(tok.word)) {
                final word = tok.word;
                final start = tokStart;
                final length = tok.len;
                final anchor = rawEditorState.contextMenuAnchors.primaryAnchor;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  rawEditorState.hideToolbar();
                  _showSpellPopup(context, ctrl, word, start, length, anchor);
                });
                return const SizedBox.shrink();
              }
              break;
            }
          }
        }
      }
    }
    // Not on a misspelled word — show the editor's normal Copy/Cut/Paste menu.
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: rawEditorState.contextMenuAnchors,
      buttonItems: rawEditorState.contextMenuButtonItems,
    );
  }

  // Modal suggestions popup, then a clean replace after it closes.
  Future<void> _showSpellPopup(
    BuildContext context,
    quill.QuillController ctrl,
    String word,
    int start,
    int length,
    Offset anchorGlobal,
  ) async {
    final suggestions = suggest(word).take(6).toList();
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final localAnchor = overlay.globalToLocal(anchorGlobal);
    final position = RelativeRect.fromRect(
      localAnchor & const Size(1, 1),
      Offset.zero & overlay.size,
    );
    final choice = await showMenu<String>(
      context: context,
      position: position,
      items: suggestions.isEmpty
          ? const [
              PopupMenuItem<String>(
                enabled: false,
                child: Text('No suggestions'),
              ),
            ]
          : [
              for (final s in suggestions)
                PopupMenuItem<String>(value: s, child: Text(s)),
            ],
    );
    if (choice == null) return;
    ctrl.replaceText(start, length, choice, null);
    ctrl.updateSelection(
      TextSelection.collapsed(offset: start + choice.length),
      quill.ChangeSource.local,
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

  // Polls the active chunk's alignment sidecar until it lands, so word
  // highlighting (SWH) appears during the FIRST streamed listen — not only on
  // replay. The sidecar is written when the chunk finishes streaming, which (for
  // small chunks) happens a few seconds into playback since synthesis outpaces
  // playback.
  Timer? _alignmentPoll;
  String? _pollingChunkId;

  // Chunks already warmed (audio + alignment prefetched) so we don't re-trigger.
  final Set<String> _warmed = {};

  GlobalKey _pageKey(int pageNumber) =>
      _pageKeys.putIfAbsent(pageNumber, () => GlobalKey());

  // Pre-generate a chunk's audio AND alignment ahead of Play. prefetchChunk
  // hits /audio, which (on cache miss) writes both the mp3 and the alignment
  // sidecar — so by the time the writer presses Play the highlight is ready
  // instead of loading during the read.
  void _warm(String chunkId, String voiceId) {
    if (chunkId.isEmpty || _warmed.contains(chunkId)) return;
    _warmed.add(chunkId);
    ref.read(audioServiceProvider).prefetchChunk(
          documentId: widget.documentId,
          chunkId: chunkId,
          voiceId: voiceId,
        );
  }

  @override
  void dispose() {
    _stopAlignmentPoll();
    _scroll.dispose();
    super.dispose();
  }

  void _stopAlignmentPoll() {
    _alignmentPoll?.cancel();
    _alignmentPoll = null;
    _pollingChunkId = null;
  }

  void _pollAlignment(String chunkId, String voiceId) {
    if (_pollingChunkId == chunkId && _alignmentPoll != null) return;
    _stopAlignmentPoll();
    _pollingChunkId = chunkId;
    var attempts = 0;
    _alignmentPoll = Timer.periodic(const Duration(milliseconds: 1500), (t) {
      attempts++;
      if (!mounted || attempts > 12) {
        _stopAlignmentPoll();
        return;
      }
      final key = AlignmentKey(
        documentId: widget.documentId,
        chunkId: chunkId,
        voiceId: voiceId,
      );
      final current = ref.read(chunkAlignmentProvider(key));
      if (current.valueOrNull?['alignment'] != null) {
        _stopAlignmentPoll(); // loaded — SWH will render
        return;
      }
      ref.invalidate(chunkAlignmentProvider(key));
    });
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

    // Precise seek using the chunk's alignment (exact per-character start
    // times). Proportional (char fraction × duration) undershoots because
    // speech isn't linear — that made playback start ~2 words early.
    int? seekMs;
    try {
      final key = AlignmentKey(
        documentId: widget.documentId,
        chunkId: chunkId,
        voiceId: voiceId,
      );
      // playChunk just wrote the sidecar via /audio; refresh so we read it.
      ref.invalidate(chunkAlignmentProvider(key));
      final payload = await ref
          .read(chunkAlignmentProvider(key).future)
          .timeout(const Duration(seconds: 12));
      final block = payload['alignment'];
      if (block is Map) {
        final na = block['normalized_alignment'];
        if (na is Map) {
          final starts = na['character_start_times_seconds'];
          if (starts is List && starts.isNotEmpty) {
            final idx = charInChunk.clamp(0, starts.length - 1);
            seekMs = ((starts[idx] as num).toDouble() * 1000).round();
          }
        }
      }
    } catch (_) {
      // Fall through to proportional.
    }

    if (seekMs == null) {
      final frac = (charInChunk / c.textLength).clamp(0.0, 0.98);
      final dur = await audioService.player.durationStream
          .firstWhere((d) => d != null && d > Duration.zero)
          .timeout(const Duration(seconds: 12), onTimeout: () => null);
      if (dur != null) seekMs = (frac * dur.inMilliseconds).round();
    }

    if (seekMs != null) {
      await audioService.seek(Duration(milliseconds: seekMs));
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
    final hasAlignment = alignmentPayload['alignment'] != null;
    final isPlaying = ref.watch(audioPlayingProvider).valueOrNull ?? false;

    // SWH on first play: keep polling the active chunk's alignment until it
    // lands (sidecar is written when the chunk finishes streaming). Stop once it
    // loads.
    if (hasAlignment) {
      _stopAlignmentPoll();
    } else if (activeChunkId.isNotEmpty && isPlaying) {
      _pollAlignment(activeChunkId, voiceId);
    }

    // Warm the active chunk + the next ahead of Play so audio AND alignment are
    // cached before listening (removes the first-listen highlight delay).
    if (activeChunkId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _warm(activeChunkId, voiceId);
        final nextIdx = rawIndex + 1;
        if (nextIdx >= 0 && nextIdx < chunkIds.length) {
          _warm(chunkIds[nextIdx], voiceId);
        }
      });
    }

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
