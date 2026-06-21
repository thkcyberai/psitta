import '../api/api_client.dart';
import '../models/blueprint.dart';
import '../models/blueprint_enums.dart';

/// Sentinel for "field not provided" in PATCH-style updates, so callers can
/// distinguish *omit* (leave unchanged) from an explicit *null* (clear) on
/// nullable fields. Mirrors the backend's `model_fields_set` / `exclude_unset`
/// presence semantics (see `PartUpdate` / `BlueprintUpdate` in
/// `core/backend/src/psitta/schemas/api.py`): present-and-null and absent are
/// distinct intents on the wire.
const Object _unset = Object();

/// Blueprint repository — API communication for the Blueprint feature.
///
/// One repository over the full backend surface (read, write, parts, project
/// adoption, document placement, derived overview). Mirrors
/// [DocumentRepository] / [ProjectRepository]: constructed with the shared
/// [ApiClient] (which attaches the Cognito JWT and owns 401 refresh/retry), all
/// calls go through `_api.dio`, and errors are left to propagate from Dio — the
/// caller (the 3c controller) decides how to react to status codes; this layer
/// does not branch business logic on them.
///
/// Routes, bodies, and response shapes follow the backend exactly
/// (`api/v1/blueprints.py`, `api/v1/project_blueprints.py`). Trailing slashes
/// match the backend route declarations to avoid 307 redirects.
class BlueprintRepository {
  BlueprintRepository(this._api);

  final ApiClient _api;

  // ── Blueprints ─────────────────────────────────────────────────────────

  /// `GET /blueprints/` — list blueprints visible to the caller (system
  /// templates + the caller's own), as summaries.
  Future<List<BlueprintSummary>> listBlueprints() async {
    final response = await _api.dio.get('/blueprints/');
    return (response.data as List)
        .map((e) => BlueprintSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /blueprints/{id}` — one visible blueprint with its nested parts tree.
  Future<BlueprintDetail> getBlueprint(String id) async {
    final response = await _api.dio.get('/blueprints/$id');
    return BlueprintDetail.fromJson(response.data as Map<String, dynamic>);
  }

  /// `POST /blueprints/` — create a new, empty user-owned blueprint.
  ///
  /// Returns the created blueprint (the backend responds with a
  /// [BlueprintSummary]). Throws [ArgumentError] before any request if [genre]
  /// or [status] is the read-only `unknown` sentinel.
  Future<BlueprintSummary> createBlueprint({
    required String name,
    required Genre genre,
    String? description,
    BlueprintStatus? status,
    String? narrativeStructureKey,
    String? narrativeVariant,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'genre': _genreToWire(genre),
    };
    if (description != null) body['description'] = description;
    if (status != null) body['status'] = _statusToWire(status);
    if (narrativeStructureKey != null) {
      body['narrative_structure_key'] = narrativeStructureKey;
    }
    if (narrativeVariant != null) body['narrative_variant'] = narrativeVariant;
    final response = await _api.dio.post('/blueprints/', data: body);
    return BlueprintSummary.fromJson(response.data as Map<String, dynamic>);
  }

  /// `POST /blueprints/{id}/clone/` — clone a visible blueprint (system or own)
  /// into a user-owned copy, returning the full detail (with cloned parts). An
  /// optional [name] overrides the source name.
  Future<BlueprintDetail> cloneBlueprint(String id, {String? name}) async {
    final body = name == null ? null : {'name': name};
    final response = await _api.dio.post('/blueprints/$id/clone/', data: body);
    return BlueprintDetail.fromJson(response.data as Map<String, dynamic>);
  }

  /// `PATCH /blueprints/{id}` — partial update of a user blueprint. Returns the
  /// updated blueprint (a [BlueprintSummary]).
  ///
  /// Presence drives intent: a null [name] / [genre] / [status] is omitted
  /// (left unchanged). [description] is tri-state — omit to leave unchanged,
  /// pass `null` to clear it, pass a string to set it. Throws [ArgumentError]
  /// before any request if [genre] or [status] is the `unknown` sentinel.
  Future<BlueprintSummary> updateBlueprint(
    String id, {
    String? name,
    Object? description = _unset,
    Genre? genre,
    BlueprintStatus? status,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (!identical(description, _unset)) body['description'] = description;
    if (genre != null) body['genre'] = _genreToWire(genre);
    if (status != null) body['status'] = _statusToWire(status);
    final response = await _api.dio.patch('/blueprints/$id', data: body);
    return BlueprintSummary.fromJson(response.data as Map<String, dynamic>);
  }

  /// `DELETE /blueprints/{id}` — delete a user blueprint (parts cascade).
  Future<void> deleteBlueprint(String id) async {
    await _api.dio.delete('/blueprints/$id');
  }

  // ── Parts ──────────────────────────────────────────────────────────────

  /// `POST /blueprints/{blueprintId}/parts/` — add a part. A null
  /// [parentPartId] creates a root part; a null [afterPartId] places it first
  /// under the resolved parent (these match the backend's create defaults, so
  /// nulls are simply omitted).
  Future<PartDetail> createPart(
    String blueprintId, {
    required String name,
    String? description,
    String? parentPartId,
    String? afterPartId,
  }) async {
    final body = <String, dynamic>{'name': name};
    if (description != null) body['description'] = description;
    if (parentPartId != null) body['parent_part_id'] = parentPartId;
    if (afterPartId != null) body['after_part_id'] = afterPartId;
    final response =
        await _api.dio.post('/blueprints/$blueprintId/parts/', data: body);
    return PartDetail.fromJson(response.data as Map<String, dynamic>);
  }

  /// `PATCH /blueprints/{blueprintId}/parts/{partId}` — edit fields and/or
  /// reorder/nest a part.
  ///
  /// Tri-state semantics mirror the backend's `PartUpdate` (presence, not
  /// value, drives intent):
  ///   - [name]: null ⇒ unchanged; a string ⇒ rename.
  ///   - [description]: omit ⇒ unchanged; `null` ⇒ clear; a string ⇒ set.
  ///   - [parentPartId]: omit ⇒ parent unchanged; `null` ⇒ move to root; a
  ///     string ⇒ reparent under that part.
  ///   - [afterPartId]: omit ⇒ position unchanged (append on reparent); `null`
  ///     ⇒ first under the resolved parent; a string ⇒ after that sibling.
  Future<PartDetail> updatePart(
    String blueprintId,
    String partId, {
    String? name,
    Object? description = _unset,
    Object? parentPartId = _unset,
    Object? afterPartId = _unset,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (!identical(description, _unset)) body['description'] = description;
    if (!identical(parentPartId, _unset)) body['parent_part_id'] = parentPartId;
    if (!identical(afterPartId, _unset)) body['after_part_id'] = afterPartId;
    final response = await _api.dio
        .patch('/blueprints/$blueprintId/parts/$partId', data: body);
    return PartDetail.fromJson(response.data as Map<String, dynamic>);
  }

  /// `DELETE /blueprints/{blueprintId}/parts/{partId}` — delete a part; its
  /// subtree cascades at the database.
  Future<void> deletePart(String blueprintId, String partId) async {
    await _api.dio.delete('/blueprints/$blueprintId/parts/$partId');
  }

  // ── Project ↔ blueprint adoption ─────────────────────────────────────────

  /// `GET /projects/{projectId}/blueprints/` — list the blueprints adopted by a
  /// project (primary-first).
  Future<List<AdoptedBlueprint>> listAdoptedBlueprints(String projectId) async {
    final response = await _api.dio.get('/projects/$projectId/blueprints/');
    return (response.data as List)
        .map((e) => AdoptedBlueprint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /projects/{projectId}/blueprints/` — adopt a user-owned blueprint
  /// into a project. The first adoption is primary automatically; pass
  /// [isPrimary] true to adopt-as-primary (swapping any existing primary).
  Future<AdoptedBlueprint> adoptBlueprint(
    String projectId,
    String blueprintId, {
    bool isPrimary = false,
  }) async {
    final body = <String, dynamic>{'blueprint_id': blueprintId};
    if (isPrimary) body['is_primary'] = true;
    final response =
        await _api.dio.post('/projects/$projectId/blueprints/', data: body);
    return AdoptedBlueprint.fromJson(response.data as Map<String, dynamic>);
  }

  /// `PATCH /projects/{projectId}/blueprints/{blueprintId}` — set or clear which
  /// adopted blueprint is the project's primary. Returns the updated adoption.
  /// [isPrimary] true makes this the primary (clearing any existing primary);
  /// false clears this row's primary flag (no auto-promotion).
  Future<AdoptedBlueprint> setPrimaryBlueprint(
    String projectId,
    String blueprintId, {
    bool isPrimary = true,
  }) async {
    final response = await _api.dio.patch(
      '/projects/$projectId/blueprints/$blueprintId',
      data: {'is_primary': isPrimary},
    );
    return AdoptedBlueprint.fromJson(response.data as Map<String, dynamic>);
  }

  /// `DELETE /projects/{projectId}/blueprints/{blueprintId}` — un-adopt a
  /// blueprint from a project (plain link removal; never un-adopts the
  /// blueprint itself).
  Future<void> unadoptBlueprint(String projectId, String blueprintId) async {
    await _api.dio.delete('/projects/$projectId/blueprints/$blueprintId');
  }

  // ── Document placement ───────────────────────────────────────────────────

  /// `PUT /documents/{documentId}/placement` — assign or move a document into a
  /// part (idempotent), auto-adopting the part's blueprint into the project.
  /// Throws [ArgumentError] before any request if [role] is the `unknown`
  /// sentinel.
  Future<DocumentPlacement> setPlacement(
    String documentId,
    String partId,
    Role role,
  ) async {
    final response = await _api.dio.put(
      '/documents/$documentId/placement',
      data: {'part_id': partId, 'role': _roleToWire(role)},
    );
    return DocumentPlacement.fromJson(response.data as Map<String, dynamic>);
  }

  /// `GET /documents/{documentId}/placement` — the document's current
  /// placement.
  Future<DocumentPlacement> getPlacement(String documentId) async {
    final response = await _api.dio.get('/documents/$documentId/placement');
    return DocumentPlacement.fromJson(response.data as Map<String, dynamic>);
  }

  /// `DELETE /documents/{documentId}/placement` — un-place a document (remove
  /// its placement row). Never auto-un-adopts the blueprint.
  Future<void> removePlacement(String documentId) async {
    await _api.dio.delete('/documents/$documentId/placement');
  }

  // ── Derived overview ─────────────────────────────────────────────────────

  /// `GET /projects/{projectId}/blueprint-overview/` — the derived, read-only
  /// coherence overview for a project's adopted blueprints.
  Future<ProjectBlueprintOverview> getProjectBlueprintOverview(
    String projectId,
  ) async {
    final response =
        await _api.dio.get('/projects/$projectId/blueprint-overview/');
    return ProjectBlueprintOverview.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}

// ── Write-side enum serialization guards ───────────────────────────────────
// Reads may receive and hold the `unknown` sentinel (forward-compat); writes
// must never emit it — the backend CHECK constraints would reject it. Fail fast
// client-side with a clear error instead of issuing a doomed request.

String _genreToWire(Genre genre) {
  if (genre == Genre.unknown) {
    throw ArgumentError.value(
      genre,
      'genre',
      'Cannot send Genre.unknown to the backend; it is a read-only '
          'forward-compatibility sentinel and would violate the genre CHECK '
          'constraint.',
    );
  }
  return genre.wire;
}

String _statusToWire(BlueprintStatus status) {
  if (status == BlueprintStatus.unknown) {
    throw ArgumentError.value(
      status,
      'status',
      'Cannot send BlueprintStatus.unknown to the backend; it is a read-only '
          'forward-compatibility sentinel and would violate the status CHECK '
          'constraint.',
    );
  }
  return status.wire;
}

String _roleToWire(Role role) {
  if (role == Role.unknown) {
    throw ArgumentError.value(
      role,
      'role',
      'Cannot send Role.unknown to the backend; it is a read-only '
          'forward-compatibility sentinel and would violate the role CHECK '
          'constraint.',
    );
  }
  return role.wire;
}
