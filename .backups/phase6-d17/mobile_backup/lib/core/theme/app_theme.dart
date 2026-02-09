import 'package:flutter/material.dart';
import 'colors.dart';

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true, colorSchemeSeed: AppColors.primary,
    brightness: Brightness.light, scaffoldBackgroundColor: AppColors.surface,
    appBarTheme: const AppBarTheme(elevation: 0, centerTitle: false));

  static ThemeData get dark => ThemeData(
    useMaterial3: true, colorSchemeSeed: AppColors.primary,
    brightness: Brightness.dark, scaffoldBackgroundColor: AppColors.surfaceDark,
    appBarTheme: const AppBarTheme(elevation: 0, centerTitle: false));
}
