/// Immutable Dart models for the Blueprint API read/response surface.
///
/// Each class mirrors a Pydantic schema in
/// `core/backend/src/psitta/schemas/api.py` — field names and nullability match
/// the backend byte-for-byte (snake_case wire keys → camelCase Dart fields).
/// Backend `float` columns (e.g. `sort_order`, `ratio`) are `double` here.
///
/// Style follows the existing hand-written models (`document.dart`,
/// `psitta_document.dart`): `@immutable`, const constructors, `final` fields,
/// and explicit `fromJson` factories (no codegen). The four closed sets are
/// parsed through the value-carrying enums in `blueprint_enums.dart`.
///
/// This is the model + enum layer ONLY — no networking, repository, or
/// providers (those land in later slices).
library;

import 'package:flutter/foundation.dart';

import 'blueprint_enums.dart';

// ── Read surface ────────────────────────────────────────────────────────────

/// A blueprint without its parts — the list-view shape (`BlueprintSummary`).
@immutable
class BlueprintSummary {
  const BlueprintSummary({
    required this.id,
    required this.name,
    this.description,
    required this.genre,
    required this.status,
    required this.isSystem,
    this.sourceTemplateId,
    this.narrativeStructureKey,
    this.narrativeVariant,
  });

  factory BlueprintSummary.fromJson(Map<String, dynamic> json) =>
      BlueprintSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        genre: Genre.fromWire(json['genre'] as String),
        status: BlueprintStatus.fromWire(json['status'] as String),
        isSystem: json['is_system'] as bool,
        sourceTemplateId: json['source_template_id'] as String?,
        narrativeStructureKey: json['narrative_structure_key'] as String?,
        narrativeVariant: json['narrative_variant'] as String?,
      );

  final String id;
  final String name;
  final String? description;
  final Genre genre;
  final BlueprintStatus status;
  final bool isSystem;
  final String? sourceTemplateId;
  final String? narrativeStructureKey;
  final String? narrativeVariant;
}

/// A blueprint part and its nested children — the recursive read-tree node
/// (`PartNode`).
@immutable
class PartNode {
  const PartNode({
    required this.id,
    required this.name,
    this.description,
    required this.sortOrder,
    required this.children,
  });

  factory PartNode.fromJson(Map<String, dynamic> json) => PartNode(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        sortOrder: (json['sort_order'] as num).toDouble(),
        children: _partNodes(json['children']),
      );

  final String id;
  final String name;
  final String? description;
  final double sortOrder;
  final List<PartNode> children;
}

/// A blueprint plus its top-level parts as nested [PartNode] trees
/// (`BlueprintDetail`, which extends `BlueprintSummary` on the backend).
@immutable
class BlueprintDetail extends BlueprintSummary {
  const BlueprintDetail({
    required super.id,
    required super.name,
    super.description,
    required super.genre,
    required super.status,
    required super.isSystem,
    super.sourceTemplateId,
    super.narrativeStructureKey,
    super.narrativeVariant,
    required this.parts,
  });

  factory BlueprintDetail.fromJson(Map<String, dynamic> json) =>
      BlueprintDetail(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        genre: Genre.fromWire(json['genre'] as String),
        status: BlueprintStatus.fromWire(json['status'] as String),
        isSystem: json['is_system'] as bool,
        sourceTemplateId: json['source_template_id'] as String?,
        narrativeStructureKey: json['narrative_structure_key'] as String?,
        narrativeVariant: json['narrative_variant'] as String?,
        parts: _partNodes(json['parts']),
      );

  final List<PartNode> parts;
}

/// A single part, flat — the write-path response shape (`PartDetail`). Carries
/// `parentPartId` and `blueprintId` so a client can place the affected part
/// without re-reading the whole tree. Distinct from the nested [PartNode].
@immutable
class PartDetail {
  const PartDetail({
    required this.id,
    required this.blueprintId,
    this.parentPartId,
    required this.name,
    this.description,
    required this.sortOrder,
  });

  factory PartDetail.fromJson(Map<String, dynamic> json) => PartDetail(
        id: json['id'] as String,
        blueprintId: json['blueprint_id'] as String,
        parentPartId: json['parent_part_id'] as String?,
        name: json['name'] as String,
        description: json['description'] as String?,
        sortOrder: (json['sort_order'] as num).toDouble(),
      );

  final String id;
  final String blueprintId;
  final String? parentPartId;
  final String name;
  final String? description;
  final double sortOrder;
}

// ── Adoption surface ────────────────────────────────────────────────────────

/// A blueprint as adopted by a project — its summary plus adoption state
/// (`AdoptedBlueprint`, which extends `BlueprintSummary` on the backend).
@immutable
class AdoptedBlueprint extends BlueprintSummary {
  const AdoptedBlueprint({
    required super.id,
    required super.name,
    super.description,
    required super.genre,
    required super.status,
    required super.isSystem,
    super.sourceTemplateId,
    super.narrativeStructureKey,
    super.narrativeVariant,
    required this.isPrimary,
    required this.adoptedAt,
  });

  factory AdoptedBlueprint.fromJson(Map<String, dynamic> json) =>
      AdoptedBlueprint(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        genre: Genre.fromWire(json['genre'] as String),
        status: BlueprintStatus.fromWire(json['status'] as String),
        isSystem: json['is_system'] as bool,
        sourceTemplateId: json['source_template_id'] as String?,
        narrativeStructureKey: json['narrative_structure_key'] as String?,
        narrativeVariant: json['narrative_variant'] as String?,
        isPrimary: json['is_primary'] as bool,
        adoptedAt: DateTime.parse(json['adopted_at'] as String),
      );

  final bool isPrimary;
  final DateTime adoptedAt;
}

/// A document's placement in a part — the placement response shape
/// (`PartDocumentPlacement`). Carries `blueprintId` so the client can locate the
/// placement without re-reading the part's blueprint.
@immutable
class DocumentPlacement {
  const DocumentPlacement({
    required this.id,
    required this.documentId,
    required this.partId,
    required this.blueprintId,
    required this.role,
    required this.sortOrder,
  });

  factory DocumentPlacement.fromJson(Map<String, dynamic> json) =>
      DocumentPlacement(
        id: json['id'] as String,
        documentId: json['document_id'] as String,
        partId: json['part_id'] as String,
        blueprintId: json['blueprint_id'] as String,
        role: Role.fromWire(json['role'] as String),
        sortOrder: (json['sort_order'] as num).toDouble(),
      );

  final String id;
  final String documentId;
  final String partId;
  final String blueprintId;
  final Role role;
  final double sortOrder;
}

// ── Derived coherence overview (2G) ─────────────────────────────────────────

/// Leaf-based progress over a blueprint's parts, derived on read
/// (`ProgressInfo`). [ratio] is null when the blueprint has no leaves.
@immutable
class ProgressInfo {
  const ProgressInfo({
    required this.leavesWithContent,
    required this.totalLeaves,
    this.ratio,
  });

  factory ProgressInfo.fromJson(Map<String, dynamic> json) => ProgressInfo(
        leavesWithContent: json['leaves_with_content'] as int,
        totalLeaves: json['total_leaves'] as int,
        ratio: json['ratio'] == null ? null : (json['ratio'] as num).toDouble(),
      );

  final int leavesWithContent;
  final int totalLeaves;
  final double? ratio;
}

/// A part annotated with derived coherence values and its nested children
/// (`PartOverviewNode`). Everything here is computed on read, never stored.
@immutable
class PartOverviewNode {
  const PartOverviewNode({
    required this.id,
    required this.name,
    this.description,
    required this.sortOrder,
    required this.documentCount,
    required this.hasContent,
    required this.readiness,
    required this.children,
  });

  factory PartOverviewNode.fromJson(Map<String, dynamic> json) =>
      PartOverviewNode(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        sortOrder: (json['sort_order'] as num).toDouble(),
        documentCount: json['document_count'] as int,
        hasContent: json['has_content'] as bool,
        readiness: Readiness.fromWire(json['readiness'] as String),
        children: _partOverviewNodes(json['children']),
      );

  final String id;
  final String name;
  final String? description;
  final double sortOrder;
  final int documentCount;
  final bool hasContent;
  final Readiness readiness;
  final List<PartOverviewNode> children;
}

/// An adopted blueprint with its derived progress and annotated parts tree
/// (`BlueprintOverview`, which extends `AdoptedBlueprint` on the backend).
@immutable
class BlueprintOverview extends AdoptedBlueprint {
  const BlueprintOverview({
    required super.id,
    required super.name,
    super.description,
    required super.genre,
    required super.status,
    required super.isSystem,
    super.sourceTemplateId,
    super.narrativeStructureKey,
    super.narrativeVariant,
    required super.isPrimary,
    required super.adoptedAt,
    required this.progress,
    required this.parts,
  });

  factory BlueprintOverview.fromJson(Map<String, dynamic> json) =>
      BlueprintOverview(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        genre: Genre.fromWire(json['genre'] as String),
        status: BlueprintStatus.fromWire(json['status'] as String),
        isSystem: json['is_system'] as bool,
        sourceTemplateId: json['source_template_id'] as String?,
        narrativeStructureKey: json['narrative_structure_key'] as String?,
        narrativeVariant: json['narrative_variant'] as String?,
        isPrimary: json['is_primary'] as bool,
        adoptedAt: DateTime.parse(json['adopted_at'] as String),
        progress:
            ProgressInfo.fromJson(json['progress'] as Map<String, dynamic>),
        parts: _partOverviewNodes(json['parts']),
      );

  final ProgressInfo progress;
  final List<PartOverviewNode> parts;
}

/// The derived coherence overview for a project (`ProjectBlueprintOverview`).
/// [progress] is the primary blueprint's progress, or null when the project has
/// no primary (including the no-adoptions case, where [blueprints] is empty).
@immutable
class ProjectBlueprintOverview {
  const ProjectBlueprintOverview({
    this.progress,
    required this.blueprints,
  });

  factory ProjectBlueprintOverview.fromJson(Map<String, dynamic> json) =>
      ProjectBlueprintOverview(
        progress: json['progress'] == null
            ? null
            : ProgressInfo.fromJson(json['progress'] as Map<String, dynamic>),
        blueprints: (json['blueprints'] as List<dynamic>? ?? const [])
            .map((e) => BlueprintOverview.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );

  final ProgressInfo? progress;
  final List<BlueprintOverview> blueprints;
}

// ── Recursive list helpers ──────────────────────────────────────────────────

List<PartNode> _partNodes(Object? raw) =>
    (raw as List<dynamic>? ?? const [])
        .map((e) => PartNode.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

List<PartOverviewNode> _partOverviewNodes(Object? raw) =>
    (raw as List<dynamic>? ?? const [])
        .map((e) => PartOverviewNode.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
