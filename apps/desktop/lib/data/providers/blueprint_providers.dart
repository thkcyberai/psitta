import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/blueprint.dart';
import '../models/blueprint_enums.dart';
import '../repositories/blueprint_repository.dart';
import 'project_providers.dart' show projectPlacementsProvider;
import 'providers.dart' show apiClientProvider;

/// Shared "field omitted" sentinel for the controller's PATCH-style mutations.
///
/// This is the canonical `const Object()` instance — the same value the
/// [BlueprintRepository] uses internally as its omit sentinel (Dart canonicalizes
/// `const Object()` to a single shared instance program-wide). Passing it through
/// to the repository therefore reads as "leave this field unchanged", while an
/// explicit `null` reads as "clear" and any other value as "set". This is the
/// data layer's omitted-field convention; see [BlueprintRepository.updatePart] /
/// [BlueprintRepository.updateBlueprint].
const Object _unset = Object();

// ── Repository ─────────────────────────────────────────────────────────────

/// The Blueprint repository over the shared [ApiClient] (mirrors the
/// repository providers in `providers.dart`).
final blueprintRepositoryProvider = Provider<BlueprintRepository>((ref) {
  return BlueprintRepository(ref.watch(apiClientProvider));
});

// ── Read providers ───────────────────────────────────────────────────────────
// Conventional autoDispose reads delegating to the repository (family where an
// id parameterizes the request), mirroring `documentsProvider` / `chunksProvider`.

/// `GET /blueprints/` — blueprints visible to the caller (system + own).
final blueprintsListProvider =
    FutureProvider.autoDispose<List<BlueprintSummary>>((ref) async {
  final repo = ref.watch(blueprintRepositoryProvider);
  return repo.listBlueprints();
});

/// `GET /blueprints/{id}` — one blueprint with its nested parts tree.
final blueprintDetailProvider = FutureProvider.autoDispose
    .family<BlueprintDetail, String>((ref, blueprintId) async {
  final repo = ref.watch(blueprintRepositoryProvider);
  return repo.getBlueprint(blueprintId);
});

/// `GET /projects/{id}/blueprints/` — blueprints adopted by a project.
final adoptedBlueprintsProvider = FutureProvider.autoDispose
    .family<List<AdoptedBlueprint>, String>((ref, projectId) async {
  final repo = ref.watch(blueprintRepositoryProvider);
  return repo.listAdoptedBlueprints(projectId);
});

/// `GET /projects/{id}/blueprint-overview/` — derived coherence overview.
final projectBlueprintOverviewProvider = FutureProvider.autoDispose
    .family<ProjectBlueprintOverview, String>((ref, projectId) async {
  final repo = ref.watch(blueprintRepositoryProvider);
  return repo.getProjectBlueprintOverview(projectId);
});

/// `GET /documents/{id}/placement` — the document's placement, or `null` when
/// it is unplaced.
///
/// The not-found case is interpreted HERE (not in the repository): the backend
/// returns 404 for an unplaced document, which this provider maps to `null`.
/// Keeping the status-code interpretation in the provider preserves the
/// repository's "let the ApiClient surface status codes" contract.
final documentPlacementProvider = FutureProvider.autoDispose
    .family<DocumentPlacement?, String>((ref, documentId) async {
  final repo = ref.watch(blueprintRepositoryProvider);
  try {
    return await repo.getPlacement(documentId);
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return null;
    rethrow;
  }
});

// ── Mutation controller ──────────────────────────────────────────────────────

/// The single mutation entry point for the Blueprint feature.
final blueprintActionsProvider = Provider<BlueprintActions>((ref) {
  return BlueprintActions(ref, ref.watch(blueprintRepositoryProvider));
});

/// Centralizes every Blueprint mutation together with its provider
/// invalidations (the C-hybrid design: conventional read providers + one thin
/// actions controller). No optimistic state — each method awaits the repository
/// call, invalidates exactly the affected read providers, then returns the
/// repository result.
///
/// Invalidation rule: where a concrete id is known, the specific family instance
/// is invalidated; where the affected set depends on which projects adopted a
/// blueprint (the adoption graph, which lives server-side), the WHOLE family is
/// invalidated rather than tracking adoptions client-side.
class BlueprintActions {
  BlueprintActions(this._ref, this._repo);

  final Ref _ref;
  final BlueprintRepository _repo;

  // ── Blueprints ─────────────────────────────────────────────────────────

  /// Create a new user-owned blueprint, then refresh the visible list.
  Future<BlueprintSummary> createBlueprint({
    required String name,
    required Genre genre,
    String? description,
    BlueprintStatus? status,
  }) async {
    final created = await _repo.createBlueprint(
      name: name,
      genre: genre,
      description: description,
      status: status,
    );
    // A new blueprint joins the visible list.
    _ref.invalidate(blueprintsListProvider);
    return created;
  }

  /// Clone a blueprint into a user-owned copy, then refresh the visible list.
  Future<BlueprintDetail> cloneBlueprint(String id, {String? name}) async {
    final clone = await _repo.cloneBlueprint(id, name: name);
    // The clone is a new user-owned blueprint in the visible list.
    _ref.invalidate(blueprintsListProvider);
    return clone;
  }

  /// Update a blueprint's fields. [description] is tri-state (omit ⇒ unchanged,
  /// `null` ⇒ clear, value ⇒ set); a null [genre]/[status]/[name] is left
  /// unchanged.
  Future<BlueprintSummary> updateBlueprint(
    String id, {
    String? name,
    Object? description = _unset,
    Genre? genre,
    BlueprintStatus? status,
  }) async {
    final updated = await _repo.updateBlueprint(
      id,
      name: name,
      description: description,
      genre: genre,
      status: status,
    );
    // The list row and the detail both change; every project that adopted this
    // blueprint sees updated summary/overview data — invalidate those whole
    // families (the adoption graph is server-side, not tracked here).
    _ref.invalidate(blueprintsListProvider);
    _ref.invalidate(blueprintDetailProvider(id));
    _ref.invalidate(adoptedBlueprintsProvider);
    _ref.invalidate(projectBlueprintOverviewProvider);
    return updated;
  }

  /// Delete a user blueprint (its parts cascade server-side).
  Future<void> deleteBlueprint(String id) async {
    await _repo.deleteBlueprint(id);
    // Gone from the list and its detail; any adopting project's adoptions and
    // overview change too (whole families).
    _ref.invalidate(blueprintsListProvider);
    _ref.invalidate(blueprintDetailProvider(id));
    _ref.invalidate(adoptedBlueprintsProvider);
    _ref.invalidate(projectBlueprintOverviewProvider);
  }

  // ── Parts ──────────────────────────────────────────────────────────────

  /// Add a part to a blueprint.
  Future<PartDetail> createPart(
    String blueprintId, {
    required String name,
    String? description,
    String? parentPartId,
    String? afterPartId,
  }) async {
    final part = await _repo.createPart(
      blueprintId,
      name: name,
      description: description,
      parentPartId: parentPartId,
      afterPartId: afterPartId,
    );
    _invalidateAfterPartChange(blueprintId);
    return part;
  }

  /// Edit and/or reorder/nest a part. [description]/[parentPartId]/[afterPartId]
  /// are tri-state (omit ⇒ unchanged, `null` ⇒ clear / move-to-root / first,
  /// value ⇒ set); see [BlueprintRepository.updatePart].
  Future<PartDetail> updatePart(
    String blueprintId,
    String partId, {
    String? name,
    Object? description = _unset,
    Object? parentPartId = _unset,
    Object? afterPartId = _unset,
  }) async {
    final part = await _repo.updatePart(
      blueprintId,
      partId,
      name: name,
      description: description,
      parentPartId: parentPartId,
      afterPartId: afterPartId,
    );
    _invalidateAfterPartChange(blueprintId);
    return part;
  }

  /// Delete a part (its subtree cascades server-side).
  Future<void> deletePart(String blueprintId, String partId) async {
    await _repo.deletePart(blueprintId, partId);
    _invalidateAfterPartChange(blueprintId);
  }

  /// A part change rewrites this blueprint's tree and shifts coherence for any
  /// project that adopted it (whole overview family).
  void _invalidateAfterPartChange(String blueprintId) {
    _ref.invalidate(blueprintDetailProvider(blueprintId));
    _ref.invalidate(projectBlueprintOverviewProvider);
  }

  // ── Project ↔ blueprint adoption ─────────────────────────────────────────

  /// Adopt a blueprint into a project. The first adoption is primary
  /// automatically; pass [isPrimary] true to adopt-as-primary.
  Future<AdoptedBlueprint> adoptBlueprint(
    String projectId,
    String blueprintId, {
    bool isPrimary = false,
  }) async {
    final adopted =
        await _repo.adoptBlueprint(projectId, blueprintId, isPrimary: isPrimary);
    _invalidateProjectAdoption(projectId);
    return adopted;
  }

  /// Set or clear which adopted blueprint is the project's primary. The backend
  /// route supports both (`is_primary` true ⇒ make primary swapping any
  /// existing; false ⇒ clear, leaving no primary — confirmed in
  /// `project_blueprints.py`), so the clear path is exposed via [isPrimary].
  Future<AdoptedBlueprint> setPrimaryBlueprint(
    String projectId,
    String blueprintId, {
    bool isPrimary = true,
  }) async {
    final adopted = await _repo.setPrimaryBlueprint(
      projectId,
      blueprintId,
      isPrimary: isPrimary,
    );
    _invalidateProjectAdoption(projectId);
    return adopted;
  }

  /// Un-adopt a blueprint from a project (link removal; the blueprint itself is
  /// untouched).
  Future<void> unadoptBlueprint(String projectId, String blueprintId) async {
    await _repo.unadoptBlueprint(projectId, blueprintId);
    _invalidateProjectAdoption(projectId);
  }

  /// Adoption changes are scoped to one known project.
  void _invalidateProjectAdoption(String projectId) {
    _ref.invalidate(adoptedBlueprintsProvider(projectId));
    _ref.invalidate(projectBlueprintOverviewProvider(projectId));
  }

  // ── Document placement ───────────────────────────────────────────────────

  /// Assign or move a document into a part. Pass [projectId] when known to scope
  /// the overview invalidation to that project; otherwise the whole overview
  /// family is invalidated (placement auto-adopts into the document's project).
  Future<DocumentPlacement> setPlacement(
    String documentId,
    String partId,
    Role role, {
    String? projectId,
  }) async {
    final placement = await _repo.setPlacement(documentId, partId, role);
    _invalidateOverviewFor(projectId);
    _ref.invalidate(documentPlacementProvider(documentId));
    return placement;
  }

  /// Un-place a document. [projectId] scopes the overview invalidation as in
  /// [setPlacement].
  Future<void> removePlacement(String documentId, {String? projectId}) async {
    await _repo.removePlacement(documentId);
    _invalidateOverviewFor(projectId);
    _ref.invalidate(documentPlacementProvider(documentId));
  }

  /// Invalidate the overview for a known project, else the whole family (the
  /// affected project may not be known to the caller).
  void _invalidateOverviewFor(String? projectId) {
    if (projectId != null) {
      _ref.invalidate(projectBlueprintOverviewProvider(projectId));
      _ref.invalidate(projectPlacementsProvider(projectId));
    } else {
      _ref.invalidate(projectBlueprintOverviewProvider);
      _ref.invalidate(projectPlacementsProvider);
    }
  }
}
