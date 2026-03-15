/// Sanitize text for TTS synthesis.
///
/// Strips invisible/problematic Unicode characters, normalizes
/// line endings, and collapses redundant whitespace.
String sanitizeForTts(String text) {
  var t = text;

  // Remove trailing newline that Quill or TextField may append
  if (t.endsWith('\n')) {
    t = t.substring(0, t.length - 1);
  }

  // Strip invisible/problematic Unicode characters that break TTS
  t = t
      .replaceAll('\u200B', '') // zero-width space
      .replaceAll('\u200C', '') // zero-width non-joiner
      .replaceAll('\u200D', '') // zero-width joiner
      .replaceAll('\u00AD', '') // soft hyphen
      .replaceAll('\u00A0', ' ') // non-breaking space → regular space
      .replaceAll('\uFEFF', '') // BOM / zero-width no-break space
      .replaceAll('\r\n', '\n') // normalize line endings
      .replaceAll('\r', '\n'); // normalize carriage returns

  // Collapse multiple spaces into one
  t = t.replaceAll(RegExp(r' {2,}'), ' ');

  return t.trim();
}
