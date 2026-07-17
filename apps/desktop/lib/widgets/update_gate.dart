import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_version.dart';
import '../core/client_config.dart';

/// Enforces the server-owned minimum client version (the `/config` control
/// plane) at the app root.
///
/// * [UpdateStatus.updateRequired] → replaces the whole app with a blocking
///   "update required" screen. This is the remote kill switch for outdated
///   builds: raising `minimum_supported_version` above a client's version
///   walls it off until it updates.
/// * [UpdateStatus.updateRecommended] and [UpdateStatus.upToDate] → render the
///   app normally (an optional soft-nudge for "recommended" is a future step).
///
/// Fail-open by construction: [updateStatusProvider] resolves to
/// [UpdateStatus.upToDate] whenever `/config` is loading or errored, so a
/// network or config fault can never block the app.
class UpdateGate extends ConsumerWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(updateStatusProvider);
    if (status == UpdateStatus.updateRequired) {
      return const _UpdateRequiredScreen();
    }
    return child;
  }
}

class _UpdateRequiredScreen extends ConsumerWidget {
  const _UpdateRequiredScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.system_update_alt,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Update required',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'This version of Psitta is no longer supported. Please close '
                  'and reopen Psitta to install the latest update, then sign in '
                  'again.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(clientConfigProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check again'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Installed version $clientVersion',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
