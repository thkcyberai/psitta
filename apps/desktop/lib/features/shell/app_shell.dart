import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:country_flags/country_flags.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/i18n/working_language.dart';
import '../../l10n/app_localizations.dart';
import '../../core/state/now_reading.dart';
import '../../core/theme/psitta_tokens.dart';
import '../../data/providers/project_providers.dart'
    show projectDetailProvider, projectPlacementsProvider;
import '../../data/providers/blueprint_providers.dart'
    show blueprintsListProvider, blueprintDetailProvider;
import '../../data/providers/providers.dart'
    show
        billingStatusProvider,
        documentRepositoryProvider,
        documentsProvider,
        projectsProvider,
        quotaUsageProvider,
        archivedDocumentsProvider,
        notesProvider,
        recordingsProvider,
        storageUsageProvider,
        trashedDocumentsProvider,
        userProfileProvider,
        displayNameFromProfile;
import '../../data/services/audio_service.dart';
import '../../data/services/preferences_service.dart';
import '../library/floating_scribbles.dart';
import '../../features/writing_desk/desk_providers.dart'
    show deskDocumentProvider;
import '../../features/writing_desk/leave_guard.dart';
import '../../widgets/document_cover.dart';
import '../../widgets/export_options_dialog.dart';
import '../../widgets/user_avatar.dart';
import 'widgets/player_bar.dart';
import 'widgets/sidebar_nav.dart';
import 'widgets/writing_nav.dart';

/// Manual refresh from the top bar: re-fetch the data that drives the current
/// view and drop image/cover caches so anything changed server-side (covers,
/// docs, projects, plan, profile) is reflected immediately.
void _refreshAllData(WidgetRef ref) {
  DocumentCover.evictAllCache();
  PaintingBinding.instance.imageCache.clear();
  ref.invalidate(documentsProvider);
  ref.invalidate(projectsProvider);
  ref.invalidate(quotaUsageProvider);
  ref.invalidate(billingStatusProvider);
  ref.invalidate(userProfileProvider);
  ref.invalidate(storageUsageProvider);
  ref.invalidate(trashedDocumentsProvider);
  ref.invalidate(archivedDocumentsProvider);
  ref.invalidate(recordingsProvider);
  ref.invalidate(notesProvider);
}

/// AppShell — persistent desktop layout with header, sidebar, optional right panel, and pinned player bar.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.content,
    required this.isSidebarCollapsed,
    this.rightPanel,
    this.isWritingShell = false,
  });

  final Widget content;
  final Widget? rightPanel;
  final bool isSidebarCollapsed;
  final bool isWritingShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sidebarWidth = isSidebarCollapsed
        ? AppConstants.sidebarCollapsedWidth
        : AppConstants.sidebarWidth;

    final tokens = PsittaTokens.of(context);

    // Right panel should never reserve width on the Player route.
    final uri = GoRouterState.of(context).uri;
    final isPlayerRoute =
        uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'player';
    final effectiveRightPanel = isPlayerRoute ? null : rightPanel;

    // Writing Nook: the bottom player bar lives only in the Writing Desk, where
    // listening happens. Every other Writing-Nook screen (Library, Projects,
    // Blueprints, Voices, Settings) hides it. The Reading Nook is unchanged —
    // it keeps the bar on every screen.
    final isWritingDeskRoute = uri.pathSegments.isNotEmpty &&
        uri.pathSegments.first == 'writing-desk';
    final showPlayerBar = !isWritingShell || isWritingDeskRoute;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(gradient: tokens.backgroundGradient),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        width: sidebarWidth,
                        child: isWritingShell
                            ? WritingNav(isCollapsed: isSidebarCollapsed)
                            : SidebarNav(isCollapsed: isSidebarCollapsed),
                      ),
                      VerticalDivider(width: 1, color: tokens.divider),
                      Expanded(
                        child: Column(
                          children: [
                            _ContextHeader(
                                tokens: tokens, isWritingShell: isWritingShell),
                            Divider(height: 1, color: tokens.divider),
                            Expanded(child: content),
                          ],
                        ),
                      ),
                      if (effectiveRightPanel != null) ...[
                        VerticalDivider(width: 1, color: tokens.divider),
                        SizedBox(
                          width: AppConstants.detailPanelMinWidth,
                          child: effectiveRightPanel,
                        ),
                      ],
                    ],
                  ),
                ),
                if (showPlayerBar) ...[
                  Divider(height: 1, color: tokens.divider),
                  const SizedBox(
                    height: AppConstants.playerBarHeight,
                    child: PlayerBar(),
                  ),
                ] else if (isWritingShell) ...[
                  Divider(height: 1, color: tokens.divider),
                  _WritingStatusBar(tokens: tokens),
                ],
              ],
            ),
          ),
          // Pinned scribbles float over every screen. Pass-through: empty
          // space stays click-through, only the note cards are interactive.
          const Positioned.fill(child: FloatingScribblesLayer()),
        ],
      ),
    );
  }
}

/// Slim status bar shown along the bottom of Writing-Nook screens that don't
/// host the player bar (Library, Projects, Blueprints, Voices, Settings). Gives
/// the layout a finished, anchored edge and surfaces a couple of real shortcuts.
class _WritingStatusBar extends StatelessWidget {
  const _WritingStatusBar({required this.tokens});

  final PsittaTokens tokens;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant.withOpacity(0.85);
    final loc = AppLocalizations.of(context);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: tokens.headerSurface),
      child: Row(
        children: [
          Icon(Icons.menu_book_outlined,
              size: 13, color: tokens.glow.withOpacity(0.85)),
          const SizedBox(width: 8),
          Text(
            'The Writing Nook',
            style: TextStyle(
                fontSize: 11.5, color: muted, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          _hint(context, 'Ctrl F', loc.statusSearch, muted),
          const SizedBox(width: 16),
          _hint(context, 'Ctrl /', loc.statusShortcuts, muted),
        ],
      ),
    );
  }

  Widget _hint(BuildContext context, String keys, String label, Color muted) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: tokens.inputFill,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: tokens.border),
          ),
          child: Text(keys,
              style: TextStyle(
                  fontSize: 10, color: muted, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: muted)),
      ],
    );
  }
}

class _ContextHeader extends ConsumerWidget {
  const _ContextHeader({required this.tokens, this.isWritingShell = false});

  final PsittaTokens tokens;
  final bool isWritingShell;

  String _breadcrumbFromLocation(Uri uri) {
    final seg = uri.pathSegments;
    if (seg.isEmpty) return 'Library';

    String pretty(String s) =>
        s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

    final first = seg.first;
    if (first == 'library') return 'Library';
    if (first == 'player') {
      if (seg.length >= 2) return 'Player / ${seg[1]}';
      return 'Player';
    }
    if (first == 'projects') return 'Projects';
    if (first == 'settings') return 'Settings';
    return pretty(first);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final loc = AppLocalizations.of(context);
    final uri = GoRouterState.of(context).uri;

    // ── Writing Desk header ───────────────────────────────────────────────────
    if (isWritingShell) {
      final segs = uri.pathSegments;
      final documentId = segs.length >= 2 && segs.first == 'writing-desk'
          ? segs[1]
          : null;

      int? wordCount;
      int? paragraphCount;
      int? pageCount;
      if (documentId != null) {
        final blocks =
            ref.watch(deskDocumentProvider(documentId)).valueOrNull?.blocks;
        if (blocks != null) {
          wordCount = blocks
              .map((b) => b.plainText)
              .join(' ')
              .split(RegExp(r'\s+'))
              .where((t) => t.isNotEmpty)
              .length;
          // Paragraphs = non-empty content blocks.
          paragraphCount =
              blocks.where((b) => b.plainText.trim().isNotEmpty).length;
          // Page estimate: ~250 words per standard manuscript page.
          pageCount = wordCount == 0 ? 0 : (wordCount / 250).ceil();
        }
      }

      // Breadcrumb segments: Project › Blueprint › Section › FileName. Project
      // and Blueprint segments carry a route so they become clickable links;
      // section and file are plain. Empty list -> static subtitle.
      final crumbs = <_Crumb>[];
      if (documentId != null) {
        final docs = ref.watch(documentsProvider).valueOrNull;
        final doc = docs?.where((d) => d.id == documentId).firstOrNull;
        final pid = doc?.projectId;
        if (pid != null) {
          final projectName =
              ref.watch(projectDetailProvider(pid)).valueOrNull?.name;
          if (projectName != null) {
            crumbs.add(_Crumb(
              projectName,
              '/projects/$pid?projectName=${Uri.encodeComponent(projectName)}',
            ));
          }
          final placements =
              ref.watch(projectPlacementsProvider(pid)).valueOrNull;
          final pl = placements
              ?.where((p) => p.documentId == documentId)
              .firstOrNull;
          if (pl != null) {
            // Placed: file's blueprint (links to Blueprints) + section.
            crumbs.add(_Crumb(pl.blueprintName, '/blueprints'));
            crumbs.add(_Crumb(pl.partName));
          }
          // Unplaced: the file is in NO blueprint, so the breadcrumb is just
          // Project › FileName. It must not borrow the project's adopted
          // blueprints — that wrongly implied this file was placed in them.
        } else {
          // Opened from the Library (not in a project): show the return path.
          crumbs.add(_Crumb(loc.navLibrary, '/library'));
        }
        final fileName = doc?.title;
        if (fileName != null && fileName.isNotEmpty) {
          crumbs.add(_Crumb(fileName));
        }
      }

      return Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: tokens.headerSurface,
          border: Border(bottom: BorderSide(color: tokens.divider, width: 1)),
        ),
        child: Row(
          children: [
            // LEFT — route-aware title. The Writing Desk shows its own title +
            // breadcrumb; the Library renders its own large header so the top
            // bar stays clean there; every other section shows its name.
            // Expanded (not Flexible+Spacer) so the trailing icon cluster is
            // pinned to the far right identically on every sector.
            Expanded(
              child: Builder(
                builder: (context) {
                  if (documentId != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          loc.navWritingDesk,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (crumbs.isNotEmpty)
                          _DeskBreadcrumb(crumbs: crumbs)
                        else
                          Text(
                            'Write, edit, listen and perfect your story',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                      ],
                    );
                  }
                  final first = uri.pathSegments.isNotEmpty
                      ? uri.pathSegments.first
                      : 'library';
                  // Library: personalise with the writer's handle, e.g.
                  // "luisaao's Library". Falls back to plain "Library" while the
                  // profile loads or if no name is available.
                  if (first == 'library') {
                    final name = displayNameFromProfile(
                        ref.watch(userProfileProvider).valueOrNull);
                    return Text(
                      name.isEmpty ? loc.libraryTitle : loc.libraryOfUser(name),
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  }
                  // Screens that render their own large in-content header
                  // suppress the top-bar title so the heading isn't shown
                  // twice. Everything else (Settings, etc.) keeps it.
                  const ownsHeaderRoutes = {
                    'blueprints',
                    'voices',
                    'whispers',
                    'scribbles',
                    'projects',
                  };
                  if (ownsHeaderRoutes.contains(first)) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    _breadcrumbFromLocation(uri),
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            // Doc-specific right cluster — only on /writing-desk/:id
            if (documentId != null) ...[
              // Pages · paragraphs · words (pages + paragraphs before words)
              Text(
                wordCount != null
                    ? '${loc.deskPagesCount(pageCount!)}  ·  '
                        '${loc.deskParagraphsCount(paragraphCount!)}  ·  '
                        '${loc.deskWordsCount(wordCount)}'
                    : '—',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              // c) Export
              OutlinedButton.icon(
                key: const ValueKey('desk-export-btn'),
                onPressed: () async {
                  final docs = await ref.read(documentsProvider.future);
                  final doc =
                      docs.where((d) => d.id == documentId).firstOrNull;
                  if (doc == null) return;
                  if (!context.mounted) return;
                  final options = await showExportOptionsDialog(
                    context,
                    title: doc.title,
                    showScope: true,
                    // Full-book export endpoint lands in the next slice.
                    fullBookEnabled: false,
                  );
                  if (options == null) return;
                  if (!context.mounted) return;
                  if (options.fullBook) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Full-book export is coming soon.')),
                    );
                    return;
                  }
                  final savePath = await FilePicker.platform.saveFile(
                    dialogTitle: 'Save Document',
                    fileName: '${doc.title}.docx',
                    type: FileType.custom,
                    allowedExtensions: ['docx'],
                  );
                  if (savePath == null) return;
                  if (!context.mounted) return;
                  try {
                    final bytes = await ref
                        .read(documentRepositoryProvider)
                        .exportDocument(
                          documentId,
                          includeCover: options.includeCover,
                          includeFooter: options.includeFooter,
                        );
                    final finalPath = savePath.endsWith('.docx')
                        ? savePath
                        : '$savePath.docx';
                    await File(finalPath).writeAsBytes(bytes);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Saved to ${File(finalPath).parent.path}'),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Export failed: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.download, size: 16),
                label: Text(loc.btnExport),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 0),
                ),
              ),
              const SizedBox(width: 6),
              // Share — opens a mobile-style share sheet (Instagram, Reddit,
              // Substack, X, WhatsApp, email, …) plus "Save file" for manual
              // attachment.
              OutlinedButton.icon(
                key: const ValueKey('desk-share-btn'),
                onPressed: () async {
                  final docs = await ref.read(documentsProvider.future);
                  final doc =
                      docs.where((d) => d.id == documentId).firstOrNull;
                  if (doc == null) return;
                  String body = '';
                  try {
                    final psitta = await ref
                        .read(deskDocumentProvider(documentId).future);
                    body = psitta.blocks
                        .map((b) => b.plainText)
                        .where((t) => t.trim().isNotEmpty)
                        .join('\n\n');
                  } catch (_) {}
                  if (!context.mounted) return;
                  _showWritingShareSheet(
                    context,
                    ref,
                    documentId: documentId,
                    title: doc.title,
                    body: body,
                  );
                },
                icon: const Icon(Icons.share_outlined, size: 16),
                label: Text(loc.btnShare),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 0),
                ),
              ),
              const SizedBox(width: 10),
            ],
            // Always present: language, refresh, help, settings, avatar
            const _LanguageFlagBar(),
            const SizedBox(width: 10),
            IconButton(
              tooltip: loc.tooltipRefresh,
              onPressed: () => _refreshAllData(ref),
              icon: Icon(
                Icons.refresh,
                size: 20,
                color: theme.iconTheme.color?.withOpacity(0.70),
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              tooltip: loc.tooltipHelp,
              onPressed: () => context.go('/help'),
              icon: Icon(
                Icons.help_outline,
                size: 20,
                color: theme.iconTheme.color?.withOpacity(0.70),
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              tooltip: loc.navSettings,
              onPressed: () => context.go('/settings'),
              icon: Icon(
                Icons.settings_outlined,
                color: theme.iconTheme.color?.withOpacity(0.90),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => context.go('/settings'),
              child: const MouseRegion(
                cursor: SystemMouseCursors.click,
                child: UserAvatarWidget(size: 32),
              ),
            ),
          ],
        ),
      );
    }

    // ── Standard header (unchanged) ───────────────────────────────────────────
    final crumb = _breadcrumbFromLocation(uri);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: tokens.headerSurface,
        border: Border(
          bottom: BorderSide(color: tokens.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Psitta',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                ref.watch(selectedThemeNameProvider),
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Now Playing strip
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: _NowPlayingStrip(crumb: crumb),
            ),
          ),

          if (!isWritingShell) ...[
            const SizedBox(width: 14),
            Builder(
              builder: (context) {
                final activeDocId = ref.watch(activeDocumentIdProvider);
                return OutlinedButton.icon(
                  onPressed: activeDocId == null
                      ? null
                      : () => context.go('/player/$activeDocId'),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(loc.btnResume),
                );
              },
            ),
          ],
          const SizedBox(width: 10),
          const _LanguageFlagBar(),
          const SizedBox(width: 10),
          IconButton(
            tooltip: loc.tooltipRefresh,
            onPressed: () => _refreshAllData(ref),
            icon: Icon(
              Icons.refresh,
              size: 20,
              color: theme.iconTheme.color?.withOpacity(0.70),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: loc.tooltipHelp,
            onPressed: () => context.go('/help'),
            icon: Icon(
              Icons.help_outline,
              size: 20,
              color: theme.iconTheme.color?.withOpacity(0.70),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: loc.navSettings,
            onPressed: () => context.go('/settings'),
            icon: Icon(
              Icons.settings_outlined,
              color: theme.iconTheme.color?.withOpacity(0.90),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => context.go('/settings'),
            child: const MouseRegion(
              cursor: SystemMouseCursors.click,
              child: UserAvatarWidget(size: 32),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Working-language flag bar ─────────────────────────────────────────────────

/// The 5-flag working-language selector shown in the top bar.
///
/// Picking a flag sets the writer's working language: it switches the UI
/// locale AND resets the narration voice to that language's default, so the
/// whole product turns to the chosen language in one click. `pt-BR` and
/// `pt-PT` are separate flags that share the same `pt` UI strings but carry
/// different default voices.
class _LanguageFlagBar extends ConsumerWidget {
  const _LanguageFlagBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        WorkingLanguage.fromLocale(ref.watch(selectedLocaleProvider));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final lang in WorkingLanguage.bar)
          _FlagButton(
            lang: lang,
            selected: lang == current,
            onTap: () async {
              // Re-selecting the current flag is a no-op.
              if (lang == current) return;
              // Capture router + current location before any async gap.
              final router = GoRouter.of(context);
              final path = GoRouterState.of(context).uri.toString();
              // If the writer is mid-edit in the Desk, prompt to save before
              // switching languages. Cancel keeps the current language + doc.
              if (!await confirmLeaveWritingDesk(context)) return;
              if (!context.mounted) return;
              // Apply the language switch (UI locale + default narrator).
              ref.read(selectedLocaleProvider.notifier).setLocale(lang.locale);
              ref
                  .read(selectedVoiceIdProvider.notifier)
                  .select(lang.defaultVoiceId);
              // Server data localized via translate-on-serve must re-fetch
              // with the new X-Psitta-Language header on a language switch.
              ref.invalidate(blueprintsListProvider);
              ref.invalidate(blueprintDetailProvider);
              // Anti-mismatch: a language-A narrator must never read a
              // language-B document. Always drop the active playback session +
              // audio so a stale document/voice never lingers in the player bar
              // after a language change. If a document is currently open,
              // also return to the Library so the writer picks a same-language
              // document.
              await ref.read(audioServiceProvider).stop();
              ref.read(activeDocumentIdProvider.notifier).state = null;
              final onDocument = path.startsWith('/writing-desk') ||
                  path.startsWith('/player');
              if (onDocument && context.mounted) router.go('/library');
            },
          ),
      ],
    );
  }
}

class _FlagButton extends StatelessWidget {
  const _FlagButton({
    required this.lang,
    required this.selected,
    required this.onTap,
  });

  final WorkingLanguage lang;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: lang.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: selected ? 1.0 : 0.42,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected ? scheme.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: SizedBox(
              width: 22,
              height: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: CountryFlag.fromCountryCode(lang.countryCode),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Writing Desk breadcrumb ───────────────────────────────────────────────────

/// One target in the Writing Desk share sheet.
class _ShareTarget {
  const _ShareTarget(this.label, this.icon, this.color, this.onTap);
  final String label;
  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;
}

/// Opens a mobile-style share sheet for the open document. Because desktop
/// platforms have no system share sheet for web services, each target opens the
/// service's web composer with the text pre-filled where the platform supports
/// it (X, Reddit, WhatsApp, Telegram, email), and copies the text to the
/// clipboard for the ones that don't (Instagram, Substack, Facebook, LinkedIn).
void _showWritingShareSheet(
  BuildContext context,
  WidgetRef ref, {
  required String documentId,
  required String title,
  required String body,
}) {
  final loc = AppLocalizations.of(context);
  final full = body.trim().isEmpty ? title : '$title\n\n$body';
  String clip(int n) => full.length <= n ? full : '${full.substring(0, n)}…';

  final enc = Uri.encodeComponent(clip(1500));
  final encTitle = Uri.encodeComponent(title);
  final encBody = Uri.encodeComponent(clip(1400));

  Future<void> open(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\'t open that app.')),
      );
    }
  }

  Future<void> copyThenOpen(String url, String where) async {
    await Clipboard.setData(ClipboardData(text: full));
    await open(url);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Text copied — paste it into $where.')),
      );
    }
  }

  final targets = <_ShareTarget>[
    _ShareTarget(loc.shareCopyText, Icons.content_copy, const Color(0xFF6B7280),
        () async {
      await Clipboard.setData(ClipboardData(text: full));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.shareCopied)),
        );
      }
    }),
    _ShareTarget(loc.shareEmail, Icons.mail_outline, const Color(0xFF2563EB),
        () => open('mailto:?subject=$encTitle&body=$enc')),
    _ShareTarget('WhatsApp', Icons.chat, const Color(0xFF25D366),
        () => open('https://wa.me/?text=$enc')),
    _ShareTarget('Telegram', Icons.send, const Color(0xFF26A5E4),
        () => open('https://t.me/share/url?url=&text=$enc')),
    _ShareTarget('X', Icons.tag, const Color(0xFF111827),
        () => open('https://twitter.com/intent/tweet?text=$enc')),
    _ShareTarget('Reddit', Icons.forum_outlined, const Color(0xFFFF4500),
        () => open('https://www.reddit.com/submit?title=$encTitle&text=$encBody')),
    _ShareTarget('LinkedIn', Icons.work_outline, const Color(0xFF0A66C2),
        () => copyThenOpen('https://www.linkedin.com/feed/', 'LinkedIn')),
    _ShareTarget('Facebook', Icons.facebook, const Color(0xFF1877F2),
        () => copyThenOpen('https://www.facebook.com/', 'Facebook')),
    _ShareTarget('Substack', Icons.article_outlined, const Color(0xFFFF6719),
        () => copyThenOpen('https://substack.com/', 'your Substack post')),
    _ShareTarget(
        'Instagram', Icons.camera_alt_outlined, const Color(0xFFE1306C),
        () => copyThenOpen('https://www.instagram.com/', 'Instagram')),
    _ShareTarget(loc.shareSaveFile, Icons.folder_open_outlined,
        const Color(0xFF6B7280), () => _saveAndRevealDocx(context, ref, documentId)),
  ];

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.shareHeader(title),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                loc.shareSubtitle,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  for (final t in targets)
                    _ShareTargetButton(
                      target: t,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        t.onTap();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Circular icon + label tile in the share sheet.
class _ShareTargetButton extends StatelessWidget {
  const _ShareTargetButton({required this.target, required this.onTap});

  final _ShareTarget target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: InkWell(
        key: ValueKey('desk-share-target-${target.label}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: target.color.withOpacity(0.14),
                child: Icon(target.icon, size: 22, color: target.color),
              ),
              const SizedBox(height: 6),
              Text(
                target.label,
                style: Theme.of(context).textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Exports [documentId] to a DOCX in the user's Downloads folder and opens that
/// folder so the writer can attach the file manually (e.g. to email).
Future<void> _saveAndRevealDocx(
  BuildContext context,
  WidgetRef ref,
  String documentId,
) async {
  final docs = await ref.read(documentsProvider.future);
  final doc = docs.where((d) => d.id == documentId).firstOrNull;
  if (doc == null) return;
  if (!context.mounted) return;
  try {
    final bytes =
        await ref.read(documentRepositoryProvider).exportDocument(documentId);
    final dir =
        (await getDownloadsDirectory()) ?? (await getTemporaryDirectory());
    final safe = doc.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final fileName = safe.isEmpty ? 'document' : safe;
    final path = '${dir.path}${Platform.pathSeparator}$fileName.docx';
    await File(path).writeAsBytes(bytes);

    if (Platform.isWindows) {
      await Process.run('explorer', [dir.path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [dir.path]);
    } else {
      await Process.run('xdg-open', [dir.path]);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved "$fileName.docx" — opening its folder.')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Save failed: $e')),
    );
  }
}

/// One breadcrumb segment. A non-null [route] makes the segment a navigational
/// link; null renders it as plain text.
class _Crumb {
  const _Crumb(this.label, [this.route]);
  final String label;
  final String? route;
}

/// Renders the Writing Desk breadcrumb on one line. The visual design is
/// unchanged (same text, size, and color); segments with a route become
/// clickable (pointer cursor on hover) and navigate via go_router. Tap
/// recognizers are owned and disposed here to avoid leaks.
class _DeskBreadcrumb extends StatefulWidget {
  const _DeskBreadcrumb({required this.crumbs});
  final List<_Crumb> crumbs;

  @override
  State<_DeskBreadcrumb> createState() => _DeskBreadcrumbState();
}

class _DeskBreadcrumbState extends State<_DeskBreadcrumb> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base =
        theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    final spans = <InlineSpan>[];
    for (var i = 0; i < widget.crumbs.length; i++) {
      if (i > 0) {
        spans.add(TextSpan(text: '  ›  ', style: base));
      }
      final crumb = widget.crumbs[i];
      final route = crumb.route;
      if (route != null) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () => context.go(route);
        _recognizers.add(recognizer);
        spans.add(TextSpan(
          text: crumb.label,
          style: base,
          recognizer: recognizer,
          mouseCursor: SystemMouseCursors.click,
        ));
      } else {
        spans.add(TextSpan(text: crumb.label, style: base));
      }
    }

    return Text.rich(
      TextSpan(children: spans),
      key: const ValueKey('desk-breadcrumb'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _NowPlayingStrip extends ConsumerWidget {
  const _NowPlayingStrip({required this.crumb});
  final String crumb;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowReading = ref.watch(nowReadingTextProvider);
    final isPlaying = ref.watch(audioPlayingProvider).valueOrNull ?? false;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isActive = nowReading.trim().isNotEmpty;

    if (!isActive) {
      // Idle state — plain breadcrumb
      return Container(
        constraints: const BoxConstraints(maxWidth: 760),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          crumb,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
          ),
        ),
      );
    }

    // Active state — glowing Now Playing pill
    final tokens = PsittaTokens.of(context);
    final goldColor = tokens.glow;
    final glowColor = goldColor.withOpacity(isDark ? 0.35 : 0.20);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      constraints: const BoxConstraints(maxWidth: 760),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            goldColor.withOpacity(isDark ? 0.18 : 0.12),
            goldColor.withOpacity(isDark ? 0.08 : 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: goldColor.withOpacity(0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPlaying ? Icons.graphic_eq : Icons.music_note,
            size: 15,
            color: goldColor,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              nowReading.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: goldColor,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
