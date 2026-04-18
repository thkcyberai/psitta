import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/document.dart';
import '../data/providers/providers.dart';

/// Current plan snapshot sourced from [billingStatusProvider].
///
/// A user is "Pro" iff [plan] is non-free AND [status] is active.
/// Anything else -- loading, errored, past-due, canceled -- falls back
/// to the most restrictive behavior (free tier), so gating defaults to
/// safety when the billing endpoint is briefly unavailable.
class PlanStatus {
  const PlanStatus({required this.plan, required this.status});

  final String plan;
  final String status;

  bool get isPro => plan != 'free' && status == 'active';

  static const free = PlanStatus(plan: 'free', status: 'none');
}

/// Resolved plan for the current user. Resolves to [PlanStatus.free] while
/// billing is loading or errored.
final planStatusProvider = Provider.autoDispose<PlanStatus>((ref) {
  final billing = ref.watch(billingStatusProvider);
  return billing.whenOrNull(
        data: (data) => PlanStatus(
          plan: (data['plan'] as String?) ?? 'free',
          status: (data['status'] as String?) ?? 'none',
        ),
      ) ??
      PlanStatus.free;
});

/// Convenience boolean: true when the user has any active paid plan.
final isProUserProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(planStatusProvider).isPro;
});

// ── Per-plan numeric limits ──────────────────────────────────────────────

/// Monthly document upload limits by plan.
const int kFreeMonthlyDocLimit = 3;
const int kProMonthlyDocLimit = 50;

/// Playback speed ceilings by plan.
const double kFreeMaxSpeed = 2.0;
const double kProMaxSpeed = 4.0;

int monthlyDocLimitFor(PlanStatus plan) =>
    plan.isPro ? kProMonthlyDocLimit : kFreeMonthlyDocLimit;

double maxSpeedFor(PlanStatus plan) =>
    plan.isPro ? kProMaxSpeed : kFreeMaxSpeed;

/// Returns the number of documents whose [Document.createdAt] falls in the
/// current calendar month (local time). Used to preflight the upload
/// limit before hitting the backend; the backend is the ultimate authority
/// and will return 402 if the limit is actually exceeded.
int countDocumentsThisMonth(Iterable<Document> docs) {
  final now = DateTime.now();
  final year = now.year;
  final month = now.month;
  return docs
      .where((d) {
        final c = d.createdAt.toLocal();
        return c.year == year && c.month == month;
      })
      .length;
}

// ── Upgrade prompts ──────────────────────────────────────────────────────

/// Full-modal upgrade prompt. Routes to the Change Plan screen on accept.
Future<void> showUpgradePrompt(
  BuildContext context, {
  required String featureName,
  String requiredPlan = 'Reading Nook Pro',
  String? message,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.lock_outline, size: 32),
      title: const Text('Upgrade required'),
      content: Text(
        message ??
            '$featureName requires $requiredPlan. Upgrade your plan to '
                'unlock this feature.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            context.go('/plan');
          },
          child: const Text('Upgrade'),
        ),
      ],
    ),
  );
}

/// Lightweight snackbar variant -- used where a full modal would be
/// disruptive (e.g., tapping a locked voice tile).
void showUpgradeSnackbar(
  BuildContext context, {
  required String featureName,
  String requiredPlan = 'Reading Nook Pro',
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('$featureName requires $requiredPlan'),
        action: SnackBarAction(
          label: 'Upgrade',
          onPressed: () => context.go('/plan'),
        ),
      ),
    );
}

/// Dialog shown when a free user tries to upload past their monthly limit.
Future<void> showUploadLimitPrompt(
  BuildContext context, {
  required int limit,
  required int used,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.cloud_off_outlined, size: 32),
      title: const Text('Monthly upload limit reached'),
      content: Text(
        "You've uploaded $used of $limit documents this month on the Free "
        'plan. Upgrade to Reading Nook Pro for $kProMonthlyDocLimit '
        'documents per month.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            context.go('/plan');
          },
          child: const Text('Upgrade'),
        ),
      ],
    ),
  );
}
