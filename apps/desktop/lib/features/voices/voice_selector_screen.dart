import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/providers.dart';
import '../../data/services/preferences_service.dart';

class VoiceSelectorScreen extends ConsumerWidget {
  const VoiceSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voicesAsync = ref.watch(voicesProvider);
    final selectedId = ref.watch(selectedVoiceIdProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Settings'),
                  onPressed: () => context.go('/settings'),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Default Voice',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Select the voice used for new documents.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: voicesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (voices) => voices.isEmpty
                    ? const Center(child: Text('No voices available'))
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 1.1,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: voices.length,
                        itemBuilder: (context, i) {
                          final v = voices[i];
                          final isSelected = v.id == selectedId;
                          return _VoiceCell(
                            displayName: v.displayName,
                            language: v.language,
                            gender: v.gender,
                            isSelected: isSelected,
                            onTap: () {
                              ref
                                  .read(selectedVoiceIdProvider.notifier)
                                  .select(v.id);
                              context.go('/settings');
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceCell extends StatelessWidget {
  final String displayName;
  final String language;
  final String gender;
  final bool isSelected;
  final VoidCallback onTap;

  const _VoiceCell({
    required this.displayName,
    required this.language,
    required this.gender,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? cs.primaryContainer.withOpacity(0.6)
              : cs.surfaceContainerHighest.withOpacity(0.5),
          border: isSelected
              ? Border.all(color: cs.primary, width: 1)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: cs.primary, width: 3)
                    : null,
              ),
              padding: EdgeInsets.all(isSelected ? 0 : 3),
              child: ClipOval(
                child: SizedBox(
                  width: 110,
                  height: 110,
                  child: CustomPaint(
                    painter: VoiceAvatarPainter(
                      isFemale: gender == 'female',
                      isSelected: isSelected,
                      primaryColor: cs.primary,
                      primaryContainer: cs.primaryContainer,
                      secondaryColor: cs.secondary,
                      secondaryContainer: cs.secondaryContainer,
                      surfaceHighest: cs.surfaceContainerHighest,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              language,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VoiceAvatarPainter extends CustomPainter {
  static const _skinLight = Color(0xFFFFE0C8);
  static const _skinMid = Color(0xFFFFBFA0);

  final bool isFemale;
  final bool isSelected;
  final Color primaryColor;
  final Color primaryContainer;
  final Color secondaryColor;
  final Color secondaryContainer;
  final Color surfaceHighest;

  VoiceAvatarPainter({
    required this.isFemale,
    required this.isSelected,
    required this.primaryColor,
    required this.primaryContainer,
    required this.secondaryColor,
    required this.secondaryContainer,
    required this.surfaceHighest,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // --- Background radial gradient ---
    final bgCenter = Offset(cx, h * 0.4);
    if (isFemale) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = ui.Gradient.radial(
            bgCenter,
            w * 0.7,
            [primaryContainer, primaryColor.withOpacity(0.15)],
          ),
      );
    } else {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = ui.Gradient.radial(
            bgCenter,
            w * 0.7,
            [secondaryContainer, secondaryColor.withOpacity(0.15)],
          ),
      );
    }

    final accentColor = isFemale ? primaryColor : secondaryColor;
    final accentContainer =
        isFemale ? primaryContainer : secondaryContainer;

    // --- Body / Shoulders ---
    final shoulderWidth = isFemale ? w * 0.40 : w * 0.48;
    final shoulderY = h * 0.76;
    final bodyPath = Path();
    bodyPath.moveTo(cx - shoulderWidth, h);
    bodyPath.quadraticBezierTo(
      cx - shoulderWidth, shoulderY,
      cx, shoulderY - (isFemale ? 5 : 3),
    );
    bodyPath.quadraticBezierTo(
      cx + shoulderWidth, shoulderY,
      cx + shoulderWidth, h,
    );
    bodyPath.close();
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx, shoulderY),
          Offset(cx, h),
          [accentColor.withOpacity(isFemale ? 0.6 : 0.5), accentContainer],
        ),
    );

    // Male collar V-shape
    if (!isFemale) {
      final collarPath = Path();
      final collarTop = shoulderY - 2;
      collarPath.moveTo(cx - 6, collarTop);
      collarPath.lineTo(cx, collarTop + 10);
      collarPath.lineTo(cx + 6, collarTop);
      canvas.drawPath(
        collarPath,
        Paint()
          ..color = accentContainer
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // --- Neck ---
    final neckW = w * 0.09;
    final neckTop = h * 0.56;
    canvas.drawRect(
      Rect.fromLTRB(cx - neckW, neckTop, cx + neckW, h * 0.78),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx, neckTop),
          Offset(cx, h * 0.78),
          [_skinLight, _skinMid],
        ),
    );

    // --- Head ---
    final headRadius = w * 0.24;
    final headCy = h * 0.38;
    canvas.drawCircle(
      Offset(cx, headCy),
      headRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - 2, headCy - 3),
          headRadius * 1.2,
          [_skinLight, _skinMid],
        ),
    );

    // --- Hair ---
    final hairColor = accentColor.withOpacity(0.85);
    final hairPaint = Paint()..color = hairColor;

    if (isFemale) {
      // Top hair cap — covers top 60% of head
      final topHair = Path();
      final hairCapBottom = headCy - headRadius * 0.1;
      topHair.moveTo(cx - headRadius - 3, hairCapBottom);
      topHair.quadraticBezierTo(
        cx - headRadius - 3, headCy - headRadius - 5,
        cx, headCy - headRadius - 6,
      );
      topHair.quadraticBezierTo(
        cx + headRadius + 3, headCy - headRadius - 5,
        cx + headRadius + 3, hairCapBottom,
      );
      topHair.arcTo(
        Rect.fromCircle(
            center: Offset(cx, headCy), radius: headRadius + 3),
        0,
        -pi,
        false,
      );
      topHair.close();
      canvas.drawPath(topHair, hairPaint);

      // Left hair strand flowing down
      final leftHair = Path();
      leftHair.moveTo(cx - headRadius - 2, headCy - 4);
      leftHair.cubicTo(
        cx - headRadius - 7, headCy + headRadius * 0.8,
        cx - headRadius - 4, headCy + headRadius * 1.6,
        cx - headRadius + 3, h * 0.85,
      );
      leftHair.lineTo(cx - headRadius + 8, h * 0.85);
      leftHair.cubicTo(
        cx - headRadius + 4, headCy + headRadius * 1.2,
        cx - headRadius + 1, headCy + headRadius * 0.5,
        cx - headRadius + 1, headCy,
      );
      leftHair.close();
      canvas.drawPath(leftHair, hairPaint);

      // Right hair strand flowing down
      final rightHair = Path();
      rightHair.moveTo(cx + headRadius + 2, headCy - 4);
      rightHair.cubicTo(
        cx + headRadius + 7, headCy + headRadius * 0.8,
        cx + headRadius + 4, headCy + headRadius * 1.6,
        cx + headRadius - 3, h * 0.85,
      );
      rightHair.lineTo(cx + headRadius - 8, h * 0.85);
      rightHair.cubicTo(
        cx + headRadius - 4, headCy + headRadius * 1.2,
        cx + headRadius - 1, headCy + headRadius * 0.5,
        cx + headRadius - 1, headCy,
      );
      rightHair.close();
      canvas.drawPath(rightHair, hairPaint);
    } else {
      // Short hair — flat top arc, slightly angular
      final topHair = Path();
      final hairTop = headCy - headRadius - 4;
      topHair.moveTo(cx - headRadius - 2, headCy - headRadius * 0.15);
      topHair.lineTo(cx - headRadius - 2, hairTop + 6);
      topHair.lineTo(cx - headRadius * 0.4, hairTop);
      topHair.lineTo(cx + headRadius * 0.4, hairTop);
      topHair.lineTo(cx + headRadius + 2, hairTop + 6);
      topHair.lineTo(cx + headRadius + 2, headCy - headRadius * 0.15);
      topHair.arcTo(
        Rect.fromCircle(
            center: Offset(cx, headCy), radius: headRadius + 2),
        0,
        -pi,
        false,
      );
      topHair.close();
      canvas.drawPath(topHair, hairPaint);
    }
  }

  @override
  bool shouldRepaint(VoiceAvatarPainter old) => false;
}
