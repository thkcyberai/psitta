import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
