import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/psitta_tokens.dart';
import '../../../widgets/document_cover.dart';

class DocumentCard extends StatelessWidget {
  const DocumentCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.isSelected,
    required this.onTap,
    required this.onRead,
    required this.onEdit,
    required this.onDelete,
    this.onArchive,
    this.onDownload,
    this.onAssignProject,
    this.onRemoveProject,
    this.onChangeCover,
    this.onRegenerateAudio,
    this.currentProjectId,
    this.documentId,
    this.projectPath,
    this.coverType,
    this.coverValue,
    this.sourceType,
  });

  final String title;
  final String subtitle;
  final String status;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRead;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onArchive;
  final VoidCallback? onDownload;
  final VoidCallback? onAssignProject;
  final VoidCallback? onRemoveProject;
  final VoidCallback? onChangeCover;
  final VoidCallback? onRegenerateAudio;
  final String? currentProjectId;
  final String? documentId;
  final String? projectPath;
  final String? coverType;
  final String? coverValue;
  final String? sourceType;

  IconData get _statusIcon => switch (status) {
        'ready' => Icons.check,
        'processing' => Icons.hourglass_top,
        'failed' => Icons.error_outline,
        'uploaded' => Icons.cloud_upload_outlined,
        _ => Icons.description_outlined,
      };

  String get _statusLabel => switch (status) {
        'ready' => 'Ready',
        'processing' => 'Processing',
        'failed' => 'Failed',
        'uploaded' => 'Uploaded',
        _ => status,
      };

  IconData get _fileIcon {
    final t = subtitle.toLowerCase();
    if (t.contains('pdf')) return Icons.picture_as_pdf;
    if (t.contains('docx')) return Icons.article;
    if (t.contains('markdown') || t.contains('md')) return Icons.code;
    if (t.contains('text') || t.contains('txt')) return Icons.text_snippet;
    if (t.contains('html')) return Icons.language;
    return Icons.description;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = PsittaTokens.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final titleColor =
        theme.colorScheme.onSurface.withOpacity(isDark ? 0.95 : 0.92);
    final subColor =
        theme.colorScheme.onSurfaceVariant.withOpacity(isDark ? 0.80 : 0.78);
    final menuColor =
        theme.colorScheme.onSurfaceVariant.withOpacity(isDark ? 0.85 : 0.80);

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radius),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: tokens.glow.withOpacity(0.10),
          hoverColor: tokens.glow.withOpacity(0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            decoration: _cardDecoration(tokens),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(tokens.radius),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: [
                            Colors.white.withOpacity(isDark ? 0.10 : 0.14),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.55],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (coverType != null && documentId != null)
                            SizedBox(
                              width: 52,
                              height: 52,
                              child: DocumentCover(
                                coverType: coverType,
                                coverValue: coverValue,
                                documentId: documentId!,
                                size: DocumentCoverSize.thumbnail,
                                sourceType: sourceType,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            )
                          else
                            Icon(_fileIcon, size: 26, color: tokens.glow),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: titleColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _statusPill(tokens, theme),
                          const SizedBox(width: 8),
                          _buildMenu(context, menuColor),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: subColor,
                        ),
                      ),
                      if (projectPath != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.folder_outlined,
                                size: 12, color: subColor.withOpacity(0.7)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                projectPath!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: subColor.withOpacity(0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context, Color menuColor) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      onSelected: (value) {
        switch (value) {
          case 'read':
            onRead();
            break;
          case 'edit':
            onEdit();
            break;
          case 'delete':
            onDelete();
            break;
          case 'archive':
            onArchive?.call();
            break;
          case 'download':
            onDownload?.call();
            break;
          case 'change_cover':
            onChangeCover?.call();
            break;
          case 'assign_project':
            onAssignProject?.call();
            break;
          case 'remove_project':
            onRemoveProject?.call();
            break;
          case 'regenerate_audio':
            onRegenerateAudio?.call();
            break;
        }
      },
      itemBuilder: (context) {
        final loc = AppLocalizations.of(context);
        return [
        PopupMenuItem(
          value: 'read',
          child: Row(children: [
            const Icon(Icons.chrome_reader_mode, size: 18),
            const SizedBox(width: 10),
            Text(loc.deskRead),
          ]),
        ),
        PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            const Icon(Icons.edit, size: 18),
            const SizedBox(width: 10),
            Text(loc.docMenuRename),
          ]),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            const Icon(Icons.delete_outline, size: 18),
            const SizedBox(width: 10),
            Text(loc.btnDelete),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'change_cover',
          child: Row(children: [
            const Icon(Icons.image_outlined, size: 18),
            const SizedBox(width: 8),
            Text(loc.docMenuChangeCover),
          ]),
        ),
        if (onArchive != null || onDownload != null)
          const PopupMenuDivider(),
        if (onArchive != null)
          PopupMenuItem<String>(
            value: 'archive',
            child: Row(children: [
              const Icon(Icons.archive_outlined, size: 18),
              const SizedBox(width: 8),
              Text(loc.archive),
            ]),
          ),
        if (onDownload != null)
          PopupMenuItem<String>(
            value: 'download',
            child: Row(children: [
              const Icon(Icons.download_outlined, size: 18),
              const SizedBox(width: 8),
              Text(loc.btnExport),
            ]),
          ),
        PopupMenuItem<String>(
          value: 'regenerate_audio',
          child: Row(children: [
            const Icon(Icons.refresh_outlined, size: 18),
            const SizedBox(width: 8),
            Text(loc.docMenuRegenAudio),
          ]),
        ),
        const PopupMenuDivider(),
        if (currentProjectId == null)
          PopupMenuItem<String>(
            value: 'assign_project',
            child: Row(children: [
              const Icon(Icons.folder_outlined, size: 18),
              const SizedBox(width: 8),
              Text(loc.docMenuAddToProject),
            ]),
          )
        else ...[
          PopupMenuItem<String>(
            value: 'assign_project',
            child: Row(children: [
              const Icon(Icons.drive_file_move_outlined, size: 18),
              const SizedBox(width: 8),
              Text(loc.docMenuMoveToProject),
            ]),
          ),
          PopupMenuItem<String>(
            value: 'remove_project',
            child: Row(children: [
              const Icon(Icons.folder_off_outlined, size: 18),
              const SizedBox(width: 8),
              Text(loc.docMenuRemoveFromProject),
            ]),
          ),
        ],
        ];
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(Icons.more_horiz, size: 18, color: menuColor),
      ),
    );
  }

  Widget _statusPill(PsittaTokens tokens, ThemeData theme) {
    final bool readyAndSelected = status == 'ready' && isSelected;
    final isDark = theme.brightness == Brightness.dark;

    final Color bg = isDark
        ? (readyAndSelected ? const Color(0xFF1D3B2B) : const Color(0xFF1B2340))
        : (readyAndSelected
            ? tokens.glow.withOpacity(0.22)
            : theme.colorScheme.surface.withOpacity(0.90));

    final Color border = readyAndSelected
        ? (isDark
            ? AppColors.success.withOpacity(0.45)
            : tokens.glow.withOpacity(0.45))
        : tokens.border.withOpacity(isDark ? 0.30 : 0.55);

    final Color fg = readyAndSelected
        ? (isDark
            ? AppColors.success
            : theme.colorScheme.onSurface.withOpacity(0.92))
        : theme.colorScheme.onSurface.withOpacity(isDark ? 0.92 : 0.86);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        children: [
          Icon(_statusIcon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            _statusLabel,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(PsittaTokens tokens) {
    final baseBorder = tokens.border.withOpacity(isSelected ? 0.50 : 0.32);

    final fill = isSelected
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.surface.withOpacity(0.98),
              tokens.surface2.withOpacity(0.92),
              tokens.glow.withOpacity(0.06),
            ],
            stops: const [0.0, 0.78, 1.0],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.surface.withOpacity(0.96),
              tokens.surface2.withOpacity(0.90),
            ],
          );

    return BoxDecoration(
      borderRadius: BorderRadius.circular(tokens.radius),
      gradient: fill,
      border: Border.all(color: baseBorder, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.18),
          blurRadius: 22,
          offset: const Offset(0, 14),
        ),
        if (isSelected)
          BoxShadow(
            color: tokens.glow.withOpacity(0.14),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
      ],
    );
  }
}
