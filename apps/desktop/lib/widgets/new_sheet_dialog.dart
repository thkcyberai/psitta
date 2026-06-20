import 'package:flutter/material.dart';

/// Asks the writer to name a new document before the blank sheet opens.
/// Returns the trimmed title (empty = keep the default), or null if the writer
/// cancelled (in which case no document should be created).
Future<String?> promptNewSheetName(BuildContext context) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Name your document'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Title',
          hintText: 'e.g. Chapter One',
        ),
        onSubmitted: (_) => Navigator.of(ctx).pop(controller.text.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: const Text('Create'),
        ),
      ],
    ),
  );
  controller.dispose();
  return name;
}
