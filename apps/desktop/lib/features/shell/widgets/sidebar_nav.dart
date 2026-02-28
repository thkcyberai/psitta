import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/psitta_tokens.dart';

class SidebarNav extends StatelessWidget {
  final bool isCollapsed;

  const SidebarNav({super.key, required this.isCollapsed});

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);

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
              padding: const EdgeInsets.symmetric(vertical: 14),
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
                  icon: Icons.tune_outlined,
                  route: '/settings',
                ),
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
  final bool isCollapsed;

  const _BrandHeader({required this.isCollapsed});

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final theme = Theme.of(context);

    return SizedBox(
      height: 64,
      child: Row(
        children: [
          const SizedBox(width: 14),
          _GradientIcon(
            icon: Icons.auto_awesome,
            size: 22,
            isMuted: false,
            glow: tokens.glow,
          ),
          if (!isCollapsed) ...[
            const SizedBox(width: 12),
            Text(
              'Creator Studio',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryDark,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BrandFooter extends StatelessWidget {
  final bool isCollapsed;

  const _BrandFooter({required this.isCollapsed});

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 10 : 14,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: tokens.surface2,
        border: Border(top: BorderSide(color: tokens.divider, width: 1)),
      ),
      child: isCollapsed
          ? Center(
              child: Image.asset(
                'assets/branding/Logo.png',
                width: 34,
                height: 34,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth;
                final logoW = (maxW * 0.82).clamp(160.0, 260.0);
                final logoH = (logoW * 0.30).clamp(44.0, 72.0);

                return Center(
                  child: SizedBox(
                    width: logoW,
                    height: logoH,
                    child: Image.asset(
                      'assets/branding/Logo.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                );
              },
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

    final fg = isActive ? AppColors.textPrimaryDark : AppColors.textSecondaryDark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radius),
        onTap: () => context.go(route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: isActive ? tokens.inputFill : Colors.transparent,
            borderRadius: BorderRadius.circular(tokens.radius),
            border: isActive
                ? Border.all(color: tokens.border.withOpacity(0.50), width: 1)
                : null,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: tokens.glow.withOpacity(0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            children: [
              _GradientIcon(
                icon: icon,
                size: 20,
                isMuted: !isActive,
                glow: tokens.glow,
              ),
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

class _GradientIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool isMuted;
  final Color glow;

  const _GradientIcon({
    required this.icon,
    required this.size,
    required this.isMuted,
    required this.glow,
  });

  @override
  Widget build(BuildContext context) {
    final Color a = const Color(0xFF9B6BFF);
    final Color b = const Color(0xFF5B7CFF);

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isMuted
          ? [
              b.withOpacity(0.55),
              a.withOpacity(0.35),
            ]
          : [a, b],
    );

    return ShaderMask(
      shaderCallback: (rect) => gradient.createShader(rect),
      blendMode: BlendMode.srcIn,
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}
