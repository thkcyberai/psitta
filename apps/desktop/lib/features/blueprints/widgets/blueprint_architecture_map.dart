import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/psitta_tokens.dart';

/// The file-centric relationship map for the Blueprints "Diagram" tab. The
/// DOCUMENT (the writer's file) sits at the centre; everything connects to it
/// and it connects to everything. A file has exactly one home — one Project and
/// one Section — so the spokes read in the singular ("filed in 1 project",
/// "placed in 1 section"). Amber = saved in the database; grey = in-app only.
///
/// Fixed logical canvas; the caller scales it to fit.
class ArchitectureMap extends StatelessWidget {
  const ArchitectureMap({super.key});

  static const double w = 580;
  static const double h = 600;

  static const Rect _doc = Rect.fromLTWH(204, 234, 172, 70); // hub
  static const Rect _desk = Rect.fromLTWH(212, 40, 156, 56);
  static const Rect _proj = Rect.fromLTWH(404, 182, 158, 56);
  static const Rect _section = Rect.fromLTWH(18, 182, 158, 56);
  static const Rect _bp = Rect.fromLTWH(202, 398, 176, 60);
  static const Rect _narr = Rect.fromLTWH(202, 516, 176, 60);

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;

    final nodes = <_Node>[
      _Node(_doc, 'DOCUMENT', 'your file — the centre of everything',
          saved: true, hub: true),
      _Node(_desk, 'WRITING DESK', 'where you write it', saved: false),
      _Node(_proj, 'PROJECT', 'a folder of files', saved: true),
      _Node(_section, 'SECTION', 'its home in the outline', saved: true),
      _Node(_bp, 'BOOK STRUCTURE', 'the outline of your book', saved: true),
      _Node(_narr, 'NARRATIVE STRUCTURE', 'story model (builds a Book Structure)',
          saved: false),
    ];

    final links = <_Link>[
      // file ↔ everything (the hub spokes)
      _link(_doc, _desk, 'written & edited here', bidi: true, dashed: true),
      _link(_doc, _proj, 'filed in 1 project', bidi: true),
      _link(_doc, _section, 'placed in 1 section', bidi: true),
      // how the structure extends out from the file's section
      _link(_section, _bp, 'section of'),
      _link(_proj, _bp, 'project adopts it'),
      _link(_bp, _narr, 'built from'),
    ];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _EdgePainter(
              links: links,
              lineColor: const Color(0xFF8B93A1),
              chipBg: tokens.surface2,
              chipBorder: tokens.border,
              labelColor: scheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final n in nodes) _box(n, scheme, tokens.glow),
      ],
    );
  }

  /// A straight connector clipped to both boxes' borders.
  _Link _link(Rect a, Rect b, String label,
      {bool bidi = false, bool dashed = false}) {
    return _Link(_anchor(a, b.center), _anchor(b, a.center), label,
        bidi: bidi, dashed: dashed);
  }

  /// The point on [box]'s border in the direction of [toward].
  static Offset _anchor(Rect box, Offset toward) {
    final c = box.center;
    final d = toward - c;
    if (d.dx.abs() < 1e-6 && d.dy.abs() < 1e-6) return c;
    final tx = d.dx.abs() < 1e-6 ? double.infinity : (box.width / 2) / d.dx.abs();
    final ty =
        d.dy.abs() < 1e-6 ? double.infinity : (box.height / 2) / d.dy.abs();
    final t = math.min(tx, ty);
    return c + d * t;
  }

  Widget _box(_Node n, ColorScheme scheme, Color hubColor) {
    final accent = n.hub
        ? hubColor
        : (n.saved ? const Color(0xFFE0A24E) : const Color(0xFF7C8696));
    final fill = n.hub
        ? hubColor.withValues(alpha: 0.16)
        : (n.saved ? const Color(0xFF2E2710) : const Color(0xFF262A33));
    return Positioned(
      left: n.rect.left,
      top: n.rect.top,
      width: n.rect.width,
      height: n.rect.height,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(n.hub ? 14 : 10),
          border: Border.all(
              color: accent.withValues(alpha: n.hub ? 1 : 0.75),
              width: n.hub ? 2.2 : 1.4),
          boxShadow: n.hub
              ? [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 16)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(n.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: n.hub ? 13 : 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: accent)),
            const SizedBox(height: 2),
            Text(n.subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 9.5,
                    height: 1.2,
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _Node {
  const _Node(this.rect, this.title, this.subtitle,
      {required this.saved, this.hub = false});
  final Rect rect;
  final String title;
  final String subtitle;
  final bool saved;
  final bool hub;
}

class _Link {
  const _Link(this.a, this.b, this.label,
      {this.bidi = false, this.dashed = false});
  final Offset a;
  final Offset b;
  final String label;
  final bool bidi;
  final bool dashed;
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.links,
    required this.lineColor,
    required this.chipBg,
    required this.chipBorder,
    required this.labelColor,
  });

  final List<_Link> links;
  final Color lineColor;
  final Color chipBg;
  final Color chipBorder;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = lineColor.withValues(alpha: 0.75);
    final fill = Paint()..color = lineColor.withValues(alpha: 0.85);

    for (final link in links) {
      final a = link.a;
      final b = link.b;

      if (link.dashed) {
        const steps = 40;
        for (var i = 0; i < steps; i++) {
          if (i.isOdd) continue;
          canvas.drawLine(
              Offset.lerp(a, b, i / steps)!,
              Offset.lerp(a, b, (i + 1) / steps)!,
              stroke);
        }
      } else {
        canvas.drawLine(a, b, stroke);
      }

      _arrow(canvas, b, math.atan2(b.dy - a.dy, b.dx - a.dx), fill);
      if (link.bidi) {
        _arrow(canvas, a, math.atan2(a.dy - b.dy, a.dx - b.dx), fill);
      }

      _label(canvas, Offset.lerp(a, b, 0.5)!, link.label);
    }
  }

  void _arrow(Canvas canvas, Offset tip, double ang, Paint fill) {
    const ah = 8.0;
    final p = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - ah * math.cos(ang - 0.45),
          tip.dy - ah * math.sin(ang - 0.45))
      ..lineTo(tip.dx - ah * math.cos(ang + 0.45),
          tip.dy - ah * math.sin(ang + 0.45))
      ..close();
    canvas.drawPath(p, fill);
  }

  void _label(Canvas canvas, Offset center, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 10, height: 1.0, color: labelColor),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: 124);
    const padH = 6.0;
    const padV = 3.0;
    final rect = Rect.fromCenter(
      center: center,
      width: tp.width + padH * 2,
      height: tp.height + padV * 2,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawRRect(rrect, Paint()..color = chipBg);
    canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = chipBorder);
    tp.paint(canvas, Offset(rect.left + padH, rect.top + padV));
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) => false;
}
