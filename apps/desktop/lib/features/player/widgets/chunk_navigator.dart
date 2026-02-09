import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

/// Chunk navigator — table of contents for the document.
///
/// Desktop-optimized: compact list items, hover effects,
/// active chunk highlighted with primary color accent.
/// Scrolls to keep active chunk visible during playback.
class ChunkNavigator extends StatelessWidget {
  final List<Map<String, String>> chunks;
  final int activeIndex;
  final ValueChanged<int> onChunkSelected;

  const ChunkNavigator({
    super.key,
    required this.chunks,
    required this.activeIndex,
    required this.onChunkSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: chunks.length,
      itemBuilder: (context, index) {
        final isActive = index == activeIndex;
        final chunk = chunks[index];

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: isActive ? AppColors.primary.withOpacity(0.1) : null,
          ),
          child: ListTile(
            dense: true,
            leading: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? AppColors.primary
                    : Colors.transparent,
                border: isActive
                    ? null
                    : Border.all(color: theme.dividerColor),
              ),
              child: Text(
                '${index + 1}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isActive ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            title: Text(
              chunk['title']!,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive ? AppColors.primary : null,
              ),
            ),
            subtitle: Text(
              chunk['preview']!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            selected: isActive,
            hoverColor: AppColors.primary.withOpacity(0.04),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            onTap: () => onChunkSelected(index),
          ),
        );
      },
    );
  }
}
