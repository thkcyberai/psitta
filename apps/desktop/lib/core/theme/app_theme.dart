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
    const divider = Color(0x1EFFFFFF);

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

      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 52,
        backgroundColor: bg,
        foregroundColor: Color(0xFFEAF0FF),
      ),

      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),

      cardTheme: const CardTheme(
        elevation: 0,
        color: surface2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: border, width: 1),
        ),
      ),

      listTileTheme: const ListTileThemeData(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),

      // Inputs: glassy fill + soft border
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x1AFFFFFF),
        hintStyle: const TextStyle(color: Color(0x99EAF0FF)),
        labelStyle: const TextStyle(color: Color(0xB3EAF0FF)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x665B7CFF), width: 1.2),
        ),
      ),

      // Buttons: filled primary + outlined secondary like the skin
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          backgroundColor: WidgetStateProperty.all(seed),
          foregroundColor: WidgetStateProperty.all(const Color(0xFFEAF0FF)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          side: WidgetStateProperty.all(const BorderSide(color: border, width: 1)),
          foregroundColor: WidgetStateProperty.all(const Color(0xFFEAF0FF)),
        ),
      ),

      // Slider: blue + purple vibe, subtle inactive track
      sliderTheme: const SliderThemeData(
        trackHeight: 3,
        activeTrackColor: seed,
        inactiveTrackColor: Color(0x334B5B7C),
        thumbColor: Color(0xFFEAF0FF),
        overlayColor: Color(0x225B7CFF),
        valueIndicatorColor: seed,
      ),

      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: WidgetStateProperty.all(true),
        thickness: WidgetStateProperty.all(6),
      ),
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
        colorSchemeSeed: const Color(0xFFE06B6B),
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
        colorSchemeSeed: const Color(0xFF0B2A4A),
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
