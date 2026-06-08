/// Value-carrying enums for the four closed sets in the Blueprint API.
///
/// Each enum mirrors the backend's TEXT + CHECK controlled list (see
/// `core/backend/src/psitta/schemas/api.py` — `GenreEnum`,
/// `BlueprintStatusEnum`, `RoleEnum`, `ReadinessEnum`) byte-for-byte. The wire
/// strings are read directly from that source of truth, not typed from memory
/// (note `Children's Picture Book` carries a single apostrophe, `in_progress`
/// is snake_case, `Main Content` is two title-cased words).
///
/// This formalizes the [DocBlockType] string-mapping precedent in
/// `psitta_document.dart`: instead of an inline `switch` with a string default,
/// every variant carries its [wire] value and exposes a non-throwing [fromWire]
/// factory.
///
/// ## Forward-compatibility contract
/// [fromWire] MUST NEVER throw. Every enum carries an explicit `unknown`
/// sentinel and falls back to it for any value the backend may add later. The
/// app must keep parsing (and not crash) when the server introduces a new
/// genre, status, role, or readiness state. The `unknown` sentinel's [wire] is
/// the client-only string `'unknown'`, which never appears on the wire for
/// these required, CHECK-constrained fields — so it cannot collide with a real
/// value and is never serialized back in this read-only layer.
library;

/// Blueprint genre — the ten values of `ck_blueprints_genre`.
enum Genre {
  novel('Novel'),
  memoir('Memoir'),
  nonFiction('Non-Fiction'),
  biography('Biography'),
  researchPaper('Research Paper'),
  childrensPictureBook("Children's Picture Book"),
  screenplay('Screenplay'),
  workbookHowTo('Workbook/How-To'),
  businessBook('Business Book'),
  shortStoryCollection('Short Story Collection'),

  /// Forward-compatibility fallback — never emitted by the backend.
  unknown('unknown');

  const Genre(this.wire);

  /// The exact backend string for this variant.
  final String wire;

  /// Maps a backend string to its variant; unrecognized values map to
  /// [Genre.unknown]. Never throws.
  static Genre fromWire(String value) => Genre.values.firstWhere(
        (g) => g.wire == value,
        orElse: () => Genre.unknown,
      );
}

/// Blueprint lifecycle status — the three values of `ck_blueprints_status`.
enum BlueprintStatus {
  draft('Draft'),
  completed('Completed'),
  archived('Archived'),

  /// Forward-compatibility fallback — never emitted by the backend.
  unknown('unknown');

  const BlueprintStatus(this.wire);

  /// The exact backend string for this variant.
  final String wire;

  /// Maps a backend string to its variant; unrecognized values map to
  /// [BlueprintStatus.unknown]. Never throws.
  static BlueprintStatus fromWire(String value) =>
      BlueprintStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => BlueprintStatus.unknown,
      );
}

/// Part-document role — the five values of `ck_part_documents_role`.
enum Role {
  mainContent('Main Content'),
  supportingContent('Supporting Content'),
  research('Research'),
  notes('Notes'),
  referenceMaterial('Reference Material'),

  /// Forward-compatibility fallback — never emitted by the backend.
  unknown('unknown');

  const Role(this.wire);

  /// The exact backend string for this variant.
  final String wire;

  /// Maps a backend string to its variant; unrecognized values map to
  /// [Role.unknown]. Never throws.
  static Role fromWire(String value) => Role.values.firstWhere(
        (r) => r.wire == value,
        orElse: () => Role.unknown,
      );
}

/// Leaf-aware subtree readiness, derived on read — the three values of
/// `ReadinessEnum`.
enum Readiness {
  empty('empty'),
  inProgress('in_progress'),
  ready('ready'),

  /// Forward-compatibility fallback — never emitted by the backend.
  unknown('unknown');

  const Readiness(this.wire);

  /// The exact backend string for this variant.
  final String wire;

  /// Maps a backend string to its variant; unrecognized values map to
  /// [Readiness.unknown]. Never throws.
  static Readiness fromWire(String value) => Readiness.values.firstWhere(
        (r) => r.wire == value,
        orElse: () => Readiness.unknown,
      );
}
