// Golden-fixture round-trip parse tests for the Blueprint models.
//
// Fixtures are derived from the backend schemas
// (core/backend/src/psitta/schemas/api.py) and the concrete payload shapes
// asserted by the backend integration tests, NOT hand-invented:
//   - BlueprintDetail nested tree  -> test_blueprint_api.py (Novel seed: 5 roots,
//     Front Matter + Back Matter each 2 children, 9 nodes total)
//   - clone response               -> test_blueprint_write_api.py (is_system
//     false, source_template_id set, status Draft)
//   - ProjectBlueprintOverview     -> test_blueprint_overview_api.py (all three
//     readiness states, 2/4 leaves, ratio 0.5, primary flag)
//   - AdoptedBlueprint             -> test_project_blueprint_api.py (first adopt
//     is primary)
//   - PartDetail                   -> test_blueprint_part_api.py (create/nest)
//   - DocumentPlacement            -> PartDocumentPlacement schema (2F)
//
// JSON is decoded via dart:convert so the value types match what the wire
// actually delivers (int / double / bool / null / List / Map).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:psitta/data/models/blueprint.dart';
import 'package:psitta/data/models/blueprint_enums.dart';

int _countPartNodes(List<PartNode> nodes) =>
    nodes.fold(0, (sum, n) => sum + 1 + _countPartNodes(n.children));

PartNode _findPart(List<PartNode> nodes, String name) =>
    nodes.firstWhere((n) => n.name == name);

PartOverviewNode _findOverview(List<PartOverviewNode> nodes, String name) =>
    nodes.firstWhere((n) => n.name == name);

void main() {
  group('BlueprintDetail', () {
    const novelJson = '''
    {
      "id": "5eed0001-0000-4000-8000-000000000001",
      "name": "Novel",
      "description": "A long-form fictional narrative.",
      "genre": "Novel",
      "status": "Draft",
      "is_system": true,
      "source_template_id": null,
      "parts": [
        {"id": "11111111-0000-4000-8000-000000000001", "name": "Front Matter",
         "description": null, "sort_order": 1000.0, "children": [
           {"id": "11111111-0000-4000-8000-0000000000a1", "name": "Title Page",
            "description": null, "sort_order": 1000.0, "children": []},
           {"id": "11111111-0000-4000-8000-0000000000a2", "name": "Dedication",
            "description": null, "sort_order": 2000.0, "children": []}
         ]},
        {"id": "11111111-0000-4000-8000-000000000002", "name": "Act I",
         "description": null, "sort_order": 2000.0, "children": []},
        {"id": "11111111-0000-4000-8000-000000000003", "name": "Act II",
         "description": null, "sort_order": 3000.0, "children": []},
        {"id": "11111111-0000-4000-8000-000000000004", "name": "Act III",
         "description": null, "sort_order": 4000.0, "children": []},
        {"id": "11111111-0000-4000-8000-000000000005", "name": "Back Matter",
         "description": null, "sort_order": 5000.0, "children": [
           {"id": "11111111-0000-4000-8000-0000000000b1", "name": "Epilogue",
            "description": null, "sort_order": 1000.0, "children": []},
           {"id": "11111111-0000-4000-8000-0000000000b2",
            "name": "Acknowledgments",
            "description": null, "sort_order": 2000.0, "children": []}
         ]}
      ]
    }
    ''';

    test('parses summary fields and the nested multi-level tree', () {
      final detail = BlueprintDetail.fromJson(
        jsonDecode(novelJson) as Map<String, dynamic>,
      );

      expect(detail.id, '5eed0001-0000-4000-8000-000000000001');
      expect(detail.name, 'Novel');
      expect(detail.description, 'A long-form fictional narrative.');
      expect(detail.genre, Genre.novel);
      expect(detail.status, BlueprintStatus.draft);
      expect(detail.isSystem, isTrue);
      expect(detail.sourceTemplateId, isNull);

      // 5 top-level parts; Front Matter + Back Matter each carry 2 children.
      expect(detail.parts.length, 5);
      expect(_findPart(detail.parts, 'Front Matter').children.length, 2);
      expect(_findPart(detail.parts, 'Back Matter').children.length, 2);

      // 5 roots + 2 + 2 nested = 9 nodes total.
      expect(_countPartNodes(detail.parts), 9);

      // Top-level parts arrive in ascending sort_order, typed as double.
      final orders = detail.parts.map((p) => p.sortOrder).toList();
      expect(orders, List<double>.from(orders)..sort());
      expect(detail.parts.first.sortOrder, 1000.0);
      expect(detail.parts.first.sortOrder, isA<double>());

      // A grandchild is reachable through the recursive children lists.
      final titlePage =
          _findPart(_findPart(detail.parts, 'Front Matter').children, 'Title Page');
      expect(titlePage.children, isEmpty);
    });

    test('parses a clone response (user-owned, source_template_id set)', () {
      const cloneJson = '''
      {
        "id": "22222222-0000-4000-8000-000000000001",
        "name": "Novel",
        "description": null,
        "genre": "Novel",
        "status": "Draft",
        "is_system": false,
        "source_template_id": "5eed0001-0000-4000-8000-000000000001",
        "parts": []
      }
      ''';

      final clone = BlueprintDetail.fromJson(
        jsonDecode(cloneJson) as Map<String, dynamic>,
      );

      expect(clone.isSystem, isFalse);
      expect(clone.sourceTemplateId, '5eed0001-0000-4000-8000-000000000001');
      expect(clone.status, BlueprintStatus.draft);
      expect(clone.parts, isEmpty);
    });
  });

  group('ProjectBlueprintOverview', () {
    const overviewJson = '''
    {
      "progress": {"leaves_with_content": 2, "total_leaves": 4, "ratio": 0.5},
      "blueprints": [
        {
          "id": "33333333-0000-4000-8000-000000000001",
          "name": "Nested",
          "description": null,
          "genre": "Novel",
          "status": "Draft",
          "is_system": false,
          "source_template_id": null,
          "is_primary": true,
          "adopted_at": "2026-06-08T12:00:00Z",
          "progress": {"leaves_with_content": 2, "total_leaves": 4, "ratio": 0.5},
          "parts": [
            {"id": "a1", "name": "Act I", "description": null, "sort_order": 1000.0,
             "document_count": 0, "has_content": false, "readiness": "in_progress",
             "children": [
               {"id": "c1", "name": "Ch 1", "description": null, "sort_order": 1000.0,
                "document_count": 1, "has_content": true, "readiness": "ready",
                "children": []},
               {"id": "c2", "name": "Ch 2", "description": null, "sort_order": 2000.0,
                "document_count": 0, "has_content": false, "readiness": "empty",
                "children": []}
             ]},
            {"id": "a2", "name": "Act II", "description": null, "sort_order": 2000.0,
             "document_count": 0, "has_content": false, "readiness": "ready",
             "children": [
               {"id": "c3", "name": "Ch 3", "description": null, "sort_order": 1000.0,
                "document_count": 1, "has_content": true, "readiness": "ready",
                "children": []}
             ]},
            {"id": "a3", "name": "Act III", "description": null, "sort_order": 3000.0,
             "document_count": 0, "has_content": false, "readiness": "empty",
             "children": []}
          ]
        }
      ]
    }
    ''';

    test('parses project progress, the adopted blueprint, and all three '
        'readiness states', () {
      final overview = ProjectBlueprintOverview.fromJson(
        jsonDecode(overviewJson) as Map<String, dynamic>,
      );

      // Project-level progress == primary blueprint progress (2/4 leaves).
      expect(overview.progress, isNotNull);
      expect(overview.progress!.leavesWithContent, 2);
      expect(overview.progress!.totalLeaves, 4);
      expect(overview.progress!.ratio, 0.5);

      expect(overview.blueprints.length, 1);
      final bp = overview.blueprints.single;

      // AdoptedBlueprint summary + adoption state carried through inheritance.
      expect(bp.isPrimary, isTrue);
      expect(bp.genre, Genre.novel);
      expect(bp.isSystem, isFalse);
      expect(bp.adoptedAt, DateTime.utc(2026, 6, 8, 12));
      expect(bp.progress.ratio, 0.5);

      final act1 = _findOverview(bp.parts, 'Act I');
      final act2 = _findOverview(bp.parts, 'Act II');
      final act3 = _findOverview(bp.parts, 'Act III');

      // in_progress container with one ready + one empty leaf.
      expect(act1.readiness, Readiness.inProgress);
      final ch1 = _findOverview(act1.children, 'Ch 1');
      expect(ch1.readiness, Readiness.ready);
      expect(ch1.documentCount, 1);
      expect(ch1.hasContent, isTrue);
      expect(ch1.sortOrder, isA<double>());

      final ch2 = _findOverview(act1.children, 'Ch 2');
      expect(ch2.readiness, Readiness.empty);
      expect(ch2.documentCount, 0);
      expect(ch2.hasContent, isFalse);

      // ready container.
      expect(act2.readiness, Readiness.ready);
      expect(_findOverview(act2.children, 'Ch 3').documentCount, 1);

      // empty leaf.
      expect(act3.readiness, Readiness.empty);
      expect(act3.documentCount, 0);
      expect(act3.children, isEmpty);
    });

    test('parses the empty-project case (null progress, no blueprints)', () {
      const emptyJson = '{"progress": null, "blueprints": []}';
      final overview = ProjectBlueprintOverview.fromJson(
        jsonDecode(emptyJson) as Map<String, dynamic>,
      );
      expect(overview.progress, isNull);
      expect(overview.blueprints, isEmpty);
    });
  });

  group('AdoptedBlueprint', () {
    test('parses summary fields plus is_primary and adopted_at', () {
      const json = '''
      {
        "id": "44444444-0000-4000-8000-000000000001",
        "name": "Solo",
        "description": null,
        "genre": "Memoir",
        "status": "Draft",
        "is_system": false,
        "source_template_id": null,
        "is_primary": true,
        "adopted_at": "2026-06-08T09:30:00Z"
      }
      ''';

      final adopted =
          AdoptedBlueprint.fromJson(jsonDecode(json) as Map<String, dynamic>);

      expect(adopted.id, '44444444-0000-4000-8000-000000000001');
      expect(adopted.name, 'Solo');
      expect(adopted.genre, Genre.memoir);
      expect(adopted.status, BlueprintStatus.draft);
      expect(adopted.isSystem, isFalse);
      expect(adopted.isPrimary, isTrue);
      expect(adopted.adoptedAt, DateTime.utc(2026, 6, 8, 9, 30));
    });
  });

  group('PartDetail', () {
    test('parses a root part (parent_part_id null)', () {
      const json = '''
      {
        "id": "55555555-0000-4000-8000-000000000001",
        "blueprint_id": "55555555-0000-4000-8000-0000000000bp",
        "parent_part_id": null,
        "name": "A",
        "description": null,
        "sort_order": 1000.0
      }
      ''';

      final part = PartDetail.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(part.id, '55555555-0000-4000-8000-000000000001');
      expect(part.blueprintId, '55555555-0000-4000-8000-0000000000bp');
      expect(part.parentPartId, isNull);
      expect(part.name, 'A');
      expect(part.sortOrder, 1000.0);
      expect(part.sortOrder, isA<double>());
    });

    test('parses a nested part (parent_part_id set, midpoint sort_order)', () {
      const json = '''
      {
        "id": "55555555-0000-4000-8000-000000000002",
        "blueprint_id": "55555555-0000-4000-8000-0000000000bp",
        "parent_part_id": "55555555-0000-4000-8000-000000000001",
        "name": "Child",
        "description": "nested",
        "sort_order": 1500.0
      }
      ''';

      final part = PartDetail.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(part.parentPartId, '55555555-0000-4000-8000-000000000001');
      expect(part.description, 'nested');
      expect(part.sortOrder, 1500.0);
    });
  });

  group('DocumentPlacement', () {
    test('parses the placement response with role and blueprint_id', () {
      const json = '''
      {
        "id": "66666666-0000-4000-8000-000000000001",
        "document_id": "66666666-0000-4000-8000-0000000000d0",
        "part_id": "66666666-0000-4000-8000-0000000000p0",
        "blueprint_id": "66666666-0000-4000-8000-0000000000bp",
        "role": "Main Content",
        "sort_order": 1000.0
      }
      ''';

      final placement =
          DocumentPlacement.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(placement.id, '66666666-0000-4000-8000-000000000001');
      expect(placement.documentId, '66666666-0000-4000-8000-0000000000d0');
      expect(placement.partId, '66666666-0000-4000-8000-0000000000p0');
      expect(placement.blueprintId, '66666666-0000-4000-8000-0000000000bp');
      expect(placement.role, Role.mainContent);
      expect(placement.sortOrder, 1000.0);
    });
  });
}
