// Golden diagnostic for the bold first-/last-char highlight clip.
//
// Hypothesis (KL 2026-06-01c): Flutter paints TextSpan.backgroundColor from a
// glyph's ADVANCE origin, not its visual ink extent. A heavy bold cap has a
// leading bearing (ink sits left of the advance origin); when the highlighted
// span is the FIRST child of the paragraph there is no preceding glyph whose
// advance "absorbs" that bearing, so the leading ink can fall OUTSIDE the
// background rect and look unhighlighted. The symmetric tail case (last child)
// is included to test the trailing edge.
//
// This is a TEST ONLY. It renders the SAME TextSpan tree + TextStyle that
// DocumentReadingView builds (recon: heading = textTheme.headlineMedium +
// height 1.6; word highlight = +w700 +colorScheme.primary.withOpacity(0.45);
// rendered via SelectableText.rich), so the captured paint artifact is faithful
// to production. REAL Roboto is loaded via golden_toolkit.loadAppFonts() — the
// default Ahem fallback has uniform metrics and would hide the bearing artifact.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:psitta/core/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  testWidgets('bold first/last-char highlight clip — controlled cases A–E',
      (tester) async {
    // The five cases stack vertically; pin a surface tall enough that every
    // case (A–E) lands inside the captured PNG. The default 800x600 test
    // surface would clip case E off the bottom and defeat the inspection.
    // Reset registered via addTearDown so it runs inside the test zone
    // (a top-level tearDown() trips the binding's `inTest` assertion).
    await tester.binding.setSurfaceSize(const Size(820, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.paperLight,
        home: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            final primary = theme.colorScheme.primary;
            final bg = primary.withOpacity(0.45);

            // Heading style — matches DocumentReadingView level-1 heading.
            final base = theme.textTheme.headlineMedium!.copyWith(height: 1.6);
            final bold = base.copyWith(fontWeight: FontWeight.w700);
            final highlightBold = base.copyWith(
              fontWeight: FontWeight.w700,
              backgroundColor: bg,
            );

            // List-item control style — bodyLarge w400 + height 1.6.
            final listPlain =
                theme.textTheme.bodyLarge!.copyWith(height: 1.6);
            final listHighlight = listPlain.copyWith(backgroundColor: bg);

            Widget caseRow(String label, List<TextSpan> spans) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.labelMedium),
                    const SizedBox(height: 4),
                    SelectableText.rich(TextSpan(children: spans)),
                  ],
                ),
              );
            }

            return Scaffold(
              backgroundColor: Colors.white,
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // A — BUG: highlighted bold span is the FIRST child.
                      caseRow('A - bold, highlight is FIRST child (bug)', [
                        TextSpan(text: 'Thursday', style: highlightBold),
                        TextSpan(text: ': Cardio + Core', style: bold),
                      ]),
                      // B — FIX-a: zero-width leading span absorbs the bearing.
                      caseRow('B - fix-a: zero-width (U+200B) leading span', [
                        TextSpan(text: '​', style: bold),
                        TextSpan(text: 'Thursday', style: highlightBold),
                        TextSpan(text: ': Cardio + Core', style: bold),
                      ]),
                      // C — list control: non-bold, highlight not first child.
                      caseRow('C - list control (bullet prefix, non-bold)', [
                        TextSpan(text: '  •  ', style: listPlain),
                        TextSpan(text: 'Exercises', style: listHighlight),
                        TextSpan(
                            text: ': Push-ups, pull-ups', style: listPlain),
                      ]),
                      // D — non-bold first child (w400) to isolate weight.
                      caseRow('D - non-bold first-child (w400)', [
                        TextSpan(
                            text: 'Thursday',
                            style: base.copyWith(backgroundColor: bg)),
                        TextSpan(text: ': Cardio + Core', style: base),
                      ]),
                      // E — highlighted bold span is the LAST child (tail).
                      caseRow('E - bold, highlight is LAST child', [
                        TextSpan(text: 'Thursday: Cardio + ', style: bold),
                        TextSpan(text: 'Core', style: highlightBold),
                      ]),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/bold_highlight_clip.png'),
    );
  });
}
