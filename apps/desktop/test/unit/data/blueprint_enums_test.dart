// Unit tests for the Blueprint value-carrying enums.
//
// Asserts that every variant's `wire` string matches the backend controlled
// list byte-for-byte (source of truth: core/backend/src/psitta/schemas/api.py —
// GenreEnum, BlueprintStatusEnum, RoleEnum, ReadinessEnum), that `fromWire`
// round-trips every real string, and that an unrecognized string falls back to
// the `unknown` sentinel WITHOUT throwing (forward-compatibility contract).
import 'package:flutter_test/flutter_test.dart';
import 'package:psitta/data/models/blueprint_enums.dart';

void main() {
  group('Genre', () {
    // Byte-for-byte from GenreEnum (note the single apostrophe).
    const expected = <String, Genre>{
      'Novel': Genre.novel,
      'Memoir': Genre.memoir,
      'Non-Fiction': Genre.nonFiction,
      'Biography': Genre.biography,
      'Research Paper': Genre.researchPaper,
      "Children's Picture Book": Genre.childrensPictureBook,
      'Screenplay': Genre.screenplay,
      'Workbook/How-To': Genre.workbookHowTo,
      'Business Book': Genre.businessBook,
      'Short Story Collection': Genre.shortStoryCollection,
    };

    test('every wire string round-trips through fromWire', () {
      expected.forEach((wire, variant) {
        expect(Genre.fromWire(wire), variant, reason: 'fromWire($wire)');
        expect(variant.wire, wire, reason: '${variant.name}.wire');
      });
    });

    test('covers all ten backend genres', () {
      expect(expected.length, 10);
    });

    test('unrecognized string falls back to unknown without throwing', () {
      expect(Genre.fromWire('Cookbook'), Genre.unknown);
      expect(Genre.fromWire(''), Genre.unknown);
      expect(Genre.fromWire('novel'), Genre.unknown); // case-sensitive
    });
  });

  group('BlueprintStatus', () {
    const expected = <String, BlueprintStatus>{
      'Draft': BlueprintStatus.draft,
      'Completed': BlueprintStatus.completed,
      'Archived': BlueprintStatus.archived,
    };

    test('every wire string round-trips through fromWire', () {
      expected.forEach((wire, variant) {
        expect(BlueprintStatus.fromWire(wire), variant);
        expect(variant.wire, wire);
      });
    });

    test('unrecognized string falls back to unknown without throwing', () {
      expect(BlueprintStatus.fromWire('Published'), BlueprintStatus.unknown);
      expect(BlueprintStatus.fromWire('draft'), BlueprintStatus.unknown);
    });
  });

  group('Role', () {
    const expected = <String, Role>{
      'Main Content': Role.mainContent,
      'Supporting Content': Role.supportingContent,
      'Research': Role.research,
      'Notes': Role.notes,
      'Reference Material': Role.referenceMaterial,
    };

    test('every wire string round-trips through fromWire', () {
      expected.forEach((wire, variant) {
        expect(Role.fromWire(wire), variant);
        expect(variant.wire, wire);
      });
    });

    test('unrecognized string falls back to unknown without throwing', () {
      expect(Role.fromWire('Appendix'), Role.unknown);
      expect(Role.fromWire('main content'), Role.unknown);
    });
  });

  group('Readiness', () {
    const expected = <String, Readiness>{
      'empty': Readiness.empty,
      'in_progress': Readiness.inProgress,
      'ready': Readiness.ready,
    };

    test('every wire string round-trips through fromWire', () {
      expected.forEach((wire, variant) {
        expect(Readiness.fromWire(wire), variant);
        expect(variant.wire, wire);
      });
    });

    test('unrecognized string falls back to unknown without throwing', () {
      expect(Readiness.fromWire('blocked'), Readiness.unknown);
      expect(Readiness.fromWire('In_Progress'), Readiness.unknown);
    });
  });
}
