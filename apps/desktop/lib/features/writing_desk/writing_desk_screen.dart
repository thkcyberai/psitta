import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/psitta_tokens.dart';
import '../../data/providers/providers.dart';
import '../../data/services/audio_service.dart' show audioServiceProvider;
import '../shell/widgets/player_bar.dart'
    show
        activeChunkIdsProvider,
        activeDocumentIdProvider,
        currentChunkIndexProvider,
        currentDocTitleProvider,
        streamingPlaybackProvider,
        totalChunksProvider;
import 'desk_center_pane.dart';
import 'document_context_pane.dart';
import 'project_navigator_pane.dart';
import '../../l10n/app_localizations.dart';

/// Three-column Writing Desk surface.
///
/// Navigator (~260 px, resizable) | Center (expanded) | Context (~280 px, resizable)
///
/// WD-1: placeholder panes only. WD-2 fills the navigator, WD-3 the center,
/// WD-4/5/6 the context panels.
class WritingDeskScreen extends ConsumerStatefulWidget {
  const WritingDeskScreen({
    super.key,
    required this.documentId,
    this.projectId,
    this.initialRead = false,
  });

  final String documentId;
  final String? projectId;

  /// Open straight into Read/Listen mode (Library "Read" action).
  final bool initialRead;

  @override
  ConsumerState<WritingDeskScreen> createState() => _WritingDeskScreenState();
}

class _WritingDeskScreenState extends ConsumerState<WritingDeskScreen> {
  static const double _kNavigatorMin = 160;
  static const double _kNavigatorMax = 400;
  static const double _kContextMin = 180;
  static const double _kContextMax = 420;

  double _navigatorWidth = 260;
  double _contextWidth = 280;
  bool _contextCollapsed = false;

  // Which document the bottom player bar has been reset for. Set the instant
  // the open document changes so stale audio is cleared before populating.
  String? _wiredDocId;

  // Captured when `ref` is valid so dispose() can reset it without touching
  // `ref` (which throws "Cannot use ref after the widget was disposed").
  StateController<bool>? _streamingNotifier;

  @override
  void initState() {
    super.initState();
    // Route the bottom player bar through the streaming endpoint while the
    // Writing Desk is the active surface (fast first play). Reset on dispose so
    // the Reading Nook / Player keeps the batch path.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(streamingPlaybackProvider.notifier).state = true;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _streamingNotifier = ref.read(streamingPlaybackProvider.notifier);
  }

  @override
  void dispose() {
    // Defer the reset off the teardown frame: mutating a provider during
    // dispose() notifies listeners while the widget tree is finalizing,
    // which Riverpod forbids. The captured notifier survives the deferral.
    final streamingNotifier = _streamingNotifier;
    Future.microtask(() {
      try {
        streamingNotifier?.state = false;
      } catch (_) {
        // Provider already disposed — nothing to reset.
      }
    });
    super.dispose();
  }

  String? _docTitle() => ref
      .read(documentsProvider)
      .valueOrNull
      ?.where((d) => d.id == widget.documentId)
      .firstOrNull
      ?.title;

  // The open document changed: clear the previous file's prepared audio so the
  // next Play synthesizes the NEW file instead of resuming the old one from the
  // audio cache. Also resets the player-bar providers to the new document.
  void _resetPlaybackForNewDoc() {
    if (!mounted) return;
    ref.read(audioServiceProvider).reset();
    ref.read(activeDocumentIdProvider.notifier).state = widget.documentId;
    ref.read(currentChunkIndexProvider.notifier).state = 0;
    ref.read(activeChunkIdsProvider.notifier).state = const <String>[];
    ref.read(totalChunksProvider.notifier).state = 0;
    final title = _docTitle();
    if (title != null && title.isNotEmpty) {
      ref.read(currentDocTitleProvider.notifier).state = title;
    }
  }

  // Populate the player-bar chunk ids once the NEW document's chunks load.
  // Guarded so a chunk read that resolves after the user already switched
  // documents can't repopulate the wrong file.
  void _populateChunks(List<String> chunkIds) {
    if (!mounted) return;
    if (ref.read(activeDocumentIdProvider) != widget.documentId) return;
    if (!listEquals(ref.read(activeChunkIdsProvider), chunkIds)) {
      ref.read(activeChunkIdsProvider.notifier).state = chunkIds;
      ref.read(totalChunksProvider.notifier).state = chunkIds.length;
    }
    final title = _docTitle();
    if (title != null &&
        title.isNotEmpty &&
        ref.read(currentDocTitleProvider) != title) {
      ref.read(currentDocTitleProvider.notifier).state = title;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final docProjectId = ref
        .watch(documentsProvider)
        .valueOrNull
        ?.where((d) => d.id == widget.documentId)
        .firstOrNull
        ?.projectId;
    final effectiveProjectId = widget.projectId ?? docProjectId;

    // The instant the open document changes, reset playback so a stale prepared
    // chunk from the previous file can't be resumed by Play. This runs before
    // chunks load, closing the window where the old file could still play.
    if (_wiredDocId != widget.documentId) {
      _wiredDocId = widget.documentId;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _resetPlaybackForNewDoc());
    }

    // Populate the player bar's chunk ids once this document's chunks load.
    ref.watch(chunksProvider(widget.documentId)).whenData((data) {
      final chunks = (data['chunks'] as List<dynamic>?) ?? const [];
      final chunkIds = chunks
          .map<String>(
              (c) => ((c as Map<String, dynamic>)['id'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList();
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _populateChunks(chunkIds));
    });
    return ColoredBox(
      color: tokens.surface,
      child: Row(
        children: [
          // ── Navigator pane ───────────────────────────────────────────────
          SizedBox(
            key: const ValueKey('desk-navigator-pane'),
            width: _navigatorWidth,
            child: ProjectNavigatorPane(
              documentId: widget.documentId,
              projectId: effectiveProjectId,
            ),
          ),
          // ── Resize handle: navigator ↔ center ───────────────────────────
          _ResizeHandle(
            key: const ValueKey('desk-handle-left'),
            onDrag: (dx) => setState(() {
              _navigatorWidth = (_navigatorWidth + dx)
                  .clamp(_kNavigatorMin, _kNavigatorMax);
            }),
            tokens: tokens,
          ),
          // ── Center pane (expanded) ───────────────────────────────────────
          Expanded(
            child: DeskCenterPane(
              key: const ValueKey('desk-center-pane'),
              documentId: widget.documentId,
              projectId: effectiveProjectId,
              initialRead: widget.initialRead,
            ),
          ),
          // ── Resize handle: center ↔ context (drag) ──────────────────────
          if (!_contextCollapsed)
            _ResizeHandle(
              key: const ValueKey('desk-handle-right'),
              onDrag: (dx) => setState(() {
                _contextWidth = (_contextWidth - dx)
                    .clamp(_kContextMin, _kContextMax);
              }),
              tokens: tokens,
            ),
          // ── Collapse / expand toggle rail ───────────────────────────────
          _ContextToggleRail(
            collapsed: _contextCollapsed,
            tokens: tokens,
            onToggle: () =>
                setState(() => _contextCollapsed = !_contextCollapsed),
          ),
          // ── Context pane (hidden when collapsed) ─────────────────────────
          if (!_contextCollapsed)
            SizedBox(
              key: const ValueKey('desk-context-pane'),
              width: _contextWidth,
              child: DocumentContextPane(
                documentId: widget.documentId,
                projectId: effectiveProjectId,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Resize handle ─────────────────────────────────────────────────────────────

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({
    super.key,
    required this.onDrag,
    required this.tokens,
  });

  final void Function(double dx) onDrag;
  final PsittaTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 4,
          color: tokens.divider,
        ),
      ),
    );
  }
}

// ── Context collapse / expand toggle rail ─────────────────────────────────────

class _ContextToggleRail extends StatelessWidget {
  const _ContextToggleRail({
    required this.collapsed,
    required this.onToggle,
    required this.tokens,
  });

  final bool collapsed;
  final VoidCallback onToggle;
  final PsittaTokens tokens;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return Row(
      children: [
        VerticalDivider(width: 1, color: tokens.divider),
        SizedBox(
          width: 22,
          child: ColoredBox(
            color: tokens.surface2,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: IconButton(
                  key: const ValueKey('desk-context-toggle'),
                  iconSize: 16,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 22,
                    height: 28,
                  ),
                  tooltip: collapsed ? loc.showPanel : loc.hidePanel,
                  icon: Icon(
                    collapsed ? Icons.chevron_left : Icons.chevron_right,
                    color: scheme.onSurfaceVariant,
                  ),
                  onPressed: onToggle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Placeholder panes (WD-5/6 will replace the next placeholder) ─────────────

