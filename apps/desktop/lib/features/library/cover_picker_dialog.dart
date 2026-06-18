import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/psitta_tokens.dart';
import '../../data/models/cover_illustration.dart';

/// Result from the cover picker dialog.
sealed class CoverPickerResult {}

class CoverPickerBuiltin extends CoverPickerResult {
  CoverPickerBuiltin(this.illustrationId);
  final String illustrationId;
}

class CoverPickerUpload extends CoverPickerResult {
  CoverPickerUpload(this.file);
  final File file;
}

class CoverPickerRemove extends CoverPickerResult {}

/// Selecting a bundled photographic cover from the Psitta Covers reservatory.
class CoverPickerStock extends CoverPickerResult {
  CoverPickerStock(this.assetPath);
  final String assetPath;
}

/// Nicer labels for known cover files. Any file not listed gets a label
/// derived from its filename (snake/kebab → Title Case). Keys are the
/// lowercased filename stem.
const Map<String, String> _kCoverLabelOverrides = {
  'writing_nook': 'Writing Nook',
  'fantasy_castle': 'Fantasy',
  'code_desk': 'Code',
  'oak_sunset': 'Sunset Oak',
  'town_square': 'Town Square',
  'reading': 'Reading',
  'romantic': 'Romance',
  'romantic2': 'Romance II',
  'children_book': "Children's",
  'epic': 'Epic',
  'epic2': 'Epic II',
  'wich': 'Witch',
};

String _coverLabelFor(String assetPath) {
  final file = assetPath.split('/').last;
  final dot = file.lastIndexOf('.');
  final stem = dot > 0 ? file.substring(0, dot) : file;
  final override = _kCoverLabelOverrides[stem.toLowerCase()];
  if (override != null) return override;
  return stem
      .split(RegExp(r'[_\-\s]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

/// The bundled photographic cover reservatory, discovered at runtime from the
/// asset bundle. Drop a JPG/PNG into assets/covers/ and it appears here on the
/// next build — no code edit needed. Optionally add a nicer label above.
Future<List<({String asset, String label})>> loadStockCovers() async {
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final keys = manifest
        .listAssets()
        .where((k) => k.startsWith('assets/covers/'))
        .where((k) {
          final l = k.toLowerCase();
          return l.endsWith('.jpg') ||
              l.endsWith('.jpeg') ||
              l.endsWith('.png');
        })
        .toList()
      ..sort();
    return [for (final k in keys) (asset: k, label: _coverLabelFor(k))];
  } catch (_) {
    return const [];
  }
}

/// Shows the cover picker dialog. Returns null if cancelled.
Future<CoverPickerResult?> showCoverPickerDialog({
  required BuildContext context,
  String? currentCoverType,
  String? currentCoverValue,
  bool showStockCovers = false,
}) {
  return showDialog<CoverPickerResult>(
    context: context,
    builder: (_) => _CoverPickerDialog(
      currentCoverType: currentCoverType,
      currentCoverValue: currentCoverValue,
      showStockCovers: showStockCovers,
    ),
  );
}

class _CoverPickerDialog extends StatefulWidget {
  const _CoverPickerDialog({
    this.currentCoverType,
    this.currentCoverValue,
    this.showStockCovers = false,
  });

  final String? currentCoverType;
  final String? currentCoverValue;
  final bool showStockCovers;

  @override
  State<_CoverPickerDialog> createState() => _CoverPickerDialogState();
}

class _CoverPickerDialogState extends State<_CoverPickerDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _selectedBuiltinId;
  String? _selectedStock;
  File? _selectedFile;

  /// Photographic covers discovered from the asset bundle (Writing Nook only).
  List<({String asset, String label})> _stockCovers = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.currentCoverType == 'builtin') {
      _selectedBuiltinId = widget.currentCoverValue;
    }
    if (widget.showStockCovers) {
      loadStockCovers().then((covers) {
        if (mounted) setState(() => _stockCovers = covers);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpeg', 'jpg', 'gif', 'png'],
    );
    if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
      final file = File(result.files.first.path!);
      final size = await file.length();
      if (size > 20 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Image is too large. Please choose an image under 20MB.')),
          );
        }
        return;
      }
      setState(() => _selectedFile = file);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = PsittaTokens.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      child: SizedBox(
        width: 500,
        height: 480,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Text(
                    'Choose Cover',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Gallery'),
                Tab(text: 'Upload'),
              ],
              labelStyle: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              indicatorColor: tokens.glow,
              labelColor: tokens.glow,
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGalleryTab(theme, tokens, isDark),
                  _buildUploadTab(theme, tokens, isDark),
                ],
              ),
            ),

            // Bottom actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  // Remove cover option
                  if (widget.currentCoverType != null)
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pop(CoverPickerRemove()),
                      child: Text(
                        'Remove Cover',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _canConfirm ? _onConfirm : null,
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canConfirm {
    if (_tabController.index == 0) {
      return _selectedStock != null || _selectedBuiltinId != null;
    }
    if (_tabController.index == 1) return _selectedFile != null;
    return false;
  }

  void _onConfirm() {
    if (_tabController.index == 0) {
      if (_selectedStock != null) {
        Navigator.of(context).pop(CoverPickerStock(_selectedStock!));
      } else if (_selectedBuiltinId != null) {
        Navigator.of(context).pop(CoverPickerBuiltin(_selectedBuiltinId!));
      }
    } else if (_tabController.index == 1 && _selectedFile != null) {
      Navigator.of(context).pop(CoverPickerUpload(_selectedFile!));
    }
  }

  Widget _buildGalleryTab(
      ThemeData theme, PsittaTokens tokens, bool isDark) {
    final categories = CoverIllustration.byCategory;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Psitta Covers (photographic reservatory) — Writing Nook only ──
        if (widget.showStockCovers && _stockCovers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              'Psitta Covers',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in _stockCovers)
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedStock = c.asset;
                    _selectedBuiltinId = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 104,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedStock == c.asset
                            ? tokens.glow
                            : tokens.border.withOpacity(isDark ? 0.30 : 0.40),
                        width: _selectedStock == c.asset ? 2.5 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.asset(c.asset, fit: BoxFit.cover),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        for (final entry in categories.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              entry.key,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: entry.value.map((ill) {
              final isSelected = _selectedBuiltinId == ill.id;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedBuiltinId = ill.id;
                  _selectedStock = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 80,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? tokens.glow
                          : tokens.border.withOpacity(isDark ? 0.30 : 0.40),
                      width: isSelected ? 2.5 : 1,
                    ),
                    color: isDark
                        ? tokens.surface.withOpacity(0.50)
                        : tokens.surface2.withOpacity(0.60),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: SvgPicture.asset(
                        ill.assetPath,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildUploadTab(
      ThemeData theme, PsittaTokens tokens, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _pickFile,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(tokens.radius - 4),
                  border: Border.all(
                    color: _selectedFile != null
                        ? tokens.glow.withOpacity(0.6)
                        : tokens.border.withOpacity(isDark ? 0.30 : 0.45),
                    width: _selectedFile != null ? 2 : 1,
                    // ignore: deprecated_member_use
                    style: _selectedFile != null
                        ? BorderStyle.solid
                        : BorderStyle.solid,
                  ),
                  color: isDark
                      ? tokens.surface.withOpacity(0.30)
                      : tokens.surface2.withOpacity(0.50),
                ),
                child: _selectedFile != null
                    ? ClipRRect(
                        borderRadius:
                            BorderRadius.circular(tokens.radius - 5),
                        child: Image.file(
                          _selectedFile!,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              size: 48,
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.35),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Upload an image',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.55),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'JPEG, PNG, or GIF · up to 20 MB · saved as a '
                              'crisp 1600px cover',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.40),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Images are resized to fit 400\u00d7400px',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.40),
              fontSize: 11,
            ),
          ),
          if (_selectedFile != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: const Text('Choose different image'),
            ),
          ],
        ],
      ),
    );
  }
}
