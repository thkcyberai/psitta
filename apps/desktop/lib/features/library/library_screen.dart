import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/psitta_tokens.dart';
import '../../data/providers/providers.dart';
import '../../data/services/audio_service.dart';
import '../../data/services/preferences_service.dart';
import '../../data/models/document.dart';
import '../../data/repositories/project_repository.dart';
import '../shell/app_shell.dart';
import '../shell/desktop_shell.dart';
import '../shell/widgets/player_bar.dart';
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

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String? _selectedDocId;

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
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: ${file.name}')),
          );
        }
      }
    }
    setState(() => _isUploading = false);
    ref.invalidate(documentsProvider);
  }

  /// Big-tech UX: selecting a document in Library should prime the bottom PlayerBar.
  /// This enables "select document -> press Play" without navigating to Player first.
  Future<void> _primePlaybackSession(Document doc) async {
    final audioService = ref.read(audioServiceProvider);
    // Switching documents should stop prior playback and clear audio source state.
    await audioService.stop();
    audioService.reset();

    ref.read(activeDocumentIdProvider.notifier).state = doc.id;
    ref.read(currentDocTitleProvider.notifier).state = doc.title;
    ref.read(currentChunkIndexProvider.notifier).state = 0;
    ref.read(totalChunksProvider.notifier).state = 0;
    ref.read(activeChunkIdsProvider.notifier).state = const [];

    try {
      final data = await ref.read(chunksProvider(doc.id).future);
      final chunks = (data['chunks'] as List<dynamic>?) ?? const [];
      final ids = chunks
          .map((c) => ((c as Map<String, dynamic>)['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();

      ref.read(activeChunkIdsProvider.notifier).state = ids;
      ref.read(totalChunksProvider.notifier).state = ids.length;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load chapters: $e')),
        );
      }
    }
  }

  void _handleDrop(DropDoneDetails details) {
    setState(() => _isDragging = false);
    final files = details.files
        .where((f) {
          final ext = f.name.split('.').last.toLowerCase();
          return AppConstants.allowedExtensions.contains(ext);
        })
        .map(
          (f) => PlatformFile(
            name: f.name,
            size: 0,
            path: f.path,
          ),
        )
        .toList();
    if (files.isNotEmpty) {
      _uploadFiles(files);
    }
  }

  String _prettySourceType(String sourceType) {
    final st = sourceType.trim().toLowerCase();
    switch (st) {
      case 'pdf':
        return 'PDF Document';
      case 'docx':
        return 'DOCX Document';
      case 'txt':
        return 'Text File';
      case 'md':
        return 'Markdown';
      case 'html':
        return 'HTML';
      default:
        return st.toUpperCase();
    }
  }

  void _showDetails(Document doc) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                doc.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow(label: 'Type', value: doc.sourceType.toUpperCase()),
              _DetailRow(
                label: 'Uploaded',
                value: doc.createdAt.toLocal().toString().split('.').first,
              ),
              _DetailRow(label: 'Pages', value: doc.pageCount.toString()),
              if (doc.wordCount != null)
                _DetailRow(
                  label: 'Word Count',
                  value: '${doc.wordCount} words',
                ),
              _DetailRow(label: 'Status', value: doc.status),
              _DetailRow(label: 'Document ID', value: doc.id),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDelete(Document doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document'),
        content: Text('Delete "${doc.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final repo = ref.read(documentRepositoryProvider);
    try {
      await repo.deleteDocument(doc.id);
      final activeId = ref.read(activeDocumentIdProvider);
      if (activeId == doc.id) {
        ref.read(activeDocumentIdProvider.notifier).state = null;
        ref.read(currentDocTitleProvider.notifier).state = '';
      }
      ref.invalidate(documentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Future<void> _archiveDocument(Document doc) async {
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.archiveDocument(doc.id);
      ref.invalidate(documentsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to archive: $e')),
        );
      }
    }
  }

  Future<void> _downloadDocument(Document doc) async {
    try {
      final repo = ref.read(documentRepositoryProvider);
      final bytes = await repo.downloadDocument(doc.id);
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Original file not available for download')),
          );
        }
        return;
      }
      // Save to Downloads folder
      final fileName = '${doc.title}.${doc.sourceType}';
      final downloadsPath = '${Platform.environment['USERPROFILE']}/Downloads/$fileName';
      await File(downloadsPath).writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to Downloads: $fileName')),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.statusCode == 404
          ? 'Download unavailable — only documents uploaded after D28 support this.'
          : 'Download failed: ${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  Future<void> _assignToProject(Document doc) async {
    final projects = await ref.read(projectsProvider.future);
    if (projects.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No projects yet. Create one in the Projects section.'),
        ),
      );
      return;
    }
    if (!mounted) return;
    final selected = await showDialog<Project>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Add to Project'),
        children: projects
            .map((p) => SimpleDialogOption(
                  onPressed: () => Navigator.of(ctx).pop(p),
                  child: Text(p.name),
                ))
            .toList(),
      ),
    );
    if (selected == null) return;
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.assignToProject(doc.id, selected.id);
      ref.invalidate(documentsProvider);
      ref.invalidate(projectsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign project: $e')),
        );
      }
    }
  }

  Future<void> _removeFromProject(Document doc) async {
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.assignToProject(doc.id, null);
      ref.invalidate(documentsProvider);
      ref.invalidate(projectsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove from project: $e')),
        );
      }
    }
  }

  Future<void> _rename(Document doc) async {
    final controller = TextEditingController(text: doc.title);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit document name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Enter a document name',
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final trimmed = (newTitle ?? '').trim();
    if (trimmed.isEmpty || trimmed == doc.title) return;

    final repo = ref.read(documentRepositoryProvider);
    try {
      await repo.renameDocument(doc.id, trimmed);
      ref.invalidate(documentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = PsittaTokens.of(context);
    final documentsAsync = ref.watch(documentsProvider);

    Document? selected;

    final content = documentsAsync.when(
      loading: () => _LibraryBody(
        isDragging: _isDragging,
        onDragEntered: () => setState(() => _isDragging = true),
        onDragExited: () => setState(() => _isDragging = false),
        onDrop: _handleDrop,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _LibraryBody(
        isDragging: _isDragging,
        onDragEntered: () => setState(() => _isDragging = true),
        onDragExited: () => setState(() => _isDragging = false),
        onDrop: _handleDrop,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: AppColors.error),
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
                onPressed: () => ref.invalidate(documentsProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (documents) {
        final query = _searchQuery.trim().toLowerCase();
        final filteredDocs = query.isEmpty
            ? documents
            : documents
                .where((doc) => doc.title.toLowerCase().contains(query))
                .toList();

        if (_selectedDocId != null) {
          for (final doc in documents) {
            if (doc.id == _selectedDocId) {
              selected = doc;
              break;
            }
          }
        }

        return _LibraryBody(
          isDragging: _isDragging,
          onDragEntered: () => setState(() => _isDragging = true),
          onDragExited: () => setState(() => _isDragging = false),
          onDrop: _handleDrop,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 900;

                    final searchField = TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search documents... (Ctrl+F)',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                icon: const Icon(Icons.close, size: 18),
                              ),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: isNarrow ? 10 : 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(tokens.radius - 6),
                        ),
                        isDense: true,
                      ),
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Uploading...',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          searchField,
                          const SizedBox(height: 12),
                          Consumer(
                            builder: (context, ref, _) {
                              final showArchived = ref.watch(showArchivedProvider);
                              return FilterChip(
                                label: const Text('Show Archived'),
                                selected: showArchived,
                                onSelected: (val) =>
                                    ref.read(showArchivedProvider.notifier).state = val,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isUploading ? null : _handleFilePick,
                              icon: const Icon(Icons.upload_file, size: 18),
                              label: const Text('Upload'),
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
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
                          child: searchField,
                        ),
                        const SizedBox(width: 12),
                        Consumer(
                          builder: (context, ref, _) {
                            final showArchived = ref.watch(showArchivedProvider);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: const Text('Show Archived'),
                                selected: showArchived,
                                onSelected: (val) =>
                                    ref.read(showArchivedProvider.notifier).state = val,
                              ),
                            );
                          },
                        ),
                        FilledButton.icon(
                          onPressed: _isUploading ? null : _handleFilePick,
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: const Text('Upload'),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: documents.isEmpty
                      ? _EmptyState(onUpload: _handleFilePick)
                      : filteredDocs.isEmpty
                          ? Center(
                              child: Text(
                                'No matches',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final crossAxisCount =
                                    (constraints.maxWidth / 320)
                                        .floor()
                                        .clamp(1, 4);
                                final childAspectRatio =
                                    constraints.maxWidth < 900 ? 1.55 : 2.2;
                                return GridView.builder(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    childAspectRatio: childAspectRatio,
                                  ),
                                  itemCount: filteredDocs.length,
                                  itemBuilder: (context, index) {
                                    final doc = filteredDocs[index];
                                    return DocumentCard(
                                      title: doc.title,
                                      subtitle:
                                          _prettySourceType(doc.sourceType),
                                      status: doc.status,
                                      isSelected: doc.id == _selectedDocId,
                                      onTap: () {
                                        setState(() => _selectedDocId = doc.id);
                                        _primePlaybackSession(doc);
                                      },
                                      onRead: () {
                                        _primePlaybackSession(doc);
                                        context
                                            .go('/player/${doc.id}?autoplay=0');
                                      },
                                      onEdit: () => _rename(doc),
                                      onDelete: () => _confirmAndDelete(doc),
                                      onArchive: () => _archiveDocument(doc),
                                      onDownload: () => _downloadDocument(doc),
                                      currentProjectId: doc.projectId,
                                      onAssignProject: () => _assignToProject(doc),
                                      onRemoveProject: () => _removeFromProject(doc),
                                    );
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );

    final isInDesktopShell =
        context.findAncestorWidgetOfExactType<DesktopShell>() != null;

    final rightPanel = _LibraryRightPanel(
      selected: selected,
      tokens: tokens,
      onListen: selected == null
          ? null
          : () {
              _primePlaybackSession(selected!);
              context.go('/player/${selected!.id}');
            },
      onRename: selected == null ? null : () => _rename(selected!),
      onDelete: selected == null ? null : () => _confirmAndDelete(selected!),
      onViewDetails: selected == null ? null : () => _showDetails(selected!),
    );

    if (isInDesktopShell) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final showRightPanel = constraints.maxWidth >= 1100;
          return Row(
            children: [
              Expanded(child: content),
              if (showRightPanel) ...[
                VerticalDivider(width: 1, color: tokens.divider),
                SizedBox(
                  width: AppConstants.detailPanelMinWidth,
                  child: rightPanel,
                ),
              ],
            ],
          );
        },
      );
    }

    return AppShell(
      content: content,
      rightPanel: rightPanel,
      isSidebarCollapsed: ref.read(sidebarCollapsedProvider),
    );
  }
}

class _LibraryBody extends StatelessWidget {
  final bool isDragging;
  final VoidCallback onDragEntered;
  final VoidCallback onDragExited;
  final void Function(DropDoneDetails) onDrop;
  final Widget child;

  const _LibraryBody({
    required this.isDragging,
    required this.onDragEntered,
    required this.onDragExited,
    required this.onDrop,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => onDragEntered(),
      onDragExited: (_) => onDragExited(),
      onDragDone: onDrop,
      child: Stack(
        children: [
          child,
          if (isDragging) const DropZoneOverlay(),
        ],
      ),
    );
  }
}

class _LibraryRightPanel extends StatelessWidget {
  final Document? selected;
  final PsittaTokens tokens;
  final VoidCallback? onListen;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onViewDetails;

  const _LibraryRightPanel({
    required this.selected,
    required this.tokens,
    required this.onListen,
    required this.onRename,
    required this.onDelete,
    required this.onViewDetails,
  });

  String _fmtDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.surface.withOpacity(0.92),
            tokens.surface2.withOpacity(0.88),
          ],
        ),
        border: Border.all(color: tokens.border.withOpacity(0.45), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 26,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: selected == null
          ? Center(
              child: Text(
                'Select a document',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.75),
                ),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected!.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selected!.sourceType.toUpperCase(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.70),
                          ),
                        ),
                      ),
                      Text(
                        'Uploaded: ${_fmtDate(selected!.createdAt.toLocal())}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color
                              ?.withOpacity(0.75),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pages: ${selected!.pageCount}${selected!.wordCount == null ? '' : '  |  Length: ${selected!.wordCount} words'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.textTheme.bodySmall?.color?.withOpacity(0.75),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onListen,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Listen'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Voice',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Consumer(
                    builder: (context, ref, _) {
                      return ref.watch(voicesProvider).when(
                            loading: () => const SizedBox(height: 36),
                            error: (_, __) => const SizedBox(height: 36),
                            data: (voices) {
                              
                              final filtered = voices
                                  
                                  .toList();

                              final selectedVoice =
                                  ref.watch(selectedVoiceIdProvider);
                              final current =
                                  filtered.any((v) => v.id == selectedVoice)
                                      ? selectedVoice
                                      : (filtered.isNotEmpty
                                          ? filtered.first.id
                                          : selectedVoice);

                              if (current != selectedVoice &&
                                  filtered.isNotEmpty) {
                                ref
                                    .read(selectedVoiceIdProvider.notifier)
                                    .select(current);
                              }

                              return SizedBox(
                                height: 40,
                                child: DropdownButtonFormField<String>(
                                  value: current,
                                  items: filtered
                                      .map(
                                        (v) => DropdownMenuItem(
                                          value: v.id,
                                          child: Text(v.displayName),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    ref
                                        .read(selectedVoiceIdProvider.notifier)
                                        .select(value);
                                  },
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                          tokens.radius - 6),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                    },
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Quick Actions',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),


                  const SizedBox(height: 10),
                  _QuickAction(
                    icon: Icons.info_outline,
                    label: 'View Details',
                    onTap: onViewDetails,
                  ),

                ],
              ),
            ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.surface.withOpacity(0.55),
          borderRadius: BorderRadius.circular(tokens.radius),
          border: Border.all(color: tokens.border, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18, color: theme.iconTheme.color?.withOpacity(0.85)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: theme.iconTheme.color?.withOpacity(0.6),
            ),
          ],
        ),
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
            'Supported: PDF, DOCX, TXT, MD, HTML',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Upload'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.65),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
