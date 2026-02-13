import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/keyboard/shortcuts.dart';
import 'widgets/sidebar_nav.dart';
import 'widgets/player_bar.dart';

/// Sidebar collapsed state — persists across navigation.
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

/// Desktop Shell — persistent multi-pane layout.
///
/// Layout structure:
/// ┌──────────┬──────────────────────────────┐
/// │          │                              │
/// │ Sidebar  │       Content Area           │
/// │  (nav)   │   (swapped by GoRouter)      │
/// │          │                              │
/// │          │                              │
/// ├──────────┴──────────────────────────────┤
/// │              Player Bar                 │
/// └─────────────────────────────────────────┘
///
/// The shell never rebuilds when navigating — only the content
/// area changes. Sidebar and player bar are persistent.
class DesktopShell extends ConsumerWidget {
  final Widget child;

  const DesktopShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCollapsed = ref.watch(sidebarCollapsedProvider);
    final sidebarWidth = isCollapsed
        ? AppConstants.sidebarCollapsedWidth
        : AppConstants.sidebarWidth;

    return Shortcuts(
      shortcuts: psittaShortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          ToggleSidebarIntent: CallbackAction<ToggleSidebarIntent>(
            onInvoke: (_) {
              ref.read(sidebarCollapsedProvider.notifier).state = !isCollapsed;
              return null;
            },
          ),
          // Playback actions wired in player_bar.dart via ref
          // Upload action wired in library_screen.dart
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Column(
              children: [
                // ── Main area: sidebar + content ──────────────
                Expanded(
                  child: Row(
                    children: [
                      // Sidebar
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        width: sidebarWidth,
                        child: SidebarNav(isCollapsed: isCollapsed),
                      ),
                      // Vertical divider
                      const VerticalDivider(width: 1),
                      // Content area (from GoRouter)
                      Expanded(child: child),
                    ],
                  ),
                ),
                // ── Player bar (persistent) ──────────────────
                const Divider(height: 1),
                const SizedBox(
                  height: AppConstants.playerBarHeight,
                  child: PlayerBar(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
