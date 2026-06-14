import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/state/now_reading.dart';
import '../../core/theme/psitta_tokens.dart';
import '../../data/providers/blueprint_providers.dart'
    show projectBlueprintOverviewProvider;
import '../../data/providers/project_providers.dart'
    show projectDetailProvider, projectPlacementsProvider;
import '../../data/providers/providers.dart'
    show documentRepositoryProvider, documentsProvider;
import '../../data/services/audio_service.dart';
import '../../data/services/preferences_service.dart';
import '../../features/writing_desk/desk_providers.dart'
    show DeskSaveState, deskDocumentProvider, deskSaveStateProvider;
import '../../widgets/user_avatar.dart';
import 'widgets/player_bar.dart';
import 'widgets/shortcuts_panel.dart';
import 'widgets/sidebar_nav.dart';
import 'widgets/writing_nav.dart';

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
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
                        _ContextHeader(tokens: tokens, isWritingShell: isWritingShell),
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
            Divider(height: 1, color: tokens.divider),
            const SizedBox(
              height: AppConstants.playerBarHeight,
              child: PlayerBar(),
            ),
          ],
        ),
      ),
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
    final uri = GoRouterState.of(context).uri;

    // ── Writing Desk header ───────────────────────────────────────────────────
    if (isWritingShell) {
      final segs = uri.pathSegments;
      final documentId = segs.length >= 2 && segs.first == 'writing-desk'
          ? segs[1]
          : null;

      final saveState = ref.watch(deskSaveStateProvider);
      final IconData saveIcon;
      final String saveLabel;
      final Color saveColor;
      switch (saveState) {
        case DeskSaveState.saving:
          saveIcon = Icons.sync;
          saveLabel = 'Saving…';
          saveColor = scheme.secondary;
        case DeskSaveState.editing:
          saveIcon = Icons.edit_outlined;
          saveLabel = 'Editing';
          saveColor = scheme.onSurfaceVariant;
        case DeskSaveState.saved:
          saveIcon = Icons.check_circle_outline;
          saveLabel = 'Saved';
          saveColor = scheme.primary;
      }

      int? wordCount;
      if (documentId != null) {
        final docAsync = ref.watch(deskDocumentProvider(documentId));
        wordCount = docAsync.valueOrNull?.blocks
            .map((b) => b.plainText)
            .join(' ')
            .split(RegExp(r'\s+'))
            .where((t) => t.isNotEmpty)
            .length;
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
          } else {
            // Unplaced: project's adopted blueprint, for consistency with the
            // PLACED IN card and Book panel (no section yet).
            final overview =
                ref.watch(projectBlueprintOverviewProvider(pid)).valueOrNull;
            final names =
                overview?.blueprints.map((b) => b.name).toList() ??
                    const <String>[];
            if (names.isNotEmpty) {
              crumbs.add(_Crumb(names.join(', '), '/blueprints'));
            }
          }
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
            // LEFT — title + breadcrumb (or subtitle)
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Writing Desk',
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
              ),
            ),
            const SizedBox(width: 16),
            const Spacer(),
            // Doc-specific right cluster — only on /writing-desk/:id
            if (documentId != null) ...[
              // a) Saved indicator
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(saveIcon, size: 16, color: saveColor),
                  const SizedBox(width: 4),
                  Text(
                    saveLabel,
                    style:
                        theme.textTheme.labelSmall?.copyWith(color: saveColor),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // b) Word count
              Text(
                wordCount != null
                    ? 'Word count $wordCount'
                    : 'Word count —',
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
                        .exportDocument(documentId);
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
                label: const Text('Export'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 0),
                ),
              ),
              const SizedBox(width: 6),
              // d) Share — placeholder SnackBar
              OutlinedButton.icon(
                key: const ValueKey('desk-share-btn'),
                onPressed: () =>
                    ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Sharing is coming soon.')),
                ),
                icon: const Icon(Icons.share_outlined, size: 16),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 0),
                ),
              ),
              const SizedBox(width: 10),
            ],
            // Always present: help, settings, avatar
            IconButton(
              tooltip: 'Keyboard Shortcuts (Ctrl+/)',
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const ShortcutsPanel(),
              ),
              icon: Icon(
                Icons.help_outline,
                size: 20,
                color: theme.iconTheme.color?.withOpacity(0.70),
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              tooltip: 'Settings',
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
                  label: const Text('Resume'),
                );
              },
            ),
          ],
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Keyboard Shortcuts (Ctrl+/)',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const ShortcutsPanel(),
            ),
            icon: Icon(
              Icons.help_outline,
              size: 20,
              color: theme.iconTheme.color?.withOpacity(0.70),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: 'Settings',
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

// ── Writing Desk breadcrumb ───────────────────────────────────────────────────

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
