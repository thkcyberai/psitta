import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/state/now_reading.dart';
import '../../core/utils/text_sanitizer.dart';
import '../../data/models/document.dart';
import '../../data/providers/providers.dart';
import '../../data/services/audio_service.dart';
import '../../data/services/preferences_service.dart';
import '../../widgets/document_cover.dart';
import '../editor/chunk_editor_provider.dart';
import '../shell/widgets/player_bar.dart';
import 'widgets/docx_document_editor.dart';
import 'widgets/docx_page_layout.dart';
import 'widgets/page_break_embed.dart';
import 'widgets/docx_document_viewport.dart';
import 'widgets/docx_player_navigator.dart';
import 'widgets/document_reading_view.dart';
import 'widgets/inline_chunk_editor.dart';
import 'widgets/pdf_document_viewport.dart';
import 'widgets/pdf_player_navigator.dart';
import 'widgets/word_highlight_view.dart';
import '../../data/models/document_assembler.dart';
import 'spellcheck/spell_dictionary.dart';
import '../../data/models/psitta_document.dart';
import 'chunk_slicer.dart';

/// Character count above which the unified editor falls back to the
/// legacy per-paragraph architecture. flutter_quill 10.8.x has known
/// typing-latency degradation with single Documents above ~100k chars
/// (GitHub issues #1670, #1842). Above the threshold we continue to
/// render one controller per block, which stays responsive.
const int kUnifiedEditorCharThreshold = 100000;

/// Decide whether a document is small enough to use the unified
/// per-document Quill controller. Measured against the sum of block
/// plain-text lengths so we do not instantiate the unified controller
/// on documents that would stutter.
bool shouldUseUnifiedEditor(PsittaDocument doc) {
  var total = 0;
  for (final block in doc.blocks) {
    total += block.plainText.length;
    if (total > kUnifiedEditorCharThreshold) return false;
  }
  return true;
}

/// Normalize a Quill `color` attribute value to lowercase 6-digit hex
/// without `#`. Accepts `#RRGGBB`, `RRGGBB`, `#AARRGGBB`, `AARRGGBB`,
/// case-insensitive. Returns null on any unparseable shape — the save
/// path then drops the attribute silently rather than poisoning the
/// stored formatted_content with a string the export builder can't feed
/// to `RGBColor.from_string`.
///
/// 8-digit format is what flutter_quill's color picker emits. Its
/// `colorToHex` (color_button.dart:220) computes
/// `color.value.toRadixString(16).padLeft(8, '0')`, and Flutter's
/// `Color.value` is laid out **AARRGGBB** (alpha first). For Material
/// red `0xFFF44336`, the picker emits `"#FFF44336"`, which this
/// normalizer must reduce to `"f44336"` (drop the leading 2 alpha
/// chars), NOT `"fff443"`.
///
/// History: M13.4 Ship 1 originally implemented this assuming CSS
/// `RRGGBBAA` byte order (alpha trailing) and stripped the wrong end,
/// causing red to render as yellow because alpha+R+G was kept and B
/// was discarded. Corrected after manual testing surfaced the symptom.
String? _normalizeHexColor(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  final body = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
  if (body.length != 6 && body.length != 8) return null;
  for (int i = 0; i < 6; i++) {
    final c = body.codeUnitAt(i);
    final isDigit = c >= 0x30 && c <= 0x39;
    final isHexLower = c >= 0x61 && c <= 0x66;
    final isHexUpper = c >= 0x41 && c <= 0x46;
    if (!isDigit && !isHexLower && !isHexUpper) return null;
  }
  return (body.length == 8 ? body.substring(2) : body).toLowerCase();
}

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    super.key,
    required this.documentId,
    this.originProjectId,
    this.originProjectName,
  });

  final String documentId;
  final String? originProjectId;
  final String? originProjectName;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _hasAutoPlayed = false;
  ProviderSubscription<int>? _chunkIndexSub;
  ProviderSubscription<String>? _voiceSub;
  ProviderSubscription<AsyncValue<bool>>? _audioPlayingSub;
  ProviderSubscription<AsyncValue<Duration>>? _audioPositionSub;

  // Captured early so dispose() can use them without ref.read()
  AudioService? _audioService;
  StateController<String>? _nowReadingController;

  final ScrollController _contentScrollController = ScrollController();
  bool _userScrolling = false;
  List<dynamic>? _activeSentenceBoundaries;
  final Map<String, GlobalKey> _docBlockKeys = {};
  final Map<int, GlobalKey> _docxPageKeys = {};
  final GlobalKey _docScrollViewportKey = GlobalKey();
  int _currentDocxPageNumber = 1;
  int _activeReadingPageNumber = 1;
  Map<GlobalKey, int> _blockKeyToPage = {};
  // blockId → page map (mode-independent, rebuilt per-frame from docxPages).
  // Used by edit-mode find to resolve a match's page for thumbnail-follow
  // without depending on the reading view's GlobalKey registry being mounted.
  Map<String, int> _docxBlockPageMap = const {};
  int _docxDragTargetPageNumber = 1;
  double _docxThumbProgress = 0.0;
  int? _focusedDocxSentenceIndex;
  bool _hasPendingDocxJump = false;
  int? _pendingDocxJumpTargetMs;
  int _docxJumpRequestSeq = 0;
  final PdfViewerController _pdfViewerController = PdfViewerController();
  PdfDocumentRef? _pdfDocumentRef;
  List<PdfOutlineNode>? _pdfOutline;
  int? _focusedPdfChunkIndex;
  int? _focusedPdfSentenceIndex;
  int? _lastAutoFollowedPdfPage;
  int? _lastPdfPrefetchedChunkIndex;
  String? _clearedPdfPlaybackCacheKey;
  bool _hasPendingPdfJump = false;
  int? _pendingPdfJumpTargetMs;
  int _pdfJumpRequestSeq = 0;

  // ── Ctrl+scroll zoom state ─────────────────────────────────────────
  double _textScale = 1.0;

  // ── Find-in-document state ─────────────────────────────────────────
  bool _showFindBar = false;
  // Query typed before the PDF document / viewer is ready. Replayed once
  // onDocumentLoaded fires or the PdfViewerController becomes ready.
  String _pendingFindQuery = '';
  VoidCallback? _pdfReadyListener;
  final TextEditingController _findController = TextEditingController();
  final FocusNode _findFocusNode = FocusNode();
  final FocusNode _findShortcutFocusNode = FocusNode(
    debugLabel: 'PlayerScreen-FindShortcut',
    skipTraversal: true,
  );
  PdfTextSearcher? _pdfTextSearcher;
  // DOCX match state: list of block IDs containing the query, current index.
  List<String> _docxFindBlockIds = const [];
  int _docxFindIndex = -1;
  // Reading-mode current-match doc-offset range (first occurrence in the
  // current match block) for DocumentReadingView word highlighting.
  int? _docxFindMatchStart;
  int? _docxFindMatchEnd;
  // Edit-mode (unified DOCX) find state — character-offset matches in the
  // live Quill document. Separate from the block-granular reading-mode
  // state above; never reuse one for the other.
  List<int> _editMatchOffsets = const [];
  int _editMatchIndex = -1;
  bool _findCaseSensitive = false;
  // Replace (DOCX edit-unified only). The replace row is click-to-expand via
  // _findExpanded; the chevron + row never show in PDF/reading-mode find.
  final TextEditingController _replaceController = TextEditingController();
  bool _findExpanded = false;
  // Key on the unified editor's EditorState — lets find scroll a match into
  // view via renderEditor.getLocalRectForCaret (public per flutter_quill).
  final GlobalKey<quill.EditorState> _unifiedEditorKey =
      GlobalKey<quill.EditorState>();
  // Latest PsittaDocument rendered by the data builder — captured so the
  // find-bar shortcut callbacks can access it outside the builder scope.
  PsittaDocument? _currentPsittaDoc;

  void _handleCtrlScroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!HardwareKeyboard.instance.isControlPressed) return;

    final resolvedDoc = _resolveDocument(ref);
    final isPdf = (resolvedDoc?.sourceType.toLowerCase() ?? '') == 'pdf';

    if (isPdf) {
      if (event.scrollDelta.dy < 0) {
        _pdfViewerController.zoomUp();
      } else if (event.scrollDelta.dy > 0) {
        _pdfViewerController.zoomDown();
      }
    } else {
      setState(() {
        if (event.scrollDelta.dy < 0) {
          _textScale = (_textScale + 0.1).clamp(0.5, 3.0);
        } else if (event.scrollDelta.dy > 0) {
          _textScale = (_textScale - 0.1).clamp(0.5, 3.0);
        }
      });
    }
  }

  // ── Find-in-document ───────────────────────────────────────────────

  /// Intercepts Ctrl+F / Escape at the Flutter key-event layer.
  ///
  /// This is used by both the wrapper [KeyboardListener] (for events that
  /// bubble up through the Player subtree's focus chain) and the global
  /// [HardwareKeyboard] handler registered in [initState] (for events
  /// that reach Flutter while focus is held by a descendant that does
  /// not forward keys through the focus chain — e.g. the PDFium native
  /// view). Returns true when the event should be considered handled.
  bool _tryHandleFindShortcut(KeyEvent event) {
    if (!mounted) return false;
    if (event is! KeyDownEvent) return false;
    final kb = HardwareKeyboard.instance;
    if (event.logicalKey == LogicalKeyboardKey.keyF && kb.isControlPressed) {
      _openFindBar();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape && _showFindBar) {
      _closeFindBar();
      return true;
    }
    return false;
  }

  /// Global [HardwareKeyboard] handler — fires for every key event
  /// regardless of which widget currently holds focus. Registered while
  /// this [State] is mounted.
  bool _handleHardwareKey(KeyEvent event) {
    return _tryHandleFindShortcut(event);
  }

  /// [KeyboardListener.onKeyEvent] callback — receives events bubbled up
  /// through the Focus chain when focus is within the Player subtree.
  void _handleKeyboardListener(KeyEvent event) {
    _tryHandleFindShortcut(event);
  }

  void _openFindBar() {
    if (_showFindBar) {
      _findFocusNode.requestFocus();
      return;
    }
    setState(() => _showFindBar = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _findFocusNode.requestFocus();
      _findController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _findController.text.length,
      );
    });
  }

  void _closeFindBar() {
    if (!_showFindBar) return;
    _findController.clear();
    _replaceController.clear();
    _findExpanded = false;
    _pdfTextSearcher?.resetTextSearch();
    _pendingFindQuery = '';
    final readyListener = _pdfReadyListener;
    if (readyListener != null) {
      _pdfViewerController.removeListener(readyListener);
      _pdfReadyListener = null;
    }
    setState(() {
      _showFindBar = false;
      _docxFindBlockIds = const [];
      _docxFindIndex = -1;
      _docxFindMatchStart = null;
      _docxFindMatchEnd = null;
    });
    _findShortcutFocusNode.requestFocus();
  }

  PdfTextSearcher _ensurePdfSearcher() {
    final existing = _pdfTextSearcher;
    if (existing != null) return existing;
    final searcher = PdfTextSearcher(_pdfViewerController)
      ..addListener(_onPdfSearcherChanged);
    _pdfTextSearcher = searcher;
    return searcher;
  }

  void _onPdfSearcherChanged() {
    if (!mounted) return;
    setState(() {}); // refresh "X of Y" indicator + find highlight
  }

  /// Current PDF find match (for highlight painting in the viewport). Scroll
  /// and page-tracking are handled by the searcher's goToMatchOfIndex.
  PdfTextRangeWithFragments? get _currentPdfFindMatch {
    final s = _pdfTextSearcher;
    final i = s?.currentIndex;
    if (s == null || i == null || i < 0 || i >= s.matches.length) return null;
    return s.matches[i];
  }

  void _onFindQueryChanged(String query) {
    final trimmed = query;
    final resolvedDoc = _resolveDocument(ref);
    final isPdfDocument =
        (resolvedDoc?.sourceType.toLowerCase() ?? '') == 'pdf';

    // PDF path
    if (isPdfDocument) {
      // Document not yet loaded — stash the query and replay it from
      // onDocumentLoaded. Must not fall through to the DOCX branch, which
      // would return "0 of 0" against an empty PsittaDocument.
      if (_pdfDocumentRef == null) {
        _pendingFindQuery = trimmed;
        return;
      }
      final searcher = _ensurePdfSearcher();
      if (trimmed.isEmpty) {
        searcher.resetTextSearch();
        _pendingFindQuery = '';
        return;
      }
      // The PdfViewerController may not be attached to the viewport yet
      // even after the document ref is resolved (first-frame race). If
      // isReady is false, startTextSearch silently no-ops, so stash the
      // query and retry via a one-shot controller listener.
      if (!_pdfViewerController.isReady) {
        _pendingFindQuery = trimmed;
        if (_pdfReadyListener == null) {
          void listener() {
            if (!mounted) return;
            if (!_pdfViewerController.isReady) return;
            final pending = _pendingFindQuery;
            final existing = _pdfReadyListener;
            if (existing != null) {
              _pdfViewerController.removeListener(existing);
              _pdfReadyListener = null;
            }
            if (pending.isNotEmpty) {
              _onFindQueryChanged(pending);
            }
          }
          _pdfReadyListener = listener;
          _pdfViewerController.addListener(listener);
        }
        return;
      }
      _pendingFindQuery = '';
      searcher.startTextSearch(
        trimmed,
        caseInsensitive: true,
        searchImmediately: true,
      );
      return;
    }
    // Edit-mode (unified DOCX) path — search the live Quill document by
    // character offset and navigate via native selection. Kept ahead of the
    // reading-mode block scan below, which targets the static PsittaDocument
    // and cannot select inside the live editor.
    if (_isEditing && _docxUnifiedController != null) {
      final q = query.trim();
      if (q.isEmpty) {
        setState(() {
          _editMatchOffsets = const [];
          _editMatchIndex = -1;
        });
        return;
      }
      final offs = _docxUnifiedController!.document.search(
        q,
        caseSensitive: _findCaseSensitive,
      );
      setState(() {
        _editMatchOffsets = offs;
        _editMatchIndex = offs.isEmpty ? -1 : 0;
      });
      if (offs.isNotEmpty) _moveToEditMatch(0);
      return;
    }

    // DOCX path
    final psittaDoc = _currentPsittaDoc;
    if (psittaDoc == null) return;
    if (trimmed.isEmpty) {
      setState(() {
        _docxFindBlockIds = const [];
        _docxFindIndex = -1;
        _docxFindMatchStart = null;
        _docxFindMatchEnd = null;
      });
      return;
    }
    final needle = trimmed.toLowerCase();
    final hits = <String>[];
    for (final block in psittaDoc.blocks) {
      if (block.plainText.toLowerCase().contains(needle)) {
        hits.add(block.blockId);
      }
    }
    setState(() {
      _docxFindBlockIds = hits;
      _docxFindIndex = hits.isEmpty ? -1 : 0;
    });
    if (hits.isNotEmpty) {
      _scrollToDocxFindMatch();
    }
  }

  /// Move the live-editor selection to edit-match [i] and let the focused
  /// editor scroll it into view (mirrors the built-in search_dialog
  /// _moveToPosition). The native selection is the current-match highlight.
  void _moveToEditMatch(int i) {
    final controller = _docxUnifiedController;
    if (controller == null) return;
    if (i < 0 || i >= _editMatchOffsets.length) return;
    final off = _editMatchOffsets[i];
    final len = _findController.text.trim().length;
    if (len <= 0) return;
    controller.updateSelection(
      TextSelection(baseOffset: off, extentOffset: off + len),
      quill.ChangeSource.local,
    );
    _revealEditMatch(off);

    // Thumbnail-follow: map the match offset → block → page so the navigator
    // panel's active page tracks find in edit mode (the panel renders in both
    // modes). Written ONLY on navigation so find doesn't fight playback's page
    // tracking. (Coarse: the offset is in Quill-document space while blocks are
    // in doc.plainText space, so near block boundaries the page may be off by
    // one — acceptable for a page-level rail.)
    final doc = _editingDocxDocument ?? _currentPsittaDoc;
    final block = doc?.blockForOffset(off);
    final page = block == null ? null : _docxBlockPageMap[block.blockId];
    if (page != null && page != _activeReadingPageNumber) {
      setState(() => _activeReadingPageNumber = page);
    }
  }

  /// Scroll the current edit-mode match into view via the OUTER content
  /// scroll controller (spike-confirmed owner of on-screen scroll in edit
  /// mode). The match's caret rect comes from the editor's RenderEditor
  /// (public via [_unifiedEditorKey].currentState.renderEditor); mapping it to
  /// global coords lets us compare against the scroll viewport without manual
  /// accounting for the sheet padding / leading static blocks above the
  /// editor. Scrolls only when the match is outside the viewport. Touches no
  /// focus (find field keeps it) and no document content (no unsaved flag).
  void _revealEditMatch(int off) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final editorState = _unifiedEditorKey.currentState;
      final scrollCtrl = _contentScrollController;
      if (editorState == null || !scrollCtrl.hasClients) return;
      final viewportObj =
          _docScrollViewportKey.currentContext?.findRenderObject();
      if (viewportObj is! RenderBox || !viewportObj.attached) return;

      final renderEditor = editorState.renderEditor;
      final caretRect =
          renderEditor.getLocalRectForCaret(TextPosition(offset: off));
      final caretTop = renderEditor.localToGlobal(caretRect.topLeft).dy;
      final caretBottom = renderEditor.localToGlobal(caretRect.bottomLeft).dy;
      final viewTop = viewportObj.localToGlobal(Offset.zero).dy;
      final viewBottom = viewTop + viewportObj.size.height;

      // Comfortable margins: top clears the sticky toolbar + find bar.
      const topMargin = 96.0;
      const bottomMargin = 48.0;
      double? target;
      if (caretTop < viewTop + topMargin) {
        target = scrollCtrl.offset - ((viewTop + topMargin) - caretTop);
      } else if (caretBottom > viewBottom - bottomMargin) {
        target = scrollCtrl.offset + (caretBottom - (viewBottom - bottomMargin));
      }
      if (target == null) return; // already comfortably visible

      final pos = scrollCtrl.position;
      final clamped =
          target.clamp(pos.minScrollExtent, pos.maxScrollExtent).toDouble();
      if ((clamped - scrollCtrl.offset).abs() < 1.0) return;
      scrollCtrl.animateTo(
        clamped,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _nextFindMatch() {
    if (_pdfDocumentRef != null) {
      // pdfrx goToNextMatch advances currentIndex + scrolls but never
      // notifyListeners(), so refresh the UI ourselves; otherwise (idle) the
      // counter + highlight only update when the playback loop forces a build.
      final s = _pdfTextSearcher;
      if (s == null) return;
      unawaited(s.goToNextMatch().then((_) {
        if (mounted) setState(() {});
      }));
      return;
    }
    if (_isEditing && _docxUnifiedController != null) {
      if (_editMatchOffsets.isEmpty) return;
      setState(() {
        _editMatchIndex = (_editMatchIndex + 1) % _editMatchOffsets.length;
      });
      _moveToEditMatch(_editMatchIndex);
      return;
    }
    if (_docxFindBlockIds.isEmpty) return;
    setState(() {
      _docxFindIndex = (_docxFindIndex + 1) % _docxFindBlockIds.length;
    });
    _scrollToDocxFindMatch();
  }

  void _prevFindMatch() {
    if (_pdfDocumentRef != null) {
      // See _nextFindMatch: refresh after nav since pdfrx doesn't notify.
      final s = _pdfTextSearcher;
      if (s == null) return;
      unawaited(s.goToPrevMatch().then((_) {
        if (mounted) setState(() {});
      }));
      return;
    }
    if (_isEditing && _docxUnifiedController != null) {
      if (_editMatchOffsets.isEmpty) return;
      setState(() {
        _editMatchIndex =
            (_editMatchIndex - 1 + _editMatchOffsets.length) %
                _editMatchOffsets.length;
      });
      _moveToEditMatch(_editMatchIndex);
      return;
    }
    if (_docxFindBlockIds.isEmpty) return;
    setState(() {
      _docxFindIndex = (_docxFindIndex - 1 + _docxFindBlockIds.length) %
          _docxFindBlockIds.length;
    });
    _scrollToDocxFindMatch();
  }

  void _scrollToDocxFindMatch() {
    if (_docxFindIndex < 0 || _docxFindIndex >= _docxFindBlockIds.length) {
      return;
    }
    final blockId = _docxFindBlockIds[_docxFindIndex];
    final key = _docBlockKeys[blockId];

    // Reading-mode word highlight + thumbnail-follow: compute the current
    // match's doc-offset range (first occurrence in the block) and the block's
    // page, then update both in one setState. Writing _activeReadingPageNumber
    // ONLY here (on navigation) keeps find from fighting playback's page track.
    final doc = _currentPsittaDoc;
    final needle = _findController.text.trim().toLowerCase();
    int? matchStart;
    int? matchEnd;
    int? matchPage;
    if (doc != null && needle.isNotEmpty) {
      for (final b in doc.blocks) {
        if (b.blockId != blockId) continue;
        final idx = b.plainText.toLowerCase().indexOf(needle);
        if (idx >= 0) {
          matchStart = b.textOffset + idx;
          matchEnd = matchStart + needle.length;
        }
        break;
      }
      if (key != null) matchPage = _blockKeyToPage[key];
    }
    if (matchStart != _docxFindMatchStart ||
        matchEnd != _docxFindMatchEnd ||
        (matchPage != null && matchPage != _activeReadingPageNumber)) {
      setState(() {
        _docxFindMatchStart = matchStart;
        _docxFindMatchEnd = matchEnd;
        if (matchPage != null) _activeReadingPageNumber = matchPage;
      });
    }

    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );
    }

    // Cursor positioning is only meaningful while editing — QuillEditor
    // is only live in DOCX edit mode. In read mode we keep
    // navigation-only behavior.
    if (!_isEditing || _editingDocxDocument == null) return;

    final controller = _docxBlockControllers[blockId];
    final focusNode = _docxBlockFocusNodes[blockId];
    if (controller == null || focusNode == null) return;

    final query = _findController.text;
    if (query.isEmpty) return;

    final plainText = controller.document.toPlainText();
    final matchOffset =
        plainText.toLowerCase().indexOf(query.toLowerCase());
    if (matchOffset < 0) return;

    controller.updateSelection(
      TextSelection.collapsed(offset: matchOffset),
      quill.ChangeSource.local,
    );
    // Defer focus request until after the current frame so the
    // ensureVisible scroll and selection update have been applied.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      focusNode.requestFocus();
    });
  }

  /// Replace the current edit-mode match with the replace field's text, then
  /// re-search and advance to the next occurrence past the replacement. DOCX
  /// edit-unified only. The default-notify replaceText flags unsaved via the
  /// existing controller-listener chain (no manual dirty bump needed).
  void _replaceCurrent() {
    final controller = _docxUnifiedController;
    if (!_isEditing || controller == null) return;
    if (_editMatchOffsets.isEmpty) return;
    if (_editMatchIndex < 0 || _editMatchIndex >= _editMatchOffsets.length) {
      return;
    }
    final query = _findController.text.trim();
    if (query.isEmpty) return;

    final off = _editMatchOffsets[_editMatchIndex];
    final repl = _replaceController.text;
    controller.replaceText(off, query.length, repl, null);

    // The replacement shifts every later offset by (repl.length -
    // query.length); re-search to refresh the offsets from the live document.
    final fresh = controller.document.search(
      query,
      caseSensitive: _findCaseSensitive,
    );
    // Advance to the first match at/after the end of the inserted text so we
    // don't re-hit the replacement (which may itself contain the query). If
    // none remain ahead, wrap to the first match only when matches still exist.
    final boundary = off + repl.length;
    var newIndex = fresh.indexWhere((o) => o >= boundary);
    if (newIndex < 0) newIndex = fresh.isEmpty ? -1 : 0;

    setState(() {
      _editMatchOffsets = fresh;
      _editMatchIndex = newIndex;
    });
    if (newIndex >= 0) _moveToEditMatch(newIndex);
  }

  Widget _buildFindBar({
    required ThemeData theme,
    required bool isPdfDocument,
  }) {
    final int totalMatches;
    final int currentMatch;
    if (_isEditing && _docxUnifiedController != null) {
      totalMatches = _editMatchOffsets.length;
      currentMatch =
          (_editMatchIndex < 0 || totalMatches == 0) ? 0 : _editMatchIndex + 1;
    } else if (isPdfDocument) {
      final searcher = _pdfTextSearcher;
      totalMatches = searcher?.matches.length ?? 0;
      final idx = searcher?.currentIndex;
      currentMatch = (idx == null || totalMatches == 0) ? 0 : idx + 1;
    } else {
      totalMatches = _docxFindBlockIds.length;
      currentMatch =
          (_docxFindIndex < 0 || totalMatches == 0) ? 0 : _docxFindIndex + 1;
    }
    final hasQuery = _findController.text.isNotEmpty;
    final countLabel =
        hasQuery ? '$currentMatch of $totalMatches' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.search,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _findController,
                  focusNode: _findFocusNode,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  style: theme.textTheme.bodyMedium,
                  decoration: const InputDecoration(
                    hintText: 'Find in document',
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  onChanged: _onFindQueryChanged,
                  onSubmitted: (_) => _nextFindMatch(),
                ),
              ),
              if (hasQuery) ...[
                Text(
                  countLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: totalMatches == 0
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 4),
              ],
              // Expand/collapse the replace row — edit-unified only (Replace
              // is a live-editor operation; never offered in PDF/reading find).
              // "R" glyph styled to pair with the "Aa" toggle; selected state
              // (subtle highlight) reflects _findExpanded just like Aa.
              if (_isEditing && _docxUnifiedController != null)
                IconButton(
                  icon: const Text(
                    'R',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  tooltip: 'Replace',
                  visualDensity: VisualDensity.compact,
                  isSelected: _findExpanded,
                  onPressed: () =>
                      setState(() => _findExpanded = !_findExpanded),
                ),
              // Case-sensitivity toggle — edit-mode only (reading-mode/PDF find
              // is case-insensitive by design; _findCaseSensitive drives only
              // the unified-editor search branch).
              if (_isEditing && _docxUnifiedController != null)
                IconButton(
                  icon: const Text(
                    'Aa',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  tooltip: 'Match case',
                  visualDensity: VisualDensity.compact,
                  isSelected: _findCaseSensitive,
                  onPressed: () {
                    setState(() => _findCaseSensitive = !_findCaseSensitive);
                    _onFindQueryChanged(_findController.text);
                  },
                ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                tooltip: 'Previous match',
                visualDensity: VisualDensity.compact,
                onPressed: totalMatches == 0 ? null : _prevFindMatch,
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                tooltip: 'Next match',
                visualDensity: VisualDensity.compact,
                onPressed: totalMatches == 0 ? null : _nextFindMatch,
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Close (Esc)',
                visualDensity: VisualDensity.compact,
                onPressed: _closeFindBar,
              ),
            ],
          ),
          // Replace row — DOCX edit-unified only, revealed by the chevron.
          if (_findExpanded && _isEditing && _docxUnifiedController != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.find_replace,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _replaceController,
                      style: theme.textTheme.bodyMedium,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        hintText: 'Replace with…',
                        isDense: true,
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _replaceCurrent(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: theme.colorScheme.primary,
                    ),
                    onPressed: totalMatches == 0 ? null : _replaceCurrent,
                    child: const Text('Replace'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Inline editing state ─────────────────────────────────────────
  bool _autoEditPending = true; // checked once on first data load
  bool _isEditing = false;
  String _editingChunkId = '';
  String _originalText = '';
  bool _hasUnsavedChanges = false;
  final TextEditingController _editController = TextEditingController();
  final FocusNode _editFocusNode = FocusNode();
  final Map<String, quill.QuillController> _docxBlockControllers = {};
  // Long-lived focus nodes, one per block — owned by the Player state so
  // find-in-document can request focus on a specific block's QuillEditor
  // (cursor positioning for DOCX matches).
  final Map<String, FocusNode> _docxBlockFocusNodes = {};
  final Map<String, String> _docxOriginalBlockTexts = {};
  final Map<String, String> _docxOriginalChunkTexts = {};
  final Map<String, String> _docxBlockChunkIds = {};
  // Pre-edit formatted-content snapshots — used by onChanged + _saveDocxEdit
  // so formatting-only edits (e.g. bolding an already-present word) are
  // detected as dirty state and persisted end-to-end. Keyed by blockId and
  // chunkId respectively to mirror the plain-text snapshots above.
  final Map<String, Map<String, dynamic>> _docxOriginalBlockFormatted = {};
  final Map<String, List<Map<String, dynamic>>> _docxOriginalChunkFormatted = {};
  PsittaDocument? _editingDocxDocument;
  quill.QuillController? _activeDocxController;

  // ── M13.1a unified editor state ─────────────────────────────────────
  // When active, _docxUnifiedEditMode is true and _docxBlockControllers
  // stays empty; the whole document lives in the single unified
  // controller below. When false, the legacy per-paragraph path is used
  // (kept as a fallback for documents above kUnifiedEditorCharThreshold
  // and as the first-year safety net for M13.1a).
  bool _docxUnifiedEditMode = false;
  quill.QuillController? _docxUnifiedController;
  FocusNode? _docxUnifiedFocusNode;
  // Pre-edit snapshot of the flat block-dict list — used by onChanged to
  // detect dirty state and by _saveDocxEditUnified to compare against
  // the current serialized document.
  List<Map<String, dynamic>> _docxOriginalUnifiedBlockDicts = const [];
  String _docxOriginalUnifiedPlainText = '';

  // ── SG3b live spellcheck ────────────────────────────────────────────
  // Debounce timer for the live re-check; reentrancy guard so the spell
  // pass's own notifying formatText can't schedule another tick (the
  // change callback fires synchronously inside the pass); and the raw
  // plain text at the last pass (raw toPlainText, NOT the sanitized
  // _docxOriginalUnifiedPlainText) so an attribute-only notify early-outs.
  Timer? _spellDebounce;
  bool _squiggleInFlight = false;
  String? _lastSpellPlainText;

  @override
  void initState() {
    super.initState();
    // Global key interception — reliable when focus is held by a
    // descendant PlatformView (PDF viewer) or QuillEditor that sits
    // outside this State's Focus subtree. Only registered while the
    // Player screen is mounted, so it doesn't affect other screens.
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    _editController.addListener(_onEditTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeDocumentIdProvider.notifier).state = widget.documentId;
      _audioService = ref.read(audioServiceProvider);
      _nowReadingController = ref.read(nowReadingTextProvider.notifier);
      // Title resolved immediately if docs already loaded, or via listener below
      _resolveTitle();
      _initSession();
    });

    // Listen for documentsProvider to finish loading and update title
    ref.listenManual<AsyncValue<List<dynamic>>>(documentsProvider, (_, next) {
      next.whenData((_) => _resolveTitle());
    });

    _chunkIndexSub =
        ref.listenManual<int>(currentChunkIndexProvider, (prev, next) {
      if (prev != next) {
        debugPrint('[PlayerScreen] currentChunkIndexProvider: $prev -> $next');
      }
    });

    _voiceSub =
        ref.listenManual<String>(selectedVoiceIdProvider, (previous, next) {
      if (previous != null && previous != next) {
        // Voice-change replay handled via PlayerBar / AudioService.
      }
    });

    _audioPlayingSub =
        ref.listenManual<AsyncValue<bool>>(audioPlayingProvider, (prev, next) {
      final wasPlaying = prev?.valueOrNull ?? false;
      final isPlaying = next.valueOrNull ?? false;
      if (!wasPlaying &&
          isPlaying &&
          mounted &&
          _hasPendingDocxJump &&
          _pendingDocxJumpTargetMs == null) {
        setState(() {
          _hasPendingDocxJump = false;
          _pendingDocxJumpTargetMs = null;
        });
      }
    });

    _audioPositionSub = ref
        .listenManual<AsyncValue<Duration>>(audioPositionProvider, (_, next) {
      final position = next.valueOrNull;
      if (!mounted || position == null || !(_audioService?.isPlaying ?? false)) {
        return;
      }

      final docxTargetMs = _pendingDocxJumpTargetMs;
      if (_hasPendingDocxJump && docxTargetMs != null) {
        final delta = (position.inMilliseconds - docxTargetMs).abs();
        if (delta <= 350 || position.inMilliseconds > docxTargetMs) {
          setState(() {
            _hasPendingDocxJump = false;
            _pendingDocxJumpTargetMs = null;
          });
        }
      }

      final pdfTargetMs = _pendingPdfJumpTargetMs;
      if (_hasPendingPdfJump && pdfTargetMs != null) {
        final delta = (position.inMilliseconds - pdfTargetMs).abs();
        if (delta <= 350 || position.inMilliseconds > pdfTargetMs) {
          setState(() {
            _hasPendingPdfJump = false;
            _pendingPdfJumpTargetMs = null;
          });
        }
      }
    });
  }

  int _restorePositionMs = 0;

  Future<void> _initSession() async {
    try {
      final repo = ref.read(playbackRepositoryProvider);
      final voiceId = ref.read(selectedVoiceIdProvider);
      final speed = ref.read(selectedSpeedProvider);
      final session = await repo.createSession(
        documentId: widget.documentId,
        voiceId: voiceId,
        speed: speed,
      );
      // Restore chunk index from last session
      if (!_hasAutoPlayed && session.currentChunkIndex > 0) {
        ref.read(currentChunkIndexProvider.notifier).state =
            session.currentChunkIndex;
      }

      // Store position for seek-after-play
      _restorePositionMs = session.positionMs;

      // Start tracking immediately — don't wait for autoplay
      final audioService = ref.read(audioServiceProvider);
      final idx = ref.read(currentChunkIndexProvider);
      audioService.startPositionTracking(
        sessionId: session.id,
        chunkIndex: idx,
        repository: repo,
      );

      // ── Eager PDF prefetch ──────────────────────────────────────────
      // For PDF documents, synthesize the first 2 chunks immediately so
      // audio is ready by the time the user clicks Play.
      // DOCX is excluded — it already loads in ~1 second.
      _eagerPrefetchPdfChunks(voiceId: voiceId, startIndex: idx);
    } catch (e) {
      debugPrint('[PlayerScreen] Session init failed: $e');
    }
  }

  /// Fire-and-forget prefetch of first 2 PDF chunks on player open.
  /// Only runs for PDF documents. DOCX is never touched.
  Future<void> _eagerPrefetchPdfChunks({
    required String voiceId,
    required int startIndex,
  }) async {
    try {
      // Resolve document type — only proceed for PDF
      final docs = ref.read(documentsProvider).valueOrNull;
      if (docs == null) return;
      dynamic resolvedDoc;
      for (final doc in docs) {
        if (doc.id == widget.documentId) {
          resolvedDoc = doc;
          break;
        }
      }
      if (resolvedDoc == null) return;
      final sourceType = (resolvedDoc.sourceType ?? '').toString().toLowerCase();
      if (sourceType != 'pdf') return;

      // Fetch chunks and prefetch first 2 starting from current index
      final chunks = await ref.read(chunksProvider(widget.documentId).future);
      if (!mounted) return;

      final audioService = ref.read(audioServiceProvider);
      final prefetchCount = 2;
      for (int i = startIndex; i < startIndex + prefetchCount && i < chunks.length; i++) {
        final chunk = chunks[i] as Map<String, dynamic>;
        final chunkId = (chunk['id'] ?? '').toString();
        if (chunkId.isEmpty) continue;
        debugPrint('[PDF PREFETCH] eager prefetch chunk $i id=$chunkId');
        unawaited(audioService.prefetchChunk(
          documentId: widget.documentId,
          chunkId: chunkId,
          voiceId: voiceId,
        ));
      }
    } catch (e) {
      debugPrint('[PDF PREFETCH] eager prefetch failed: $e');
    }
  }

  void _resolveTitle() {
    final docs = ref.read(documentsProvider).valueOrNull;
    if (docs == null) return;
    String docTitle = widget.documentId;
    for (final doc in docs) {
      if (doc.id == widget.documentId) {
        docTitle = doc.title;
        break;
      }
    }
    ref.read(currentDocTitleProvider.notifier).state = docTitle;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _spellDebounce?.cancel(); // SG3b (fuller teardown in SG3b.2)
    _editController.removeListener(_onEditTextChanged);
    _editController.dispose();
    _editFocusNode.dispose();
    _findController.dispose();
    _replaceController.dispose();
    _findFocusNode.dispose();
    _findShortcutFocusNode.dispose();
    _pdfTextSearcher?.removeListener(_onPdfSearcherChanged);
    _pdfTextSearcher?.dispose();
    _pdfTextSearcher = null;
    for (final node in _docxBlockFocusNodes.values) {
      node.dispose();
    }
    _docxBlockFocusNodes.clear();
    _contentScrollController.dispose();
    _chunkIndexSub?.close();
    _voiceSub?.close();
    _audioPlayingSub?.close();
    _audioPositionSub?.close();
    _audioService?.stopPositionTracking();
    // Defer provider modification past the current build frame to avoid
    // "Tried to modify a provider while the widget tree was building".
    final controller = _nowReadingController;
    if (controller != null) {
      Future.microtask(() => controller.state = '');
    }
    super.dispose();
  }

  // ── Inline editing helpers ───────────────────────────────────────

  void _onEditTextChanged() {
    final changed =
        sanitizeForTts(_editController.text) != sanitizeForTts(_originalText);
    if (changed != _hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = changed);
    }
  }

  void _enterEditMode(String chunkId, String chunkText) {
    final audioService = ref.read(audioServiceProvider);
    audioService.pause();
    ref.read(isInlineEditingProvider.notifier).state = true;
    setState(() {
      _isEditing = true;
      _editingChunkId = chunkId;
      _originalText = chunkText;
      _editController.text = chunkText;
      _editController.selection = const TextSelection.collapsed(offset: 0);
      _hasUnsavedChanges = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editFocusNode.requestFocus();
      if (_contentScrollController.hasClients) {
        _contentScrollController.jumpTo(0);
      }
    });
  }

  /// Enter DOCX edit mode. Dispatches to the unified editor when the
  /// document fits under [kUnifiedEditorCharThreshold], otherwise falls
  /// back to the legacy per-paragraph editor. Shared pre-flight steps
  /// (pause audio, close find bar, flip the global editing provider)
  /// happen once in this dispatcher.
  void _enterDocxEditMode(
    PsittaDocument document,
    List<dynamic> rawChunks,
  ) {
    if (_showFindBar) _closeFindBar();
    final audioService = ref.read(audioServiceProvider);
    audioService.pause();
    ref.read(isInlineEditingProvider.notifier).state = true;

    if (shouldUseUnifiedEditor(document)) {
      _enterDocxEditModeUnified(document, rawChunks);
    } else {
      _enterDocxEditModePerParagraph(document, rawChunks);
    }
  }

  /// Legacy per-paragraph edit mode. One QuillController per DocBlock.
  /// Kept for large documents (> [kUnifiedEditorCharThreshold] chars)
  /// where the unified Quill Document would stutter. All fields this
  /// method populates are mutually exclusive with the unified path.
  void _enterDocxEditModePerParagraph(
    PsittaDocument document,
    List<dynamic> rawChunks,
  ) {
    for (final controller in _docxBlockControllers.values) {
      controller.dispose();
    }
    for (final node in _docxBlockFocusNodes.values) {
      node.dispose();
    }
    _docxBlockControllers.clear();
    _docxBlockFocusNodes.clear();
    _docxOriginalBlockTexts.clear();
    _docxOriginalChunkTexts.clear();
    _docxBlockChunkIds.clear();
    _docxOriginalBlockFormatted.clear();
    _docxOriginalChunkFormatted.clear();

    for (final block in document.blocks) {
      final text = block.plainText;
      _docxOriginalBlockTexts[block.blockId] = text;
      // Build a block-dict view of the DocBlock so the same converter can
      // initialise the QuillController AND seed the formatting snapshot
      // the onChanged/save diff logic compares against.
      final blockDict = _docBlockToDict(block);
      _docxOriginalBlockFormatted[block.blockId] = blockDict;
      final doc = _blockDictToQuillDocument(blockDict);
      _docxBlockControllers[block.blockId] = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
      _docxBlockFocusNodes[block.blockId] = FocusNode(
        debugLabel: 'docx-block-${block.blockId}',
      );
      final chunk = document.chunkForOffset(block.textOffset);
      if (chunk != null) {
        _docxBlockChunkIds[block.blockId] = chunk.chunkId;
      } else {
        debugPrint(
            '[_enterDocxEditModePerParagraph] WARNING: block=${block.blockId} '
            'has NO chunk mapping (textOffset=${block.textOffset}) — '
            'edits to this block will be silently dropped at save');
      }
    }
    debugPrint(
        '[_enterDocxEditModePerParagraph] blocks=${document.blocks.length} '
        'mapped=${_docxBlockChunkIds.length}');
    for (final entry in _docxBlockChunkIds.entries) {
      debugPrint(
          '[_enterDocxEditModePerParagraph] blockId=${entry.key} -> chunkId=${entry.value}');
    }

    for (final rawChunk in rawChunks) {
      final chunk = rawChunk as Map<String, dynamic>;
      final chunkId = (chunk['id'] ?? '').toString();
      _docxOriginalChunkTexts[chunkId] =
          (chunk['text_content'] ?? '').toString();
    }
    // Snapshot the per-chunk formatted-block lists so the save path can
    // detect formatting-only edits (which wouldn't change text_content).
    for (final chunkEntry in _docxChunkFormattedBlocks(document).entries) {
      _docxOriginalChunkFormatted[chunkEntry.key] = chunkEntry.value;
    }

    setState(() {
      _isEditing = true;
      _docxUnifiedEditMode = false;
      _editingChunkId = '';
      _originalText = '';
      _hasUnsavedChanges = false;
      _editingDocxDocument = document;
    });
  }

  /// M13.1a unified edit mode. One QuillController for the whole
  /// document. Cursor, selection, undo/redo, clipboard and keyboard
  /// shortcuts all flow across paragraph boundaries natively because
  /// Quill treats the entire Delta as a single editable surface.
  void _enterDocxEditModeUnified(
    PsittaDocument document,
    List<dynamic> rawChunks,
  ) {
    _disposeUnifiedEditorState();
    // Also clear any lingering per-paragraph maps so the two code paths
    // never mix. These should already be empty when entering unified
    // mode, but the clears are cheap and defensive.
    _docxBlockControllers.clear();
    _docxBlockFocusNodes.clear();
    _docxOriginalBlockTexts.clear();
    _docxOriginalChunkTexts.clear();
    _docxBlockChunkIds.clear();
    _docxOriginalBlockFormatted.clear();
    _docxOriginalChunkFormatted.clear();

    final flatBlocks = DocumentAssembler.flatBlockDicts(document);
    final quillDoc = _blockDictsToQuillDocument(flatBlocks);
    final controller = quill.QuillController(
      document: quillDoc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    final focusNode = FocusNode(debugLabel: 'docx-unified');

    _docxUnifiedController = controller;
    _docxUnifiedFocusNode = focusNode;
    _docxOriginalUnifiedBlockDicts = flatBlocks;
    _docxOriginalUnifiedPlainText = sanitizeForTts(quillDoc.toPlainText());

    // Snapshot pre-edit chunk state for diff-save (M13.1a uses positional
    // one-to-one matching; M13.1b will extend this with content hashing).
    for (final rawChunk in rawChunks) {
      final chunk = rawChunk as Map<String, dynamic>;
      final chunkId = (chunk['id'] ?? '').toString();
      _docxOriginalChunkTexts[chunkId] =
          (chunk['text_content'] ?? '').toString();
      // Also snapshot formatted_content so the save path can detect
      // formatting-only edits (those don't alter plain text, so the
      // content-hash matcher returns KEEP — we rely on the pre-edit
      // formatted_content to promote KEEP→UPDATE when the block dicts
      // actually changed).
      final fc = chunk['formatted_content'];
      if (fc is List) {
        _docxOriginalChunkFormatted[chunkId] = fc
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    debugPrint(
        '[_enterDocxEditModeUnified] blocks=${flatBlocks.length} '
        'chars=${_docxOriginalUnifiedPlainText.length}');

    setState(() {
      _isEditing = true;
      _docxUnifiedEditMode = true;
      _editingChunkId = '';
      _originalText = '';
      _hasUnsavedChanges = false;
      _editingDocxDocument = document;
    });

    // Request focus on the next frame so the widget tree is built first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _docxUnifiedFocusNode != null) {
        _docxUnifiedFocusNode!.requestFocus();
      }
    });

    // SG3a: one-shot offline spellcheck pass once the dictionary has finished
    // loading (whichever is later — edit-mode entry or dictionary ready). The
    // `controller` capture guards against a later re-entry having replaced the
    // unified controller out from under this async callback. No live/debounced
    // re-check yet (SG3b).
    SpellDictionary.instance.ready.then((_) {
      if (!mounted) return;
      if (!_isEditing || !_docxUnifiedEditMode) return;
      if (_docxUnifiedController != controller) return;
      // Guard the one-shot pass the same way the live tick does so the pass's
      // own notifying formatText doesn't schedule a redundant debounce tick,
      // and seed _lastSpellPlainText so the next tick early-outs until a real
      // text edit happens.
      _squiggleInFlight = true;
      try {
        _runSpellPass();
      } finally {
        _squiggleInFlight = false;
      }
      _lastSpellPlainText = controller.document.toPlainText();
    });
  }

  /// SG3a: paint red wavy squiggles under misspelled words in the unified
  /// editor. Full-document for SG3a; the [start]/[end] range params are
  /// reserved for SG3b's incremental (changed-paragraph) scope.
  ///
  /// Undo-safe and non-persistent:
  ///   - mutations run with `document.history.ignoreChange = true` (restored
  ///     in a finally) so squiggles never enter the undo/redo stack;
  ///   - the 'squiggle' attribute is NOT in the save whitelist
  ///     ([_quillDocumentToBlockDicts] flush()), so a squiggle-only pass
  ///     serializes to identical block dicts → no false unsaved, and squiggles
  ///     never persist through save.
  ///
  /// Issues exactly one notifying `formatText` (the last op) so the editor
  /// repaints once for the whole pass.
  void _runSpellPass({int? start, int? end}) {
    final controller = _docxUnifiedController;
    if (controller == null) return;

    final plain = controller.document.toPlainText();
    final rangeStart = (start ?? 0).clamp(0, plain.length);
    final rangeEnd = (end ?? plain.length).clamp(rangeStart, plain.length);
    final rangeLen = rangeEnd - rangeStart;
    if (rangeLen <= 0) return;

    // Collect misspelled token ranges first so the very last format op can be
    // the single notifying one (one repaint for the whole pass).
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
      // Clear any existing squiggles across the range. Notify here only when
      // there is nothing to re-apply (so the pass still triggers one repaint).
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
    debugPrint('[SG3a] spell pass: ${bad.length} misspelled token(s) over '
        '[$rangeStart,$rangeEnd) (dict=${SpellDictionary.instance.wordCount})');
  }

  /// SG3b: (re)start the debounce so a live spell re-check fires ~350ms after
  /// the user stops typing. Called from [_handleDocxUnifiedChanged].
  void _scheduleSpellCheck() {
    _spellDebounce?.cancel();
    _spellDebounce =
        Timer(const Duration(milliseconds: 350), _spellTick);
  }

  /// SG3b: debounced live spell re-check, scoped to the paragraph containing
  /// the cursor (incremental — never a whole-doc re-pass). Two loop guards:
  /// (a) [_squiggleInFlight] brackets the pass body so its synchronous notify
  /// can't reschedule a tick; (b) the plaintext-unchanged early-out makes the
  /// tick idempotent on any notify that didn't change the text (selection
  /// moves, toolbar formatting, the squiggle pass itself).
  void _spellTick() {
    if (!mounted || !_isEditing || !_docxUnifiedEditMode) return;
    final controller = _docxUnifiedController;
    if (controller == null) return;

    final plain = controller.document.toPlainText();
    if (plain.isEmpty) {
      _lastSpellPlainText = plain;
      return;
    }
    // Attribute-only change (e.g. the squiggle pass, a bold toggle, a cursor
    // move) leaves the text identical — nothing to re-spell.
    if (plain == _lastSpellPlainText) return;

    // Edited paragraph = the Quill line containing the cursor.
    final offset = controller.selection.baseOffset.clamp(0, plain.length - 1);
    final res = controller.document.queryChild(offset);
    final node = res.node;
    if (node is! quill.Line) {
      _lastSpellPlainText = plain;
      return;
    }
    final start = node.documentOffset;
    final end = start + node.length;

    _squiggleInFlight = true;
    try {
      _runSpellPass(start: start, end: end);
    } finally {
      _squiggleInFlight = false;
    }
    _lastSpellPlainText = plain;
  }

  void _disposeUnifiedEditorState() {
    _docxUnifiedController?.dispose();
    _docxUnifiedFocusNode?.dispose();
    _docxUnifiedController = null;
    _docxUnifiedFocusNode = null;
    _docxOriginalUnifiedBlockDicts = const [];
    _docxOriginalUnifiedPlainText = '';
  }

  void _exitEditMode() {
    ref.read(isInlineEditingProvider.notifier).state = false;
    // Tear down BOTH editor modes unconditionally. Only one of them has
    // live state at any given time; the other's clears are no-ops.
    _disposeUnifiedEditorState();
    for (final controller in _docxBlockControllers.values) {
      controller.dispose();
    }
    for (final node in _docxBlockFocusNodes.values) {
      node.dispose();
    }
    _docxBlockControllers.clear();
    _docxBlockFocusNodes.clear();
    _docxOriginalBlockTexts.clear();
    _docxOriginalChunkTexts.clear();
    _docxBlockChunkIds.clear();
    _docxOriginalBlockFormatted.clear();
    _docxOriginalChunkFormatted.clear();
    setState(() {
      _isEditing = false;
      _docxUnifiedEditMode = false;
      _editingChunkId = '';
      _originalText = '';
      _hasUnsavedChanges = false;
      _editingDocxDocument = null;
      _activeDocxController = null;
    });
    _editFocusNode.unfocus();
  }

  void _discardInlineEdit() {
    _editController.text = _originalText;
    _exitEditMode();
  }

  Future<void> _saveInlineEdit(String chunkId) async {
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
      chunkId: chunkId,
      plainText: sanitizeForTts(_editController.text),
    );

    if (success && mounted) {
      final voiceId = ref.read(selectedVoiceIdProvider);

      // Auto-title blank sheets using first ~50 chars of content
      final doc = _resolveDocument(ref);
      if (doc != null && doc.title == 'Untitled Sheet') {
        final plainText = sanitizeForTts(_editController.text);
        if (plainText.isNotEmpty) {
          var autoTitle = plainText.replaceAll('\n', ' ').trim();
          if (autoTitle.length > 50) {
            autoTitle = '${autoTitle.substring(0, 50).trimRight()}\u2026';
          }
          try {
            final repo = ref.read(documentRepositoryProvider);
            await repo.renameDocument(widget.documentId, autoTitle);
          } catch (_) {
            // Non-critical — title update is best-effort
          }
        }
      }

      // 1. Clear Flutter-side audio cache
      final audio = ref.read(audioServiceProvider);
      unawaited(audio.invalidateChunkCache(chunkId));

      // 2. Invalidate providers — triggers fresh TTS synthesis
      //    chunkAlignmentProvider re-fetch calls GET /alignment which
      //    triggers backend synthesis if no cache exists.
      ref.invalidate(chunksProvider(widget.documentId));
      ref.invalidate(chunkAlignmentProvider(AlignmentKey(
        documentId: widget.documentId,
        chunkId: chunkId,
        voiceId: voiceId,
      )));

      // 3. Refresh Library so the new/renamed doc appears
      ref.invalidate(documentsProvider);

      _exitEditMode();
    }
  }

  Map<String, String> _docxChunkTexts(PsittaDocument document) {
    final chunkOrder = document.chunkMap.map((chunk) => chunk.chunkId).toList();
    final chunkBuffers = <String, List<String>>{
      for (final chunkId in chunkOrder) chunkId: <String>[],
    };

    for (final block in document.blocks) {
      final chunkId = _docxBlockChunkIds[block.blockId];
      if (chunkId == null) continue;
      final controller = _docxBlockControllers[block.blockId];
      final text = sanitizeForTts(
          controller?.document.toPlainText() ?? block.plainText);
      chunkBuffers.putIfAbsent(chunkId, () => <String>[]).add(text);
    }

    return {
      for (final chunkId in chunkOrder)
        chunkId: chunkBuffers[chunkId]!.isEmpty
            ? (_docxOriginalChunkTexts[chunkId] ?? '')
            : chunkBuffers[chunkId]!
                .where((text) => text.isNotEmpty)
                .join('\n\n'),
    };
  }

  /// Parallel to [_docxChunkTexts] but emits the list of block dicts for
  /// each chunk in the canonical `formatted_content` schema. Used at
  /// edit-mode entry to snapshot the pre-edit state, and at save time to
  /// produce the payload sent to the backend.
  Map<String, List<Map<String, dynamic>>> _docxChunkFormattedBlocks(
      PsittaDocument document) {
    final chunkOrder = document.chunkMap.map((chunk) => chunk.chunkId).toList();
    final chunkBuffers = <String, List<Map<String, dynamic>>>{
      for (final chunkId in chunkOrder) chunkId: <Map<String, dynamic>>[],
    };

    for (final block in document.blocks) {
      final chunkId = _docxBlockChunkIds[block.blockId];
      if (chunkId == null) continue;
      final controller = _docxBlockControllers[block.blockId];
      if (controller != null) {
        // A single controller may now emit multiple block dicts when the
        // user pressed Enter inside it — each paragraph boundary becomes
        // a separate block so the load path can rehydrate N paragraphs.
        final blockDicts = _quillDocumentToBlockDicts(
          controller.document,
          block.type,
          block.level,
        );
        chunkBuffers[chunkId]!.addAll(blockDicts);
      } else {
        // Fallback for any block whose controller was not instantiated
        // (shouldn't happen in practice — kept defensive). Always yields
        // a single block dict.
        chunkBuffers[chunkId]!.add(_docBlockToDict(block));
      }
    }

    return {
      for (final chunkId in chunkOrder) chunkId: chunkBuffers[chunkId]!,
    };
  }

  /// Convert a [DocBlock] from the backend-assembled PsittaDocument into
  /// the canonical block-dict shape (`{type, level?, runs}`) consumed by
  /// both the Quill initialiser and the save-time payload.
  Map<String, dynamic> _docBlockToDict(DocBlock block) {
    final runs = <Map<String, dynamic>>[];
    for (final run in block.runs) {
      if (run.text.isEmpty) continue;
      final entry = <String, dynamic>{'text': run.text};
      if (run.bold) entry['bold'] = true;
      if (run.italic) entry['italic'] = true;
      if (run.underline) entry['underline'] = true;
      if (run.fontSize != null) entry['font_size'] = run.fontSize;
      runs.add(entry);
    }
    if (runs.isEmpty) {
      runs.add(<String, dynamic>{'text': ''});
    }
    final dict = <String, dynamic>{
      'type': _blockTypeToString(block.type),
      'runs': runs,
    };
    if (block.level != null) dict['level'] = block.level;
    return dict;
  }

  /// Build a [quill.Document] populated with the block's runs as
  /// attributed Delta ops. The Phase 1 attribute set (bold, italic,
  /// underline, font_size) maps to Quill's inline attributes. Block-level
  /// type/level is NOT stored on the Delta itself — the Quill editor
  /// hosts one block per controller, and the outer widget applies the
  /// appropriate TextStyle via the DocBlock.type.
  quill.Document _blockDictToQuillDocument(Map<String, dynamic> block) {
    final deltaJson = <Map<String, dynamic>>[];
    final runs = (block['runs'] as List?) ?? const [];
    for (final raw in runs) {
      if (raw is! Map) continue;
      final text = (raw['text'] ?? '') as String;
      if (text.isEmpty) continue;
      final attrs = <String, dynamic>{};
      if (raw['bold'] == true) attrs['bold'] = true;
      if (raw['italic'] == true) attrs['italic'] = true;
      if (raw['underline'] == true) attrs['underline'] = true;
      final fontSize = raw['font_size'];
      if (fontSize != null) {
        // Emit whole-number sizes as integer strings ("20") to match the
        // toolbar dropdown's key format; emit fractional sizes with their
        // full decimal representation. Quill's renderer parses either via
        // getFontSize, but matching the toolbar's exact shape avoids any
        // subtle store-shape asymmetry between load and live-edit paths.
        final d = (fontSize as num).toDouble();
        final asInt = d.toInt();
        final isWhole = asInt.toDouble() == d;
        attrs['size'] = (isWhole ? asInt : d).toString();
      }
      final op = <String, dynamic>{'insert': text};
      if (attrs.isNotEmpty) op['attributes'] = attrs;
      deltaJson.add(op);
    }
    // Quill documents require at least one op and must end with a
    // newline insert. An empty block-dict still yields a valid empty doc.
    deltaJson.add(<String, dynamic>{'insert': '\n'});
    return quill.Document.fromJson(deltaJson);
  }

  /// Unified-editor counterpart of [_blockDictToQuillDocument]: stitch a
  /// flat block-dict list into ONE Quill [quill.Document].
  ///
  /// Each block's runs become inline `insert` ops carrying the Phase 1
  /// attribute set ({bold, italic, underline, size}). The block is
  /// terminated by a `\n` insert that carries block-level attributes
  /// ({header, list}) — Quill's documented convention for paragraph,
  /// heading and list styling (see flutter_quill-10.8.5/lib/src/document/
  /// attribute.dart, `HeaderAttribute` and `ListAttribute`).
  quill.Document _blockDictsToQuillDocument(
    List<Map<String, dynamic>> blockDicts,
  ) {
    if (blockDicts.isEmpty) {
      return quill.Document.fromJson(<Map<String, dynamic>>[
        <String, dynamic>{'insert': '\n'}
      ]);
    }
    final ops = <Map<String, dynamic>>[];
    for (final block in blockDicts) {
      // M13.5 scaffolding — page_break blocks have no runs, no text,
      // no block-level attrs. Emit the BlockEmbed.custom op (which
      // serializes to {custom: '<jsonString>'} — the shape
      // text_line.dart:148 recognizes) + a trailing \n so the embed
      // owns its line per the single-child-line invariant.
      if (block['type'] == 'page_break') {
        ops.add(<String, dynamic>{
          'insert': quill.BlockEmbed.custom(const PageBreakEmbed()).toJson(),
        });
        ops.add(<String, dynamic>{'insert': '\n'});
        continue;
      }
      final runs = (block['runs'] as List?) ?? const [];
      for (final raw in runs) {
        if (raw is! Map) continue;
        final text = (raw['text'] ?? '') as String;
        if (text.isEmpty) continue;
        final attrs = <String, dynamic>{};
        if (raw['bold'] == true) attrs['bold'] = true;
        if (raw['italic'] == true) attrs['italic'] = true;
        if (raw['underline'] == true) attrs['underline'] = true;
        if (raw['strike'] == true) attrs['strike'] = true;
        final fontSize = raw['font_size'];
        if (fontSize != null) {
          // Emit whole-number sizes as integer strings ("20") to match
          // the toolbar dropdown's key format; emit fractional sizes with
          // their full decimal representation. Matches the toolbar's
          // exact shape so load and live-edit Deltas agree.
          final d = (fontSize as num).toDouble();
          final asInt = d.toInt();
          final isWhole = asInt.toDouble() == d;
          attrs['size'] = (isWhole ? asInt : d).toString();
        }
        // Color: stored as lowercase 6-digit hex without `#`. Quill's
        // ColorAttribute expects the `#`-prefixed form so the toolbar's
        // current-color indicator and the picker round-trip cleanly.
        final colorRaw = raw['color'];
        if (colorRaw is String && colorRaw.isNotEmpty) {
          attrs['color'] = colorRaw.startsWith('#') ? colorRaw : '#$colorRaw';
        }
        // Font family: stored as `font_family` (matching python-docx
        // run.font.name); Quill's FontAttribute uses the `font` key.
        final fontFamily = raw['font_family'];
        if (fontFamily is String && fontFamily.isNotEmpty) {
          attrs['font'] = fontFamily;
        }
        final op = <String, dynamic>{'insert': text};
        if (attrs.isNotEmpty) op['attributes'] = attrs;
        ops.add(op);
      }
      // Close the block with a `\n` carrying any block-level attrs.
      final blockAttrs = _blockLevelAttrs(block);
      final newlineOp = <String, dynamic>{'insert': '\n'};
      if (blockAttrs.isNotEmpty) newlineOp['attributes'] = blockAttrs;
      ops.add(newlineOp);
    }
    return quill.Document.fromJson(ops);
  }

  /// Map a canonical block dict's block-level styling to the Quill
  /// attribute shape. Heading uses `{'header': int}` (1–6); list items
  /// use `{'list': 'bullet'|'ordered'}`. Alignment uses
  /// `{'align': 'left'|'center'|'right'|'justify'}` and composes
  /// orthogonally with header/list — a centered heading is a valid
  /// merged map `{header: 1, align: 'center'}`. Keys and value types
  /// match the SDK's HeaderAttribute, ListAttribute and AlignAttribute
  /// conventions exactly.
  Map<String, dynamic> _blockLevelAttrs(Map<String, dynamic> block) {
    final attrs = <String, dynamic>{};
    final type = block['type'] as String?;
    if (type == 'heading') {
      final level = block['level'];
      if (level is int && level >= 1 && level <= 6) {
        attrs['header'] = level;
      }
    } else if (type == 'list_item') {
      // list_type: 'numbered' → Quill 'ordered'; default/missing/'bullet'
      // → Quill 'bullet'. Round-trips with the save side, which emits
      // 'numbered' for Quill 'ordered' and 'bullet' for Quill 'bullet'.
      final listType = block['list_type'];
      attrs['list'] = (listType == 'numbered') ? 'ordered' : 'bullet';
    }
    final alignment = block['alignment'];
    if (alignment is String &&
        (alignment == 'left' ||
            alignment == 'center' ||
            alignment == 'right' ||
            alignment == 'justify')) {
      attrs['align'] = alignment;
    }
    return attrs;
  }

  /// Convert a [quill.Document] back into the canonical block-dict list,
  /// grouping consecutive inline inserts by identical attribute-set and
  /// splitting into multiple blocks on paragraph-break boundaries (the
  /// newline-between-fragments case in the Delta walk).
  ///
  /// Paragraph-break demotion: the FIRST emitted block inherits [type]
  /// and [level]; any additional blocks produced by a newline inside the
  /// controller use [DocBlockType.paragraph] with `level == null`. This
  /// matches Word's behavior — pressing Enter inside a heading splits off
  /// a plain body paragraph, it does not clone the heading.
  ///
  /// Phase 1 silently drops attributes outside the supported set (color,
  /// background, align, strike, etc.) — these are also hidden from the
  /// toolbar so users shouldn't generate them in practice.
  List<Map<String, dynamic>> _quillDocumentToBlockDicts(
    quill.Document doc,
    DocBlockType type,
    int? level,
  ) {
    final outBlocks = <Map<String, dynamic>>[];
    var currentRuns = <Map<String, dynamic>>[];
    var currentType = type;
    int? currentLevel = level;
    String? currentListType;
    String? currentAlignment;
    Map<String, dynamic>? pendingAttrs;
    final pendingText = StringBuffer();

    void flush() {
      final text = pendingText.toString();
      if (text.isEmpty) return;
      final run = <String, dynamic>{'text': text};
      final attrs = pendingAttrs;
      if (attrs != null) {
        if (attrs['bold'] == true) run['bold'] = true;
        if (attrs['italic'] == true) run['italic'] = true;
        if (attrs['underline'] == true) run['underline'] = true;
        if (attrs['strike'] == true) run['strike'] = true;
        final size = attrs['size'];
        if (size != null) {
          final parsed = double.tryParse(size.toString());
          if (parsed != null) run['font_size'] = parsed;
        }
        // Color: flutter_quill emits a hex string (`#RRGGBB`). Normalize to
        // lowercase 6-digit no-`#` so the export builder can hand it to
        // RGBColor.from_string without further coercion. Unparseable shapes
        // (rgba(...), named colors, malformed hex) are dropped silently —
        // we never poison formatted_content with a value the backend can't
        // consume.
        final rawColor = attrs['color'];
        if (rawColor is String) {
          final normalized = _normalizeHexColor(rawColor);
          if (normalized != null) run['color'] = normalized;
        }
        // Font family: flutter_quill emits `font` (string family name).
        // Stored as `font_family` to match the python-docx run.font.name
        // contract on the export side. No normalization — we trust the
        // toolbar's font picker output.
        final rawFont = attrs['font'];
        if (rawFont is String && rawFont.isNotEmpty) {
          run['font_family'] = rawFont;
        }
      }
      currentRuns.add(run);
      pendingText.clear();
    }

    void closeBlock() {
      if (currentRuns.isEmpty && outBlocks.isNotEmpty) {
        // Skip empty trailing blocks produced by the terminating newline
        // that every Quill document carries. The first block is still
        // emitted in the empty-document case via the post-walk guard.
        currentType = DocBlockType.paragraph;
        currentLevel = null;
        currentListType = null;
        currentAlignment = null;
        return;
      }
      final runs = currentRuns.isEmpty
          ? <Map<String, dynamic>>[<String, dynamic>{'text': ''}]
          : currentRuns;
      final dict = <String, dynamic>{
        'type': _blockTypeToString(currentType),
        'runs': runs,
      };
      if (currentLevel != null) dict['level'] = currentLevel;
      if (currentListType != null) dict['list_type'] = currentListType;
      if (currentAlignment != null) dict['alignment'] = currentAlignment;
      outBlocks.add(dict);
      currentRuns = <Map<String, dynamic>>[];
      // Paragraph-break demotion: subsequent blocks are plain paragraphs.
      currentType = DocBlockType.paragraph;
      currentLevel = null;
      currentListType = null;
      currentAlignment = null;
    }

    for (final op in doc.toDelta().toList()) {
      final data = op.data;
      // M13.5 scaffolding — detect a PageBreakEmbed serialized as
      // {insert: {custom: '{"page_break":""}'}}. flutter_quill wraps a
      // BlockEmbed.custom by stuffing the inner type+data as a
      // JSON-encoded string into the outer "custom" key (see
      // CustomBlockEmbed.toJsonString in embeddable.dart). We emit the
      // page_break block here so any data already containing one
      // round-trips cleanly through save. The user-visible toolbar
      // button + the "skip-next-newline state machine" that prevents
      // phantom paragraphs around the break ship together in M13.5.
      if (data is Map) {
        final customJson = data['custom'];
        if (customJson is String) {
          try {
            final inner = jsonDecode(customJson);
            if (inner is Map && inner.containsKey('page_break')) {
              flush();
              closeBlock();
              outBlocks.add(<String, dynamic>{
                'type': 'page_break',
                'runs': const <Map<String, dynamic>>[],
              });
            }
          } catch (_) {
            // malformed embed JSON — drop silently
          }
        }
        continue; // skip non-page-break embeds and the failed page_break
      }
      if (data is! String) continue;
      final chunks = data.split('\n');
      for (var i = 0; i < chunks.length; i++) {
        final fragment = chunks[i];
        if (fragment.isNotEmpty) {
          final attrs = op.attributes ?? const <String, dynamic>{};
          final current = pendingAttrs;
          if (current == null || !_attributesEqual(current, attrs)) {
            flush();
            pendingAttrs = Map<String, dynamic>.from(attrs);
          }
          pendingText.write(fragment);
        }
        // Newline between fragments — close the current block and start
        // a new one. This is the paragraph-boundary emission point.
        if (i != chunks.length - 1) {
          flush();
          pendingAttrs = null;
          // Apply block-level attributes from the op carrying this \n.
          // Quill stores heading level on the trailing newline as
          // {"header": int}, list type as {"list": "bullet"|"ordered"},
          // and alignment as {"align": "left"|"center"|"right"|"justify"}.
          // Read these BEFORE closeBlock() so the emitted dict has the
          // correct type/level/list_type/alignment. Alignment is
          // orthogonal — it composes with heading and list_item rather
          // than replacing them (a centered heading and a right-aligned
          // numbered item are both valid). When neither header nor list
          // is present, the existing currentType/currentLevel/
          // currentListType values are used (paragraph default after
          // demotion, or the parent function's `type` parameter for the
          // very first block in per-paragraph legacy mode).
          final blockAttrs = op.attributes ?? const <String, dynamic>{};
          final headerAttr = blockAttrs['header'];
          if (headerAttr is int && headerAttr >= 1 && headerAttr <= 6) {
            currentType = DocBlockType.heading;
            currentLevel = headerAttr;
            currentListType = null;
          } else {
            final listAttr = blockAttrs['list'];
            if (listAttr == 'bullet') {
              currentType = DocBlockType.listItem;
              currentLevel = null;
              currentListType = 'bullet';
            } else if (listAttr == 'ordered') {
              currentType = DocBlockType.listItem;
              currentLevel = null;
              currentListType = 'numbered';
            }
          }
          final alignAttr = blockAttrs['align'];
          if (alignAttr is String &&
              (alignAttr == 'left' ||
                  alignAttr == 'center' ||
                  alignAttr == 'right' ||
                  alignAttr == 'justify')) {
            currentAlignment = alignAttr;
          }
          closeBlock();
        }
      }
    }
    flush();
    closeBlock();

    if (outBlocks.isEmpty) {
      outBlocks.add(<String, dynamic>{
        'type': _blockTypeToString(type),
        'runs': <Map<String, dynamic>>[<String, dynamic>{'text': ''}],
        if (level != null) 'level': level,
      });
    }
    return outBlocks;
  }

  /// Compare two Quill inline-attribute maps for run-grouping equality.
  ///
  /// MUST list every inline attribute the formatted_content schema supports.
  /// If an attribute is missing here, adjacent ops differing only in that
  /// attribute will be incorrectly merged into one run on save, producing:
  ///   - Scope spread (when the attributed op is the seed of a run group)
  ///   - Attribute loss (when the attributed op is mid-iteration)
  ///
  /// History: M13.4 Ship 1 (commit 9983260) added strike/color/font to the
  /// schema and to flush() emission, but the keys list here was not
  /// updated. Symptoms surfaced as strike-spreads-to-whole-sentence; latent
  /// bugs existed for color and font_family. Repaired by adding all three
  /// to the keys array.
  bool _attributesEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    const keys = ['bold', 'italic', 'underline', 'size', 'strike', 'color', 'font'];
    for (final key in keys) {
      if ((a[key] ?? false) != (b[key] ?? false)) {
        if (a[key] == null && b[key] == null) continue;
        if (a[key] != b[key]) return false;
      }
    }
    return true;
  }

  String _blockTypeToString(DocBlockType type) {
    switch (type) {
      case DocBlockType.heading:
        return 'heading';
      case DocBlockType.listItem:
        return 'list_item';
      case DocBlockType.paragraph:
        return 'paragraph';
    }
  }

  /// onChanged handler for the unified editor. Dirty check is a single
  /// jsonEncode comparison between the current flat block-dict list and
  /// the pre-edit snapshot captured in [_enterDocxEditModeUnified].
  void _handleDocxUnifiedChanged() {
    final controller = _docxUnifiedController;
    if (controller == null) return;
    final currentDicts = _quillDocumentToBlockDicts(
      controller.document,
      DocBlockType.paragraph,
      null,
    );
    final changed = jsonEncode(currentDicts) !=
        jsonEncode(_docxOriginalUnifiedBlockDicts);
    if (changed != _hasUnsavedChanges && mounted) {
      setState(() {
        _hasUnsavedChanges = changed;
      });
    }
    // SG3b: schedule a live spell re-check unless this notify came from the
    // squiggle pass itself (which fires this callback synchronously). The tick
    // additionally early-outs when the plain text is unchanged.
    if (!_squiggleInFlight) _scheduleSpellCheck();
  }

  /// onChanged handler factory for per-paragraph (legacy) mode. Needs
  /// [psittaDoc] in closure to look up each block's type/level when
  /// serializing its QuillController. Returns a zero-arg callback
  /// compatible with [DocxDocumentEditor.onChanged].
  VoidCallback _handleDocxPerParagraphChanged(PsittaDocument psittaDoc) {
    return () {
      var changed = false;
      for (final entry in _docxBlockControllers.entries) {
        final blockId = entry.key;
        final originalText =
            _docxOriginalBlockTexts[blockId] ?? '';
        if (sanitizeForTts(entry.value.document.toPlainText()) !=
            sanitizeForTts(originalText)) {
          changed = true;
          break;
        }
        final originalBlock =
            _docxOriginalBlockFormatted[blockId];
        if (originalBlock != null) {
          DocBlock? docBlock;
          for (final candidate in psittaDoc.blocks) {
            if (candidate.blockId == blockId) {
              docBlock = candidate;
              break;
            }
          }
          if (docBlock != null) {
            final currentBlockList = _quillDocumentToBlockDicts(
              entry.value.document,
              docBlock.type,
              docBlock.level,
            );
            final originalBlockList = <Map<String, dynamic>>[
              originalBlock,
            ];
            if (jsonEncode(currentBlockList) !=
                jsonEncode(originalBlockList)) {
              changed = true;
              break;
            }
          }
        }
      }
      if (changed != _hasUnsavedChanges && mounted) {
        setState(() {
          _hasUnsavedChanges = changed;
        });
      }
    };
  }

  /// Save the DOCX edit. Dispatches to the unified save (M13.1a) when
  /// the unified controller is active; otherwise falls through to the
  /// legacy per-paragraph save.
  Future<bool> _saveDocxEdit(PsittaDocument document) async {
    if (_docxUnifiedEditMode) {
      return _saveDocxEditUnified(document);
    }
    return _saveDocxEditPerParagraph(document);
  }

  Future<bool> _saveDocxEditPerParagraph(PsittaDocument document) async {
    debugPrint(
        '[_saveDocxEditPerParagraph] called — _hasUnsavedChanges=$_hasUnsavedChanges');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Audio'),
        content: const Text(
          'Saving these changes will regenerate audio for the edited sections. '
          'You may need to replay from the updated section to hear the new audio.',
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

    if (confirmed != true || !mounted) return false;

    final nextChunkTexts = _docxChunkTexts(document);
    final nextChunkFormatted = _docxChunkFormattedBlocks(document);

    // A chunk needs saving if EITHER the plain text differs from the
    // pre-edit snapshot (old semantics) OR the formatted_content block
    // list differs (new Phase 1 semantics — catches formatting-only
    // edits like bolding a word that don't change text_content).
    final changedChunkTexts = <String, String>{};
    final changedChunkFormatted = <String, List<Map<String, dynamic>>>{};
    for (final entry in nextChunkTexts.entries) {
      final chunkId = entry.key;
      final previousText = _docxOriginalChunkTexts[chunkId] ?? '';
      final textDiffers =
          sanitizeForTts(entry.value) != sanitizeForTts(previousText);

      final previousBlocks = _docxOriginalChunkFormatted[chunkId] ?? const [];
      final currentBlocks = nextChunkFormatted[chunkId] ?? const [];
      final fmtDiffers = jsonEncode(currentBlocks) != jsonEncode(previousBlocks);

      if (textDiffers || fmtDiffers) {
        changedChunkTexts[chunkId] = sanitizeForTts(entry.value);
        changedChunkFormatted[chunkId] = currentBlocks;
      }
    }

    if (changedChunkTexts.isEmpty) {
      debugPrint(
          '[_saveDocxEdit] no text or formatting changes — exiting edit mode');
      _exitEditMode();
      return true;
    }

    debugPrint(
        '[_saveDocxEdit] changedChunkTexts (${changedChunkTexts.length} '
        'entries):');
    for (final entry in changedChunkTexts.entries) {
      debugPrint(
          '[_saveDocxEdit] SAVING chunk_id=${entry.key} text.len=${entry.value.length} '
          'fmt.blocks=${changedChunkFormatted[entry.key]?.length ?? 0}');
    }

    final notifier = ref.read(chunkEditorProvider.notifier);
    final success = await notifier.saveChunkTexts(
      documentId: widget.documentId,
      chunkTexts: changedChunkTexts,
      chunkFormatted: changedChunkFormatted,
    );
    debugPrint('[_saveDocxEdit] saveChunkTexts returned success=$success');

    if (!success || !mounted) return false;

    for (final entry in _docxBlockControllers.entries) {
      _docxOriginalBlockTexts[entry.key] =
          sanitizeForTts(entry.value.document.toPlainText());
    }
    _docxOriginalChunkTexts.addAll(changedChunkTexts);
    _docxOriginalChunkFormatted.addAll(changedChunkFormatted);
    setState(() {
      _hasUnsavedChanges = false;
    });

    final voiceId = ref.read(selectedVoiceIdProvider);
    final audio = ref.read(audioServiceProvider);
    for (final chunkId in changedChunkTexts.keys) {
      unawaited(audio.invalidateChunkCache(chunkId));
      ref.invalidate(chunkAlignmentProvider(AlignmentKey(
        documentId: widget.documentId,
        chunkId: chunkId,
        voiceId: voiceId,
      )));
    }

    // Explicitly invalidate the cached chunks before re-fetching so the
    // refresh goes all the way to the backend instead of returning stale
    // Riverpod cache.
    ref.invalidate(chunksProvider(widget.documentId));
    ref.invalidate(documentsProvider);
    debugPrint('[_saveDocxEdit] invalidated chunksProvider + documentsProvider');

    final refreshedData =
        await ref.read(chunksProvider(widget.documentId).future);
    final refreshedChunks = (refreshedData['chunks'] as List<dynamic>?) ?? [];
    final refreshedTexts = <String, String>{
      for (final rawChunk in refreshedChunks)
        ((rawChunk as Map<String, dynamic>)['id'] ?? '').toString():
            sanitizeForTts((rawChunk['text_content'] ?? '').toString()),
    };
    debugPrint(
        '[_saveDocxEdit] refreshed ${refreshedTexts.length} chunks from backend');
    for (final entry in changedChunkTexts.entries) {
      final got = refreshedTexts[entry.key];
      debugPrint(
          '[_saveDocxEdit] verify chunk_id=${entry.key} '
          'expected=${sanitizeForTts(entry.value)} got=$got');
    }
    final persisted = changedChunkTexts.entries.every(
      (entry) => refreshedTexts[entry.key] == sanitizeForTts(entry.value),
    );
    debugPrint('[_saveDocxEdit] persisted=$persisted');
    if (!persisted) {
      if (mounted) {
        setState(() {
          _hasUnsavedChanges = true;
        });
      }
      return false;
    }
    _exitEditMode();
    return true;
  }

  /// M13.1b unified save path.
  ///
  /// 1. Serialize the unified Quill Document → flat block-dict list.
  /// 2. Slice into fixed ~500-word windows.
  /// 3. Match sliced chunks to pre-edit chunk_ids via content hash +
  ///    same-position fallback ([assignChunkIdsByContent]).
  /// 4. Orchestrator fans out UPDATEs → INSERTs → DELETEs, then
  ///    PATCHes `chunk_positions` + `chunk_count` on the document in
  ///    one backend transaction that also reindexes sequence_index.
  ///
  /// Structural changes (inserts, deletes) are fully supported; the
  /// M13.1a "This edit changes the document structure" SnackBar is no
  /// longer emitted.
  Future<bool> _saveDocxEditUnified(PsittaDocument document) async {
    debugPrint(
        '[_saveDocxEditUnified] called — _hasUnsavedChanges=$_hasUnsavedChanges');
    final controller = _docxUnifiedController;
    if (controller == null) {
      debugPrint(
          '[_saveDocxEditUnified] no unified controller — aborting');
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Audio'),
        content: const Text(
          'Saving these changes will regenerate audio for the edited sections. '
          'You may need to replay from the updated section to hear the new audio.',
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
    if (confirmed != true || !mounted) return false;

    // Step 1: Serialize unified controller → flat block-dict list.
    final flatBlocks = _quillDocumentToBlockDicts(
      controller.document,
      DocBlockType.paragraph,
      null,
    );
    debugPrint(
        '[_saveDocxEditUnified] serialized ${flatBlocks.length} blocks');

    // No-op guard — short-circuit zero-delta saves before any network.
    if (jsonEncode(flatBlocks) ==
        jsonEncode(_docxOriginalUnifiedBlockDicts)) {
      debugPrint(
          '[_saveDocxEditUnified] no changes vs pre-edit snapshot — exiting');
      _exitEditMode();
      return true;
    }

    // Step 2: Slice into chunks (fixed ~500-word windows).
    final slicedChunks = sliceBlocksIntoChunks(flatBlocks);
    debugPrint(
        '[_saveDocxEditUnified] sliced into ${slicedChunks.length} chunks');

    // Step 3: Content-hash match against the pre-edit chunk IDs. Keeps
    // match chunks whose normalized text is identical; same-position
    // unmatched chunks degrade to UPDATE so the audit trail survives.
    final preEditChunkIds =
        document.chunkMap.map((c) => c.chunkId).toList();
    final assignments = assignChunkIdsByContent(
      slicedChunks,
      preEditChunkIds,
      _docxOriginalChunkTexts,
    );

    // M13.1b regression fix: assignChunkIdsByContent hashes on plain text
    // only, so formatting-only edits (Bold/Italic/Underline/FontSize) come
    // back as KEEP for every chunk. Promote to UPDATE when the sliced
    // blockDicts differ from the pre-edit formatted_content snapshot so
    // the orchestrator actually writes the new formatted_content.
    var promoted = 0;
    for (var i = 0; i < assignments.length; i++) {
      final a = assignments[i];
      if (a.action != ChunkAction.keep) continue;
      final cid = a.chunkId;
      final s = a.slicedChunk;
      if (cid == null || s == null) continue;
      final previousBlocks =
          _docxOriginalChunkFormatted[cid] ?? const <Map<String, dynamic>>[];
      if (jsonEncode(s.blockDicts) != jsonEncode(previousBlocks)) {
        assignments[i] = a.copyWith(action: ChunkAction.update);
        promoted++;
      }
    }
    if (promoted > 0) {
      debugPrint(
          '[_saveDocxEditUnified] promoted $promoted keep→update '
          '(formatting-only diff)');
    }

    final keeps = assignments.where((a) => a.action == ChunkAction.keep).length;
    final updates = assignments.where((a) => a.action == ChunkAction.update).length;
    final inserts = assignments.where((a) => a.action == ChunkAction.insert).length;
    final deletes = assignments.where((a) => a.action == ChunkAction.delete).length;
    final nonDeleteCount = assignments.length - deletes;
    final preservedRatio =
        nonDeleteCount == 0 ? 0.0 : keeps / nonDeleteCount;
    debugPrint(
        '[_saveDocxEditUnified] assignments keeps=$keeps updates=$updates '
        'inserts=$inserts deletes=$deletes '
        'chunks_preserved_ratio=${preservedRatio.toStringAsFixed(2)}');

    if (keeps == assignments.length && updates == 0 && inserts == 0 && deletes == 0) {
      // Everything matched as KEEP — no edits reached the wire.
      debugPrint(
          '[_saveDocxEditUnified] all keeps, no writes needed — exiting');
      _exitEditMode();
      return true;
    }

    // Step 4: Fan out via the orchestrator.
    final notifier = ref.read(chunkEditorProvider.notifier);
    final success = await notifier.saveDocumentChunks(
      documentId: widget.documentId,
      assignments: assignments,
    );
    debugPrint(
        '[_saveDocxEditUnified] saveDocumentChunks returned success=$success');

    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Save failed — please try again. Your changes are preserved.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
        setState(() {
          _hasUnsavedChanges = true;
        });
      }
      return false;
    }
    if (!mounted) return false;

    // Update snapshots so the next save diff runs from the new baseline.
    _docxOriginalUnifiedBlockDicts = flatBlocks;
    _docxOriginalUnifiedPlainText =
        sanitizeForTts(controller.document.toPlainText());
    // For UPDATE chunks the chunk_id is unchanged, so seed the pre-edit
    // maps from the sliced content. Inserts are handled on the next
    // load (when chunksProvider refreshes with new chunk_ids).
    for (final a in assignments) {
      if (a.action == ChunkAction.update || a.action == ChunkAction.keep) {
        final cid = a.chunkId;
        final s = a.slicedChunk;
        if (cid == null || s == null) continue;
        _docxOriginalChunkTexts[cid] = sanitizeForTts(s.plainText);
        _docxOriginalChunkFormatted[cid] = s.blockDicts;
      } else if (a.action == ChunkAction.delete) {
        final cid = a.chunkId;
        if (cid != null) {
          _docxOriginalChunkTexts.remove(cid);
          _docxOriginalChunkFormatted.remove(cid);
        }
      }
    }

    setState(() {
      _hasUnsavedChanges = false;
    });

    // Invalidate audio cache + alignment providers for every chunk
    // that changed (updates + all inserts since they're brand-new).
    // Deletes are already handled server-side by delete_chunk's call
    // to _invalidate_chunk_audio_cache.
    final voiceId = ref.read(selectedVoiceIdProvider);
    final audio = ref.read(audioServiceProvider);
    for (final a in assignments) {
      if (a.action == ChunkAction.update && a.chunkId != null) {
        unawaited(audio.invalidateChunkCache(a.chunkId!));
        ref.invalidate(chunkAlignmentProvider(AlignmentKey(
          documentId: widget.documentId,
          chunkId: a.chunkId!,
          voiceId: voiceId,
        )));
      }
    }

    ref.invalidate(chunksProvider(widget.documentId));
    ref.invalidate(documentsProvider);
    debugPrint(
        '[_saveDocxEditUnified] invalidated chunksProvider + documentsProvider');

    _exitEditMode();
    return true;
  }

  /// Shows a dialog when navigating away with unsaved changes.
  /// Returns 'save', 'discard', or null (cancel).
  Future<String?> _showUnsavedChangesDialog() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. Save before leaving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Guard that checks for unsaved changes before performing an action.
  /// Returns true if the action should proceed.
  Future<bool> _guardUnsavedChanges() async {
    if (!_hasUnsavedChanges) {
      if (_isEditing) _exitEditMode();
      return true;
    }
    final result = await _showUnsavedChangesDialog();
    if (result == 'save') {
      if (_editingDocxDocument != null) {
        return _saveDocxEdit(_editingDocxDocument!);
      } else {
        await _saveInlineEdit(_editingChunkId);
        return true;
      }
    } else if (result == 'discard') {
      if (_editingDocxDocument != null) {
        _exitEditMode();
      } else {
        _discardInlineEdit();
      }
      return true;
    }
    return false; // cancel
  }

  Document? _resolveDocument(WidgetRef ref) {
    final docs = ref.watch(documentsProvider).valueOrNull;
    if (docs == null) return null;
    for (final doc in docs) {
      if (doc.id == widget.documentId) return doc;
    }
    return null;
  }

  String _voiceName(WidgetRef ref) {
    final voicesAsync = ref.watch(voicesProvider);
    final selectedId = ref.watch(selectedVoiceIdProvider);
    String name =
        selectedId.length >= 8 ? selectedId.substring(0, 8) : selectedId;
    voicesAsync.whenData((voices) {
      for (final voice in voices) {
        if (voice.id == selectedId) {
          name = voice.displayName;
          break;
        }
      }
    });
    return name;
  }

  void _onActiveWordChanged(int wordIndex, int totalWords) {
    if (_userScrolling || _isEditing) return;
    if (!_contentScrollController.hasClients) return;
    final maxExtent = _contentScrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return;

    final fraction = wordIndex / (totalWords - 1).clamp(1, totalWords);
    if (fraction > 0.90) {
      _contentScrollController.animateTo(
        maxExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }
    final target = fraction * maxExtent;
    final current = _contentScrollController.offset;
    if ((target - current).abs() < 4) return;

    _contentScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _scrollFromSentence(GlobalKey sentenceKey) {
    // Rail follows the voice's page regardless of manual scroll / auto-scroll
    // suppression, so this precedes the scroll-suppression early-return below.
    if (mounted) {
      final readingPage = _blockKeyToPage[sentenceKey];
      if (readingPage != null && readingPage != _activeReadingPageNumber) {
        setState(() => _activeReadingPageNumber = readingPage);
      }
    }
    if (_userScrolling || _isEditing) return;
    _scrollBlockIntoReadingBand(sentenceKey);
  }

  GlobalKey _pageKeyForDocx(int pageNumber) {
    return _docxPageKeys.putIfAbsent(pageNumber, () => GlobalKey());
  }

  void _scrollFromPosition(Duration position, Duration duration) {
    if (_userScrolling || _isEditing) return;
    if (!_contentScrollController.hasClients) return;
    final maxExtent = _contentScrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return;

    final fraction = position.inMilliseconds / duration.inMilliseconds;
    final target = fraction > 0.90 ? maxExtent : fraction * maxExtent;
    final current = _contentScrollController.offset;
    if ((target - current).abs() < 50) return;

    _contentScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollBlockIntoReadingBand(GlobalKey blockKey, {bool force = false}) {
    if (_userScrolling || _isEditing) return;
    if (!_contentScrollController.hasClients) return;

    final blockCtx = blockKey.currentContext;
    final viewportCtx = _docScrollViewportKey.currentContext;
    if (blockCtx == null || viewportCtx == null) return;

    final blockBox = blockCtx.findRenderObject() as RenderBox?;
    final viewportBox = viewportCtx.findRenderObject() as RenderBox?;
    if (blockBox == null || viewportBox == null) return;

    final topLeft = blockBox.localToGlobal(Offset.zero, ancestor: viewportBox);
    final bottomRight = blockBox.localToGlobal(
      blockBox.size.bottomRight(Offset.zero),
      ancestor: viewportBox,
    );

    final viewportHeight = viewportBox.size.height;
    final topComfort = viewportHeight * 0.18;
    final bottomComfort = viewportHeight * 0.72;
    final targetBand = viewportHeight * 0.32;
    final top = topLeft.dy;
    final bottom = bottomRight.dy;

    if (!force && top >= topComfort && bottom <= bottomComfort) {
      return;
    }

    final desiredOffset = (_contentScrollController.offset + top - targetBand)
        .clamp(0.0, _contentScrollController.position.maxScrollExtent);

    if ((desiredOffset - _contentScrollController.offset).abs() < 20) {
      return;
    }

    _contentScrollController.animateTo(
      desiredOffset,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  DocSentence? _nearestSentenceForOffset(
      PsittaDocument document, int docOffset) {
    if (document.sentences.isEmpty) return null;

    DocSentence? best;
    var bestDistance = 1 << 30;
    for (final sentence in document.sentences) {
      final distance = docOffset < sentence.startOffset
          ? sentence.startOffset - docOffset
          : docOffset > sentence.endOffset
              ? docOffset - sentence.endOffset
              : 0;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = sentence;
      }
    }
    return best;
  }

  int? _positionMsFromAlignmentPayload(
    Map<String, dynamic>? payload,
    int chunkCharOffset,
  ) {
    final alignment = payload?['alignment'];
    if (alignment is! Map) return null;
    final normalized = alignment['normalized_alignment'];
    if (normalized is! Map) return null;
    final starts = normalized['character_start_times_seconds'];
    if (starts is! List || starts.isEmpty) return null;

    final safeIndex = chunkCharOffset.clamp(0, starts.length - 1).toInt();
    final seconds = starts[safeIndex];
    if (seconds is! num) return null;
    return (seconds.toDouble() * 1000).round();
  }

  int _estimatePositionMsFromDuration(
    int chunkCharOffset,
    int chunkTextLength,
  ) {
    final durationMs = _audioService?.duration?.inMilliseconds ?? 0;
    if (durationMs <= 0 || chunkTextLength <= 0) return 0;
    final ratio = chunkCharOffset / chunkTextLength;
    return (durationMs * ratio).round();
  }

  Future<void> _scrollToDocxPage({
    required List<DocxPageLayoutPage> pages,
    required int pageNumber,
  }) async {
    if (mounted) {
      final pageProgress = pages.length <= 1
          ? 0.0
          : ((pageNumber.clamp(1, pages.length) - 1) / (pages.length - 1))
              .clamp(0.0, 1.0);
      setState(() {
        _currentDocxPageNumber = pageNumber;
        _docxDragTargetPageNumber = pageNumber;
        _docxThumbProgress = pageProgress;
      });
    }
    final pageKey = _docxPageKeys[pageNumber];
    final pageContext = pageKey?.currentContext;
    if (pageContext != null) {
      await Scrollable.ensureVisible(
        pageContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
        alignment: 0.02,
      );
      return;
    }

    final page = pages.where((candidate) => candidate.pageNumber == pageNumber);
    if (page.isEmpty) return;
    final firstBlock = page.first.blocks.isEmpty ? null : page.first.blocks.first;
    if (firstBlock == null) {
      // No block available — fall through to proportional scroll.
    } else {
      final blockKey = _docBlockKeys[firstBlock.blockId];
      if (blockKey != null && blockKey.currentContext != null) {
        _scrollBlockIntoReadingBand(blockKey, force: true);
        return;
      }
    }

    // Proportional scroll fallback (e.g. during edit mode when page/block
    // keys have no mounted context).
    if (_contentScrollController.hasClients) {
      final maxExtent = _contentScrollController.position.maxScrollExtent;
      final pageProgress = pages.length <= 1
          ? 0.0
          : ((pageNumber.clamp(1, pages.length) - 1) / (pages.length - 1))
              .clamp(0.0, 1.0);
      await _contentScrollController.animateTo(
        maxExtent * pageProgress,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _updateCurrentDocxPage(List<DocxPageLayoutPage> pages) {
    if (!mounted || pages.isEmpty) return;
    final viewportCtx = _docScrollViewportKey.currentContext;
    final viewportBox = viewportCtx?.findRenderObject() as RenderBox?;
    if (viewportBox == null) return;

    final anchorY = viewportBox.size.height * 0.22;
    var bestPage = _currentDocxPageNumber;
    var bestDistance = double.infinity;

    for (final page in pages) {
      final key = _docxPageKeys[page.pageNumber];
      final pageCtx = key?.currentContext;
      final pageBox = pageCtx?.findRenderObject() as RenderBox?;
      if (pageBox == null) continue;

      final topLeft = pageBox.localToGlobal(Offset.zero, ancestor: viewportBox);
      final bottomRight = pageBox.localToGlobal(
        pageBox.size.bottomRight(Offset.zero),
        ancestor: viewportBox,
      );
      final top = topLeft.dy;
      final bottom = bottomRight.dy;

      if (anchorY >= top && anchorY <= bottom) {
        bestPage = page.pageNumber;
        bestDistance = 0;
        break;
      }

      final distance =
          top > anchorY ? (top - anchorY).abs() : (anchorY - bottom).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestPage = page.pageNumber;
      }
    }

    final controllerProgress =
        _contentScrollController.hasClients &&
            _contentScrollController.position.maxScrollExtent > 0
        ? (_contentScrollController.offset /
                _contentScrollController.position.maxScrollExtent)
            .clamp(0.0, 1.0)
        : (pages.length <= 1
              ? 0.0
              : ((_currentDocxPageNumber.clamp(1, pages.length) - 1) /
                      (pages.length - 1))
                  .clamp(0.0, 1.0));

    if (bestPage != _currentDocxPageNumber ||
        (controllerProgress - _docxThumbProgress).abs() > 0.002) {
      setState(() {
        _currentDocxPageNumber = bestPage;
        _docxDragTargetPageNumber = bestPage;
        _docxThumbProgress = controllerProgress;
      });
    }
  }

  Future<void> _moveDocxThumbToPosition({
    required List<DocxPageLayoutPage> pages,
    required Offset globalPosition,
    required bool animate,
  }) async {
    if (pages.isEmpty) return;
    final viewportCtx = _docScrollViewportKey.currentContext;
    final viewportBox = viewportCtx?.findRenderObject() as RenderBox?;
    if (viewportBox == null) return;

    final viewportTopLeft = viewportBox.localToGlobal(Offset.zero);
    final localDy =
        (globalPosition.dy - viewportTopLeft.dy).clamp(0.0, viewportBox.size.height);
    final ratio = viewportBox.size.height <= 0
        ? 0.0
        : (localDy / viewportBox.size.height).clamp(0.0, 0.999999);
    final pageIndex =
        (ratio * pages.length).floor().clamp(0, pages.length - 1);
    final targetPage = pages[pageIndex].pageNumber;

    if (mounted &&
        ((ratio - _docxThumbProgress).abs() > 0.002 ||
            targetPage != _docxDragTargetPageNumber)) {
      setState(() {
        _docxThumbProgress = ratio;
        _docxDragTargetPageNumber = targetPage;
      });
    }

    if (_contentScrollController.hasClients) {
      final maxScrollExtent =
          _contentScrollController.position.maxScrollExtent;
      final targetOffset = maxScrollExtent <= 0 ? 0.0 : maxScrollExtent * ratio;
      if (animate) {
        await _contentScrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        _contentScrollController.jumpTo(targetOffset);
      }
      return;
    }

    if (targetPage == _docxDragTargetPageNumber) return;
    await _scrollToDocxPage(pages: pages, pageNumber: targetPage);
  }

  int? _charIndexAtMsFromAlignmentPayload(
    Map<String, dynamic>? payload,
    int tMs,
  ) {
    final alignment = payload?['alignment'];
    if (alignment is! Map) return null;
    final normalized = alignment['normalized_alignment'];
    if (normalized is! Map) return null;
    final starts = normalized['character_start_times_seconds'];
    final ends = normalized['character_end_times_seconds'];
    if (starts is! List || ends is! List) return null;
    if (starts.isEmpty || starts.length != ends.length) return null;

    final t = tMs / 1000.0;
    for (var i = 0; i < starts.length; i++) {
      final start = starts[i];
      final end = ends[i];
      if (start is! num || end is! num) return null;
      if (t >= start.toDouble() && t <= end.toDouble()) {
        return i;
      }
    }

    final lastEnd = ends.last;
    if (lastEnd is num && t > lastEnd.toDouble()) {
      return starts.length - 1;
    }
    return null;
  }

  List<int> _pdfChunkIndicesForPage(List<dynamic> chunks, int pageNumber) {
    final indices = <int>[];
    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i] as Map<String, dynamic>;
      final chunkPage = (chunk['page_number'] as num?)?.toInt() ?? 1;
      if (chunkPage == pageNumber) {
        indices.add(i);
      }
    }
    return indices;
  }

  ({int start, int end}) _trimPdfSentenceBoundary(
    String chunkText,
    List<dynamic> boundary,
  ) {
    var start =
        (boundary[0] as num).toInt().clamp(0, chunkText.length).toInt();
    var end =
        (boundary[1] as num).toInt().clamp(start, chunkText.length).toInt();
    while (start < end && RegExp(r'\s').hasMatch(chunkText[start])) {
      start++;
    }
    while (end > start && RegExp(r'\s').hasMatch(chunkText[end - 1])) {
      end--;
    }
    return (start: start, end: end);
  }

  int _pdfSentenceIndexForCharOffset(
    String chunkText,
    List<dynamic>? sentenceBoundaries,
    int charOffset,
  ) {
    if (sentenceBoundaries == null || sentenceBoundaries.isEmpty) return 0;
    for (var i = 0; i < sentenceBoundaries.length; i++) {
      final boundary = sentenceBoundaries[i] as List<dynamic>;
      final trimmed = _trimPdfSentenceBoundary(chunkText, boundary);
      final start = trimmed.start;
      final end = trimmed.end;
      if (charOffset >= start && charOffset < end) {
        return i;
      }
      if (charOffset < start) {
        return i == 0 ? 0 : i - 1;
      }
    }
    return sentenceBoundaries.length - 1;
  }

  int _resolvePdfSentenceIndex(
    String chunkText,
    List<dynamic>? sentenceBoundaries,
    double chunkRatio,
    int chunkTextLength,
  ) {
    if (sentenceBoundaries == null || sentenceBoundaries.isEmpty) return 0;
    final safeLength = chunkTextLength.clamp(1, 1 << 30).toInt();
    final safeRatio = chunkRatio.clamp(0.0, 0.999999);
    final charOffset =
        (safeRatio * safeLength).floor().clamp(0, safeLength - 1).toInt();
    return _pdfSentenceIndexForCharOffset(
      chunkText,
      sentenceBoundaries,
      charOffset,
    );
  }

  int _actualPdfSentenceIndex(
    Map<String, dynamic> chunk,
    Duration position,
    Duration duration,
    Map<String, dynamic>? alignmentPayload,
  ) {
    final boundaries = chunk['sentence_boundaries'] as List<dynamic>? ?? const [];
    if (boundaries.isEmpty) return 0;
    final text = (chunk['text_content'] ?? '').toString();
    if (text.isEmpty) return 0;
    final alignedCharOffset = _charIndexAtMsFromAlignmentPayload(
      alignmentPayload, position.inMilliseconds);
    if (alignedCharOffset != null) {
      return _pdfSentenceIndexForCharOffset(text, boundaries, alignedCharOffset);
    }
    if (duration.inMilliseconds <= 0) return 0;
    final ratio = (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 0.999999);
    final charOffset = (ratio * text.length).floor().clamp(0, text.length - 1).toInt();
    return _pdfSentenceIndexForCharOffset(text, boundaries, charOffset);
  }

  int _activePdfSentenceIndex(
    Map<String, dynamic> chunk,
    Duration position,
    Duration duration,
    Map<String, dynamic>? alignmentPayload,
  ) {
    final boundaries = chunk['sentence_boundaries'] as List<dynamic>? ?? const [];
    if (boundaries.isEmpty) return 0;
    final text = (chunk['text_content'] ?? '').toString();
    if (text.isEmpty) return 0;

    // Look-ahead: shift position forward by 400ms so the highlight
    // transitions to the next sentence slightly BEFORE the voice arrives.
    // This ensures the highlight always leads the voice, never lags behind.
    const lookAheadMs = 600;
    final lookaheadPositionMs = position.inMilliseconds + lookAheadMs;

    final alignedCharOffset = _charIndexAtMsFromAlignmentPayload(
      alignmentPayload,
      lookaheadPositionMs,
    );
    if (alignedCharOffset != null) {
      return _pdfSentenceIndexForCharOffset(text, boundaries, alignedCharOffset);
    }

    if (duration.inMilliseconds <= 0) return 0;
    final ratio =
        (lookaheadPositionMs / duration.inMilliseconds).clamp(0.0, 0.999999);
    final charOffset =
        (ratio * text.length).floor().clamp(0, text.length - 1).toInt();
    return _pdfSentenceIndexForCharOffset(text, boundaries, charOffset);
  }

  PdfReadingHighlight? _buildPdfHighlight({
    required List<dynamic> chunks,
    required int currentIndex,
    required Duration position,
    required Duration duration,
    required bool isPlaying,
    required Map<String, dynamic>? alignmentPayload,
  }) {
    if (chunks.isEmpty || currentIndex < 0 || currentIndex >= chunks.length) {
      return null;
    }
    final chunk = chunks[currentIndex] as Map<String, dynamic>;
    final pageNumber = (chunk['page_number'] as num?)?.toInt();
    if (pageNumber == null) return null;
    final chunkText = (chunk['text_content'] ?? '').toString();
    final sentenceBoundaries =
        chunk['sentence_boundaries'] as List<dynamic>? ?? const [];
    if (chunkText.isEmpty || sentenceBoundaries.isEmpty) return null;

    final sentenceIndex = ((!isPlaying || _hasPendingPdfJump) &&
            _focusedPdfChunkIndex == currentIndex &&
            _focusedPdfSentenceIndex != null)
        ? _focusedPdfSentenceIndex!
        : _activePdfSentenceIndex(
            chunk,
            position,
            duration,
            alignmentPayload,
          );
    final safeSentenceIndex =
        sentenceIndex.clamp(0, sentenceBoundaries.length - 1).toInt();

    // Dual highlight: show current + next sentence during transition.
    final actualIdx = _actualPdfSentenceIndex(
      chunk, position, duration, alignmentPayload);
    final safeActual = actualIdx.clamp(0, sentenceBoundaries.length - 1).toInt();
    final int? endSentenceIndex = (safeSentenceIndex > safeActual)
        ? safeSentenceIndex
        : null;
    final startSentenceIndex = endSentenceIndex != null
        ? safeActual
        : safeSentenceIndex;
    return PdfReadingHighlight(
      pageNumber: pageNumber,
      chunkIndex: currentIndex,
      sentenceIndex: startSentenceIndex,
      endSentenceIndex: endSentenceIndex,
    );
  }

  Future<void> _jumpToPdfLocation({
    required List<dynamic> chunks,
    required int pageNumber,
    double? pageTopRatio,
    int? targetChunkIndex,
    int? targetSentenceIndex,
    bool autoPlay = true,
    bool forcePlay = false,
  }) async {
    final jumpRequestId = ++_pdfJumpRequestSeq;
    final pageChunkIndices = _pdfChunkIndicesForPage(chunks, pageNumber);
    if (pageChunkIndices.isEmpty) return;

    var resolvedChunkIndex = targetChunkIndex ?? pageChunkIndices.first;
    if (targetChunkIndex == null &&
        pageTopRatio != null &&
        pageChunkIndices.length > 1) {
      final lengths = pageChunkIndices
          .map((index) =>
              ((chunks[index] as Map<String, dynamic>)['text_content'] ?? '')
                  .toString()
                  .length
                  .clamp(1, 1 << 30)
                  .toInt())
          .toList();
      final totalLength = lengths.fold<int>(0, (sum, len) => sum + len);
      var cumulative = 0.0;
      for (var i = 0; i < pageChunkIndices.length; i++) {
        final span =
            totalLength > 0 ? lengths[i] / totalLength : 1.0 / pageChunkIndices.length;
        final next = cumulative + span;
        if (pageTopRatio <= next || i == pageChunkIndices.length - 1) {
          resolvedChunkIndex = pageChunkIndices[i];
          break;
        }
        cumulative = next;
      }
    }

    final targetChunk = chunks[resolvedChunkIndex] as Map<String, dynamic>;
    final chunkId = (targetChunk['id'] ?? '').toString();
    if (chunkId.isEmpty) return;

    final chunkText = (targetChunk['text_content'] ?? '').toString();
    final sentenceBoundaries =
        targetChunk['sentence_boundaries'] as List<dynamic>? ?? const [];
    var sentenceIndex = targetSentenceIndex ?? 0;
    var chunkOffset = 0;
    if (targetSentenceIndex != null && sentenceBoundaries.isNotEmpty) {
      sentenceIndex =
          targetSentenceIndex.clamp(0, sentenceBoundaries.length - 1).toInt();
      final boundary = sentenceBoundaries[sentenceIndex] as List<dynamic>;
      final trimmedBoundary = _trimPdfSentenceBoundary(chunkText, boundary);
      chunkOffset = trimmedBoundary.start;
    } else if (pageTopRatio != null && sentenceBoundaries.isNotEmpty) {
      final chunkLengths = pageChunkIndices
          .map((index) =>
              ((chunks[index] as Map<String, dynamic>)['text_content'] ?? '')
                  .toString()
                  .length
                  .clamp(1, 1 << 30)
                  .toInt())
          .toList();
      final totalLength = chunkLengths.fold<int>(0, (sum, len) => sum + len);
      var precedingLength = 0;
      for (var i = 0; i < pageChunkIndices.length; i++) {
        if (pageChunkIndices[i] == resolvedChunkIndex) break;
        precedingLength += chunkLengths[i];
      }
      final chunkPosition = pageChunkIndices.indexOf(resolvedChunkIndex);
      final chunkLength =
          chunkPosition >= 0 ? chunkLengths[chunkPosition] : chunkText.length;
      final chunkTopRatio =
          totalLength > 0 ? precedingLength / totalLength : 0.0;
      final chunkHeightRatio =
          totalLength > 0 ? chunkLength / totalLength : 1.0;
      final localRatio = chunkHeightRatio > 0
          ? ((pageTopRatio - chunkTopRatio) / chunkHeightRatio).clamp(0.0, 0.999999)
          : 0.0;
      sentenceIndex = _resolvePdfSentenceIndex(
        chunkText,
        sentenceBoundaries,
        localRatio,
        chunkText.length,
      );
      final boundary = sentenceBoundaries[sentenceIndex] as List<dynamic>;
      final trimmedBoundary = _trimPdfSentenceBoundary(chunkText, boundary);
      chunkOffset = trimmedBoundary.start;
    } else if (sentenceBoundaries.isNotEmpty) {
      final trimmedBoundary =
          _trimPdfSentenceBoundary(chunkText, sentenceBoundaries.first as List<dynamic>);
      chunkOffset = trimmedBoundary.start;
    }

    final audioService = _audioService;
    if (audioService == null) return;
    final wasPlaying = audioService.isPlaying ||
        (ref.read(audioPlayingProvider).valueOrNull ?? false);
    final voiceId = ref.read(selectedVoiceIdProvider);
    final speed = ref.read(selectedSpeedProvider);
    final volume = ref.read(selectedVolumeProvider);
    final alignmentKey = AlignmentKey(
      documentId: widget.documentId,
      chunkId: chunkId,
      voiceId: voiceId,
    );
    final cachedAlignment =
        ref.read(chunkAlignmentProvider(alignmentKey)).valueOrNull;
    final alignmentFuture = cachedAlignment != null
        ? Future<Map<String, dynamic>?>.value(cachedAlignment)
        : ref
            .read(chunkAlignmentProvider(alignmentKey).future)
            .then<Map<String, dynamic>?>((value) => value)
            .catchError((_) => null);

    setState(() {
      _focusedPdfChunkIndex = resolvedChunkIndex;
      _focusedPdfSentenceIndex = sentenceIndex;
      _lastAutoFollowedPdfPage = pageNumber;
      _hasPendingPdfJump = true;
      _pendingPdfJumpTargetMs = null;
    });

    ref.read(currentChunkIndexProvider.notifier).state = resolvedChunkIndex;
    audioService.updateTrackingChunk(resolvedChunkIndex);

    final loaded = await audioService.prepareChunk(
      documentId: widget.documentId,
      chunkId: chunkId,
      voiceId: voiceId,
      speed: speed,
      volume: volume,
    );
    if (!loaded || !mounted || jumpRequestId != _pdfJumpRequestSeq) {
      if (mounted && jumpRequestId == _pdfJumpRequestSeq) {
        setState(() {
          _hasPendingPdfJump = false;
          _pendingPdfJumpTargetMs = null;
        });
      }
      return;
    }

    final alignmentPayload = await alignmentFuture;
    if (!mounted || jumpRequestId != _pdfJumpRequestSeq) return;

    final targetMs = _positionMsFromAlignmentPayload(
          alignmentPayload,
          chunkOffset,
        ) ??
        _estimatePositionMsFromDuration(
          chunkOffset,
          chunkText.length,
        );
    setState(() {
      _pendingPdfJumpTargetMs = targetMs;
    });
    await audioService.seek(Duration(milliseconds: targetMs));
    if (jumpRequestId != _pdfJumpRequestSeq) return;
    if (forcePlay || (autoPlay && wasPlaying)) {
      await audioService.play();
    }
  }

  Future<void> _jumpToDocumentOffset({
    required PsittaDocument document,
    required int docOffset,
    String? preferredBlockId,
    bool autoPlay = true,
    bool forcePlay = false,
  }) async {
    final jumpRequestId = ++_docxJumpRequestSeq;
    final AudioService audioService =
        _audioService ?? ref.read(audioServiceProvider);
    final chunkIds = ref.read(activeChunkIdsProvider);
    final targetSentence = document.sentenceForOffset(docOffset) ??
        _nearestSentenceForOffset(document, docOffset);
    final targetOffset = targetSentence?.startOffset ?? docOffset;
    final targetChunk = document.chunkForOffset(targetOffset);
    if (targetChunk == null) return;
    if (targetChunk.chunkIndex < 0 ||
        targetChunk.chunkIndex >= chunkIds.length) {
      return;
    }

    String? targetBlockId;
    if (targetSentence != null && targetSentence.blockIds.isNotEmpty) {
      targetBlockId = targetSentence.blockIds.first;
    } else {
      targetBlockId =
          preferredBlockId ?? document.blockForOffset(targetOffset)?.blockId;
    }

    if (targetBlockId != null) {
      final key = _docBlockKeys[targetBlockId];
      if (key != null) {
        _scrollBlockIntoReadingBand(key, force: true);
      }
    }

    final wasPlaying = audioService.isPlaying ||
        (ref.read(audioPlayingProvider).valueOrNull ?? false);
    final targetChunkIndex = targetChunk.chunkIndex;
    final targetChunkId = chunkIds[targetChunkIndex];
    final chunkOffset = document.toChunkOffset(targetOffset, targetChunk);
    final voiceId = ref.read(selectedVoiceIdProvider);
    final speed = ref.read(selectedSpeedProvider);
    final volume = ref.read(selectedVolumeProvider);

    final cachedAlignment = ref
        .read(
          chunkAlignmentProvider(
            AlignmentKey(
              documentId: widget.documentId,
              chunkId: targetChunkId,
              voiceId: voiceId,
            ),
          ),
        )
        .valueOrNull;

    if (mounted) {
      setState(() {
        _focusedDocxSentenceIndex = targetSentence?.index;
        _hasPendingDocxJump = true;
        _pendingDocxJumpTargetMs = null;
      });
    }

    if (!autoPlay && wasPlaying) {
      await audioService.pause();
    }

    ref.read(currentChunkIndexProvider.notifier).state = targetChunkIndex;
    audioService.updateTrackingChunk(targetChunkIndex);

    final loaded = await audioService.prepareChunk(
      documentId: widget.documentId,
      chunkId: targetChunkId,
      voiceId: voiceId,
      speed: speed,
      volume: volume,
    );

    if (!loaded || !mounted || jumpRequestId != _docxJumpRequestSeq) {
      if (mounted) {
        setState(() {
          _hasPendingDocxJump = false;
          _pendingDocxJumpTargetMs = null;
        });
      }
      return;
    }

    final targetMs = _positionMsFromAlignmentPayload(
            cachedAlignment, chunkOffset) ??
        _estimatePositionMsFromDuration(chunkOffset, targetChunk.textLength);

    if (mounted) {
      setState(() {
        _pendingDocxJumpTargetMs = targetMs;
      });
    }

    await audioService.seek(Duration(milliseconds: targetMs));
    if (jumpRequestId != _docxJumpRequestSeq) return;

    if (forcePlay || (autoPlay && wasPlaying)) {
      await audioService.play();
    }
  }

  Future<void> _goToPdfPageTop(int pageNumber) async {
    if (!_pdfViewerController.isReady) return;
    await _pdfViewerController.goToPage(
      pageNumber: pageNumber,
      anchor: PdfPageAnchor.top,
    );
  }

  void _prefetchNextPdfChunk(
    List<dynamic> chunks,
    int currentIndex,
    String voiceId,
  ) {
    if (currentIndex < 0 || currentIndex >= chunks.length - 1) return;
    if (_lastPdfPrefetchedChunkIndex == currentIndex) return;

    final nextChunk = chunks[currentIndex + 1] as Map<String, dynamic>;
    final nextChunkId = (nextChunk['id'] ?? '').toString();
    if (nextChunkId.isEmpty) return;

    _lastPdfPrefetchedChunkIndex = currentIndex;
    final audioService = ref.read(audioServiceProvider);
    unawaited(audioService.prefetchChunk(
      documentId: widget.documentId,
      chunkId: nextChunkId,
      voiceId: voiceId,
    ));
    unawaited(
      ref.read(
        chunkAlignmentProvider(
          AlignmentKey(
            documentId: widget.documentId,
            chunkId: nextChunkId,
            voiceId: voiceId,
          ),
        ).future,
      ).catchError((_) => <String, dynamic>{}),
    );
  }

  void _publishNowReading({
    required String chunkTitle,
    required String chunkText,
    required int currentIndex,
    required int total,
  }) {
    final excerpt = _truncate(chunkText, 140);
    final line =
        '$chunkTitle \u2022 ${currentIndex + 1}/$total \u2022 $excerpt';
    ref.read(nowReadingTextProvider.notifier).state = line;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chunksAsync = ref.watch(chunksProvider(widget.documentId));
    final activeChunkIndex = ref.watch(currentChunkIndexProvider);
    final isSynthesizing =
        ref.watch(isSynthesizingProvider).valueOrNull ?? false;
    final editorState = ref.watch(chunkEditorProvider);

    final uri = GoRouterState.of(context).uri;
    final autoplayParam = uri.queryParameters['autoplay']?.toLowerCase().trim();
    final shouldAutoPlay = !(autoplayParam == '0' || autoplayParam == 'false');
    final swhParam = uri.queryParameters['swh']?.toLowerCase().trim();
    final swhEnabled = !(swhParam == '0' || swhParam == 'false');

    // When SWH is OFF, drive auto-scroll from audio position fraction.
    // When SWH is ON, _onActiveWordChanged handles scroll instead.
    if (!swhEnabled) {
      ref.listen<AsyncValue<Duration>>(audioPositionProvider, (_, next) {
        if (_isEditing) return;
        final position = next.valueOrNull;
        if (position == null) return;
        final duration = ref.read(audioDurationProvider).valueOrNull;
        if (duration == null || duration.inMilliseconds == 0) return;
        if (_activeSentenceBoundaries == null ||
            _activeSentenceBoundaries!.isEmpty) {
          _scrollFromPosition(position, duration);
        }
        // When sentenceBoundaries exist, scroll is driven by onActiveSentenceChanged instead.
      });
    }

    final body = chunksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Failed to load document', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('$err', style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  ref.invalidate(chunksProvider(widget.documentId)),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (data) {
        final chunks = (data['chunks'] as List<dynamic>?) ?? [];
        if (chunks.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.article_outlined,
                    size: 48, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No content available',
                    style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final chunkIds = chunks
              .map<String>(
                  (c) => ((c as Map<String, dynamic>)['id'] ?? '').toString())
              .toList();
          ref.read(activeChunkIdsProvider.notifier).state = chunkIds;
          ref.read(totalChunksProvider.notifier).state = chunks.length;
          if (!_hasAutoPlayed && chunkIds.isNotEmpty && shouldAutoPlay) {
            _hasAutoPlayed = true;
            final idx = ref.read(currentChunkIndexProvider);
            final docId = ref.read(activeDocumentIdProvider);
            if (docId != null && idx < chunkIds.length) {
              final audioService = ref.read(audioServiceProvider);
              final voiceId = ref.read(selectedVoiceIdProvider);
              final speed = ref.read(selectedSpeedProvider);
              final volume = ref.read(selectedVolumeProvider);
              audioService.playChunk(
                documentId: docId,
                chunkId: chunkIds[idx],
                voiceId: voiceId,
                speed: speed,
                volume: volume,
              );
              // Seek to restored position after audio loads
              if (_restorePositionMs > 0) {
                final restoreMs = _restorePositionMs;
                _restorePositionMs = 0;
                audioService.playingStream
                    .firstWhere((playing) => playing)
                    .then((_) {
                  audioService.seek(Duration(milliseconds: restoreMs));
                }).catchError((_) {});
              }
            }
          }
        });

        final currentIndex = activeChunkIndex.clamp(0, chunks.length - 1);
        final activeChunk = chunks[currentIndex] as Map<String, dynamic>;
        final chunkId = (activeChunk['id'] ?? '').toString();
        final chunkTitle =
            (activeChunk['title'] ?? 'Section ${currentIndex + 1}').toString();
        final chunkText = (activeChunk['text_content'] ?? '').toString();
        final sentenceBoundaries =
            activeChunk['sentence_boundaries'] as List<dynamic>?;
        final formattedContent =
            activeChunk['formatted_content'] as List<dynamic>?;
        _activeSentenceBoundaries = sentenceBoundaries;
        final resolvedDoc = _resolveDocument(ref);
        final isPdfDocument =
            (resolvedDoc?.sourceType.toLowerCase() ?? '') == 'pdf';
        final isDocxDocument =
            (resolvedDoc?.sourceType.toLowerCase() ?? '') == 'docx';

        // Only the legacy chunk editor should auto-exit on chunk switches.
        if (_isEditing &&
            _editingDocxDocument == null &&
            _editingChunkId != chunkId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _exitEditMode();
          });
        }

        // The auto-enter-edit-mode branch for ?edit=1 was moved below the
        // DocumentAssembler.assemble() call so it can pass psittaDoc into
        // _enterDocxEditMode. See the block immediately after psittaDoc is
        // assigned.

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _publishNowReading(
            chunkTitle: chunkTitle,
            chunkText: chunkText,
            currentIndex: currentIndex,
            total: chunks.length,
          );
        });

        final voiceId = ref.watch(selectedVoiceIdProvider);
        final pdfPlaybackCacheKey = isPdfDocument
            ? '${widget.documentId}_$voiceId'
            : null;
        if (pdfPlaybackCacheKey != null &&
            _clearedPdfPlaybackCacheKey != pdfPlaybackCacheKey) {
          _clearedPdfPlaybackCacheKey = pdfPlaybackCacheKey;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final audioService = ref.read(audioServiceProvider);
            for (final rawChunk in chunks) {
              final chunk = rawChunk as Map<String, dynamic>;
              final pdfChunkId = (chunk['id'] ?? '').toString();
              if (pdfChunkId.isEmpty) continue;
              unawaited(audioService.invalidateChunkCache(pdfChunkId));
              ref.invalidate(
                chunkAlignmentProvider(
                  AlignmentKey(
                    documentId: widget.documentId,
                    chunkId: pdfChunkId,
                    voiceId: voiceId,
                  ),
                ),
              );
            }
            _lastPdfPrefetchedChunkIndex = null;
          });
        }

        // PDFs now render from the original file, so chunk alignment is only
        // needed for non-PDF fallback rendering.
        final alignmentAsync = chunkId.isEmpty
            ? const AsyncValue<Map<String, dynamic>>.data({})
            : ref.watch(
                chunkAlignmentProvider(
                  AlignmentKey(
                    documentId: widget.documentId,
                    chunkId: chunkId,
                    voiceId: voiceId,
                  ),
                ),
              );

        final alignmentPayload = alignmentAsync.valueOrNull;
        final hasAlignment =
            alignmentPayload != null && alignmentPayload['alignment'] != null;
        final isFetchingAlignment = alignmentAsync.isLoading;
        final audioPosition =
            ref.watch(audioPositionProvider).valueOrNull ?? Duration.zero;
        final audioDuration =
            ref.watch(audioDurationProvider).valueOrNull ?? Duration.zero;
        final isAudioPlaying =
            ref.watch(audioPlayingProvider).valueOrNull ?? false;

        // ── Assemble document model ──────────────────────────────────
        final psittaDoc = isPdfDocument
            ? const PsittaDocument(
                id: '',
                title: '',
                blocks: [],
                plainText: '',
                sentences: [],
                chunkMap: [],
              )
            : DocumentAssembler.assemble(
                data: data,
                title: chunkTitle,
                sourceType: resolvedDoc?.sourceType,
              );
        // Capture for find-bar shortcut callbacks outside this builder.
        _currentPsittaDoc = psittaDoc;

        // Auto-enter edit mode when ?edit=1 is passed (e.g. from New Sheet).
        // For DOCX documents (new blank sheets now come through as DOCX),
        // route to the DOCX block editor so the user lands in the
        // page-styled Word-like editor. Legacy source_type='blank' docs
        // keep using the inline chunk editor.
        final editParam = uri.queryParameters['edit']?.trim();
        if (_autoEditPending && editParam == '1' && !_isEditing) {
          _autoEditPending = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (isDocxDocument) {
              _enterDocxEditMode(psittaDoc, chunks);
              // In per-paragraph fallback mode, request focus on the
              // first block's Quill editor so the caret is visible
              // immediately. Unified mode handles its own post-frame
              // focus request inside _enterDocxEditModeUnified.
              if (!_docxUnifiedEditMode) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  if (psittaDoc.blocks.isNotEmpty) {
                    _docxBlockFocusNodes[psittaDoc.blocks.first.blockId]
                        ?.requestFocus();
                  }
                });
              }
            } else {
              _enterEditMode(chunkId, chunkText);
            }
          });
        } else if (_autoEditPending) {
          _autoEditPending = false;
        }

        final pdfHighlight = isPdfDocument
            ? _buildPdfHighlight(
                chunks: chunks,
                currentIndex: currentIndex,
                position: audioPosition,
                duration: audioDuration,
                isPlaying: isAudioPlaying,
                alignmentPayload: alignmentPayload,
              )
            : null;

        if (isPdfDocument) {
          _prefetchNextPdfChunk(chunks, currentIndex, voiceId);
        }

        if (isPdfDocument && isAudioPlaying) {
          final activePdfPageNumber =
              (activeChunk['page_number'] as num?)?.toInt() ?? 1;
          if (_pdfViewerController.isReady &&
              _lastAutoFollowedPdfPage != activePdfPageNumber) {
            _lastAutoFollowedPdfPage = activePdfPageNumber;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _goToPdfPageTop(activePdfPageNumber);
            });
          }
        }

        // ── Build text content area ──────────────────────────────────
        final docxPages = isDocxDocument
            ? paginateDocxDocument(context, psittaDoc)
            : const <DocxPageLayoutPage>[];
        final docxBlockPageMap = <String, int>{
          for (final page in docxPages)
            for (final block in page.blocks) block.blockId: page.pageNumber,
        };
        _docxBlockPageMap = docxBlockPageMap;
        // Reading-derived block→page map: composes the live blockId→page map with
        // the live blockId→GlobalKey registry so the active-sentence callback key
        // resolves to a page in O(1). Rebuilt per-frame to match docxBlockPageMap.
        _blockKeyToPage = {
          for (final entry in _docBlockKeys.entries)
            if (docxBlockPageMap[entry.key] != null)
              entry.value: docxBlockPageMap[entry.key]!,
        };
        if (isDocxDocument && !_isEditing && docxPages.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateCurrentDocxPage(docxPages);
          });
        }

        Widget textWidget;
        if (isPdfDocument) {
          textWidget = PdfDocumentViewport(
            key: ValueKey('pdf_${widget.documentId}'),
            documentId: widget.documentId,
            chunks: chunks,
            controller: _pdfViewerController,
            highlight: pdfHighlight,
            alignmentPayload: alignmentPayload,
            findMatch: _currentPdfFindMatch,
            onDocumentLoaded: (documentRef, outline) {
              if (!mounted) return;
              final activePdfPageNumber =
                  (activeChunk['page_number'] as num?)?.toInt() ?? 1;
              setState(() {
                _pdfDocumentRef = documentRef;
                _pdfOutline = outline;
                _lastAutoFollowedPdfPage = activePdfPageNumber;
              });
              // Replay any query the user typed before the document
              // finished loading. Clearing the pending slot first avoids
              // a re-entrant stash from _onFindQueryChanged.
              final pending = _pendingFindQuery;
              if (pending.isNotEmpty) {
                _pendingFindQuery = '';
                _onFindQueryChanged(pending);
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _goToPdfPageTop(activePdfPageNumber);
              });
            },
            onSentenceTap: (target) async {
              await _jumpToPdfLocation(
                chunks: chunks,
                pageNumber: target.pageNumber,
                targetChunkIndex: target.chunkIndex,
                targetSentenceIndex: target.sentenceIndex,
                autoPlay: true,
                forcePlay: true,
              );
            },
            onPageTap: (hitTest) async {
              final fromTopRatio =
                  (1 - (hitTest.offset.dy / hitTest.page.height))
                      .clamp(0.0, 1.0);
              await _jumpToPdfLocation(
                chunks: chunks,
                pageNumber: hitTest.page.pageNumber,
                pageTopRatio: fromTopRatio,
                autoPlay: false,
              );
            },
          );
        } else if (isDocxDocument && psittaDoc.blocks.isNotEmpty) {
          debugPrint('[DOCX ALIGN DEBUG] chunkId=$chunkId alignmentPayload.keys=${alignmentPayload?.keys.toList()} hasAlignment=$hasAlignment isFetching=$isFetchingAlignment');
          textWidget = DocxDocumentViewport(
            key: ValueKey('docx_${widget.documentId}_$voiceId'),
            document: psittaDoc,
            pages: docxPages,
            activeChunkIndex: currentIndex,
            alignmentPayload: alignmentPayload ?? const {},
            focusedSentenceIndex:
                _hasPendingDocxJump ? _focusedDocxSentenceIndex : null,
            isFetchingAlignment: isFetchingAlignment,
            findMatchStart: _isEditing ? null : _docxFindMatchStart,
            findMatchEnd: _isEditing ? null : _docxFindMatchEnd,
            editorChild: _isEditing && _editingDocxDocument != null
                ? DocxDocumentEditor(
                    key: ValueKey(_docxUnifiedEditMode
                        ? 'docx_edit_unified_${widget.documentId}'
                        : 'docx_edit_${widget.documentId}'),
                    document: _editingDocxDocument!,
                    controllers: _docxUnifiedEditMode
                        ? const {}
                        : _docxBlockControllers,
                    focusNodes: _docxUnifiedEditMode
                        ? const {}
                        : _docxBlockFocusNodes,
                    unifiedController: _docxUnifiedEditMode
                        ? _docxUnifiedController
                        : null,
                    unifiedFocusNode: _docxUnifiedEditMode
                        ? _docxUnifiedFocusNode
                        : null,
                    unifiedEditorKey:
                        _docxUnifiedEditMode ? _unifiedEditorKey : null,
                    isSaving: editorState.isSaving,
                    error: editorState.error,
                    onActiveControllerChanged: (controller) {
                      if (_activeDocxController != controller && mounted) {
                        setState(() {
                          _activeDocxController = controller;
                        });
                      }
                    },
                    onChanged: _docxUnifiedEditMode
                        ? _handleDocxUnifiedChanged
                        : _handleDocxPerParagraphChanged(psittaDoc),
                  )
                : null,
            onActiveSentenceChanged: _scrollFromSentence,
            onActiveWordChanged: _onActiveWordChanged,
            onSentenceTap: (docOffset) => _jumpToDocumentOffset(
              document: psittaDoc,
              docOffset: docOffset,
              autoPlay: true,
              forcePlay: true,
            ),
            onLinePlayTap: (docOffset) => _jumpToDocumentOffset(
              document: psittaDoc,
              docOffset: docOffset,
              autoPlay: true,
              forcePlay: true,
            ),
            audioService: _audioService,
            blockKeys: _docBlockKeys,
            pageKeys: {
              for (final page in docxPages) page.pageNumber: _pageKeyForDocx(page.pageNumber),
            },
            textScale: _textScale,
          );
        } else if (_isEditing && _editingChunkId == chunkId) {
          // Keep the existing non-DOCX editing fallback unchanged.
          textWidget = InlineChunkEditor(
            key: ValueKey('edit_$chunkId'),
            initialText: _originalText,
            controller: _editController,
            focusNode: _editFocusNode,
            onSave: () => _saveInlineEdit(chunkId),
            onDiscard: _discardInlineEdit,
            isSaving: editorState.isSaving,
            error: editorState.error,
          );
        } else if (psittaDoc.blocks.isNotEmpty) {
          // Document-native rendering
          textWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isFetchingAlignment && !hasAlignment)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: theme.colorScheme.primary.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Loading word highlighting\u2026',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              DocumentReadingView(
                key: ValueKey('doc_${widget.documentId}_$voiceId'),
                document: psittaDoc,
                activeChunkIndex: currentIndex,
                alignmentPayload: alignmentPayload ?? const {},
                onActiveSentenceChanged: _scrollFromSentence,
                onActiveWordChanged: _onActiveWordChanged,
                audioService: _audioService,
                enableContextMenu: true,
                blockKeys: _docBlockKeys,
                textScale: _textScale,
              ),
            ],
          );
        } else {
          // Fallback: old WordHighlightView for edge cases
          textWidget = WordHighlightView(
            key: ValueKey('${chunkId}_${voiceId}_plain'),
            chunkText: chunkText,
            alignmentPayload: alignmentPayload ?? const {},
            sentenceBoundaries: sentenceBoundaries,
            formattedContent: formattedContent,
            onActiveWordChanged: _onActiveWordChanged,
            onActiveSentenceChanged: _scrollFromSentence,
            enableContextMenu: true,
            audioService: _audioService,
          );
        }

        // Resolve document model for cover data
        final activeDoc = _resolveDocument(ref);

        // ── Build document outline from heading blocks ──
        final outlineEntries = <_OutlineEntry>[];
        final docxContentsEntries = <DocxNavigatorEntry>[];
        for (final block in psittaDoc.blocks) {
          if (block.type == DocBlockType.heading) {
            outlineEntries.add(_OutlineEntry(
              blockId: block.blockId,
              title: block.plainText,
              level: block.level ?? 1,
            ));
            if (isDocxDocument) {
              docxContentsEntries.add(DocxNavigatorEntry(
                blockId: block.blockId,
                title: block.plainText,
                level: block.level ?? 1,
                pageNumber: docxBlockPageMap[block.blockId] ?? 1,
              ));
            }
          }
        }

        return Stack(
          children: [
            Row(
              children: [
                // ── Left sidebar: cover + document outline ──
                SizedBox(
                  width: 280,
                  child: Container(
                    color: theme.colorScheme.surfaceContainerLow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Document cover image
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Center(
                            child: SizedBox(
                              width: 220,
                              child: Material(
                                elevation: 2,
                                borderRadius: BorderRadius.circular(12),
                                clipBehavior: Clip.antiAlias,
                                color: Colors.transparent,
                                child: DocumentCover(
                                  coverType: activeDoc?.coverType,
                                  coverValue: activeDoc?.coverValue,
                                  documentId: widget.documentId,
                                  size: DocumentCoverSize.player,
                                  sourceType: activeDoc?.sourceType,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Document title below cover
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                          child: Text(
                            activeDoc?.title ?? '',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (isPdfDocument || isDocxDocument)
                                    ? 'Navigator'
                                    : 'Outline',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.record_voice_over,
                                    size: 14,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Voice: ${_voiceName(ref)}',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Document navigator / outline
                        Expanded(
                          child: isPdfDocument
                              ? PdfPlayerNavigator(
                                  controller: _pdfViewerController,
                                  documentRef: _pdfDocumentRef,
                                  outline: _pdfOutline,
                                  onOutlineSelected: (node) async {
                                    final pageNumber = node.dest?.pageNumber ??
                                        _pdfViewerController.pageNumber ??
                                        ((activeChunk['page_number'] as num?)
                                                ?.toInt() ??
                                            1);
                                    await _goToPdfPageTop(pageNumber);
                                    await _jumpToPdfLocation(
                                      chunks: chunks,
                                      pageNumber: pageNumber,
                                    );
                                  },
                                  onThumbnailSelected: (pageNumber) async {
                                    await _goToPdfPageTop(pageNumber);
                                    await _jumpToPdfLocation(
                                      chunks: chunks,
                                      pageNumber: pageNumber,
                                    );
                                  },
                                )
                              : isDocxDocument
                                  ? DocxPlayerNavigator(
                                      pages: docxPages,
                                      contents: docxContentsEntries,
                                      activePageNumber: _activeReadingPageNumber,
                                      onContentsSelected: (entry) async {
                                        DocBlock? block;
                                        for (final candidate
                                            in psittaDoc.blocks) {
                                          if (candidate.blockId ==
                                              entry.blockId) {
                                            block = candidate;
                                            break;
                                          }
                                        }
                                        if (block == null) return;
                                        await _jumpToDocumentOffset(
                                          document: psittaDoc,
                                          docOffset: block.textOffset,
                                          preferredBlockId: entry.blockId,
                                        );
                                      },
                                      onThumbnailSelected: (pageNumber) async {
                                        // Set active page first so the
                                        // navigator's existing highlight +
                                        // rail-scroll (driven by
                                        // activePageNumber) fire instantly,
                                        // before the main-pane scroll.
                                        if (mounted) {
                                          setState(() => _activeReadingPageNumber =
                                              pageNumber);
                                        }
                                        await _scrollToDocxPage(
                                          pages: docxPages,
                                          pageNumber: pageNumber,
                                        );
                                      },
                                    )
                              : outlineEntries.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          'No headings found',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme.colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      itemCount: outlineEntries.length,
                                      itemBuilder: (context, index) {
                                        final entry = outlineEntries[index];
                                        final indent =
                                            ((entry.level - 1) * 16.0)
                                                .clamp(0.0, 48.0);
                                        return InkWell(
                                          onTap: () async {
                                            DocBlock? block;
                                            for (final candidate
                                                in psittaDoc.blocks) {
                                              if (candidate.blockId ==
                                                  entry.blockId) {
                                                block = candidate;
                                                break;
                                              }
                                            }
                                            if (block == null) return;
                                            await _jumpToDocumentOffset(
                                              document: psittaDoc,
                                              docOffset: block.textOffset,
                                              preferredBlockId: entry.blockId,
                                            );
                                          },
                                          child: Padding(
                                            padding: EdgeInsets.fromLTRB(
                                                16 + indent, 8, 16, 8),
                                            child: Text(
                                              entry.title,
                                              style: theme
                                                  .textTheme.bodyMedium
                                                  ?.copyWith(
                                                fontWeight: entry.level <= 1
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                // ── Main document canvas ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Document-level header
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              tooltip: widget.originProjectId != null
                                  ? widget.originProjectName ?? 'Project'
                                  : 'Library',
                              onPressed: () async {
                                final router = GoRouter.of(context);
                                if (_hasUnsavedChanges) {
                                  final proceed = await _guardUnsavedChanges();
                                  if (!proceed || !mounted) return;
                                } else if (_isEditing) {
                                  _exitEditMode();
                                }
                                if (!mounted) return;
                                if (widget.originProjectId != null) {
                                  router.go(
                                    '/projects/${widget.originProjectId}'
                                    '?projectName=${Uri.encodeComponent(widget.originProjectName ?? 'Project')}',
                                  );
                                } else {
                                  router.go('/');
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                activeDoc?.title ?? psittaDoc.title,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (isDocxDocument && !_isEditing) ...[
                              IconButton(
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                tooltip: 'Edit document',
                                onPressed: () =>
                                    _enterDocxEditMode(psittaDoc, chunks),
                              ),
                            ],
                            if (isDocxDocument && _isEditing)
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.save_outlined,
                                      size: 18,
                                      color: theme.colorScheme.primary,
                                    ),
                                    tooltip: 'Save document',
                                    onPressed: editorState.isSaving
                                        ? null
                                        : () => _saveDocxEdit(
                                              _editingDocxDocument!,
                                            ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      size: 18,
                                      color: theme.colorScheme.error,
                                    ),
                                    tooltip: 'Cancel editing',
                                    onPressed: () async {
                                      if (_hasUnsavedChanges) {
                                        final proceed =
                                            await _guardUnsavedChanges();
                                        if (!proceed) return;
                                      } else {
                                        _exitEditMode();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            if (hasAlignment) ...[
                              Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color:
                                    theme.colorScheme.primary.withOpacity(0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Word sync',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.7),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        // ── Sticky DOCX edit toolbar (above scroll area)
                        if (_isEditing &&
                            _editingDocxDocument != null &&
                            isDocxDocument &&
                            _activeDocxController != null)
                          buildDocxEditToolbar(
                            controller: _activeDocxController!,
                            theme: theme,
                          ),
                        if (_isEditing &&
                            _editingDocxDocument != null &&
                            isDocxDocument &&
                            _activeDocxController != null)
                          const Divider(height: 1),
                        // ── Find-in-document bar (Ctrl+F)
                        // Renders in reading mode AND in unified DOCX edit
                        // mode (searches the live Quill document by offset and
                        // navigates via native selection). Suppressed only in
                        // the legacy per-paragraph edit path.
                        if (_showFindBar &&
                            (!_isEditing || _docxUnifiedController != null))
                          _buildFindBar(
                            theme: theme,
                            isPdfDocument: isPdfDocument,
                          ),
                        // Document surface
                        Expanded(
                          child: Listener(
                            onPointerSignal: _handleCtrlScroll,
                            child: isPdfDocument
                              ? textWidget
                              : Stack(
                                  children: [
                                    NotificationListener<ScrollNotification>(
                                      onNotification: (notification) {
                                        if (notification
                                            is UserScrollNotification) {
                                          _userScrolling =
                                              notification.direction !=
                                                  ScrollDirection.idle;
                                        }
                                        if (isDocxDocument && !_isEditing) {
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                            _updateCurrentDocxPage(docxPages);
                                          });
                                        }
                                        return false;
                                      },
                                      child: (isDocxDocument && !_isEditing)
                                          ? ScrollConfiguration(
                                              behavior:
                                                  ScrollConfiguration.of(
                                                    context,
                                                  ).copyWith(
                                                    scrollbars: false,
                                                  ),
                                              child: SingleChildScrollView(
                                                key: _docScrollViewportKey,
                                                controller:
                                                    _contentScrollController,
                                                padding: const EdgeInsets.only(
                                                    bottom: 120),
                                                child: LayoutBuilder(
                                                  builder:
                                                      (context, constraints) =>
                                                          SizedBox(
                                                    width: constraints.maxWidth,
                                                    child: textWidget,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Scrollbar(
                                              controller:
                                                  _contentScrollController,
                                              thumbVisibility: isDocxDocument
                                                  ? true
                                                  : null,
                                              interactive: true,
                                              child: SingleChildScrollView(
                                                key: _docScrollViewportKey,
                                                controller:
                                                    _contentScrollController,
                                                padding: const EdgeInsets.only(
                                                    bottom: 120),
                                                child: LayoutBuilder(
                                                  builder:
                                                      (context, constraints) =>
                                                          SizedBox(
                                                    width: constraints.maxWidth,
                                                    child: textWidget,
                                                  ),
                                                ),
                                              ),
                                            ),
                                    ),
                                    if (isDocxDocument &&
                                        !_isEditing &&
                                        docxPages.isNotEmpty)
                                      Positioned(
                                        right: 12,
                                        top: 16,
                                        bottom: 120,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: _DocxPageNumberThumb(
                                            pageNumber: _currentDocxPageNumber
                                                .clamp(1, docxPages.length),
                                            totalPages: docxPages.length,
                                            progress: _docxThumbProgress,
                                            onTapDown: (details) {
                                              _moveDocxThumbToPosition(
                                                pages: docxPages,
                                                globalPosition:
                                                    details.globalPosition,
                                                animate: true,
                                              );
                                            },
                                            onPanStart: (details) {
                                              _moveDocxThumbToPosition(
                                                pages: docxPages,
                                                globalPosition:
                                                    details.globalPosition,
                                                animate: false,
                                              );
                                            },
                                            onPanUpdate: (details) {
                                              _moveDocxThumbToPosition(
                                                pages: docxPages,
                                                globalPosition:
                                                    details.globalPosition,
                                                animate: false,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (isSynthesizing)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: theme.colorScheme.primaryContainer,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Synthesizing audio\u2026',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );

    // KeyboardListener wraps the entire Player body so that key events
    // bubbling up through any descendant's focus chain reach the find
    // handler. A global HardwareKeyboard handler registered in
    // initState() acts as a fallback for descendants (e.g. the PDFium
    // PlatformView) that don't route their key events through Flutter's
    // focus tree.
    return KeyboardListener(
      focusNode: _findShortcutFocusNode,
      includeSemantics: false,
      onKeyEvent: _handleKeyboardListener,
      child: body,
    );
  }

  String _truncate(String text, int maxLen) {
    final clean = text.replaceAll('\n', ' ').trim();
    if (clean.length <= maxLen) return clean;
    return '${clean.substring(0, maxLen)}\u2026';
  }
}

/// Entry in the document outline sidebar.
class _OutlineEntry {
  const _OutlineEntry({
    required this.blockId,
    required this.title,
    required this.level,
  });

  final String blockId;
  final String title;
  final int level;
}

class _DocxPageNumberThumb extends StatelessWidget {
  const _DocxPageNumberThumb({
    required this.pageNumber,
    required this.totalPages,
    required this.progress,
    this.onTapDown,
    this.onPanStart,
    this.onPanUpdate,
  });

  final int pageNumber;
  final int totalPages;
  final double progress;
  final GestureTapDownCallback? onTapDown;
  final GestureDragStartCallback? onPanStart;
  final GestureDragUpdateCallback? onPanUpdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const thumbWidth = 46.0;
    const thumbHeight = 28.0;

    return SizedBox(
      width: thumbWidth,
      child: Tooltip(
        message: 'Drag to navigate pages',
        preferBelow: false,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: onTapDown,
          onVerticalDragStart: onPanStart,
          onVerticalDragUpdate: onPanUpdate,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final trackHeight = constraints.maxHeight.clamp(
                thumbHeight,
                double.infinity,
              );
              final pageProgress = progress.clamp(0.0, 1.0);
              final thumbTop = (trackHeight - thumbHeight) * pageProgress;

              return Stack(
                children: [
                  Positioned(
                    top: thumbTop,
                    left: 0,
                    right: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: thumbWidth,
                        height: thumbHeight,
                        child: Center(
                          child: Text(
                            '$pageNumber',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
