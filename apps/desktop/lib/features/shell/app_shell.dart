import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'widgets/player_bar.dart';
import 'widgets/sidebar_nav.dart';

/// AppShell — persistent desktop layout with header, sidebar, and player bar.
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
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // Main area: sidebar + content + optional right panel
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
                // Vertical divider
                const VerticalDivider(width: 1),
                // Content area with header
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 64,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 300,
                              height: 36,
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: searchHint,
                                  prefixIcon:
                                      const Icon(Icons.search, size: 18),
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(child: content),
                    ],
                  ),
                ),
                if (rightPanel != null) ...[
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: AppConstants.detailPanelMinWidth,
                    child: rightPanel,
                  ),
                ],
              ],
            ),
          ),
          // Player bar (persistent)
          const Divider(height: 1),
          const SizedBox(
            height: AppConstants.playerBarHeight,
            child: PlayerBar(),
          ),
        ],
      ),
    );
  }
}
