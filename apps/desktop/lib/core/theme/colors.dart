import 'package:flutter/material.dart';

/// Psitta design tokens — color palette.
///
/// Desktop-optimized: higher contrast ratios for monitor viewing,
/// subtle surface distinctions for multi-pane layouts.
abstract final class AppColors {
  // ── Primary ──────────────────────────────────────────────────
  static const primary = Color(0xFF1A73E8);
  static const primaryLight = Color(0xFF4DA3FF);
  static const primaryDark = Color(0xFF0D47A1);

  // ── Surfaces (desktop multi-pane) ────────────────────────────
  static const surface = Color(0xFFFAFAFA);
  static const surfaceDark = Color(0xFF1E1E1E);
  static const sidebarLight = Color(0xFFF0F2F5);
  static const sidebarDark = Color(0xFF252526);
  static const panelBorder = Color(0xFFE0E0E0);
  static const panelBorderDark = Color(0xFF3C3C3C);

  // ── Text ─────────────────────────────────────────────────────
  static const textPrimary = Color(0xFF1F1F1F);
  static const textSecondary = Color(0xFF5F6368);
  static const textPrimaryDark = Color(0xFFE0E0E0);
  static const textSecondaryDark = Color(0xFF9AA0A6);

  // ── Semantic ─────────────────────────────────────────────────
  static const success = Color(0xFF34A853);
  static const warning = Color(0xFFFBBC04);
  static const error = Color(0xFFEA4335);

  // ── Audio / Playback ─────────────────────────────────────────
  static const waveform = Color(0xFF1A73E8);
  static const waveformInactive = Color(0xFFDADCE0);
  static const playerBar = Color(0xFFF8F9FA);
  static const playerBarDark = Color(0xFF2D2D2D);
}
