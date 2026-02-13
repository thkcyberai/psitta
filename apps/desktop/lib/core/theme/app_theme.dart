import 'package:flutter/material.dart';
import 'colors.dart';

/// Psitta theming — desktop-optimized Material 3.
///
/// Uses [VisualDensity.comfortable] for mouse/keyboard interaction
/// (tighter than mobile touch targets, but not cramped).
abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.primary,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.surface,
        visualDensity: VisualDensity.comfortable,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          toolbarHeight: 48,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.panelBorder,
          thickness: 1,
          space: 1,
        ),
        listTileTheme: const ListTileThemeData(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbVisibility: WidgetStateProperty.all(true),
          thickness: WidgetStateProperty.all(6),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.primary,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.surfaceDark,
        visualDensity: VisualDensity.comfortable,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          toolbarHeight: 48,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.panelBorderDark,
          thickness: 1,
          space: 1,
        ),
        listTileTheme: const ListTileThemeData(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbVisibility: WidgetStateProperty.all(true),
          thickness: WidgetStateProperty.all(6),
        ),
      );
}
