import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/psitta_tokens.dart';
import 'blueprint_architecture_map.dart';

/// The "Diagram" tab — the place a writer goes to understand the whole
/// Blueprint sector. Two coaching surfaces:
///   1. a simple didactic diagram that coaches HOW to choose a Book Structure
///      and a Narrative Structure;
///   2. the full relationship map that coaches HOW the Writing Nook tier fits
///      together (yellow = saved in the database, grey = in-app only).
/// Pure teaching surface; reads and writes nothing.
///
/// NOTE: filename is historical (started as a dialog). Safe to rename the file
/// to `blueprint_guide_tab.dart`.
class BlueprintGuideTab extends StatelessWidget {
  const BlueprintGuideTab({super.key});

  static const Color _purple = Color(0xFF8A7CFF); // Book Structure
  static const Color _blue = Color(0xFF4FB0E5); // Narrative Structure
  static const Color _amber = Color(0xFFE0A24E); // saved
  static const Color _grey = Color(0xFF7C8696); // in-app

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: tokens.surface,
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Understanding Blueprints',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface)),
              const SizedBox(height: 6),
              Text('Every great book combines structure and narrative.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13.5, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 26),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _didactic(tokens, scheme),
              ),
              const SizedBox(height: 22),
              _chooseCoach(tokens, scheme),
              const SizedBox(height: 30),
              Divider(height: 1, color: tokens.divider),
              const SizedBox(height: 24),
              Text('How the Writing Nook fits together',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface)),
              const SizedBox(height: 4),
              Text('Every piece of your book — and how you move between them.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 14),
              _mapSwatches(scheme),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, cns) {
                  final maxW = cns.maxWidth.isFinite ? cns.maxWidth : 580.0;
                  final scale = math.min(1.0, maxW / ArchitectureMap.w);
                  return SizedBox(
                    width: ArchitectureMap.w * scale,
                    height: ArchitectureMap.h * scale,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: ArchitectureMap.w,
                        height: ArchitectureMap.h,
                        child: const ArchitectureMap(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 22),
              _glossary(tokens, scheme),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. Didactic infographic ──────────────────────────────────────────────

  Widget _didactic(PsittaTokens tokens, ColorScheme scheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          decoration: BoxDecoration(
            color: tokens.glow.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: tokens.glow.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_rounded, size: 18, color: tokens.glow),
              const SizedBox(width: 8),
              Text('BOOK',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: tokens.glow)),
            ],
          ),
        ),
        _arrow(tokens.glow),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _branch(scheme, Icons.view_agenda_rounded, 'BOOK STRUCTURE', _purple,
                const [
                  'Front Matter',
                  'Part I',
                  'Part II',
                  'Part III',
                  'Back Matter',
                ]),
            const SizedBox(width: 22),
            _branch(scheme, Icons.timeline_rounded, 'NARRATIVE STRUCTURE', _blue,
                const [
                  'Beginning',
                  'Conflict',
                  'Challenge',
                  'Climax',
                  'Resolution',
                ]),
          ],
        ),
        const SizedBox(height: 22),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: tokens.glow.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tokens.glow.withValues(alpha: 0.26)),
          ),
          child: Column(
            children: [
              _legend(scheme, _purple, 'Book Structure',
                  '  =  Where content lives'),
              const SizedBox(height: 10),
              _legend(scheme, _blue, 'Narrative Structure',
                  '  =  How content flows'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _branch(ColorScheme scheme, IconData icon, String title, Color color,
      List<String> items) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 5),
                Text(title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: color)),
              ],
            ),
          ),
          _arrow(color),
          for (var k = 0; k < items.length; k++) ...[
            _miniBox(scheme, items[k], color),
            if (k < items.length - 1) _arrow(color),
          ],
        ],
      ),
    );
  }

  Widget _miniBox(ColorScheme scheme, String text, Color color) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface)),
      );

  Widget _arrow(Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Icon(Icons.keyboard_arrow_down_rounded,
            size: 17, color: color.withValues(alpha: 0.7)),
      );

  Widget _legend(ColorScheme scheme, Color color, String bold, String rest) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(top: 5, right: 10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                    fontSize: 13.5, height: 1.3, color: scheme.onSurfaceVariant),
                children: [
                  TextSpan(
                      text: bold,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface)),
                  TextSpan(text: rest),
                ],
              ),
            ),
          ),
        ],
      );

  // ── Coaching: how to choose each structure ───────────────────────────────

  Widget _chooseCoach(PsittaTokens tokens, ColorScheme scheme) {
    // IntrinsicHeight bounds the Row's height; a stretch Row directly in the
    // vertical scroll would get unbounded height → "render box with no size".
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Expanded(
          child: _chooseCard(
            scheme,
            _purple,
            'Choosing your Book Structure',
            'Pick by format — how the manuscript is organized.',
            const [
              'Novel → Parts & Chapters',
              'Memoir → life phases',
              'Business → Problem ▸ Method',
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _chooseCard(
            scheme,
            _blue,
            'Choosing your Narrative Structure',
            'Pick by journey — how the story unfolds.',
            const [
              "Hero's Journey → transformation",
              'Three Act → most fiction',
              'Save the Cat → screenplays',
            ],
          ),
        ),
      ],
      ),
    );
  }

  Widget _chooseCard(ColorScheme scheme, Color color, String title,
      String rule, List<String> examples) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(height: 5),
          Text(rule,
              style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: scheme.onSurface)),
          const SizedBox(height: 9),
          for (final e in examples)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3, right: 7),
                    child: Icon(Icons.check_rounded, size: 13, color: color),
                  ),
                  Expanded(
                    child: Text(e,
                        style: TextStyle(
                            fontSize: 11.5,
                            height: 1.3,
                            color: scheme.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Map: swatches, glossary, flow, line key ──────────────────────────────

  Widget _mapSwatches(ColorScheme scheme) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _swatch(_amber, 'Saved in the database', scheme),
          const SizedBox(width: 20),
          _swatch(_grey, 'In-app only (not saved)', scheme),
        ],
      );

  Widget _swatch(Color color, String label, ColorScheme scheme) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: color),
            ),
          ),
          const SizedBox(width: 7),
          Text(label,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      );

  Widget _glossary(PsittaTokens tokens, ColorScheme scheme) {
    const items = <(String, String)>[
      ('Document', 'your file — the centre of everything'),
      ('Writing Desk', 'where you write a file'),
      ('Project', 'a folder that holds the book and its files'),
      ('Section', 'a file’s home in the outline — one file, one section'),
      ('Book Structure',
          'your reusable book outline and its sections (saved)'),
      ('Narrative Structure',
          'a menu of story models — picking one builds a Book Structure'),
    ];
    const flow = <String>[
      'Create a Project — the book you are working on.',
      'Choose a structure — it generates a Book Structure outline.',
      'Add or place each file into one Section of that outline.',
      'Write each file at the Writing Desk.',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What each piece means',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface)),
          const SizedBox(height: 10),
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: scheme.onSurfaceVariant),
                  children: [
                    TextSpan(
                        text: '${it.$1}  —  ',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface)),
                    TextSpan(text: it.$2),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 6),
          Divider(height: 1, color: tokens.divider),
          const SizedBox(height: 12),
          Text('The writer’s path',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface)),
          const SizedBox(height: 9),
          for (var i = 0; i < flow.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    margin: const EdgeInsets.only(right: 9, top: 1),
                    decoration: BoxDecoration(
                      color: tokens.glow.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Text('${i + 1}',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: tokens.glow)),
                  ),
                  Expanded(
                    child: Text(flow[i],
                        style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: scheme.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Divider(height: 1, color: tokens.divider),
          const SizedBox(height: 12),
          _lineKey(scheme,
              dashed: false,
              text: 'Solid line — a saved connection between pieces.'),
          const SizedBox(height: 8),
          _lineKey(scheme,
              dashed: true,
              text: 'Dashed line — an action you take from the Writing Desk.'),
        ],
      ),
    );
  }

  Widget _lineKey(ColorScheme scheme,
      {required bool dashed, required String text}) {
    return Row(
      children: [
        SizedBox(
          width: 26,
          height: 10,
          child: CustomPaint(
            painter: _LineKeyPainter(dashed: dashed, color: _grey),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style:
                  TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}

/// Tiny solid/dashed line sample for the map's line key.
class _LineKeyPainter extends CustomPainter {
  _LineKeyPainter({required this.dashed, required this.color});
  final bool dashed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    } else {
      const dash = 5.0;
      const gap = 4.0;
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(
            Offset(x, y), Offset(math.min(x + dash, size.width), y), p);
        x += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineKeyPainter old) =>
      old.dashed != dashed || old.color != color;
}
