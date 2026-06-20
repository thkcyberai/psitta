import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'player_bar.dart';

import '../../../core/keyboard/shortcuts.dart';
import '../../../core/theme/psitta_tokens.dart';
import '../../../shared/widgets/psitta_logo.dart';

/// Sidebar navigation for the Writing Nook shell.
///
/// Mirrors [SidebarNav] in structure but exposes the 8 Writing-specific
/// destinations.  Items can be statically disabled (Analytics — coming soon)
/// or dynamically disabled (Writing Desk — requires an active document).
class WritingNav extends StatelessWidget {
  const WritingNav({super.key, required this.isCollapsed});

  final bool isCollapsed;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);

    return Container(
      color: tokens.surface2,
      child: Column(
        children: [
          _WritingBrandHeader(isCollapsed: isCollapsed),
          Divider(height: 1, color: tokens.divider),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 14),
              children: [
                _WritingNavItem(
                  label: 'Library',
                  icon: Icons.article_outlined,
                  route: '/library',
                  isCollapsed: isCollapsed,
                ),
                _WritingNavItem(
                  label: 'Writing Desk',
                  icon: Icons.edit_note_outlined,
                  route: '/writing-desk',
                  isCollapsed: isCollapsed,
                ),
                _WritingNavItem(
                  label: 'Projects',
                  icon: Icons.folder_outlined,
                  route: '/projects',
                  isCollapsed: isCollapsed,
                ),
                _WritingNavItem(
                  label: 'Blueprints',
                  icon: Icons.account_tree_outlined,
                  route: '/blueprints',
                  isCollapsed: isCollapsed,
                ),
                _WritingNavItem(
                  label: 'Creative Nook',
                  icon: Icons.auto_awesome_outlined,
                  route: '/plan',
                  badge: 'Upgrade',
                  isCollapsed: isCollapsed,
                ),
                _WritingNavItem(
                  label: 'Voices',
                  icon: Icons.record_voice_over_outlined,
                  route: '/voices',
                  isCollapsed: isCollapsed,
                ),
                _WritingNavItem(
                  label: 'Analytics',
                  icon: Icons.bar_chart_outlined,
                  route: '/analytics',
                  enabled: false,
                  isCollapsed: isCollapsed,
                ),
                _WritingNavItem(
                  label: 'Settings',
                  icon: Icons.tune_outlined,
                  route: '/settings',
                  isCollapsed: isCollapsed,
                ),
                _WritingNavItem(
                  label: 'Help',
                  icon: Icons.help_outline,
                  route: '/help',
                  isCollapsed: isCollapsed,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.divider),
          _WritingBrandFooter(isCollapsed: isCollapsed),
        ],
      ),
    );
  }
}

// ── Brand header ─────────────────────────────────────────────────────────────

class _WritingBrandHeader extends StatelessWidget {
  const _WritingBrandHeader({required this.isCollapsed});

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
            key: const ValueKey('writing-nav-toggle'),
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
            icon: Icons.edit_outlined,
            size: 22,
            isMuted: false,
            a: theme.colorScheme.primary,
            b: tokens.glow,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'The Writing Nook',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withOpacity(0.92),
                letterSpacing: 0.2,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('writing-nav-toggle'),
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

// ── Brand footer ─────────────────────────────────────────────────────────────

class _WritingBrandFooter extends StatelessWidget {
  const _WritingBrandFooter({required this.isCollapsed});

  final bool isCollapsed;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

// ── Nav item ──────────────────────────────────────────────────────────────────

class _WritingNavItem extends ConsumerWidget {
  const _WritingNavItem({
    required this.label,
    required this.icon,
    required this.route,
    required this.isCollapsed,
    this.enabled = true,
    this.badge,
  });

  final String label;
  final IconData icon;
  final String route;
  final bool isCollapsed;

  /// When false the item renders greyed and non-tappable with a
  /// 'Coming soon' tooltip (e.g. Analytics).
  /// Writing Desk uses dynamic logic instead — see build().
  final bool enabled;

  /// Optional small chip label rendered to the right of the label
  /// (e.g. 'Upgrade' for the Creative Nook upsell entry).
  final String? badge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).uri.toString();

    // Always watch activeDocumentIdProvider so Writing Desk items rebuild
    // when a document is opened/closed.  Non-Writing-Desk items ignore the
    // value but the subscription is cheap and avoids conditional ref.watch.
    final activeDocId = ref.watch(activeDocumentIdProvider);

    // Writing Desk: enabled only when an active document is open.
    // Mirrors the Player item pattern in sidebar_nav.dart:172.
    final effectiveEnabled =
        route == '/writing-desk' ? (enabled && activeDocId != null) : enabled;

    final isActive = effectiveEnabled &&
        (location == route || location.startsWith('$route/'));

    final fg = !effectiveEnabled
        ? theme.colorScheme.onSurfaceVariant.withOpacity(0.32)
        : isActive
            ? Colors.white
            : theme.colorScheme.onSurfaceVariant.withOpacity(0.85);

    final item = Padding(
      padding: EdgeInsets.symmetric(
          horizontal: isCollapsed ? 4 : 8, vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radius),
        onTap: !effectiveEnabled
            ? null
            : () {
                if (route == '/writing-desk') {
                  // re-read: ref.watch value above may be stale at tap time.
                  final docId = ref.read(activeDocumentIdProvider);
                  if (docId != null) context.go('/writing-desk/$docId');
                  return;
                }
                context.go(route);
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 8 : 10, vertical: 7),
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
                    isMuted: !isActive || !effectiveEnabled,
                    a: effectiveEnabled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    b: effectiveEnabled
                        ? tokens.glow
                        : theme.colorScheme.outline,
                  ),
                )
              : Row(
            children: [
              _GradientIcon(
                icon: icon,
                size: 18,
                isMuted: !isActive || !effectiveEnabled,
                a: effectiveEnabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                b: effectiveEnabled
                    ? tokens.glow
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: fg,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              if (badge != null && effectiveEnabled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // Static disabled items (enabled == false) get a 'Coming soon' tooltip.
    // Dynamically disabled items (Writing Desk without an open doc) do not.
    if (!enabled) return Tooltip(message: 'Coming soon', child: item);
    if (isCollapsed) return Tooltip(message: label, child: item);
    return item;
  }
}

// ── Gradient icon (copied from sidebar_nav.dart) ──────────────────────────────

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
