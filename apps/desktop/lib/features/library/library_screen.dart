import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme/colors.dart';
import 'widgets/document_card.dart';
import 'widgets/drop_zone_overlay.dart';

/// Library Screen — document management with drag-and-drop upload.
///
/// Desktop UX: drag files from Finder/Explorer directly onto the
/// library area. Also supports click-to-upload via the FAB.
/// Documents are displayed in a responsive grid that adapts to
/// the available content width.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _isDragging = false;

  // TODO: Replace with Riverpod provider + API data
  final List<Map<String, String>> _documents = [
    {'id': '1', 'title': 'Research Paper — LLM Safety.pdf', 'status': 'ready'},
    {'id': '2', 'title': 'Quarterly Report Q4.docx', 'status': 'processing'},
    {'id': '3', 'title': 'Meeting Notes Dec.md', 'status': 'ready'},
  ];

  Future<void> _handleFilePick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.allowedExtensions,
      allowMultiple: true,
    );
    if (result != null) {
      // TODO: Upload via DocumentRepository
      debugPrint('Picked ${result.files.length} files');
    }
  }

  void _handleDrop(DropDoneDetails details) {
    setState(() => _isDragging = false);
    // TODO: Validate file types and upload via DocumentRepository
    debugPrint('Dropped ${details.files.length} files');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: _handleDrop,
      child: Stack(
        children: [
          // ── Main content ─────────────────────────────────────
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
                    const Spacer(),
                    // Search field
                    SizedBox(
                      width: 260,
                      height: 36,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search documents... (Ctrl+F)',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _handleFilePick,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('Upload'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Document grid
                Expanded(
                  child: _documents.isEmpty
                      ? _EmptyState(onUpload: _handleFilePick)
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount =
                                (constraints.maxWidth / 300).floor().clamp(1, 5);
                            return GridView.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 2.2,
                              ),
                              itemCount: _documents.length,
                              itemBuilder: (context, index) {
                                final doc = _documents[index];
                                return DocumentCard(
                                  title: doc['title']!,
                                  status: doc['status']!,
                                  onTap: () =>
                                      context.go('/player/${doc["id"]}'),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // ── Drag overlay ───────────────────────────────────
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
          Icon(Icons.description_outlined, size: 64, color: AppColors.textSecondary),
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
