import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'blueprint_providers.dart';
import 'project_providers.dart';
import 'providers.dart';

/// A document placed into a blueprint section, for read-only display in the
/// Blueprints "Book Structure" tab. Mirrors what the Writing Desk shows.
class PlacedFile {
  const PlacedFile({
    required this.documentId,
    required this.title,
    required this.sortOrder,
  });

  final String documentId;
  final String title;
  final double sortOrder;
}

/// partId -> files placed in that section, for the given blueprint.
///
/// Placements are project-scoped, so this resolves the blueprint to the project
/// that adopted it (one Book Structure per project), reads that project's
/// placements filtered to this blueprint, and joins document titles. Returns an
/// empty map for templates and unadopted structures. Watches its dependencies,
/// so placing a file in the Writing Desk refreshes this view (the Heart).
final blueprintPlacedFilesProvider = FutureProvider.autoDispose
    .family<Map<String, List<PlacedFile>>, String>((ref, blueprintId) async {
  final projects = await ref.watch(projectsProvider.future);

  String? projectId;
  for (final p in projects) {
    final adopted = await ref.watch(adoptedBlueprintsProvider(p.id).future);
    if (adopted.any((b) => b.id == blueprintId)) {
      projectId = p.id;
      break;
    }
  }
  if (projectId == null) return const <String, List<PlacedFile>>{};

  final placements =
      await ref.watch(projectPlacementsProvider(projectId).future);
  final docs = await ref.watch(documentsProvider.future);
  final titleById = {for (final d in docs) d.id: d.title};

  final map = <String, List<PlacedFile>>{};
  for (final pl in placements.where((p) => p.blueprintId == blueprintId)) {
    (map[pl.partId] ??= <PlacedFile>[]).add(PlacedFile(
      documentId: pl.documentId,
      title: titleById[pl.documentId] ?? 'Untitled',
      sortOrder: pl.sortOrder,
    ));
  }
  for (final list in map.values) {
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }
  return map;
});
