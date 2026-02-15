import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme/colors.dart';
import '../../data/providers/providers.dart';
import 'widgets/document_card.dart';
import 'widgets/drop_zone_overlay.dart';

/// Library Screen — document management with drag-and-drop upload.
///
/// Fetches documents from the backend API via Riverpod.
/// Supports drag-and-drop and click-to-upload.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _isDragging = false;
  bool _isUploading = false;

  Future<void> _handleFilePick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.allowedExtensions,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      await _uploadFiles(result.files);
    }
  }

  Future<void> _uploadFiles(List<PlatformFile> files) async {
    setState(() => _isUploading = true);
    final repo = ref.read(documentRepositoryProvider);
    for (final file in files) {
      if (file.path == null) continue;
      try {
        await repo.uploadDocument(file.path!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: ${file.name}')),
          );
        }
      }
    }
    setState(() => _isUploading = false);
    // Refresh document list
    ref.invalidate(documentsProvider);
  }

  void _handleDrop(DropDoneDetails details) {
    setState(() => _isDragging = false);
    final files = details.files
        .where((f) {
          final ext = f.name.split('.').last.toLowerCase();
          return AppConstants.allowedExtensions.contains(ext);
        })
        .map((f) => PlatformFile(
              name: f.name,
              size: 0,
              path: f.path,
            ))
        .toList();
    if (files.isNotEmpty) {
      _uploadFiles(files);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final documentsAsync = ref.watch(documentsProvider);

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: _handleDrop,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Text(
                      'Library',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_isUploading) ...[
                      const SizedBox(width: 16),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Uploading...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const Spacer(),
                    SizedBox(
                      width: 260,
                      height: 36,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search documents... (Ctrl+F)',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _isUploading ? null : _handleFilePick,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('Upload'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Document grid — powered by Riverpod
                Expanded(
                  child: documentsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off,
                              size: 48, color: AppColors.error),
                          const SizedBox(height: 12),
                          Text(
                            'Could not load documents',
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            error.toString(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () =>
                                ref.invalidate(documentsProvider),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                    data: (documents) => documents.isEmpty
                        ? _EmptyState(onUpload: _handleFilePick)
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final crossAxisCount =
                                  (constraints.maxWidth / 300)
                                      .floor()
                                      .clamp(1, 5);
                              return GridView.builder(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 2.2,
                                ),
                                itemCount: documents.length,
                                itemBuilder: (context, index) {
                                  final doc = documents[index];
                                  return DocumentCard(
                                    title: doc.title,
                                    status: doc.status,
                                    onTap: () =>
                                        context.go('/player/${doc.id}'),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),

          if (_isDragging) const DropZoneOverlay(),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onUpload;
  const _EmptyState({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined,
              size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            'Drag documents here or click Upload',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Supports PDF, DOCX, TXT, Markdown, HTML',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload Document'),
          ),
        ],
      ),
    );
  }
}
