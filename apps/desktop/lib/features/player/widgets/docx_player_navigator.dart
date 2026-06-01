import 'package:flutter/material.dart';

import '../../../data/models/psitta_document.dart';
import 'docx_page_layout.dart';

@immutable
class DocxNavigatorEntry {
  const DocxNavigatorEntry({
    required this.blockId,
    required this.title,
    required this.level,
    required this.pageNumber,
  });

  final String blockId;
  final String title;
  final int level;
  final int pageNumber;
}

class DocxPlayerNavigator extends StatelessWidget {
  const DocxPlayerNavigator({
    super.key,
    required this.pages,
    required this.contents,
    required this.activePageNumber,
    this.onContentsSelected,
    this.onThumbnailSelected,
  });

  final List<DocxPageLayoutPage> pages;
  final List<DocxNavigatorEntry> contents;
  final int activePageNumber;
  final void Function(DocxNavigatorEntry entry)? onContentsSelected;
  final void Function(int pageNumber)? onThumbnailSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      initialIndex: 0, // Thumbnails is the default selected tab.
      child: Column(
        children: [
          Container(
            color: theme.colorScheme.surfaceContainerLow,
            child: TabBar(
              tabs: const [
                Tab(icon: Icon(Icons.grid_view_rounded), text: 'Thumbnails'),
                Tab(icon: Icon(Icons.menu_book_outlined), text: 'Contents'),
              ],
              labelStyle: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _DocxThumbnailView(
                  pages: pages,
                  activePageNumber: activePageNumber,
                  onSelected: onThumbnailSelected,
                ),
                _DocxContentsView(
                  entries: contents,
                  onSelected: onContentsSelected,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocxContentsView extends StatelessWidget {
  const _DocxContentsView({
    required this.entries,
    this.onSelected,
  });

  final List<DocxNavigatorEntry> entries;
  final void Function(DocxNavigatorEntry entry)? onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (entries.isEmpty) {
      return const _DocxNavigatorMessage(
        icon: Icons.menu_book_outlined,
        title: 'No table of contents',
        subtitle: 'This DOCX does not expose heading structure yet.',
      );
    }

    return Scrollbar(
      thumbVisibility: true,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final indent = ((entry.level - 1) * 14.0).clamp(0.0, 42.0);
          return InkWell(
            onTap: () => onSelected?.call(entry),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16 + indent, 10, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: entry.level <= 1
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Page ${entry.pageNumber}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DocxThumbnailView extends StatefulWidget {
  const _DocxThumbnailView({
    required this.pages,
    required this.activePageNumber,
    this.onSelected,
  });

  final List<DocxPageLayoutPage> pages;
  final int activePageNumber;
  final void Function(int pageNumber)? onSelected;

  @override
  State<_DocxThumbnailView> createState() => _DocxThumbnailViewState();
}

class _DocxThumbnailViewState extends State<_DocxThumbnailView> {
  late final ScrollController _scrollController;
  final Map<int, GlobalKey> _thumbnailKeys = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _DocxThumbnailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activePageNumber != oldWidget.activePageNumber) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _thumbnailKeys[widget.activePageNumber]?.currentContext;
        if (ctx == null) return;
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.3,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.pages.isEmpty) {
      return const _DocxNavigatorMessage(
        icon: Icons.grid_view_rounded,
        title: 'No pages yet',
        subtitle: 'DOCX pages will appear here once the document is loaded.',
      );
    }

    final docTheme = buildDocxDocumentTheme(theme);
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
        itemCount: widget.pages.length,
        itemBuilder: (context, index) {
          final page = widget.pages[index];
          final isActive = widget.activePageNumber == page.pageNumber;

          return Padding(
            key: _thumbnailKeys.putIfAbsent(page.pageNumber, () => GlobalKey()),
            padding: const EdgeInsets.only(bottom: 14),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => widget.onSelected?.call(page.pageNumber),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActive
                      ? theme.colorScheme.primary.withOpacity(0.10)
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? theme.colorScheme.primary.withOpacity(0.55)
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 156,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x16000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Theme(
                            data: docTheme,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                width: kDocxPageWidth,
                                height: kDocxPageHeight,
                                child: Padding(
                                  padding: kDocxPagePadding,
                                  child: _DocxPagePreviewBlocks(
                                    blocks: page.blocks,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Page ${page.pageNumber}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DocxPagePreviewBlocks extends StatelessWidget {
  const _DocxPagePreviewBlocks({
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
            child: Text.rich(
              TextSpan(
                children: docxSpansForBlock(block, Theme.of(context)),
              ),
              maxLines: block.type == DocBlockType.heading ? 3 : 5,
              overflow: TextOverflow.clip,
            ),
          ),
      ],
    );
  }
}

class _DocxNavigatorMessage extends StatelessWidget {
  const _DocxNavigatorMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 34,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
