import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

/// Extracts raw text from each page of a PDF file using pdfrx.
///
/// Used as the single source of truth for PDF text extraction on the
/// client side, so the backend receives pre-extracted page texts and
/// does not need to re-parse the PDF.
class PdfTextExtractor {
  PdfTextExtractor._();

  /// Returns a list of `{page_number: int, text: String}` maps for every
  /// page that contains non-empty text.  Returns an empty list on failure.
  static Future<List<Map<String, dynamic>>> extractPageTexts(
    String filePath,
  ) async {
    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(filePath);
      final List<Map<String, dynamic>> results = [];

      for (int i = 0; i < document.pages.length; i++) {
        final page = document.pages[i];
        final pageText = await page.loadText();
        final text = pageText.fullText;
        if (text.isNotEmpty) {
          results.add({
            'page_number': i + 1,
            'text': text,
          });
        }
      }

      return results;
    } catch (e) {
      debugPrint('[PdfTextExtractor] Failed to extract text: $e');
      return [];
    } finally {
      document?.dispose();
    }
  }
}
