import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/psitta_tokens.dart';
import '../../../data/providers/project_providers.dart';
import '../../../data/providers/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../project_cover_picker_dialog.dart';
import 'project_activity_feed.dart';

/// Project screen right rail: About, Project Actions, and an honest Activity
/// "Coming soon" card. Project actions reuse the existing dialogs/repository and
/// follow the existing invalidate-after-mutate pattern (project actions are not
/// routed through a controller).
class ProjectRightRail extends StatelessWidget {
  const ProjectRightRail({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  final String projectId;
  final String projectName;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 20, 20),
      children: [
        _AboutCard(projectId: projectId),
        const SizedBox(height: 16),
        _ProjectActions(projectId: projectId, projectName: projectName),
        const SizedBox(height: 16),
        _RailCard(
          title: AppLocalizations.of(context).rrActivity,
          child: ProjectActivityFeed(projectId: projectId, compact: true),
        ),
      ],
    );
  }
}

/// Shared card chrome for the rail.
class _RailCard extends StatelessWidget {
  const _RailCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(tokens.radius),
        border: Border.all(color: tokens.border.withOpacity(0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AboutCard extends ConsumerWidget {
  const _AboutCard({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectDetailProvider(projectId));
    final loc = AppLocalizations.of(context);
    return _RailCard(
      title: loc.rrAboutTitle,
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(
          loc.rrLoadError,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        data: (d) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description deferred (no backend field yet).
            _AboutRow(label: loc.rrCreated, value: _fmtDate(d.createdAt)),
            _AboutRow(label: loc.rrLastUpdated, value: _fmtDate(d.updatedAt)),
            _AboutRow(label: loc.rrTotalWords, value: '${d.totalWords}'),
            _AboutRow(label: loc.rrOwner, value: loc.rrOwnerYou),
          ],
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: TextStyle(fontSize: 12, color: muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectActions extends ConsumerWidget {
  const _ProjectActions({required this.projectId, required this.projectName});
  final String projectId;
  final String projectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = Theme.of(context).colorScheme.error;
    final loc = AppLocalizations.of(context);
    return _RailCard(
      title: loc.rrActionsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            key: const ValueKey('project-rename-button'),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(loc.docMenuRename),
            onPressed: () => _rename(context, ref),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('project-cover-button'),
            icon: const Icon(Icons.image_outlined, size: 18),
            label: Text(loc.docMenuChangeCover),
            onPressed: () => _changeCover(context, ref),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('project-delete-button'),
            icon: Icon(Icons.delete_outline, size: 18, color: error),
            label: Text(loc.docMenuDelete, style: TextStyle(color: error)),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController(text: projectName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.rrRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
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
      try {
        await ref
            .read(projectRepositoryProvider)
            .renameProject(projectId, controller.text.trim());
        ref.invalidate(projectDetailProvider(projectId));
        ref.invalidate(projectsProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.pdtRenameError('$e'))),
          );
        }
      }
    }
    controller.dispose();
  }

  Future<void> _changeCover(BuildContext context, WidgetRef ref) async {
    final result = await showProjectCoverPickerDialog(
      context: context,
      ref: ref,
      projectId: projectId,
      currentCoverDocumentId: null,
    );
    if (result == null) return;
    try {
      await ref
          .read(projectRepositoryProvider)
          .setProjectCover(projectId, result.documentId);
      ref.invalidate(projectsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).rrCoverError('$e'))),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.rrDeleteTitle),
        content: Text(loc.rrDeleteBody(projectName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(loc.btnCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(loc.docMenuDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(projectRepositoryProvider).deleteProject(projectId);
      ref.invalidate(projectsProvider);
      if (context.mounted) context.go('/projects');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.rrDeleteError('$e'))),
        );
      }
    }
  }
}

/// Honest "Coming soon" state for project activity — never fabricates events.
/// Shared by the rail's Activity card and the Activity tab stub.
class ProjectActivityComingSoon extends StatelessWidget {
  const ProjectActivityComingSoon({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.history_outlined, size: 28, color: muted),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context).rrActivitySoon,
          style: TextStyle(fontSize: 12, color: muted),
        ),
      ],
    );
  }
}

String _fmtDate(DateTime d) {
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)}';
}
