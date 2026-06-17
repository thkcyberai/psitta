import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/constants.dart';
import '../core/theme/psitta_tokens.dart';
import '../data/models/cover_illustration.dart';
import '../data/providers/providers.dart' show apiClientProvider;

/// Reusable document cover image widget.
///
/// Renders the appropriate cover based on [coverType]:
/// - "builtin": loads SVG from local assets
/// - "uploaded": loads image from backend API
/// - null: shows default gradient + file icon placeholder
enum DocumentCoverSize { mini, thumbnail, card, detail, player }

class DocumentCover extends StatelessWidget {
  const DocumentCover({
    super.key,
    required this.coverType,
    required this.coverValue,
    required this.documentId,
    this.size = DocumentCoverSize.detail,
    this.sourceType,
    this.borderRadius,
    this.height,
  });

  final String? coverType;
  final String? coverValue;
  final String documentId;
  final DocumentCoverSize size;
  final String? sourceType;
  final BorderRadius? borderRadius;

  /// Optional explicit banner height. When null, falls back to the per-[size]
  /// default. Lets callers (e.g. the Library grid) render a taller cover banner
  /// without changing the default behaviour of existing call sites.
  final double? height;

  double get _height =>
      height ??
      switch (size) {
        DocumentCoverSize.mini => 36,
        DocumentCoverSize.thumbnail => 60,
        DocumentCoverSize.card => 90,
        DocumentCoverSize.detail => 160,
        DocumentCoverSize.player => 220,
      };

  IconData _fileIcon() {
    final t = (sourceType ?? '').toLowerCase();
    if (t.contains('pdf')) return Icons.picture_as_pdf;
    if (t.contains('docx')) return Icons.article;
    if (t.contains('md')) return Icons.code;
    if (t.contains('txt')) return Icons.text_snippet;
    if (t.contains('html')) return Icons.language;
    return Icons.description;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(tokens.radius - 4);

    if (coverType == 'builtin' && coverValue != null) {
      return _buildBuiltin(tokens, isDark, radius);
    }
    if (coverType == 'uploaded') {
      return _buildUploaded(tokens, isDark, radius);
    }
    return _buildPlaceholder(tokens, isDark, radius);
  }

  Widget _buildBuiltin(PsittaTokens tokens, bool isDark, BorderRadius radius) {
    final illustration = CoverIllustration.findById(coverValue!);
    if (illustration == null) {
      return _buildPlaceholder(tokens, isDark, radius);
    }

    return Container(
      width: double.infinity,
      height: _height,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.glow.withOpacity(isDark ? 0.08 : 0.06),
            tokens.surface2.withOpacity(isDark ? 0.50 : 0.70),
          ],
        ),
        border: Border.all(
          color: tokens.border.withOpacity(isDark ? 0.25 : 0.35),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.all(switch (size) {
            DocumentCoverSize.mini => 4,
            DocumentCoverSize.thumbnail => 8,
            DocumentCoverSize.card => 10,
            _ => 16,
          }),
          child: SvgPicture.asset(
            illustration.assetPath,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildUploaded(PsittaTokens tokens, bool isDark, BorderRadius radius) {
    // Cache-bust with coverValue hashCode so re-uploads show the new image.
    final cacheBuster = coverValue?.hashCode ?? DateTime.now().millisecondsSinceEpoch;
    final url =
        '${AppConstants.apiBaseUrl}/documents/$documentId/cover?v=$cacheBuster';

    return Container(
      width: double.infinity,
      height: _height,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: tokens.border.withOpacity(isDark ? 0.25 : 0.35),
          width: 1,
        ),
      ),
      // The cover image endpoint is authenticated, so Image.network must send
      // the Bearer token (a plain network image would 401 and fall back to the
      // placeholder). Fetch the cached access token, then load with the header.
      child: ClipRRect(
        borderRadius: radius,
        child: Consumer(
          builder: (context, ref, _) {
            return FutureBuilder<String?>(
              future: ref.read(apiClientProvider).accessToken(),
              builder: (context, snap) {
                final token = snap.data;
                final headers = (token != null && token.isNotEmpty)
                    ? {'Authorization': 'Bearer $token'}
                    : const <String, String>{};
                return Image.network(
                  url,
                  headers: headers,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _placeholderContent(tokens, isDark),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholder(
      PsittaTokens tokens, bool isDark, BorderRadius radius) {
    return Container(
      width: double.infinity,
      height: _height,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.glow.withOpacity(isDark ? 0.08 : 0.06),
            tokens.surface2.withOpacity(isDark ? 0.50 : 0.70),
            tokens.glow.withOpacity(isDark ? 0.05 : 0.04),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(
          color: tokens.border.withOpacity(isDark ? 0.25 : 0.35),
          width: 1,
        ),
      ),
      child: _placeholderContent(tokens, isDark),
    );
  }

  Widget _placeholderContent(PsittaTokens tokens, bool isDark) {
    return Center(
      child: Icon(
        _fileIcon(),
        size: switch (size) {
          DocumentCoverSize.mini => 16,
          DocumentCoverSize.thumbnail => 24,
          DocumentCoverSize.card => 32,
          DocumentCoverSize.detail => 48,
          DocumentCoverSize.player => 56,
        },
        color: tokens.glow.withOpacity(isDark ? 0.35 : 0.30),
      ),
    );
  }
}
