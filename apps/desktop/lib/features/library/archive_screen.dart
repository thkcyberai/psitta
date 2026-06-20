import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/psitta_tokens.dart';
import '../../data/models/document.dart';
import '../../data/providers/providers.dart';
import '../../data/providers/document_actions.dart';
import '../../widgets/library_breadcrumb.dart';

/// Archive — archived documents, with unarchive / move-to-Trash.
class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  static IconData _icon(String type) {
    switch (type.toLowerCase()) {
      case 'docx':
        return Icons.description_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'epub':
        return Icons.menu_book_outlined;
      case 'md':
        return Icons.tag;
      case 'txt':
        return Icons.notes_outlined;
      case 'html':
        return Icons.code;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Future<void> _unarchive(
      WidgetRef ref, BuildContext context, Document doc) async {
    try {
      // archive toggle: archived -> ready
      await ref.read(documentActionsProvider).archiveDocument(doc.id);
      ref.invalidate(archivedDocumentsProvider);
      ref.invalidate(documentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unarchived “${doc.title}”')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t unarchive the document.')),
        );
      }
    }
  }

  Future<void> _trash(
      WidgetRef ref, BuildContext context, Document doc) async {
    try {
      await ref.read(documentActionsProvider).deleteDocument(doc.id);
      ref.invalidate(archivedDocumentsProvider);
      ref.invalidate(trashedDocumentsProvider);
      ref.invalidate(storageUsageProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Moved “${doc.title}” to Trash')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t move the document.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(archivedDocumentsProvider);

    return Container(
      color: tokens.surface,
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LibraryBreadcrumb(current: 'Archive'),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 26, color: scheme.onSurface),
              const SizedBox(width: 10),
              Text('Archive',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Archived documents are hidden from your Library but kept safe. '
            'Unarchive to bring one back.',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Couldn’t load the Archive.',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
              data: (docs) {
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 48,
                            color: scheme.onSurfaceVariant.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text('Nothing archived',
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => Divider(
                      height: 1, color: tokens.divider.withOpacity(0.4)),
                  itemBuilder: (_, i) {
                    final doc = docs[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Icon(_icon(doc.sourceType),
                              size: 20, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(doc.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                Text(doc.sourceType.toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _unarchive(ref, context, doc),
                            icon: const Icon(Icons.unarchive_outlined,
                                size: 18),
                            label: const Text('Unarchive'),
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            onPressed: () => _trash(ref, context, doc),
                            style: TextButton.styleFrom(
                                foregroundColor: scheme.onSurfaceVariant),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Trash'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
