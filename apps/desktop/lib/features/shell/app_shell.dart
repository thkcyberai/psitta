import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme/psitta_tokens.dart';
import 'widgets/player_bar.dart';
import 'widgets/sidebar_nav.dart';

/// AppShell — persistent desktop layout with header, sidebar, optional right panel, and pinned player bar.
class AppShell extends StatelessWidget {
  final Widget content;
  final Widget? rightPanel;
  final String title;
  final String searchHint;
  final bool isSidebarCollapsed;

  const AppShell({
    super.key,
    required this.content,
    required this.isSidebarCollapsed,
    this.rightPanel,
    this.title = 'Psitta',
    this.searchHint = 'Search…',
  });

  @override
  Widget build(BuildContext context) {
    final sidebarWidth = isSidebarCollapsed
        ? AppConstants.sidebarCollapsedWidth
        : AppConstants.sidebarWidth;

    final tokens = PsittaTokens.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: tokens.backgroundGradient),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  // Sidebar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: sidebarWidth,
                    child: SidebarNav(isCollapsed: isSidebarCollapsed),
                  ),

                  VerticalDivider(width: 1, color: tokens.divider),

                  // Content area + header
                  Expanded(
                    child: Column(
                      children: [
                        _Header(
                          title: title,
                          searchHint: searchHint,
                          theme: theme,
                          tokens: tokens,
                        ),
                        Divider(height: 1, color: tokens.divider),
                        Expanded(child: content),
                      ],
                    ),
                  ),

                  if (rightPanel != null) ...[
                    VerticalDivider(width: 1, color: tokens.divider),
                    SizedBox(
                      width: AppConstants.detailPanelMinWidth,
                      child: rightPanel,
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

class _Header extends StatelessWidget {
  final String title;
  final String searchHint;
  final ThemeData theme;
  final PsittaTokens tokens;

  const _Header({
    required this.title,
    required this.searchHint,
    required this.theme,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
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
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
