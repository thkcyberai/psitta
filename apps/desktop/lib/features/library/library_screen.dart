import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

import 'package:path/path.dart' as p;

import '../../core/constants.dart';
import '../../core/theme/colors.dart';
import '../../data/services/pdf_text_extractor.dart';
import '../../core/theme/psitta_tokens.dart';
import '../../data/providers/providers.dart';
import '../../data/services/audio_service.dart';
import '../../data/services/preferences_service.dart';
import '../../data/models/document.dart';
import '../../data/repositories/project_repository.dart';
import '../settings/settings_screen.dart';
import '../shell/app_shell.dart';
import '../shell/desktop_shell.dart';
import '../shell/widgets/player_bar.dart';
import '../../widgets/document_cover.dart';
import 'cover_picker_dialog.dart';
import 'widgets/document_card.dart';
import 'widgets/drop_zone_overlay.dart';

/// Global FocusNode for the library search field.
/// Used by keyboard shortcuts (Ctrl+F) to focus the search from any screen.
final librarySearchFocusProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'librarySearch');
  ref.onDispose(() => node.dispose());
  return node;
});

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

  Future<void> _handleNewSheet() async {
    try {
      final repo = ref.read(documentRepositoryProvider);
      final result = await repo.createBlankDocument();
      final docId = result['id']!;
      ref.invalidate(documentsProvider);
      if (mounted) {
        context.go('/player/$docId?autoplay=0&edit=1');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create sheet: $e')),
        );
      }
    }
  }

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
        if (p.extension(file.path!).toLowerCase() == '.pdf') {
          final pageTexts =
              await PdfTextExtractor.extractPageTexts(file.path!);
          await repo.uploadDocument(
            file.path!,
            pageTexts: pageTexts.isNotEmpty ? pageTexts : null,
          );
        } else {
          await repo.uploadDocument(file.path!);
        }
      } on DioException catch (e) {
        if (mounted) {
          String msg = 'Upload failed: ${file.name}';
          final statusCode = e.response?.statusCode;
          if (statusCode == 402 || statusCode == 403) {
            try {
              final data = e.response?.data;
              if (data is Map && data['detail'] is Map) {
                msg = data['detail']['message'] as String? ?? msg;
              }
            } catch (_) {}
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
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
    // Fire-and-forget stop — do not await, never block navigation.
    unawaited(audioService.stop());
    unawaited(audioService.reset());
    ref.read(activeDocumentIdProvider.notifier).state = doc.id;
    ref.read(currentDocTitleProvider.notifier).state = doc.title;
    ref.read(currentChunkIndexProvider.notifier).state = 0;
    ref.read(totalChunksProvider.notifier).state = 0;
    ref.read(activeChunkIdsProvider.notifier).state = const [];
  }

  Future<void> _listenToDocument(Document doc) async {
    final swhMode = ref.read(selectedSwhModeProvider);
    final swhEnabled = swhMode == SwhMode.always;
    await _primePlaybackSession(doc);
    if (!mounted) return;
    final swhParam = swhEnabled ? '1' : '0';
    context.go('/player/${doc.id}?autoplay=0&swh=$swhParam');
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

  Future<void> _regenerateAudio(Document doc) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Regenerating audio for ${doc.title}...')),
    );
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.resynthesizeDocument(doc.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Audio regeneration started for ${doc.title}')),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Regenerate audio failed: $e')),
        );
    }
  }

  Future<void> _downloadDocument(Document doc) async {
    // Step 1: Show download options dialog
    final options = await showDialog<_DownloadOptions>(
      context: context,
      builder: (ctx) => _DownloadOptionsDialog(docTitle: doc.title),
    );
    if (options == null) return; // user cancelled

    // Step 2: Show native Save As dialog
    final defaultName = '${doc.title}.docx';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Document',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: ['docx'],
    );
    if (savePath == null) return; // user cancelled

    if (!mounted) return;

    // Step 3: Download with progress indication
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Exporting document…'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      final repo = ref.read(documentRepositoryProvider);
      final bytes = await repo.exportDocument(
        doc.id,
        includeCover: options.includeCover,
        includeFooter: options.includeFooter,
      );
      if (bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Export produced no content')),
          );
        return;
      }

      // Ensure .docx extension
      final finalPath =
          savePath.endsWith('.docx') ? savePath : '$savePath.docx';
      await File(finalPath).writeAsBytes(bytes);

      if (!mounted) return;
      final folder = File(finalPath).parent.path;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Saved to $folder'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => Process.run('cmd', ['/c', 'start', '', finalPath]),
            ),
            duration: const Duration(seconds: 6),
          ),
        );
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(e.response?.statusCode == 404
              ? 'Export unavailable for this document.'
              : 'Export failed: ${e.message}'),
        ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Export failed: $e')));
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

  Future<void> _changeCover(Document doc) async {
    final result = await showCoverPickerDialog(
      context: context,
      currentCoverType: doc.coverType,
      currentCoverValue: doc.coverValue,
    );
    if (result == null || !mounted) return;

    final repo = ref.read(documentRepositoryProvider);
    try {
      switch (result) {
        case CoverPickerBuiltin(:final illustrationId):
          await repo.setCoverBuiltin(doc.id, illustrationId);
        case CoverPickerUpload(:final file):
          await repo.uploadCover(doc.id, file.path);
        case CoverPickerRemove():
          await repo.removeCover(doc.id);
      }
      // Clear Flutter's image cache so uploaded covers refresh immediately.
      PaintingBinding.instance.imageCache.clear();
      ref.invalidate(documentsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update cover: $e')),
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
    final projectsAsync = ref.watch(projectsProvider);
    final subAsync = ref.watch(subscriptionSummaryProvider);
    final isProTier = subAsync.whenOrNull(
          data: (data) => data['plan_id'] != 'free',
        ) ??
        false;

    // Build project ID → name map for path labels
    final Map<String, String> projectNameMap = {};
    projectsAsync.whenData((projects) {
      for (final p in projects) {
        projectNameMap[p.id] = p.name;
      }
    });

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
              const Icon(Icons.cloud_off, size: 48, color: AppColors.error),
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
                      focusNode: ref.watch(librarySearchFocusProvider),
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
                          width: 160,
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
                        Tooltip(
                          message: isProTier
                              ? ''
                              : 'Available on Pro \u2014 Upgrade in Settings',
                          child: OutlinedButton.icon(
                            onPressed: _isUploading || !isProTier
                                ? null
                                : _handleNewSheet,
                            icon: const Icon(Icons.edit_note, size: 18),
                            label: const Text('New Sheet'),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                                    final projectName = doc.projectId != null
                                        ? projectNameMap[doc.projectId]
                                        : null;
                                    final path = projectName != null
                                        ? '/Library/$projectName'
                                        : '/Library';
                                    return DocumentCard(
                                      title: doc.title,
                                      subtitle:
                                          _prettySourceType(doc.sourceType),
                                      status: doc.status,
                                      isSelected: doc.id == _selectedDocId,
                                      projectPath: path,
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
                                      onChangeCover: () => _changeCover(doc),
                                      onRegenerateAudio: () => _regenerateAudio(doc),
                                      documentId: doc.id,
                                      coverType: doc.coverType,
                                      coverValue: doc.coverValue,
                                      sourceType: doc.sourceType,
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

    // Resolve project name for the selected document
    final selectedProjectName = selected?.projectId != null
        ? projectNameMap[selected!.projectId]
        : null;

    final rightPanel = _LibraryRightPanel(
      selected: selected,
      tokens: tokens,
      projectName: selectedProjectName,
      onListen: selected == null
          ? null
          : () => _listenToDocument(selected!),
      onRename: selected == null ? null : () => _rename(selected!),
      onDelete: selected == null ? null : () => _confirmAndDelete(selected!),
      onViewDetails: selected == null ? null : () => _showDetails(selected!),
      onEditText: selected == null
          ? null
          : () => context.push(
                '/editor/${selected!.id}?title=${Uri.encodeComponent(selected!.title)}'),
      onAssignProject: selected == null
          ? null
          : () => _assignToProject(selected!),
      onChangeCover: selected == null
          ? null
          : () => _changeCover(selected!),
    );

    if (isInDesktopShell) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final showRightPanel = constraints.maxWidth >= 900;
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
  const _LibraryBody({
    required this.isDragging,
    required this.onDragEntered,
    required this.onDragExited,
    required this.onDrop,
    required this.child,
  });

  final bool isDragging;
  final VoidCallback onDragEntered;
  final VoidCallback onDragExited;
  final void Function(DropDoneDetails) onDrop;
  final Widget child;

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
  const _LibraryRightPanel({
    required this.selected,
    required this.tokens,
    required this.onListen,
    required this.onRename,
    required this.onDelete,
    required this.onViewDetails,
    this.onEditText,
    this.onAssignProject,
    this.onChangeCover,
    this.projectName,
  });

  final Document? selected;
  final PsittaTokens tokens;
  final VoidCallback? onListen;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onViewDetails;
  final VoidCallback? onEditText;
  final VoidCallback? onAssignProject;
  final VoidCallback? onChangeCover;
  final String? projectName;

  String _fmtDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedColor = theme.colorScheme.onSurface.withOpacity(isDark ? 0.55 : 0.50);

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? tokens.surface.withOpacity(0.60)
            : tokens.surface.withOpacity(0.85),
        border: Border(
          left: BorderSide(
            color: tokens.border.withOpacity(isDark ? 0.40 : 0.55),
            width: 1,
          ),
        ),
      ),
      child: selected == null
          ? _buildEmptyState(theme, isDark, mutedColor)
          : _buildSelectedState(context, theme, isDark, mutedColor),
    );
  }

  Widget _buildEmptyState(
      ThemeData theme, bool isDark, Color mutedColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: 0.25,
              child: Image.asset(
                'assets/branding/Logo.png',
                width: 72,
                height: 72,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Select a document',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: mutedColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Click on a document to see its details',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: mutedColor.withOpacity(0.70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedState(
      BuildContext context, ThemeData theme, bool isDark, Color mutedColor) {
    final doc = selected!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER ──
          Text(
            doc.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tokens.glow.withOpacity(isDark ? 0.15 : 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: tokens.glow.withOpacity(isDark ? 0.30 : 0.25),
                    width: 1,
                  ),
                ),
                child: Text(
                  doc.sourceType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: tokens.glow,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _fmtDate(doc.createdAt.toLocal()),
                  style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Pages: ${doc.pageCount ?? '—'}${doc.wordCount == null ? '' : '  ·  ${doc.wordCount} words'}',
            style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
          ),

          const SizedBox(height: 20),

          // ── COVER ART ──
          GestureDetector(
            onTap: onChangeCover,
            child: Stack(
              children: [
                DocumentCover(
                  coverType: doc.coverType,
                  coverValue: doc.coverValue,
                  documentId: doc.id,
                  size: DocumentCoverSize.detail,
                  sourceType: doc.sourceType,
                  borderRadius: BorderRadius.circular(tokens.radius - 4),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.black : Colors.white)
                          .withOpacity(0.70),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image_outlined,
                            size: 14, color: mutedColor),
                        const SizedBox(width: 4),
                        Text(
                          'Change',
                          style: TextStyle(
                              fontSize: 11, color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── PRIMARY ACTION ──
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: onListen,
              icon: const Icon(Icons.play_arrow, size: 20),
              label: const Text('Listen'),
            ),
          ),

          const SizedBox(height: 20),

          // ── VOICE SELECTOR ──
          Text(
            'Voice',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: mutedColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) {
              return ref.watch(voicesProvider).when(
                    loading: () => const SizedBox(height: 40),
                    error: (_, __) => const SizedBox(height: 40),
                    data: (voices) {
                      final filtered = voices.toList();

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

          const SizedBox(height: 20),

          // ── METADATA ──
          Text(
            'Details',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: mutedColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          _MetadataRow(
            icon: Icons.folder_outlined,
            label: 'Project',
            value: projectName ?? 'Not assigned',
            tokens: tokens,
          ),
          const SizedBox(height: 6),
          _MetadataRow(
            icon: doc.status == 'ready'
                ? Icons.check_circle_outline
                : Icons.hourglass_top,
            label: 'Status',
            value: doc.status == 'ready'
                ? 'Ready'
                : doc.status[0].toUpperCase() + doc.status.substring(1),
            tokens: tokens,
          ),

          const SizedBox(height: 20),

          // ── QUICK ACTIONS ──
          Text(
            'Quick Actions',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: mutedColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          _QuickAction(
            icon: Icons.info_outline,
            label: 'View Details',
            onTap: onViewDetails,
          ),
          const SizedBox(height: 6),
          _QuickAction(
            icon: Icons.edit_note_outlined,
            label: 'Edit Text',
            onTap: onEditText,
          ),
          const SizedBox(height: 6),
          _QuickAction(
            icon: doc.projectId != null
                ? Icons.drive_file_move_outlined
                : Icons.folder_outlined,
            label: doc.projectId != null ? 'Change Project' : 'Add to Project',
            onTap: onAssignProject,
          ),
        ],
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.tokens,
  });

  final IconData icon;
  final String label;
  final String value;
  final PsittaTokens tokens;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedColor = theme.colorScheme.onSurface.withOpacity(isDark ? 0.55 : 0.50);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: mutedColor),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: mutedColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(isDark ? 0.80 : 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

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
  const _EmptyState({required this.onUpload});
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.description_outlined,
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
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

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

// ── Download Options ──────────────────────────────────────────────────────────

class _DownloadOptions {
  const _DownloadOptions({
    required this.includeCover,
    required this.includeFooter,
  });
  final bool includeCover;
  final bool includeFooter;
}

class _DownloadOptionsDialog extends StatefulWidget {
  const _DownloadOptionsDialog({required this.docTitle});
  final String docTitle;

  @override
  State<_DownloadOptionsDialog> createState() => _DownloadOptionsDialogState();
}

class _DownloadOptionsDialogState extends State<_DownloadOptionsDialog> {
  bool _includeCover = true;
  bool _includeFooter = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Download Options'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.docTitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Export as a branded DOCX file.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Include cover page'),
              subtitle: const Text('Title page with document name and date'),
              value: _includeCover,
              onChanged: (v) => setState(() => _includeCover = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Include Psitta footer'),
              subtitle: const Text('Branding and page numbers on every page'),
              value: _includeFooter,
              onChanged: (v) => setState(() => _includeFooter = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Download'),
          onPressed: () => Navigator.of(context).pop(
            _DownloadOptions(
              includeCover: _includeCover,
              includeFooter: _includeFooter,
            ),
          ),
        ),
      ],
    );
  }
}

