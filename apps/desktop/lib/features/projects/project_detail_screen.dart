import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/psitta_tokens.dart';
import '../../data/providers/project_providers.dart';
import 'widgets/project_blueprints_tab.dart';
import 'widgets/project_documents_tab.dart';
import 'widgets/project_overview_tab.dart';
import 'widgets/project_right_rail.dart';
import 'widgets/add_documents_dialog.dart';

/// Project screen — tabbed shell (Overview · Documents · Blueprints · Activity)
/// with a project-level right rail (About, Project Actions, Activity).
///
/// This slice (5b) builds the shell, header, right rail, and the Documents tab;
/// Overview and Blueprints are placeholder panes filled in by 5c/5d.
class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  final String projectId;
  final String projectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PsittaTokens.of(context);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProjectHeader(projectId: projectId, projectName: projectName),
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Overview'),
                Tab(text: 'Documents'),
                Tab(text: 'Book Structure'),
                Tab(text: 'Activity'),
              ],
            ),
            Divider(height: 1, color: tokens.divider),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: TabBarView(
                      children: [
                        ProjectOverviewTab(projectId: projectId),
                        ProjectDocumentsTab(
                          projectId: projectId,
                          projectName: projectName,
                        ),
                        ProjectBlueprintsTab(projectId: projectId),
                        const Center(child: ProjectActivityComingSoon()),
                      ],
                    ),
                  ),
                  VerticalDivider(width: 1, color: tokens.divider),
                  SizedBox(
                    width: 300,
                    child: ProjectRightRail(
                      projectId: projectId,
                      projectName: projectName,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header: breadcrumb back to Projects + the project name (from
/// projectDetailProvider, falling back to the routed name while loading).
class _ProjectHeader extends ConsumerWidget {
  const _ProjectHeader({required this.projectId, required this.projectName});

  final String projectId;
  final String projectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(projectDetailProvider(projectId));
    final name = detailAsync.maybeWhen(
      data: (d) => d.name,
      orElse: () => projectName,
    );
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        children: [
          TextButton.icon(
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Projects'),
            onPressed: () => context.go('/projects'),
          ),
          Text(' / ', style: TextStyle(color: muted)),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            icon: const Icon(Icons.note_add_outlined, size: 16),
            label: const Text('Add files'),
            onPressed: () =>
                addDocumentsToProjectFlow(context, ref, projectId: projectId),
          ),
        ],
      ),
    );
  }
}
