import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Asks the writer to name a new document before the blank sheet opens.
/// Returns the trimmed title (empty = keep the default), or null if the writer
/// cancelled (in which case no document should be created).
Future<String?> promptNewSheetName(BuildContext context) async {
  final loc = AppLocalizations.of(context);
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(loc.nameYourDocument),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: loc.titleLabel,
          hintText: loc.titleHint,
        ),
        onSubmitted: (_) => Navigator.of(ctx).pop(controller.text.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(loc.btnCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: Text(loc.btnCreate),
        ),
      ],
    ),
  );
  controller.dispose();
  return name;
}
