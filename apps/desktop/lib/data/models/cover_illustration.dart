/// Built-in cover illustration catalog.
///
/// Each illustration is an SVG bundled in assets/illustrations/.
class CoverIllustration {
  const CoverIllustration({
    required this.id,
    required this.label,
    required this.category,
    required this.assetPath,
  });

  final String id;
  final String label;
  final String category;
  final String assetPath;

  static const List<CoverIllustration> all = [
    // ── Nature ──
    CoverIllustration(id: 'cover_nature_01', label: 'Trees', category: 'Nature', assetPath: 'assets/illustrations/cover_nature_01.svg'),
    CoverIllustration(id: 'cover_nature_02', label: 'Mountains', category: 'Nature', assetPath: 'assets/illustrations/cover_nature_02.svg'),
    CoverIllustration(id: 'cover_nature_03', label: 'Ocean Waves', category: 'Nature', assetPath: 'assets/illustrations/cover_nature_03.svg'),
    CoverIllustration(id: 'cover_nature_04', label: 'Sunset', category: 'Nature', assetPath: 'assets/illustrations/cover_nature_04.svg'),
    // ── Abstract ──
    CoverIllustration(id: 'cover_abstract_01', label: 'Geometric', category: 'Abstract', assetPath: 'assets/illustrations/cover_abstract_01.svg'),
    CoverIllustration(id: 'cover_abstract_02', label: 'Flowing', category: 'Abstract', assetPath: 'assets/illustrations/cover_abstract_02.svg'),
    CoverIllustration(id: 'cover_abstract_03', label: 'Circles', category: 'Abstract', assetPath: 'assets/illustrations/cover_abstract_03.svg'),
    CoverIllustration(id: 'cover_abstract_04', label: 'Dots', category: 'Abstract', assetPath: 'assets/illustrations/cover_abstract_04.svg'),
    // ── Literature ──
    CoverIllustration(id: 'cover_literature_01', label: 'Open Book', category: 'Literature', assetPath: 'assets/illustrations/cover_literature_01.svg'),
    CoverIllustration(id: 'cover_literature_02', label: 'Quill Pen', category: 'Literature', assetPath: 'assets/illustrations/cover_literature_02.svg'),
    CoverIllustration(id: 'cover_literature_03', label: 'Scroll', category: 'Literature', assetPath: 'assets/illustrations/cover_literature_03.svg'),
    CoverIllustration(id: 'cover_literature_04', label: 'Typewriter', category: 'Literature', assetPath: 'assets/illustrations/cover_literature_04.svg'),
    // ── Science ──
    CoverIllustration(id: 'cover_science_01', label: 'Atom', category: 'Science', assetPath: 'assets/illustrations/cover_science_01.svg'),
    CoverIllustration(id: 'cover_science_02', label: 'DNA Helix', category: 'Science', assetPath: 'assets/illustrations/cover_science_02.svg'),
    CoverIllustration(id: 'cover_science_03', label: 'Constellation', category: 'Science', assetPath: 'assets/illustrations/cover_science_03.svg'),
    CoverIllustration(id: 'cover_science_04', label: 'Flask', category: 'Science', assetPath: 'assets/illustrations/cover_science_04.svg'),
    // ── Urban ──
    CoverIllustration(id: 'cover_urban_01', label: 'City Skyline', category: 'Urban', assetPath: 'assets/illustrations/cover_urban_01.svg'),
    CoverIllustration(id: 'cover_urban_02', label: 'Bridge', category: 'Urban', assetPath: 'assets/illustrations/cover_urban_02.svg'),
    CoverIllustration(id: 'cover_urban_03', label: 'Street Lamp', category: 'Urban', assetPath: 'assets/illustrations/cover_urban_03.svg'),
    CoverIllustration(id: 'cover_urban_04', label: 'Window View', category: 'Urban', assetPath: 'assets/illustrations/cover_urban_04.svg'),
    // ── Minimalist ──
    CoverIllustration(id: 'cover_minimalist_01', label: 'Line Art', category: 'Minimalist', assetPath: 'assets/illustrations/cover_minimalist_01.svg'),
    CoverIllustration(id: 'cover_minimalist_02', label: 'Dot Wave', category: 'Minimalist', assetPath: 'assets/illustrations/cover_minimalist_02.svg'),
    CoverIllustration(id: 'cover_minimalist_03', label: 'Shapes', category: 'Minimalist', assetPath: 'assets/illustrations/cover_minimalist_03.svg'),
    CoverIllustration(id: 'cover_minimalist_04', label: 'Zen Circle', category: 'Minimalist', assetPath: 'assets/illustrations/cover_minimalist_04.svg'),
  ];

  /// Returns illustrations grouped by category, preserving order.
  static Map<String, List<CoverIllustration>> get byCategory {
    final map = <String, List<CoverIllustration>>{};
    for (final item in all) {
      (map[item.category] ??= []).add(item);
    }
    return map;
  }

  /// Find a specific illustration by id, or null.
  static CoverIllustration? findById(String id) {
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }
}
