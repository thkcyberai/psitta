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
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      return const PsittaTokens(
        backgroundGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF070A12),
            Color(0xFF070C1C),
            Color(0xFF0A1533),
            Color(0xFF070A12),
          ],
          stops: [0.0, 0.35, 0.75, 1.0],
        ),
        headerSurface: Color(0xCC0B1329),
        surface: Color(0xB30B1329),
        surface2: Color(0x990B1329),
        border: Color(0x2A86A9FF),
        divider: Color(0x1EFFFFFF),
        inputFill: Color(0x2AFFFFFF),
        glow: Color(0xFF7AA8FF),
        radius: 14,
      );
    }

    // Light fallback (still slightly “premium”).
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
