/// Project read models for the Phase 5 Project screen.
///
/// Mirror the backend response schemas (`core/backend/src/psitta/schemas/api.py`
/// — `ProjectDetail`, `ProjectPlacement`; `api/v1/projects.py`). Plain immutable
/// classes with `fromJson`, matching the existing `Project` / `Document` model
/// style (snake_case wire → camelCase Dart).
library;

import 'blueprint_enums.dart' show Role;

/// Aggregated detail for one project (`GET /projects/{id}`). Counts/words cover
/// non-deleted documents; `totalWords` is 0 when the project has none.
class ProjectDetail {
  const ProjectDetail({
    required this.id,
    required this.name,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    required this.documentCount,
    required this.blueprintCount,
    required this.totalWords,
    this.narrativeStructureKey,
    this.narrativeVariant,
    this.narrativeBeats,
  });

  factory ProjectDetail.fromJson(Map<String, dynamic> json) => ProjectDetail(
        id: json['id'] as String,
        name: json['name'] as String,
        userId: json['user_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        documentCount: (json['document_count'] as num).toInt(),
        blueprintCount: (json['blueprint_count'] as num).toInt(),
        totalWords: (json['total_words'] as num).toInt(),
        narrativeStructureKey: json['narrative_structure_key'] as String?,
        narrativeVariant: json['narrative_variant'] as String?,
        narrativeBeats: (json['narrative_beats'] as List?)
            ?.map((e) => e as String)
            .toList(),
      );

  final String id;
  final String name;

  /// Owner user id (the current user; surfaced as "You" in the UI).
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Non-deleted documents in the project.
  final int documentCount;

  /// Adopted blueprints.
  final int blueprintCount;

  /// Sum of word_count over non-deleted documents.
  final int totalWords;

  /// The project's chosen narrative — NULL until the writer attaches one.
  final String? narrativeStructureKey;
  final String? narrativeVariant;
  final List<String>? narrativeBeats;
}

/// A document's placement within an adopted blueprint's part
/// (`GET /projects/{id}/placements`). Carries the blueprint and part (section)
/// names so the client need not re-read the tree.
class ProjectPlacement {
  const ProjectPlacement({
    required this.documentId,
    required this.blueprintId,
    required this.partId,
    required this.blueprintName,
    required this.partName,
    required this.role,
    required this.sortOrder,
  });

  factory ProjectPlacement.fromJson(Map<String, dynamic> json) =>
      ProjectPlacement(
        documentId: json['document_id'] as String,
        blueprintId: json['blueprint_id'] as String,
        partId: json['part_id'] as String,
        blueprintName: json['blueprint_name'] as String,
        partName: json['part_name'] as String,
        role: Role.fromWire(json['role'] as String),
        sortOrder: (json['sort_order'] as num).toDouble(),
      );

  final String documentId;
  final String blueprintId;
  final String partId;
  final String blueprintName;
  final String partName;

  /// Part-document role — e.g. [Role.mainContent].
  final Role role;

  /// Ordering position within the part (gapped NUMERIC, first append = 1000.0).
  final double sortOrder;
}
