import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/psitta_tokens.dart';

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
    final tokens = PsittaTokens.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radius),
      child: Container(
        decoration: _premiumCardDecoration(tokens),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(tokens.radius),
            splashColor: tokens.glow.withOpacity(0.08),
            hoverColor: tokens.glow.withOpacity(0.06),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(_fileIcon, size: 28, color: tokens.glow),
                      const Spacer(),
                      Icon(_statusIcon, size: 16, color: _statusColor),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _statusColor,
                          fontWeight: FontWeight.w700,
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
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.more_horiz,
                            size: 18,
                            color: theme.iconTheme.color?.withOpacity(0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _premiumCardDecoration(PsittaTokens tokens) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(tokens.radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          tokens.surface.withOpacity(0.98),
          tokens.surface2.withOpacity(0.92),
        ],
      ),
      border: Border.all(color: tokens.border, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.45),
          blurRadius: 26,
          offset: const Offset(0, 18),
        ),
        BoxShadow(
          color: tokens.glow.withOpacity(0.10),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}
