import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/concept_style.dart';
import '../../core/theme/psitta_tokens.dart';
import '../../data/models/blueprint.dart';
import '../../data/models/blueprint_enums.dart';
import '../../data/models/document.dart';
import '../../data/models/project_detail.dart';
import '../../data/providers/blueprint_providers.dart';
import '../../data/providers/project_providers.dart';
import '../../data/providers/providers.dart'
    show documentsProvider, projectRepositoryProvider;
import '../../data/repositories/project_repository.dart' show Project;
import '../blueprints/widgets/blueprint_dialogs.dart'
    show showSectionFormDialog, confirmDeleteDialog, runBlueprintMutation;
import '../projects/widgets/adopt_blueprint_dialog.dart';

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
                              'No Book Structure.',
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
          const Spacer(),
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
          // ── Menu fills the panel: SECTIONS for Book, FILES for Files ───
          if (!_collapsed)
            Expanded(
              child: _panel == _RailPanel.bookContent
                  ? _BookContentPanel(
                      documentId: widget.documentId,
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
            )
          else
            const Spacer(),
          // ── Blueprint progress — pinned to the panel bottom ────────────
          if (overview.progress != null)
            _NavProgressFooter(progress: overview.progress!),
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

class _BookContentPanel extends ConsumerWidget {
  const _BookContentPanel({
    required this.documentId,
    required this.selected,
    required this.blueprints,
    required this.placements,
    required this.docs,
    required this.projectId,
    required this.onBlueprintSelected,
  });

  final String documentId;
  final BlueprintOverview? selected;
  final List<BlueprintOverview> blueprints;
  final List<ProjectPlacement> placements;
  final List<Document> docs;
  final String projectId;
  final void Function(String?) onBlueprintSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    final placedIds = placements.map((p) => p.documentId).toSet();
    final unplaced =
        docs.where((d) => !placedIds.contains(d.id)).toList();

    // The blueprint belongs to the PROJECT, not to an unplaced file. If the file
    // currently open isn't placed in any section, don't show the project's
    // blueprint structure as if this file were part of it — show a "place this
    // file" prompt instead (mirrors the right-rail PLACED IN "Not assigned").
    final currentFilePlaced =
        placements.any((p) => p.documentId == documentId);
    if (selected != null && !currentFilePlaced) {
      return _FileNotPlacedPanel(
        documentId: documentId,
        blueprints: blueprints,
        projectId: projectId,
      );
    }

    void chooseBlueprint() => adoptBlueprintFlow(
          context,
          ref,
          projectId: projectId,
          adoptedIds: blueprints.map((b) => b.id).toSet(),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (blueprints.length > 1)
          _BlueprintSelector(
            blueprints: blueprints,
            selectedId: selected?.id,
            onChanged: onBlueprintSelected,
          )
        else if (selected != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
            child: Row(
              children: [
                Icon(DeskConcept.blueprint.icon,
                    size: 16, color: DeskConcept.blueprint.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    selected!.name,
                    key: const ValueKey('desk-book-blueprint-name'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        // SECTIONS header with an inline "Choose a Blueprint" action.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'SECTIONS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                ),
              ),
              Tooltip(
                message: 'Choose a Book Structure for this project',
                child: InkWell(
                  key: const ValueKey('desk-add-blueprint'),
                  onTap: chooseBlueprint,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: scheme.primary),
                        const SizedBox(width: 2),
                        Text(
                          'Book Structure',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: selected == null
              ? _NoBlueprintAdopt(onAdd: chooseBlueprint)
              : _PartTree(
                  parts: selected!.parts,
                  placements: placements,
                  docs: docs,
                  unplacedDocs: unplaced,
                  projectId: projectId,
                  blueprintId: selected!.id,
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Row(
        children: [
          Icon(DeskConcept.blueprint.icon,
              size: 16, color: DeskConcept.blueprint.color),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const ValueKey('desk-blueprint-selector'),
                value: selectedId,
                isExpanded: true,
                isDense: true,
                iconSize: 18,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                items: blueprints
                    .map((b) => DropdownMenuItem(
                          value: b.id,
                          child:
                              Text(b.name, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── No-blueprint adopt prompt ─────────────────────────────────────────────────

class _NoBlueprintAdopt extends StatelessWidget {
  const _NoBlueprintAdopt({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No Book Structure yet.\nChoose one to structure your book.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('desk-choose-blueprint-empty'),
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Choose a Book Structure'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── File-not-placed prompt ────────────────────────────────────────────────────
//
// Shown in the Book panel when the OPEN file isn't placed in any blueprint
// section. The blueprint belongs to the project, not to an unplaced file, so we
// don't show the project's section tree here — only a prompt to place this file.

class _FileNotPlacedPanel extends ConsumerWidget {
  const _FileNotPlacedPanel({
    required this.documentId,
    required this.blueprints,
    required this.projectId,
  });

  final String documentId;
  final List<BlueprintOverview> blueprints;
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(DeskConcept.blueprint.icon,
                size: 30, color: DeskConcept.blueprint.color.withOpacity(0.6)),
            const SizedBox(height: 12),
            Text(
              "This file isn't in a Book Structure yet.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Place it in a section to organize it into your book.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const ValueKey('desk-book-place-file'),
              onPressed: () => _place(context, ref),
              icon: const Icon(Icons.playlist_add_check, size: 18),
              label: const Text('Place in a section'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _place(BuildContext context, WidgetRef ref) async {
    final flat = <PartOverviewNode>[];
    for (final bp in blueprints) {
      _flatten(bp.parts, flat);
    }
    if (flat.isEmpty) return;
    final chosen = await showDialog<PartOverviewNode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Place in a Section'),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final part in flat)
                ListTile(
                  key: ValueKey('desk-book-place-section-${part.id}'),
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
    if (chosen == null || !context.mounted) return;
    await ref.read(blueprintActionsProvider).setPlacement(
          documentId,
          chosen.id,
          Role.mainContent,
          projectId: projectId,
        );
  }

  static void _flatten(
      List<PartOverviewNode> nodes, List<PartOverviewNode> out) {
    for (final n in nodes) {
      out.add(n);
      _flatten(n.children, out);
    }
  }
}

// ── Drag payload + feedback ───────────────────────────────────────────────────

/// Carried while dragging a file onto a blueprint section. Keeps the file's
/// current role so a move between sections preserves it.
class _DocDrag {
  const _DocDrag(this.documentId, this.role);
  final String documentId;
  final Role role;
}

/// The chip that follows the cursor during a file drag. Material-wrapped so its
/// text renders correctly in the drag overlay.
class _DragChip extends StatelessWidget {
  const _DragChip({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 14, color: scheme.onPrimary),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(color: scheme.onPrimary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ── Part tree ─────────────────────────────────────────────────────────────────

class _PartTree extends StatefulWidget {
  const _PartTree({
    required this.parts,
    required this.placements,
    required this.docs,
    required this.unplacedDocs,
    required this.projectId,
    required this.blueprintId,
  });

  final List<PartOverviewNode> parts;
  final List<ProjectPlacement> placements;
  final List<Document> docs;
  final List<Document> unplacedDocs;
  final String projectId;
  final String blueprintId;

  @override
  State<_PartTree> createState() => _PartTreeState();
}

class _PartTreeState extends State<_PartTree> {
  final ScrollController _scroll = ScrollController();
  Timer? _scrollTimer;

  // Section ids the writer has expanded. Sections start collapsed so the
  // blueprint's structure shows as a clean, lined-up list; clicking the
  // chevron opens a section to reveal its subsections and placed files.
  final Set<String> _expanded = <String>{};

  void _toggleExpand(String partId) {
    setState(() {
      if (!_expanded.remove(partId)) _expanded.add(partId);
    });
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  // Auto-scroll while a file is dragged over the top/bottom edge bands, so the
  // writer can reach an off-screen section without releasing the drag.
  void _autoScroll(int direction) {
    if (_scrollTimer != null) return;
    _scrollTimer =
        Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      final next = (_scroll.offset + direction * 14).clamp(0.0, max);
      if (next != _scroll.offset) _scroll.jumpTo(next);
    });
  }

  void _stopScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
  }

  Widget _edgeBand({required bool top}) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: 0,
      right: 0,
      height: 36,
      child: DragTarget<_DocDrag>(
        // Reject so drops fall through to the section behind; we only use the
        // band to detect a hovering drag and drive auto-scroll.
        onWillAcceptWithDetails: (_) => false,
        onMove: (_) => _autoScroll(top ? -1 : 1),
        onLeave: (_) => _stopScroll(),
        builder: (_, __, ___) => const SizedBox.expand(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    _flatten(context, widget.parts, items, 0);

    if (widget.unplacedDocs.isNotEmpty) {
      items.add(const _SectionHeader(
        key: ValueKey('desk-unassigned-header'),
        label: 'Unassigned documents',
      ));
      for (final doc in widget.unplacedDocs) {
        items.add(_UnplacedDocTile(
          key: ValueKey('desk-unplaced-${doc.id}'),
          doc: doc,
          parts: widget.parts,
          projectId: widget.projectId,
        ));
      }
    }

    return Stack(
      children: [
        ListView(
          controller: _scroll,
          padding: const EdgeInsets.only(top: 4, bottom: 16),
          children: items,
        ),
        _edgeBand(top: true),
        _edgeBand(top: false),
      ],
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
          widget.placements.where((p) => p.partId == part.id).toList();
      final partDocs = widget.docs
          .where((d) => partPlacements.any((p) => p.documentId == d.id))
          .toList();
      final expandable =
          part.children.isNotEmpty || partDocs.isNotEmpty;
      final expanded = _expanded.contains(part.id);
      out.add(_SectionTile(
        part: part,
        depth: depth,
        placements: partPlacements,
        docs: partDocs,
        blueprintId: widget.blueprintId,
        projectId: widget.projectId,
        expandable: expandable,
        expanded: expanded,
        onToggle: () => _toggleExpand(part.id),
      ));
      // Recurse into subsections only when this section is open.
      if (expanded) _flatten(context, part.children, out, depth + 1);
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

// ── Blueprint progress footer ─────────────────────────────────────────────────
//
// Pinned to the bottom of the left navigator panel (moved here from the right
// rail). Shows the blueprint's sections-with-content meter.

class _NavProgressFooter extends StatelessWidget {
  const _NavProgressFooter({required this.progress});
  final ProgressInfo progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = progress.ratio ?? 0.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.outline.withOpacity(0.15)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'BLUEPRINT PROGRESS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: scheme.outline.withOpacity(0.15),
              color: scheme.primary,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${progress.leavesWithContent} / ${progress.totalLeaves} sections with content',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Section tile ──────────────────────────────────────────────────────────────

class _SectionTile extends ConsumerWidget {
  const _SectionTile({
    required this.part,
    required this.depth,
    required this.placements,
    required this.docs,
    required this.blueprintId,
    required this.projectId,
    required this.expandable,
    required this.expanded,
    required this.onToggle,
  });

  final PartOverviewNode part;
  final int depth;
  final List<ProjectPlacement> placements;
  final List<Document> docs;
  final String blueprintId;
  final String projectId;

  /// Whether this section has subsections or placed files to reveal.
  final bool expandable;

  /// Whether this section is currently open.
  final bool expanded;

  /// Toggle this section open/closed.
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: ValueKey('desk-section-${part.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The section header is a drop target: dragging a file onto it places
        // (or moves) the file into this section.
        DragTarget<_DocDrag>(
          onWillAcceptWithDetails: (d) => d.data.documentId.isNotEmpty,
          onAcceptWithDetails: (details) {
            final d = details.data;
            ref.read(blueprintActionsProvider).setPlacement(
                  d.documentId,
                  part.id,
                  d.role == Role.unknown ? Role.mainContent : d.role,
                  projectId: projectId,
                );
            // Open the section so the writer sees the file land in it.
            if (!expanded) onToggle();
          },
          builder: (context, candidate, rejected) {
            final hovering = candidate.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: EdgeInsets.only(left: 12.0 + depth * 16.0, right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: hovering
                    ? scheme.primary.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: hovering ? scheme.primary : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Collapse/expand chevron. A fixed-width slot keeps every
                  // section name aligned whether or not it can expand.
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: expandable
                        ? InkWell(
                            key: ValueKey('desk-section-toggle-${part.id}'),
                            borderRadius: BorderRadius.circular(10),
                            onTap: onToggle,
                            child: AnimatedRotation(
                              turns: expanded ? 0.25 : 0.0,
                              duration: const Duration(milliseconds: 150),
                              child: Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 2),
                  if (depth == 0)
                    Icon(
                      DeskConcept.blueprint.icon,
                      size: 16,
                      color: DeskConcept.blueprint.color,
                    )
                  else
                    _ReadinessDot(readiness: part.readiness),
                  const SizedBox(width: 8),
                  Expanded(
                    // Tapping the name also toggles, matching file-tree UX.
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: expandable ? onToggle : null,
                      child: Text(
                        part.name,
                        key: ValueKey('desk-section-name-${part.id}'),
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: depth == 0
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (part.documentCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '${part.documentCount}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  _SectionActionsMenu(part: part, blueprintId: blueprintId),
                ],
              ),
            );
          },
        ),
        // Inline placed-doc sublist — only when the section is open.
        if (expanded)
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

// ── Section actions menu ──────────────────────────────────────────────────────
//
// Per-section overflow menu in the Desk's SECTIONS tree: rename, add subsection,
// delete. Mutations go through blueprintActionsProvider (which invalidates the
// overview, so the tree refreshes), reusing the Blueprints editor's dialogs.

class _SectionActionsMenu extends ConsumerWidget {
  const _SectionActionsMenu({required this.part, required this.blueprintId});

  final PartOverviewNode part;
  final String blueprintId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 26,
      height: 26,
      child: PopupMenuButton<String>(
      key: ValueKey('desk-section-menu-${part.id}'),
      tooltip: 'Section actions',
      padding: EdgeInsets.zero,
      iconSize: 16,
      icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
      onSelected: (value) => _onSelected(context, ref, value),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        const PopupMenuItem(value: 'addsub', child: Text('Add subsection')),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: scheme.error)),
        ),
      ],
      ),
    );
  }

  Future<void> _onSelected(
      BuildContext context, WidgetRef ref, String value) async {
    final actions = ref.read(blueprintActionsProvider);
    switch (value) {
      case 'rename':
        final result = await showSectionFormDialog(
          context,
          title: 'Rename Section',
          submitLabel: 'Save',
          initialName: part.name,
          initialDescription: part.description,
        );
        if (result == null || !context.mounted) return;
        await runBlueprintMutation(
          context,
          () => actions.updatePart(
            blueprintId,
            part.id,
            name: result.name,
            description: result.description,
          ),
        );
      case 'addsub':
        final result = await showSectionFormDialog(
          context,
          title: 'Add Subsection',
          submitLabel: 'Add',
        );
        if (result == null || !context.mounted) return;
        await runBlueprintMutation(
          context,
          () => actions.createPart(
            blueprintId,
            name: result.name,
            description: result.description,
            parentPartId: part.id,
          ),
        );
      case 'delete':
        final ok = await confirmDeleteDialog(
          context,
          title: 'Delete Section?',
          message:
              'Delete this section? Any subsections are removed too. Files in '
              'it return to Unassigned — they stay in your project and Library.',
        );
        if (!ok || !context.mounted) return;
        await runBlueprintMutation(
          context,
          () => actions.deletePart(blueprintId, part.id),
        );
    }
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
    final scheme = Theme.of(context).colorScheme;
    final row = Padding(
      padding: EdgeInsets.only(left: indent, right: 12, top: 2, bottom: 2),
      child: Row(
        children: [
          Icon(Icons.drag_indicator,
              size: 14, color: scheme.onSurfaceVariant.withOpacity(0.6)),
          const SizedBox(width: 2),
          Icon(Icons.article_outlined,
              size: 14, color: scheme.onSurfaceVariant),
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
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
    return Draggable<_DocDrag>(
      data: _DocDrag(doc.id, placement.role),
      dragAnchorStrategy: childDragAnchorStrategy,
      feedback: _DragChip(title: doc.title),
      childWhenDragging: Opacity(opacity: 0.4, child: row),
      child: row,
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
    final scheme = Theme.of(context).colorScheme;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Icon(Icons.drag_indicator,
              size: 14, color: scheme.onSurfaceVariant.withOpacity(0.6)),
          const SizedBox(width: 2),
          Icon(Icons.article_outlined,
              size: 14, color: scheme.onSurfaceVariant),
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
    return Draggable<_DocDrag>(
      data: _DocDrag(doc.id, Role.mainContent),
      dragAnchorStrategy: childDragAnchorStrategy,
      feedback: _DragChip(title: doc.title),
      childWhenDragging: Opacity(opacity: 0.4, child: row),
      child: row,
    );
  }

  Future<void> _showAssignDialog(
      BuildContext context, WidgetRef ref) async {
    final flat = <PartOverviewNode>[];
    _flattenParts(parts, flat);

    // No blueprint adopted → no sections to assign into. Guide the writer to
    // choose a blueprint first instead of showing an empty list.
    if (flat.isEmpty) {
      final choose = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Assign to Section'),
          content: SizedBox(
            width: 320,
            child: Text(
              'This project has no Book Structure yet, so there are no sections to '
              'assign into. Choose a Book Structure first.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Choose a Book Structure'),
            ),
          ],
        ),
      );
      if (choose == true && context.mounted) {
        await adoptBlueprintFlow(
          context,
          ref,
          projectId: projectId,
          adoptedIds: const {},
        );
      }
      return;
    }

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
