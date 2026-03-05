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

  // ─────────────────────────────────────────────────────────────
  // Skin 1: Creator Studio Dark (matches CreatorStudioDark.png)
  // ─────────────────────────────────────────────────────────────
  static ThemeData get creatorStudioDark {
    const seed = Color(0xFF5B7CFF); // blue
    const accent = Color(0xFF9B6BFF); // purple
    const bg = Color(0xFF070A14);
    const surface = Color(0xFF0C1224);
    const surface2 = Color(0xFF101A33);
    const border = Color(0x262F6BFF); // subtle blue border

    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      primary: seed,
      secondary: accent,
      surface: surface,
      surfaceContainerHighest: surface2,
      outline: border,
      outlineVariant: border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      cardColor: surface2,
      visualDensity: VisualDensity.comfortable,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Other skins (unchanged behavior)
  // ─────────────────────────────────────────────────────────────
  static ThemeData get paperLight => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF1D4ED8),
        scaffoldBackgroundColor: const Color(0xFFF7F5EF),
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
        colorSchemeSeed: const Color(0xFFE38B77),
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

  static ThemeData get beigeGoldNavy {
    const gold = Color(0xFFB88A4B);
    const navy = Color(0xFF333D50);

    final scheme = ColorScheme.fromSeed(
      seedColor: gold,
      brightness: Brightness.light,
    ).copyWith(
      primary: gold,
      secondary: navy,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF4EFE5),
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
}
