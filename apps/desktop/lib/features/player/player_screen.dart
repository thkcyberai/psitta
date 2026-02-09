import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../shell/widgets/player_bar.dart';
import 'widgets/chunk_navigator.dart';
import 'widgets/playback_controls.dart';

/// Player Screen — document playback with chunk navigation.
///
/// Desktop layout: two-pane view.
/// Left: chunk navigator (table of contents with active highlight).
/// Right: current chunk text with synchronized highlighting.
/// The persistent player bar at the bottom handles transport controls.
class PlayerScreen extends ConsumerStatefulWidget {
  final String documentId;

  const PlayerScreen({super.key, required this.documentId});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  int _activeChunkIndex = 0;

  // TODO: Replace with real data from PlaybackRepository
  final List<Map<String, String>> _chunks = [
    {'title': 'Abstract', 'preview': 'This paper presents a comprehensive overview...'},
    {'title': 'Introduction', 'preview': 'Recent advances in large language models...'},
    {'title': 'Background', 'preview': 'The field of AI safety has evolved...'},
    {'title': 'Methodology', 'preview': 'We conducted a systematic review of...'},
    {'title': 'Results', 'preview': 'Our analysis reveals three key findings...'},
    {'title': 'Discussion', 'preview': 'The implications of these results...'},
    {'title': 'Conclusion', 'preview': 'In summary, this work demonstrates...'},
    {'title': 'References', 'preview': '[1] Smith et al., 2024...'},
  ];

  @override
  void initState() {
    super.initState();
    // Set the player bar title when entering player
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentDocTitleProvider.notifier).state =
          'Document ${widget.documentId}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        // ── Chunk navigator (left pane) ────────────────────
        SizedBox(
          width: 280,
          child: Container(
            color: isDark ? AppColors.sidebarDark : AppColors.sidebarLight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Chapters',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ChunkNavigator(
                    chunks: _chunks,
                    activeIndex: _activeChunkIndex,
                    onChunkSelected: (index) {
                      setState(() => _activeChunkIndex = index);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),

        // ── Content area (right pane) ──────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chunk title
                Text(
                  _chunks[_activeChunkIndex]['title']!,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Chunk ${_activeChunkIndex + 1} of ${_chunks.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Chunk text content (scrollable)
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _chunks[_activeChunkIndex]['preview']! * 20,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.8,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
