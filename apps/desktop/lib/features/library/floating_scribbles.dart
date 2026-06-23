import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Floating "stick on top" scribbles.
///
/// A writer can pin any scribble so it floats as a small draggable sticky note
/// over EVERY Psitta screen (Writing Desk, Library, Projects, …). The overlay
/// is pass-through: empty space does not absorb pointer events, so only the
/// note cards are interactive and the app underneath keeps working.
///
/// v1 keeps pinned notes in memory (they clear on app restart). Persisting the
/// pinned set + positions to user-scoped preferences is an easy follow-up.

/// Pastel sticky-note colors, keyed by the backend color tag (mirrors
/// ScribblesScreen's palette).
const Map<String, Color> kFloatingNoteColors = {
  'yellow': Color(0xFFFFF1B8),
  'pink': Color(0xFFFAD1E0),
  'blue': Color(0xFFC9E7F5),
  'green': Color(0xFFCDEBD0),
  'purple': Color(0xFFE3D7F7),
};
const Color kFloatingNoteInk = Color(0xFF33312B);

const double _kFloatW = 214;
const double _kFloatH = 196;

/// A scribble currently pinned on top, with its on-screen position.
class FloatingNote {
  const FloatingNote({
    required this.id,
    required this.content,
    required this.color,
    required this.position,
  });

  final String id;
  final String content;
  final String color;
  final Offset position;

  FloatingNote copyWith({String? content, String? color, Offset? position}) =>
      FloatingNote(
        id: id,
        content: content ?? this.content,
        color: color ?? this.color,
        position: position ?? this.position,
      );
}

class FloatingScribblesNotifier extends StateNotifier<List<FloatingNote>> {
  FloatingScribblesNotifier() : super(const []);

  bool isPinned(String id) => state.any((n) => n.id == id);

  /// Pin a scribble (no-op if already pinned). New notes cascade slightly so
  /// they don't land exactly on top of each other.
  void pin(Map<String, dynamic> note) {
    final id = note['id'].toString();
    if (isPinned(id)) return;
    final step = state.length * 26.0;
    state = [
      ...state,
      FloatingNote(
        id: id,
        content: (note['content'] as String?) ?? '',
        color: (note['color'] as String?) ?? 'yellow',
        position: Offset(90 + step, 90 + step),
      ),
    ];
  }

  void toggle(Map<String, dynamic> note) {
    final id = note['id'].toString();
    if (isPinned(id)) {
      unpin(id);
    } else {
      pin(note);
    }
  }

  void unpin(String id) =>
      state = state.where((n) => n.id != id).toList(growable: false);

  /// Bring a note to the front (last in the list paints on top) while dragging.
  void raise(String id) {
    final idx = state.indexWhere((n) => n.id == id);
    if (idx < 0 || idx == state.length - 1) return;
    final n = state[idx];
    state = [...state.where((e) => e.id != id), n];
  }

  void move(String id, Offset delta, Size bounds) {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(position: _clamp(n.position + delta, bounds)) else n,
    ];
  }

  /// Reflect an edit made on the Scribbles wall into the floating copy.
  void update(String id, {String? content, String? color}) {
    if (!isPinned(id)) return;
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(content: content, color: color) else n,
    ];
  }

  Offset _clamp(Offset p, Size bounds) {
    final maxX = (bounds.width - _kFloatW).clamp(0.0, double.infinity);
    final maxY = (bounds.height - _kFloatH).clamp(0.0, double.infinity);
    return Offset(p.dx.clamp(0.0, maxX), p.dy.clamp(0.0, maxY));
  }
}

final floatingScribblesProvider =
    StateNotifierProvider<FloatingScribblesNotifier, List<FloatingNote>>(
  (ref) => FloatingScribblesNotifier(),
);

/// Pass-through overlay that paints every pinned note. Drop it into a Stack
/// (via Positioned.fill) above the app content. Empty regions are click-through
/// because a Stack reports no hit outside its children.
class FloatingScribblesLayer extends ConsumerWidget {
  const FloatingScribblesLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(floatingScribblesProvider);
    if (notes.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final n in notes)
              Positioned(
                left: n.position.dx,
                top: n.position.dy,
                child: _FloatingNoteCard(note: n, bounds: bounds),
              ),
          ],
        );
      },
    );
  }
}

class _FloatingNoteCard extends ConsumerWidget {
  const _FloatingNoteCard({required this.note, required this.bounds});

  final FloatingNote note;
  final Size bounds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(floatingScribblesProvider.notifier);
    final color = kFloatingNoteColors[note.color] ?? kFloatingNoteColors['yellow']!;
    final content = note.content.trim();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: _kFloatW,
        height: _kFloatH,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          children: [
            // Drag grip + unstick.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => notifier.raise(note.id),
              onPanUpdate: (d) => notifier.move(note.id, d.delta, bounds),
              child: MouseRegion(
                cursor: SystemMouseCursors.move,
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.only(left: 8, right: 2),
                  child: Row(
                    children: [
                      Icon(Icons.drag_indicator,
                          size: 16,
                          color: kFloatingNoteInk.withValues(alpha: 0.40)),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Unstick',
                        iconSize: 16,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => notifier.unpin(note.id),
                        icon: Icon(Icons.push_pin,
                            size: 16,
                            color: kFloatingNoteInk.withValues(alpha: 0.65)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
                child: SingleChildScrollView(
                  child: Text(
                    content.isEmpty ? 'Empty note' : content,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      color: content.isEmpty
                          ? kFloatingNoteInk.withValues(alpha: 0.45)
                          : kFloatingNoteInk,
                      fontStyle:
                          content.isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
