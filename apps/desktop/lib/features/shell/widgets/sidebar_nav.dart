import 'package:flutter/material.dart';
import '../../../core/keyboard/shortcuts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';

/// Sidebar navigation — collapsible, persistent.
class SidebarNav extends StatelessWidget {
  final bool isCollapsed;

  const SidebarNav({super.key, required this.isCollapsed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentPath = GoRouterState.of(context).uri.toString();

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = isCollapsed || constraints.maxWidth < 150;

        return Container(
          color: isDark ? AppColors.sidebarDark : AppColors.sidebarLight,
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: narrow ? 12 : 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.headphones,
                        color: AppColors.primary,
                        size: narrow ? 28 : 24,
                      ),
                      if (!narrow) ...[
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Psitta',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),

              const SizedBox(height: 8),
              _NavItem(
                icon: Icons.library_books_outlined,
                activeIcon: Icons.library_books,
                label: 'Library',
                path: '/library',
                currentPath: currentPath,
                narrow: narrow,
              ),
              _NavItem(
                icon: Icons.play_circle_outline,
                activeIcon: Icons.play_circle,
                label: 'Player',
                path: '/player',
                currentPath: currentPath,
                narrow: narrow,
              ),
              _NavItem(
                icon: Icons.folder_open_outlined,
                activeIcon: Icons.folder_open,
                label: 'Projects',
                path: '/projects',
                currentPath: currentPath,
                narrow: narrow,
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: 'Settings',
                path: '/settings',
                currentPath: currentPath,
                narrow: narrow,
              ),

              const Spacer(),

              const Divider(height: 1),
              _CollapseButton(isCollapsed: isCollapsed),
            ],
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  final String currentPath;
  final bool narrow;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
    required this.currentPath,
    required this.narrow,
  });

  bool get _isActive => currentPath.startsWith(path);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _isActive ? AppColors.primary : theme.iconTheme.color;

    if (narrow) {
      return Tooltip(
        message: label,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: InkWell(
            onTap: () => context.go(path),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 44,
              decoration: _isActive
                  ? BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              child: Center(
                child: Icon(
                  _isActive ? activeIcon : icon,
                  color: color,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListTile(
        leading: Icon(
          _isActive ? activeIcon : icon,
          color: color,
          size: 22,
        ),
        title: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: _isActive ? FontWeight.w600 : FontWeight.w400,
            color: _isActive ? AppColors.primary : null,
          ),
        ),
        selected: _isActive,
        selectedTileColor: AppColors.primary.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        onTap: () => context.go(path),
      ),
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
          Actions.maybeInvoke(context, const ToggleSidebarIntent());
        },
      ),
    );
  }
}
