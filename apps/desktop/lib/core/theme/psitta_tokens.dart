import 'package:flutter/material.dart';

/// PsittaTokens
/// Centralized look-and-feel tokens used by the desktop shell and surfaces.
///
/// Keep these tokens stable. Evolve carefully to avoid UI drift.
class PsittaTokens {
  final Gradient backgroundGradient;
  final Color headerSurface;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color divider;
  final Color inputFill;
  final Color glow;
  final double radius;

  const PsittaTokens({
    required this.backgroundGradient,
    required this.headerSurface,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.divider,
    required this.inputFill,
    required this.glow,
    required this.radius,
  });

  static PsittaTokens of(BuildContext context) {
    final theme = Theme.of(context);

    // Midnight feel (deep navy + glass)
    if (theme.brightness == Brightness.dark) {
      return const PsittaTokens(
        backgroundGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF070A14),
            Color(0xFF070C1C),
            Color(0xFF0B1636),
            Color(0xFF070A14),
          ],
          stops: [0.0, 0.33, 0.78, 1.0],
        ),
        headerSurface: Color(0xCC0C1224),
        surface: Color(0xB30C1224),
        surface2: Color(0x990C1224),
        border: Color(0x262F6BFF),
        divider: Color(0x1EFFFFFF),
        inputFill: Color(0x1AFFFFFF),
        glow: Color(0xFF8A7CFF),
        radius: 18,
      );
    }

    // Light skins are selected via ThemeData (AppTheme.*) by setting distinct scaffold backgrounds.
    final bg = theme.scaffoldBackgroundColor.value;

    // ── Skin: Rose (matches RoseSalmonPastel.png) ──
    if (bg == const Color(0xFFFFF7F5).value) {
      return const PsittaTokens(
        backgroundGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF7F4), // paper
            Color(0xFFF7EFEE), // blush haze
            Color(0xFFF4DDD3), // warm salmon wash
            Color(0xFFFFF7F4),
          ],
          stops: [0.0, 0.35, 0.78, 1.0],
        ),
        headerSurface: Color(0xFFFFF7F4),
        surface: Color(0xFFFDF7F4),
        surface2: Color(0xFFF7EFEE),
        border: Color(0x33E7BDB2), // warm border
        divider: Color(0x26C9A59C),
        inputFill: Color(0x12B07B6E),
        glow: Color(0xFFE38B77), // salmon accent
        radius: 16,
      );
    }

    // ── Skin: Parchment (matches PaperLight.png) ──
    if (bg == const Color(0xFFF7F5EF).value) {
      return const PsittaTokens(
        backgroundGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF3F5F7),
            Color(0xFFE7EBF1),
            Color(0xFFFFFFFF),
          ],
          stops: [0.0, 0.35, 0.78, 1.0],
        ),
        headerSurface: Color(0xFDFEFEFF),
        surface: Color(0xFFFFFFFF),
        surface2: Color(0xFFF9F9FB),
        border: Color(0x22000000),
        divider: Color(0x14000000),
        inputFill: Color(0x0F000000),
        glow: Color(0xFF3162A7),
        radius: 14,
      );
    }

    // ── Skin: Amber (matches BeigeGold.png) ──
    if (bg == const Color(0xFFF4EFE5).value) {
      return const PsittaTokens(
        backgroundGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFBF3EF),
            Color(0xFFF5EAE2),
            Color(0xFFEDDCCD),
            Color(0xFFFBF3EF),
          ],
          stops: [0.0, 0.35, 0.78, 1.0],
        ),
        headerSurface: Color(0xFFFDF8F2),
        surface: Color(0xFFFDF8F2),
        surface2: Color(0xFFF5EAE2),
        border: Color(0x33C7B39C),
        divider: Color(0x26B9A88F),
        inputFill: Color(0x12A8875E),
        glow: Color(0xFFB88A4B), // gold accent
        radius: 16,
      );
    }

    // Default light fallback (safe)
    return const PsittaTokens(
      backgroundGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFF6F8FF),
          Color(0xFFF3F6FF),
          Color(0xFFEFF3FF),
          Color(0xFFF6F8FF),
        ],
        stops: [0.0, 0.35, 0.75, 1.0],
      ),
      headerSurface: Color(0xEFFFFFFF),
      surface: Color(0xF2FFFFFF),
      surface2: Color(0xE6FFFFFF),
      border: Color(0x22000000),
      divider: Color(0x14000000),
      inputFill: Color(0x0F000000),
      glow: Color(0xFF3B6FFF),
      radius: 14,
    );
  }
}
