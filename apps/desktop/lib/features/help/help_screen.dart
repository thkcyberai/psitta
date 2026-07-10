import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shell/widgets/shortcuts_panel.dart';
import '../../l10n/app_localizations.dart';

const String _supportEmail = 'support@psitta.ai';

/// Help & Guides — written guidance and short videos for writers. Videos open in
/// the browser (url_launcher); their URLs are filled in as they are produced
/// (a null url renders a tidy "coming soon" state).
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.helpTitle,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            loc.helpSubtitle,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: ListView(
                  children: [
                    _HelpSection(
                      icon: Icons.rocket_launch_outlined,
                      title: loc.helpSecGettingStarted,
                      children: [
                        _GuideTile(
                          icon: Icons.bolt_outlined,
                          title: loc.helpGuideFirstBook,
                          body: loc.helpGuideFirstBookBody,
                        ),
                        _VideoTile(
                            title: loc.helpWatchGettingStarted, minutes: 3),
                      ],
                    ),
                    _HelpSection(
                      icon: Icons.account_tree_outlined,
                      title: loc.helpSecFourSystems,
                      children: [
                        _GuideTile(
                          icon: Icons.article_outlined,
                          title: loc.navLibrary,
                          body: loc.helpGuideLibraryBody,
                        ),
                        _GuideTile(
                          icon: Icons.account_tree_outlined,
                          title: loc.navBlueprints,
                          body: loc.helpGuideBlueprintsBody,
                        ),
                        _GuideTile(
                          icon: Icons.folder_outlined,
                          title: loc.navProjects,
                          body: loc.helpGuideProjectsBody,
                        ),
                        _GuideTile(
                          icon: Icons.edit_note_outlined,
                          title: loc.navWritingDesk,
                          body: loc.helpGuideDeskBody,
                        ),
                        _VideoTile(
                            title: loc.helpWatchFourSystems, minutes: 6),
                      ],
                    ),
                    _HelpSection(
                      icon: Icons.help_outline,
                      title: loc.helpSecFaq,
                      children: [
                        _FaqTile(q: loc.helpFaqQ1, a: loc.helpFaqA1),
                        _FaqTile(q: loc.helpFaqQ2, a: loc.helpFaqA2),
                        _FaqTile(q: loc.helpFaqQ3, a: loc.helpFaqA3),
                        _FaqTile(q: loc.helpFaqQ4, a: loc.helpFaqA4),
                      ],
                    ),
                    _HelpSection(
                      icon: Icons.support_agent_outlined,
                      title: loc.helpSecMore,
                      children: [
                        _ActionTile(
                          icon: Icons.mail_outline,
                          title: loc.helpContactSupport,
                          subtitle: _supportEmail,
                          onTap: _emailSupport,
                        ),
                        _ActionTile(
                          icon: Icons.keyboard_outlined,
                          title: loc.keyboardShortcuts,
                          subtitle: loc.helpViewShortcuts,
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => const ShortcutsPanel(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _emailSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: 'subject=Psitta Help',
    );
    await launchUrl(uri);
  }
}

/// A titled card grouping help rows. Matches the Settings card style.
class _HelpSection extends StatelessWidget {
  const _HelpSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outline.withValues(alpha: 0.14)),
          ...children,
        ],
      ),
    );
  }
}

class _GuideTile extends StatelessWidget {
  const _GuideTile({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A video row. Opens [url] in the browser when provided; otherwise shows a
/// "coming soon" state. Fill in URLs as the videos are produced.
class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.title, required this.minutes}) : url = null;

  final String title;
  final int minutes;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final loc = AppLocalizations.of(context);
    final available = url != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: scheme.primary.withValues(alpha: available ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: available
              ? () => launchUrl(Uri.parse(url!),
                  mode: LaunchMode.externalApplication)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    available ? Icons.play_arrow_rounded : Icons.hourglass_empty,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        available
                            ? loc.helpVideoMinutes(minutes)
                            : loc.helpVideoComingSoon,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (available)
                  Icon(Icons.open_in_new, size: 16, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.q, required this.a});

  final String q;
  final String a;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Text(
          q,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              a,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
