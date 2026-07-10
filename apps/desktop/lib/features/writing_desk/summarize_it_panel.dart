import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

import '../../core/theme/psitta_tokens.dart';
import '../../data/providers/providers.dart';

/// Average LLM tokens consumed per Summarize-it call.
/// Used to convert the remaining token budget to a human-readable count.
const _kAvgTokensPerSummary = 6500;

/// Statuses where the document has no synthesised text yet — Summarize is
/// disabled until these pass. 'ready', 'error', and any future post-content
/// status allow the button so a failed-but-chunked doc can still be
/// summarised from available chunks.
const _kPreContentStatuses = {'uploaded', 'parsing', 'chunking'};

const _kMonthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

enum _SummarizeState { idle, loading, result, quotaExhausted, notInPlan, error }

/// Live Summarize-it panel in the Writing Desk context rail (WD-6).
///
/// States: idle (length chips + Summarize button), loading, result (summary
/// text + quota footer + Re-summarize), 402 quota exhausted, 403 locked /
/// upgrade, error / retry.
///
/// Entitlement: uses [billingStatusProvider] — writing_nook_pro and
/// creative_nook_pro are entitled; free users see the locked state. If the
/// provider is loading the panel shows idle and falls back to the 403 the
/// backend enforces.
class SummarizeItPanel extends ConsumerStatefulWidget {
  const SummarizeItPanel({
    super.key,
    required this.documentId,
  });

  final String documentId;

  @override
  ConsumerState<SummarizeItPanel> createState() => _SummarizeItPanelState();
}

class _SummarizeItPanelState extends ConsumerState<SummarizeItPanel> {
  _SummarizeState _state = _SummarizeState.idle;
  String _selectedLength = 'medium';

  // result state
  String? _summary;
  int _tokensUsedPeriod = 0;
  int _tokensLimitPeriod = 0;

  // 402 state — ISO date string from quota.period_end
  String? _resetDate;

  // error state
  String? _errorMessage;

  // ── API call ───────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() {
      _state = _SummarizeState.loading;
      _summary = null;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(apiClientProvider).dio;
      final response = await dio.post(
        '/documents/${widget.documentId}/summarize',
        data: {'length': _selectedLength},
      );
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _summary = (data['summary'] as String?) ?? '';
        _tokensUsedPeriod =
            (data['tokens_used_period'] as num?)?.toInt() ?? 0;
        _tokensLimitPeriod =
            (data['tokens_limit_period'] as num?)?.toInt() ?? 0;
        _state = _SummarizeState.result;
      });
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final raw = e.response?.data;
      final detail = raw is Map ? raw['detail'] : null;

      if (status == 402) {
        final quota = detail is Map ? (detail['quota'] as Map?) : null;
        setState(() {
          _resetDate = quota?['period_end'] as String?;
          _state = _SummarizeState.quotaExhausted;
        });
      } else if (status == 403) {
        setState(() => _state = _SummarizeState.notInPlan);
      } else {
        setState(() {
          _errorMessage = "Couldn't generate a summary. Please try again.";
          _state = _SummarizeState.error;
        });
      }
    } catch (_) {
      setState(() {
        _errorMessage = "Couldn't generate a summary. Please try again.";
        _state = _SummarizeState.error;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    // Entitlement: gate on llm_tokens_per_period > 0 from billing limits.
    // Writing Nook Pro and Creative Nook Pro have llm > 0; Free and Reading
    // Nook Pro have llm == 0. If billing is still loading we show idle and
    // let the backend enforce via 403.
    final billingAsync = ref.watch(billingStatusProvider);
    final llmTokens =
        (billingAsync.valueOrNull?['llm_tokens_per_period'] as num?)?.toInt() ??
            0;
    final planConfirmedLocked = billingAsync.hasValue && llmTokens == 0;

    if ((planConfirmedLocked && _state == _SummarizeState.idle) ||
        _state == _SummarizeState.notInPlan) {
      return _PanelCard(
        tokens: tokens,
        child: _buildLockedContent(context, scheme),
      );
    }

    // Has-text gate: trust document status from the cached docs list.
    final docsAsync = ref.watch(documentsProvider);
    final doc = docsAsync.valueOrNull
        ?.where((d) => d.id == widget.documentId)
        .firstOrNull;
    final String? notReadyHint = (doc != null &&
            _kPreContentStatuses.contains(doc.status))
        ? loc.docProcessing
        : null;

    final int? summariesPerPeriod =
        llmTokens > 0 ? (llmTokens ~/ _kAvgTokensPerSummary) : null;

    return _PanelCard(
      tokens: tokens,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, scheme),
          const SizedBox(height: 8),
          _buildStateContent(
              context, scheme, notReadyHint, summariesPerPeriod),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, ColorScheme scheme) {
    final loc = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            loc.summarizeItTitle,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Writing Nook',
            key: const ValueKey('desk-summarize-tier-badge'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                ),
          ),
        ),
      ],
    );
  }

  // ── State dispatcher ───────────────────────────────────────────────────────

  Widget _buildStateContent(
    BuildContext context,
    ColorScheme scheme,
    String? notReadyHint,
    int? summariesPerPeriod,
  ) {
    if (_state == _SummarizeState.loading) {
      return _buildLoading(context, scheme);
    }
    if (_state == _SummarizeState.result) {
      return _buildResult(context, scheme);
    }
    if (_state == _SummarizeState.quotaExhausted) {
      return _buildQuotaExhausted(context, scheme);
    }
    if (_state == _SummarizeState.error) {
      return _buildError(context, scheme);
    }
    // idle (notInPlan is handled before _buildStateContent is reached)
    return _buildIdle(context, scheme, notReadyHint, summariesPerPeriod);
  }

  String _lengthLabel(AppLocalizations loc, String value) {
    switch (value) {
      case 'short':
        return loc.lengthShort;
      case 'long':
        return loc.lengthLong;
      default:
        return loc.lengthMedium;
    }
  }

  // ── Idle ───────────────────────────────────────────────────────────────────

  Widget _buildIdle(
    BuildContext context,
    ColorScheme scheme,
    String? notReadyHint,
    int? summariesPerPeriod,
  ) {
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 4,
          children: [
            for (final length in ['short', 'medium', 'long'])
              ChoiceChip(
                key: ValueKey('desk-summarize-length-$length'),
                label: Text(
                  _lengthLabel(loc, length),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                selected: _selectedLength == length,
                onSelected: (_) =>
                    setState(() => _selectedLength = length),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Tooltip(
          message: notReadyHint ?? '',
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('desk-summarize-generate'),
              onPressed: notReadyHint == null ? _submit : null,
              child: Text(loc.summarizeBtn),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline,
                size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                summariesPerPeriod != null
                    ? loc.summarizeAllowanceCount(summariesPerPeriod)
                    : loc.summarizeAllowance,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  Widget _buildLoading(BuildContext context, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Summarizing…',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  // ── Result ─────────────────────────────────────────────────────────────────

  Widget _buildResult(BuildContext context, ColorScheme scheme) {
    final remaining = _tokensLimitPeriod > 0
        ? ((_tokensLimitPeriod - _tokensUsedPeriod) / _kAvgTokensPerSummary)
            .round()
            .clamp(0, 9999)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          _summary ?? '',
          key: const ValueKey('desk-summarize-result-text'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface,
                height: 1.5,
              ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            key: const ValueKey('desk-summarize-redo'),
            onPressed: () => setState(() => _state = _SummarizeState.idle),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Re-summarize'),
          ),
        ),
        if (remaining != null) ...[
          const SizedBox(height: 6),
          Text(
            'About $remaining ${remaining == 1 ? 'summary' : 'summaries'} left this month',
            key: const ValueKey('desk-summarize-quota-footer'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }

  // ── Quota exhausted ────────────────────────────────────────────────────────

  Widget _buildQuotaExhausted(BuildContext context, ColorScheme scheme) {
    var resetLabel = 'your next billing anniversary';
    if (_resetDate != null) {
      final dt = DateTime.tryParse(_resetDate!);
      if (dt != null) {
        resetLabel = '${_kMonthAbbr[dt.month - 1]} ${dt.day}';
      }
    }
    return Text(
      'Monthly summaries used up.\nResets on $resetLabel.',
      key: const ValueKey('desk-summarize-quota-exhausted'),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurface,
          ),
    );
  }

  // ── Locked / not in plan ───────────────────────────────────────────────────

  Widget _buildLockedContent(BuildContext context, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, scheme),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.lock_outline, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Upgrade to Writing Nook',
                key: const ValueKey('desk-summarize-locked-label'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _buildError(BuildContext context, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _errorMessage ?? "Couldn't generate a summary. Please try again.",
          key: const ValueKey('desk-summarize-error-text'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.error,
              ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            key: const ValueKey('desk-summarize-retry'),
            onPressed: _submit,
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}

// ── Card shell (mirrors _RailCard from document_context_pane.dart) ─────────────

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.tokens,
    required this.child,
  });

  final PsittaTokens tokens;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(tokens.radius),
        border: Border.all(
          color: tokens.border.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}
