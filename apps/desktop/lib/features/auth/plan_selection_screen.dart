import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/providers/providers.dart';
import '../../data/services/auth_service.dart';
import '../../l10n/app_localizations.dart';

/// Plan selection screen — accessible from the sidebar "Plans" entry and
/// Settings > Change Plan.
///
/// Shows three tiers (Free, Writing Nook, Creative Nook). Writing Nook is the
/// only purchasable product — every new subscription starts with a 14-day
/// Stripe-native free trial. The monthly/annual toggle drives the Stripe
/// lookup_key sent to /billing/checkout-session. On success the checkout URL
/// opens in the system browser (Stripe-hosted) and the screen polls
/// /billing/status until the webhook activates the plan (status 'active' OR
/// 'trialing' — both are entitled).
///
/// Creative Nook is a Coming Soon marketing placeholder: waitlist only, no
/// checkout, no billing. Tier ranks gate the CTAs.
class PlanSelectionScreen extends ConsumerStatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  ConsumerState<PlanSelectionScreen> createState() =>
      _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends ConsumerState<PlanSelectionScreen> {
  bool _isAnnual = false;
  bool _isSubmitting = false;

  /// Which paid tier's checkout is in flight ('writing_nook_pro' — the only
  /// purchasable tier), so only that card shows a spinner.
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
  /// 'reading_nook_pro' is retained for backward compatibility only (a
  /// grandfathered historical plan id — the backend normally reports it as
  /// writing_nook_pro); it has no card of its own.
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
        _showSnack(AppLocalizations.of(context).planNoCheckoutUrl);
        return;
      }
      final launched = await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showSnack(AppLocalizations.of(context).planCouldNotOpenBrowser);
        return;
      }
      _showSnack(
        AppLocalizations.of(context).planCompletePayment,
        durationSeconds: 6,
      );
      _beginStatusPolling();
    } on DioException catch (e) {
      _handleCheckoutError(e);
    } catch (e) {
      _showSnack(AppLocalizations.of(context).planConnectionError);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _handleCheckoutError(DioException e) {
    final status = e.response?.statusCode;
    switch (status) {
      case 400:
        _showSnack(AppLocalizations.of(context).planNotAvailableYet);
      case 409:
        _showSnack(AppLocalizations.of(context).planAlreadySubscribed);
      case 502:
        _showSnack(AppLocalizations.of(context).planServiceUnavailable);
      default:
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          _showSnack(AppLocalizations.of(context).planConnectionError);
        } else {
          _showSnack(AppLocalizations.of(context).planServiceError);
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
        _showSnack(AppLocalizations.of(context).planCouldNotReadEmail);
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
          AppLocalizations.of(context).planWaitlistJoined,
          durationSeconds: 5,
        );
      } else {
        _showSnack(AppLocalizations.of(context).planCouldNotSaveSpot);
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        _showSnack(AppLocalizations.of(context).planConnectionError);
      } else {
        _showSnack(AppLocalizations.of(context).planCouldNotSaveSpot);
      }
    } catch (_) {
      _showSnack(AppLocalizations.of(context).planCouldNotSaveSpot);
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
        // A4 trialing contract: a 14-day-trial subscription reports
        // status 'trialing' — it is fully entitled, exactly like 'active'.
        if ((plan == 'writing_nook_pro' || plan == 'creative_nook_pro') &&
            (status == 'active' || status == 'trialing')) {
          timer.cancel();
          ref.invalidate(billingStatusProvider);
          _showSnack(AppLocalizations.of(context).planActiveWelcome);
          return;
        }
      } catch (_) {
        // Transient poll failures are ignored — next tick retries.
      }
      if (_pollAttempts >= _maxPollAttempts) {
        timer.cancel();
        _showSnack(
          AppLocalizations.of(context).planPaymentProcessing,
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
    final loc = AppLocalizations.of(context);
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
                    tooltip: loc.planBackToSettings,
                    onPressed: () => context.go('/settings'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    loc.navPlans,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                loc.planSubtitle,
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
                          loc.planStatusError,
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
                        child: Text(loc.actionRetry),
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
                      loc.planLoading,
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
                constraints: const BoxConstraints(maxWidth: 1020),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _freeCard(currentRank)),
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
    final loc = AppLocalizations.of(context);
    final isCurrent = currentRank == 0;
    return _PlanCard(
      tierName: 'Free',
      title: loc.planTaglineRead,
      price: '\$0',
      priceSubtitle: '',
      features: [
        _PlanFeature(loc.featListen),
        _PlanFeature(loc.featBasicVoices),
        _PlanFeature(loc.feat10Docs),
        _PlanFeature(loc.featPremiumVoices, included: false),
        _PlanFeature(loc.featWordByWord, included: false),
        _PlanFeature(loc.featDeskBlueprints, included: false),
        _PlanFeature(loc.featStoryCoachTools, included: false),
      ],
      isCurrent: isCurrent,
      buttonLabel: isCurrent ? loc.planCurrent : loc.planGetStarted,
      isPrimary: false,
      isLoading: false,
      onPressed: null,
    );
  }

  Widget _writingCard(int currentRank) {
    const rank = 2;
    final isCurrent = currentRank == rank;
    final included = currentRank > rank;
    final canUpgrade = currentRank >= 0 && currentRank < rank;
    final loc = AppLocalizations.of(context);
    return _PlanCard(
      tierName: 'Writing Nook',
      title: loc.planTaglineWrite,
      price: _isAnnual ? '\$183${loc.perYear}' : '\$17.99${loc.perMonth}',
      priceSubtitle: _isAnnual
          ? '${loc.planTrial14} · ${loc.billedAnnuallyAt('\$15.25${loc.perMonth}')}'
          : '${loc.planTrial14} · ${loc.billedMonthly}',
      savingsLabel: _isAnnual ? loc.billingSave15 : null,
      popular: true,
      features: [
        _PlanFeature.header(loc.featHdrWorkspace),
        _PlanFeature(loc.featFullDesk),
        _PlanFeature(loc.featUnlimitedProjects),
        _PlanFeature.header(loc.featHdrBookDev),
        _PlanFeature(loc.featBlueprints25),
        _PlanFeature(loc.featSceneProgress),
        _PlanFeature.header(loc.featHdrAiIntel),
        _PlanFeature(loc.featStoryCoachDrift),
        _PlanFeature(loc.featureStructureAnalyzer),
        _PlanFeature(loc.feat1MTokens),
        _PlanFeature.header(loc.featHdrListening),
        _PlanFeature(loc.featPremiumNatural),
        _PlanFeature(loc.featWordSentence),
        _PlanFeature(loc.featPlayback4x),
        _PlanFeature(loc.featBrandedDocx),
        _PlanFeature(loc.feat250k),
        _PlanFeature(loc.featWritingAnalytics),
        _PlanFeature(loc.featPriority),
      ],
      isCurrent: isCurrent,
      buttonLabel: isCurrent
          ? loc.planCurrent
          : included
              ? loc.planIncluded
              : loc.planUpgradeFinish,
      isPrimary: true,
      isLoading: _isSubmitting && _checkoutBase == 'writing_nook_pro',
      onPressed: (canUpgrade && !_isSubmitting)
          ? () => _startCheckout('writing_nook_pro')
          : null,
    );
  }

  Widget _creativeCard() {
    final loc = AppLocalizations.of(context);
    return _PlanCard(
      tierName: 'Creative Nook',
      title: loc.planTaglineCreate,
      price: _isAnnual ? '\$305${loc.perYear}' : '\$29.99${loc.perMonth}',
      priceSubtitle: _isAnnual
          ? loc.billedAnnuallyAt('\$25.42${loc.perMonth}')
          : loc.launchingSoon,
      comingSoon: true,
      features: [
        _PlanFeature.header(loc.featHdrEverythingWriting),
        _PlanFeature(loc.featInspoBoards, comingSoon: true),
        _PlanFeature(loc.featStoryWorldMood, comingSoon: true),
        _PlanFeature(loc.featAiBrainstorm, comingSoon: true),
        _PlanFeature(loc.featCloneVoice, comingSoon: true),
        _PlanFeature(loc.featCreativeAssets, comingSoon: true),
        _PlanFeature(loc.feat400k, comingSoon: true),
        _PlanFeature(loc.feat2MTokens, comingSoon: true),
      ],
      isCurrent: false,
      buttonLabel:
          _isOnWaitlist ? loc.planOnWaitlist : loc.planNotifyLaunch,
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
    final loc = AppLocalizations.of(context);

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
            label: loc.billingMonthly,
            selected: !isAnnual,
            onTap: onChanged == null ? null : () => onChanged!(false),
          ),
          _ToggleOption(
            label: loc.billingAnnual,
            trailingBadge: loc.billingSave15,
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
    final loc = AppLocalizations.of(context);
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
                    label: loc.planMostPopular,
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
                    label: loc.planCurrent,
                    background: cs.primary,
                    foreground: cs.onPrimary,
                  )
                else if (comingSoon)
                  _Pill(
                    label: loc.planComingSoon,
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
