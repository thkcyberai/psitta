import '../../data/models/blueprint_enums.dart';

/// One audience variant of a narrative structure. Each "Best For" carries its
/// OWN ordered list of [components] (story beats / sections) — the wording
/// differs per audience (e.g. the Hero's Journey reads differently for Fantasy
/// vs Adventure vs Sci-Fi). Sourced from the curated Segmented Narrative
/// Components catalog.
class NarrativeVariant {
  const NarrativeVariant({required this.bestFor, required this.components});

  /// The audience / genre this variant is tuned for (e.g. "Fantasy").
  final String bestFor;

  /// Ordered story beats the writer can pick from.
  final List<String> components;
}

/// A curated narrative structure — a named story framework with one or more
/// audience [variants]. The writer picks a variant, then chooses the steps;
/// the chosen steps become blueprint sections.
///
/// Layer 1 of Story Coach: a client-side catalog. "Use this Structure" generates
/// a real, user-owned blueprint from the picked steps via the existing
/// create-blueprint + create-part actions (no new backend). [genre] maps to one
/// of the ten allowed blueprint genres for the create call; [cover] is the card
/// illustration (assets/covers/).
class NarrativeStructure {
  const NarrativeStructure({
    required this.name,
    required this.genre,
    required this.cover,
    required this.variants,
  });

  final String name;
  final Genre genre;
  final String cover;
  final List<NarrativeVariant> variants;

  /// Stable catalog key for persistence (derived from the fixed display name;
  /// writers never see it). e.g. "Hero's Journey" -> "hero_s_journey".
  String get key => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+\$'), '');

  /// Every audience, comma-joined (e.g. "Fantasy, Adventure, Sci-Fi").
  String get bestFor => variants.map((v) => v.bestFor).join(', ');

  /// Whether this structure offers more than one audience variant.
  bool get hasVariants => variants.length > 1;

  /// Components of the first variant — a sensible default for previews/lists.
  List<String> get components => variants.first.components;
}

const List<NarrativeStructure> kNarrativeStructures = [
  NarrativeStructure(
    name: "Hero's Journey",
    genre: Genre.novel,
    cover: 'assets/covers/fantasy_castle.jpg',
    variants: [
      NarrativeVariant(bestFor: 'Fantasy', components: [
        'Ordinary World',
        'Prophecy or ancient legend',
        'Call to Adventure',
        'Refusal of the Call',
        'Magical Mentor',
        'Crossing into the enchanted world',
        'Trials, allies, and monsters',
        'Approach to the dark power',
        'Ordeal or sacrifice',
        'Reward or magical knowledge',
        'Road Back',
        'Resurrection',
        'Return with the Elixir',
      ]),
      NarrativeVariant(bestFor: 'Adventure', components: [
        'Ordinary Life',
        'Mission or challenge appears',
        'Refusal or hesitation',
        'Guide or experienced ally',
        'Departure',
        'Dangerous route',
        'Tests, allies, and rivals',
        'Approach to final obstacle',
        'Ordeal',
        'Prize or discovery',
        'Return journey',
        'Final test',
        'Return changed',
      ]),
      NarrativeVariant(bestFor: 'Sci-Fi', components: [
        'Ordinary World or colony',
        'Signal, anomaly, or discovery',
        'Refusal or fear of the unknown',
        'Scientist, AI, or commander mentor',
        'Crossing into space, simulation, or future world',
        'Tests with technology and alien forces',
        'Approach to core mystery',
        'System failure or existential ordeal',
        'Revelation or data reward',
        'Escape or return route',
        'Final transformation',
        'New future for humanity',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Three Act Structure',
    genre: Genre.novel,
    cover: 'assets/covers/novel.png',
    variants: [
      NarrativeVariant(bestFor: 'General Fiction', components: [
        'Act I Setup',
        'Main character introduced',
        'Everyday conflict',
        'Inciting Incident',
        'First Plot Point',
        'Act II Rising Action',
        'Complications',
        'Midpoint shift',
        'Crisis',
        'Act III Climax',
        'Resolution',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Save the Cat',
    genre: Genre.screenplay,
    cover: 'assets/covers/town_square.jpg',
    variants: [
      NarrativeVariant(bestFor: 'Commercial Fiction', components: [
        'Opening Image',
        'Theme Stated',
        'Setup',
        'Catalyst',
        'Debate',
        'Break Into Two',
        'B Story',
        'Fun and Games',
        'Midpoint',
        'Bad Guys Close In',
        'All Is Lost',
        'Dark Night of the Soul',
        'Break Into Three',
        'Finale',
        'Final Image',
      ]),
      NarrativeVariant(bestFor: 'Screenwriting', components: [
        'Opening Image',
        'Theme Stated visually',
        'Setup scenes',
        'Catalyst scene',
        'Debate sequence',
        'Act Two break',
        'B Story introduction',
        'Promise of premise sequence',
        'Midpoint twist',
        'Pressure increases',
        'All Is Lost beat',
        'Dark Night scene',
        'Act Three solution',
        'Finale sequence',
        'Final Image',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Seven Point Story Structure',
    genre: Genre.novel,
    cover: 'assets/covers/reading.jpg',
    variants: [
      NarrativeVariant(bestFor: 'Novels', components: [
        'Hook',
        'Plot Turn 1',
        'Pinch Point 1',
        'Midpoint',
        'Pinch Point 2',
        'Plot Turn 2',
        'Resolution',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Snowflake Method',
    genre: Genre.novel,
    cover: 'assets/covers/oak_sunset.jpg',
    variants: [
      NarrativeVariant(bestFor: 'Novel Planning', components: [
        'One Sentence Summary',
        'One Paragraph Summary',
        'Character Summaries',
        'Expanded Synopsis',
        'Character Arcs',
        'Scene List',
        'First Draft',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Freytag Pyramid',
    genre: Genre.novel,
    cover: 'assets/covers/epic.jpg',
    variants: [
      NarrativeVariant(bestFor: 'Drama', components: [
        'Exposition',
        'Inciting Force',
        'Rising Action',
        'Climax',
        'Falling Action',
        'Catastrophe or Resolution',
      ]),
      NarrativeVariant(bestFor: 'Literary Fiction', components: [
        'Exposition',
        'Character tension',
        'Rising psychological action',
        'Emotional or thematic climax',
        'Falling action',
        'Ambiguous or reflective resolution',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Fichtean Curve',
    genre: Genre.novel,
    cover: 'assets/covers/epic2.jpg',
    variants: [
      NarrativeVariant(bestFor: 'Fast-Paced Fiction', components: [
        'Opening crisis',
        'Crisis 1',
        'Temporary recovery',
        'Crisis 2',
        'Escalation',
        'Crisis 3',
        'Complication',
        'Crisis 4',
        'Climax',
        'Resolution',
      ]),
    ],
  ),
  NarrativeStructure(
    name: "Dan Harmon's Story Circle",
    genre: Genre.novel,
    cover: 'assets/covers/novel.png',
    variants: [
      NarrativeVariant(bestFor: 'Modern Fiction', components: [
        'You',
        'Need',
        'Go',
        'Search',
        'Find',
        'Take',
        'Return',
        'Change',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Mystery Structure',
    genre: Genre.novel,
    cover: 'assets/covers/wich.jpg',
    variants: [
      NarrativeVariant(bestFor: 'Mystery', components: [
        'Crime or strange event',
        'Detective introduced',
        'Investigation begins',
        'Clues discovered',
        'Red herrings',
        'False suspect',
        'Revelation',
        'Confrontation',
        'Solution',
      ]),
      NarrativeVariant(bestFor: 'Detective', components: [
        'Case assigned',
        'Detective goal',
        'Witness interviews',
        'Evidence trail',
        'False leads',
        'Hidden motive',
        'Breakthrough clue',
        'Suspect confrontation',
        'Case solved',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Thriller Structure',
    genre: Genre.novel,
    cover: 'assets/covers/town_square.jpg',
    variants: [
      NarrativeVariant(bestFor: 'Thriller', components: [
        'Threat',
        'Escalation',
        'Complications',
        'Chase',
        'Revelation',
        'Final Confrontation',
        'Aftermath',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Romance Structure',
    genre: Genre.novel,
    cover: 'assets/covers/Romantic.jpg',
    variants: [
      NarrativeVariant(bestFor: 'Romance', components: [
        'Meet Cute',
        'Attraction',
        'Emotional connection',
        'Commitment tension',
        'Obstacle',
        'Separation',
        'Realization',
        'Reunion',
        'Happily Ever After or Happy For Now',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Romantic Comedy',
    genre: Genre.screenplay,
    cover: 'assets/covers/Romantic2.jpg',
    variants: [
      NarrativeVariant(bestFor: 'Rom-Com', components: [
        'Meet',
        'Awkward spark',
        'Comic complication',
        'Growing attraction',
        'Misunderstanding',
        'Big conflict',
        'Separation',
        'Grand gesture',
        'Reunion',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Tragedy',
    genre: Genre.novel,
    cover: 'assets/covers/epic.jpg',
    variants: [
      NarrativeVariant(bestFor: 'Literary Fiction', components: [
        'Introduction',
        'Flaw revealed',
        'Desire intensifies',
        'Warnings ignored',
        'Rising consequences',
        'Crisis',
        'Catastrophe',
        'Reflection',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Coming of Age',
    genre: Genre.novel,
    cover: 'assets/covers/oak_sunset.jpg',
    variants: [
      NarrativeVariant(bestFor: 'Young Adult', components: [
        'Innocence',
        'New challenge',
        'Pressure from peers, family, or society',
        'Growth',
        'Identity crisis',
        'Difficult choice',
        'Transformation',
        'Maturity',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Quest Structure',
    genre: Genre.novel,
    cover: 'assets/covers/fantasy_castle.jpg',
    variants: [
      NarrativeVariant(bestFor: 'Fantasy', components: [
        'Mission',
        'Prophecy or sacred object',
        'Journey begins',
        'Trials',
        'Allies and magical helpers',
        'Temptation',
        'Sacrifice',
        'Goal achieved',
        'Return',
      ]),
      NarrativeVariant(bestFor: 'Adventure', components: [
        'Mission',
        'Map or objective',
        'Journey begins',
        'Physical obstacles',
        'Allies',
        'Betrayal or setback',
        'Final trial',
        'Goal achieved',
        'Return',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Epic Structure',
    genre: Genre.novel,
    cover: 'assets/covers/epic2.jpg',
    variants: [
      NarrativeVariant(bestFor: 'Epic Fantasy', components: [
        'World Introduction',
        'Ancient threat emerges',
        'Chosen or reluctant hero',
        'Gathering forces',
        'Political or magical conflict',
        'War',
        'Sacrifice',
        'Victory',
        'Legacy',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Horror Structure',
    genre: Genre.novel,
    cover: 'assets/covers/wich.jpg',
    variants: [
      NarrativeVariant(bestFor: 'Horror', components: [
        'Unease',
        'Warning signs',
        'Discovery',
        'Fear escalation',
        'Isolation',
        'Survival attempts',
        'Final horror',
        'Cost',
        'Outcome',
      ]),
    ],
  ),
  NarrativeStructure(
    name: "Children's Story",
    genre: Genre.childrensPictureBook,
    cover: 'assets/covers/childrens_book.png',
    variants: [
      NarrativeVariant(bestFor: "Children's Books", components: [
        'Introduction',
        'Simple desire',
        'Problem',
        'Attempts',
        'Help from friend or adult',
        'Solution',
        'Lesson learned',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Picture Book Structure',
    genre: Genre.childrensPictureBook,
    cover: 'assets/covers/children_book.jpg',
    variants: [
      NarrativeVariant(bestFor: 'Picture Books', components: [
        'Setup',
        'Clear problem',
        'Repeated attempts',
        'Escalation',
        'Turning point',
        'Simple resolution',
        'Emotional close',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Memoir Structure',
    genre: Genre.memoir,
    cover: 'assets/covers/my_memoir.png',
    variants: [
      NarrativeVariant(bestFor: 'Memoir', components: [
        'Early life context',
        'Defining moment',
        'Internal struggle',
        'External challenges',
        'Turning point',
        'Transformation',
        'Reflection',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Biography Structure',
    genre: Genre.biography,
    cover: 'assets/covers/biography.png',
    variants: [
      NarrativeVariant(bestFor: 'Biography', components: [
        'Background',
        'Formative years',
        'Early influences',
        'Major achievements',
        'Challenges',
        'Turning points',
        'Later life',
        'Legacy',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Business Book Structure',
    genre: Genre.businessBook,
    cover: 'assets/covers/code_desk.jpg',
    variants: [
      NarrativeVariant(bestFor: 'Business', components: [
        'Problem',
        'Why it matters',
        'Framework',
        'Method',
        'Examples',
        'Case studies',
        'Implementation',
        'Conclusion',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Self-Help Structure',
    genre: Genre.nonFiction,
    cover: 'assets/covers/reading.jpg',
    variants: [
      NarrativeVariant(bestFor: 'Self Improvement', components: [
        'Pain Point',
        'Reader identification',
        'Mindset Shift',
        'Framework',
        'Action Steps',
        'Exercises',
        'Case Studies',
        'Transformation',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Educational Book Structure',
    genre: Genre.researchPaper,
    cover: 'assets/covers/non_fiction.png',
    variants: [
      NarrativeVariant(bestFor: 'Academic', components: [
        'Introduction',
        'Learning objectives',
        'Core concepts',
        'Lessons',
        'Examples',
        'Exercises',
        'Review',
        'Summary',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Authority Book Structure',
    genre: Genre.nonFiction,
    cover: 'assets/covers/writing_nook.jpg',
    variants: [
      NarrativeVariant(bestFor: 'Experts', components: [
        'Problem',
        'Why It Matters',
        'Original Framework',
        'Proof',
        'Case Studies',
        'Implementation',
        'Future State',
      ]),
      NarrativeVariant(bestFor: 'Consultants', components: [
        'Client problem',
        'Market pain',
        'Consulting framework',
        'Diagnostic method',
        'Case studies',
        'Implementation roadmap',
        'Results',
        'Future state',
      ]),
    ],
  ),
];
