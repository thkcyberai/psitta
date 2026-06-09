import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/psitta_tokens.dart';
import '../../../data/models/blueprint.dart';
import '../../../data/providers/blueprint_providers.dart';
import '../blueprint_screen_state.dart';

/// Center pane: the selected blueprint's section tree (read-only in slice 4b;
/// per-section editing controls are added in 4c).
///
/// "Section" is the user-facing term; the code keeps the data layer's "part"
/// terminology (PartNode, [_PartTreeNode], selectedPartIdProvider).
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
      data: (detail) => _content(context, detail),
    );
  }

  Widget _content(BuildContext context, BlueprintDetail detail) {
    final tokens = PsittaTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Sections',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
                      for (final part in detail.parts)
                        _PartTreeNode(node: part, depth: 0),
                    ],
                  ),
          ),
        ],
      ),
    );
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
/// [PartNode.children]; expansion is local widget state.
class _PartTreeNode extends ConsumerStatefulWidget {
  const _PartTreeNode({required this.node, required this.depth});

  final PartNode node;
  final int depth;

  @override
  ConsumerState<_PartTreeNode> createState() => _PartTreeNodeState();
}

class _PartTreeNodeState extends ConsumerState<_PartTreeNode> {
  bool _expanded = true;

  static const double _baseIndent = 8;
  static const double _perDepth = 20;

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
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
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
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasChildren && _expanded)
          for (final child in node.children)
            _PartTreeNode(node: child, depth: widget.depth + 1),
      ],
    );
  }
}
