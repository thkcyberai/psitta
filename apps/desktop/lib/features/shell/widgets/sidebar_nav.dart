import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/psitta_tokens.dart';

class SidebarNav extends StatelessWidget {
  final bool isCollapsed;

  const SidebarNav({super.key, required this.isCollapsed});

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface2,
        border: Border(right: BorderSide(color: tokens.divider, width: 1)),
      ),
      child: Column(
        children: [
          _BrandHeader(isCollapsed: isCollapsed),
          Divider(height: 1, color: tokens.divider),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: const [
                _NavItem(
                  label: 'Library',
                  icon: Icons.article_outlined,
                  route: '/library',
                ),
                _NavItem(
                  label: 'Player',
                  icon: Icons.play_circle_outline,
                  route: '/player',
                ),
                _NavItem(
                  label: 'Projects',
                  icon: Icons.folder_outlined,
                  route: '/projects',
                ),
                _NavItem(
                  label: 'Settings',
                  icon: Icons.settings_outlined,
                  route: '/settings',
                ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.divider),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 8),
                IconButton(
                  tooltip: isCollapsed ? 'Expand' : 'Collapse',
                  onPressed: () {
                    // Collapse state is owned by DesktopShell via provider.
                    // This widget stays stateless.
                    // The collapse button remains for UI continuity.
                  },
                  icon: Icon(
                    isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                    color: theme.iconTheme.color?.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  final bool isCollapsed;

  const _BrandHeader({required this.isCollapsed});

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final theme = Theme.of(context);

    return SizedBox(
      height: 72,
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.headphones, color: tokens.glow),
          if (!isCollapsed) ...[
            const SizedBox(width: 12),
            Text(
              'Psitta',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final String route;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).uri.toString();
    final isActive = location == route || location.startsWith('$route/');

    final fg = isActive
        ? Colors.white
        : theme.textTheme.bodyMedium?.color?.withOpacity(0.85);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radius),
        onTap: () => context.go(route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? tokens.inputFill : Colors.transparent,
            borderRadius: BorderRadius.circular(tokens.radius),
            border:
                isActive ? Border.all(color: tokens.border, width: 1) : null,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: tokens.glow.withOpacity(0.20),
                      blurRadius: 18,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
