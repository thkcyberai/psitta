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
        'assets/branding/voice_avatars/$prefix-${voiceName.toLowerCase()}.png';
    final ring = ringColor ?? PsittaTokens.of(context).glow;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: ringWidth),
        boxShadow: [
          BoxShadow(
            color: ring.withOpacity(0.30),
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
