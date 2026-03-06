import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/state/now_reading.dart';
import '../../core/theme/psitta_tokens.dart';
import '../../data/services/audio_service.dart';
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

          // Now Playing strip
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: _NowPlayingStrip(crumb: crumb),
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

class _NowPlayingStrip extends ConsumerWidget {
  final String crumb;
  const _NowPlayingStrip({required this.crumb});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowReading = ref.watch(nowReadingTextProvider);
    final isPlaying = ref.watch(audioPlayingProvider).valueOrNull ?? false;
    final docTitle = ref.watch(currentDocTitleProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isActive = nowReading.trim().isNotEmpty;

    if (!isActive) {
      // Idle state — plain breadcrumb
      return Container(
        constraints: const BoxConstraints(maxWidth: 760),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          crumb,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
          ),
        ),
      );
    }

    // Active state — glowing Now Playing pill
    final tokens = PsittaTokens.of(context);
    final goldColor = tokens.glow;
    final glowColor = goldColor.withOpacity(isDark ? 0.35 : 0.20);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      constraints: const BoxConstraints(maxWidth: 760),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            goldColor.withOpacity(isDark ? 0.18 : 0.12),
            goldColor.withOpacity(isDark ? 0.08 : 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: goldColor.withOpacity(0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPlaying ? Icons.graphic_eq : Icons.music_note,
            size: 15,
            color: goldColor,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              nowReading.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: goldColor,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
