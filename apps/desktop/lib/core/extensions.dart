// Dart extension methods used across the app.

extension DurationFormatting on Duration {
  /// Formats duration as player timestamp: "1:05:30" or "05:30".
  String toPlayerTimestamp() {
    final hours = inHours;
    final minutes = inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }
}

extension StringTruncate on String {
  /// Truncate with ellipsis for sidebar display.
  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - 1)}…';
  }
}
