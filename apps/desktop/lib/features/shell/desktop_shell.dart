import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/keyboard/shortcuts.dart';
import 'app_shell.dart';

/// Sidebar collapsed state — persists across navigation.
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

/// Desktop Shell — persistent multi-pane layout.
///
/// The shell never rebuilds when navigating — only the content
/// area changes. Sidebar and player bar are persistent.
class DesktopShell extends ConsumerWidget {
  const DesktopShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCollapsed = ref.watch(sidebarCollapsedProvider);

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
          child: AppShell(
            content: child,
            isSidebarCollapsed: isCollapsed,
          ),
        ),
      ),
    );
  }
}
