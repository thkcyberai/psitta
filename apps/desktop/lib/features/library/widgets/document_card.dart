import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

/// Document card — displayed in the library grid.
///
/// Shows document title, processing status with visual indicator,
/// and file type icon. Desktop-optimized: hover effect and actions menu.
class DocumentCard extends StatelessWidget {
  final String title;
  final String status;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const DocumentCard({
    super.key,
    required this.title,
    required this.status,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  IconData get _statusIcon => switch (status) {
        'ready' => Icons.check_circle,
        'processing' => Icons.hourglass_top,
        'failed' => Icons.error,
        'uploaded' => Icons.cloud_upload,
        _ => Icons.description,
      };

  Color get _statusColor => switch (status) {
        'ready' => AppColors.success,
        'processing' => AppColors.warning,
        'failed' => AppColors.error,
        _ => AppColors.textSecondary,
      };

  IconData get _fileIcon {
    final t = title.toLowerCase();
    if (t.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (t.endsWith('.docx')) return Icons.article;
    if (t.endsWith('.md')) return Icons.code;
    if (t.endsWith('.txt')) return Icons.text_snippet;
    if (t.endsWith('.html')) return Icons.language;
    return Icons.description;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: theme.dividerColor.withOpacity(0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: AppColors.primary.withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(_fileIcon, size: 28, color: AppColors.primary),
                  const Spacer(),
                  Icon(_statusIcon, size: 16, color: _statusColor),
                  const SizedBox(width: 4),
                  Text(
                    status,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'Actions',
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 10),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18),
                            SizedBox(width: 10),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.more_horiz, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
