import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'player_bar.dart';

import '../../../core/keyboard/shortcuts.dart';
import '../../../core/theme/psitta_tokens.dart';
import '../../../shared/widgets/psitta_logo.dart';

class SidebarNav extends StatelessWidget {
  const SidebarNav({super.key, required this.isCollapsed});

  final bool isCollapsed;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);

    return Container(
      // Sidebar surface only. No special logo container styling.
      color: tokens.surface2,
      child: Column(
        children: [
          _BrandHeader(isCollapsed: isCollapsed),
          Divider(height: 1, color: tokens.divider),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 14),
              children: [
                _NavItem(
                    label: 'Library',
                    icon: Icons.article_outlined,
                    route: '/library',
                    isCollapsed: isCollapsed),
                _NavItem(
                    label: 'Player',
                    icon: Icons.play_circle_outline,
                    route: '/player',
                    isCollapsed: isCollapsed),
                _NavItem(
                    label: 'Projects',
                    icon: Icons.folder_outlined,
                    route: '/projects',
                    isCollapsed: isCollapsed),
                _NavItem(
                    label: 'Blueprints',
                    icon: Icons.account_tree_outlined,
                    route: '/blueprints',
                    isCollapsed: isCollapsed),
                _NavItem(
                    label: 'Voices',
                    icon: Icons.record_voice_over_outlined,
                    route: '/voices',
                    isCollapsed: isCollapsed),
                _NavItem(
                    label: 'Settings',
                    icon: Icons.tune_outlined,
                    route: '/settings',
                    isCollapsed: isCollapsed),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.divider),
          _BrandFooter(isCollapsed: isCollapsed),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.isCollapsed});

  final bool isCollapsed;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final theme = Theme.of(context);

    if (isCollapsed) {
      return SizedBox(
        height: 64,
        child: Center(
          child: IconButton(
            key: const ValueKey('reading-nav-toggle'),
            iconSize: 20,
            tooltip: 'Expand sidebar',
            icon: Icon(Icons.menu,
                color: theme.colorScheme.onSurface.withOpacity(0.7)),
            onPressed: () =>
                Actions.maybeInvoke(context, const ToggleSidebarIntent()),
          ),
        ),
      );
    }
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          const SizedBox(width: 14),
          _GradientIcon(
            icon: Icons.auto_awesome,
            size: 22,
            isMuted: false,
            a: theme.colorScheme.primary,
            b: tokens.glow,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'The Reading Nook',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withOpacity(0.92),
                letterSpacing: 0.2,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('reading-nav-toggle'),
            iconSize: 20,
            tooltip: 'Collapse sidebar',
            icon: Icon(Icons.menu_open,
                color: theme.colorScheme.onSurface.withOpacity(0.7)),
            onPressed: () =>
                Actions.maybeInvoke(context, const ToggleSidebarIntent()),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _BrandFooter extends StatelessWidget {
  const _BrandFooter({required this.isCollapsed});

  final bool isCollapsed;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // IMPORTANT: no decoration, no borderRadius, no border, no Card.
    // Just the image on the sidebar surface.
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 10 : 14,
        vertical: 14,
      ),
      color: tokens.surface2,
      child: isCollapsed
          ? Center(
              child: Image.asset(
                'assets/branding/psitta-bird.png',
                width: 46,
                height: 46,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            )
          : Center(
              child: Opacity(
                opacity: isDark ? 0.30 : 1.0,
                child: const PsittaLogo(
                  width: 240,
                  height: 80,
                ),
              ),
            ),
    );
  }
}

class _NavItem extends ConsumerWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.route,
    required this.isCollapsed,
  });

  final String label;
  final IconData icon;
  final String route;
  final bool isCollapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).uri.toString();
    final isActive = location == route || location.startsWith('$route/');

    final fg = isActive
        ? Colors.white
        : theme.colorScheme.onSurfaceVariant.withOpacity(0.85);

    final item = Padding(
      padding: EdgeInsets.symmetric(
          horizontal: isCollapsed ? 4 : 10, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radius),
        onTap: () {
          if (route == '/player') {
            final activeDocId = ref.read(activeDocumentIdProvider);
            if (activeDocId != null) {
              context.go('/player/$activeDocId?autoplay=0');
            }
            return;
          }
          context.go(route);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 8 : 12, vertical: 11),
          decoration: BoxDecoration(
            color: isActive
                ? tokens.inputFill.withOpacity(0.45)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(tokens.radius),
            border: isActive
                ? Border.all(color: tokens.border.withOpacity(0.65), width: 1)
                : null,
          ),
          child: isCollapsed
              ? Center(
                  child: _GradientIcon(
                    icon: icon,
                    size: 22,
                    isMuted: !isActive,
                    a: theme.colorScheme.primary,
                    b: tokens.glow,
                  ),
                )
              : Row(
            children: [
              _GradientIcon(
                icon: icon,
                size: 20,
                isMuted: !isActive,
                a: theme.colorScheme.primary,
                b: tokens.glow,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (isCollapsed) return Tooltip(message: label, child: item);
    return item;
  }
}

class _GradientIcon extends StatelessWidget {
  const _GradientIcon({
    required this.icon,
    required this.size,
    required this.isMuted,
    required this.a,
    required this.b,
  });

  final IconData icon;
  final double size;
  final bool isMuted;
  final Color a;
  final Color b;

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isMuted ? [a.withOpacity(0.55), b.withOpacity(0.35)] : [a, b],
    );

    return ShaderMask(
      shaderCallback: (rect) => gradient.createShader(rect),
      blendMode: BlendMode.srcIn,
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}
