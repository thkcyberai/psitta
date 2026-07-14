import 'package:flutter/material.dart';
import '../core/theme/psitta_tokens.dart';

enum VoiceAvatarVariant { small, big, auto }

class VoiceAvatar extends StatelessWidget {
  const VoiceAvatar({
    super.key,
    required this.voiceName,
    required this.size,
    this.variant = VoiceAvatarVariant.auto,
    this.ringWidth = 2.0,
    this.ringColor,
  });

  final String voiceName;
  final double size;
  final VoiceAvatarVariant variant;
  final double ringWidth;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final useBig = variant == VoiceAvatarVariant.big ||
        (variant == VoiceAvatarVariant.auto && size > 64);
    final prefix = useBig ? 'big' : 'small';
    final assetPath =
        'assets/branding/voice_avatars/$prefix-${_assetSlug(voiceName)}.png';
    final ring = ringColor ?? PsittaTokens.of(context).glow;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: ringWidth),
        boxShadow: [
          BoxShadow(
            color: ring.withValues(alpha: 0.30),
            blurRadius: ringWidth * 4,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(context),
        ),
      ),
    );
  }

  /// Maps a voice display name to its asset file slug: lowercased with Latin
  /// diacritics stripped, so "Antônio" → "antonio" and "Álvaro" → "alvaro".
  /// English names (no accents) are unaffected.
  static String _assetSlug(String name) {
    const accents = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    final buf = StringBuffer();
    for (final ch in name.toLowerCase().split('')) {
      buf.write(accents[ch] ?? ch);
    }
    return buf.toString();
  }

  Widget _fallback(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Icon(
        Icons.person_outline,
        size: size * 0.5,
        color: cs.onSurfaceVariant,
      ),
    );
  }
}
