import 'package:flutter_riverpod/flutter_riverpod.dart';

/// UI selection state coordinating the Blueprints screen's panes.
///
/// These are presentation-only; the data layer (providers/repository) is
/// unchanged. UI text calls a tree node a "Section"; the code keeps the
/// data-layer term "part" (e.g. [selectedPartIdProvider]).

/// The blueprint selected in the left list pane (null = nothing selected yet).
/// Drives the center section-tree pane.
final selectedBlueprintIdProvider = StateProvider<String?>((ref) => null);

/// The section (part) selected in the center tree pane (null = none). Reset to
/// null whenever the selected blueprint changes, since part ids are per-blueprint.
final selectedPartIdProvider = StateProvider<String?>((ref) => null);
