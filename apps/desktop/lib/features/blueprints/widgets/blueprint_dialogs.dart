import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../data/models/blueprint_enums.dart';
import '../../../data/models/blueprint_enum_labels.dart';
import '../../../l10n/app_localizations.dart';

/// Dialogs and the shared mutation runner for the Blueprints screen. UI text
/// uses "Blueprint"/"Section"; the data layer's terms are unchanged.

// ── Blueprint create/edit form ───────────────────────────────────────────────

/// Result of the blueprint create/edit form. [genre] is never [Genre.unknown]
/// (that variant is excluded from the dropdown).
class BlueprintFormResult {
  const BlueprintFormResult({
    required this.name,
    required this.genre,
    required this.status,
  });

  final String name;
  final Genre genre;
  final BlueprintStatus status;
}

Future<BlueprintFormResult?> showBlueprintFormDialog(
  BuildContext context, {
  required String title,
  required String submitLabel,
  String? initialName,
  Genre? initialGenre,
  BlueprintStatus? initialStatus,
}) {
  return showDialog<BlueprintFormResult>(
    context: context,
    builder: (_) => _BlueprintFormDialog(
      title: title,
      submitLabel: submitLabel,
      initialName: initialName,
      initialGenre: initialGenre,
      initialStatus: initialStatus,
    ),
  );
}

class _BlueprintFormDialog extends StatefulWidget {
  const _BlueprintFormDialog({
    required this.title,
    required this.submitLabel,
    this.initialName,
    this.initialGenre,
    this.initialStatus,
  });

  final String title;
  final String submitLabel;
  final String? initialName;
  final Genre? initialGenre;
  final BlueprintStatus? initialStatus;

  @override
  State<_BlueprintFormDialog> createState() => _BlueprintFormDialogState();
}

class _BlueprintFormDialogState extends State<_BlueprintFormDialog> {
  late final TextEditingController _name;
  late Genre _genre;
  late BlueprintStatus _status;

  // Never offer the forward-compat sentinels in the UI.
  static final List<Genre> _genres =
      Genre.values.where((g) => g != Genre.unknown).toList();
  static final List<BlueprintStatus> _statuses =
      BlueprintStatus.values.where((s) => s != BlueprintStatus.unknown).toList();

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName ?? '');
    final g = widget.initialGenre ?? Genre.novel;
    _genre = g == Genre.unknown ? Genre.novel : g;
    final s = widget.initialStatus ?? BlueprintStatus.draft;
    _status = s == BlueprintStatus.unknown ? BlueprintStatus.draft : s;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) return;
    Navigator.of(context).pop(BlueprintFormResult(
      name: _name.text.trim(),
      genre: _genre,
      status: _status,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: loc.fieldName,
                hintText: loc.bookStructureNameHint,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Genre>(
              value: _genre,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: loc.fieldGenre,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final g in _genres)
                  DropdownMenuItem(value: g, child: Text(genreLabel(loc, g))),
              ],
              onChanged: (g) {
                if (g != null) setState(() => _genre = g);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<BlueprintStatus>(
              value: _status,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: loc.fieldStatus,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final s in _statuses)
                  DropdownMenuItem(value: s, child: Text(blueprintStatusLabel(loc, s))),
              ],
              onChanged: (s) {
                if (s != null) setState(() => _status = s);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc.btnCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
      ],
    );
  }
}

// ── Section create/edit form ─────────────────────────────────────────────────

/// Result of the section create/edit form. [description] is null when left blank.
class SectionFormResult {
  const SectionFormResult({required this.name, this.description});

  final String name;
  final String? description;
}

Future<SectionFormResult?> showSectionFormDialog(
  BuildContext context, {
  required String title,
  required String submitLabel,
  String? initialName,
  String? initialDescription,
}) {
  return showDialog<SectionFormResult>(
    context: context,
    builder: (_) => _SectionFormDialog(
      title: title,
      submitLabel: submitLabel,
      initialName: initialName,
      initialDescription: initialDescription,
    ),
  );
}

class _SectionFormDialog extends StatefulWidget {
  const _SectionFormDialog({
    required this.title,
    required this.submitLabel,
    this.initialName,
    this.initialDescription,
  });

  final String title;
  final String submitLabel;
  final String? initialName;
  final String? initialDescription;

  @override
  State<_SectionFormDialog> createState() => _SectionFormDialogState();
}

class _SectionFormDialogState extends State<_SectionFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName ?? '');
    _description = TextEditingController(text: widget.initialDescription ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) return;
    final desc = _description.text.trim();
    Navigator.of(context).pop(SectionFormResult(
      name: _name.text.trim(),
      description: desc.isEmpty ? null : desc,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: loc.fieldName,
                hintText: loc.sectionNameHint,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: loc.descriptionOptional,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc.btnCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
      ],
    );
  }
}

// ── Destructive confirm ──────────────────────────────────────────────────────

Future<bool> confirmDeleteDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final loc = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(loc.btnCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

// ── Mutation runner ──────────────────────────────────────────────────────────

/// Runs a Blueprint mutation [op], returning its result, or null on failure
/// after surfacing a SnackBar (e.g. the backend's 400 detail for an invalid
/// move). All Blueprint mutations should funnel through here.
Future<T?> runBlueprintMutation<T>(
  BuildContext context,
  Future<T> Function() op,
) async {
  try {
    return await op();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeBlueprintError(e))),
      );
    }
    return null;
  }
}

/// Human-readable message for a Blueprint mutation failure, preferring the
/// backend's `detail` field on a Dio error.
String describeBlueprintError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['detail'] is String) {
      return data['detail'] as String;
    }
    return 'Request failed (${error.response?.statusCode ?? 'network error'})';
  }
  return error.toString();
}
