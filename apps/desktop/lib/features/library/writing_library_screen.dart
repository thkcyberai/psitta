import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../core/constants.dart';
import '../../core/plan_gate.dart';
import '../../core/quota_gate.dart';
import '../../core/theme/psitta_tokens.dart';
import '../../data/models/document.dart';
import '../../data/providers/providers.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/services/pdf_text_extractor.dart';
import '../../widgets/document_cover.dart';
import 'cover_picker_dialog.dart';
import 'library_screen.dart' show LibraryScreen, librarySearchFocusProvider;

/// Route selector for `/library`.
///
/// The Writing Nook tier gets the remodeled [WritingLibraryScreen]; every other
/// tier (notably the Reading Nook) keeps the original [LibraryScreen] untouched.
class LibraryRoute extends ConsumerWidget {
  const LibraryRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWriting =
        ref.watch(planStatusProvider).plan == 'writing_nook_pro';
    return isWriting ? const WritingLibraryScreen() : const LibraryScreen();
  }
}

enum _LibView { grid, list }

/// Type filter chips. The category→sourceType mapping is pragmatic until a real
/// document-type/category field lands (Phase 2).
const List<String> _kTypeChips = [
  'All',
  'Documents',
  'Notes',
  'PDFs',
  'Spreadsheets',
  'Books',
  'Other',
];

/// Remodeled Writing Nook Library.
class WritingLibraryScreen extends ConsumerStatefulWidget {
  const WritingLibraryScreen({super.key});

  @override
  ConsumerState<WritingLibraryScreen> createState() =>
      _WritingLibraryScreenState();
}

class _WritingLibraryScreenState extends ConsumerState<WritingLibraryScreen> {
  bool _isDragging = false;
  bool _isUploading = false;
  String _search = '';
  String _typeFilter = 'All';
  String _sort = 'Last edited';
  _LibView _view = _LibView.grid;
  String? _selectedDocId;

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Upload (mirrors LibraryScreen behaviour) ────────────────────────────────
  Future<bool> _canAcceptUploads(int incoming) async {
    final plan = ref.read(planStatusProvider);
    final limit = monthlyDocLimitFor(plan);
    final docs = ref.read(documentsProvider).valueOrNull ?? const [];
    final used = countDocumentsThisMonth(docs);
    if (used + incoming <= limit) return true;
    if (!mounted) return false;
    await showUploadLimitPrompt(context, limit: limit, used: used);
    return false;
  }

  Future<void> _handleFilePick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.allowedExtensions,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      await _uploadFiles(result.files);
    }
  }

  Future<void> _uploadFiles(List<PlatformFile> files) async {
    final cachedQuota = ref.read(quotaUsageProvider).valueOrNull;
    if (cachedQuota != null && cachedQuota.atLimit) {
      if (!mounted) return;
      await showQuotaDialog(context, cachedQuota);
      return;
    }
    if (!await _canAcceptUploads(files.length)) return;
    setState(() => _isUploading = true);
    final repo = ref.read(documentRepositoryProvider);
    var shownQuotaDialog = false;
    for (final file in files) {
      if (file.path == null) continue;
      try {
        if (p.extension(file.path!).toLowerCase() == '.pdf') {
          final pageTexts =
              await PdfTextExtractor.extractPageTexts(file.path!);
          await repo.uploadDocument(
            file.path!,
            pageTexts: pageTexts.isNotEmpty ? pageTexts : null,
          );
        } else {
          await repo.uploadDocument(file.path!);
        }
      } on DioException catch (e) {
        if (!mounted) return;
        if (e.response?.statusCode == 402) {
          if (!shownQuotaDialog) {
            shownQuotaDialog = true;
            final data = e.response?.data;
            final detail = data is Map ? data['detail'] : null;
            final info = QuotaInfo.from402Detail(
              detail,
              fallbackPlan: cachedQuota?.plan ?? 'free',
            );
            ref.invalidate(quotaUsageProvider);
            await showQuotaDialog(context, info);
          }
          break;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${file.name}')),
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: ${file.name}')),
          );
        }
      }
    }
    if (mounted) setState(() => _isUploading = false);
    ref.invalidate(documentsProvider);
    ref.invalidate(quotaUsageProvider);
  }

  void _handleDrop(DropDoneDetails details) {
    setState(() => _isDragging = false);
    final files = details.files
        .where((f) {
          final ext = f.name.split('.').last.toLowerCase();
          return AppConstants.allowedExtensions.contains(ext);
        })
        .map((f) => PlatformFile(name: f.name, size: 0, path: f.path))
        .toList();
    if (files.isNotEmpty) _uploadFiles(files);
  }

  Future<void> _newBlank() async {
    final cachedQuota = ref.read(quotaUsageProvider).valueOrNull;
    if (cachedQuota != null && cachedQuota.atLimit) {
      await showQuotaDialog(context, cachedQuota);
      return;
    }
    try {
      final repo = ref.read(documentRepositoryProvider);
      final result = await repo.createBlankDocument();
      final docId = result['id']!;
      ref.invalidate(documentsProvider);
      ref.invalidate(quotaUsageProvider);
      if (mounted) context.go('/writing-desk/$docId');
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 402) {
        final data = e.response?.data;
        final detail = data is Map ? data['detail'] : null;
        final info = QuotaInfo.from402Detail(detail,
            fallbackPlan: cachedQuota?.plan ?? 'free');
        ref.invalidate(quotaUsageProvider);
        await showQuotaDialog(context, info);
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to create: $e')));
    }
  }

  void _openDoc(Document doc) => context.go('/writing-desk/${doc.id}');

  void _soon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — coming soon')),
    );
  }

  // ── Filtering / sorting ─────────────────────────────────────────────────────
  bool _matchesType(Document d) {
    final t = d.sourceType.toLowerCase();
    switch (_typeFilter) {
      case 'All':
        return true;
      case 'Documents':
        return t == 'docx';
      case 'Notes':
        return t == 'md' || t == 'txt';
      case 'PDFs':
        return t == 'pdf';
      case 'Spreadsheets':
        return t == 'xlsx' || t == 'xls' || t == 'csv';
      case 'Books':
        return t == 'epub' || d.projectId != null;
      case 'Other':
        return !['docx', 'md', 'txt', 'pdf', 'xlsx', 'xls', 'csv', 'epub']
            .contains(t);
      default:
        return true;
    }
  }

  List<Document> _visible(List<Document> docs) {
    final q = _search.trim().toLowerCase();
    var list = docs
        .where((d) => d.status != 'archived')
        .where(_matchesType)
        .where((d) => q.isEmpty || d.title.toLowerCase().contains(q))
        .toList();
    switch (_sort) {
      case 'Name':
        list.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      default: // 'Last edited' / 'Date added' — createdAt proxy until updatedAt lands
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  String _projectName(String? projectId, List<Project> projects) {
    if (projectId == null) return 'My Writing Nook';
    for (final pr in projects) {
      if (pr.id == projectId) return pr.name;
    }
    return 'Project';
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    final local = d.toLocal();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      final hh = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final mm = local.minute.toString().padLeft(2, '0');
      final ap = local.hour < 12 ? 'AM' : 'PM';
      return 'Today, $hh:$mm $ap';
    }
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  int _thisWeek(List<Document> docs) {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 7));
    return docs.where((d) => d.createdAt.isAfter(cutoff)).length;
  }

  Color _typeColor(String sourceType, PsittaTokens tokens) {
    switch (sourceType.toLowerCase()) {
      case 'pdf':
        return const Color(0xFFE5534B);
      case 'docx':
        return const Color(0xFF4F8DF5);
      case 'md':
        return const Color(0xFF34C77B);
      case 'txt':
        return const Color(0xFF7C8BA1);
      case 'xlsx':
      case 'xls':
      case 'csv':
        return const Color(0xFF1FA97E);
      case 'epub':
        return const Color(0xFF8A7CFF);
      default:
        return tokens.glow;
    }
  }

  IconData _typeIcon(String sourceType) {
    final t = sourceType.toLowerCase();
    if (t.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (t.contains('docx')) return Icons.article_outlined;
    if (t.contains('md')) return Icons.code;
    if (t.contains('txt')) return Icons.text_snippet_outlined;
    if (t.contains('xls') || t.contains('csv')) return Icons.table_chart_outlined;
    if (t.contains('html')) return Icons.language;
    if (t.contains('epub')) return Icons.menu_book_outlined;
    return Icons.description_outlined;
  }

  /// Colored fallback banner shown when a document has no cover set — gives the
  /// grid the mockup's "cover banner" feel until real cover images exist.
  Widget _typeBanner(Document doc, PsittaTokens tokens) {
    final color = _typeColor(doc.sourceType, tokens);
    return Container(
      height: 132,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.32),
            color.withOpacity(0.12),
            tokens.surface2.withOpacity(0.55),
          ],
        ),
      ),
      child: Center(
        child: Icon(_typeIcon(doc.sourceType),
            size: 38, color: color.withOpacity(0.9)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PsittaTokens.of(context);
    final docsAsync = ref.watch(documentsProvider);
    final projects = ref.watch(projectsProvider).valueOrNull ?? const [];

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: _handleDrop,
      child: Container(
        decoration: BoxDecoration(gradient: tokens.backgroundGradient),
        child: LayoutBuilder(
          builder: (context, c) {
            // Hide the right rail when the window is too narrow to host both it
            // and a usable content area — keeps the layout from overflowing.
            final showRail = c.maxWidth >= 920;
            final main = docsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load: $e')),
              data: (docs) => _buildMain(context, tokens, docs, projects),
            );
            if (!showRail) return main;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: main),
                _RightRail(
                  tokens: tokens,
                  isPro: ref.watch(planStatusProvider).isPro,
                  docCount: docsAsync.valueOrNull?.length ?? 0,
                  projects: projects,
                  onProjects: () => context.go('/projects'),
                  onSoon: _soon,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMain(BuildContext context, PsittaTokens tokens,
      List<Document> docs, List<Project> projects) {
    final visible = _visible(docs);
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(28, 24, 20, 28),
          children: [
            _header(context, tokens),
            const SizedBox(height: 20),
            _statRow(tokens, docs),
            const SizedBox(height: 18),
            _filterRow(tokens),
            const SizedBox(height: 16),
            if (visible.isEmpty)
              _emptyState(tokens)
            else if (_view == _LibView.grid)
              _grid(visible, projects)
            else
              _list(visible, projects),
            const SizedBox(height: 20),
            _uploadZone(tokens),
          ],
        ),
        if (_isDragging)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: tokens.glow.withOpacity(0.10),
                child: Center(
                  child: Text('Drop files to upload',
                      style: TextStyle(
                          color: tokens.glow,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        if (_isUploading)
          const Positioned(
            top: 12,
            right: 12,
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ],
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _header(BuildContext context, PsittaTokens tokens) {
    final scheme = Theme.of(context).colorScheme;

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_library_outlined, color: tokens.glow, size: 26),
            const SizedBox(width: 10),
            Flexible(
              child: Text('Library',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'All your documents, notes, and writing resources in one place.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
      ],
    );

    final filters = _ghostButton(
      tokens,
      icon: Icons.tune,
      label: 'Filters',
      onTap: () => _filtersMenu(context),
    );
    final newDoc = FilledButton(
      onPressed: _newDocMenu,
      style: FilledButton.styleFrom(
        backgroundColor: tokens.glow,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 16),
          SizedBox(width: 6),
          Text('New File', style: TextStyle(fontSize: 12)),
          SizedBox(width: 2),
          Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        // Stack controls under the title when there isn't room for them on one
        // line — prevents the title from being squeezed and the row overflowing.
        if (c.maxWidth < 860) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _searchField(tokens)),
                  const SizedBox(width: 10),
                  filters,
                  const SizedBox(width: 10),
                  newDoc,
                ],
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            SizedBox(width: 280, child: _searchField(tokens)),
            const SizedBox(width: 10),
            filters,
            const SizedBox(width: 10),
            newDoc,
          ],
        );
      },
    );
  }

  Widget _searchField(PsittaTokens tokens) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _searchController,
      focusNode: ref.read(librarySearchFocusProvider),
      onChanged: (v) => setState(() => _search = v),
      style: TextStyle(fontSize: 13, color: scheme.onSurface),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search documents, folders, or tags...',
        hintStyle:
            TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        prefixIcon: Icon(Icons.search, size: 18, color: scheme.onSurfaceVariant),
        filled: true,
        fillColor: tokens.inputFill,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.border),
        ),
      ),
    );
  }

  void _filtersMenu(BuildContext context) {
    final showArchived = ref.read(showArchivedProvider);
    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(600, 110, 40, 0),
      items: [
        CheckedPopupMenuItem<String>(
          value: 'archived',
          checked: showArchived,
          child: const Text('Show archived'),
        ),
      ],
    ).then((v) {
      if (v == 'archived') {
        ref.read(showArchivedProvider.notifier).state = !showArchived;
      }
    });
  }

  void _newDocMenu() {
    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 110, 24, 0),
      items: const [
        PopupMenuItem(value: 'blank', child: Text('New blank file (DOCX)')),
        PopupMenuItem(value: 'upload', child: Text('Upload from device')),
      ],
    ).then((v) {
      if (v == 'blank') _newBlank();
      if (v == 'upload') _handleFilePick();
    });
  }

  // ── Stat cards ──────────────────────────────────────────────────────────────
  Widget _statRow(PsittaTokens tokens, List<Document> docs) {
    final week = _thisWeek(docs);
    final cards = <Widget>[
      _StatCard(
        tokens: tokens,
        icon: Icons.description_outlined,
        value: '${docs.where((d) => d.status != 'archived').length}',
        label: 'Documents',
        sub: week > 0 ? '+$week this week' : null,
        accent: tokens.glow,
      ),
      _StatCard(
        tokens: tokens,
        icon: Icons.folder_outlined,
        value: '—',
        label: 'Folders',
        sub: 'Coming soon',
        accent: const Color(0xFF4F8DF5),
        onTap: () => _soon('Folders'),
      ),
      _StatCard(
        tokens: tokens,
        icon: Icons.dashboard_customize_outlined,
        value: '—',
        label: 'Templates',
        sub: 'Coming soon',
        accent: const Color(0xFF34C77B),
        onTap: () => _soon('Templates'),
      ),
      _StatCard(
        tokens: tokens,
        icon: Icons.delete_outline,
        value: '—',
        label: 'Trash',
        sub: 'Coming soon',
        accent: const Color(0xFFE0A03A),
        onTap: () => _soon('Trash'),
      ),
      _StatCard(
        tokens: tokens,
        icon: Icons.cloud_outlined,
        value: '—',
        label: 'Storage',
        sub: 'Coming soon',
        accent: const Color(0xFF8A7CFF),
        onTap: () => _soon('Storage'),
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 12.0;
        final perRow = c.maxWidth >= 980
            ? 5
            : c.maxWidth >= 720
                ? 3
                : c.maxWidth >= 460
                    ? 2
                    : 1;
        final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards) SizedBox(width: w, child: card),
          ],
        );
      },
    );
  }

  // ── Filter chips + sort + view toggle ───────────────────────────────────────
  Widget _filterRow(PsittaTokens tokens) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _kTypeChips)
                _Chip(
                  tokens: tokens,
                  label: c,
                  selected: _typeFilter == c,
                  onTap: () => setState(() => _typeFilter = c),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text('Sort by',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(width: 8),
        _sortDropdown(tokens),
        const SizedBox(width: 12),
        _viewToggle(tokens),
      ],
    );
  }

  Widget _sortDropdown(PsittaTokens tokens) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.inputFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sort,
          isDense: true,
          dropdownColor: tokens.surface,
          style: TextStyle(fontSize: 12, color: scheme.onSurface),
          items: const [
            DropdownMenuItem(value: 'Last edited', child: Text('Last edited')),
            DropdownMenuItem(value: 'Name', child: Text('Name')),
            DropdownMenuItem(value: 'Date added', child: Text('Date added')),
          ],
          onChanged: (v) => setState(() => _sort = v ?? 'Last edited'),
        ),
      ),
    );
  }

  Widget _viewToggle(PsittaTokens tokens) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.inputFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          _viewButton(tokens, Icons.grid_view_rounded, _LibView.grid),
          _viewButton(tokens, Icons.view_list_rounded, _LibView.list),
        ],
      ),
    );
  }

  Widget _viewButton(PsittaTokens tokens, IconData icon, _LibView v) {
    final selected = _view == v;
    return InkWell(
      onTap: () => setState(() => _view = v),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? tokens.glow.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon,
            size: 18,
            color: selected
                ? tokens.glow
                : Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  // ── Grid / list ─────────────────────────────────────────────────────────────
  Widget _grid(List<Document> docs, List<Project> projects) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1100
            ? 4
            : c.maxWidth >= 820
                ? 3
                : c.maxWidth >= 560
                    ? 2
                    : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: 210,
          ),
          itemCount: docs.length,
          itemBuilder: (_, i) => _gridCard(docs[i], projects),
        );
      },
    );
  }

  Widget _gridCard(Document doc, List<Project> projects) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final selected = _selectedDocId == doc.id;
    return InkWell(
      onTap: () => _openDoc(doc),
      borderRadius: BorderRadius.circular(tokens.radius - 2),
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(tokens.radius - 2),
          border: Border.all(
            color: selected ? tokens.glow : tokens.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(tokens.radius - 2)),
                  child: doc.coverType != null
                      ? DocumentCover(
                          coverType: doc.coverType,
                          coverValue: doc.coverValue,
                          documentId: doc.id,
                          sourceType: doc.sourceType,
                          size: DocumentCoverSize.card,
                          height: 132,
                          borderRadius: BorderRadius.zero,
                        )
                      : _typeBanner(doc, tokens),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(doc.sourceType.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: _cardMenuButton(doc,
                      iconColor: Colors.white, iconSize: 16),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface)),
                  const SizedBox(height: 3),
                  Text(_projectName(doc.projectId, projects),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(_fmtDate(doc.createdAt),
                      style: TextStyle(
                          fontSize: 10.5,
                          color: scheme.onSurfaceVariant.withOpacity(0.8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<Document> docs, List<Project> projects) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final doc in docs)
          InkWell(
            onTap: () => _openDoc(doc),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _selectedDocId == doc.id
                        ? tokens.glow
                        : tokens.border),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: DocumentCover(
                      coverType: doc.coverType,
                      coverValue: doc.coverValue,
                      documentId: doc.id,
                      sourceType: doc.sourceType,
                      size: DocumentCoverSize.mini,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface)),
                        Text(_projectName(doc.projectId, projects),
                            style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Text(doc.sourceType.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant)),
                  const SizedBox(width: 12),
                  Text(_fmtDate(doc.createdAt),
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant)),
                  _cardMenuButton(doc,
                      iconColor: scheme.onSurfaceVariant, iconSize: 18),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// ⋯ menu anchored to its own button (PopupMenuButton positions itself, so
  /// the menu opens next to the icon instead of at a fixed screen point).
  Widget _cardMenuButton(Document doc,
      {required Color iconColor, double iconSize = 16}) {
    final tokens = PsittaTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: '',
      padding: EdgeInsets.zero,
      iconSize: iconSize,
      icon: Icon(Icons.more_horiz, color: iconColor),
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: tokens.border),
      ),
      itemBuilder: (_) => [
        _menuItem('read', Icons.headphones_outlined, 'Read', scheme),
        _menuItem('rename', Icons.drive_file_rename_outline, 'Rename', scheme),
        _menuItem('cover', Icons.image_outlined, 'Change cover', scheme),
        _menuItem('project', Icons.folder_outlined, 'Add to Project', scheme),
        _menuItem('download', Icons.download_outlined, 'Download', scheme),
        _menuItem('details', Icons.info_outline, 'Details', scheme),
        const PopupMenuDivider(),
        _menuItem('archive', Icons.archive_outlined, 'Archive', scheme),
        _menuItem('delete', Icons.delete_outline, 'Delete', scheme,
            danger: true),
      ],
      onSelected: (v) {
        switch (v) {
          case 'read':
            _read(doc);
          case 'rename':
            _rename(doc);
          case 'cover':
            _changeCover(doc);
          case 'project':
            _addToProject(doc);
          case 'download':
            _download(doc);
          case 'details':
            _showDetails(doc);
          case 'archive':
            _archive(doc);
          case 'delete':
            _delete(doc);
        }
      },
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label, ColorScheme scheme,
      {bool danger = false}) {
    final color = danger ? const Color(0xFFE5534B) : scheme.onSurface;
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _changeCover(Document doc) async {
    final result = await showCoverPickerDialog(
      context: context,
      currentCoverType: doc.coverType,
      currentCoverValue: doc.coverValue,
      showStockCovers: true,
    );
    if (result == null || !mounted) return;
    final repo = ref.read(documentRepositoryProvider);
    try {
      switch (result) {
        case CoverPickerBuiltin(:final illustrationId):
          await repo.setCoverBuiltin(doc.id, illustrationId);
        case CoverPickerStock(:final assetPath):
          final data = await rootBundle.load(assetPath);
          await repo.uploadCoverBytes(
            doc.id,
            data.buffer.asUint8List(),
            assetPath.split('/').last,
          );
        case CoverPickerUpload(:final file):
          await repo.uploadCover(doc.id, file.path);
        case CoverPickerRemove():
          await repo.removeCover(doc.id);
      }
      // Clear Flutter's image cache so uploaded covers refresh immediately.
      PaintingBinding.instance.imageCache.clear();
      ref.invalidate(documentsProvider);
    } on DioException catch (e) {
      if (!mounted) return;
      final code = e.response?.statusCode;
      final msg = code == 413
          ? 'That image is too large. Please use an image under 20 MB.'
          : code == 415
              ? 'Unsupported image type. Use JPEG, PNG, or GIF.'
              : 'Couldn’t update the cover. Please try again.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t update the cover.')),
        );
      }
    }
  }

  // Open the document in the Writing Desk's Read/Listen mode.
  void _read(Document doc) => context.go('/writing-desk/${doc.id}?read=1');

  Future<void> _rename(Document doc) async {
    final ctrl = TextEditingController(text: doc.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Rename')),
        ],
      ),
    );
    ctrl.dispose();
    if (newTitle == null ||
        newTitle.isEmpty ||
        newTitle == doc.title ||
        !mounted) {
      return;
    }
    try {
      await ref.read(documentRepositoryProvider).renameDocument(doc.id, newTitle);
      ref.invalidate(documentsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t rename the file.')),
        );
      }
    }
  }

  Future<void> _archive(Document doc) async {
    try {
      await ref.read(documentRepositoryProvider).archiveDocument(doc.id);
      ref.invalidate(documentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document archived.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t archive the document.')),
        );
      }
    }
  }

  Future<void> _delete(Document doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text(
            '“${doc.title}” will be permanently deleted. This can’t be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE5534B)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(documentRepositoryProvider).deleteDocument(doc.id);
      ref.invalidate(documentsProvider);
      ref.invalidate(quotaUsageProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t delete the document.')),
        );
      }
    }
  }

  Future<void> _addToProject(Document doc) async {
    final projects = ref.read(projectsProvider).valueOrNull ?? const [];
    final chosen = await showDialog<String?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Add to Project'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, '__none__'),
            child: const Text('None (remove from project)'),
          ),
          for (final pr in projects)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, pr.id),
              child: Text(pr.name),
            ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    final projectId = chosen == '__none__' ? null : chosen;
    try {
      await ref
          .read(documentRepositoryProvider)
          .assignToProject(doc.id, projectId);
      ref.invalidate(documentsProvider);
      ref.invalidate(projectsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t update the project.')),
        );
      }
    }
  }

  Future<void> _download(Document doc) async {
    try {
      final bytes =
          await ref.read(documentRepositoryProvider).downloadDocument(doc.id);
      if (!mounted) return;
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save document',
        fileName: '${doc.title}.${doc.sourceType}',
      );
      if (savePath == null) return;
      await File(savePath).writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to $savePath')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t download the document.')),
        );
      }
    }
  }

  void _showDetails(Document doc) {
    final scheme = Theme.of(context).colorScheme;
    String fmt(DateTime? d) => d == null ? '—' : _fmtDate(d);
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12.5, color: scheme.onSurfaceVariant)),
              ),
              Expanded(
                child: Text(value,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface)),
              ),
            ],
          ),
        );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(doc.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              row('Type', doc.sourceType.toUpperCase()),
              row('Word count', doc.wordCount?.toString() ?? '—'),
              row('Pages', doc.pageCount?.toString() ?? '—'),
              row('First uploaded', fmt(doc.createdAt)),
              row('Last changed', fmt(doc.updatedAt)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _emptyState(PsittaTokens tokens) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.menu_book_outlined,
              size: 40, color: scheme.onSurfaceVariant.withOpacity(0.5)),
          const SizedBox(height: 10),
          Text(
            _search.isNotEmpty || _typeFilter != 'All'
                ? 'No documents match this filter.'
                : 'No documents yet — upload or create one to begin.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ── Drag & drop upload zone ─────────────────────────────────────────────────
  Widget _uploadZone(PsittaTokens tokens) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: _handleFilePick,
      borderRadius: BorderRadius.circular(tokens.radius),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radius),
          border: Border.all(
            color: _isDragging ? tokens.glow : tokens.border,
            width: _isDragging ? 1.6 : 1,
          ),
          color: _isDragging
              ? tokens.glow.withOpacity(0.06)
              : tokens.surface2.withOpacity(0.4),
        ),
        child: Column(
          children: [
            Icon(Icons.cloud_upload_outlined,
                size: 30, color: tokens.glow.withOpacity(0.8)),
            const SizedBox(height: 8),
            Text('Drag & drop files here',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface)),
            const SizedBox(height: 2),
            Text('or click to upload from your device',
                style: TextStyle(
                    fontSize: 11, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text('DOCX · PDF · EPUB · TXT · MD · HTML',
                style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  // ── Shared small buttons ────────────────────────────────────────────────────
  Widget _ghostButton(PsittaTokens tokens,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: tokens.border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

}

// ── Stat card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.tokens,
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
    this.sub,
    this.onTap,
  });

  final PsittaTokens tokens;
  final IconData icon;
  final String value;
  final String label;
  final Color accent;
  final String? sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radius - 2),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(tokens.radius - 2),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface)),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  if (sub != null)
                    Text(sub!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10,
                            color: accent.withOpacity(0.9),
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  const _Chip({
    required this.tokens,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final PsittaTokens tokens;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? tokens.glow : tokens.inputFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? tokens.glow : tokens.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : scheme.onSurfaceVariant)),
      ),
    );
  }
}

// ── Right rail ────────────────────────────────────────────────────────────────
class _RightRail extends StatelessWidget {
  const _RightRail({
    required this.tokens,
    required this.isPro,
    required this.docCount,
    required this.projects,
    required this.onProjects,
    required this.onSoon,
  });

  final PsittaTokens tokens;
  final bool isPro;
  final int docCount;
  final List<Project> projects;
  final VoidCallback onProjects;
  final void Function(String) onSoon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: tokens.surface.withOpacity(0.4),
        border: Border(left: BorderSide(color: tokens.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        children: [
          _profileCard(context, scheme),
          const SizedBox(height: 18),
          _sectionLabel('Quick Access', scheme),
          const SizedBox(height: 8),
          _quickRow(context, Icons.auto_stories_outlined, 'My Writing Nook',
              '$docCount items', null),
          _quickRow(context, Icons.folder_outlined, 'Projects',
              '${projects.length} projects', onProjects),
          _quickRow(context, Icons.dashboard_customize_outlined, 'Templates',
              'Coming soon', () => onSoon('Templates')),
          _quickRow(context, Icons.inventory_2_outlined, 'Archive',
              'Coming soon', () => onSoon('Archive')),
          const SizedBox(height: 20),
          _sectionLabel('Recent Collections', scheme),
          const SizedBox(height: 8),
          if (projects.isEmpty)
            Text('No collections yet.',
                style:
                    TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))
          else
            for (final pr in projects.take(4))
              _collectionRow(context, pr),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => onSoon('New Collection'),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Collection'),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.onSurface,
              side: BorderSide(color: tokens.border),
              minimumSize: const Size.fromHeight(38),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _profileCard(BuildContext context, ColorScheme scheme) {
    // Avatar + quote area are placeholders designed to accept a real uploaded
    // photo and a writer quote once account-photo uploads land.
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radius - 2),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: tokens.glow.withOpacity(0.18),
            child: Icon(Icons.person_outline, size: 34, color: tokens.glow),
          ),
          const SizedBox(height: 10),
          Text('Your Profile',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface)),
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: tokens.glow.withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(isPro ? 'Pro Plan' : 'Free Plan',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: tokens.glow)),
          ),
          const SizedBox(height: 10),
          Text('“Every great story starts with a single word.”',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, ColorScheme scheme) => Text(
        text.toUpperCase(),
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: scheme.onSurfaceVariant),
      );

  Widget _quickRow(BuildContext context, IconData icon, String title,
      String sub, VoidCallback? onTap) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(icon, size: 18, color: tokens.glow),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface)),
                  Text(sub,
                      style: TextStyle(
                          fontSize: 10.5,
                          color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 16, color: scheme.onSurfaceVariant.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _collectionRow(BuildContext context, Project pr) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: tokens.glow.withOpacity(0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.collections_bookmark_outlined,
                size: 16, color: tokens.glow),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pr.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface)),
                Text('${pr.documentCount} documents',
                    style: TextStyle(
                        fontSize: 10.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
