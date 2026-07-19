// D1 regression — no phantom highlight after genuine document completion.
//
// After a document finishes, F5 stops the engine (playlist retired, context
// nulled) and rewinds the chunk model to 0. But the position stream, a cached
// alignment payload, and a stale sentence index could still describe a
// sentence nobody is reading — which painted a phantom sentence highlight on
// page 1 (observed in QA round 2 as "attention jumped to the 11th sentence")
// and dragged the follow-scroll to it. The fix gates ALL sentence-mode paint
// on an ACTIVE sentence playlist (audioService.hasSentencePlaylist).
//
// These tests pin: (1) sentence mode with NO active playlist paints nothing
// and fires no follow-scroll, even with alignment + a non-zero
// sentenceCharBase mimicking the stale post-completion state; (2) the guard
// does not over-suppress — chunk-alignment mode (sentenceMode: false) still
// paints its word highlight exactly as before.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psitta/data/models/psitta_document.dart';
import 'package:psitta/data/services/audio_service.dart'
    show
        audioPositionProvider,
        audioDurationProvider,
        audioPlayingProvider;
import 'package:psitta/features/player/widgets/document_reading_view.dart';

PsittaDocument _twoSentenceDoc() {
  //                0123456789012345678901234567
  const text = 'First sentence. Second one.';
  return const PsittaDocument(
    id: 'doc-1',
    title: 't',
    blocks: [
      DocBlock(
        blockId: 'b_0',
        type: DocBlockType.paragraph,
        runs: [DocRun(text: text)],
        textOffset: 0,
        textLength: 27,
      ),
    ],
    plainText: text,
    sentences: [
      DocSentence(index: 0, startOffset: 0, endOffset: 16, blockIds: ['b_0']),
      DocSentence(index: 1, startOffset: 16, endOffset: 27, blockIds: ['b_0']),
    ],
    chunkMap: [
      ChunkRef(chunkId: 'c0', chunkIndex: 0, textOffset: 0, textLength: 27),
    ],
  );
}

/// Alignment whose char 0 starts at t=0 so a reset position (0 ms) resolves —
/// exactly the ingredients of the phantom-paint bug.
Map<String, dynamic> _alignmentFor(String sentence) => {
      'alignment': {
        'normalized_alignment': {
          'characters': sentence.split(''),
          'character_start_times_seconds': [
            for (var i = 0; i < sentence.length; i++) i * 0.1,
          ],
          'character_end_times_seconds': [
            for (var i = 0; i < sentence.length; i++) (i + 1) * 0.1,
          ],
        },
      },
    };

int _countHighlightedSpans(WidgetTester tester) {
  var highlighted = 0;
  for (final selectable
      in tester.widgetList<SelectableText>(find.byType(SelectableText))) {
    void walk(InlineSpan span) {
      if (span is TextSpan) {
        if (span.style?.backgroundColor != null) highlighted++;
        span.children?.forEach(walk);
      }
    }

    final span = selectable.textSpan;
    if (span != null) walk(span);
  }
  return highlighted;
}

Widget _host(Widget child) => ProviderScope(
      overrides: [
        audioPositionProvider
            .overrideWith((ref) => Stream<Duration>.value(Duration.zero)),
        audioDurationProvider
            .overrideWith((ref) => Stream<Duration?>.value(Duration.zero)),
        audioPlayingProvider.overrideWith((ref) => Stream<bool>.value(false)),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  testWidgets(
      'sentence mode with NO active playlist paints nothing after completion '
      '(stale base + cached alignment + reset position)', (tester) async {
    var scrollCallbacks = 0;
    await tester.pumpWidget(_host(
      DocumentReadingView(
        document: _twoSentenceDoc(),
        activeChunkIndex: 0, // F5 rewound the model to chunk 0
        // Stale state mimicry: the last chunk's final sentence left base 16
        // (sentence 2) and its alignment is still cached.
        alignmentPayload: _alignmentFor('Second one.'),
        sentenceMode: true,
        sentenceCharBase: 16,
        audioService: null, // no active playlist — document completed
        onActiveSentenceChanged: (_) => scrollCallbacks++,
      ),
    ));
    await tester.pump();

    expect(_countHighlightedSpans(tester), 0,
        reason: 'no sentence/word may be highlighted after completion');
    expect(scrollCallbacks, 0,
        reason: 'no follow-scroll may fire after completion');
  });

  testWidgets(
      'guard does not over-suppress: chunk-alignment mode still paints the '
      'active word during playback', (tester) async {
    await tester.pumpWidget(_host(
      DocumentReadingView(
        document: _twoSentenceDoc(),
        activeChunkIndex: 0,
        // Whole-chunk alignment for the full text; position 0 → first word.
        alignmentPayload: _alignmentFor('First sentence. Second one.'),
        sentenceMode: false,
        audioService: null,
      ),
    ));
    await tester.pump();

    expect(_countHighlightedSpans(tester), greaterThan(0),
        reason: 'non-sentence mode must keep its existing highlight paint');
  });
}
