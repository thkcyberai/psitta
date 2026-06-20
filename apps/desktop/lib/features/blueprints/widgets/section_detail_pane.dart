import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/theme/psitta_tokens.dart';
import '../../../data/models/blueprint.dart';
import '../../../data/models/blueprint_enums.dart';
import '../../../data/providers/blueprint_providers.dart';
import '../../../data/providers/providers.dart';
import '../blueprint_screen_state.dart';
import 'blueprint_dialogs.dart';

/// Right pane: details + actions for the selected section (part). Uses only
/// data already in [BlueprintDetail] (name, description, children) plus the
/// existing mutation dialogs — no new backend.
class SectionDetailPane extends ConsumerWidget {
  const SectionDetailPane({super.key});

  static PartNode? _findNode(List<PartNode> nodes, String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
      final found = _findNode(n.children, id);
      if (found != null) return found;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final blueprintId = ref.watch(selectedBlueprintIdProvider);
    final partId = ref.watch(selectedPartIdProvider);

    final detail = blueprintId == null
        ? null
        : ref.watch(blueprintDetailProvider(blueprintId)).valueOrNull;
    final node = (detail == null || partId == null)
        ? null
        : _findNode(detail.parts, partId);

    if (detail == null || node == null) {
      return Container(
        color: tokens.surface,
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_outlined,
                size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('Select a section',
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('to see its details',
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    final owned = !detail.isSystem;
    final subCount = node.children.length;
    final hasDesc = node.description != null && node.description!.isNotEmpty;

    return Container(
      color: tokens.surface,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
      child: ListView(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                subCount > 0
                    ? Icons.folder_rounded
                    : Icons.description_outlined,
                size: 22,
                color: tokens.glow,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  node.name,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _label(context, 'DESCRIPTION'),
          const SizedBox(height: 6),
          Text(
            hasDesc ? node.description! : 'No description yet.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: hasDesc ? scheme.onSurface : scheme.onSurfaceVariant,
              fontStyle: hasDesc ? FontStyle.normal : FontStyle.italic,
            ),
          ),
          const SizedBox(height: 22),
          _label(context, 'IN THIS BOOK STRUCTURE'),
          const SizedBox(height: 8),
          _infoRow(context, Icons.account_tree_outlined, detail.name),
          const SizedBox(height: 8),
          _infoRow(
            context,
            Icons.subdirectory_arrow_right,
            '$subCount subsection${subCount == 1 ? '' : 's'}',
          ),
          if (owned) ...[
            const SizedBox(height: 24),
            _label(context, 'ACTIONS'),
            const SizedBox(height: 8),
            _ActionRow(
              icon: Icons.note_add_outlined,
              label: 'Add document',
              onTap: () => _addDocument(context, ref, detail.id, node),
            ),
            _ActionRow(
              icon: Icons.edit_outlined,
              label: 'Rename / edit',
              onTap: () => _edit(context, ref, detail.id, node),
            ),
            _ActionRow(
              icon: Icons.add,
              label: 'Add subsection',
              onTap: () => _addSub(context, ref, detail.id, node),
            ),
            _ActionRow(
              icon: Icons.delete_outline,
              label: 'Delete section',
              danger: true,
              onTap: () => _delete(context, ref, detail.id, node),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    String blueprintId,
    PartNode node,
  ) async {
    final result = await showSectionFormDialog(
      context,
      title: 'Edit Section',
      submitLabel: 'Save',
      initialName: node.name,
      initialDescription: node.description,
    );
    if (result == null || !context.mounted) return;
    await runBlueprintMutation(
      context,
      () => ref.read(blueprintActionsProvider).updatePart(
            blueprintId,
            node.id,
            name: result.name,
            description: result.description,
          ),
    );
  }

  Future<void> _addSub(
    BuildContext context,
    WidgetRef ref,
    String blueprintId,
    PartNode node,
  ) async {
    final result = await showSectionFormDialog(
      context,
      title: 'Add Subsection',
      submitLabel: 'Add',
    );
    if (result == null || !context.mounted) return;
    await runBlueprintMutation(
      context,
      () => ref.read(blueprintActionsProvider).createPart(
            blueprintId,
            name: result.name,
            description: result.description,
            parentPartId: node.id,
          ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    String blueprintId,
    PartNode node,
  ) async {
    final ok = await confirmDeleteDialog(
      context,
      title: 'Delete Section?',
      message:
          'Delete "${node.name}"? Any subsections beneath it are removed too.',
    );
    if (!ok || !context.mounted) return;
    await runBlueprintMutation(
      context,
      () => ref.read(blueprintActionsProvider).deletePart(blueprintId, node.id),
    );
    ref.read(selectedPartIdProvider.notifier).state = null;
  }

  // ── Add a document into this section ──────────────────────────────────────
  // New empty / Upload → funnel into a Project (the writer's home) → file the
  // document into it → place it in this section → open in the Writing Desk.
  // Shown only on owned Book Structures (templates hide the ACTIONS block).
  Future<void> _addDocument(
    BuildContext context,
    WidgetRef ref,
    String blueprintId,
    PartNode node,
  ) async {
    final kind = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Add a document to “${node.name}”'),
        children: [
          _addChoice(ctx, 'new', Icons.note_add_outlined,
              'New empty document', 'Start from a blank page'),
          _addChoice(ctx, 'upload', Icons.upload_file_outlined,
              'Upload a file', 'PDF, DOCX, TXT, MD or HTML'),
        ],
      ),
    );
    if (kind == null || !context.mounted) return;

    // Funnel into a Project — every file needs a home.
    final projectId = await _ensureProject(context, ref);
    if (projectId == null || !context.mounted) return;

    final repo = ref.read(documentRepositoryProvider);
    String? docId;
    try {
      if (kind == 'new') {
        final res = await repo.createBlankDocument();
        docId = res['id'];
      } else {
        final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: AppConstants.allowedExtensions,
        );
        final path = picked?.files.single.path;
        if (path == null) return;
        final doc = await repo.uploadDocument(path);
        docId = doc.id;
      }
    } on DioException catch (e) {
      if (context.mounted) {
        final msg = e.response?.statusCode == 402
            ? 'You’ve reached your monthly document limit.'
            : 'Couldn’t create the document.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
      return;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couldn’t create the document.')));
      }
      return;
    }
    if (docId == null) return;

    // File it into the project, then place it in this section.
    try {
      await repo.assignToProject(docId, projectId);
      await ref
          .read(blueprintActionsProvider)
          .setPlacement(docId, node.id, Role.mainContent);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Document created, but couldn’t place it here.')));
      }
    }

    ref.invalidate(documentsProvider);
    ref.invalidate(quotaUsageProvider);
    ref.invalidate(projectsProvider);
    ref.invalidate(blueprintDetailProvider(blueprintId));
    if (context.mounted) {
      context.go('/writing-desk/$docId?projectId=$projectId');
    }
  }

  Widget _addChoice(BuildContext ctx, String value, IconData icon,
          String title, String subtitle) =>
      SimpleDialogOption(
        onPressed: () => Navigator.of(ctx).pop(value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 22, color: Theme.of(ctx).colorScheme.primary),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      );

  /// Choose an existing Project or create one. Returns the project id, or null
  /// if cancelled. The '__new__' sentinel routes to the create-project prompt.
  Future<String?> _ensureProject(BuildContext context, WidgetRef ref) async {
    final projects = await ref.read(projectsProvider.future);
    if (!context.mounted) return null;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Put this in a Project'),
        children: [
          for (final p in projects)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(p.id),
              child: Text(p.name.isEmpty ? 'Untitled project' : p.name),
            ),
          if (projects.isNotEmpty) const Divider(height: 10),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('__new__'),
            child: Row(
              children: const [
                Icon(Icons.add, size: 18),
                SizedBox(width: 10),
                Text('Create New Project'),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return null;
    if (picked != '__new__') return picked;

    final name = await _promptProjectName(context);
    if (name == null || name.trim().isEmpty || !context.mounted) return null;
    final created =
        await ref.read(projectRepositoryProvider).createProject(name.trim());
    ref.invalidate(projectsProvider);
    return created.id;
  }

  Future<String?> _promptProjectName(BuildContext context) {
    final ctl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Project'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Project name'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(ctl.text),
              child: const Text('Create')),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? scheme.error : scheme.onSurface;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
