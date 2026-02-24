import 'package:flutter/material.dart';

/// App themes (named templates).
///
/// These are intentionally "token-light" so they can port to mobile later.
/// Each theme uses a seed + a few key surfaces to shape the feel.
abstract final class AppTheme {
  static ThemeData forName(String themeName) {
    switch (themeName) {
      case 'Creator Studio Dark':
        return creatorStudioDark;
      case 'Paper Light':
        return paperLight;
      case 'Rose Salmon Pastel':
        return roseSalmonPastel;
      case 'Beige Gold Navy':
        return beigeGoldNavy;
      default:
        return creatorStudioDark;
    }
  }

  static ThemeData get creatorStudioDark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF2F6BFF), // dark blue energy
        scaffoldBackgroundColor: const Color(0xFF0B1220),
        cardColor: const Color(0xFF111B2E),
        visualDensity: VisualDensity.comfortable,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          toolbarHeight: 48,
          backgroundColor: Color(0xFF0B1220),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF22304A),
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

  static ThemeData get paperLight => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF1D4ED8), // calm blue
        scaffoldBackgroundColor: const Color(0xFFF7F5EF), // paper
        cardColor: const Color(0xFFFFFFFF),
        visualDensity: VisualDensity.comfortable,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          toolbarHeight: 48,
          backgroundColor: Color(0xFFF7F5EF),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE7E1D6),
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

  static ThemeData get roseSalmonPastel => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFFE06B6B), // salmon/rose
        scaffoldBackgroundColor: const Color(0xFFFFF7F5),
        cardColor: const Color(0xFFFFFFFF),
        visualDensity: VisualDensity.comfortable,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          toolbarHeight: 48,
          backgroundColor: Color(0xFFFFF7F5),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFF1D6D2),
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

  static ThemeData get beigeGoldNavy => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF0B2A4A), // navy
        scaffoldBackgroundColor: const Color(0xFFF4EFE5), // beige
        cardColor: const Color(0xFFFFFFFF),
        visualDensity: VisualDensity.comfortable,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          toolbarHeight: 48,
          backgroundColor: Color(0xFFF4EFE5),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE2D7C5),
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
