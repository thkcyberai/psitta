import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/psitta_tokens.dart';
import '../../data/providers/project_providers.dart';
import '../../data/providers/providers.dart';
import '../projects/widgets/progress_tracker.dart';
import '../projects/widgets/scene_map_dialog.dart';
import '../projects/widgets/structure_analyzer_dialog.dart';
import 'interactive_guide_dialog.dart';
import 'narrative_structures.dart';
import 'narrative_i18n.dart';
import '../../l10n/app_localizations.dart';

/// Index of the selected narrative structure within [kNarrativeStructures].
final selectedStructureIndexProvider = StateProvider<int>((ref) => 0);

/// Index of the selected audience variant within the current structure's
/// `variants`. Reset to 0 whenever the writer picks a different structure.
final selectedVariantIndexProvider = StateProvider<int>((ref) => 0);

/// The "Narrative Structure" tab — a list of structures on the left, a detail
/// view of the selected one in the centre (Best For selector + interactive
/// circle of steps), and an info panel on the right. "Use this Structure"
/// generates a real blueprint with each picked step as a section, then jumps to
/// the My Blueprints tab with it selected.
class NarrativeStructureTab extends ConsumerWidget {
  const NarrativeStructureTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);
    final sIndex = ref
        .watch(selectedStructureIndexProvider)
        .clamp(0, kNarrativeStructures.length - 1);
    final structure = kNarrativeStructures[sIndex];
    final vIndex = ref
        .watch(selectedVariantIndexProvider)
        .clamp(0, structure.variants.length - 1);

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 300, child: _StructureList(selectedIndex: sIndex)),
              VerticalDivider(width: 1, color: tokens.divider),
              Expanded(
                child: _StructureDetail(
                    structure: structure, variantIndex: vIndex),
              ),
              VerticalDivider(width: 1, color: tokens.divider),
              SizedBox(
                width: 300,
                child:
                    _StructureInfo(structure: structure, variantIndex: vIndex),
              ),
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

class _BottomTools extends ConsumerWidget {
  const _BottomTools();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sIndex = ref
        .watch(selectedStructureIndexProvider)
        .clamp(0, kNarrativeStructures.length - 1);
    final structure = kNarrativeStructures[sIndex];
    final vIndex = ref
        .watch(selectedVariantIndexProvider)
        .clamp(0, structure.variants.length - 1);

    // Interactive Guide is live; the other three remain "Coming soon" (onTap null).
    final loc = AppLocalizations.of(context);
    final tools = <(IconData, String, String, VoidCallback?)>[
      (
        Icons.menu_book_outlined,
        loc.featureInteractiveGuide,
        loc.guideDesc,
        () => showInteractiveGuide(context,
            structure: structure, variantIndex: vIndex),
      ),
      (
        Icons.insights_outlined,
        loc.featureStructureAnalyzer,
        loc.analyzerDesc,
        () => pickProjectAndShowAnalyzer(context, ref),
      ),
      (
        Icons.hub_outlined,
        loc.featureSceneMapper,
        loc.sceneMapperDesc,
        () => pickProjectAndShowSceneMap(context, ref),
      ),
      (
        Icons.track_changes_outlined,
        loc.featureProgressTracker,
        loc.progressDesc,
        () => pickProjectAndShowProgress(context, ref),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        // (bottom tools strip — slightly tighter to give the circle room above)
        children: [
          for (var i = 0; i < tools.length; i++) ...[
            Expanded(
              child: _ToolCard(
                icon: tools[i].$1,
                title: tools[i].$2,
                subtitle: tools[i].$3,
                onTap: tools[i].$4,
              ),
            ),
            if (i < tools.length - 1) const SizedBox(width: 12),
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
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// When non-null the card is live (tappable, shows an "Open" affordance);
  /// when null it shows the "Coming soon" pill.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final active = onTap != null;
    final loc = AppLocalizations.of(context);

    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: active ? tokens.glow.withValues(alpha: 0.5) : tokens.border),
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
          if (active)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(loc.openGuide,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: tokens.glow)),
                const SizedBox(width: 3),
                Icon(Icons.arrow_forward, size: 12, color: tokens.glow),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: tokens.glow.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(loc.comingSoon,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: tokens.glow)),
            ),
        ],
      ),
    );

    if (!active) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: card,
      ),
    );
  }
}

// ── Palette: nodes/arcs cycle through these as a progression around the ring ──

const List<Color> _kStepColors = [
  Color(0xFF8A7CFF), // purple
  Color(0xFF4FB0E5), // blue
  Color(0xFF54C68A), // green
  Color(0xFFE0A24E), // amber
  Color(0xFFE5709B), // pink
];

/// Colour for step [i] of [n], stepping through the palette as a progression
/// (early beats purple → late beats pink), so the ring reads as a journey.
Color _stepColor(int i, int n) {
  if (n <= 1) return _kStepColors.first;
  final idx = (i * _kStepColors.length / n).floor();
  return _kStepColors[idx.clamp(0, _kStepColors.length - 1)];
}

// ── The circle: steps as numbered nodes around a ring ────────────────────────

/// A self-sizing circular story map: every step is a numbered node on the ring,
/// with its label placed radially (diagonally) just outside the node. Labels are
/// measured up-front so they share one font that fits all of them in ≤3 lines,
/// and the ring radius is computed only after reserving a label gutter on every
/// side — so nothing is ever clipped or overlapping the ring.
class _StructureCircle extends StatelessWidget {
  const _StructureCircle({
    required this.components,
    required this.selected,
    required this.onToggle,
  });

  final List<String> components;
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
    final loc = AppLocalizations.of(context);
    final steps = [for (final c in components) beatLabel(context, c)];
    final n = steps.length;

    return LayoutBuilder(
      builder: (context, cns) {
        final w = cns.maxWidth.isFinite ? cns.maxWidth : 640.0;
        final h = cns.maxHeight.isFinite ? cns.maxHeight : 420.0;

        // Node size and base font ease down as the step count grows.
        final nodeR = n > 14 ? 11.0 : (n > 9 ? 12.5 : 14.0);
        final baseFont = n <= 7
            ? 12.5
            : n <= 11
                ? 11.5
                : n <= 16
                    ? 10.5
                    : 9.5;

        const gap = 6.0; // node edge → label gap (labels sit close to nodes)
        const margin = 8.0; // keep clear of the container edge

        // Label box width per side, bounded so the ring keeps real estate.
        final labelW = (w * 0.23).clamp(92.0, 138.0).toDouble();

        // One font that fits every label in ≤3 lines inside the box (3 lines so
        // long beats like "Crossing into space, simulation, or future world"
        // are never truncated).
        final font = _uniformLabelFont(steps, labelW - 4, baseFont, 7.5, 3);
        final lineH = font * 1.25;
        final labelH = lineH * 3 + 2;

        // Radius = whatever remains after reserving label gutters all round.
        final halfW = w / 2 - labelW - gap - nodeR - margin;
        final halfH = h / 2 - labelH - gap - nodeR - margin;
        // Noticeably smaller than the available room so the ring sits well
        // inside its gutters, with generous breathing space all around.
        final r = math.max(52.0, math.min(halfW, halfH) * 0.70);
        final cx = w / 2;
        // Centre the ring in its room: equal clearance top and bottom so no
        // label clips on either side.
        final cy = h / 2;

        final children = <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _RingPainter(n: n, radius: r),
            ),
          ),
          // Centre caption.
          Positioned(
            left: cx - 70,
            top: cy - 16,
            width: 140,
            child: IgnorePointer(
              child: Text(
                loc.ringStepsSelected(selected.length, n),
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
          final color = _stepColor(i, n);
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

          // Label, anchored just outside the node. In the crowded top/bottom
          // arcs the labels would sit at nearly the same height and collide, so
          // we push alternate labels further out — a two-tier stagger that
          // separates neighbours vertically.
          final crowded = cosT.abs() < 0.55;
          final extraOut = (crowded && i.isOdd) ? labelH * 0.45 : 0.0;
          final ax = cx + (r + nodeR + gap + extraOut) * cosT;
          final ay = cy + (r + nodeR + gap + extraOut) * sinT;

          final double left;
          final TextAlign align;
          final Alignment boxAlign;
          if (cosT > 0.18) {
            left = ax;
            align = TextAlign.left;
            boxAlign = Alignment.centerLeft;
          } else if (cosT < -0.18) {
            left = ax - labelW;
            align = TextAlign.right;
            boxAlign = Alignment.centerRight;
          } else {
            left = ax - labelW / 2;
            align = TextAlign.center;
            boxAlign = Alignment.center;
          }
          // Near-vertical (top/bottom) labels sit fully clear of the node;
          // diagonal/side labels centre on the radial anchor.
          final double top = cosT.abs() <= 0.18
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
                  maxLines: 3,
                  textAlign: align,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: font,
                    height: 1.2,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                    color: isSel ? scheme.onSurface : scheme.onSurfaceVariant,
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
  _RingPainter({required this.n, required this.radius});
  final int n;
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
      stroke.color = _stepColor(i, n).withValues(alpha: 0.5);
      canvas.drawArc(rect, a0, sweep, false, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.n != n || old.radius != radius;
}

/// The Best-For selector cards above the circle. One card per audience variant;
/// the selected one is highlighted. Tapping a card swaps the circle to that
/// audience's components.
class _BestForCards extends StatelessWidget {
  const _BestForCards({
    required this.structure,
    required this.selectedVariant,
    required this.onSelect,
  });

  final NarrativeStructure structure;
  final int selectedVariant;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = PsittaTokens.of(context);
    final loc = AppLocalizations.of(context);
    final cards = <Widget>[];
    for (var i = 0; i < structure.variants.length; i++) {
      final v = structure.variants[i];
      final isSel = i == selectedVariant;
      final color = tokens.glow;
      cards.add(Expanded(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSel
                    ? color.withValues(alpha: 0.14)
                    : tokens.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSel ? color : tokens.border,
                  width: isSel ? 1.8 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSel
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: isSel ? color : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          bestForLabel(context, v.bestFor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isSel ? color : scheme.onSurface,
                          ),
                        ),
                        Text(loc.nSteps(v.components.length),
                            style: TextStyle(
                                fontSize: 10.5,
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
      if (i < structure.variants.length - 1) {
        cards.add(const SizedBox(width: 10));
      }
    }
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
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 10, 12),
      child: ListView.builder(
        itemCount: kNarrativeStructures.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
              child: Text(
                loc.popularStructures,
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
            onTap: () {
              // New structure → reset the variant selector to the first one.
              ref.read(selectedStructureIndexProvider.notifier).state = idx;
              ref.read(selectedVariantIndexProvider.notifier).state = 0;
            },
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
    final loc = AppLocalizations.of(context);

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
                          structure.variants
                              .map((v) => bestForLabel(context, v.bestFor))
                              .join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10.5, color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          structure.hasVariants
                              ? loc.nAudiences(structure.variants.length)
                              : loc.nSections(structure.components.length),
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
  const _StructureDetail({required this.structure, required this.variantIndex});
  final NarrativeStructure structure;
  final int variantIndex;

  @override
  ConsumerState<_StructureDetail> createState() => _StructureDetailState();
}

class _StructureDetailState extends ConsumerState<_StructureDetail> {
  late Set<int> _selected;

  List<String> get _components =>
      widget.structure.variants[widget.variantIndex].components;

  @override
  void initState() {
    super.initState();
    _selectAll();
  }

  @override
  void didUpdateWidget(covariant _StructureDetail old) {
    super.didUpdateWidget(old);
    // Reset the picks when the writer switches structure OR Best-For variant.
    if (old.structure.name != widget.structure.name ||
        old.variantIndex != widget.variantIndex) {
      setState(_selectAll);
    }
  }

  void _selectAll() {
    _selected = {for (var i = 0; i < _components.length; i++) i};
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final s = widget.structure;
    final variant = s.variants[widget.variantIndex];
    final components = _components;
    final total = components.length;
    final count = _selected.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 2, 28, 8),
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
                      '${bestForLabel(context, variant.bestFor)}  ·  ${loc.sectionsSelected(count, total)}',
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
                label: Text(loc.useThisStructure),
                onPressed: count == 0
                    ? null
                    : () => _attachNarrativeToProject(
                          context,
                          ref,
                          s.name,
                          s.key,
                          variant.bestFor,
                          [
                            for (var i = 0; i < total; i++)
                              if (_selected.contains(i)) components[i],
                          ],
                        ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Best-For selector — pick the audience, the circle redraws.
          Row(
            children: [
              Text(loc.labelBestFor,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 6),
          _BestForCards(
            structure: s,
            selectedVariant: widget.variantIndex,
            onSelect: (i) =>
                ref.read(selectedVariantIndexProvider.notifier).state = i,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(loc.pickSections,
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(_selectAll),
                child: Text(loc.selectAll),
              ),
              TextButton(
                onPressed: () => setState(() => _selected = {}),
                child: Text(loc.clearSelection),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: tokens.divider),
          Expanded(
            child: LayoutBuilder(
              builder: (context, cns) {
                // Give the circle generous room so labels never collide or
                // clip; scroll vertically when the pane is shorter than needed.
                final n = components.length;
                final need = 360.0 + (n > 10 ? (n - 10) * 20.0 : 0.0);
                final hh = math.max(cns.maxHeight, need);
                return SingleChildScrollView(
                  child: SizedBox(
                    width: cns.maxWidth,
                    height: hh,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: _StructureCircle(
                        components: components,
                        selected: _selected,
                        onToggle: _toggle,
                      ),
                    ),
                  ),
                );
              },
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
  const _StructureInfo({required this.structure, required this.variantIndex});
  final NarrativeStructure structure;
  final int variantIndex;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final variants = structure.variants;
    final selected = variants[variantIndex];
    final loc = AppLocalizations.of(context);

    return Container(
      color: tokens.surface,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
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
          _label(context, loc.labelBestFor),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < variants.length; i++)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: i == variantIndex
                        ? tokens.glow
                        : tokens.glow.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(bestForLabel(context, variants[i].bestFor),
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: i == variantIndex
                              ? Colors.white
                              : tokens.glow)),
                ),
            ],
          ),
          const SizedBox(height: 22),
          _label(context, loc.labelIncludes),
          const SizedBox(height: 8),
          _infoRow(scheme, Icons.check_circle_outline,
              loc.sectionsForBestFor(selected.components.length, bestForLabel(context, selected.bestFor))),
          const SizedBox(height: 8),
          _infoRow(scheme, Icons.check_circle_outline,
              loc.editableInDesk),
          const SizedBox(height: 8),
          _infoRow(scheme, Icons.check_circle_outline,
              loc.placeDocsInSection),
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
        crossAxisAlignment: CrossAxisAlignment.start,
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

// ── Attach the chosen narrative to a project ─────────────────────────────────

/// Saves the writer's narrative pick (structure + Best-For + chosen beats) onto
/// a project via PUT /projects/{id}/narrative. It never touches Book Structure.
/// Auto-targets the only book, or asks which one when there are several.
Future<void> _attachNarrativeToProject(
  BuildContext context,
  WidgetRef ref,
  String structureName,
  String structureKey,
  String variant,
  List<String> beats,
) async {
  final loc = AppLocalizations.of(context);
  final repo = ref.read(projectRepositoryProvider);
  final projects =
      ref.read(projectsProvider).valueOrNull ?? await repo.listProjects();
  if (!context.mounted) return;
  if (projects.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(loc.createProjectFirstNarrative)));
    return;
  }
  final projectId = projects.length == 1
      ? projects.first.id
      : await showDialog<String>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: Text(loc.addNarrativeToBook),
            children: [
              for (final p in projects)
                SimpleDialogOption(
                  onPressed: () => Navigator.of(ctx).pop(p.id),
                  child: Text(p.name),
                ),
            ],
          ),
        );
  if (projectId == null || !context.mounted) return;
  try {
    await repo.setProjectNarrative(
      projectId,
      structureKey: structureKey,
      variant: variant,
      beats: beats,
    );
    ref.invalidate(projectDetailProvider(projectId));
    if (!context.mounted) return;
    final pname = projects.firstWhere((p) => p.id == projectId).name;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(loc.narrativeSavedMsg(structureName, variant, pname))));
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.narrativeSaveFailed)));
    }
  }
}
