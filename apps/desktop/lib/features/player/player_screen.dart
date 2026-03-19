import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'widgets/docx_document_viewport.dart';
import 'widgets/document_reading_view.dart';
import 'widgets/inline_chunk_editor.dart';
import 'widgets/pdf_document_viewport.dart';
import 'widgets/pdf_player_navigator.dart';
import 'widgets/word_highlight_view.dart';
import '../../data/models/document_assembler.dart';
import '../../data/models/psitta_document.dart';

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
  final GlobalKey _docScrollViewportKey = GlobalKey();
  bool _isDocxMarkerMode = false;
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

  // ── Inline editing state ─────────────────────────────────────────
  bool _autoEditPending = true; // checked once on first data load
  bool _isEditing = false;
  String _editingChunkId = '';
  String _originalText = '';
  bool _hasUnsavedChanges = false;
  final TextEditingController _editController = TextEditingController();
  final FocusNode _editFocusNode = FocusNode();
  final Map<String, TextEditingController> _docxBlockControllers = {};
  final Map<String, String> _docxOriginalBlockTexts = {};
  final Map<String, String> _docxOriginalChunkTexts = {};
  final Map<String, String> _docxBlockChunkIds = {};
  PsittaDocument? _editingDocxDocument;

  @override
  void initState() {
    super.initState();
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
    } catch (e) {
      debugPrint('[PlayerScreen] Session init failed: $e');
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
    _editController.removeListener(_onEditTextChanged);
    _editController.dispose();
    _editFocusNode.dispose();
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
      _isDocxMarkerMode = false;
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

  void _enterDocxEditMode(
    PsittaDocument document,
    List<dynamic> rawChunks,
  ) {
    final audioService = ref.read(audioServiceProvider);
    audioService.pause();
    ref.read(isInlineEditingProvider.notifier).state = true;

    for (final controller in _docxBlockControllers.values) {
      controller.dispose();
    }
    _docxBlockControllers.clear();
    _docxOriginalBlockTexts.clear();
    _docxOriginalChunkTexts.clear();
    _docxBlockChunkIds.clear();

    for (final block in document.blocks) {
      final text = block.plainText;
      _docxOriginalBlockTexts[block.blockId] = text;
      _docxBlockControllers[block.blockId] = TextEditingController(text: text);
      final chunk = document.chunkForOffset(block.textOffset);
      if (chunk != null) {
        _docxBlockChunkIds[block.blockId] = chunk.chunkId;
      }
    }

    for (final rawChunk in rawChunks) {
      final chunk = rawChunk as Map<String, dynamic>;
      final chunkId = (chunk['id'] ?? '').toString();
      _docxOriginalChunkTexts[chunkId] =
          (chunk['text_content'] ?? '').toString();
    }

    setState(() {
      _isDocxMarkerMode = false;
      _isEditing = true;
      _editingChunkId = '';
      _originalText = '';
      _hasUnsavedChanges = false;
      _editingDocxDocument = document;
    });
  }

  void _exitEditMode() {
    ref.read(isInlineEditingProvider.notifier).state = false;
    for (final controller in _docxBlockControllers.values) {
      controller.dispose();
    }
    _docxBlockControllers.clear();
    _docxOriginalBlockTexts.clear();
    _docxOriginalChunkTexts.clear();
    _docxBlockChunkIds.clear();
    setState(() {
      _isEditing = false;
      _editingChunkId = '';
      _originalText = '';
      _hasUnsavedChanges = false;
      _editingDocxDocument = null;
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
      final text = sanitizeForTts(controller?.text ?? block.plainText);
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

  Future<bool> _saveDocxEdit(PsittaDocument document) async {
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
    final changedChunkTexts = <String, String>{};
    for (final entry in nextChunkTexts.entries) {
      final previous = _docxOriginalChunkTexts[entry.key] ?? '';
      if (sanitizeForTts(entry.value) != sanitizeForTts(previous)) {
        changedChunkTexts[entry.key] = sanitizeForTts(entry.value);
      }
    }

    if (changedChunkTexts.isEmpty) {
      _exitEditMode();
      return true;
    }

    final notifier = ref.read(chunkEditorProvider.notifier);
    final success = await notifier.saveChunkTexts(
      documentId: widget.documentId,
      chunkTexts: changedChunkTexts,
    );

    if (!success || !mounted) return false;

    for (final entry in _docxBlockControllers.entries) {
      _docxOriginalBlockTexts[entry.key] = sanitizeForTts(entry.value.text);
    }
    _docxOriginalChunkTexts.addAll(changedChunkTexts);
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

    final refreshedData = await ref.refresh(chunksProvider(widget.documentId).future);
    final refreshedChunks = (refreshedData['chunks'] as List<dynamic>?) ?? [];
    final refreshedTexts = <String, String>{
      for (final rawChunk in refreshedChunks)
        ((rawChunk as Map<String, dynamic>)['id'] ?? '').toString():
            sanitizeForTts((rawChunk['text_content'] ?? '').toString()),
    };
    final persisted = changedChunkTexts.entries.every(
      (entry) => refreshedTexts[entry.key] == sanitizeForTts(entry.value),
    );
    if (!persisted) {
      if (mounted) {
        setState(() {
          _hasUnsavedChanges = true;
        });
      }
      return false;
    }
    ref.invalidate(documentsProvider);
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
    if (_userScrolling || _isEditing) return;
    _scrollBlockIntoReadingBand(sentenceKey);
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

    final alignedCharOffset = _charIndexAtMsFromAlignmentPayload(
      alignmentPayload,
      position.inMilliseconds,
    );
    if (alignedCharOffset != null) {
      return _pdfSentenceIndexForCharOffset(text, boundaries, alignedCharOffset);
    }

    if (duration.inMilliseconds <= 0) return 0;
    final ratio =
        (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 0.999999);
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

    return PdfReadingHighlight(
      pageNumber: pageNumber,
      chunkIndex: currentIndex,
      sentenceIndex: safeSentenceIndex,
    );
  }

  Future<void> _jumpToPdfLocation({
    required List<dynamic> chunks,
    required int pageNumber,
    double? pageTopRatio,
    int? targetChunkIndex,
    int? targetSentenceIndex,
    bool autoPlay = true,
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
    if (wasPlaying && autoPlay) {
      await audioService.play();
    }
  }

  Future<void> _jumpToDocumentOffset({
    required PsittaDocument document,
    required int docOffset,
    String? preferredBlockId,
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

    if (wasPlaying) {
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
      ).catchError((_) {}),
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

    return chunksAsync.when(
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

        // Auto-enter edit mode when ?edit=1 is passed (e.g. from New Sheet)
        final editParam = uri.queryParameters['edit']?.trim();
        if (_autoEditPending && editParam == '1' && !_isEditing) {
          _autoEditPending = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _enterEditMode(chunkId, chunkText);
          });
        } else if (_autoEditPending) {
          _autoEditPending = false;
        }

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
              );

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
        Widget textWidget;
        if (isPdfDocument) {
          textWidget = PdfDocumentViewport(
            key: ValueKey('pdf_${widget.documentId}'),
            documentId: widget.documentId,
            chunks: chunks,
            controller: _pdfViewerController,
            highlight: pdfHighlight,
            onDocumentLoaded: (documentRef, outline) {
              if (!mounted) return;
              final activePdfPageNumber =
                  (activeChunk['page_number'] as num?)?.toInt() ?? 1;
              setState(() {
                _pdfDocumentRef = documentRef;
                _pdfOutline = outline;
                _lastAutoFollowedPdfPage = activePdfPageNumber;
              });
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
                autoPlay: false,
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
          textWidget = DocxDocumentViewport(
            key: ValueKey('docx_${widget.documentId}_$voiceId'),
            document: psittaDoc,
            activeChunkIndex: currentIndex,
            alignmentPayload: alignmentPayload ?? const {},
            focusedSentenceIndex:
                _hasPendingDocxJump ? _focusedDocxSentenceIndex : null,
            isFetchingAlignment: isFetchingAlignment,
            editorChild: _isEditing && _editingDocxDocument != null
                ? DocxDocumentEditor(
                    key: ValueKey('docx_edit_${widget.documentId}'),
                    document: _editingDocxDocument!,
                    controllers: _docxBlockControllers,
                    isSaving: editorState.isSaving,
                    error: editorState.error,
                    onChanged: () {
                      var changed = false;
                      for (final entry in _docxBlockControllers.entries) {
                        final original =
                            _docxOriginalBlockTexts[entry.key] ?? '';
                        if (sanitizeForTts(entry.value.text) !=
                            sanitizeForTts(original)) {
                          changed = true;
                          break;
                        }
                      }
                      if (changed != _hasUnsavedChanges && mounted) {
                        setState(() {
                          _hasUnsavedChanges = changed;
                        });
                      }
                    },
                  )
                : null,
            onActiveSentenceChanged: _scrollFromSentence,
            onActiveWordChanged: _onActiveWordChanged,
            onMarkerTap: (docOffset) => _jumpToDocumentOffset(
              document: psittaDoc,
              docOffset: docOffset,
            ),
            audioService: _audioService,
            markerModeEnabled: !_isEditing && _isDocxMarkerMode,
            blockKeys: _docBlockKeys,
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
        for (final block in psittaDoc.blocks) {
          if (block.type == DocBlockType.heading) {
            outlineEntries.add(_OutlineEntry(
              blockId: block.blockId,
              title: block.plainText,
              level: block.level ?? 1,
            ));
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
                                isPdfDocument ? 'Navigator' : 'Outline',
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
                              Tooltip(
                                preferBelow: false,
                                verticalOffset: 20,
                                message: _isDocxMarkerMode
                                    ? 'Marker jump is on. Click document text while voice is reading to jump narration.'
                                    : 'Marker jump tool. Turn this on, then click document text while voice is reading to jump narration.',
                                child: IconButton.filledTonal(
                                  icon: Icon(
                                    _isDocxMarkerMode
                                        ? Icons.close
                                        : Icons.highlight_alt,
                                    size: 18,
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: _isDocxMarkerMode
                                        ? (theme.brightness == Brightness.dark
                                            ? const Color(0xFF58651F)
                                            : const Color(0xFFEAF68B))
                                        : (theme.brightness == Brightness.dark
                                            ? theme.colorScheme
                                                .surfaceContainerHigh
                                            : const Color(0xFFF7F7D8)),
                                    foregroundColor: _isDocxMarkerMode
                                        ? (theme.brightness == Brightness.dark
                                            ? const Color(0xFFF6F8E2)
                                            : const Color(0xFF4A5B17))
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isDocxMarkerMode = !_isDocxMarkerMode;
                                    });
                                  },
                                ),
                              ),
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
                            if (!isPdfDocument && hasAlignment) ...[
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
                        // Document surface
                        Expanded(
                          child: isPdfDocument
                              ? textWidget
                              : NotificationListener<ScrollNotification>(
                                  onNotification: (notification) {
                                    if (notification
                                        is UserScrollNotification) {
                                      _userScrolling = notification.direction !=
                                          ScrollDirection.idle;
                                    }
                                    return false;
                                  },
                                  child: Scrollbar(
                                    controller: _contentScrollController,
                                    thumbVisibility: isDocxDocument
                                        ? (_isEditing || _isDocxMarkerMode)
                                        : null,
                                    interactive: true,
                                    child: SingleChildScrollView(
                                      key: _docScrollViewportKey,
                                      controller: _contentScrollController,
                                      padding:
                                          const EdgeInsets.only(bottom: 120),
                                      child: LayoutBuilder(
                                        builder: (context, constraints) =>
                                            SizedBox(
                                          width: constraints.maxWidth,
                                          child: textWidget,
                                        ),
                                      ),
                                    ),
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
