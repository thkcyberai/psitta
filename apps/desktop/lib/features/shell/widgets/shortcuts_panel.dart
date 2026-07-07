import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Modal dialog showing all keyboard shortcuts.
class ShortcutsPanel extends StatelessWidget {
  const ShortcutsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedColor = isDark
        ? theme.colorScheme.onSurface.withOpacity(0.5)
        : theme.colorScheme.onSurface.withOpacity(0.45);
    final keyBg = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surfaceContainerHighest.withOpacity(0.7);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.keyboard_outlined, size: 22,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    loc.keyboardShortcuts,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // PLAYBACK
              _SectionHeader(label: loc.scSecPlayback, color: mutedColor),
              const SizedBox(height: 8),
              _ShortcutRow(keys: const ['Space'], label: loc.scPlayPause,
                  keyBg: keyBg, theme: theme),
              _ShortcutRow(keys: const ['Ctrl', '\u2192'], label: loc.scSkipForward,
                  keyBg: keyBg, theme: theme),
              _ShortcutRow(keys: const ['Ctrl', '\u2190'], label: loc.scSkipBackward,
                  keyBg: keyBg, theme: theme),

              const SizedBox(height: 16),

              // NAVIGATION
              _SectionHeader(label: loc.scSecNavigation, color: mutedColor),
              const SizedBox(height: 8),
              _ShortcutRow(keys: const ['Ctrl', '\\'], label: loc.scToggleSidebar,
                  keyBg: keyBg, theme: theme),
              _ShortcutRow(keys: const ['Ctrl', 'O'], label: loc.scUploadDocument,
                  keyBg: keyBg, theme: theme),
              _ShortcutRow(keys: const ['Ctrl', 'F'], label: loc.scSearchLibrary,
                  keyBg: keyBg, theme: theme),
              _ShortcutRow(keys: const ['Ctrl', '/'], label: loc.scThisHelpPanel,
                  keyBg: keyBg, theme: theme),

              const SizedBox(height: 16),

              // PLAYER
              _SectionHeader(label: loc.scSecPlayer, color: mutedColor),
              const SizedBox(height: 8),
              _ShortcutRow(keys: [loc.scRightClick], label: loc.scListenFromHere,
                  keyBg: keyBg, theme: theme),

              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(loc.actionClose),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: color,
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.keys,
    required this.label,
    required this.keyBg,
    required this.theme,
  });

  final List<String> keys;
  final String label;
  final Color keyBg;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Wrap(
              spacing: 4,
              children: keys.map((k) => _KeyCap(label: k, bg: keyBg, theme: theme)).toList(),
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label, required this.bg, required this.theme});
  final String label;
  final Color bg;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.3),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
