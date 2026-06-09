import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/psitta_tokens.dart';
import '../../../data/models/blueprint.dart';
import '../../../data/providers/blueprint_providers.dart';
import '../blueprint_screen_state.dart';
import 'blueprint_dialogs.dart';

/// Center pane: the selected blueprint's section tree, with editing for owned
/// blueprints and a clone action for system templates.
///
/// "Section" is the user-facing term; the code keeps the data layer's "part"
/// terminology (PartNode, [_PartTreeNode], selectedPartIdProvider). All
/// mutations funnel through blueprintActionsProvider via [runBlueprintMutation];
/// the UI never calls ref.invalidate.
class PartTreePane extends ConsumerWidget {
  const PartTreePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedBlueprintIdProvider);
    if (selectedId == null) {
      return const _Placeholder(
        icon: Icons.account_tree_outlined,
        message: 'Select a blueprint',
      );
    }

    final async = ref.watch(blueprintDetailProvider(selectedId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (detail) => _content(context, ref, detail),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, BlueprintDetail detail) {
    final tokens = PsittaTokens.of(context);
    final owned = !detail.isSystem;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sections',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (owned)
                ..._ownedHeaderActions(context, ref, detail)
              else
                FilledButton.icon(
                  key: const ValueKey('use-template-button'),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Use this Blueprint'),
                  onPressed: () => _useTemplate(context, ref, detail),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: tokens.divider),
          const SizedBox(height: 8),
          Expanded(
            child: detail.parts.isEmpty
                ? const _Placeholder(
                    icon: Icons.list_alt_outlined,
                    message: 'No sections yet',
                  )
                : ListView(
                    children: [
                      for (var i = 0; i < detail.parts.length; i++)
                        _PartTreeNode(
                          node: detail.parts[i],
                          depth: 0,
                          siblings: detail.parts,
                          index: i,
                          parentId: null,
                          grandparentId: null,
                          isOwned: owned,
                          blueprintId: detail.id,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _ownedHeaderActions(
    BuildContext context,
    WidgetRef ref,
    BlueprintDetail detail,
  ) {
    return [
      OutlinedButton.icon(
        key: const ValueKey('add-root-section-button'),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add Section'),
        onPressed: () => _addRootSection(context, ref, detail),
      ),
      const SizedBox(width: 8),
      IconButton(
        key: const ValueKey('edit-blueprint-button'),
        tooltip: 'Edit blueprint',
        icon: const Icon(Icons.edit_outlined),
        onPressed: () => _editBlueprint(context, ref, detail),
      ),
      IconButton(
        key: const ValueKey('delete-blueprint-button'),
        tooltip: 'Delete blueprint',
        icon: Icon(Icons.delete_outline,
            color: Theme.of(context).colorScheme.error),
        onPressed: () => _deleteBlueprint(context, ref, detail),
      ),
    ];
  }

  Future<void> _useTemplate(
    BuildContext context,
    WidgetRef ref,
    BlueprintDetail detail,
  ) async {
    final clone = await runBlueprintMutation(
      context,
      () => ref.read(blueprintActionsProvider).cloneBlueprint(detail.id),
    );
    if (clone != null) {
      ref.read(selectedBlueprintIdProvider.notifier).state = clone.id;
      ref.read(selectedPartIdProvider.notifier).state = null;
    }
  }

  Future<void> _editBlueprint(
    BuildContext context,
    WidgetRef ref,
    BlueprintDetail detail,
  ) async {
    final result = await showBlueprintFormDialog(
      context,
      title: 'Edit Blueprint',
      submitLabel: 'Save',
      initialName: detail.name,
      initialGenre: detail.genre,
      initialStatus: detail.status,
    );
    if (result == null) return;
    if (!context.mounted) return;
    await runBlueprintMutation(
      context,
      () => ref.read(blueprintActionsProvider).updateBlueprint(
            detail.id,
            name: result.name,
            genre: result.genre,
            status: result.status,
          ),
    );
  }

  Future<void> _addRootSection(
    BuildContext context,
    WidgetRef ref,
    BlueprintDetail detail,
  ) async {
    final result = await showSectionFormDialog(
      context,
      title: 'Add Section',
      submitLabel: 'Add',
    );
    if (result == null) return;
    if (!context.mounted) return;
    await runBlueprintMutation(
      context,
      () => ref.read(blueprintActionsProvider).createPart(
            detail.id,
            name: result.name,
            description: result.description,
          ),
    );
  }

  Future<void> _deleteBlueprint(
    BuildContext context,
    WidgetRef ref,
    BlueprintDetail detail,
  ) async {
    final ok = await confirmDeleteDialog(
      context,
      title: 'Delete Blueprint?',
      message:
          'Delete "${detail.name}"? Its sections will be permanently removed.',
    );
    if (!ok || !context.mounted) return;
    final result = await runBlueprintMutation(
      context,
      () async {
        await ref.read(blueprintActionsProvider).deleteBlueprint(detail.id);
        return true;
      },
    );
    if (result == true) {
      // Drop the now-deleted selection; the list pane re-selects the first row.
      ref.read(selectedBlueprintIdProvider.notifier).state = null;
      ref.read(selectedPartIdProvider.notifier).state = null;
    }
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 14),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

/// One section row plus (when expanded) its descendants. Recursive over
/// [PartNode.children]; expansion is local state. Per-row editing controls
/// render only for owned blueprints. The sibling list + index + parent ids let
/// each row compute reorder/nest targets locally.
class _PartTreeNode extends ConsumerStatefulWidget {
  const _PartTreeNode({
    required this.node,
    required this.depth,
    required this.siblings,
    required this.index,
    required this.parentId,
    required this.grandparentId,
    required this.isOwned,
    required this.blueprintId,
  });

  final PartNode node;
  final int depth;
  final List<PartNode> siblings;
  final int index;
  final String? parentId;
  final String? grandparentId;
  final bool isOwned;
  final String blueprintId;

  @override
  ConsumerState<_PartTreeNode> createState() => _PartTreeNodeState();
}

class _PartTreeNodeState extends ConsumerState<_PartTreeNode> {
  bool _expanded = true;

  static const double _baseIndent = 8;
  static const double _perDepth = 20;

  BlueprintActions get _actions => ref.read(blueprintActionsProvider);
  PartNode get _node => widget.node;

  bool get _canMoveUp => widget.index > 0;
  bool get _canMoveDown => widget.index < widget.siblings.length - 1;
  bool get _canIndent => widget.index > 0;
  bool get _canOutdent => widget.parentId != null;

  Future<void> _moveUp() async {
    // Land after the sibling two positions up, or first under the parent.
    final afterId =
        widget.index >= 2 ? widget.siblings[widget.index - 2].id : null;
    await runBlueprintMutation(
      context,
      () => _actions.updatePart(widget.blueprintId, _node.id, afterPartId: afterId),
    );
  }

  Future<void> _moveDown() async {
    final afterId = widget.siblings[widget.index + 1].id;
    await runBlueprintMutation(
      context,
      () => _actions.updatePart(widget.blueprintId, _node.id, afterPartId: afterId),
    );
  }

  Future<void> _indent() async {
    // Nest under the previous sibling (append to the end of its children).
    final newParent = widget.siblings[widget.index - 1].id;
    await runBlueprintMutation(
      context,
      () => _actions.updatePart(widget.blueprintId, _node.id,
          parentPartId: newParent),
    );
  }

  Future<void> _outdent() async {
    // Become a sibling of the current parent, positioned right after it.
    await runBlueprintMutation(
      context,
      () => _actions.updatePart(
        widget.blueprintId,
        _node.id,
        parentPartId: widget.grandparentId,
        afterPartId: widget.parentId,
      ),
    );
  }

  Future<void> _addSubsection() async {
    final result = await showSectionFormDialog(
      context,
      title: 'Add Subsection',
      submitLabel: 'Add',
    );
    if (result == null || !mounted) return;
    await runBlueprintMutation(
      context,
      () => _actions.createPart(
        widget.blueprintId,
        name: result.name,
        description: result.description,
        parentPartId: _node.id,
      ),
    );
  }

  Future<void> _editSection() async {
    final result = await showSectionFormDialog(
      context,
      title: 'Edit Section',
      submitLabel: 'Save',
      initialName: _node.name,
      initialDescription: _node.description,
    );
    if (result == null || !mounted) return;
    await runBlueprintMutation(
      context,
      () => _actions.updatePart(
        widget.blueprintId,
        _node.id,
        name: result.name,
        description: result.description,
      ),
    );
  }

  Future<void> _deleteSection() async {
    final ok = await confirmDeleteDialog(
      context,
      title: 'Delete Section?',
      message:
          'Delete this section? Any subsections beneath it are removed too.',
    );
    if (!ok || !mounted) return;
    await runBlueprintMutation(
      context,
      () => _actions.deletePart(widget.blueprintId, _node.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final tokens = PsittaTokens.of(context);
    final theme = Theme.of(context);
    final hasChildren = node.children.isNotEmpty;
    final isSelected = ref.watch(selectedPartIdProvider) == node.id;
    final description = node.description;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          key: ValueKey('part-pad-${node.id}'),
          padding: EdgeInsets.only(
            left: _baseIndent + widget.depth * _perDepth,
            top: 1,
            bottom: 1,
          ),
          child: Material(
            color: isSelected
                ? tokens.inputFill.withOpacity(0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () =>
                  ref.read(selectedPartIdProvider.notifier).state = node.id,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: hasChildren
                          ? IconButton(
                              key: ValueKey('part-caret-${node.id}'),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 24, minHeight: 24),
                              iconSize: 18,
                              icon: Icon(
                                _expanded
                                    ? Icons.expand_more
                                    : Icons.chevron_right,
                              ),
                              onPressed: () =>
                                  setState(() => _expanded = !_expanded),
                            )
                          : null,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            node.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (description != null && description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.isOwned) _rowControls(),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasChildren && _expanded)
          for (var i = 0; i < node.children.length; i++)
            _PartTreeNode(
              node: node.children[i],
              depth: widget.depth + 1,
              siblings: node.children,
              index: i,
              parentId: node.id,
              grandparentId: widget.parentId,
              isOwned: widget.isOwned,
              blueprintId: widget.blueprintId,
            ),
      ],
    );
  }

  Widget _rowControls() {
    final id = widget.node.id;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ctl('part-moveup-$id', Icons.arrow_upward, 'Move up',
            _canMoveUp ? _moveUp : null),
        _ctl('part-movedown-$id', Icons.arrow_downward, 'Move down',
            _canMoveDown ? _moveDown : null),
        _ctl('part-outdent-$id', Icons.format_indent_decrease, 'Outdent',
            _canOutdent ? _outdent : null),
        _ctl('part-indent-$id', Icons.format_indent_increase, 'Indent',
            _canIndent ? _indent : null),
        _ctl('part-add-$id', Icons.add, 'Add subsection', _addSubsection),
        PopupMenuButton<String>(
          key: ValueKey('part-menu-$id'),
          icon: const Icon(Icons.more_vert, size: 16),
          tooltip: 'More',
          onSelected: (v) {
            if (v == 'edit') _editSection();
            if (v == 'delete') _deleteSection();
          },
          itemBuilder: (context) {
            final error = Theme.of(context).colorScheme.error;
            return [
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Edit'),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, size: 18, color: error),
                  const SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: error)),
                ]),
              ),
            ];
          },
        ),
      ],
    );
  }

  Widget _ctl(
    String key,
    IconData icon,
    String tooltip,
    Future<void> Function()? onPressed,
  ) {
    return IconButton(
      key: ValueKey(key),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      iconSize: 16,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}
