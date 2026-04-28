import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/plan_gate.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/services/preferences_service.dart';

/// Root application widget.
///
/// Configures GoRouter for shell-based desktop navigation,
/// and applies the selected Theme (template).
class PsittaApp extends ConsumerWidget {
  const PsittaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeName = ref.watch(selectedThemeNameProvider);
    final theme = AppTheme.forName(themeName);

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
