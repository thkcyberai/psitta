import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/providers.dart';
import '../settings/settings_screen.dart';

/// Plan selection screen — accessible from Settings > Change Plan.
///
/// Displays Free and Pro plan cards side by side.
/// The user's current plan is highlighted with a "Current Plan" badge.
/// No payment required (Stripe comes in M3b) — selecting a plan
/// calls PATCH /users/me/plan then navigates back.
class PlanSelectionScreen extends ConsumerStatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  ConsumerState<PlanSelectionScreen> createState() =>
      _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends ConsumerState<PlanSelectionScreen> {
  bool _isSubmitting = false;

  Future<void> _selectPlan(String planId) async {
    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.patch('/users/me/plan', data: {'plan_id': planId});
      // Refresh subscription data so Settings tile updates
      ref.invalidate(subscriptionSummaryProvider);
      if (mounted) context.go('/settings');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set plan: $e')),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final subAsync = ref.watch(subscriptionSummaryProvider);

    final currentPlanId = subAsync.whenOrNull(
      data: (data) => data['plan_id'] as String?,
    );

    final isFree = currentPlanId == null ||
        currentPlanId == 'free';

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back to Settings',
                    onPressed: () => context.go('/settings'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Change Plan',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Select a plan below. You can switch anytime.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PlanCard(
                        title: 'Free',
                        price: 'Free',
                        priceSubtitle: 'No credit card required',
                        features: const [
                          '3 documents per month',
                          'Basic voices (Edge TTS)',
                          '7-day audio cache',
                          'Word-by-word highlighting',
                        ],
                        isCurrent: isFree,
                        buttonLabel: isFree ? 'Current Plan' : 'Switch to Free',
                        isPrimary: false,
                        isLoading: _isSubmitting,
                        onPressed: _isSubmitting || isFree
                            ? null
                            : () => _selectPlan('free'),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _PlanCard(
                        title: 'Pro',
                        price: '\$9.99/mo',
                        priceSubtitle: 'Free during beta',
                        features: const [
                          '50 documents per month',
                          'All premium voices',
                          '90-day audio cache',
                          'Word-by-word highlighting',
                          'Archive documents',
                          'Priority support',
                        ],
                        isCurrent: !isFree,
                        buttonLabel:
                            !isFree ? 'Current Plan' : 'Switch to Pro',
                        isPrimary: true,
                        badge: isFree ? 'Recommended' : null,
                        isLoading: _isSubmitting,
                        onPressed: _isSubmitting || !isFree
                            ? null
                            : () => _selectPlan('pro_monthly'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.priceSubtitle,
    required this.features,
    required this.buttonLabel,
    required this.isPrimary,
    required this.isLoading,
    required this.isCurrent,
    this.badge,
    this.onPressed,
  });

  final String title;
  final String price;
  final String priceSubtitle;
  final List<String> features;
  final String buttonLabel;
  final bool isPrimary;
  final bool isLoading;
  final bool isCurrent;
  final String? badge;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: isCurrent ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCurrent
            ? BorderSide(color: cs.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Current Plan',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.tertiary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Text(
              price,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isPrimary ? cs.primary : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              priceSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(f, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: isCurrent
                  ? FilledButton.tonal(
                      onPressed: null,
                      child: Text(buttonLabel),
                    )
                  : isPrimary
                      ? FilledButton(
                          onPressed: onPressed,
                          child: isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(buttonLabel),
                        )
                      : OutlinedButton(
                          onPressed: onPressed,
                          child: isLoading
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: cs.primary),
                                )
                              : Text(buttonLabel),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
