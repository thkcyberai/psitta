import 'package:flutter/material.dart';

/// Psitta design tokens — color palette.
///
/// Desktop-optimized: higher contrast ratios for monitor viewing,
/// subtle surface distinctions for multi-pane layouts.
abstract final class AppColors {
  // ── Primary ──────────────────────────────────────────────────
  // Midnight accent direction: blue -> purple
  static const primary = Color(0xFF5B7CFF);
  static const primaryLight = Color(0xFF86A9FF);
  static const primaryDark = Color(0xFF2F56FF);

  static const secondary = Color(0xFF9B6BFF);

  // ── Surfaces (desktop multi-pane) ────────────────────────────
  static const surface = Color(0xFFF9FAFB);
  static const surfaceDark = Color(0xFF0C1224);
  static const sidebarLight = Color(0xFFF0F2F5);
  static const sidebarDark = Color(0xFF0B1020);
  static const panelBorder = Color(0xFFE0E0E0);
  static const panelBorderDark = Color(0x262F6BFF);

  // ── Text ─────────────────────────────────────────────────────
  static const textPrimary = Color(0xFF1F1F1F);
  static const textSecondary = Color(0xFF5F6368);
  static const textPrimaryDark = Color(0xFFEAF0FF);
  static const textSecondaryDark = Color(0xFF9BB0D6);

  // ── Semantic ─────────────────────────────────────────────────
  static const success = Color(0xFF34A853);
  static const warning = Color(0xFFFBBC04);
  static const error = Color(0xFFEA4335);

  // ── Audio / Playback ─────────────────────────────────────────
  static const waveform = primary;
  static const waveformInactive = Color(0x335B7CFF);
  static const playerBar = Color(0xFFF8F9FA);
  static const playerBarDark = Color(0xFF0B1020);
}
