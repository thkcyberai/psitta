import 'package:flutter/material.dart';

/// Result of the export dialog. [fullBook] is only meaningful when the dialog
/// was opened with `showScope: true` (Writing Nook).
class ExportOptions {
  const ExportOptions({
    required this.includeCover,
    required this.includeFooter,
    this.fullBook = false,
  });

  final bool includeCover;
  final bool includeFooter;
  final bool fullBook;
}

/// Shared export dialog used across tiers. [showScope] adds the
/// "This file / Full book" choice (Writing Nook). Full book is selectable only
/// when [fullBookEnabled] (its backend export endpoint exists).
Future<ExportOptions?> showExportOptionsDialog(
  BuildContext context, {
  required String title,
  bool showScope = false,
  bool fullBookEnabled = false,
}) {
  return showDialog<ExportOptions>(
    context: context,
    builder: (_) => _ExportOptionsDialog(
      title: title,
      showScope: showScope,
      fullBookEnabled: fullBookEnabled,
    ),
  );
}

class _ExportOptionsDialog extends StatefulWidget {
  const _ExportOptionsDialog({
    required this.title,
    required this.showScope,
    required this.fullBookEnabled,
  });

  final String title;
  final bool showScope;
  final bool fullBookEnabled;

  @override
  State<_ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<_ExportOptionsDialog> {
  bool _includeCover = true;
  bool _includeFooter = true;
  bool _fullBook = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Export Options'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Export as a branded DOCX file.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (widget.showScope) ...[
              const SizedBox(height: 14),
              Text(
                'WHAT TO EXPORT',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
              ),
              RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: false,
                groupValue: _fullBook,
                onChanged: (v) => setState(() => _fullBook = v ?? false),
                title: const Text('This file'),
                subtitle: const Text('Only the document open now'),
              ),
              RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: true,
                groupValue: _fullBook,
                onChanged: widget.fullBookEnabled
                    ? (v) => setState(() => _fullBook = v ?? true)
                    : null,
                title: Row(
                  children: [
                    const Text('Full book'),
                    if (!widget.fullBookEnabled) ...[
                      const SizedBox(width: 6),
                      const _SoonTag(),
                    ],
                  ],
                ),
                subtitle:
                    const Text('All files assembled in blueprint order'),
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Include cover page'),
              subtitle: const Text('Title page with name and date'),
              value: _includeCover,
              onChanged: (v) => setState(() => _includeCover = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Include Psitta footer'),
              subtitle: const Text('Branding and page numbers on every page'),
              value: _includeFooter,
              onChanged: (v) => setState(() => _includeFooter = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Export'),
          onPressed: () => Navigator.of(context).pop(
            ExportOptions(
              includeCover: _includeCover,
              includeFooter: _includeFooter,
              fullBook: _fullBook,
            ),
          ),
        ),
      ],
    );
  }
}

class _SoonTag extends StatelessWidget {
  const _SoonTag();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.secondary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Soon',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.secondary,
              fontSize: 10,
            ),
      ),
    );
  }
}
