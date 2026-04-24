import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
