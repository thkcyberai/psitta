import 'package:flutter/material.dart';

/// Canonical icon + accent color for the Writing Desk structural concepts.
///
/// Single source of truth so Project / Blueprint / Part / Role render with
/// the SAME icon and the SAME color wherever they appear (PLACED IN card,
/// Project Navigator, tiles, etc.). Colors are pulled from the active
/// [ColorScheme] so all four skins (Midnight, Rose, Amber, Parchment) adapt.
enum DeskConcept { project, blueprint, part, role, narrative }

extension DeskConceptStyle on DeskConcept {
  /// Locked icon per concept (Folder / Book / Page / Person), matching the
  /// mockup's iconography.
  IconData get icon => switch (this) {
        DeskConcept.project => Icons.folder,
        DeskConcept.blueprint => Icons.menu_book,
        DeskConcept.part => Icons.description,
        DeskConcept.role => Icons.person,
        DeskConcept.narrative => Icons.auto_stories,
      };

  /// Fixed, skin-INDEPENDENT accent per concept. Mid-tone hues chosen to read
  /// clearly on both light (Rose / Amber / Parchment) and dark (Midnight)
  /// surfaces, mirroring the mockup's icon palette. Deliberately not pulled
  /// from the ColorScheme so the concept colors stay identical across skins.
  Color get color => switch (this) {
        DeskConcept.project => const Color(0xFFD99A2B), // gold  (folder)
        DeskConcept.blueprint => const Color(0xFF4F7CC4), // blue  (book)
        DeskConcept.part => const Color(0xFF3E9C92), // teal  (page)
        DeskConcept.role => const Color(0xFF8D6FC4), // violet (person)
        DeskConcept.narrative => const Color(0xFFC2557A), // rose (arc)
      };

  /// Human label per concept.
  String get label => switch (this) {
        DeskConcept.project => 'Project',
        DeskConcept.blueprint => 'Blueprint',
        DeskConcept.part => 'Part',
        DeskConcept.role => 'Role',
        DeskConcept.narrative => 'Narrative',
      };
}
