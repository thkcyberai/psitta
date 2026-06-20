import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/psitta_tokens.dart';
import '../../data/models/document.dart';
import '../../data/providers/providers.dart';

import '../../data/providers/document_actions.dart';
/// Trash — soft-deleted documents with restore / delete-forever.
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

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

  Future<void> _restore(
      WidgetRef ref, BuildContext context, Document doc) async {
    try {
      await ref.read(documentActionsProvider).restoreDocument(doc.id);
      ref.invalidate(trashedDocumentsProvider);
      ref.invalidate(documentsProvider);
      ref.invalidate(storageUsageProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored “${doc.title}”')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t restore the document.')),
        );
      }
    }
  }

  Future<void> _purge(
      WidgetRef ref, BuildContext context, Document doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete forever?'),
        content: Text(
            '“${doc.title}” will be permanently deleted. This can’t be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE5534B)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(documentActionsProvider).purgeDocument(doc.id);
      ref.invalidate(trashedDocumentsProvider);
      ref.invalidate(storageUsageProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted “${doc.title}” forever')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t delete the document.')),
        );
      }
    }
  }

  Future<void> _emptyTrash(
      WidgetRef ref, BuildContext context, List<Document> docs) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Empty Trash?'),
        content: Text(
            'All ${docs.length} document${docs.length == 1 ? '' : 's'} in Trash '
            'will be permanently deleted. This can’t be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE5534B)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    var failed = 0;
    for (final d in docs) {
      try {
        await ref.read(documentActionsProvider).purgeDocument(d.id);
      } catch (_) {
        failed++;
      }
    }
    ref.invalidate(trashedDocumentsProvider);
    ref.invalidate(storageUsageProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(failed == 0
                ? 'Trash emptied'
                : 'Emptied — $failed item${failed == 1 ? '' : 's'} couldn’t be deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(trashedDocumentsProvider);
    final docs = async.valueOrNull ?? const <Document>[];

    return Container(
      color: tokens.surface,
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb — where you came from.
          Row(
            children: [
              InkWell(
                onTap: () => context.go('/library'),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_left, size: 16, color: scheme.primary),
                      Text('Library',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.primary)),
                    ],
                  ),
                ),
              ),
              Text('  ›  Trash',
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.delete_outline, size: 26, color: scheme.onSurface),
              const SizedBox(width: 10),
              Text('Trash',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              if (docs.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _emptyTrash(ref, context, docs),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE5534B)),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: Text('Empty Trash (${docs.length})'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Deleted documents are kept here. Restore them to your Library, '
            'or delete them permanently.',
            style:
                TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Couldn’t load Trash.',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
              data: (docs) {
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline,
                            size: 48,
                            color: scheme.onSurfaceVariant.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text('Trash is empty',
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
                            onPressed: () => _restore(ref, context, doc),
                            icon: const Icon(Icons.restore, size: 18),
                            label: const Text('Restore'),
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            onPressed: () => _purge(ref, context, doc),
                            style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFE5534B)),
                            icon: const Icon(Icons.delete_forever_outlined,
                                size: 18),
                            label: const Text('Delete'),
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
