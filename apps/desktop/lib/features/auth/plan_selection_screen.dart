import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/providers/providers.dart';
import '../../data/services/auth_service.dart';

/// Plan selection screen — accessible from the sidebar "Plans" entry and
/// Settings > Change Plan.
///
/// Shows four tiers (Free, Reading Nook, Writing Nook, Creative Nook). The two
/// purchasable Pro cards (Reading + Writing) expose the shared monthly/annual
/// toggle that drives the Stripe lookup_key sent to /billing/checkout-session.
/// On success the checkout URL opens in the system browser (Stripe-hosted) and
/// the screen polls /billing/status until the webhook activates the plan.
///
/// Tier ranks gate the CTAs: a user can only upgrade to a higher tier; a tier
/// they already get (via a higher plan) shows "Included".
class PlanSelectionScreen extends ConsumerStatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  ConsumerState<PlanSelectionScreen> createState() =>
      _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends ConsumerState<PlanSelectionScreen> {
  bool _isAnnual = false;
  bool _isSubmitting = false;

  /// Which paid tier's checkout is in flight ('reading_nook_pro' /
  /// 'writing_nook_pro'), so only that card shows a spinner.
  String _checkoutBase = '';

  // Creative Nook waitlist state. The Creative card is gated as "Coming Soon";
  // clicking the CTA POSTs the user's email to /waitlist/creativity-nook.
  // Backend dedupes via ON CONFLICT (email) DO NOTHING, so re-submission is
  // harmless.
  bool _isWaitlistSubmitting = false;
  bool _isOnWaitlist = false;

  // Post-checkout polling — flips the card to "Current Plan" once the Stripe
  // webhook has activated the subscription on the backend.
  Timer? _pollTimer;
  int _pollAttempts = 0;
  static const int _maxPollAttempts = 10;
  static const Duration _pollInterval = Duration(seconds: 3);

  /// Tier ordering used to gate upgrade/downgrade affordances.
  static const Map<String, int> _rank = {
    'free': 0,
    'reading_nook_pro': 1,
    'writing_nook_pro': 2,
    'creative_nook_pro': 3,
  };

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _startCheckout(String base) async {
    setState(() {
      _isSubmitting = true;
      _checkoutBase = base;
    });
    final lookupKey = '${base}_${_isAnnual ? 'annual' : 'monthly'}';
    final api = ref.read(apiClientProvider);
    try {
      final response = await api.dio.post(
        '/billing/checkout-session',
        data: {'lookup_key': lookupKey},
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
        'Complete your payment in the browser. This page will update '
        'automatically.',
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
        _showSnack('That plan is not available yet. Please try again later.');
      case 409:
        _showSnack('You already have an active subscription');
      case 502:
        _showSnack(
            'Payment service temporarily unavailable. Please try again.');
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

  Future<void> _joinWaitlist() async {
    if (_isOnWaitlist || _isWaitlistSubmitting) return;
    setState(() => _isWaitlistSubmitting = true);
    try {
      final authService = ref.read(authServiceProvider);
      final idToken = await authService.getIdToken();
      final token = idToken ?? await authService.getAccessToken();
      String? email;
      if (token != null) {
        try {
          final claims = JwtDecoder.decode(token);
          email = (claims['email'] as String?) ??
              (claims['https://psitta.app/email'] as String?);
        } catch (_) {
          email = null;
        }
      }
      if (email == null || email.isEmpty) {
        _showSnack('Could not read your email. Please try again later.');
        return;
      }
      final api = ref.read(apiClientProvider);
      final response = await api.dio.post(
        '/waitlist/creativity-nook',
        data: {'email': email},
      );
      if (response.statusCode == 200) {
        setState(() => _isOnWaitlist = true);
        _showSnack(
          "You're on the waitlist. We'll email you when Creative Nook "
          'launches.',
          durationSeconds: 5,
        );
      } else {
        _showSnack('Could not save your spot. Please try again.');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        _showSnack('Connection error. Please check your internet.');
      } else {
        _showSnack('Could not save your spot. Please try again.');
      }
    } catch (_) {
      _showSnack('Could not save your spot. Please try again.');
    } finally {
      if (mounted) setState(() => _isWaitlistSubmitting = false);
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
        if ((plan == 'reading_nook_pro' ||
                plan == 'writing_nook_pro' ||
                plan == 'creative_nook_pro') &&
            status == 'active') {
          timer.cancel();
          ref.invalidate(billingStatusProvider);
          _showSnack('Your plan is active. Welcome!');
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

    final statusHasError = statusAsync.hasError;
    final statusIsLoading = statusAsync.isLoading;
    final statusReady = !statusHasError && !statusIsLoading;
    final currentPlan = statusAsync.whenOrNull(
          data: (data) => data['plan'] as String?,
        ) ??
        'free';
    // -1 while loading/error so no card is marked current and the CTAs stay in
    // their default state (mirrors the prior false-on-loading guard).
    final currentRank = statusReady ? (_rank[currentPlan] ?? 0) : -1;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
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
                    'Plans',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you finish your book.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              if (statusHasError) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.error.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 20, color: cs.onErrorContainer),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Plan status temporarily unavailable. '
                          'Your current plan cannot be shown right now.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onErrorContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: cs.onErrorContainer,
                        ),
                        onPressed: () =>
                            ref.invalidate(billingStatusProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ] else if (statusIsLoading) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Loading your plan…',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 28),
              _BillingPeriodToggle(
                isAnnual: _isAnnual,
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(() => _isAnnual = value),
              ),
              const SizedBox(height: 28),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _freeCard(currentRank)),
                    const SizedBox(width: 18),
                    Expanded(child: _readingCard(currentRank)),
                    const SizedBox(width: 18),
                    Expanded(child: _writingCard(currentRank)),
                    const SizedBox(width: 18),
                    Expanded(child: _creativeCard()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Cards ──────────────────────────────────────────────────────────────────

  Widget _freeCard(int currentRank) {
    final isCurrent = currentRank == 0;
    return _PlanCard(
      tierName: 'Free',
      title: 'Read',
      price: '\$0',
      priceSubtitle: '',
      features: const [
        _PlanFeature('Listen to your documents'),
        _PlanFeature('Basic voices'),
        _PlanFeature('10 documents per month'),
        _PlanFeature('Premium voices', included: false),
        _PlanFeature('Word-by-word highlighting', included: false),
        _PlanFeature('Writing Desk & Blueprints', included: false),
        _PlanFeature('Story-Coach & AI tools', included: false),
      ],
      isCurrent: isCurrent,
      buttonLabel: isCurrent ? 'Current Plan' : 'Get Started',
      isPrimary: false,
      isLoading: false,
      onPressed: null,
    );
  }

  Widget _readingCard(int currentRank) {
    const rank = 1;
    final isCurrent = currentRank == rank;
    final included = currentRank > rank; // already get it via a higher plan
    final canUpgrade = currentRank >= 0 && currentRank < rank;
    return _PlanCard(
      tierName: 'Reading Nook',
      title: 'Read. Refine.',
      price: _isAnnual ? '\$152/yr' : '\$14.99/mo',
      priceSubtitle:
          _isAnnual ? '\$12.67/mo billed annually' : 'Billed monthly',
      savingsLabel: _isAnnual ? 'Save 15%' : null,
      features: const [
        _PlanFeature.header('Listening & revision'),
        _PlanFeature('Premium natural voices'),
        _PlanFeature('Word & sentence highlighting'),
        _PlanFeature('Playback speed up to 4×'),
        _PlanFeature.header('Documents'),
        _PlanFeature('Edit & download branded DOCX'),
        _PlanFeature('50 documents per month'),
        _PlanFeature('Archive documents'),
        _PlanFeature('150k premium-voice characters / month'),
        _PlanFeature('Priority support'),
        _PlanFeature('Writing platform & AI tools', included: false),
      ],
      isCurrent: isCurrent,
      buttonLabel: isCurrent
          ? 'Current Plan'
          : included
              ? 'Included'
              : 'Choose Reading',
      isPrimary: false,
      isLoading: _isSubmitting && _checkoutBase == 'reading_nook_pro',
      onPressed: (canUpgrade && !_isSubmitting)
          ? () => _startCheckout('reading_nook_pro')
          : null,
    );
  }

  Widget _writingCard(int currentRank) {
    const rank = 2;
    final isCurrent = currentRank == rank;
    final included = currentRank > rank;
    final canUpgrade = currentRank >= 0 && currentRank < rank;
    return _PlanCard(
      tierName: 'Writing Nook',
      title: 'Write. Structure. Finish.',
      price: _isAnnual ? '\$183/yr' : '\$17.99/mo',
      priceSubtitle:
          _isAnnual ? '\$15.25/mo billed annually' : 'Billed monthly',
      savingsLabel: _isAnnual ? 'Save 15%' : null,
      popular: true,
      features: const [
        _PlanFeature.header('Everything in Reading Nook, plus'),
        _PlanFeature.header('Writing workspace'),
        _PlanFeature('Full Writing Desk'),
        _PlanFeature('Unlimited projects'),
        _PlanFeature.header('Book development'),
        _PlanFeature('Blueprints & 25+ Narrative Structures'),
        _PlanFeature('Scene Mapping & Progress Tracking'),
        _PlanFeature.header('AI writing intelligence'),
        _PlanFeature('Story-Coach — live drift nudges'),
        _PlanFeature('Structure Analyzer'),
        _PlanFeature('1M AI tokens / month'),
        _PlanFeature('250k premium-voice characters / month'),
        _PlanFeature('Writing analytics'),
      ],
      isCurrent: isCurrent,
      buttonLabel: isCurrent
          ? 'Current Plan'
          : included
              ? 'Included'
              : 'Upgrade — finish your book',
      isPrimary: true,
      isLoading: _isSubmitting && _checkoutBase == 'writing_nook_pro',
      onPressed: (canUpgrade && !_isSubmitting)
          ? () => _startCheckout('writing_nook_pro')
          : null,
    );
  }

  Widget _creativeCard() {
    return _PlanCard(
      tierName: 'Creative Nook',
      title: 'Create. Refine. Research.',
      price: _isAnnual ? '\$305/yr' : '\$29.99/mo',
      priceSubtitle: _isAnnual ? '\$25.42/mo billed annually' : 'Launching soon',
      comingSoon: true,
      features: const [
        _PlanFeature.header('Everything in Writing Nook, plus a Creative Studio'),
        _PlanFeature('Inspiration, Character & Research boards',
            comingSoon: true),
        _PlanFeature('Story, World & Mood boards', comingSoon: true),
        _PlanFeature('AI brainstorming & story expansion', comingSoon: true),
        _PlanFeature('Clone your own voice', comingSoon: true),
        _PlanFeature('Creative asset management', comingSoon: true),
        _PlanFeature('400k premium-voice characters / month', comingSoon: true),
        _PlanFeature('2M AI tokens / month', comingSoon: true),
      ],
      isCurrent: false,
      buttonLabel:
          _isOnWaitlist ? 'On the waitlist ✓' : 'Notify me when it launches',
      isPrimary: false,
      isLoading: _isWaitlistSubmitting,
      onPressed: (_isOnWaitlist || _isWaitlistSubmitting) ? null : _joinWaitlist,
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
            trailingBadge: 'Save 15%',
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
                      ? cs.onPrimary.withValues(alpha: 0.2)
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
    this.popular = false,
    this.onPressed,
  });

  final String tierName;
  final String title;
  final String price;
  final String priceSubtitle;
  final List<_PlanFeature> features;
  final String buttonLabel;
  final bool isPrimary;
  final bool isLoading;
  final bool isCurrent;
  final String? savingsLabel;
  final bool comingSoon;
  final bool popular;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final highlight = isCurrent || popular;

    return Card(
      elevation: highlight ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: highlight
            ? BorderSide(color: cs.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tierName,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (popular && !isCurrent)
                  _Pill(
                    label: 'Most Popular',
                    background: cs.primary,
                    foreground: cs.onPrimary,
                  ),
              ],
            ),
            const SizedBox(height: 4),
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
            if (price.isNotEmpty || priceSubtitle.isNotEmpty) ...[
              const SizedBox(height: 16),
              if (price.isNotEmpty)
                Text(
                  price,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: comingSoon
                        ? cs.onSurfaceVariant
                        : (isPrimary ? cs.primary : null),
                  ),
                ),
              if (price.isNotEmpty && priceSubtitle.isNotEmpty)
                const SizedBox(height: 4),
              if (priceSubtitle.isNotEmpty)
                Text(
                  priceSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
            const SizedBox(height: 20),
            ...features.map((f) => _FeatureRow(feature: f)),
            const SizedBox(height: 20),
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
    // Current plan: a solid, clearly-visible accent button (disabled but
    // styled with the primary color + a check) so it stands out instead of
    // fading into a muted disabled state.
    if (isCurrent) {
      return FilledButton.icon(
        onPressed: null,
        style: FilledButton.styleFrom(
          disabledBackgroundColor: cs.primary,
          disabledForegroundColor: cs.onPrimary,
        ),
        icon: const Icon(Icons.check_circle, size: 18),
        label: Text(buttonLabel),
      );
    }
    // Other non-actionable states (Free, "Included", waitlist done) keep the
    // muted tonal style.
    if (onPressed == null) {
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

/// A single feature entry in a plan card. Presentation modes:
///   - header (`isHeader: true`) — small muted section label, no icon
///   - default (`included: true`) — green check + normal text
///   - excluded (`included: false`) — gray dash + muted text
///   - coming soon (`comingSoon: true`) — clock icon + italic muted text
/// Precedence: header > comingSoon > included.
class _PlanFeature {
  const _PlanFeature(
    this.label, {
    this.included = true,
    this.comingSoon = false,
  }) : isHeader = false;

  const _PlanFeature.header(this.label)
      : included = true,
        comingSoon = false,
        isHeader = true;

  final String label;
  final bool included;
  final bool comingSoon;
  final bool isHeader;
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature});

  final _PlanFeature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (feature.isHeader) {
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Text(
          feature.label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      );
    }

    final IconData icon;
    final Color iconColor;
    final Color? textColor;
    final FontStyle fontStyle;

    if (feature.comingSoon) {
      icon = Icons.schedule;
      iconColor = cs.onSurfaceVariant.withValues(alpha: 0.75);
      textColor = cs.onSurfaceVariant;
      fontStyle = FontStyle.italic;
    } else if (feature.included) {
      icon = Icons.check_circle_outline;
      iconColor = Colors.green.shade600;
      textColor = theme.textTheme.bodyMedium?.color;
      fontStyle = FontStyle.normal;
    } else {
      icon = Icons.remove_circle_outline;
      iconColor = cs.onSurface.withValues(alpha: 0.28);
      textColor = cs.onSurfaceVariant.withValues(alpha: 0.7);
      fontStyle = FontStyle.normal;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
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
