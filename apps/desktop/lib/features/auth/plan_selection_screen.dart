import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/providers/providers.dart';

/// Plan selection screen — accessible from Settings > Change Plan.
///
/// Shows three tiers (Free, Reading Nook Pro, Creative Nook Pro).
/// The Pro card exposes a monthly/annual toggle that drives the Stripe
/// lookup_key sent to /billing/checkout-session. On success the checkout
/// URL opens in the system browser (Stripe-hosted), and the screen polls
/// /billing/status every 3 seconds up to 30 seconds until the webhook
/// activates the subscription.
class PlanSelectionScreen extends ConsumerStatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  ConsumerState<PlanSelectionScreen> createState() =>
      _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends ConsumerState<PlanSelectionScreen> {
  bool _isAnnual = false;
  bool _isSubmitting = false;

  // Post-checkout polling — drives the UI to flip to "Current Plan" on Pro
  // once the Stripe webhook has activated the subscription on the backend.
  Timer? _pollTimer;
  int _pollAttempts = 0;
  static const int _maxPollAttempts = 10;
  static const Duration _pollInterval = Duration(seconds: 3);

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  String get _selectedLookupKey =>
      _isAnnual ? 'reading_nook_pro_annual' : 'reading_nook_pro_monthly';

  Future<void> _startCheckout() async {
    setState(() => _isSubmitting = true);
    final api = ref.read(apiClientProvider);
    try {
      final response = await api.dio.post(
        '/billing/checkout-session',
        data: {'lookup_key': _selectedLookupKey},
      );
      final data = response.data as Map<String, dynamic>;
      final checkoutUrl = data['checkout_url'] as String?;
      if (checkoutUrl == null) {
        _showSnack('Payment service returned no checkout URL.');
        return;
      }

      final launched = await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showSnack('Could not open browser. Please try again.');
        return;
      }

      _showSnack(
        'Complete your payment in the browser. This page will update automatically.',
        durationSeconds: 6,
      );
      _beginStatusPolling();
    } on DioException catch (e) {
      _handleCheckoutError(e);
    } catch (e) {
      _showSnack('Connection error. Please check your internet.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _handleCheckoutError(DioException e) {
    final status = e.response?.statusCode;
    switch (status) {
      case 400:
        _showSnack('Invalid plan selected');
      case 409:
        _showSnack('You already have an active subscription');
      case 502:
        _showSnack('Payment service temporarily unavailable. Please try again.');
      default:
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          _showSnack('Connection error. Please check your internet.');
        } else {
          _showSnack('Payment service error. Please try again.');
        }
    }
  }

  void _beginStatusPolling() {
    _pollTimer?.cancel();
    _pollAttempts = 0;
    _pollTimer = Timer.periodic(_pollInterval, (timer) async {
      _pollAttempts += 1;
      if (!mounted) {
        timer.cancel();
        return;
      }
      try {
        final api = ref.read(apiClientProvider);
        final response = await api.dio.get('/billing/status');
        final data = response.data as Map<String, dynamic>;
        final plan = data['plan'] as String?;
        final status = data['status'] as String?;
        if (plan == 'reading_nook_pro' && status == 'active') {
          timer.cancel();
          ref.invalidate(billingStatusProvider);
          _showSnack('Welcome to Reading Nook Pro!');
          return;
        }
      } catch (_) {
        // Transient poll failures are ignored — next tick retries.
      }
      if (_pollAttempts >= _maxPollAttempts) {
        timer.cancel();
        _showSnack(
          'Payment processing. Your plan will update shortly.',
          durationSeconds: 6,
        );
        // Trigger a final refresh so the webhook's eventual write appears
        // the moment the user revisits this screen.
        ref.invalidate(billingStatusProvider);
      }
    });
  }

  void _showSnack(String message, {int durationSeconds = 4}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: durationSeconds),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final statusAsync = ref.watch(billingStatusProvider);

    final currentPlan = statusAsync.whenOrNull(
          data: (data) => data['plan'] as String?,
        ) ??
        'free';
    final isFree = currentPlan == 'free';
    final isPro = currentPlan == 'reading_nook_pro';

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
                'This helps you write better.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              _BillingPeriodToggle(
                isAnnual: _isAnnual,
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(() => _isAnnual = value),
              ),
              const SizedBox(height: 32),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PlanCard(
                        tierName: 'Free',
                        title: 'Read',
                        price: '\$0',
                        priceSubtitle: 'No credit card required',
                        features: const [
                          _PlanFeature('Listen to your documents'),
                          _PlanFeature('Basic voices'),
                          _PlanFeature('3 documents per month'),
                          _PlanFeature('Edit DOCX in real time',
                              included: false),
                          _PlanFeature('Premium voices', included: false),
                          _PlanFeature('50 documents per month',
                              included: false),
                          _PlanFeature('Word-by-word highlighting',
                              included: false),
                          _PlanFeature('Download branded DOCX',
                              included: false),
                          _PlanFeature('Archive documents', included: false),
                          _PlanFeature('Priority support', included: false),
                          _PlanFeature('Creative Nooks', included: false),
                        ],
                        isCurrent: isFree,
                        buttonLabel: isFree ? 'Current Plan' : 'Get Started',
                        isPrimary: false,
                        isLoading: false,
                        // Downgrade path is not wired yet — disabled for Pro users.
                        onPressed: null,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _PlanCard(
                        tierName: 'Reading Nook Pro',
                        title: 'Read. Refine.',
                        price: _isAnnual ? '\$119/yr' : '\$14.99/mo',
                        priceSubtitle: _isAnnual
                            ? '\$9.92/mo billed annually'
                            : 'Billed monthly',
                        features: const [
                          _PlanFeature('Listen while you write'),
                          _PlanFeature('Edit DOCX in real time'),
                          _PlanFeature('Premium voices'),
                          _PlanFeature('50 documents per month'),
                          _PlanFeature('Word-by-word highlighting'),
                          _PlanFeature('Download branded DOCX'),
                          _PlanFeature('Archive documents'),
                          _PlanFeature('Priority support'),
                          _PlanFeature('Creative Nooks', included: false),
                        ],
                        isCurrent: isPro,
                        buttonLabel: isPro ? 'Current Plan' : 'Upgrade',
                        isPrimary: true,
                        savingsLabel:
                            _isAnnual && !isPro ? 'Save 34%' : null,
                        isLoading: _isSubmitting,
                        onPressed: _isSubmitting || isPro
                            ? null
                            : _startCheckout,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _PlanCard(
                        tierName: 'Creative Nook Pro',
                        title: 'Create. Refine. Research.',
                        price: _isAnnual ? '\$199/yr' : '\$19.99/mo',
                        priceSubtitle: _isAnnual
                            ? '\$16.58/mo billed annually'
                            : 'Billed monthly',
                        features: const [
                          _PlanFeature('Premium voices'),
                          _PlanFeature('50 documents per month'),
                          _PlanFeature('Word-by-word highlighting'),
                          _PlanFeature('Download branded DOCX'),
                          _PlanFeature('Archive documents'),
                          _PlanFeature('Priority support'),
                          _PlanFeature('Creative Nooks — coming soon',
                              comingSoon: true),
                          _PlanFeature(
                              'AI-assisted writing workflows — coming soon',
                              comingSoon: true),
                        ],
                        isCurrent: false,
                        buttonLabel: 'Coming Soon',
                        isPrimary: false,
                        isLoading: false,
                        comingSoon: true,
                        savingsLabel: _isAnnual ? 'Save 17%' : null,
                        onPressed: null,
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

class _BillingPeriodToggle extends StatelessWidget {
  const _BillingPeriodToggle({
    required this.isAnnual,
    required this.onChanged,
  });

  final bool isAnnual;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleOption(
            label: 'Monthly',
            selected: !isAnnual,
            onTap: onChanged == null ? null : () => onChanged!(false),
          ),
          _ToggleOption(
            label: 'Annual',
            trailingBadge: 'Save 34%',
            selected: isAnnual,
            onTap: onChanged == null ? null : () => onChanged!(true),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailingBadge,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final String? trailingBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected ? cs.onPrimary : cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (trailingBadge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? cs.onPrimary.withOpacity(0.2)
                      : cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  trailingBadge!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color:
                        selected ? cs.onPrimary : cs.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.tierName,
    required this.title,
    required this.price,
    required this.priceSubtitle,
    required this.features,
    required this.buttonLabel,
    required this.isPrimary,
    required this.isLoading,
    required this.isCurrent,
    this.savingsLabel,
    this.comingSoon = false,
    this.onPressed,
  });

  /// Plan tier identifier shown above the marketing headline (e.g.
  /// "Reading Nook Pro" sitting above "Read. Refine."). Smaller +
  /// muted to anchor the headline without competing with it.
  final String tierName;
  final String title;
  final String price;
  final String priceSubtitle;
  final List<_PlanFeature> features;
  final String buttonLabel;
  final bool isPrimary;
  final bool isLoading;
  final bool isCurrent;
  /// Optional discount pill (e.g. "Save 34%"). Rendered alongside any
  /// status pill so Creative Nook Pro can show both "Coming Soon" and
  /// "Save 17%" simultaneously when the annual toggle is active.
  final String? savingsLabel;
  final bool comingSoon;
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
            Text(
              tierName,
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: 13,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            // Wrap — so the savings pill can flow to a second line instead
            // of overflowing when a card has both a status pill and a
            // savings pill (e.g. Creative Nook Pro on the annual toggle).
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (isCurrent)
                  _Pill(
                    label: 'Current Plan',
                    background: cs.primary,
                    foreground: cs.onPrimary,
                  )
                else if (comingSoon)
                  _Pill(
                    label: 'Coming Soon',
                    background: cs.surfaceContainerHighest,
                    foreground: cs.onSurfaceVariant,
                  ),
                if (savingsLabel != null)
                  _Pill(
                    label: savingsLabel!,
                    background: cs.tertiary,
                    foreground: cs.onTertiary,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              price,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: comingSoon
                    ? cs.onSurfaceVariant
                    : (isPrimary ? cs.primary : null),
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
            ...features.map((f) => _FeatureRow(feature: f)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: _buildButton(theme, cs),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(ThemeData theme, ColorScheme cs) {
    if (comingSoon || isCurrent || onPressed == null) {
      return FilledButton.tonal(
        onPressed: null,
        child: Text(buttonLabel),
      );
    }
    final child = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isPrimary ? Colors.white : cs.primary,
            ),
          )
        : Text(buttonLabel);
    return isPrimary
        ? FilledButton(onPressed: onPressed, child: child)
        : OutlinedButton(onPressed: onPressed, child: child);
  }
}

/// A single feature entry in a plan card. Three presentation modes:
///   - default (`included: true`) — green check + normal text
///   - excluded (`included: false`) — gray dash + muted text
///   - coming soon (`comingSoon: true`) — clock icon + italic muted text
/// ``comingSoon`` takes precedence over ``included`` when both are set.
class _PlanFeature {
  const _PlanFeature(
    this.label, {
    this.included = true,
    this.comingSoon = false,
  });
  final String label;
  final bool included;
  final bool comingSoon;
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature});

  final _PlanFeature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final IconData icon;
    final Color iconColor;
    final Color? textColor;
    final FontStyle fontStyle;

    if (feature.comingSoon) {
      icon = Icons.schedule;
      iconColor = cs.onSurfaceVariant.withOpacity(0.75);
      textColor = cs.onSurfaceVariant;
      fontStyle = FontStyle.italic;
    } else if (feature.included) {
      icon = Icons.check_circle_outline;
      iconColor = Colors.green.shade600;
      textColor = theme.textTheme.bodyMedium?.color;
      fontStyle = FontStyle.normal;
    } else {
      icon = Icons.remove_circle_outline;
      iconColor = cs.onSurface.withOpacity(0.28);
      textColor = cs.onSurfaceVariant.withOpacity(0.7);
      fontStyle = FontStyle.normal;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              feature.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontStyle: fontStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
