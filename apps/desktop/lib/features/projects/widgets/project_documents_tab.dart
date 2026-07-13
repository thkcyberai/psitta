import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/plan_gate.dart';
import '../../../data/models/document.dart';
import '../../../data/providers/project_providers.dart';
import '../../../data/providers/providers.dart';
import '../../../data/providers/document_actions.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/document_cover.dart';
import '../../shell/widgets/player_bar.dart';

/// Documents tab — the project's document list with the existing per-document
/// menu (Rename / Move / Remove), cover leading, and play navigation. Ported
/// verbatim from the pre-tab project detail screen.
class ProjectDocumentsTab extends ConsumerWidget {
  const ProjectDocumentsTab({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  final String projectId;
  final String projectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(projectDocumentsProvider(projectId));
    return docsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text(AppLocalizations.of(context).bpTabError('$e'))),
      data: (docs) =>
          docs.isEmpty ? _buildEmptyState(context) : _buildDocList(context, ref, docs),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_outlined,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(loc.pdtEmptyTitle),
          const SizedBox(height: 8),
          Text(
            loc.pdtEmptyBody,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDocList(BuildContext context, WidgetRef ref, List<Document> docs) {
    return ListView.separated(
      itemCount: docs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final doc = docs[i];
        return ListTile(
          leading: _docLeading(doc),
          title: Text(doc.title),
          subtitle: Text(doc.status),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DocContextMenu(
                doc: doc,
                projectId: projectId,
                projectName: projectName,
              ),
              IconButton(
                icon: const Icon(Icons.play_circle_outline),
                tooltip: AppLocalizations.of(context).tipPlay,
                onPressed: () => _openInPlayer(context, ref, doc),
              ),
            ],
          ),
          onTap: () => _openInPlayer(context, ref, doc),
        );
      },
    );
  }

  void _openInPlayer(BuildContext context, WidgetRef ref, Document doc) {
    ref.read(activeDocumentIdProvider.notifier).state = doc.id;
    ref.read(currentDocTitleProvider.notifier).state = doc.title;
    final isWritingShell =
        ref.read(planStatusProvider).plan == 'writing_nook_pro';
    if (isWritingShell) {
      context.go('/writing-desk/${doc.id}?projectId=$projectId');
    } else {
      context.go(
        '/player/${doc.id}'
        '?origin=project'
        '&projectId=$projectId'
        '&projectName=${Uri.encodeComponent(projectName)}',
      );
    }
  }

  Widget _docLeading(Document doc) {
    if (doc.coverType != null) {
      return SizedBox(
        width: 36,
        height: 36,
        child: DocumentCover(
          coverType: doc.coverType,
          coverValue: doc.coverValue,
          documentId: doc.id,
          size: DocumentCoverSize.mini,
          sourceType: doc.sourceType,
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }
    final icon = switch (doc.sourceType) {
      'pdf' => Icons.picture_as_pdf_outlined,
      'docx' => Icons.article_outlined,
      'txt' => Icons.text_snippet_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
    return Icon(icon);
  }
}

// ── Document Context Menu (ported verbatim) ──────────────────────────────────

class _DocContextMenu extends ConsumerWidget {
  const _DocContextMenu({
    required this.doc,
    required this.projectId,
    required this.projectName,
  });

  final Document doc;
  final String projectId;
  final String projectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = Theme.of(context).colorScheme.error;
    final loc = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      tooltip: loc.tipMore,
      onSelected: (value) async {
        switch (value) {
          case 'open_desk':
            _openInWritingDesk(context);
            break;
          case 'rename':
            await _showRenameDialog(context, ref);
            break;
          case 'move':
            await _showMoveDialog(context, ref);
            break;
          case 'remove':
            await _confirmRemove(context, ref);
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'open_desk',
          child: Row(children: [
            const Icon(Icons.edit_note_outlined, size: 18),
            const SizedBox(width: 8),
            Text(loc.pdtOpenInDesk),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'rename',
          child: Row(children: [
            const Icon(Icons.edit_outlined, size: 18),
            const SizedBox(width: 8),
            Text(loc.docMenuRename),
          ]),
        ),
        PopupMenuItem(
          value: 'move',
          child: Row(children: [
            const Icon(Icons.drive_file_move_outlined, size: 18),
            const SizedBox(width: 8),
            Text(loc.docMenuMoveToProject),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'remove',
          child: Row(children: [
            Icon(Icons.delete_outlined, size: 18, color: error),
            const SizedBox(width: 8),
            Text(loc.btnRemove, style: TextStyle(color: error)),
          ]),
        ),
      ],
    );
  }

  void _openInWritingDesk(BuildContext context) {
    context.go('/writing-desk/${doc.id}?projectId=$projectId');
  }

  Future<void> _showRenameDialog(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController(text: doc.title);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.pdtRenameTitle),
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
        await ref.read(documentActionsProvider).renameDocument(doc.id, controller.text.trim());
        ref.invalidate(projectDocumentsProvider(projectId));
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

  Future<void> _showMoveDialog(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    List<Project> allProjects;
    try {
      final repo = ref.read(projectRepositoryProvider);
      allProjects = await repo.listProjects();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.pdtLoadProjectsError('$e'))),
        );
      }
      return;
    }

    final otherProjects = allProjects.where((p) => p.id != projectId).toList();
    if (otherProjects.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.pdtNoOtherProjects)),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final targetProject = await showDialog<Project>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.docMenuMoveToProject),
        content: SizedBox(
          width: 340,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: otherProjects.length,
            itemBuilder: (_, i) {
              final p = otherProjects[i];
              return ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(p.name),
                subtitle: Text(loc.storageDocs(p.documentCount)),
                onTap: () => Navigator.of(ctx).pop(p),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.btnCancel),
          ),
        ],
      ),
    );

    if (targetProject == null) return;

    try {
      await ref.read(documentActionsProvider).assignToProject(doc.id, targetProject.id);
      ref.invalidate(projectDocumentsProvider(projectId));
      ref.invalidate(projectsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.pdtMoveError('$e'))),
        );
      }
    }
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.docMenuRemoveFromProject),
        content: Text(loc.pdtRemoveBody(doc.title, projectName)),
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
            child: Text(loc.btnRemove),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(documentActionsProvider).assignToProject(doc.id, null);
        ref.invalidate(projectDocumentsProvider(projectId));
        ref.invalidate(projectsProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.pdtRemoveError('$e'))),
          );
        }
      }
    }
  }
}
