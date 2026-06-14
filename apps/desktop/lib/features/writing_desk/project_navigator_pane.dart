import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/psitta_tokens.dart';
import '../../data/models/blueprint.dart';
import '../../data/models/blueprint_enums.dart';
import '../../data/models/document.dart';
import '../../data/models/project_detail.dart';
import '../../data/models/psitta_document.dart' show PsittaDocument, DocBlock, DocBlockType;
import '../../data/providers/blueprint_providers.dart';
import '../../data/providers/project_providers.dart';
import '../../data/providers/providers.dart'
    show documentsProvider, projectRepositoryProvider;
import '../../data/repositories/project_repository.dart' show Project;
import '../player/widgets/docx_page_layout.dart'
    show paginateDocxDocument, DocxPageLayoutPage;
import '../player/widgets/docx_player_navigator.dart'
    show DocxPlayerNavigator, DocxNavigatorEntry;
import 'desk_providers.dart' show deskDocumentProvider;

/// Left-rail navigator for the Writing Desk.
///
/// Shows the project's blueprint structure alongside placed and unplaced
/// documents. The user can assign unplaced docs to sections directly from
/// here. [projectId] may be null when the screen is opened outside a project
/// context — the guard state handles that gracefully.
class ProjectNavigatorPane extends ConsumerStatefulWidget {
  const ProjectNavigatorPane({
    super.key,
    required this.documentId,
    this.projectId,
  });

  final String documentId;
  final String? projectId;

  @override
  ConsumerState<ProjectNavigatorPane> createState() =>
      _ProjectNavigatorPaneState();
}

class _ProjectNavigatorPaneState extends ConsumerState<ProjectNavigatorPane> {
  String? _selectedBlueprintId;

  @override
  Widget build(BuildContext context) {
    if (widget.projectId == null) {
      return _NoProjectNavigator(documentId: widget.documentId);
    }
    return _ProjectNavigatorBody(
      projectId: widget.projectId!,
      documentId: widget.documentId,
      selectedBlueprintId: _selectedBlueprintId,
      onBlueprintSelected: (id) => setState(() => _selectedBlueprintId = id),
    );
  }
}

// ── No-project navigator ──────────────────────────────────────────────────────
//
// Shown when a document has no project yet. Renders the same two-tile + placeholder
// frame as the project case. The left "Project" tile opens a flyover with a
// "Add to a project" action; the "Unassigned" tile is disabled until a project
// is assigned.

class _NoProjectNavigator extends ConsumerStatefulWidget {
  const _NoProjectNavigator({required this.documentId});

  final String documentId;

  @override
  ConsumerState<_NoProjectNavigator> createState() =>
      _NoProjectNavigatorState();
}

class _NoProjectNavigatorState extends ConsumerState<_NoProjectNavigator> {
  bool _flyoverOpen = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _projectLink = LayerLink();
  final LayerLink _disabledLink = LayerLink();

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  // ── Flyover helpers ─────────────────────────────────────────────────────────

  void _toggleFlyover() {
    if (_flyoverOpen) {
      _removeFlyover();
    } else {
      _openFlyover();
    }
  }

  void _removeFlyover() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _flyoverOpen = false);
  }

  void _openFlyover() {
    setState(() => _flyoverOpen = true);

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        final tokens = PsittaTokens.of(ctx);
        final scheme = Theme.of(ctx).colorScheme;
        final screenH = MediaQuery.of(ctx).size.height;

        return Stack(
          children: [
            // Full-area barrier — tap outside to dismiss.
            Positioned.fill(
              child: GestureDetector(
                onTap: _removeFlyover,
                behavior: HitTestBehavior.translucent,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            // Card anchored below the Project tile.
            CompositedTransformFollower(
              link: _projectLink,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 6),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: screenH * 0.60,
                  minWidth: 220,
                  maxWidth: 260,
                ),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: scheme.outlineVariant.withOpacity(0.3),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'This document isn\'t in a project yet.',
                              style: Theme.of(ctx).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurface),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'No blueprint.',
                              style: Theme.of(ctx).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                key: const ValueKey('desk-add-to-project'),
                                onPressed: () =>
                                    _showAddToProjectDialog(),
                                child: const Text('Add to a project'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  Future<void> _showAddToProjectDialog() async {
    final repo = ref.read(projectRepositoryProvider);
    List<Project> projects;
    try {
      projects = await repo.listProjects();
    } catch (_) {
      projects = [];
    }
    if (!mounted) return;

    final chosen = await showDialog<Project>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add to a project'),
        content: projects.isEmpty
            ? const Text('Create a project in the Projects tab first.')
            : SizedBox(
                width: 320,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final project in projects)
                      ListTile(
                        key: ValueKey('desk-project-pick-${project.id}'),
                        title: Text(project.name),
                        onTap: () => Navigator.of(ctx).pop(project),
                      ),
                  ],
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (chosen == null) return;
    if (!mounted) return;

    await repo.assignToProject(widget.documentId, chosen.id);
    ref.invalidate(documentsProvider);
    _removeFlyover();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: tokens.surface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Tiles row ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                // Project tile — opens "add to project" flyover.
                Expanded(
                  child: _NavTile(
                    key: const ValueKey('desk-nav-tile-noproject'),
                    isOpen: _flyoverOpen,
                    layerLink: _projectLink,
                    onTap: _toggleFlyover,
                    leadingIcon: Icon(
                      Icons.menu_book_outlined,
                      size: 18,
                      color: scheme.primary,
                    ),
                    label: 'Book',
                    tooltip: 'Book content — sections & pages',
                    tokens: tokens,
                    scheme: scheme,
                  ),
                ),
                const SizedBox(width: 10),
                // Unassigned tile — disabled until a project is assigned.
                Expanded(
                  child: Tooltip(
                    message: 'Add this document to a project first',
                    child: Opacity(
                      opacity: 0.45,
                      child: _NavTile(
                        key: const ValueKey(
                            'desk-nav-tile-noproject-unassigned'),
                        isOpen: false,
                        layerLink: _disabledLink,
                        onTap: () {},
                        leadingIcon: Icon(
                          Icons.layers_outlined,
                          size: 18,
                          color: scheme.secondary,
                        ),
                        label: 'Files',
                        tokens: tokens,
                        scheme: scheme,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Document thumbnails & contents ───────────────────────────
          Expanded(
            child: _DocumentThumbnailsContents(
              documentId: widget.documentId,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rail panel enum ───────────────────────────────────────────────────────────

enum _RailPanel { bookContent, addFile }

// ── Project navigator body ────────────────────────────────────────────────────

class _ProjectNavigatorBody extends ConsumerStatefulWidget {
  const _ProjectNavigatorBody({
    required this.projectId,
    required this.documentId,
    required this.selectedBlueprintId,
    required this.onBlueprintSelected,
  });

  final String projectId;
  final String documentId;
  final String? selectedBlueprintId;
  final void Function(String?) onBlueprintSelected;

  @override
  ConsumerState<_ProjectNavigatorBody> createState() =>
      _ProjectNavigatorBodyState();
}

class _ProjectNavigatorBodyState
    extends ConsumerState<_ProjectNavigatorBody> {
  // Which inline panel fills the rail. The two header tiles act as a
  // segmented toggle (no pop-overs): Book Content shows the blueprint
  // sections + the document's page thumbnails/contents; Add a File shows
  // the files waiting to be placed into a section.
  _RailPanel _panel = _RailPanel.bookContent;

  // When true the panel body is hidden (only the toggle bar shows). Clicking
  // the already-active toggle collapses; clicking either toggle re-opens.
  bool _collapsed = false;

  void _onToggle(_RailPanel panel) {
    setState(() {
      if (_panel == panel) {
        _collapsed = !_collapsed; // second click on the active tab → pull up
      } else {
        _panel = panel;
        _collapsed = false;
      }
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final overviewAsync =
        ref.watch(projectBlueprintOverviewProvider(widget.projectId));
    final docsAsync = ref.watch(projectDocumentsProvider(widget.projectId));
    final placementsAsync =
        ref.watch(projectPlacementsProvider(widget.projectId));

    // Merge the three async values: only render content when all are data.
    return overviewAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (overview) => docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (docs) => placementsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (placements) =>
              _buildContent(context, overview, docs, placements),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ProjectBlueprintOverview overview,
    List<Document> docs,
    List<ProjectPlacement> placements,
  ) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;

    final placedDocIds = placements.map((p) => p.documentId).toSet();
    final unplacedDocs =
        docs.where((d) => !placedDocIds.contains(d.id)).toList();

    // Resolve the active blueprint (selected → primary → first).
    final blueprints = overview.blueprints;
    BlueprintOverview? selected;
    if (blueprints.isNotEmpty) {
      selected = blueprints.firstWhere(
        (b) => b.id == widget.selectedBlueprintId,
        orElse: () => blueprints.firstWhere(
          (b) => b.isPrimary,
          orElse: () => blueprints.first,
        ),
      );
    }

    return ColoredBox(
      color: tokens.surface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Segmented toggle row ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: _NavTile(
                    key: const ValueKey('desk-nav-tile-blueprint'),
                    isOpen:
                        !_collapsed && _panel == _RailPanel.bookContent,
                    onTap: () => _onToggle(_RailPanel.bookContent),
                    leadingIcon: Icon(
                      Icons.menu_book_outlined,
                      size: 18,
                      color: scheme.primary,
                    ),
                    label: 'Book',
                    tooltip: 'Book content — sections & pages',
                    tokens: tokens,
                    scheme: scheme,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NavTile(
                    key: const ValueKey('desk-nav-tile-unassigned'),
                    isOpen: !_collapsed && _panel == _RailPanel.addFile,
                    onTap: () => _onToggle(_RailPanel.addFile),
                    leadingIcon: Icon(
                      Icons.layers_outlined,
                      size: 18,
                      color: scheme.secondary,
                    ),
                    label: 'Files',
                    tooltip: 'Files to place into a section',
                    badgeCount: unplacedDocs.length,
                    tokens: tokens,
                    scheme: scheme,
                  ),
                ),
              ],
            ),
          ),
          // ── Collapsible menu: SECTIONS for Book, FILES for Files ───────
          if (!_collapsed)
            Expanded(
              flex: 1,
              child: _panel == _RailPanel.bookContent
                  ? _BookContentPanel(
                      selected: selected,
                      blueprints: blueprints,
                      placements: placements,
                      docs: docs,
                      projectId: widget.projectId,
                      onBlueprintSelected: widget.onBlueprintSelected,
                    )
                  : _AddFilePanel(
                      unplacedDocs: unplacedDocs,
                      parts: selected?.parts ?? const [],
                      projectId: widget.projectId,
                    ),
            ),
          // ── Page thumbnails & contents — always visible (not collapsed
          //    by the toggle), sits below the menu. ───────────────────────
          Divider(height: 1, color: scheme.outline.withOpacity(0.15)),
          const _SectionHeader(
            key: ValueKey('desk-book-pages-header'),
            label: 'PAGES & CONTENTS',
          ),
          Expanded(
            flex: 1,
            child: _DocumentThumbnailsContents(
              documentId: widget.documentId,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Book Content panel (SECTIONS menu) ────────────────────────────────────────
//
// The collapsible "Book" menu: the project's blueprint section tree. The page
// thumbnails/contents live separately in the body and stay visible regardless
// of which toggle is active or whether the menu is collapsed.

class _BookContentPanel extends StatelessWidget {
  const _BookContentPanel({
    required this.selected,
    required this.blueprints,
    required this.placements,
    required this.docs,
    required this.projectId,
    required this.onBlueprintSelected,
  });

  final BlueprintOverview? selected;
  final List<BlueprintOverview> blueprints;
  final List<ProjectPlacement> placements;
  final List<Document> docs;
  final String projectId;
  final void Function(String?) onBlueprintSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (blueprints.length > 1)
          _BlueprintSelector(
            blueprints: blueprints,
            selectedId: selected?.id,
            onChanged: onBlueprintSelected,
          ),
        const _SectionHeader(
          key: ValueKey('desk-book-sections-header'),
          label: 'SECTIONS',
        ),
        Expanded(
          child: selected == null
              ? _NoBlueprintsHint()
              : _PartTree(
                  parts: selected!.parts,
                  placements: placements,
                  docs: docs,
                  unplacedDocs: const [],
                  projectId: projectId,
                ),
        ),
      ],
    );
  }
}

// ── Add a File panel ──────────────────────────────────────────────────────────
//
// Fills the rail with the files waiting to be placed into a section, each with
// an Assign action. Shows a muted hint when nothing is unplaced.

class _AddFilePanel extends StatelessWidget {
  const _AddFilePanel({
    required this.unplacedDocs,
    required this.parts,
    required this.projectId,
  });

  final List<Document> unplacedDocs;
  final List<PartOverviewNode> parts;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(
          key: ValueKey('desk-addfile-header'),
          label: 'FILES TO PLACE',
        ),
        Expanded(
          child: unplacedDocs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No files waiting to be placed.\n'
                      'Every file is already in a section.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    for (final doc in unplacedDocs)
                      _UnplacedDocTile(
                        key: ValueKey('desk-addfile-unplaced-${doc.id}'),
                        doc: doc,
                        parts: parts,
                        projectId: projectId,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ── Document thumbnails & contents ───────────────────────────────────────────
//
// Reuses paginateDocxDocument + DocxPlayerNavigator from the Reading Nook.
// Falls back to a muted placeholder while loading, on error, or when the
// document has no blocks yet (still processing).

class _DocumentThumbnailsContents extends ConsumerWidget {
  const _DocumentThumbnailsContents({required this.documentId});

  final String documentId;

  static Widget _placeholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.photo_library_outlined,
          size: 32,
          color: scheme.outline.withOpacity(0.4),
        ),
        const SizedBox(height: 8),
        Text(
          'Page thumbnails & contents',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.outline.withOpacity(0.55),
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(deskDocumentProvider(documentId)).when(
      loading: () => _placeholder(context),
      error: (_, __) => _placeholder(context),
      data: (PsittaDocument doc) {
        if (doc.blocks.isEmpty) return _placeholder(context);

        final pages = paginateDocxDocument(context, doc);

        // Build block→page map then extract heading entries, mirroring
        // player_screen.dart:3425-3427 and 3644-3660.
        final blockPageMap = <String, int>{
          for (final DocxPageLayoutPage page in pages)
            for (final DocBlock block in page.blocks)
              block.blockId: page.pageNumber,
        };
        final contents = <DocxNavigatorEntry>[
          for (final DocBlock block in doc.blocks)
            if (block.type == DocBlockType.heading)
              DocxNavigatorEntry(
                blockId: block.blockId,
                title: block.plainText,
                level: block.level ?? 1,
                pageNumber: blockPageMap[block.blockId] ?? 1,
              ),
        ];

        if (pages.isEmpty && contents.isEmpty) return _placeholder(context);

        return DocxPlayerNavigator(
          pages: pages,
          contents: contents,
          activePageNumber: 1,
        );
      },
    );
  }
}

// ── Nav tile ──────────────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  const _NavTile({
    super.key,
    required this.isOpen,
    required this.onTap,
    required this.leadingIcon,
    required this.label,
    required this.tokens,
    required this.scheme,
    this.layerLink,
    this.badgeCount,
    this.tooltip,
  });

  final bool isOpen;
  final LayerLink? layerLink;
  final VoidCallback onTap;
  final Widget leadingIcon;
  final String label;
  final int? badgeCount;
  final PsittaTokens tokens;
  final ColorScheme scheme;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final tile = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isOpen
              ? scheme.secondary.withOpacity(0.12)
              : tokens.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isOpen
                ? scheme.secondary.withOpacity(0.6)
                : scheme.outline.withOpacity(0.18),
            width: isOpen ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            leadingIcon,
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badgeCount != null && badgeCount! > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: scheme.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$badgeCount',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.secondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    Widget result = tile;
    final link = layerLink;
    if (link != null) {
      result = CompositedTransformTarget(link: link, child: result);
    }
    final tip = tooltip;
    if (tip != null && tip.isNotEmpty) {
      result = Tooltip(message: tip, child: result);
    }
    return result;
  }
}

// ── Blueprint selector ────────────────────────────────────────────────────────

class _BlueprintSelector extends StatelessWidget {
  const _BlueprintSelector({
    required this.blueprints,
    required this.selectedId,
    required this.onChanged,
  });

  final List<BlueprintOverview> blueprints;
  final String? selectedId;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: DropdownButtonFormField<String>(
        key: const ValueKey('desk-blueprint-selector'),
        value: selectedId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Blueprint',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(),
        ),
        items: blueprints
            .map((b) => DropdownMenuItem(
                  value: b.id,
                  child: Text(b.name, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

// ── No-blueprints hint ────────────────────────────────────────────────────────

class _NoBlueprintsHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No blueprints adopted.\nAdd one in the Blueprints tab.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ── Part tree ─────────────────────────────────────────────────────────────────

class _PartTree extends StatelessWidget {
  const _PartTree({
    required this.parts,
    required this.placements,
    required this.docs,
    required this.unplacedDocs,
    required this.projectId,
  });

  final List<PartOverviewNode> parts;
  final List<ProjectPlacement> placements;
  final List<Document> docs;
  final List<Document> unplacedDocs;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    _flatten(context, parts, items, 0);

    if (unplacedDocs.isNotEmpty) {
      items.add(const _SectionHeader(
        key: ValueKey('desk-unassigned-header'),
        label: 'Unassigned documents',
      ));
      for (final doc in unplacedDocs) {
        items.add(_UnplacedDocTile(
          key: ValueKey('desk-unplaced-${doc.id}'),
          doc: doc,
          parts: parts,
          projectId: projectId,
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      children: items,
    );
  }

  void _flatten(
    BuildContext context,
    List<PartOverviewNode> nodes,
    List<Widget> out,
    int depth,
  ) {
    for (final part in nodes) {
      final partPlacements =
          placements.where((p) => p.partId == part.id).toList();
      final partDocs = docs
          .where((d) => partPlacements.any((p) => p.documentId == d.id))
          .toList();
      out.add(_SectionTile(
        part: part,
        depth: depth,
        placements: partPlacements,
        docs: partDocs,
      ));
      _flatten(context, part.children, out, depth + 1);
    }
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

// ── Section tile ──────────────────────────────────────────────────────────────

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.part,
    required this.depth,
    required this.placements,
    required this.docs,
  });

  final PartOverviewNode part;
  final int depth;
  final List<ProjectPlacement> placements;
  final List<Document> docs;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('desk-section-${part.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: 12.0 + depth * 16.0,
            right: 12,
            top: 5,
            bottom: 5,
          ),
          child: Row(
            children: [
              _ReadinessDot(readiness: part.readiness),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  part.name,
                  key: ValueKey('desk-section-name-${part.id}'),
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (part.documentCount > 0)
                Text(
                  '${part.documentCount}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
            ],
          ),
        ),
        // Inline placed-doc sublist.
        for (final doc in docs)
          _PlacedDocTile(
            key: ValueKey('desk-placed-doc-${doc.id}'),
            doc: doc,
            placement:
                placements.firstWhere((p) => p.documentId == doc.id),
            indent: 12.0 + depth * 16.0 + 24,
          ),
      ],
    );
  }
}

// ── Readiness dot — derived from theme; no hardcoded decorative colors ────────

class _ReadinessDot extends StatelessWidget {
  const _ReadinessDot({required this.readiness});
  final Readiness readiness;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (readiness) {
      Readiness.ready => scheme.primary,
      Readiness.inProgress => scheme.secondary,
      Readiness.empty => scheme.outline.withOpacity(0.35),
      Readiness.unknown => scheme.outline.withOpacity(0.15),
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ── Placed doc tile ───────────────────────────────────────────────────────────

class _PlacedDocTile extends StatelessWidget {
  const _PlacedDocTile({
    super.key,
    required this.doc,
    required this.placement,
    required this.indent,
  });

  final Document doc;
  final ProjectPlacement placement;
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: indent, right: 12, top: 2, bottom: 2),
      child: Row(
        children: [
          Icon(Icons.article_outlined,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              doc.title,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            placement.role.wire,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Unplaced doc tile ─────────────────────────────────────────────────────────

class _UnplacedDocTile extends ConsumerWidget {
  const _UnplacedDocTile({
    super.key,
    required this.doc,
    required this.parts,
    required this.projectId,
  });

  final Document doc;
  final List<PartOverviewNode> parts;
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Icon(Icons.article_outlined,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              doc.title,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Tooltip(
            message: 'Assign to a section of the book',
            child: TextButton(
              key: ValueKey('desk-assign-${doc.id}'),
              onPressed: () => _showAssignDialog(context, ref),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Assign'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignDialog(
      BuildContext context, WidgetRef ref) async {
    final flat = <PartOverviewNode>[];
    _flattenParts(parts, flat);

    final chosen = await showDialog<PartOverviewNode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign to Section'),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final part in flat)
                ListTile(
                  key: ValueKey('desk-assign-section-${part.id}'),
                  title: Text(part.name),
                  onTap: () => Navigator.of(ctx).pop(part),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (chosen == null) return;
    if (!context.mounted) return;

    final actions = ref.read(blueprintActionsProvider);
    await actions.setPlacement(
      doc.id,
      chosen.id,
      Role.mainContent,
      projectId: projectId,
    );
  }

  void _flattenParts(List<PartOverviewNode> nodes, List<PartOverviewNode> out) {
    for (final n in nodes) {
      out.add(n);
      _flattenParts(n.children, out);
    }
  }
}
