import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/plan_gate.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/providers/providers.dart';
import 'data/services/preferences_service.dart';
import 'l10n/app_localizations.dart';

/// Throttle window for resume-driven billing invalidation. Prevents
/// /billing/status from being hammered when the user rapidly toggles
/// focus between Psitta and another window (taskbar hover, debugger
/// pause, double-click activation, etc.).
const Duration _resumeInvalidateThrottle = Duration(seconds: 5);

/// Root application widget.
///
/// Owns three responsibilities at the app lifetime:
///   * Configures GoRouter for shell-based desktop navigation and
///     applies the selected Theme.
///   * Listens for plan-downgrade transitions and clamps user
///     preferences (speed, SWH) back to Free ceilings — the
///     `ref.listen<PlanStatus>` block in [build].
///   * Listens for [AppLifecycleState.resumed] and invalidates the
///     billing/quota providers so subscription state refreshes
///     automatically when the user returns from an external browser
///     side-trip (Stripe Checkout, Stripe Customer Portal). Without
///     this, the screen-scoped 30-second poll on
///     [PlanSelectionScreen] is the only catcher and it dies as soon
///     as the user navigates away from /plan.
class PsittaApp extends ConsumerStatefulWidget {
  const PsittaApp({super.key});

  @override
  ConsumerState<PsittaApp> createState() => _PsittaAppState();
}

class _PsittaAppState extends ConsumerState<PsittaApp>
    with WidgetsBindingObserver {
  /// Wall-clock of the last resume that actually fired an invalidation.
  /// Initialised to the epoch so the first resume after launch always
  /// passes the throttle check.
  DateTime _lastResumeInvalidation =
      DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Fires on every Flutter lifecycle transition. The 2026-05-01
  /// Windows spike confirmed [AppLifecycleState.resumed] lands
  /// reliably on alt-tab return, which is precisely the moment a
  /// Stripe checkout or Customer Portal session completes in the
  /// system browser and the user comes back to Psitta.
  ///
  /// Invalidating [billingStatusProvider] and [quotaUsageProvider]
  /// causes the next consumer `ref.watch` to fetch fresh
  /// `/billing/status` and `/users/me/subscription` responses, so
  /// the UI flips off stale Free state within ~1s of return. The
  /// 30-second poll on [PlanSelectionScreen] remains as a redundant
  /// safety net for users who stay on /plan.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final now = DateTime.now();
    if (now.difference(_lastResumeInvalidation) <
        _resumeInvalidateThrottle) {
      return;
    }
    _lastResumeInvalidation = now;
    debugPrint(
      '[BILLING] billing_state.invalidate_on_resume '
      'at ${now.toIso8601String()}',
    );
    ref.invalidate(billingStatusProvider);
    ref.invalidate(quotaUsageProvider);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeName = ref.watch(selectedThemeNameProvider);
    final theme = AppTheme.forName(themeName);
    final locale = ref.watch(selectedLocaleProvider);

    // Downgrade guard: when the resolved plan is Free, enforce the Free
    // caps on any preferences the user may have set while on Pro. Runs
    // whenever the billing status transitions (login, refresh, webhook).
    //
    // The early-return predicate is `!next.isFree` (not `next.isPro`):
    // we must only act on a CONFIRMED Free resolution. After
    // _invalidateUserScopedFetches() fires on login (auth_service.dart),
    // planStatusProvider briefly resolves to PlanStatus.unavailable
    // (loading state). The old `if (next.isPro) return` predicate let
    // unavailable through -- which would then silently clamp a Pro
    // user's saved speed/SWH back to the Free ceiling on every
    // login/logout boundary. PlanStatus.isFree is true ONLY for the
    // data(plan='free') case, so it correctly excludes both Pro AND
    // unavailable.
    ref.listen<PlanStatus>(planStatusProvider, (prev, next) {
      if (!next.isFree) return;
      final currentSpeed = ref.read(selectedSpeedProvider);
      if (currentSpeed > kFreeMaxSpeed) {
        ref
            .read(selectedSpeedProvider.notifier)
            .clampToCeiling(kFreeMaxSpeed);
      }
      final currentSwh = ref.read(selectedSwhModeProvider);
      if (currentSwh == SwhMode.always) {
        ref.read(selectedSwhModeProvider.notifier).select(SwhMode.never);
      }
    });

    return MaterialApp.router(
      title: 'Psitta',
      theme: theme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      // flutter_quill 11.x hard-requires its localization delegate to be
      // registered; without it every QuillEditor/QuillSimpleToolbar throws
      // UnimplementedError. MaterialApp still appends its own Material/Widgets
      // default delegates, so this only adds Quill's.
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
