import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/providers/providers.dart';

/// Re-export the quota data surface so consumers need to touch only one
/// import when wiring quota-aware UI. [QuotaInfo] and [quotaUsageProvider]
/// are defined in `providers.dart` to keep the data-fetch provider next to
/// its peers; their UX counterparts ([QuotaBanner], [showQuotaDialog],
/// [quotaBannerDismissedProvider]) live here.
export '../data/providers/providers.dart' show QuotaInfo, quotaUsageProvider;

/// Session-scoped dismiss state for the Library quota banner. Intentionally
/// `autoDispose` so the dismissal is in-memory only — on next app launch
/// the banner reappears if the user is still at quota. Not persisted to
/// SharedPreferences on purpose: a persisted dismissal would hide legitimate
/// warnings across billing-period boundaries.
final quotaBannerDismissedProvider =
    StateProvider.autoDispose<bool>((ref) => false);

const Map<String, String> _kPlanDisplayNames = {
  'free': 'Free',
  'pro_monthly': 'Reading Nook Pro',
  'pro_annual': 'Reading Nook Pro',
  // Forward-compat: the `/billing/status` endpoint uses different plan
  // strings (`reading_nook_pro`, `creative_nook_pro`) — include them so
  // the dialog renders a human name even if the call site ever passes a
  // QuotaInfo derived from billing status instead of subscription summary.
  'reading_nook_pro': 'Reading Nook Pro',
  'creative_nook_pro': 'Creative Nook Pro',
};

String planDisplayName(String planId) =>
    _kPlanDisplayNames[planId] ?? planId;

const List<String> _kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Human-readable reset date rendered in the user's local timezone. The
/// backend keys the counter by UTC `YYYY-MM`, so we convert the UTC
/// midnight boundary to local time before formatting to match what the
/// user perceives as "the first of next month".
String formatResetDate(DateTime resetDateUtc) {
  final local = resetDateUtc.toLocal();
  return '${_kMonthNames[local.month - 1]} ${local.day}, ${local.year}';
}

/// Compact tooltip copy used by disabled New Sheet / Upload buttons.
String quotaTooltip(QuotaInfo info) =>
    'Monthly limit reached (${info.used}/${info.limit}). '
    'Resets ${formatResetDate(info.resetDate)}.';

/// Quota-reached banner rendered above the Library document grid.
///
/// Only visible when the user is at quota AND has not dismissed the
/// banner this session. Pure stateless-widget read of two providers — no
/// local state here so themes and provider changes propagate cleanly.
class QuotaBanner extends ConsumerWidget {
  const QuotaBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotaAsync = ref.watch(quotaUsageProvider);
    final dismissed = ref.watch(quotaBannerDismissedProvider);

    final info = quotaAsync.whenOrNull(data: (q) => q);
    if (info == null || !info.atLimit || dismissed) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isFree = info.plan == 'free';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.error.withOpacity(0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 20, color: cs.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "You've reached your monthly document limit "
                '(${info.used}/${info.limit}). You can continue reading '
                'existing documents. Your quota resets on '
                '${formatResetDate(info.resetDate)}.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onErrorContainer,
                ),
              ),
            ),
            if (isFree) ...[
              const SizedBox(width: 12),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: cs.onErrorContainer,
                ),
                onPressed: () => context.go('/plan'),
                child: const Text('Upgrade'),
              ),
            ],
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: cs.onErrorContainer),
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              onPressed: () => ref
                  .read(quotaBannerDismissedProvider.notifier)
                  .state = true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Safety-net dialog shown when a mutation returns 402 or when a button
/// handler detects the user is at quota before it even tries the call.
///
/// Free users see an Upgrade CTA that navigates to `/plan`; Pro users get
/// a simple acknowledge button since no action is available to them
/// beyond waiting for the monthly reset.
Future<void> showQuotaDialog(
  BuildContext context,
  QuotaInfo info,
) async {
  final isFree = info.plan == 'free';
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        icon: const Icon(Icons.cloud_off_outlined, size: 32),
        title: const Text('Monthly limit reached'),
        content: Text(
          "You've used ${info.used} of ${info.limit} documents this month "
          'on the ${planDisplayName(info.plan)} plan. '
          'Your quota resets on ${formatResetDate(info.resetDate)}.',
        ),
        actions: isFree
            ? [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go('/plan');
                  },
                  child: const Text('Upgrade'),
                ),
              ]
            : [
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Got it'),
                ),
              ],
      );
    },
  );
}

// ── EL quota helpers (C.4) ───────────────────────────────────────────

/// Format an integer with thousands separators. Hand-rolled — `intl`
/// is not yet a desktop dependency and pulling it in for one format
/// call is overkill.
String formatElChars(int chars) {
  final s = chars.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
    buffer.write(s[i]);
  }
  return buffer.toString();
}

/// Subtitle string for the Settings premium-voices tile.
String elQuotaSubtitle(QuotaInfo info) {
  final used = formatElChars(info.elCharsUsed);
  final limit = formatElChars(info.elCharsLimit);
  if (info.elAtLimit) {
    return '$used / $limit chars used this period (limit reached)';
  }
  return '$used / $limit chars used this period';
}

/// Progress-bar color resolver:
///   <90%   → primary
///   90–99% → tertiary (warning)
///   ≥100%  → error
Color elProgressColor(BuildContext context, QuotaInfo info) {
  final cs = Theme.of(context).colorScheme;
  if (info.elAtLimit) return cs.error;
  if (info.elNearLimit) return cs.tertiary;
  return cs.primary;
}

/// Show a one-shot toast when the user has hit their EL quota for the
/// current billing period. Period-stamped SharedPreferences key
/// prevents duplicate display within the same period; when
/// [QuotaInfo.elCharsResetAt] rolls forward the key changes and the
/// toast becomes fresh — implicit reset, no manual cleanup needed.
///
/// Returns true if the toast was just shown.
Future<bool> maybeShowElQuotaToast({
  required BuildContext context,
  required String userId,
  required QuotaInfo info,
}) async {
  if (!info.elAtLimit) return false;
  final periodIso =
      info.elCharsResetAt?.toIso8601String() ?? 'no-period';
  final prefs = await SharedPreferences.getInstance();
  final key = 'user_${userId}_el_quota_toast_$periodIso';
  if (prefs.getBool(key) == true) return false;
  if (!context.mounted) return false;
  final resetClause = info.elCharsResetAt != null
      ? 'until ${formatResetDate(info.elCharsResetAt!)}'
      : 'for the rest of this period';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        "You've used your premium voice allowance for this period. "
        'Standard voices will be used $resetClause.',
      ),
      duration: const Duration(seconds: 6),
    ),
  );
  await prefs.setBool(key, true);
  return true;
}

/// Session-scoped dismiss state for the Library premium-voices banner.
/// Mirrors [quotaBannerDismissedProvider] semantics — in-memory only
/// so the banner reappears on next app launch if the user is still
/// over the threshold. Not persisted on purpose: a persisted
/// dismissal could hide legitimate warnings across billing-period
/// boundaries.
final elQuotaBannerDismissedProvider =
    StateProvider.autoDispose<bool>((ref) => false);

/// Premium-voices banner above the Library document grid. Two-stage:
///   90–99% — soft heads-up, tertiary tone
///   ≥100%  — at-limit, error tone (matches docs banner)
class ElQuotaBanner extends ConsumerWidget {
  const ElQuotaBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotaAsync = ref.watch(quotaUsageProvider);
    final dismissed = ref.watch(elQuotaBannerDismissedProvider);

    final info = quotaAsync.whenOrNull(data: (q) => q);
    if (info == null || !info.elNearLimit || dismissed) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final atLimit = info.elAtLimit;
    final pct = (info.elFraction * 100).round();

    final containerColor =
        atLimit ? cs.errorContainer : cs.tertiaryContainer;
    final onContainer =
        atLimit ? cs.onErrorContainer : cs.onTertiaryContainer;
    final borderColor = atLimit
        ? cs.error.withOpacity(0.25)
        : cs.tertiary.withOpacity(0.25);

    final resetSuffix = info.elCharsResetAt != null
        ? formatResetDate(info.elCharsResetAt!)
        : 'next period';
    final body = atLimit
        ? 'Premium voice allowance reached. Standard voices will be '
            'used until $resetSuffix.'
        : "You've used $pct% of your premium voice allowance for this period.";

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.graphic_eq_outlined, size: 20, color: onContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: onContainer,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: onContainer),
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              onPressed: () => ref
                  .read(elQuotaBannerDismissedProvider.notifier)
                  .state = true,
            ),
          ],
        ),
      ),
    );
  }
}
