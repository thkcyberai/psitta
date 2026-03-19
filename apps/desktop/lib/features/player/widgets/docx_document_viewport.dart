import 'package:flutter/material.dart';

import '../../../core/theme/psitta_tokens.dart';
import '../../../data/models/psitta_document.dart';
import '../../../data/services/audio_service.dart';
import 'document_reading_view.dart';

/// Structured DOCX document viewport for the Player.
///
/// This keeps Psitta chrome and theme around the outside while rendering the
/// assembled DOCX content on a centered white document sheet.
class DocxDocumentViewport extends StatelessWidget {
  const DocxDocumentViewport({
    super.key,
    required this.document,
    required this.activeChunkIndex,
    required this.alignmentPayload,
    this.focusedSentenceIndex,
    this.isFetchingAlignment = false,
    this.onActiveSentenceChanged,
    this.onActiveWordChanged,
    this.onMarkerTap,
    this.audioService,
    this.editorChild,
    this.leadingBlocks,
    this.trailingBlocks,
    this.markerModeEnabled = false,
    this.blockKeys,
  });

  final PsittaDocument document;
  final int activeChunkIndex;
  final Map<String, dynamic> alignmentPayload;
  final int? focusedSentenceIndex;
  final bool isFetchingAlignment;
  final void Function(GlobalKey blockKey)? onActiveSentenceChanged;
  final void Function(int wordIndex, int totalWords)? onActiveWordChanged;
  final void Function(int docOffset)? onMarkerTap;
  final AudioService? audioService;
  final Widget? editorChild;
  final List<DocBlock>? leadingBlocks;
  final List<DocBlock>? trailingBlocks;
  final bool markerModeEnabled;
  final Map<String, GlobalKey>? blockKeys;

  ThemeData _documentTheme(ThemeData appTheme) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: appTheme.colorScheme.copyWith(
        brightness: Brightness.light,
        surface: Colors.white,
        onSurface: const Color(0xFF1D2430),
        onSurfaceVariant: const Color(0xFF596577),
        outlineVariant: const Color(0xFFD9DEE6),
      ),
    );

    const bodyColor = Color(0xFF1D2430);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.white,
      canvasColor: Colors.white,
      cardColor: Colors.white,
      textTheme: base.textTheme.apply(
        bodyColor: bodyColor,
        displayColor: bodyColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = PsittaTokens.of(context);
    final stageBackground =
        Color.alphaBlend(tokens.surface2, theme.scaffoldBackgroundColor);
    final hasAlignment = alignmentPayload['alignment'] != null;

    return Container(
      decoration: BoxDecoration(
        color: stageBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: tokens.border.withOpacity(0.65),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: MouseRegion(
            cursor: markerModeEnabled
                ? SystemMouseCursors.precise
                : MouseCursor.defer,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0x14000000),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x16000000),
                    blurRadius: 28,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Theme(
                data: _documentTheme(theme),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 56, vertical: 52),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isFetchingAlignment && !hasAlignment)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Loading word highlighting...',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (editorChild != null) ...[
                        if (leadingBlocks != null && leadingBlocks!.isNotEmpty)
                          _DocxStaticBlocksView(blocks: leadingBlocks!),
                        if (leadingBlocks != null && leadingBlocks!.isNotEmpty)
                          const SizedBox(height: 28),
                        editorChild!,
                        if (trailingBlocks != null &&
                            trailingBlocks!.isNotEmpty)
                          const SizedBox(height: 28),
                        if (trailingBlocks != null &&
                            trailingBlocks!.isNotEmpty)
                          _DocxStaticBlocksView(blocks: trailingBlocks!),
                      ] else
                        DocumentReadingView(
                          document: document,
                          activeChunkIndex: activeChunkIndex,
                          alignmentPayload: alignmentPayload,
                          focusedSentenceIndex: focusedSentenceIndex,
                          onActiveSentenceChanged: onActiveSentenceChanged,
                          onActiveWordChanged: onActiveWordChanged,
                          onMarkerTap: onMarkerTap,
                          audioService: audioService,
                          enableContextMenu: !markerModeEnabled,
                          markerModeEnabled: markerModeEnabled,
                          blockKeys: blockKeys,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DocxStaticBlocksView extends StatelessWidget {
  const _DocxStaticBlocksView({
    required this.blocks,
  });

  final List<DocBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks)
          Padding(
            padding: EdgeInsets.only(
              bottom: block.type == DocBlockType.heading ? 16 : 8,
            ),
            child: SelectableText.rich(
              TextSpan(
                children: _spansForBlock(block, theme),
              ),
            ),
          ),
      ],
    );
  }

  List<TextSpan> _spansForBlock(DocBlock block, ThemeData theme) {
    TextStyle blockStyle;
    switch (block.type) {
      case DocBlockType.heading:
        switch (block.level) {
          case 1:
            blockStyle = theme.textTheme.headlineMedium ??
                const TextStyle(fontSize: 24, fontWeight: FontWeight.bold);
          case 2:
            blockStyle = theme.textTheme.headlineSmall ??
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
          case 3:
            blockStyle = theme.textTheme.titleLarge ??
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
          default:
            blockStyle = theme.textTheme.titleLarge ??
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
        }
        blockStyle = blockStyle.copyWith(height: 1.6);
      case DocBlockType.listItem:
        blockStyle = theme.textTheme.bodyLarge?.copyWith(
              height: 1.6,
              fontSize: 16,
            ) ??
            const TextStyle(fontSize: 16, height: 1.6);
      case DocBlockType.paragraph:
        blockStyle = theme.textTheme.bodyLarge?.copyWith(
              height: 1.8,
              fontSize: 16,
            ) ??
            const TextStyle(fontSize: 16, height: 1.8);
    }

    final spans = <TextSpan>[];
    if (block.type == DocBlockType.listItem) {
      spans.add(TextSpan(text: '  \u2022  ', style: blockStyle));
    }

    for (final run in block.runs) {
      var runStyle = blockStyle;
      if (run.bold) {
        runStyle = runStyle.copyWith(fontWeight: FontWeight.w700);
      }
      if (run.italic) {
        runStyle = runStyle.copyWith(fontStyle: FontStyle.italic);
      }
      if (run.underline) {
        runStyle = runStyle.copyWith(decoration: TextDecoration.underline);
      }
      if (run.fontSize != null) {
        runStyle = runStyle.copyWith(fontSize: run.fontSize);
      }
      spans.add(TextSpan(text: run.text, style: runStyle));
    }
    return spans;
  }
}
