import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfPlayerNavigator extends StatelessWidget {
  const PdfPlayerNavigator({
    super.key,
    required this.controller,
    this.documentRef,
    this.outline,
    this.onOutlineSelected,
    this.onThumbnailSelected,
  });

  final PdfViewerController controller;
  final PdfDocumentRef? documentRef;
  final List<PdfOutlineNode>? outline;
  final void Function(PdfOutlineNode node)? onOutlineSelected;
  final void Function(int pageNumber)? onThumbnailSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: theme.colorScheme.surfaceContainerLow,
            child: TabBar(
              tabs: const [
                Tab(icon: Icon(Icons.menu_book_outlined), text: 'Contents'),
                Tab(icon: Icon(Icons.grid_view_rounded), text: 'Thumbnails'),
              ],
              labelStyle: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _PdfOutlineView(
                  outline: outline,
                  controller: controller,
                  isLoading: documentRef == null || outline == null,
                  onOutlineSelected: onOutlineSelected,
                ),
                _PdfThumbnailView(
                  documentRef: documentRef,
                  controller: controller,
                  onThumbnailSelected: onThumbnailSelected,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PdfOutlineView extends StatefulWidget {
  const _PdfOutlineView({
    required this.outline,
    required this.controller,
    required this.isLoading,
    this.onOutlineSelected,
  });

  final List<PdfOutlineNode>? outline;
  final PdfViewerController controller;
  final bool isLoading;
  final void Function(PdfOutlineNode node)? onOutlineSelected;

  @override
  State<_PdfOutlineView> createState() => _PdfOutlineViewState();
}

class _PdfOutlineViewState extends State<_PdfOutlineView> {
  late final ScrollController _scrollController;

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flatOutline = _flattenOutline(widget.outline, 0).toList();

    if (widget.isLoading) {
      return const _PdfNavigatorMessage(
        icon: Icons.menu_book_outlined,
        title: 'Loading contents',
        subtitle: 'Reading PDF bookmarks and outline data.',
        showSpinner: true,
      );
    }

    if (flatOutline.isEmpty) {
      return const _PdfNavigatorMessage(
        icon: Icons.menu_book_outlined,
        title: 'No table of contents',
        subtitle: 'This PDF does not expose bookmark or outline entries.',
      );
    }

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: flatOutline.length,
        itemBuilder: (context, index) {
          final item = flatOutline[index];
          final canNavigate = item.node.dest != null;
          final indent = (item.level * 14.0).clamp(0.0, 42.0);

          return InkWell(
            onTap: canNavigate
                ? () {
                    widget.onOutlineSelected?.call(item.node);
                    if (widget.onOutlineSelected == null) {
                      widget.controller.goToDest(item.node.dest);
                    }
                  }
                : null,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16 + indent, 10, 16, 10),
              child: Text(
                item.node.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight:
                      item.level == 0 ? FontWeight.w600 : FontWeight.w400,
                  color: canNavigate
                      ? null
                      : theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      ),
    );
  }

  Iterable<({PdfOutlineNode node, int level})> _flattenOutline(
    List<PdfOutlineNode>? nodes,
    int level,
  ) sync* {
    if (nodes == null) return;
    for (final node in nodes) {
      yield (node: node, level: level);
      yield* _flattenOutline(node.children, level + 1);
    }
  }
}

class _PdfThumbnailView extends StatefulWidget {
  const _PdfThumbnailView({
    required this.documentRef,
    required this.controller,
    this.onThumbnailSelected,
  });

  final PdfDocumentRef? documentRef;
  final PdfViewerController controller;
  final void Function(int pageNumber)? onThumbnailSelected;

  @override
  State<_PdfThumbnailView> createState() => _PdfThumbnailViewState();
}

class _PdfThumbnailViewState extends State<_PdfThumbnailView> {
  bool _loggedThumbnailsReady = false;
  bool _loggedFirstThumbnail = false;
  late final ScrollController _scrollController;
  final Map<int, GlobalKey> _thumbnailKeys = {};
  int? _lastScrolledPage;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  void _logPdfPerf(String stage, String message) {
    debugPrint('[PDF PERF][$stage] $message');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.documentRef == null) {
      return const _PdfNavigatorMessage(
        icon: Icons.grid_view_rounded,
        title: 'Loading thumbnails',
        subtitle: 'Preparing page previews for quick navigation.',
        showSpinner: true,
      );
    }

    return PdfDocumentViewBuilder(
      documentRef: widget.documentRef!,
      builder: (context, document) {
        if (document == null) {
          return const _PdfNavigatorMessage(
            icon: Icons.grid_view_rounded,
            title: 'Loading thumbnails',
            subtitle: 'Preparing page previews for quick navigation.',
            showSpinner: true,
          );
        }

        if (!_loggedThumbnailsReady) {
          _loggedThumbnailsReady = true;
          _logPdfPerf(
            'open',
            'thumbnails_ready pages=${document.pages.length}',
          );
        }

        return AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final currentPage = widget.controller.pageNumber ?? 1;
            if (currentPage != _lastScrolledPage) {
              _lastScrolledPage = currentPage;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final ctx = _thumbnailKeys[currentPage]?.currentContext;
                if (ctx != null) {
                  Scrollable.ensureVisible(
                    ctx,
                    alignment: 0.3,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                  );
                }
              });
            }
            return Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                itemCount: document.pages.length,
                itemBuilder: (context, index) {
                  final pageNumber = index + 1;
                  final isActive = currentPage == pageNumber;
                  if (!_loggedFirstThumbnail && index == 0) {
                    _loggedFirstThumbnail = true;
                    _logPdfPerf(
                      'open',
                      'first_thumbnail_widget_ready page=$pageNumber',
                    );
                  }

                  return Padding(
                    key: _thumbnailKeys.putIfAbsent(pageNumber, () => GlobalKey()),
                    padding: const EdgeInsets.only(bottom: 14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        widget.onThumbnailSelected?.call(pageNumber);
                        if (widget.onThumbnailSelected == null) {
                          widget.controller.goToPage(
                            pageNumber: pageNumber,
                            anchor: PdfPageAnchor.top,
                          );
                        }
                      },
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
                                  child: PdfPageView(
                                    document: document,
                                    pageNumber: pageNumber,
                                    alignment: Alignment.center,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Page $pageNumber',
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
          },
        );
      },
    );
  }
}

class _PdfNavigatorMessage extends StatelessWidget {
  const _PdfNavigatorMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.showSpinner = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool showSpinner;

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
            if (showSpinner) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
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
