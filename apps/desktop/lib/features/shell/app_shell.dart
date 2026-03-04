import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/state/now_reading.dart';
import '../../core/theme/psitta_tokens.dart';
import 'widgets/player_bar.dart';
import 'widgets/sidebar_nav.dart';

/// AppShell — persistent desktop layout with header, sidebar, optional right panel, and pinned player bar.
class AppShell extends ConsumerWidget {
  final Widget content;
  final Widget? rightPanel;
  final bool isSidebarCollapsed;

  const AppShell({
    super.key,
    required this.content,
    required this.isSidebarCollapsed,
    this.rightPanel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sidebarWidth = isSidebarCollapsed
        ? AppConstants.sidebarCollapsedWidth
        : AppConstants.sidebarWidth;

    final tokens = PsittaTokens.of(context);

    // Right panel should never reserve width on the Player route.
    final uri = GoRouterState.of(context).uri;
    final isPlayerRoute =
        uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'player';
    final effectiveRightPanel = isPlayerRoute ? null : rightPanel;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: tokens.backgroundGradient),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: sidebarWidth,
                    child: SidebarNav(isCollapsed: isSidebarCollapsed),
                  ),
                  VerticalDivider(width: 1, color: tokens.divider),
                  Expanded(
                    child: Column(
                      children: [
                        _ContextHeader(tokens: tokens),
                        Divider(height: 1, color: tokens.divider),
                        Expanded(child: content),
                      ],
                    ),
                  ),
                  if (effectiveRightPanel != null) ...[
                    VerticalDivider(width: 1, color: tokens.divider),
                    SizedBox(
                      width: AppConstants.detailPanelMinWidth,
                      child: effectiveRightPanel,
                    ),
                  ],
                ],
              ),
            ),
            Divider(height: 1, color: tokens.divider),
            const SizedBox(
              height: AppConstants.playerBarHeight,
              child: PlayerBar(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextHeader extends ConsumerWidget {
  final PsittaTokens tokens;

  const _ContextHeader({required this.tokens});

  String _breadcrumbFromLocation(Uri uri) {
    final seg = uri.pathSegments;
    if (seg.isEmpty) return 'Library';

    String pretty(String s) =>
        s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

    final first = seg.first;
    if (first == 'library') return 'Library';
    if (first == 'player') {
      if (seg.length >= 2) return 'Player / ${seg[1]}';
      return 'Player';
    }
    if (first == 'projects') return 'Projects';
    if (first == 'settings') return 'Settings';
    return pretty(first);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final uri = GoRouterState.of(context).uri;

    final crumb = _breadcrumbFromLocation(uri);
    final nowReading = ref.watch(nowReadingTextProvider);

    final wallboard = nowReading.trim().isEmpty ? crumb : nowReading.trim();

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: tokens.headerSurface,
        border: Border(
          bottom: BorderSide(color: tokens.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Psitta',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 14),

          // Wallboard strip (one line, center)
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 760),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: tokens.inputFill,
                  borderRadius: BorderRadius.circular(tokens.radius),
                  border: Border.all(
                      color: tokens.border.withOpacity(0.40), width: 1),
                ),
                child: Text(
                  wallboard,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.92),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 14),
          Builder(
            builder: (context) {
              final activeDocId = ref.watch(activeDocumentIdProvider);
              return OutlinedButton.icon(
                onPressed: activeDocId == null
                    ? null
                    : () => context.go('/player/$activeDocId'),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Resume'),
              );
            },
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
            icon: Icon(
              Icons.settings_outlined,
              color: theme.iconTheme.color?.withOpacity(0.90),
            ),
          ),
        ],
      ),
    );
  }
}
