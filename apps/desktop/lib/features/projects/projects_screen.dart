import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/psitta_tokens.dart';
import '../../data/providers/providers.dart';
import '../../data/repositories/project_repository.dart';
import '../../widgets/document_cover.dart';
import '../../widgets/library_breadcrumb.dart';
import 'project_cover_picker_dialog.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Container(
      color: tokens.surface,
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LibraryBreadcrumb(current: loc.navProjects),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.folder_copy_outlined,
                  size: 26, color: scheme.onSurface),
              const SizedBox(width: 10),
              Text(loc.navProjects,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: Text(loc.newProject),
                onPressed: () => _showCreateDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            loc.projectsSubtitle,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: projectsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(loc.projLoadError,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
              data: (projects) => projects.isEmpty
                  ? _buildEmptyState(context, ref)
                  : _buildGrid(context, ref, projects),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_outlined,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(loc.noProjectsYet,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            loc.createProjectHint,
            style:
                TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.create_new_folder_outlined, size: 18),
            label: Text(loc.createProject),
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(
      BuildContext context, WidgetRef ref, List<Project> projects) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount =
            (constraints.maxWidth / 220).floor().clamp(2, 5);
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.4,
          ),
          itemCount: projects.length,
          itemBuilder: (context, i) =>
              _ProjectCard(project: projects[i]),
        );
      },
    );
  }

  Future<void> _showCreateDialog(
      BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.newProject),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: loc.projNameHint,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(loc.btnCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(loc.btnCreate),
          ),
        ],
      ),
    );
    if (confirmed == true && controller.text.trim().isNotEmpty) {
      try {
        final repo = ref.read(projectRepositoryProvider);
        await repo.createProject(controller.text.trim());
        ref.invalidate(projectsProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.projCreateError('$e'))),
          );
        }
      }
    }
    controller.dispose();
  }
}

// ── Project Card ──────────────────────────────────────────────────────────────

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project});
  final Project project;

  bool get _hasCover =>
      project.coverDocumentId != null && project.coverType != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(
          '/projects/${project.id}?projectName=${Uri.encodeComponent(project.name)}',
        ),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: tokens.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.border),
          ),
          child: _hasCover
              ? _buildWithCover(context, ref)
              : _buildDefault(context, ref),
        ),
      ),
    );
  }

  Widget _buildDefault(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_rounded, size: 28, color: tokens.glow),
              const Spacer(),
              _ProjectMenu(project: project),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            project.name,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            loc.storageDocs(project.documentCount),
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildWithCover(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DocumentCover(
            coverType: project.coverType,
            coverValue: project.coverValue,
            documentId: project.coverDocumentId!,
            size: DocumentCoverSize.thumbnail,
            borderRadius: BorderRadius.zero,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loc.projDocShort(project.documentCount),
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              _ProjectMenu(project: project),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Project Context Menu ──────────────────────────────────────────────────────

class _ProjectMenu extends ConsumerWidget {
  const _ProjectMenu({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (value) async {
        switch (value) {
          case 'change_cover':
            await _showCoverPicker(context, ref);
            break;
          case 'rename':
            await _showRenameDialog(context, ref);
            break;
          case 'delete':
            await _confirmDelete(context, ref);
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'change_cover',
          child: Row(children: [
            const Icon(Icons.image_outlined, size: 18),
            const SizedBox(width: 8),
            Text(loc.docMenuChangeCover),
          ]),
        ),
        PopupMenuItem(
          value: 'rename',
          child: Row(children: [
            const Icon(Icons.edit_outlined, size: 18),
            const SizedBox(width: 8),
            Text(loc.docMenuRename),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            const SizedBox(width: 8),
            Text(loc.docMenuDelete, style: const TextStyle(color: Colors.red)),
          ]),
        ),
      ],
    );
  }

  Future<void> _showCoverPicker(
      BuildContext context, WidgetRef ref) async {
    final result = await showProjectCoverPickerDialog(
      context: context,
      ref: ref,
      projectId: project.id,
      currentCoverDocumentId: project.coverDocumentId,
    );
    if (result != null) {
      try {
        final repo = ref.read(projectRepositoryProvider);
        await repo.setProjectCover(project.id, result.documentId);
        ref.invalidate(projectsProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(AppLocalizations.of(context).rrCoverError('$e'))),
          );
        }
      }
    }
  }

  Future<void> _showRenameDialog(
      BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController(text: project.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.rrRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration:
              const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(loc.btnCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(loc.docMenuRename),
          ),
        ],
      ),
    );
    if (confirmed == true && controller.text.trim().isNotEmpty) {
      final repo = ref.read(projectRepositoryProvider);
      await repo.renameProject(project.id, controller.text.trim());
      ref.invalidate(projectsProvider);
    }
    controller.dispose();
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.rrDeleteTitle),
        content: Text(loc.rrDeleteBody(project.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(loc.btnCancel),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(loc.docMenuDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final repo = ref.read(projectRepositoryProvider);
      await repo.deleteProject(project.id);
      ref.invalidate(projectsProvider);
    }
  }
}
