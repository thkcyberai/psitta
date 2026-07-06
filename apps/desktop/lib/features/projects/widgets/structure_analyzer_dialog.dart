import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/psitta_tokens.dart';
import '../../../data/models/project_detail.dart'
    show StructureAnalysis, StructureBeatResult;
import '../../../data/providers/providers.dart'
    show projectRepositoryProvider, projectsProvider;
import '../../../l10n/app_localizations.dart';
import '../../blueprints/narrative_i18n.dart';

/// Opens the Structure Analyzer for a project — an on-demand, whole-manuscript
/// AI assessment of how well the writing delivers each beat.
Future<void> showStructureAnalyzer(BuildContext context,
    {required String projectId}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _StructureAnalyzerDialog(projectId: projectId),
  );
}

/// Entry from the project-agnostic Blueprints gallery: pick a book, then run.
Future<void> pickProjectAndShowAnalyzer(
    BuildContext context, WidgetRef ref) async {
  final dynamic projects;
  try {
    projects = await ref.read(projectsProvider.future);
  } catch (_) {
    return;
  }
  if (!context.mounted) return;
  final loc = AppLocalizations.of(context);

  if (projects.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.noProjectsYet),
        content: Text(loc.analyzerCreateProjectBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.actionOk)),
        ],
      ),
    );
    return;
  }

  String? chosen = projects.length == 1 ? projects.first.id as String : null;
  chosen ??= await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(loc.analyzeWhichBook),
      children: [
        for (final p in projects)
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(p.id as String),
            child: Text(p.name as String),
          ),
      ],
    ),
  );

  if (chosen != null && context.mounted) {
    await showStructureAnalyzer(context, projectId: chosen);
  }
}

enum _Phase { idle, loading, done, error }

class _StructureAnalyzerDialog extends ConsumerStatefulWidget {
  const _StructureAnalyzerDialog({required this.projectId});

  final String projectId;

  @override
  ConsumerState<_StructureAnalyzerDialog> createState() =>
      _StructureAnalyzerDialogState();
}

class _StructureAnalyzerDialogState
    extends ConsumerState<_StructureAnalyzerDialog> {
  _Phase _phase = _Phase.idle;
  StructureAnalysis? _result;
  String _error = '';

  Future<void> _run() async {
    setState(() => _phase = _Phase.loading);
    try {
      final r = await ref
          .read(projectRepositoryProvider)
          .analyzeStructure(widget.projectId);
      if (!mounted) return;
      setState(() {
        _result = r;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _messageFor(e);
        _phase = _Phase.error;
      });
    }
  }

  String _messageFor(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail is Map && detail['message'] is String) {
          return detail['message'] as String;
        }
        if (detail is String) return detail;
      }
    }
    return AppLocalizations.of(context).analyzerCouldNotAnalyze;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: tokens.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.insights_outlined, size: 22, color: tokens.glow),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(loc.featureStructureAnalyzer,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w800)),
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
            Flexible(child: _body(context, tokens, scheme)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, PsittaTokens tokens, ColorScheme scheme) {
    final loc = AppLocalizations.of(context);
    switch (_phase) {
      case _Phase.loading:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(loc.analyzerReading,
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
        );
      case _Phase.error:
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.error_outline, size: 20, color: scheme.error),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(_error,
                        style: const TextStyle(fontSize: 13.5, height: 1.4))),
              ]),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                    onPressed: _run, child: Text(loc.actionTryAgain)),
              ),
            ],
          ),
        );
      case _Phase.done:
        return _ResultView(result: _result!, onRerun: _run);
      case _Phase.idle:
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.analyzerIntro,
                style: TextStyle(
                    fontSize: 13.5, height: 1.45, color: scheme.onSurface),
              ),
              const SizedBox(height: 10),
              Text(
                loc.analyzerTokensNote,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _run,
                  icon: const Icon(Icons.insights_outlined, size: 18),
                  label: Text(loc.analyzerRun),
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result, required this.onRerun});

  final StructureAnalysis result;
  final VoidCallback onRerun;

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      children: [
        if (result.overall.trim().isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.glow.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(result.overall.trim(),
                style: TextStyle(
                    fontSize: 13.5, height: 1.45, color: scheme.onSurface)),
          ),
          const SizedBox(height: 16),
        ],
        for (final b in result.beats) _BeatResultRow(beat: b),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onRerun,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(loc.analyzerReanalyze),
          ),
        ),
      ],
    );
  }
}

class _BeatResultRow extends StatelessWidget {
  const _BeatResultRow({required this.beat});

  final StructureBeatResult beat;

  ({Color color, IconData icon, String label}) _style(BuildContext context) {
    final loc = AppLocalizations.of(context);
    switch (beat.status) {
      case 'present':
        return (
          color: const Color(0xFF54C68A),
          icon: Icons.check_circle,
          label: loc.beatStatusPresent
        );
      case 'thin':
        return (
          color: const Color(0xFFE0A24E),
          icon: Icons.error_outline,
          label: loc.beatStatusThin
        );
      case 'missing':
        return (
          color: const Color(0xFFE5709B),
          icon: Icons.cancel_outlined,
          label: loc.beatStatusMissing
        );
      default:
        return (
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          icon: Icons.help_outline,
          label: beat.status.isEmpty ? '—' : beat.status
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = _style(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(s.icon, size: 18, color: s.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(beatLabel(context, beat.beat),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Text(s.label,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: s.color)),
                  ],
                ),
                if (beat.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(beat.note.trim(),
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: scheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
