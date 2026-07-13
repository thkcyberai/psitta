import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/psitta_tokens.dart';
import '../../data/models/document.dart';
import '../../data/providers/project_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/document_cover.dart';

/// Result from the project cover picker. Null documentId means remove cover.
class ProjectCoverResult {
  const ProjectCoverResult(this.documentId);
  final String? documentId;
}

/// Shows a dialog to pick a project's cover from its documents.
Future<ProjectCoverResult?> showProjectCoverPickerDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String projectId,
  String? currentCoverDocumentId,
}) async {
  // Fetch project documents. Invalidate first so a cover just changed in the
  // Library (which saves to the backend but doesn't refresh this cached
  // family) is reflected in the SAME session. Without this the picker showed
  // "no documents with covers" until a re-login forced a refetch.
  List<Document> docs;
  try {
    ref.invalidate(projectDocumentsProvider(projectId));
    final docsData = await ref.read(projectDocumentsProvider(projectId).future);
    docs = docsData;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context).pcpLoadError)),
      );
    }
    return null;
  }

  // Filter to only docs with covers
  final docsWithCovers =
      docs.where((d) => d.coverType != null).toList();

  if (!context.mounted) return null;

  return showDialog<ProjectCoverResult>(
    context: context,
    builder: (_) => _ProjectCoverPickerDialog(
      documents: docsWithCovers,
      currentCoverDocumentId: currentCoverDocumentId,
    ),
  );
}

class _ProjectCoverPickerDialog extends StatefulWidget {
  const _ProjectCoverPickerDialog({
    required this.documents,
    this.currentCoverDocumentId,
  });

  final List<Document> documents;
  final String? currentCoverDocumentId;

  @override
  State<_ProjectCoverPickerDialog> createState() =>
      _ProjectCoverPickerDialogState();
}

class _ProjectCoverPickerDialogState
    extends State<_ProjectCoverPickerDialog> {
  String? _selectedDocId;

  @override
  void initState() {
    super.initState();
    _selectedDocId = widget.currentCoverDocumentId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = PsittaTokens.of(context);
    final loc = AppLocalizations.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      child: SizedBox(
        width: 440,
        height: 420,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Text(
                    loc.pcpTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: widget.documents.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image_not_supported_outlined,
                                size: 48,
                                color: theme.colorScheme.outline),
                            const SizedBox(height: 12),
                            Text(
                              loc.pcpNoDocsTitle,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              loc.pcpNoDocsBody,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: widget.documents.length,
                      itemBuilder: (context, i) {
                        final doc = widget.documents[i];
                        final isSelected = _selectedDocId == doc.id;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedDocId = doc.id),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? tokens.glow
                                    : Colors.transparent,
                                width: isSelected ? 2.5 : 0,
                              ),
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: DocumentCover(
                                      coverType: doc.coverType,
                                      coverValue: doc.coverValue,
                                      documentId: doc.id,
                                      size: DocumentCoverSize.thumbnail,
                                      sourceType: doc.sourceType,
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  doc.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  if (widget.currentCoverDocumentId != null)
                    TextButton(
                      onPressed: () => Navigator.of(context)
                          .pop(const ProjectCoverResult(null)),
                      child: Text(
                        loc.pcpRemoveCover,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(loc.btnCancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _selectedDocId != null
                        ? () => Navigator.of(context)
                            .pop(ProjectCoverResult(_selectedDocId))
                        : null,
                    child: Text(loc.btnApply),
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
