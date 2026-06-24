import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/psitta_tokens.dart';
import '../../data/services/preferences_service.dart';
import 'guide_chat_script.dart';

/// The Writing Nook guide as a neat, self-contained card for the Library right
/// rail — styled to match the Summarize-it panel. Pre-configured (non-AI): it
/// shows the current step's message and its options as buttons; tapping an
/// option advances the script. Author content in guide_chat_script.dart.
class GuideRailCard extends ConsumerStatefulWidget {
  const GuideRailCard({super.key});

  @override
  ConsumerState<GuideRailCard> createState() => _GuideRailCardState();
}

class _GuideRailCardState extends ConsumerState<GuideRailCard> {
  String _node = kGuideRoot;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final node = kGuideScript[_node] ?? kGuideScript[kGuideRoot]!;
    final atRoot = _node == kGuideRoot;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(tokens.radius),
        border: Border.all(color: tokens.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — uppercase label + tier badge, mirroring Summarize-it.
          Row(
            children: [
              Expanded(
                child: Text(
                  "WRITER'S GUIDE",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Writing Nook',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.primary),
                ),
              ),
              if (!atRoot)
                _miniIcon(Icons.refresh, 'Start over',
                    () => setState(() => _node = kGuideRoot), scheme),
              _miniIcon(
                Icons.close,
                'Hide (turn back on in Settings)',
                () =>
                    ref.read(guideChatEnabledProvider.notifier).setEnabled(false),
                scheme,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Current step's message.
          Text(
            node.message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 10),
          // Options as full-width, left-aligned buttons.
          for (final opt in node.options) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => setState(() => _node = opt.next),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  alignment: Alignment.centerLeft,
                  foregroundColor: scheme.onSurface,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: BorderSide(color: tokens.border.withValues(alpha: 0.6)),
                ),
                child: Text(
                  opt.label,
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _miniIcon(
      IconData icon, String tip, VoidCallback onTap, ColorScheme scheme) {
    return IconButton(
      tooltip: tip,
      iconSize: 15,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
      onPressed: onTap,
      icon: Icon(icon, size: 15, color: scheme.onSurfaceVariant),
    );
  }
}
