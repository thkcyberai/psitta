import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/document.dart';
import '../data/providers/providers.dart';

/// Current plan snapshot sourced from [billingStatusProvider].
///
/// Has three mutually exclusive states:
///   * **Pro**    — [isPro] is true (plan != free AND status == active)
///   * **Free**   — [isFree] is true (plan == free)
///   * **Unavailable** — [isUnavailable] is true (billing endpoint is
///     loading or errored). The UI must render an explicit "status
///     temporarily unavailable" affordance for this state instead of
///     silently rendering Free, which would be indistinguishable from a
///     legitimate Free user and silently downgrade a paying Pro user
///     during a transient auth/network failure.
///
/// [source] (T11.2 backend / T11.3b client) discloses which storage
/// path resolved the entitlement: `stripe`, `dev_override`,
/// `tester_allowlist`, or `free`. Used by Settings UI to render the
/// alpha-tester badge and hide the Stripe Customer Portal tile (which
/// would 502 for non-Stripe sources). Defaults to null when the
/// backend doesn't include it (older deployments) — callers must
/// treat null as "unknown source, fall back to legacy isPro/isFree
/// gating".
class PlanStatus {
  const PlanStatus({
    required this.plan,
    required this.status,
    this.isUnavailable = false,
    this.source,
    this.currentPeriodEnd,
    this.elCharsPerPeriod = 0,
    this.llmTokensPerPeriod = 0,
  });

  /// Parse a `/billing/status` response body. Preserves whatever the
  /// backend says; missing fields fall back to free/none (a legitimate
  /// Free state — distinct from the unavailable state below).
  factory PlanStatus.fromMap(Map<String, dynamic> m) {
    final periodEndRaw = m['current_period_end'] as String?;
    DateTime? periodEnd;
    if (periodEndRaw != null && periodEndRaw.isNotEmpty) {
      // ISO-8601 from backend; tryParse fails-soft to null on
      // unexpected shapes so a backend hiccup never crashes Settings.
      periodEnd = DateTime.tryParse(periodEndRaw);
    }
    return PlanStatus(
      plan: (m['plan'] as String?) ?? 'free',
      status: (m['status'] as String?) ?? 'none',
      source: m['source'] as String?,
      currentPeriodEnd: periodEnd,
      elCharsPerPeriod:
          (m['el_chars_per_period'] as num?)?.toInt() ?? 0,
      llmTokensPerPeriod:
          (m['llm_tokens_per_period'] as num?)?.toInt() ?? 0,
    );
  }

  final String plan;
  final String status;
  final bool isUnavailable;

  /// Resolver source from `/billing/status` (T11.2). Null when the
  /// backend response predates the field — callers fall back to
  /// legacy plan/status gating in that case.
  final String? source;

  /// Sunset date for the current entitlement. For Stripe this is the
  /// next billing-anniversary; for tester_allowlist it's the row's
  /// expires_at. Null for Free.
  final DateTime? currentPeriodEnd;

  /// ElevenLabs character allowance per billing period for this plan.
  /// 0 means no EL access (Free and plans without premium TTS).
  /// Mirrors plan_limits.py `el_chars_per_period`.
  final int elCharsPerPeriod;

  /// LLM token allowance per billing period for this plan.
  /// 0 means no LLM feature access (Free and Reading Nook Pro).
  /// > 0 entitles Writing Nook Pro and Creative Nook Pro to Summarize-it.
  /// Mirrors plan_limits.py `llm_tokens_per_period`.
  final int llmTokensPerPeriod;

  /// Subscription statuses that grant entitlement on the client.
  ///
  /// Mirrors the backend resolver contract (A4): `status IN ('active',
  /// 'trialing')` is entitled. Everything else — canceled, past_due,
  /// incomplete, incomplete_expired, unpaid, paused, none — is denied.
  ///
  /// PAC-2A surgical fix (2026-07-20): previously only 'active' was
  /// accepted here, so a Stripe trial subscriber passed backend gates and
  /// `plan == 'writing_nook_pro'` string checks but failed every isPro
  /// gate — a mixed Free/Pro interface during the trial. Temporary
  /// compatibility shim: PAC-2B replaces this legacy isPro path with
  /// server-resolved capabilities.
  static const Set<String> entitledStatuses = {'active', 'trialing'};

  /// PAC-2B: legacy feature gating is retired — zero production
  /// consumers remain. Gate on server-resolved capabilities instead
  /// (core/capabilities.dart: hasCapabilityProvider / CapabilityGate).
  /// Kept, with its contract tests, purely as the guard on the
  /// /billing/status entitlement contract until PlanStatus gating is
  /// removed wholesale in PAC-6.
  @Deprecated('Gate on capabilities (core/capabilities.dart); '
      'removal scheduled with PlanStatus retirement in PAC-6')
  bool get isPro =>
      !isUnavailable && plan != 'free' && entitledStatuses.contains(status);
  bool get isFree => !isUnavailable && plan == 'free';

  /// True when entitlement was resolved via the alpha tester allowlist
  /// (Item 11). Implies [isPro] is also true (allowlist users get
  /// reading_nook_pro entitlement), but no Stripe customer record
  /// exists — Stripe Customer Portal must be hidden for this state.
  bool get isTesterAllowlist => source == 'tester_allowlist';

  /// True only when entitlement was resolved via an active Stripe
  /// subscription. Distinct from [isPro], which is true for ANY active
  /// Pro source (stripe, dev_override, tester_allowlist). Use this for
  /// surfaces that require a live Stripe customer record — Customer
  /// Portal, payment-method updates, invoice history — because those
  /// would 502 for non-Stripe sources (KL 2026-05-22b).
  /// PAC-2A: accepts 'trialing' alongside 'active' — a trialing customer
  /// has a live Stripe subscription and MUST be able to reach the
  /// Customer Portal (e.g. to cancel before the trial converts).
  bool get isStripeSubscribed =>
      !isUnavailable &&
      plan != 'free' &&
      entitledStatuses.contains(status) &&
      source == 'stripe';

  static const free = PlanStatus(plan: 'free', status: 'none');
  static const unavailable = PlanStatus(
    plan: 'unavailable',
    status: 'unavailable',
    isUnavailable: true,
  );
}

/// Resolved plan for the current user.
///
/// Resolves to [PlanStatus.unavailable] while billing is loading OR
/// errored — distinct from [PlanStatus.free]. PAC-2B: feature gating
/// no longer reads this — gate on server-resolved capabilities
/// (core/capabilities.dart). Remaining consumers are billing surfaces:
/// [PlanStatus.isStripeSubscribed] (Customer Portal), the app.dart
/// confirmed-Free downgrade clamp, and plan-selection checkout UI.
final planStatusProvider = Provider.autoDispose<PlanStatus>((ref) {
  final billing = ref.watch(billingStatusProvider);
  return billing.when(
    data: PlanStatus.fromMap,
    loading: () => PlanStatus.unavailable,
    error: (_, __) => PlanStatus.unavailable,
  );
});

// PAC-2B: isProUserProvider, monthlyDocLimitFor and maxSpeedFor are
// DELETED. Entitlement is gated on server-resolved capabilities
// (core/capabilities.dart); numeric limits come from the capability
// payload (`limits.doc_cap`, `limits.max_playback_speed`).

// ── Per-plan numeric limit constants ─────────────────────────────────────
// Retained: showUploadLimitPrompt copy (kProMonthlyDocLimit), the
// Settings speed-subtitle threshold (kProMaxSpeed), and the app.dart
// confirmed-Free downgrade clamp (kFreeMaxSpeed) still reference them.
// They mirror backend plan_limits and are pinned by plan_gate_test.

/// Monthly document upload limits by plan.
const int kFreeMonthlyDocLimit = 10;
const int kProMonthlyDocLimit = 50;

/// Playback speed ceilings by plan.
const double kFreeMaxSpeed = 2.0;
const double kProMaxSpeed = 4.0;

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
  String requiredPlan = 'Writing Nook Pro',
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
  String requiredPlan = 'Writing Nook Pro',
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
        'plan. Upgrade to Writing Nook Pro for $kProMonthlyDocLimit '
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
