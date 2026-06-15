/// Application-wide constants.
///
/// Desktop-specific: window constraints, sidebar widths,
/// player bar height for multi-pane layout calculations.
abstract final class AppConstants {
  // ── API ──────────────────────────────────────────────────────
  static const String apiBaseUrl = 'https://api.psitta.ai/api/v1';
  static const Duration httpTimeout = Duration(seconds: 30);

  // ── Playback ─────────────────────────────────────────────────
  static const double minPlaybackSpeed = 0.5;
  static const double maxPlaybackSpeed = 3.0;
  static const double defaultPlaybackSpeed = 1.0;

  // ── Desktop Layout ───────────────────────────────────────────
  static const double sidebarWidth = 212.0;
  static const double sidebarCollapsedWidth = 64.0;
  static const double playerBarHeight = 80.0;
  static const double minContentWidth = 400.0;
  static const double detailPanelMinWidth = 300.0;

  // ── Window ───────────────────────────────────────────────────
  static const double windowMinWidth = 900.0;
  static const double windowMinHeight = 600.0;
  static const double windowDefaultWidth = 1280.0;
  static const double windowDefaultHeight = 800.0;

  // ── Upload ───────────────────────────────────────────────────
  static const int maxFileSizeMB = 50;
  static const List<String> allowedExtensions = [
    'pdf',
    'docx',
    'txt',
    'md',
    'html',
  ];
}
