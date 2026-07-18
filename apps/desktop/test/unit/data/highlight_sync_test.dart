// Regression tests for the sentence/word highlight desync in multi-chunk
// documents ("At the Coffe Shop" bug — docs/handoffs/
// tts-sentence-highlight-regression-handoff.md).
//
// Root cause: the highlighter combined the CHUNK from the UI toolbar model
// (currentChunkIndexProvider — advanced the instant a chunk completes by
// PlayerBar._skipForward) with the SENTENCE INDEX from the audio engine
// (chunk-local to whatever playlist is actually playing). During a chunk
// hand-off the two disagree, and because
//   docOffset = chunkMap[chunkIndex].textOffset + sentenceCharBase + charAtMs
// a one-chunk model error leaps the highlight (and the follow-scroll) an
// entire chunk down-document while the voice is still at the boundary.
//
// The fix: AudioService emits the atomic SentencePlaybackContext
// (documentId, chunkId, sentenceIndex) at every sentence change, and
// resolveHighlightSync keys EVERY highlight input to that pair whenever a
// sentence playlist is active. These tests pin both the resolver contract and
// a numeric simulation of the exact boundary hand-off event sequence proven
// in the static analysis (stale window between the chunk-model write and the
// next playlist's first index emission).
import 'package:flutter_test/flutter_test.dart';
import 'package:psitta/data/services/audio_service.dart'
    show SentencePlaybackContext, resolveHighlightSync;

void main() {
  const doc = 'doc-1';
  const chunkIds = ['chunk-0', 'chunk-1', 'chunk-2'];

  group('resolveHighlightSync contract', () {
    test('no context (nothing playing) → falls back to the chunk model', () {
      final sync = resolveHighlightSync(
        documentId: doc,
        chunkIds: chunkIds,
        modelChunkIndex: 2,
        fallbackSentenceIndex: 5,
        context: null,
      );
      expect(sync.chunkIndex, 2);
      expect(sync.sentenceIndex, 5);
      expect(sync.fromAudioContext, isFalse);
    });

    test('context for a DIFFERENT document is rejected → chunk model', () {
      final sync = resolveHighlightSync(
        documentId: doc,
        chunkIds: chunkIds,
        modelChunkIndex: 1,
        fallbackSentenceIndex: 3,
        context: const SentencePlaybackContext(
          documentId: 'other-doc',
          chunkId: 'chunk-0',
          sentenceIndex: 9,
        ),
      );
      expect(sync.chunkIndex, 1);
      expect(sync.sentenceIndex, 3);
      expect(sync.fromAudioContext, isFalse);
    });

    test('context whose chunk is absent (list re-sliced) → chunk model', () {
      final sync = resolveHighlightSync(
        documentId: doc,
        chunkIds: chunkIds,
        modelChunkIndex: 0,
        fallbackSentenceIndex: 1,
        context: const SentencePlaybackContext(
          documentId: doc,
          chunkId: 'stale-chunk-id',
          sentenceIndex: 4,
        ),
      );
      expect(sync.chunkIndex, 0);
      expect(sync.fromAudioContext, isFalse);
    });

    test('agreeing context → identical result to the model (no-op case)', () {
      final sync = resolveHighlightSync(
        documentId: doc,
        chunkIds: chunkIds,
        modelChunkIndex: 1,
        fallbackSentenceIndex: 7,
        context: const SentencePlaybackContext(
          documentId: doc,
          chunkId: 'chunk-1',
          sentenceIndex: 7,
        ),
      );
      expect(sync.chunkIndex, 1);
      expect(sync.sentenceIndex, 7);
      expect(sync.fromAudioContext, isTrue);
    });

    test(
        'THE REGRESSION CASE: model advanced to N+1, audio still on chunk N '
        '→ highlight follows the audio pair', () {
      final sync = resolveHighlightSync(
        documentId: doc,
        chunkIds: chunkIds,
        modelChunkIndex: 1, // _skipForward already wrote N+1
        fallbackSentenceIndex: 12, // stale stream value (chunk-N-local)
        context: const SentencePlaybackContext(
          documentId: doc,
          chunkId: 'chunk-0', // the audio engine is STILL on chunk N
          sentenceIndex: 12,
        ),
      );
      expect(sync.chunkIndex, 0, reason: 'chunk must come from the audio');
      expect(sync.sentenceIndex, 12);
      expect(sync.fromAudioContext, isTrue);
    });
  });

  group('boundary hand-off simulation (root-cause reproduction)', () {
    // Two-chunk fixture mirroring the real coordinate model:
    //   document offsets: chunkMap[i].textOffset lifts chunk-local sentence
    //   boundaries into document space (DocumentAssembler ~211–244), and the
    //   highlighter computes
    //     docOffset = textOffset + sentenceCharBase + localCharIdx
    //   (document_reading_view.dart _activeSentenceIndex ~222–254).
    const chunk0TextOffset = 0;
    const chunk0Length = 1500;
    // chunk-local [start, end) sentence boundaries of chunk 0 (13 sentences,
    // last one ends the chunk) and chunk 1 (enough sentences that the stale
    // index 12 is IN RANGE — the worst case: no clamp saves you).
    const chunk0Boundaries = <List<int>>[
      [0, 120], [120, 260], [260, 380], [380, 500], [500, 640],
      [640, 760], [760, 880], [880, 1000], [1000, 1120], [1120, 1240],
      [1240, 1330], [1330, 1420], [1420, 1500], // idx 12: boundary sentence
    ];
    const chunk1TextOffset = chunk0Length + 2; // +2 = '\n\n' separator
    const chunk1Boundaries = <List<int>>[
      [0, 110], [110, 240], [240, 360], [360, 470], [470, 600],
      [600, 720], [720, 830], [830, 950], [950, 1060], [1060, 1170],
      [1170, 1280], [1280, 1370], [1370, 1450], [1450, 1500],
    ];

    // The audible truth during the stale window: the voice has just finished
    // chunk 0's LAST sentence (index 12); the model has already advanced.
    const audibleChunkIndex = 0;
    const audibleSentenceIdx = 12;
    const staleModelChunkIndex = 1; // written by _skipForward at completion
    const localCharIdx = 40; // _charIndexAtMs within the audible sentence

    int docOffsetFor({
      required int chunkIndex,
      required int sentenceIdx,
    }) {
      final textOffset =
          chunkIndex == 0 ? chunk0TextOffset : chunk1TextOffset;
      final boundaries =
          chunkIndex == 0 ? chunk0Boundaries : chunk1Boundaries;
      final base = boundaries[sentenceIdx][0]; // sentenceCharBase
      return textOffset + base + localCharIdx;
    }

    test(
        'OLD combination (model chunk × audio sentence index) leaps a whole '
        'chunk down-document — the reported symptom', () {
      // Pre-fix desk/player logic: chunk from the model, index from the audio.
      final buggyOffset = docOffsetFor(
        chunkIndex: staleModelChunkIndex,
        sentenceIdx: audibleSentenceIdx,
      );
      final correctOffset = docOffsetFor(
        chunkIndex: audibleChunkIndex,
        sentenceIdx: audibleSentenceIdx,
      );
      final leap = buggyOffset - correctOffset;
      // The torn pair maps into chunk 1's document region...
      expect(buggyOffset, greaterThanOrEqualTo(chunk1TextOffset));
      // ...while the voice is audibly inside chunk 0...
      expect(correctOffset, lessThan(chunk0Length));
      // ...an abrupt forward leap on the order of a whole chunk — exactly the
      // "highlight jumps below the voice and scroll follows it" fingerprint.
      expect(leap, greaterThan(1000),
          reason: 'torn pair must reproduce the one-chunk leap');
    });

    test(
        'FIXED resolution keeps every input in the audible atomic context '
        'through the stale window', () {
      // What AudioService now emits during the hand-off: nothing new yet —
      // the last context still describes the audible boundary sentence.
      const staleWindowContext = SentencePlaybackContext(
        documentId: doc,
        chunkId: 'chunk-0',
        sentenceIndex: audibleSentenceIdx,
      );
      final sync = resolveHighlightSync(
        documentId: doc,
        chunkIds: chunkIds,
        modelChunkIndex: staleModelChunkIndex, // model already at N+1
        fallbackSentenceIndex: audibleSentenceIdx,
        context: staleWindowContext,
      );
      final fixedOffset = docOffsetFor(
        chunkIndex: sync.chunkIndex,
        sentenceIdx: sync.sentenceIndex,
      );
      final correctOffset = docOffsetFor(
        chunkIndex: audibleChunkIndex,
        sentenceIdx: audibleSentenceIdx,
      );
      expect(fixedOffset, correctOffset,
          reason: 'highlight must stay on the audible sentence');
      // And once the next chunk's playlist actually starts (index 0 emission),
      // the context rolls over and the highlight moves WITH the audio:
      const nextChunkContext = SentencePlaybackContext(
        documentId: doc,
        chunkId: 'chunk-1',
        sentenceIndex: 0,
      );
      final rolled = resolveHighlightSync(
        documentId: doc,
        chunkIds: chunkIds,
        modelChunkIndex: staleModelChunkIndex,
        fallbackSentenceIndex: 0,
        context: nextChunkContext,
      );
      expect(rolled.chunkIndex, 1);
      expect(rolled.sentenceIndex, 0);
      expect(
        docOffsetFor(
            chunkIndex: rolled.chunkIndex, sentenceIdx: rolled.sentenceIndex),
        chunk1TextOffset + localCharIdx,
      );
    });

    test(
        'highlighted sentence index never leads the audible sentence across '
        'a boundary (the handoff\'s requested regression assertion)', () {
      // Simulate the full event sequence of a chunk hand-off as a stream of
      // (modelChunkIndex, context) states in the order proven by the static
      // analysis, and assert the resolved highlight NEVER maps ahead of the
      // audible position.
      const audibleTimeline = <({int chunk, int sentence})>[
        (chunk: 0, sentence: 11), // mid chunk 0
        (chunk: 0, sentence: 12), // boundary sentence audible
        (chunk: 0, sentence: 12), // completion fires; model writes N+1 now
        (chunk: 0, sentence: 12), // stale window: next clip still loading
        (chunk: 1, sentence: 0), //  next chunk's audio actually starts
        (chunk: 1, sentence: 1),
      ];
      const modelTimeline = <int>[0, 0, 1, 1, 1, 1];
      final contexts = <SentencePlaybackContext>[
        for (final a in audibleTimeline)
          SentencePlaybackContext(
            documentId: doc,
            chunkId: chunkIds[a.chunk],
            sentenceIndex: a.sentence,
          ),
      ];
      for (var step = 0; step < audibleTimeline.length; step++) {
        final audible = audibleTimeline[step];
        final sync = resolveHighlightSync(
          documentId: doc,
          chunkIds: chunkIds,
          modelChunkIndex: modelTimeline[step],
          fallbackSentenceIndex: audible.sentence,
          context: contexts[step],
        );
        final highlightOffset = docOffsetFor(
          chunkIndex: sync.chunkIndex,
          sentenceIdx: sync.sentenceIndex,
        );
        final audibleOffset = docOffsetFor(
          chunkIndex: audible.chunk,
          sentenceIdx: audible.sentence,
        );
        expect(highlightOffset, lessThanOrEqualTo(audibleOffset),
            reason: 'step $step: highlight must never lead the voice');
        expect(sync.chunkIndex, audible.chunk,
            reason: 'step $step: highlight chunk must equal audible chunk');
      }
    });
  });
}
