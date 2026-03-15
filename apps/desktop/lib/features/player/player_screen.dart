import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/state/now_reading.dart';
import '../../core/utils/text_sanitizer.dart';
import '../../data/models/document.dart';
import '../../data/providers/providers.dart';
import '../../data/services/audio_service.dart';
import '../../data/services/preferences_service.dart';
import '../../widgets/document_cover.dart';
import '../editor/chunk_editor_provider.dart';
import '../shell/widgets/player_bar.dart';
import 'widgets/chunk_navigator.dart';
import 'widgets/inline_chunk_editor.dart';
import 'widgets/word_highlight_view.dart';

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

  // Captured early so dispose() can use them without ref.read()
  AudioService? _audioService;
  StateController<String>? _nowReadingController;

  final ScrollController _contentScrollController = ScrollController();
  bool _userScrolling = false;

  // ── Inline editing state ─────────────────────────────────────────
  bool _autoEditPending = true; // checked once on first data load
  bool _isEditing = false;
  String _editingChunkId = '';
  String _originalText = '';
  bool _hasUnsavedChanges = false;
  final TextEditingController _editController = TextEditingController();
  final FocusNode _editFocusNode = FocusNode();

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

    _chunkIndexSub = ref.listenManual<int>(currentChunkIndexProvider, (prev, next) {
      if (prev != next) {
        debugPrint('[PlayerScreen] currentChunkIndexProvider: $prev -> $next');
      }
    });

    _voiceSub = ref.listenManual<String>(selectedVoiceIdProvider, (previous, next) {
      if (previous != null && previous != next) {
        // Voice-change replay handled via PlayerBar / AudioService.
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
    final changed = sanitizeForTts(_editController.text) !=
        sanitizeForTts(_originalText);
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

  void _exitEditMode() {
    ref.read(isInlineEditingProvider.notifier).state = false;
    setState(() {
      _isEditing = false;
      _editingChunkId = '';
      _originalText = '';
      _hasUnsavedChanges = false;
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
          var autoTitle = plainText
              .replaceAll('\n', ' ')
              .trim();
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
      await _saveInlineEdit(_editingChunkId);
      return true;
    } else if (result == 'discard') {
      _discardInlineEdit();
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
    String name = selectedId.length >= 8 ? selectedId.substring(0, 8) : selectedId;
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

  void _publishNowReading({
    required String chunkTitle,
    required String chunkText,
    required int currentIndex,
    required int total,
  }) {
    final excerpt = _truncate(chunkText, 140);
    final line = '$chunkTitle \u2022 ${currentIndex + 1}/$total \u2022 $excerpt';
    ref.read(nowReadingTextProvider.notifier).state = line;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chunksAsync = ref.watch(chunksProvider(widget.documentId));
    final activeChunkIndex = ref.watch(currentChunkIndexProvider);
    final isSynthesizing = ref.watch(isSynthesizingProvider).valueOrNull ?? false;
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
        _scrollFromPosition(position, duration);
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
              onPressed: () => ref.invalidate(chunksProvider(widget.documentId)),
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
                Icon(Icons.article_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No content available', style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final chunkIds = chunks
              .map<String>((c) => ((c as Map<String, dynamic>)['id'] ?? '').toString())
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
        final chunkTitle = (activeChunk['title'] ?? 'Section ${currentIndex + 1}').toString();
        final chunkText = (activeChunk['text_content'] ?? '').toString();

        // If we switched chunks while editing, exit edit mode
        if (_isEditing && _editingChunkId != chunkId) {
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

        // Watching this kicks off the alignment fetch automatically.
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

        // ── Build text content area ──────────────────────────────────
        Widget textWidget;
        if (_isEditing && _editingChunkId == chunkId) {
          // Edit mode: show inline editor
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
        } else if (hasAlignment && swhEnabled) {
          textWidget = WordHighlightView(
            key: ValueKey('${chunkId}_$voiceId'),
            chunkText: chunkText,
            alignmentPayload: alignmentPayload,
            onActiveWordChanged: _onActiveWordChanged,
            enableContextMenu: true,
            audioService: _audioService,
          );
        } else {
          textWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isFetchingAlignment)
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
              WordHighlightView(
                key: ValueKey('${chunkId}_${voiceId}_plain'),
                chunkText: chunkText,
                alignmentPayload: const {},
                onActiveWordChanged: _onActiveWordChanged,
                enableContextMenu: true,
                audioService: _audioService,
              ),
            ],
          );
        }

        final chunkMaps = chunks.map<Map<String, String>>((c) {
          final m = c as Map<String, dynamic>;
          return {
            'title': (m['title'] ?? 'Section ${(m['sequence_index'] ?? 0) + 1}').toString(),
            'preview': _truncate((m['text_content'] ?? '').toString(), 80),
          };
        }).toList();

        // Resolve document model for cover data
        final activeDoc = _resolveDocument(ref);

        return Stack(
          children: [
            Row(
              children: [
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
                                'Chapters',
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
                                      style: theme.textTheme.bodySmall?.copyWith(
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
                        Expanded(
                          child: ChunkNavigator(
                            chunks: chunkMaps,
                            activeIndex: currentIndex,
                            onChunkSelected: (index) async {
                              if (_hasUnsavedChanges) {
                                final proceed = await _guardUnsavedChanges();
                                if (!proceed || !mounted) return;
                              } else if (_isEditing) {
                                _exitEditMode();
                              }
                              final audioService = ref.read(audioServiceProvider);
                              unawaited(audioService.reset());
                              ref.read(currentChunkIndexProvider.notifier).state = index;
                              audioService.updateTrackingChunk(index);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                chunkTitle,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            // Pencil / X toggle button
                            IconButton(
                              icon: Icon(
                                _isEditing ? Icons.close : Icons.edit_outlined,
                                size: 18,
                                color: _isEditing
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              tooltip: _isEditing
                                  ? 'Cancel editing'
                                  : 'Edit this chunk',
                              onPressed: () async {
                                if (_isEditing) {
                                  if (_hasUnsavedChanges) {
                                    final proceed = await _guardUnsavedChanges();
                                    if (!proceed) return;
                                  } else {
                                    _exitEditMode();
                                  }
                                } else {
                                  _enterEditMode(chunkId, chunkText);
                                }
                              },
                            ),
                            if (activeChunk['is_edited'] == true && !_isEditing)
                              IconButton(
                                icon: Icon(Icons.refresh_outlined,
                                    size: 18,
                                    color: theme.colorScheme.tertiary),
                                tooltip: 'Re-synthesize voice for this chunk',
                                onPressed: () {
                                  final audioService =
                                      ref.read(audioServiceProvider);
                                  audioService.invalidateChunkCache(chunkId);
                                  ref.invalidate(chunkAlignmentProvider(
                                    AlignmentKey(
                                      documentId: widget.documentId,
                                      chunkId: chunkId,
                                      voiceId: voiceId,
                                    ),
                                  ));
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Chunk ${currentIndex + 1} of ${chunks.length}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (_isEditing) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.edit,
                                size: 12,
                                color: theme.colorScheme.primary.withOpacity(0.7),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Editing',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary.withOpacity(0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ] else if (hasAlignment) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.auto_awesome,
                                size: 12,
                                color: theme.colorScheme.primary.withOpacity(0.7),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Word sync',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary.withOpacity(0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: _isEditing
                              ? textWidget
                              : NotificationListener<ScrollNotification>(
                                  onNotification: (notification) {
                                    if (notification is UserScrollNotification) {
                                      _userScrolling =
                                          notification.direction != ScrollDirection.idle;
                                    }
                                    return false;
                                  },
                                  child: SingleChildScrollView(
                                    controller: _contentScrollController,
                                    padding: const EdgeInsets.only(bottom: 120),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) => SizedBox(
                                        width: constraints.maxWidth,
                                        child: textWidget,
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
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
