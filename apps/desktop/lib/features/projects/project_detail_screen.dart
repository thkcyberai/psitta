import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api/api_client.dart';
import '../../data/models/document.dart';
import '../../data/providers/providers.dart';
import '../shell/widgets/player_bar.dart';

final projectDocumentsProvider =
    FutureProvider.autoDispose.family<List<Document>, String>(
        (ref, projectId) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.dio.get('/projects/$projectId/documents');
  return (response.data as List)
      .map((e) => Document.fromJson(e as Map<String, dynamic>))
      .toList();
});

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;
  final String projectName;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(projectDocumentsProvider(projectId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Projects'),
                  onPressed: () => context.go('/projects'),
                ),
                const Text(' / ',
                    style: TextStyle(color: Colors.grey)),
                Text(
                  projectName,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: docsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (docs) => docs.isEmpty
                    ? _buildEmptyState(context)
                    : _buildDocList(context, ref, docs),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          const Text('No documents in this project'),
          const SizedBox(height: 8),
          Text(
            'Use "Add to Project" from the Library to add documents here.',
            style:
                TextStyle(color: Theme.of(context).colorScheme.outline),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDocList(
      BuildContext context, WidgetRef ref, List<Document> docs) {
    return ListView.separated(
      itemCount: docs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final doc = docs[i];
        return ListTile(
          leading: _sourceIcon(doc.sourceType),
          title: Text(doc.title),
          subtitle: Text(doc.status),
          trailing: const Icon(Icons.play_circle_outline),
          onTap: () {
            ref.read(activeDocumentIdProvider.notifier).state = doc.id;
            ref.read(currentDocTitleProvider.notifier).state =
                doc.title;
            context.go(
              '/player/${doc.id}'
              '?origin=project'
              '&projectId=$projectId'
              '&projectName=${Uri.encodeComponent(projectName)}',
            );
          },
        );
      },
    );
  }

  Widget _sourceIcon(String? sourceType) {
    final icon = switch (sourceType) {
      'pdf' => Icons.picture_as_pdf_outlined,
      'docx' => Icons.article_outlined,
      'txt' => Icons.text_snippet_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
    return Icon(icon);
  }
}
