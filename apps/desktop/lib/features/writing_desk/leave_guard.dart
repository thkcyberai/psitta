import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'desk_providers.dart';

enum _LeaveChoice { save, discard, cancel }

/// Guards navigation away from the Writing Desk while it holds unsaved edits.
///
/// Returns `true` when it is safe to leave (nothing unsaved, the writer saved,
/// or the writer chose to discard) and `false` when the writer cancelled and
/// should stay put. Shows the Save / Don't save / Cancel dialog *only* when
/// there are unsaved edits, so read mode and clean documents leave instantly.
///
/// Takes only a [BuildContext] (no ref) so it can be called from both widgets
/// (WidgetRef) and the router's `onExit` (Ref): the provider container is read
/// off the context, which sits under the root [ProviderScope] in both cases.
Future<bool> confirmLeaveWritingDesk(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  if (!container.read(deskDirtyProvider)) return true;

  final loc = AppLocalizations.of(context);
  final choice = await showDialog<_LeaveChoice>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(loc.deskUnsavedTitle),
      content: Text(loc.deskUnsavedBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(_LeaveChoice.cancel),
          child: Text(loc.deskUnsavedCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(_LeaveChoice.discard),
          child: Text(loc.deskUnsavedDiscard),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(_LeaveChoice.save),
          child: Text(loc.deskUnsavedSave),
        ),
      ],
    ),
  );

  switch (choice) {
    case _LeaveChoice.save:
      final save = container.read(deskSaveActionProvider);
      try {
        if (save != null) await save();
      } catch (_) {
        // The Desk's own save-state surfaces failures; don't wedge navigation.
      }
      container.read(deskDirtyProvider.notifier).state = false;
      return true;
    case _LeaveChoice.discard:
      // Abandon the in-memory edits; the Desk is about to be torn down.
      container.read(deskDirtyProvider.notifier).state = false;
      return true;
    case _LeaveChoice.cancel:
    case null:
      return false;
  }
}
