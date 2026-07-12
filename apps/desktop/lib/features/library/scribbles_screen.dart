import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/psitta_tokens.dart';
import '../../data/providers/providers.dart';
import '../../widgets/library_breadcrumb.dart';
import 'floating_scribbles.dart';

/// Pastel sticky-note colors, keyed by the backend color tag.
const Map<String, Color> _kNoteColors = {
  'yellow': Color(0xFFFFF1B8),
  'pink': Color(0xFFFAD1E0),
  'blue': Color(0xFFC9E7F5),
  'green': Color(0xFFCDEBD0),
  'purple': Color(0xFFE3D7F7),
};
const Color _kNoteInk = Color(0xFF33312B);

/// Scribbles — a wall of colored sticky notes for quick idea capture.
class ScribblesScreen extends ConsumerWidget {
  const ScribblesScreen({super.key});

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    Map<String, dynamic>? note,
  }) async {
    final loc = AppLocalizations.of(context);
    final ctrl =
        TextEditingController(text: (note?['content'] as String?) ?? '');
    var color = (note?['color'] as String?) ?? 'yellow';
    if (!_kNoteColors.containsKey(color)) color = 'yellow';

    final result = await showDialog<({String content, String color})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(note == null ? loc.newScribble : loc.scribbleEdit),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ctrl,
                  maxLines: 5,
                  maxLength: 5000,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Jot an idea…',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final entry in _kNoteColors.entries)
                      GestureDetector(
                        onTap: () => setLocal(() => color = entry.key),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: entry.value,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == entry.key
                                  ? const Color(0xFF333333)
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(loc.btnCancel)),
            FilledButton(
              onPressed: () => Navigator.pop(
                  ctx, (content: ctrl.text.trim(), color: color)),
              child: Text(loc.btnSave),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    try {
      final api = ref.read(apiClientProvider);
      if (note == null) {
        await api.dio.post('/notes/',
            data: {'content': result.content, 'color': result.color});
      } else {
        await api.dio.patch('/notes/${note['id']}',
            data: {'content': result.content, 'color': result.color});
        // Keep a floating copy of this note in sync with the edit.
        ref.read(floatingScribblesProvider.notifier).update(
              note['id'].toString(),
              content: result.content,
              color: result.color,
            );
      }
      ref.invalidate(notesProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.scribbleSaveError)));
      }
    }
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, Map<String, dynamic> note) async {
    final loc = AppLocalizations.of(context);
    try {
      await ref.read(apiClientProvider).dio.delete('/notes/${note['id']}');
      ref.invalidate(notesProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.scribbleDeleteError)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final async = ref.watch(notesProvider);
    final pinnedIds =
        ref.watch(floatingScribblesProvider).map((n) => n.id).toSet();

    return Container(
      color: tokens.surface,
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LibraryBreadcrumb(current: loc.scribblesTitle),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.sticky_note_2_outlined,
                  size: 26, color: scheme.onSurface),
              const SizedBox(width: 10),
              Text(loc.scribblesTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _openEditor(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: Text(loc.newScribble),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(loc.scribblesSubtitle,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(loc.scribbleLoadError,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
              data: (notes) {
                if (notes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sticky_note_2_outlined,
                            size: 48,
                            color: scheme.onSurfaceVariant.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text(loc.noScribblesYet,
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  );
                }
                return SingleChildScrollView(
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      for (final note in notes)
                        _noteCard(context, ref, note,
                            pinnedIds.contains(note['id'].toString())),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteCard(BuildContext context, WidgetRef ref,
      Map<String, dynamic> note, bool isPinned) {
    final loc = AppLocalizations.of(context);
    final color = _kNoteColors[note['color']] ?? _kNoteColors['yellow']!;
    final content = (note['content'] as String?)?.trim() ?? '';
    return GestureDetector(
      onTap: () => _openEditor(context, ref, note: note),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 188,
          height: 188,
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  content.isEmpty ? loc.scribbleEmptyNote : content,
                  maxLines: 7,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: content.isEmpty
                        ? _kNoteInk.withOpacity(0.45)
                        : _kNoteInk,
                    fontStyle:
                        content.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: isPinned ? loc.scribbleUnstick : loc.scribbleStick,
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    onPressed: () => ref
                        .read(floatingScribblesProvider.notifier)
                        .toggle(note),
                    icon: Icon(
                      isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      color: _kNoteInk.withOpacity(isPinned ? 0.85 : 0.55),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: loc.btnDelete,
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    onPressed: () => _delete(context, ref, note),
                    icon: Icon(Icons.delete_outline,
                        color: _kNoteInk.withOpacity(0.6)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
