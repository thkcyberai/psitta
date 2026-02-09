import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';

/// Sidebar navigation — collapsible, persistent.
///
/// Shows navigation items with icons and labels.
/// When collapsed, only icons are visible (tooltip on hover).
/// Active route is highlighted.
class SidebarNav extends StatelessWidget {
  final bool isCollapsed;

  const SidebarNav({super.key, required this.isCollapsed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentPath = GoRouterState.of(context).uri.toString();

    return Container(
      color: isDark ? AppColors.sidebarDark : AppColors.sidebarLight,
      child: Column(
        children: [
          // ── App header ─────────────────────────────────────
          SizedBox(
            height: 56,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? 12 : 20,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.headphones,
                    color: AppColors.primary,
                    size: isCollapsed ? 28 : 24,
                  ),
                  if (!isCollapsed) ...[
                    const SizedBox(width: 12),
                    Text(
                      'Psitta',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // ── Navigation items ───────────────────────────────
          const SizedBox(height: 8),
          _NavItem(
            icon: Icons.library_books_outlined,
            activeIcon: Icons.library_books,
            label: 'Library',
            path: '/library',
            currentPath: currentPath,
            isCollapsed: isCollapsed,
          ),
          _NavItem(
            icon: Icons.record_voice_over_outlined,
            activeIcon: Icons.record_voice_over,
            label: 'Voices',
            path: '/voices',
            currentPath: currentPath,
            isCollapsed: isCollapsed,
          ),
          _NavItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: 'Settings',
            path: '/settings',
            currentPath: currentPath,
            isCollapsed: isCollapsed,
          ),

          const Spacer(),

          // ── Collapse toggle ────────────────────────────────
          const Divider(height: 1),
          _CollapseButton(isCollapsed: isCollapsed),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  final String currentPath;
  final bool isCollapsed;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
    required this.currentPath,
    required this.isCollapsed,
  });

  bool get _isActive => currentPath.startsWith(path);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tile = ListTile(
      leading: Icon(
        _isActive ? activeIcon : icon,
        color: _isActive ? AppColors.primary : theme.iconTheme.color,
        size: 22,
      ),
      title: isCollapsed
          ? null
          : Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: _isActive ? FontWeight.w600 : FontWeight.w400,
                color: _isActive ? AppColors.primary : null,
              ),
            ),
      selected: _isActive,
      selectedTileColor: AppColors.primary.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 20 : 16,
        vertical: 0,
      ),
      onTap: () => context.go(path),
    );

    if (isCollapsed) {
      return Tooltip(message: label, child: tile);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: tile,
    );
  }
}

class _CollapseButton extends StatelessWidget {
  final bool isCollapsed;

  const _CollapseButton({required this.isCollapsed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: IconButton(
        icon: Icon(
          isCollapsed ? Icons.chevron_right : Icons.chevron_left,
          size: 20,
        ),
        tooltip: isCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
        onPressed: () {
          // Handled by ToggleSidebarIntent in desktop_shell.dart
          // but also support direct click
          Actions.maybeInvoke(context, const ToggleSidebarIntent());
        },
      ),
    );
  }
}
