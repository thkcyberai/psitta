import 'package:flutter/material.dart';

import '../../../data/models/psitta_document.dart';

const double kDocxPageWidth = 860;
const double kDocxPageHeight = 1120;
const double kDocxPageBottomReserve = 28;
const double kDocxEstimatedBlockFudge = 8;
const EdgeInsets kDocxPagePadding =
    EdgeInsets.symmetric(horizontal: 56, vertical: 52);

double get kDocxPageContentWidth =>
    kDocxPageWidth - kDocxPagePadding.horizontal;
double get kDocxPageContentHeight =>
    kDocxPageHeight - kDocxPagePadding.vertical;

ThemeData buildDocxDocumentTheme(ThemeData appTheme) {
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

TextStyle docxBlockStyle(ThemeData theme, DocBlock block) {
  switch (block.type) {
    case DocBlockType.heading:
      final style = switch (block.level) {
        1 => theme.textTheme.headlineMedium ??
            const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        2 => theme.textTheme.headlineSmall ??
            const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        _ => theme.textTheme.titleLarge ??
            const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      };
      return style.copyWith(height: 1.6);
    case DocBlockType.listItem:
      return theme.textTheme.bodyLarge?.copyWith(
            height: 1.6,
            fontSize: 16,
          ) ??
          const TextStyle(fontSize: 16, height: 1.6);
    case DocBlockType.paragraph:
      return theme.textTheme.bodyLarge?.copyWith(
            height: 1.8,
            fontSize: 16,
          ) ??
          const TextStyle(fontSize: 16, height: 1.8);
  }
}

double docxBlockSpacing(DocBlock block) =>
    block.type == DocBlockType.heading ? 16 : 8;

List<InlineSpan> docxSpansForBlock(
  DocBlock block,
  ThemeData theme, {
  bool includeListBullet = true,
}) {
  var blockStyle = docxBlockStyle(theme, block);
  final spans = <InlineSpan>[];

  if (includeListBullet && block.type == DocBlockType.listItem) {
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

@immutable
class DocxPageLayoutPage {
  const DocxPageLayoutPage({
    required this.pageNumber,
    required this.blocks,
  });

  final int pageNumber;
  final List<DocBlock> blocks;
}

List<DocxPageLayoutPage> paginateDocxDocument(
  BuildContext context,
  PsittaDocument document,
) {
  final docTheme = buildDocxDocumentTheme(Theme.of(context));
  final pages = <DocxPageLayoutPage>[];
  final currentBlocks = <DocBlock>[];
  var pageNumber = 1;
  var usedHeight = 0.0;
  final availableHeight = kDocxPageContentHeight - kDocxPageBottomReserve;

  for (final block in document.blocks) {
    final blockHeight = _estimateBlockHeight(
      block: block,
      theme: docTheme,
      maxWidth: kDocxPageContentWidth,
    );
    final spacing = docxBlockSpacing(block);
    final entryHeight = blockHeight + spacing + kDocxEstimatedBlockFudge;
    final exceedsPage = currentBlocks.isNotEmpty &&
        usedHeight + entryHeight > availableHeight;

    if (exceedsPage) {
      pages.add(DocxPageLayoutPage(
        pageNumber: pageNumber++,
        blocks: List<DocBlock>.unmodifiable(currentBlocks),
      ));
      currentBlocks.clear();
      usedHeight = 0;
    }

    currentBlocks.add(block);
    usedHeight += entryHeight;
  }

  if (currentBlocks.isNotEmpty || pages.isEmpty) {
    pages.add(DocxPageLayoutPage(
      pageNumber: pageNumber,
      blocks: List<DocBlock>.unmodifiable(currentBlocks),
    ));
  }

  return List<DocxPageLayoutPage>.unmodifiable(pages);
}

double _estimateBlockHeight({
  required DocBlock block,
  required ThemeData theme,
  required double maxWidth,
}) {
  final painter = TextPainter(
    text: TextSpan(children: docxSpansForBlock(block, theme)),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.start,
    maxLines: null,
  )..layout(maxWidth: maxWidth);

  return painter.height;
}
