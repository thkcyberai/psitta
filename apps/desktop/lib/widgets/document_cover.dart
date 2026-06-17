import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme/psitta_tokens.dart';
import '../data/models/cover_illustration.dart';
import '../data/providers/providers.dart' show documentRepositoryProvider;

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

  /// Drop any cached cover bytes for [documentId] so the next render refetches
  /// from the backend. Required after a cover change: uploaded covers always
  /// live at the same key (`covers/{id}.jpg`), so `cover_value` is unchanged
  /// and the byte cache (keyed by document + cover_value) would otherwise keep
  /// serving the previous image.
  static void evictCache(String documentId) {
    _UploadedCoverState._cache
        .removeWhere((k, _) => k.startsWith('$documentId::'));
  }

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
    if (t.contains('epub')) return Icons.menu_book;
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
      // The cover endpoint is authenticated. Fetch the bytes through Dio (which
      // carries the auth token) and render with Image.memory — a plain
      // Image.network has no token and silently fails on desktop.
      child: ClipRRect(
        borderRadius: radius,
        child: _UploadedCover(
          documentId: documentId,
          coverValue: coverValue,
          placeholder: _placeholderContent(tokens, isDark),
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

/// Renders an uploaded document cover. Fetches the image bytes through the
/// authenticated Dio client once (re-fetching only when the document or cover
/// changes), shows a spinner while loading and the [placeholder] on failure.
class _UploadedCover extends ConsumerStatefulWidget {
  const _UploadedCover({
    required this.documentId,
    required this.coverValue,
    required this.placeholder,
  });

  final String documentId;
  final String? coverValue;
  final Widget placeholder;

  @override
  ConsumerState<_UploadedCover> createState() => _UploadedCoverState();
}

class _UploadedCoverState extends ConsumerState<_UploadedCover> {
  // Process-lifetime cache of decoded cover bytes, keyed by document + cover
  // version. Survives widget remounts, so moving Library <-> Writing Desk
  // re-shows covers instantly with no refetch or flicker. Soft-capped.
  static final Map<String, Uint8List> _cache = {};
  static const int _cacheCap = 80;

  Uint8List? _bytes;
  bool _loading = true;

  String get _key => '${widget.documentId}::${widget.coverValue ?? ''}';

  @override
  void initState() {
    super.initState();
    final cached = _cache[_key];
    if (cached != null) {
      _bytes = cached;
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant _UploadedCover old) {
    super.didUpdateWidget(old);
    if (old.documentId != widget.documentId ||
        old.coverValue != widget.coverValue) {
      final cached = _cache[_key];
      if (cached != null) {
        setState(() {
          _bytes = cached;
          _loading = false;
        });
      } else {
        _load();
      }
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final bytes =
        await ref.read(documentRepositoryProvider).getCoverBytes(widget.documentId);
    if (!mounted) return;
    if (bytes != null) {
      if (_cache.length >= _cacheCap) _cache.remove(_cache.keys.first);
      _cache[_key] = bytes;
    }
    setState(() {
      _bytes = bytes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => widget.placeholder,
      );
    }
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return widget.placeholder;
  }
}
