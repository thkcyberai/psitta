import 'package:flutter/material.dart';

import '../../../core/theme/psitta_tokens.dart';
import '../../../data/models/psitta_document.dart';
import '../../../data/services/audio_service.dart';
import 'docx_page_layout.dart';
import 'document_reading_view.dart';

/// Structured DOCX document viewport for the Player.
///
/// This keeps Psitta chrome and theme around the outside while rendering the
/// assembled DOCX content on a centered white document sheet.
class DocxDocumentViewport extends StatelessWidget {
  const DocxDocumentViewport({
    super.key,
    required this.document,
    required this.pages,
    required this.activeChunkIndex,
    required this.alignmentPayload,
    this.focusedSentenceIndex,
    this.isFetchingAlignment = false,
    this.onActiveSentenceChanged,
    this.onActiveWordChanged,
    this.onSentenceTap,
    this.audioService,
    this.editorChild,
    this.leadingBlocks,
    this.trailingBlocks,
    this.blockKeys,
    this.pageKeys,
  });

  final PsittaDocument document;
  final List<DocxPageLayoutPage> pages;
  final int activeChunkIndex;
  final Map<String, dynamic> alignmentPayload;
  final int? focusedSentenceIndex;
  final bool isFetchingAlignment;
  final void Function(GlobalKey blockKey)? onActiveSentenceChanged;
  final void Function(int wordIndex, int totalWords)? onActiveWordChanged;
  final void Function(int docOffset)? onSentenceTap;
  final AudioService? audioService;
  final Widget? editorChild;
  final List<DocBlock>? leadingBlocks;
  final List<DocBlock>? trailingBlocks;
  final Map<String, GlobalKey>? blockKeys;
  final Map<int, GlobalKey>? pageKeys;

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
        child: Theme(
          data: buildDocxDocumentTheme(theme),
          child: Column(
            children: [
              if (isFetchingAlignment && !hasAlignment)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: theme.colorScheme.primary.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Loading word highlighting...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary.withOpacity(0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              if (editorChild != null)
                _buildDocumentWideEditor()
              else
                Column(
                  children: [
                    for (final page in pages) ...[
                      _DocxPageSheet(
                        key: pageKeys?[page.pageNumber],
                        page: page,
                        document: document,
                        activeChunkIndex: activeChunkIndex,
                        alignmentPayload: alignmentPayload,
                        focusedSentenceIndex: focusedSentenceIndex,
                        onActiveSentenceChanged: onActiveSentenceChanged,
                        onActiveWordChanged: onActiveWordChanged,
                        onSentenceTap: onSentenceTap,
                        audioService: audioService,
                        blockKeys: blockKeys,
                      ),
                      const SizedBox(height: 28),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentWideEditor() {
    return _DocxSheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingBlocks != null && leadingBlocks!.isNotEmpty)
            _DocxStaticBlocksView(blocks: leadingBlocks!),
          if (leadingBlocks != null && leadingBlocks!.isNotEmpty)
            const SizedBox(height: 28),
          editorChild!,
          if (trailingBlocks != null && trailingBlocks!.isNotEmpty)
            const SizedBox(height: 28),
          if (trailingBlocks != null && trailingBlocks!.isNotEmpty)
            _DocxStaticBlocksView(blocks: trailingBlocks!),
        ],
      ),
    );
  }
}

class _DocxPageSheet extends StatelessWidget {
  const _DocxPageSheet({
    super.key,
    required this.page,
    required this.document,
    required this.activeChunkIndex,
    required this.alignmentPayload,
    this.focusedSentenceIndex,
    this.onActiveSentenceChanged,
    this.onActiveWordChanged,
    this.onSentenceTap,
    this.audioService,
    this.blockKeys,
  });

  final DocxPageLayoutPage page;
  final PsittaDocument document;
  final int activeChunkIndex;
  final Map<String, dynamic> alignmentPayload;
  final int? focusedSentenceIndex;
  final void Function(GlobalKey blockKey)? onActiveSentenceChanged;
  final void Function(int wordIndex, int totalWords)? onActiveWordChanged;
  final void Function(int docOffset)? onSentenceTap;
  final AudioService? audioService;
  final Map<String, GlobalKey>? blockKeys;

  @override
  Widget build(BuildContext context) {
    return _DocxSheetFrame(
      child: SizedBox(
        height: kDocxPageContentHeight,
        child: ClipRect(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
            ),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Align(
                alignment: Alignment.topLeft,
                child: DocumentReadingView(
                  document: document,
                  visibleBlocks: page.blocks,
                  activeChunkIndex: activeChunkIndex,
                  alignmentPayload: alignmentPayload,
                  focusedSentenceIndex: focusedSentenceIndex,
                  onActiveSentenceChanged: onActiveSentenceChanged,
                  onActiveWordChanged: onActiveWordChanged,
                  onSentenceTap: onSentenceTap,
                  audioService: audioService,
                  enableContextMenu: true,
                  enablePointerSentenceSelection: true,
                  blockKeys: blockKeys,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DocxSheetFrame extends StatelessWidget {
  const _DocxSheetFrame({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kDocxPageWidth),
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
        child: Padding(
          padding: kDocxPagePadding,
          child: child,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks)
          Padding(
            padding: EdgeInsets.only(bottom: docxBlockSpacing(block)),
            child: SelectableText.rich(
              TextSpan(
                children: docxSpansForBlock(block, Theme.of(context)),
              ),
            ),
          ),
      ],
    );
  }
}
