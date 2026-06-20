import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/psitta_tokens.dart';
import '../../data/providers/blueprint_providers.dart';
import 'blueprint_screen_state.dart';
import 'narrative_structures.dart';

/// Index of the selected narrative structure within [kNarrativeStructures].
final selectedStructureIndexProvider = StateProvider<int>((ref) => 0);

/// The "Narrative Structure" tab — a list of structures, a detail view of the
/// selected one's components, and an info panel. "Use this Structure" generates
/// a real blueprint with each component as a section, then jumps to the
/// My Blueprints tab with it selected.
class NarrativeStructureTab extends ConsumerWidget {
  const NarrativeStructureTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);
    final raw = ref.watch(selectedStructureIndexProvider);
    final index = raw.clamp(0, kNarrativeStructures.length - 1);
    final structure = kNarrativeStructures[index];

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 300, child: _StructureList(selectedIndex: index)),
              VerticalDivider(width: 1, color: tokens.divider),
              Expanded(child: _StructureDetail(structure: structure)),
              VerticalDivider(width: 1, color: tokens.divider),
              SizedBox(width: 300, child: _StructureInfo(structure: structure)),
            ],
          ),
        ),
        Divider(height: 1, color: tokens.divider),
        const _BottomTools(),
      ],
    );
  }
}

// ── Bottom: analysis tools (Layer 3 — shown as coming soon) ──────────────────

class _BottomTools extends StatelessWidget {
  const _BottomTools();

  @override
  Widget build(BuildContext context) {
    const tools = [
      (Icons.menu_book_outlined, 'Interactive Guide',
          'Learn each step with examples and tips.'),
      (Icons.insights_outlined, 'Structure Analyzer',
          'Analyze your manuscript against this structure.'),
      (Icons.hub_outlined, 'Scene Mapper',
          'Map your chapters to the structure.'),
      (Icons.track_changes_outlined, 'Progress Tracker',
          'Track your progress through the journey.'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          for (final t in tools) ...[
            Expanded(child: _ToolCard(icon: t.$1, title: t.$2, subtitle: t.$3)),
            if (t != tools.last) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: tokens.glow),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11, height: 1.3, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: tokens.glow.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Coming soon',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: tokens.glow)),
          ),
        ],
      ),
    );
  }
}

// ── The circle: steps as numbered nodes around a ring, colored by act ────────

/// Per-act node/arc colors (cycled when a structure has more than five acts).
const List<Color> _kActColors = [
  Color(0xFF8A7CFF), // purple
  Color(0xFF4FB0E5), // blue
  Color(0xFF54C68A), // green
  Color(0xFFE0A24E), // amber
  Color(0xFFE5709B), // pink
];

/// A self-sizing circular story map: every step is a numbered node on the ring,
/// with its label placed radially just outside the node. Labels are measured
/// up-front so they share one font that fits all of them in ≤2 lines, and the
/// ring radius is computed only after reserving a label gutter on every side —
/// so nothing is ever clipped by the container or overlaps the ring.
class _StructureCircle extends StatelessWidget {
  const _StructureCircle({
    required this.structure,
    required this.selected,
    required this.onToggle,
  });

  final NarrativeStructure structure;
  final Set<int> selected;
  final void Function(int) onToggle;

  /// Largest font (≤ [base], ≥ [floor]) at which EVERY label fits within
  /// [boxWidth] in at most [maxLines] lines. One shared size keeps the ring
  /// visually even and guarantees no label is truncated.
  static double _uniformLabelFont(
    List<String> labels,
    double boxWidth,
    double base,
    double floor,
    int maxLines,
  ) {
    var best = base;
    for (final label in labels) {
      var f = base;
      while (f > floor) {
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(fontSize: f, fontWeight: FontWeight.w600),
          ),
          maxLines: maxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: boxWidth);
        if (!tp.didExceedMaxLines) break;
        f -= 0.5;
      }
      if (f < best) best = f;
    }
    return best.clamp(floor, base).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final steps = structure.components;
    final n = steps.length;

    // Phase index for each flat step (drives its node/label/arc color).
    final phaseOf = <int>[];
    for (var p = 0; p < structure.phases.length; p++) {
      for (var k = 0; k < structure.phases[p].steps.length; k++) {
        phaseOf.add(p);
      }
    }

    return LayoutBuilder(
      builder: (context, cns) {
        // Guard against unbounded constraints (Infinity = "render box with no
        // size"); the Stack below needs a definite, finite size.
        final w = cns.maxWidth.isFinite ? cns.maxWidth : 640.0;
        final h = cns.maxHeight.isFinite ? cns.maxHeight : 360.0;

        // Node size and base font ease down as the step count grows.
        final nodeR = n > 14 ? 11.0 : (n > 9 ? 12.5 : 14.0);
        final baseFont = n <= 7
            ? 12.5
            : n <= 11
                ? 11.5
                : n <= 16
                    ? 10.5
                    : 9.5;

        const gap = 8.0; // node edge → label gap
        const margin = 6.0; // keep clear of the container edge

        // Label box width per side, bounded so the ring keeps real estate.
        final labelW = (w * 0.24).clamp(92.0, 152.0).toDouble();

        // One font that fits every label in ≤2 lines inside the box.
        final font = _uniformLabelFont(steps, labelW - 4, baseFont, 8.5, 2);
        final lineH = font * 1.3;
        final labelH = lineH * 2 + 2;

        // Radius = whatever remains after reserving label gutters all round.
        final halfW = w / 2 - labelW - gap - nodeR - margin;
        final halfH = h / 2 - labelH - gap - nodeR - margin;
        final r = math.max(56.0, math.min(halfW, halfH));
        final cx = w / 2;
        final cy = h / 2;

        final children = <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _RingPainter(n: n, phaseOf: phaseOf, radius: r),
            ),
          ),
          // Centre caption.
          Positioned(
            left: cx - 70,
            top: cy - 16,
            width: 140,
            child: IgnorePointer(
              child: Text(
                '${selected.length} of $n\nsteps selected',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ];

        for (var i = 0; i < n; i++) {
          final theta = -math.pi / 2 + (2 * math.pi * i / n);
          final cosT = math.cos(theta);
          final sinT = math.sin(theta);
          final color = _kActColors[phaseOf[i] % _kActColors.length];
          final isSel = selected.contains(i);

          final nx = cx + r * cosT;
          final ny = cy + r * sinT;

          // Node.
          children.add(Positioned(
            left: nx - nodeR,
            top: ny - nodeR,
            child: _tappable(
              () => onToggle(i),
              Container(
                width: nodeR * 2,
                height: nodeR * 2,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSel ? color : scheme.surface,
                  border: Border.all(color: color, width: 2),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                              color: color.withValues(alpha: 0.45),
                              blurRadius: 8)
                        ]
                      : null,
                ),
                child: Text('${i + 1}',
                    style: TextStyle(
                        fontSize: nodeR < 13 ? 10.0 : 11.5,
                        fontWeight: FontWeight.w700,
                        color: isSel ? Colors.white : color)),
              ),
            ),
          ));

          // Label, anchored just outside the node and aligned by its side.
          final ax = cx + (r + nodeR + gap) * cosT;
          final ay = cy + (r + nodeR + gap) * sinT;

          final double left;
          final TextAlign align;
          final Alignment boxAlign;
          if (cosT > 0.30) {
            left = ax;
            align = TextAlign.left;
            boxAlign = Alignment.centerLeft;
          } else if (cosT < -0.30) {
            left = ax - labelW;
            align = TextAlign.right;
            boxAlign = Alignment.centerRight;
          } else {
            left = ax - labelW / 2;
            align = TextAlign.center;
            boxAlign = Alignment.center;
          }
          // Near-vertical (top/bottom) labels are pushed fully clear of the
          // node; side labels are centred on the anchor.
          final double top = cosT.abs() <= 0.30
              ? (sinT < 0 ? ay - labelH : ay)
              : ay - labelH / 2;

          children.add(Positioned(
            left: left,
            top: top,
            width: labelW,
            height: labelH,
            child: _tappable(
              () => onToggle(i),
              Container(
                alignment: boxAlign,
                child: Text(
                  steps[i],
                  maxLines: 2,
                  textAlign: align,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: font,
                    height: 1.2,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                    color:
                        isSel ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ));
        }

        return Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: children,
        );
      },
    );
  }

  Widget _tappable(VoidCallback onTap, Widget child) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: child,
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.n, required this.phaseOf, required this.radius});
  final int n;
  final List<int> phaseOf;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      final a0 = -math.pi / 2 + (2 * math.pi * i / n);
      final sweep = 2 * math.pi / n;
      stroke.color =
          _kActColors[phaseOf[i] % _kActColors.length].withValues(alpha: 0.5);
      canvas.drawArc(rect, a0, sweep, false, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.n != n || old.radius != radius;
}

/// The act header cards (Act I — Departure, etc.), color-coded per act.
class _ActCards extends StatelessWidget {
  const _ActCards({required this.structure});
  final NarrativeStructure structure;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cards = <Widget>[];
    var start = 1;
    for (var p = 0; p < structure.phases.length; p++) {
      final phase = structure.phases[p];
      final color = _kActColors[p % _kActColors.length];
      final end = start + phase.steps.length - 1;
      final range =
          phase.steps.length == 1 ? 'Step $start' : 'Steps $start–$end';
      cards.add(Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Text('${p + 1}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      phase.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: color),
                    ),
                    Text(range,
                        style: TextStyle(
                            fontSize: 10.5, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ));
      if (p < structure.phases.length - 1) {
        cards.add(const SizedBox(width: 10));
      }
      start = end + 1;
    }
    // IntrinsicHeight gives the Row a bounded height so crossAxisAlignment.stretch
    // works (a stretch Row directly in a Column gets unbounded height → the cards
    // become infinitely tall → "render box with no size" → blank pane).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: cards,
      ),
    );
  }
}

// ── Left: structure list ─────────────────────────────────────────────────────

class _StructureList extends ConsumerWidget {
  const _StructureList({required this.selectedIndex});
  final int selectedIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 10, 12),
      child: ListView.builder(
        itemCount: kNarrativeStructures.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
              child: Text(
                'POPULAR STRUCTURES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          final idx = i - 1;
          return _StructureListCard(
            structure: kNarrativeStructures[idx],
            isSelected: idx == selectedIndex,
            onTap: () =>
                ref.read(selectedStructureIndexProvider.notifier).state = idx,
          );
        },
      ),
    );
  }
}

class _StructureListCard extends StatelessWidget {
  const _StructureListCard({
    required this.structure,
    required this.isSelected,
    required this.onTap,
  });

  final NarrativeStructure structure;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isSelected
                  ? tokens.glow.withValues(alpha: 0.10)
                  : tokens.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? tokens.glow : tokens.border,
                width: isSelected ? 1.8 : 1,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  height: 58,
                  child: Image.asset(
                    structure.cover,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: tokens.glow.withValues(alpha: 0.14),
                      alignment: Alignment.center,
                      child: Icon(Icons.auto_stories_outlined,
                          color: tokens.glow, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          structure.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          structure.bestFor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10.5, color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${structure.components.length} sections',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: tokens.glow),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Center: selected structure detail ────────────────────────────────────────

class _StructureDetail extends ConsumerStatefulWidget {
  const _StructureDetail({required this.structure});
  final NarrativeStructure structure;

  @override
  ConsumerState<_StructureDetail> createState() => _StructureDetailState();
}

class _StructureDetailState extends ConsumerState<_StructureDetail> {
  late Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _selectAll();
  }

  @override
  void didUpdateWidget(covariant _StructureDetail old) {
    super.didUpdateWidget(old);
    // Reset the picks when the writer switches to a different structure.
    if (old.structure.name != widget.structure.name) {
      setState(_selectAll);
    }
  }

  void _selectAll() {
    _selected = {
      for (var i = 0; i < widget.structure.components.length; i++) i,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final s = widget.structure;
    final total = s.components.length;
    final count = _selected.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 1),
                    Text(
                      '${s.bestFor}  ·  $count of $total sections selected',
                      style: TextStyle(
                          fontSize: 11.5, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Use this Structure'),
                onPressed: count == 0
                    ? null
                    : () => _generateFromStructure(
                          context,
                          ref,
                          s,
                          [
                            for (var i = 0; i < total; i++)
                              if (_selected.contains(i)) s.components[i],
                          ],
                        ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Pick the sections you want:',
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(_selectAll),
                child: const Text('Select all'),
              ),
              TextButton(
                onPressed: () => setState(() => _selected = {}),
                child: const Text('Clear'),
              ),
            ],
          ),
          if (s.hasActs) ...[
            const SizedBox(height: 8),
            _ActCards(structure: s),
          ],
          const SizedBox(height: 8),
          Divider(height: 1, color: tokens.divider),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _StructureCircle(
                  structure: s, selected: _selected, onToggle: _toggle),
            ),
          ),
        ],
      ),
    );
  }

  void _toggle(int i) => setState(() {
        if (_selected.contains(i)) {
          _selected.remove(i);
        } else {
          _selected.add(i);
        }
      });

}

// ── Right: info panel ────────────────────────────────────────────────────────

class _StructureInfo extends StatelessWidget {
  const _StructureInfo({required this.structure});
  final NarrativeStructure structure;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tags = structure.bestFor.split(',').map((t) => t.trim()).toList();

    return Container(
      color: tokens.surface,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
      child: ListView(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: Image.asset(
                structure.cover,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: tokens.glow.withValues(alpha: 0.14),
                  alignment: Alignment.center,
                  child: Icon(Icons.auto_stories_outlined,
                      color: tokens.glow, size: 28),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(structure.name,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          _label(context, 'BEST FOR'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in tags)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tokens.glow.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(t,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: tokens.glow)),
                ),
            ],
          ),
          const SizedBox(height: 22),
          _label(context, 'INCLUDES'),
          const SizedBox(height: 8),
          _infoRow(scheme, Icons.check_circle_outline,
              '${structure.components.length} sections'),
          const SizedBox(height: 8),
          _infoRow(scheme, Icons.check_circle_outline,
              'Editable in the Writing Desk'),
          const SizedBox(height: 8),
          _infoRow(scheme, Icons.check_circle_outline,
              'Place your documents into each section'),
          const SizedBox(height: 24),
          _label(context, 'COMING SOON'),
          const SizedBox(height: 8),
          Text(
            'Structure analyzer, scene mapper, progress tracking and writing tips.',
            style: TextStyle(
                fontSize: 12, height: 1.4, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );

  Widget _infoRow(ColorScheme scheme, IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      );
}

// ── Generate a blueprint from a structure ────────────────────────────────────

/// Creates a user blueprint from [s], seeding each component as a section, then
/// switches to the My Blueprints tab with the new blueprint selected. Sections
/// are created in reverse with no afterPartId — each becomes the first sibling —
/// so the final order matches the catalog without id chaining.
Future<void> _generateFromStructure(
    BuildContext context,
    WidgetRef ref,
    NarrativeStructure s,
    List<String> components) async {
  final tabController = DefaultTabController.maybeOf(context);

  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Center(
      child: Material(
        color: Theme.of(ctx).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 26, 30, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.6)),
              const SizedBox(height: 16),
              Text('Building your ${s.name}…',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    ),
  ));

  try {
    final actions = ref.read(blueprintActionsProvider);
    final bp = await actions.createBlueprint(name: s.name, genre: s.genre);
    for (final component in components.reversed) {
      await actions.createPart(bp.id, name: component);
    }
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    ref.invalidate(blueprintsListProvider);
    ref.read(selectedBlueprintIdProvider.notifier).state = bp.id;
    ref.read(selectedPartIdProvider.notifier).state = null;
    tabController?.animateTo(0); // jump to My Blueprints
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Created "${s.name}" with ${components.length} sections')),
      );
    }
  } catch (_) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t build the structure.')),
      );
    }
  }
}
