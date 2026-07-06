import 'package:flutter/material.dart';

import '../../core/theme/psitta_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'narrative_guidance.dart';
import 'narrative_guidance_i18n.dart';
import 'narrative_structures.dart';
import 'narrative_i18n.dart';

/// Opens the Interactive Guide for [structure]'s [variantIndex] — a walkthrough
/// of each beat with what it does and a craft tip. Read-only, no AI, no cost.
Future<void> showInteractiveGuide(
  BuildContext context, {
  required NarrativeStructure structure,
  required int variantIndex,
}) {
  final vi = variantIndex.clamp(0, structure.variants.length - 1);
  return showDialog<void>(
    context: context,
    builder: (_) => _InteractiveGuideDialog(structure: structure, variantIndex: vi),
  );
}

class _InteractiveGuideDialog extends StatelessWidget {
  const _InteractiveGuideDialog({
    required this.structure,
    required this.variantIndex,
  });

  final NarrativeStructure structure;
  final int variantIndex;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final variant = structure.variants[variantIndex];
    final beats = variant.components;
    final loc = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: tokens.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.menu_book_outlined, size: 22, color: tokens.glow),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(loc.interactiveGuideLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: tokens.glow,
                                )),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 2),
                              decoration: BoxDecoration(
                                color: tokens.glow.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(bestForLabel(context, variant.bestFor),
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: tokens.glow)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(structureNameLabel(context, structure.name),
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(loc.guideStepsCaption(beats.length),
                            style: TextStyle(
                                fontSize: 12, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: loc.actionClose,
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: tokens.divider),
            // Beats
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                itemCount: beats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _BeatCard(
                  index: i,
                  total: beats.length,
                  name: beatLabel(context, beats[i]),
                  guide: localizedGuideForBeat(context, beats[i]),
                ),
              ),
            ),
            Divider(height: 1, color: tokens.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Text(
                loc.generalCraftGuidance,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BeatCard extends StatelessWidget {
  const _BeatCard({
    required this.index,
    required this.total,
    required this.name,
    required this.guide,
  });

  final int index;
  final int total;
  final String name;
  final BeatGuide guide;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.glow.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Text('${index + 1}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: tokens.glow)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(guide.purpose,
              style: TextStyle(
                  fontSize: 13, height: 1.4, color: scheme.onSurface)),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
            decoration: BoxDecoration(
              color: tokens.glow.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, size: 15, color: tokens.glow),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: scheme.onSurface),
                      children: [
                        TextSpan(
                            text: '${loc.tipLabel}  ',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: tokens.glow)),
                        TextSpan(text: guide.tip),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
