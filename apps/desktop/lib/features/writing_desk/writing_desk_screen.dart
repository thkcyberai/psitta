import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/psitta_tokens.dart';
import '../../data/providers/providers.dart';
import 'desk_center_pane.dart';
import 'document_context_pane.dart';
import 'project_navigator_pane.dart';

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
  });

  final String documentId;
  final String? projectId;

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
                  tooltip: collapsed ? 'Show panel' : 'Hide panel',
                  icon: Icon(
                    collapsed ? Icons.chevron_left : Icons.chevron_right,
                    color: scheme.outline,
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

