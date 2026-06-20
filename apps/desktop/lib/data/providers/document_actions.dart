import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/document.dart';
import '../repositories/document_repository.dart';
import 'blueprint_providers.dart'
    show documentPlacementProvider, projectBlueprintOverviewProvider;
import 'project_providers.dart'
    show
        projectDetailProvider,
        projectDocumentsProvider,
        projectPlacementsProvider;
import 'providers.dart'
    show
        archivedDocumentsProvider,
        documentRepositoryProvider,
        documentsProvider,
        projectsProvider,
        recordingsProvider,
        storageUsageProvider,
        trashedDocumentsProvider;

/// The single mutation entry point for documents — the document-side twin of
/// [BlueprintActions].
///
/// Every method awaits the repository call, then fans the change out to every
/// sector that can display the document or a count derived from it: the Library
/// (and Trash / Archive / Whispers / Storage), Projects (cards, doc lists,
/// detail counts), and the Book Structure (placements + per-section coherence).
/// This is the Heart: a change can never show in one place but not another, and
/// the affected surfaces reconcile within the ~2s live window.
///
/// Invalidation philosophy (identical to [BlueprintActions]): where a concrete
/// id is known, invalidate the specific family instance; where the affected
/// project is not known at the call site (a document may belong to any project,
/// and membership/placement live server-side), invalidate the WHOLE family
/// rather than tracking it client-side. `autoDispose` providers only refetch
/// while something is watching them, so broad invalidation is cheap.
final documentActionsProvider = Provider<DocumentActions>((ref) {
  return DocumentActions(ref, ref.watch(documentRepositoryProvider));
});

class DocumentActions {
  DocumentActions(this._ref, this._repo);

  final Ref _ref;
  final DocumentRepository _repo;

  /// Soft-delete → Trash. The backend also clears any blueprint placement, so
  /// the document leaves the Library, Projects, and Book Structure together.
  Future<void> deleteDocument(String id) async {
    await _repo.deleteDocument(id);
    _fanOutAllSectors(id);
  }

  /// Restore a soft-deleted document from Trash back into the Library.
  Future<void> restoreDocument(String id) async {
    await _repo.restoreDocument(id);
    _fanOutAllSectors(id);
  }

  /// Permanently purge a trashed document.
  Future<void> purgeDocument(String id) async {
    await _repo.purgeDocument(id);
    _fanOutAllSectors(id);
  }

  /// Archive (hide from the main Library list; still recoverable).
  Future<void> archiveDocument(String id) async {
    await _repo.archiveDocument(id);
    _fanOutAllSectors(id);
  }

  /// Rename — the title appears in the Library, the project tabs, the placement
  /// rows and the blueprint overview, so every one of those refreshes.
  Future<Document> renameDocument(String id, String title) async {
    final updated = await _repo.renameDocument(id, title);
    _fanOutAllSectors(id);
    return updated;
  }

  /// Assign to / move between / remove from a project. The backend clears any
  /// stale placement on a real move (`documents.assign_project`); this fans the
  /// change out to both the old and new project surfaces (whole families).
  Future<void> assignToProject(String id, String? projectId) async {
    await _repo.assignToProject(id, projectId);
    _fanOutAllSectors(id);
  }

  /// Change the document's built-in cover illustration (also shown on project
  /// cards when the document is a project cover).
  Future<Document> setCoverBuiltin(String id, String illustrationId) async {
    final updated = await _repo.setCoverBuiltin(id, illustrationId);
    _fanOutAllSectors(id);
    return updated;
  }

  /// Duplicate a document into a new Library entry.
  Future<void> duplicateDocument(String id) async {
    await _repo.duplicateDocument(id);
    _fanOutAllSectors(id);
  }

  /// Invalidate every sector that can render this document or a count derived
  /// from it. Family providers are invalidated wholesale because the document's
  /// project is not always known at the call site.
  void _fanOutAllSectors(String documentId) {
    // Library surfaces
    _ref.invalidate(documentsProvider);
    _ref.invalidate(trashedDocumentsProvider);
    _ref.invalidate(archivedDocumentsProvider);
    _ref.invalidate(recordingsProvider);
    _ref.invalidate(storageUsageProvider);
    // Project surfaces (cards/counts, doc lists, placements)
    _ref.invalidate(projectsProvider);
    _ref.invalidate(projectDocumentsProvider);
    _ref.invalidate(projectDetailProvider);
    _ref.invalidate(projectPlacementsProvider);
    // Book Structure (per-section document counts / coherence)
    _ref.invalidate(projectBlueprintOverviewProvider);
    // This document's own placement card (Writing Desk "PLACED IN")
    _ref.invalidate(documentPlacementProvider(documentId));
  }
}
