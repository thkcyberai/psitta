import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A "‹ Library › <current>" breadcrumb shown at the top of the screens reached
/// from the Library's quick cards (Projects, Book Structures, Trash, …). The
/// "Library" segment is tappable and returns to /library.
class LibraryBreadcrumb extends StatelessWidget {
  const LibraryBreadcrumb({super.key, required this.current});

  final String current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        InkWell(
          onTap: () => context.go('/library'),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left, size: 16, color: scheme.primary),
                Text('Library',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary)),
              ],
            ),
          ),
        ),
        Text('  ›  $current',
            style:
                TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}
