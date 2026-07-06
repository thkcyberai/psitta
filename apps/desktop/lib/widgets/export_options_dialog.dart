import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

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
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(loc.exportOptions),
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
              loc.exportBrandedDocx,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (widget.showScope) ...[
              const SizedBox(height: 14),
              Text(
                loc.whatToExport,
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
                title: Text(loc.exportThisFile),
                subtitle: Text(loc.exportThisFileSub),
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
                    Text(loc.exportFullBook),
                    if (!widget.fullBookEnabled) ...[
                      const SizedBox(width: 6),
                      const _SoonTag(),
                    ],
                  ],
                ),
                subtitle:
                    Text(loc.exportFullBookSub),
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(loc.includeCover),
              subtitle: Text(loc.includeCoverSub),
              value: _includeCover,
              onChanged: (v) => setState(() => _includeCover = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(loc.includeFooter),
              subtitle: Text(loc.includeFooterSub),
              value: _includeFooter,
              onChanged: (v) => setState(() => _includeFooter = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc.btnCancel),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.download, size: 18),
          label: Text(loc.btnExport),
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
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.secondary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        loc.badgeSoon,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.secondary,
              fontSize: 10,
            ),
      ),
    );
  }
}
