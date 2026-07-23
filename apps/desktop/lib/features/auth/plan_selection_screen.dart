import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/capabilities.dart';
import '../../core/quota_gate.dart' show formatResetDate;
import '../../data/providers/providers.dart';
import '../../data/services/auth_service.dart';
import '../../l10n/app_localizations.dart';

/// Plan selection screen — accessible from the sidebar "Plans" entry and
/// Settings > Change Plan.
///
/// PAC-3 platform alignment: ONE product — Writing Nook — presented in
/// states. Card 1 is Writing Nook / Explore (what a writer can already do,
/// then the locked capabilities waiting, then technical limits). Card 2 is
/// the full Writing Nook: trial CTA in Explore state; a "Trial active —
/// N days remaining" banner + Manage subscription while trialing; an
/// "Active subscription" banner + Manage subscription for subscribers.
/// Every new subscription starts with a 14-day Stripe-native free trial.
/// The monthly/annual toggle drives the Stripe lookup_key sent to
/// /billing/checkout-session. On success the checkout URL opens in the
/// system browser (Stripe-hosted) and the screen polls /billing/status
/// until the webhook activates the plan (status 'active' OR 'trialing' —
/// both are entitled).
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
          ref.invalidate(capabilitiesProvider);
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

  // ── Stripe Customer Portal (PAC-3) ────────────────────────────────────
  // Ported verbatim from Settings' _ManageSubscriptionTile (same endpoint,
  // same error mapping, same invalidate-on-return) so Trial/Subscriber
  // states get a live "Manage subscription" action instead of a dead
  // "Current Plan" button. No new backend endpoint.
  bool _isLaunchingPortal = false;

  Future<void> _openPortal() async {
    setState(() => _isLaunchingPortal = true);
    final api = ref.read(apiClientProvider);
    // use_build_context_synchronously: capture the localization bundle
    // BEFORE any await — the only context read this method needs. All
    // post-await UI goes through _showSnack, which itself guards on
    // `mounted`.
    final loc = AppLocalizations.of(context);
    try {
      final response = await api.dio.post('/billing/portal-session');
      final data = response.data as Map<String, dynamic>;
      final url = data['url'] as String?;
      if (url == null) {
        _showSnack(loc.manageNoUrl);
        return;
      }
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showSnack(loc.planCouldNotOpenBrowser);
        return;
      }
      ref.invalidate(billingStatusProvider);
      ref.invalidate(capabilitiesProvider);
      _showSnack(
        loc.manageBrowserMsg,
        durationSeconds: 5,
      );
    } on DioException catch (e) {
      _handlePortalError(e);
    } catch (_) {
      _showSnack(loc.planConnectionError);
    } finally {
      if (mounted) setState(() => _isLaunchingPortal = false);
    }
  }

  void _handlePortalError(DioException e) {
    final status = e.response?.statusCode;
    switch (status) {
      case 404:
        _showSnack(AppLocalizations.of(context).manageNoSubscription);
      case 502:
        _showSnack(AppLocalizations.of(context).managePortalUnavailable);
      default:
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          _showSnack(AppLocalizations.of(context).planConnectionError);
        } else {
          _showSnack(AppLocalizations.of(context).managePortalError);
        }
    }
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
    final billingData = statusAsync.whenOrNull(data: (data) => data);
    final currentPlan = (billingData?['plan'] as String?) ?? 'free';
    // -1 while loading/error so no card is marked current and the CTAs stay in
    // their default state (mirrors the prior false-on-loading guard).
    final currentRank = statusReady ? (_rank[currentPlan] ?? 0) : -1;

    // ── PAC-3 user-state derivation (A4 contract: /billing/status reports
    // the real Stripe status; trialing is fully entitled). Everything below
    // is display state — enforcement stays server-side.
    final subStatus = (billingData?['status'] as String?) ?? 'none';
    final isTrialing =
        statusReady && currentPlan != 'free' && subStatus == 'trialing';
    final isActiveSub =
        statusReady && currentPlan != 'free' && subStatus == 'active';
    // Manage-subscription requires a real Stripe record (KL 2026-05-22b:
    // allowlist/override users have none — the portal call would 502).
    final isStripeSource = (billingData?['source'] as String?) == 'stripe';
    DateTime? periodEnd;
    final periodEndRaw = billingData?['current_period_end'] as String?;
    if (periodEndRaw != null && periodEndRaw.isNotEmpty) {
      periodEnd = DateTime.tryParse(periodEndRaw);
    }
    // Ceil to whole days, floored at 0 — "1 day remaining" until the hour
    // it actually ends.
    final int trialDaysRemaining = periodEnd == null
        ? 0
        : (periodEnd.difference(DateTime.now()).inHours / 24).ceil().clamp(0, 999);

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
                        onPressed: () {
                          ref.invalidate(billingStatusProvider);
                          ref.invalidate(capabilitiesProvider);
                        },
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
                    Expanded(child: _exploreCard(currentRank)),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _writingCard(
                        currentRank,
                        isTrialing: isTrialing,
                        isActiveSub: isActiveSub,
                        isStripeSource: isStripeSource,
                        trialDaysRemaining: trialDaysRemaining,
                        periodEnd: periodEnd,
                      ),
                    ),
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

  /// PAC-3: Writing Nook / Explore — the same product, in its free state.
  /// Outcomes first, then the capabilities waiting to unlock, then the
  /// technical limits (never leading with limitations).
  Widget _exploreCard(int currentRank) {
    final loc = AppLocalizations.of(context);
    final isCurrent = currentRank == 0;
    return _PlanCard(
      tierName: 'Writing Nook',
      title: loc.planTitleExplore,
      price: '\$0',
      priceSubtitle: loc.planFreeForever,
      features: [
        _PlanFeature(loc.planExploreCreateProjects),
        _PlanFeature(loc.planExploreOrganize),
        _PlanFeature(loc.planExploreListen),
        _PlanFeature.header(loc.planWaitingForYou),
        _PlanFeature.locked(loc.lockBlueprints),
        _PlanFeature.locked(loc.lockStoryCoach),
        _PlanFeature.locked(loc.featureStructureAnalyzer),
        _PlanFeature.locked(loc.featHdrAiIntel),
        _PlanFeature.locked(loc.featPremiumVoices),
        _PlanFeature.locked(loc.featWordSentence),
        _PlanFeature.header(loc.planTechnicalLimits),
        _PlanFeature(loc.feat10Docs, included: false),
        _PlanFeature(loc.featBasicVoices, included: false),
      ],
      isCurrent: isCurrent,
      buttonLabel:
          isCurrent ? loc.planCurrentExperience : loc.planIncluded,
      isPrimary: false,
      isLoading: false,
      onPressed: null,
    );
  }

  Widget _writingCard(
    int currentRank, {
    required bool isTrialing,
    required bool isActiveSub,
    required bool isStripeSource,
    required int trialDaysRemaining,
    required DateTime? periodEnd,
  }) {
    const rank = 2;
    final isCurrent = currentRank == rank;
    final included = currentRank > rank;
    final canUpgrade = currentRank >= 0 && currentRank < rank;
    final loc = AppLocalizations.of(context);
    final entitled = isTrialing || isActiveSub;

    // PAC-3 state banner: Trial → days remaining + end date; Subscriber →
    // active confirmation. Same card in every state — only this banner and
    // the button change.
    Widget? statusBanner;
    if (isTrialing) {
      // Null/unparseable current_period_end → plain "Trial active" (no
      // misleading "0 days remaining"); expired-but-still-trialing edge
      // clamps at 0 via trialDaysRemaining.
      statusBanner = _StateBanner(
        icon: Icons.timelapse,
        text: periodEnd == null
            ? loc.planTrialActive
            : '${loc.planTrialActive} — '
                '${loc.planDaysRemaining('$trialDaysRemaining')}'
                ' · ${loc.planEndsOn(formatResetDate(periodEnd))}',
      );
    } else if (isActiveSub && isCurrent) {
      statusBanner = _StateBanner(
        icon: Icons.check_circle_outline,
        text: loc.planActiveSubscription,
      );
    }

    // Button logic per state:
    //   Explore  → Start your 14-day free trial (existing checkout flow)
    //   Trial /
    //   Active   → Manage subscription (existing Stripe portal flow) when a
    //              real Stripe record exists; otherwise the current-plan
    //              affordance (allowlist/override users have no portal).
    //   Included (creative, future) → muted "Included".
    final String buttonLabel;
    VoidCallback? onPressed;
    if (entitled && isCurrent && isStripeSource) {
      buttonLabel = loc.manageTitle;
      onPressed = _isLaunchingPortal ? null : _openPortal;
    } else if (isCurrent) {
      buttonLabel = loc.planCurrent;
      onPressed = null;
    } else if (included) {
      buttonLabel = loc.planIncluded;
      onPressed = null;
    } else {
      buttonLabel = loc.planStartTrial;
      onPressed = (canUpgrade && !_isSubmitting)
          ? () => _startCheckout('writing_nook_pro')
          : null;
    }

    return _PlanCard(
      tierName: 'Writing Nook',
      title: loc.planTaglineWrite,
      price: _isAnnual ? '\$183${loc.perYear}' : '\$17.99${loc.perMonth}',
      priceSubtitle: _isAnnual
          ? '${loc.planTrial14} · ${loc.billedAnnuallyAt('\$15.25${loc.perMonth}')}'
          : '${loc.planTrial14} · ${loc.billedMonthly}',
      savingsLabel: _isAnnual ? loc.billingSave15 : null,
      popular: true,
      statusBanner: statusBanner,
      // Six capability groups — the approved platform vocabulary, mirroring
      // the website Pricing page (WA-4).
      features: [
        _PlanFeature.header(loc.featHdrWorkspace),
        _PlanFeature(loc.featFullDesk),
        _PlanFeature.header(loc.featHdrBookDev),
        _PlanFeature(loc.featBlueprints25),
        _PlanFeature(loc.featSceneProgress),
        _PlanFeature.header(loc.featHdrAiIntel),
        _PlanFeature(loc.featStoryCoachDrift),
        _PlanFeature(loc.featureStructureAnalyzer),
        _PlanFeature(loc.feat1MTokens),
        _PlanFeature(loc.featWritingAnalytics),
        _PlanFeature(loc.featPriority),
        _PlanFeature.header(loc.featHdrListening),
        _PlanFeature(loc.featPremiumNatural),
        _PlanFeature(loc.featWordSentence),
        _PlanFeature(loc.featPlayback4x),
        _PlanFeature(loc.featBrandedDocx),
        _PlanFeature(loc.feat250k),
        _PlanFeature.header(loc.featHdrProjectOrg),
        _PlanFeature(loc.featUnlimitedProjects),
        _PlanFeature.header(loc.featHdrNativeDesktop),
        _PlanFeature(loc.featNativeApp),
      ],
      isCurrent: isCurrent,
      buttonLabel: buttonLabel,
      isPrimary: true,
      isLoading: (_isSubmitting && _checkoutBase == 'writing_nook_pro') ||
          _isLaunchingPortal,
      onPressed: onPressed,
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
    this.statusBanner,
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

  /// PAC-3: optional user-state banner (Trial active / Active subscription)
  /// rendered between the price block and the feature list.
  final Widget? statusBanner;
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
            if (statusBanner != null) ...[
              const SizedBox(height: 14),
              statusBanner!,
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
    // PAC-3: an ACTIONABLE current card (Trial/Subscriber → Manage
    // subscription via the Stripe portal) renders a live outlined button —
    // never a dead "Current Plan".
    if (isCurrent && onPressed != null) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              )
            : const Icon(Icons.open_in_new, size: 16),
        label: Text(buttonLabel),
      );
    }
    // Current plan with no action: a solid, clearly-visible accent button
    // (disabled but styled with the primary color + a check) so it stands
    // out instead of fading into a muted disabled state.
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
  })  : isHeader = false,
        isLocked = false;

  const _PlanFeature.header(this.label)
      : included = true,
        comingSoon = false,
        isHeader = true,
        isLocked = false;

  /// PAC-3: a capability that exists and is waiting to unlock — rendered
  /// with a lock icon (anticipation), distinct from `included: false`
  /// (a plain factual limit, rendered with a dash).
  const _PlanFeature.locked(this.label)
      : included = false,
        comingSoon = false,
        isHeader = false,
        isLocked = true;

  final String label;
  final bool included;
  final bool comingSoon;
  final bool isHeader;
  final bool isLocked;
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

    if (feature.isLocked) {
      icon = Icons.lock_outline;
      iconColor = cs.onSurfaceVariant.withValues(alpha: 0.75);
      textColor = cs.onSurfaceVariant;
      fontStyle = FontStyle.normal;
    } else if (feature.comingSoon) {
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

/// PAC-3: compact state banner (Trial active / Active subscription) shown
/// inside the Writing Nook card — primary-container tone, icon + one line.
class _StateBanner extends StatelessWidget {
  const _StateBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onPrimaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w600,
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
