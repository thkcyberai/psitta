import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/providers.dart';
import '../../data/repositories/project_repository.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Projects',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                FilledButton.icon(
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: const Text('New Project'),
                  onPressed: () => _showCreateDialog(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Group your documents into projects.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: projectsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (projects) => projects.isEmpty
                    ? _buildEmptyState(context, ref)
                    : _buildGrid(context, ref, projects),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_outlined,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('No projects yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Create a project to organize your documents.',
            style:
                TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.create_new_folder_outlined, size: 18),
            label: const Text('Create Project'),
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
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Project'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Project name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Create'),
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
            SnackBar(content: Text('Failed to create project: $e')),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(
          '/projects/${project.id}?projectName=${Uri.encodeComponent(project.name)}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.folder_outlined,
                      size: 28,
                      color: Theme.of(context).colorScheme.primary),
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
                '${project.documentCount} document${project.documentCount == 1 ? '' : 's'}',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Project Context Menu ──────────────────────────────────────────────────────

class _ProjectMenu extends ConsumerWidget {
  const _ProjectMenu({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (value) async {
        switch (value) {
          case 'rename':
            await _showRenameDialog(context, ref);
            break;
          case 'delete':
            await _confirmDelete(context, ref);
            break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'rename',
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 18),
            SizedBox(width: 8),
            Text('Rename'),
          ]),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 18, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete', style: TextStyle(color: Colors.red)),
          ]),
        ),
      ],
    );
  }

  Future<void> _showRenameDialog(
      BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: project.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Project'),
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rename'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project?'),
        content: Text(
          'Delete "${project.name}"? Documents will not be deleted, just removed from the project.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
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
