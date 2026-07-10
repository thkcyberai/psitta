import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/psitta_tokens.dart';
import '../../data/services/preferences_service.dart';
import 'guide_chat_script.dart';
import '../../l10n/app_localizations.dart';

/// Current step of the Writing Nook guide. autoDispose so it resets to the root
/// whenever the Library route is left and re-entered (all listeners are
/// disposed with the route), giving the writer a fresh default each visit.
final guideNodeProvider =
    StateProvider.autoDispose<String>((ref) => kGuideRoot);

/// Whether the guide is at its root step. The Library rail watches this to keep
/// the card neatly below Quick Access at the root, and let it expand over the
/// Quick Access area once the writer drills into a topic.
final guideAtRootProvider = Provider.autoDispose<bool>(
    (ref) => ref.watch(guideNodeProvider) == kGuideRoot);

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
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final nodeId = ref.watch(guideNodeProvider);
    final loc = AppLocalizations.of(context);
    final script = guideScriptFor(Localizations.localeOf(context).languageCode);
    final node = script[nodeId] ?? script[kGuideRoot]!;
    final atRoot = nodeId == kGuideRoot;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(tokens.radius),
        border: Border.all(color: tokens.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header — uppercase label + tier badge, mirroring Summarize-it.
          Row(
            children: [
              Expanded(
                child: Text(
                  loc.guideTitle,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
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
                _miniIcon(
                    Icons.refresh,
                    loc.guideStartOver,
                    () => ref.read(guideNodeProvider.notifier).state =
                        kGuideRoot,
                    scheme),
              _miniIcon(
                Icons.close,
                loc.guideHide,
                () =>
                    ref.read(guideChatEnabledProvider.notifier).setEnabled(false),
                scheme,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Message stays pinned — always visible.
          Text(
            node.message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 10),
          // Only the options scroll inside the card (own scrollbar). Flexible
          // lets the card hug its content when short, and shrink + scroll the
          // options when the rail constrains its height.
          Flexible(
            child: Scrollbar(
              controller: _scroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.only(right: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Options as full-width, left-aligned buttons.
                    for (final opt in node.options) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => ref
                              .read(guideNodeProvider.notifier)
                              .state = opt.next,
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            alignment: Alignment.centerLeft,
                            foregroundColor: scheme.onSurface,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            side: BorderSide(
                                color: tokens.border.withValues(alpha: 0.6)),
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
              ),
            ),
          ),
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
