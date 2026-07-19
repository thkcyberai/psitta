// Word-highlight continuity (Perfection Pass P2).
//
// Alignment data timestamps EVERY character, including whitespace and
// punctuation between words (backend edge_alignment gap fills; ElevenLabs
// likewise). Highlighting only the exact char under the audio cursor made
// the word highlight strobe OFF during every inter-word gap and drop the
// final word when text ends in punctuation. findWordAnchorIndex snaps the
// cursor BACKWARD to the nearest word character, floor-bounded so the snap
// can never bleed into the previous sentence.
import 'package:flutter_test/flutter_test.dart';
import 'package:psitta/features/player/widgets/document_reading_view.dart'
    show findWordAnchorIndex;

void main() {
  group('findWordAnchorIndex', () {
    //                0123456789012345678901234
    const text = 'Hello, world. Fine day.';

    test('cursor on a word char returns the same index', () {
      expect(findWordAnchorIndex(text, 1, 0), 1); // 'e' of Hello
      expect(findWordAnchorIndex(text, 8, 0), 8); // 'o' of world
    });

    test('cursor on inter-word space snaps back onto the previous word', () {
      // index 6 is the space after "Hello," → snaps to ',' no — ',' is not a
      // word char → continues to 'o' of Hello at index 4.
      expect(findWordAnchorIndex(text, 6, 0), 4);
    });

    test('cursor on punctuation snaps back onto the previous word', () {
      expect(findWordAnchorIndex(text, 5, 0), 4); // ',' → 'o'
      expect(findWordAnchorIndex(text, 12, 0), 11); // '.' → 'd' of world
    });

    test('final word survives a trailing "." (end-of-clip clamp)', () {
      // _charIndexAtMs clamps t > lastEnd to the LAST char — '.' at 22.
      expect(findWordAnchorIndex(text, 22, 0), 21); // '.' → 'y' of day
    });

    test('index past end of text clamps into range first', () {
      expect(findWordAnchorIndex(text, 999, 0), 21);
    });

    test('floor stops the snap at the sentence start', () {
      // Sentence 2 starts at 14 ('Fine day.'). A cursor on its leading
      // region must not walk back into sentence 1.
      expect(findWordAnchorIndex(text, 14, 14), 14); // 'F' itself
      // Cursor on the space at 13 with floor 14 → below floor → null.
      expect(findWordAnchorIndex(text, 13, 14), isNull);
    });

    test('no word char at or above the floor returns null', () {
      const dots = '... hello';
      // Cursor inside the leading dots with floor 0: no word char behind.
      expect(findWordAnchorIndex(dots, 2, 0), isNull);
    });

    test('apostrophes and accents count as word chars', () {
      const pt = "d'água fresca";
      expect(findWordAnchorIndex(pt, 6, 0), 5); // space → 'a' of d'água
      expect(findWordAnchorIndex(pt, 1, 0), 1); // the apostrophe itself
    });

    test('empty text returns null', () {
      expect(findWordAnchorIndex('', 0, 0), isNull);
    });
  });
}
