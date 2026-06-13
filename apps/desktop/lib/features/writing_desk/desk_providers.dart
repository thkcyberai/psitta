import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/document_assembler.dart';
import '../../data/models/psitta_document.dart';
import '../../data/providers/providers.dart';

/// Combines [chunksProvider] and [documentsProvider] into an assembled
/// [PsittaDocument] for the Writing Desk center pane. Family key is documentId.
///
/// Additive provider — does not modify any existing data-layer file.
final deskDocumentProvider = FutureProvider.autoDispose
    .family<PsittaDocument, String>((ref, documentId) async {
  final data = await ref.watch(chunksProvider(documentId).future);
  final docs = await ref.watch(documentsProvider.future);
  final doc = docs.firstWhere(
    (d) => d.id == documentId,
    orElse: () => throw StateError('Document $documentId not found'),
  );
  return DocumentAssembler.assemble(
    data: data,
    title: doc.title,
    sourceType: doc.sourceType,
  );
});

/// Write-state of the Writing Desk center pane.
/// Consumed by the Writing Desk top-bar saved indicator.
enum DeskSaveState { saved, saving, editing }

/// Published by [DeskCenterPane] as the user enters, edits, or saves.
final deskSaveStateProvider =
    StateProvider<DeskSaveState>((ref) => DeskSaveState.saved);
