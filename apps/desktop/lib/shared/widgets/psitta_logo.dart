import 'package:flutter/material.dart';

/// Theme-aware Psitta horizontal lockup. Swaps between the light and
/// dark asset based on the active [Theme]'s brightness so the wordmark
/// stays legible on both cream and dark surfaces.
class PsittaLogo extends StatelessWidget {
  const PsittaLogo({
    super.key,
    required this.width,
    required this.height,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.high,
  });

  final double width;
  final double height;
  final BoxFit fit;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = isDark
        ? 'assets/branding/psitta-horizontal-dark.png'
        : 'assets/branding/psitta-horizontal.png';
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      filterQuality: filterQuality,
    );
  }
}
