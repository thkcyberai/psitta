// Characterization tests for quill_codec.dart.
//
// These tests lock in the exact round-trip behavior of the converters so that
// any future change to the codec is immediately caught. They cover:
//   - normalizeHexColor edge cases
//   - blockTypeToString all three variants
//   - blockLevelAttrs: heading, list_item (bullet + numbered), alignment, mixed
//   - attributesEqual: matching and differing on each tracked key
//   - blockDictsToQuillDocument → quillDocumentToBlockDicts round-trips for
//     representative inputs (plain paragraph, heading, list, styled runs,
//     multiple blocks, empty input)
//   - quillDocumentToBlockDicts → blockDictsToQuillDocument round-trips
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:psitta/core/editor/quill_codec.dart';
import 'package:psitta/data/models/psitta_document.dart' show DocBlockType;

void main() {
  // flutter_quill requires a WidgetsBinding to be initialised before it can
  // create a Document (used internally by the test helpers).
  setUpAll(WidgetsFlutterBinding.ensureInitialized);

  // ── normalizeHexColor ─────────────────────────────────────────────────────

  group('normalizeHexColor', () {
    test('normalises 6-digit hex with #', () {
      expect(normalizeHexColor('#FF0000'), 'ff0000');
    });
    test('normalises 6-digit hex without #', () {
      expect(normalizeHexColor('00FF00'), '00ff00');
    });
    test('strips alpha from 8-digit AARRGGBB', () {
      // AA=FF, RR=00, GG=00, BB=FF → keeps only RRGGBB = 0000ff
      expect(normalizeHexColor('#FF0000FF'), '0000ff');
    });
    test('returns null for null input', () {
      expect(normalizeHexColor(null), isNull);
    });
    test('returns null for wrong length', () {
      expect(normalizeHexColor('#FFF'), isNull);
    });
    test('returns null for non-hex characters', () {
      expect(normalizeHexColor('#GGGGGG'), isNull);
    });
  });

  // ── blockTypeToString ─────────────────────────────────────────────────────

  group('blockTypeToString', () {
    test('heading', () => expect(blockTypeToString(DocBlockType.heading), 'heading'));
    test('listItem', () => expect(blockTypeToString(DocBlockType.listItem), 'list_item'));
    test('paragraph', () => expect(blockTypeToString(DocBlockType.paragraph), 'paragraph'));
  });

  // ── blockLevelAttrs ───────────────────────────────────────────────────────

  group('blockLevelAttrs', () {
    test('heading level 1', () {
      final attrs = blockLevelAttrs({'type': 'heading', 'level': 1, 'runs': []});
      expect(attrs, {'header': 1});
    });
    test('heading level 6', () {
      final attrs = blockLevelAttrs({'type': 'heading', 'level': 6, 'runs': []});
      expect(attrs, {'header': 6});
    });
    test('list_item bullet', () {
      final attrs = blockLevelAttrs({'type': 'list_item', 'list_type': 'bullet', 'runs': []});
      expect(attrs, {'list': 'bullet'});
    });
    test('list_item numbered → ordered', () {
      final attrs = blockLevelAttrs({'type': 'list_item', 'list_type': 'numbered', 'runs': []});
      expect(attrs, {'list': 'ordered'});
    });
    test('paragraph has no block attrs', () {
      final attrs = blockLevelAttrs({'type': 'paragraph', 'runs': []});
      expect(attrs, isEmpty);
    });
    test('heading with alignment composes both', () {
      final attrs = blockLevelAttrs(
          {'type': 'heading', 'level': 2, 'alignment': 'center', 'runs': []});
      expect(attrs, {'header': 2, 'align': 'center'});
    });
  });

  // ── attributesEqual ───────────────────────────────────────────────────────

  group('attributesEqual', () {
    test('empty maps are equal', () {
      expect(attributesEqual({}, {}), isTrue);
    });
    test('same bold flag', () {
      expect(attributesEqual({'bold': true}, {'bold': true}), isTrue);
    });
    test('bold true vs false', () {
      expect(attributesEqual({'bold': true}, {'bold': false}), isFalse);
    });
    test('bold true vs absent', () {
      expect(attributesEqual({'bold': true}, {}), isFalse);
    });
    test('different color', () {
      expect(
        attributesEqual({'color': '#ff0000'}, {'color': '#00ff00'}),
        isFalse,
      );
    });
    test('same all supported keys', () {
      final a = {'bold': true, 'italic': true, 'underline': false, 'strike': false, 'size': '20', 'color': '#ff0000', 'font': 'Arial'};
      expect(attributesEqual(a, Map.from(a)), isTrue);
    });
  });

  // ── Round-trip helpers ────────────────────────────────────────────────────

  /// Round-trip: block-dicts → Document → block-dicts.
  List<Map<String, dynamic>> roundTrip(
    List<Map<String, dynamic>> input, {
    DocBlockType type = DocBlockType.paragraph,
    int? level,
  }) {
    final doc = blockDictsToQuillDocument(input);
    return quillDocumentToBlockDicts(doc, type, level);
  }

  // ── blockDictsToQuillDocument / round-trips ───────────────────────────────

  group('round-trip', () {
    test('empty input produces empty-sentinel document and single empty block',
        () {
      final result = roundTrip([]);
      expect(result, hasLength(1));
      expect(result.single['type'], 'paragraph');
      expect((result.single['runs'] as List).single['text'], '');
    });

    test('plain paragraph preserves text', () {
      final input = [
        {
          'type': 'paragraph',
          'runs': [
            {'text': 'Hello world'}
          ]
        }
      ];
      final result = roundTrip(input);
      expect(result, hasLength(1));
      expect(result.single['type'], 'paragraph');
      expect((result.single['runs'] as List).single['text'], 'Hello world');
    });

    test('heading preserves level', () {
      final input = [
        {
          'type': 'heading',
          'level': 2,
          'runs': [
            {'text': 'Chapter One'}
          ]
        }
      ];
      final result = roundTrip(input, type: DocBlockType.heading, level: 2);
      expect(result, hasLength(1));
      expect(result.single['type'], 'heading');
      expect(result.single['level'], 2);
      expect((result.single['runs'] as List).single['text'], 'Chapter One');
    });

    test('bullet list item round-trips', () {
      final input = [
        {
          'type': 'list_item',
          'list_type': 'bullet',
          'runs': [
            {'text': 'Item one'}
          ]
        }
      ];
      final result = roundTrip(input, type: DocBlockType.listItem);
      expect(result.single['type'], 'list_item');
      expect(result.single['list_type'], 'bullet');
    });

    test('numbered list item round-trips', () {
      final input = [
        {
          'type': 'list_item',
          'list_type': 'numbered',
          'runs': [
            {'text': 'Step one'}
          ]
        }
      ];
      final result = roundTrip(input, type: DocBlockType.listItem);
      expect(result.single['list_type'], 'numbered');
    });

    test('bold run round-trips', () {
      final input = [
        {
          'type': 'paragraph',
          'runs': [
            {'text': 'normal '},
            {'text': 'bold', 'bold': true},
            {'text': ' normal'}
          ]
        }
      ];
      final result = roundTrip(input);
      final runs = result.single['runs'] as List;
      expect(runs.length, 3);
      expect(runs[0]['text'], 'normal ');
      expect(runs[0].containsKey('bold'), isFalse);
      expect(runs[1]['text'], 'bold');
      expect(runs[1]['bold'], true);
      expect(runs[2]['text'], ' normal');
    });

    test('font_size round-trips as double', () {
      final input = [
        {
          'type': 'paragraph',
          'runs': [
            {'text': 'big', 'font_size': 24}
          ]
        }
      ];
      final result = roundTrip(input);
      final run = (result.single['runs'] as List).single;
      expect(run['font_size'], 24.0);
    });

    test('color round-trips normalized (# stripped, lowercase)', () {
      final input = [
        {
          'type': 'paragraph',
          'runs': [
            {'text': 'red', 'color': 'ff0000'}
          ]
        }
      ];
      final result = roundTrip(input);
      final run = (result.single['runs'] as List).single;
      expect(run['color'], 'ff0000');
    });

    test('font_family round-trips', () {
      final input = [
        {
          'type': 'paragraph',
          'runs': [
            {'text': 'serif', 'font_family': 'Times New Roman'}
          ]
        }
      ];
      final result = roundTrip(input);
      final run = (result.single['runs'] as List).single;
      expect(run['font_family'], 'Times New Roman');
    });

    test('multiple blocks preserve order', () {
      final input = [
        {
          'type': 'heading',
          'level': 1,
          'runs': [
            {'text': 'Title'}
          ]
        },
        {
          'type': 'paragraph',
          'runs': [
            {'text': 'Body text.'}
          ]
        },
      ];
      // Round-trip as heading first (first block inherits type).
      final doc = blockDictsToQuillDocument(input);
      final result = quillDocumentToBlockDicts(doc, DocBlockType.heading, 1);
      expect(result, hasLength(2));
      expect(result[0]['type'], 'heading');
      expect(result[0]['level'], 1);
      expect(result[1]['type'], 'paragraph');
    });

    test('alignment round-trips on paragraph', () {
      final input = [
        {
          'type': 'paragraph',
          'alignment': 'center',
          'runs': [
            {'text': 'Centered'}
          ]
        }
      ];
      final result = roundTrip(input);
      expect(result.single['alignment'], 'center');
    });
  });

  // ── quillDocumentToBlockDicts — Document-first ────────────────────────────

  group('quillDocumentToBlockDicts from Document', () {
    test('Quill Document with two paragraphs produces two blocks', () {
      final doc = quill.Document.fromJson([
        {'insert': 'First\nSecond\n'},
      ]);
      final result =
          quillDocumentToBlockDicts(doc, DocBlockType.paragraph, null);
      expect(result, hasLength(2));
      expect((result[0]['runs'] as List).single['text'], 'First');
      expect((result[1]['runs'] as List).single['text'], 'Second');
    });

    test('empty Quill Document produces one empty-paragraph block', () {
      final doc = quill.Document();
      final result =
          quillDocumentToBlockDicts(doc, DocBlockType.paragraph, null);
      expect(result, hasLength(1));
      expect(result.single['type'], 'paragraph');
    });
  });
}
