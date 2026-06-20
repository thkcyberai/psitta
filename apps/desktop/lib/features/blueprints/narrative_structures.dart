import '../../data/models/blueprint_enums.dart';

/// A phase (act) within a narrative structure. Holds the [steps] a writer can
/// pick from. [name] is the act label (e.g. "Act I — Departure"); an empty name
/// means the structure has no act grouping and the steps render as a flat list.
class NarrativePhase {
  const NarrativePhase({this.name = '', required this.steps});
  final String name;
  final List<String> steps;
}

/// A curated narrative structure — a named story framework organized into
/// [phases], each holding pickable steps. The writer assembles their book by
/// choosing steps; the chosen steps become blueprint sections.
///
/// Layer 1 of Story Coach: a client-side catalog. "Use this Structure" generates
/// a real, user-owned blueprint from the picked steps via the existing
/// create-blueprint + create-part actions (no new backend). [genre] maps to one
/// of the ten allowed blueprint genres for the create call; [cover] is the card
/// illustration (assets/covers/).
class NarrativeStructure {
  const NarrativeStructure({
    required this.name,
    required this.bestFor,
    required this.genre,
    required this.cover,
    required this.phases,
  });

  final String name;
  final String bestFor;
  final Genre genre;
  final String cover;
  final List<NarrativePhase> phases;

  /// All steps across every phase, in order.
  List<String> get components => [for (final p in phases) ...p.steps];

  /// Whether this structure has named act grouping.
  bool get hasActs => phases.any((p) => p.name.isNotEmpty);
}

const List<NarrativeStructure> kNarrativeStructures = [
  NarrativeStructure(
    name: "Hero's Journey",
    bestFor: 'Fantasy, Adventure, Sci-Fi',
    genre: Genre.novel,
    cover: 'assets/covers/fantasy_castle.jpg',
    phases: [
      NarrativePhase(name: 'Act I — Departure', steps: [
        'Ordinary World',
        'Call to Adventure',
        'Refusal of the Call',
        'Meeting the Mentor',
        'Crossing the Threshold',
      ]),
      NarrativePhase(name: 'Act II — Initiation', steps: [
        'Tests, Allies and Enemies',
        'Approach to the Inmost Cave',
        'Ordeal',
        'Reward',
      ]),
      NarrativePhase(name: 'Act III — Return', steps: [
        'Road Back',
        'Resurrection',
        'Return with the Elixir',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Three Act Structure',
    bestFor: 'General Fiction',
    genre: Genre.novel,
    cover: 'assets/covers/novel.png',
    phases: [
      NarrativePhase(name: 'Act I — Setup', steps: [
        'Setup',
        'Inciting Incident',
        'First Plot Point',
      ]),
      NarrativePhase(name: 'Act II — Confrontation', steps: [
        'Rising Action',
        'Midpoint',
        'Crisis',
      ]),
      NarrativePhase(name: 'Act III — Resolution', steps: [
        'Climax',
        'Resolution',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Save the Cat',
    bestFor: 'Commercial Fiction, Screenwriting',
    genre: Genre.screenplay,
    cover: 'assets/covers/town_square.jpg',
    phases: [
      NarrativePhase(name: 'Act One', steps: [
        'Opening Image',
        'Theme Stated',
        'Setup',
        'Catalyst',
        'Debate',
      ]),
      NarrativePhase(name: 'Act Two', steps: [
        'Break Into Two',
        'B Story',
        'Fun and Games',
        'Midpoint',
        'Bad Guys Close In',
        'All Is Lost',
        'Dark Night of the Soul',
      ]),
      NarrativePhase(name: 'Act Three', steps: [
        'Break Into Three',
        'Finale',
        'Final Image',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Seven Point Story Structure',
    bestFor: 'Novels',
    genre: Genre.novel,
    cover: 'assets/covers/reading.jpg',
    phases: [
      NarrativePhase(name: 'Beginning', steps: ['Hook', 'Plot Turn 1']),
      NarrativePhase(name: 'Middle', steps: [
        'Pinch Point 1',
        'Midpoint',
        'Pinch Point 2',
      ]),
      NarrativePhase(name: 'End', steps: ['Plot Turn 2', 'Resolution']),
    ],
  ),
  NarrativeStructure(
    name: 'Snowflake Method',
    bestFor: 'Novel Planning',
    genre: Genre.novel,
    cover: 'assets/covers/oak_sunset.jpg',
    phases: [
      NarrativePhase(name: 'Planning', steps: [
        'One Sentence Summary',
        'One Paragraph Summary',
        'Character Summaries',
        'Expanded Synopsis',
        'Scene List',
      ]),
      NarrativePhase(name: 'Drafting', steps: ['First Draft']),
    ],
  ),
  NarrativeStructure(
    name: 'Freytag Pyramid',
    bestFor: 'Drama, Literary Fiction',
    genre: Genre.novel,
    cover: 'assets/covers/epic.jpg',
    phases: [
      NarrativePhase(steps: [
        'Exposition',
        'Rising Action',
        'Climax',
        'Falling Action',
        'Resolution',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Fichtean Curve',
    bestFor: 'Fast-Paced Fiction',
    genre: Genre.novel,
    cover: 'assets/covers/epic2.jpg',
    phases: [
      NarrativePhase(name: 'Rising Crises', steps: [
        'Crisis 1',
        'Crisis 2',
        'Crisis 3',
        'Crisis 4',
      ]),
      NarrativePhase(name: 'Climax & Resolution', steps: [
        'Climax',
        'Resolution',
      ]),
    ],
  ),
  NarrativeStructure(
    name: "Dan Harmon's Story Circle",
    bestFor: 'Modern Fiction',
    genre: Genre.novel,
    cover: 'assets/covers/novel.png',
    phases: [
      NarrativePhase(name: 'Order', steps: ['You', 'Need', 'Go', 'Search']),
      NarrativePhase(name: 'Chaos & Return', steps: [
        'Find',
        'Take',
        'Return',
        'Change',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Mystery Structure',
    bestFor: 'Mystery, Detective',
    genre: Genre.novel,
    cover: 'assets/covers/wich.jpg',
    phases: [
      NarrativePhase(steps: [
        'Crime',
        'Investigation',
        'Clues',
        'Red Herrings',
        'Revelation',
        'Confrontation',
        'Solution',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Thriller Structure',
    bestFor: 'Thriller',
    genre: Genre.novel,
    cover: 'assets/covers/town_square.jpg',
    phases: [
      NarrativePhase(steps: [
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
    bestFor: 'Romance',
    genre: Genre.novel,
    cover: 'assets/covers/Romantic.jpg',
    phases: [
      NarrativePhase(steps: [
        'Meet Cute',
        'Attraction',
        'Commitment',
        'Obstacle',
        'Separation',
        'Realization',
        'Reunion',
        'Happily Ever After',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Romantic Comedy',
    bestFor: 'Rom-Com',
    genre: Genre.screenplay,
    cover: 'assets/covers/Romantic2.jpg',
    phases: [
      NarrativePhase(steps: [
        'Meet',
        'Spark',
        'Complication',
        'Growing Attraction',
        'Big Conflict',
        'Separation',
        'Reunion',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Tragedy',
    bestFor: 'Literary Fiction',
    genre: Genre.novel,
    cover: 'assets/covers/epic.jpg',
    phases: [
      NarrativePhase(steps: [
        'Introduction',
        'Fatal Flaw',
        'Rising Consequences',
        'Crisis',
        'Catastrophe',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Coming of Age',
    bestFor: 'Young Adult',
    genre: Genre.novel,
    cover: 'assets/covers/oak_sunset.jpg',
    phases: [
      NarrativePhase(steps: [
        'Innocence',
        'Challenge',
        'Growth',
        'Identity Crisis',
        'Transformation',
        'Maturity',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Quest Structure',
    bestFor: 'Fantasy, Adventure',
    genre: Genre.novel,
    cover: 'assets/covers/fantasy_castle.jpg',
    phases: [
      NarrativePhase(steps: [
        'Mission',
        'Journey Begins',
        'Trials',
        'Allies',
        'Sacrifice',
        'Goal Achieved',
        'Return',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Epic Structure',
    bestFor: 'Epic Fantasy',
    genre: Genre.novel,
    cover: 'assets/covers/epic2.jpg',
    phases: [
      NarrativePhase(steps: [
        'World Introduction',
        'Threat Emerges',
        'Gathering Forces',
        'War',
        'Sacrifice',
        'Victory',
        'Legacy',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Horror Structure',
    bestFor: 'Horror',
    genre: Genre.novel,
    cover: 'assets/covers/wich.jpg',
    phases: [
      NarrativePhase(steps: [
        'Unease',
        'Discovery',
        'Fear Escalation',
        'Survival',
        'Final Horror',
        'Outcome',
      ]),
    ],
  ),
  NarrativeStructure(
    name: "Children's Story",
    bestFor: "Children's Books",
    genre: Genre.childrensPictureBook,
    cover: 'assets/covers/childrens_book.png',
    phases: [
      NarrativePhase(steps: [
        'Introduction',
        'Problem',
        'Attempts',
        'Solution',
        'Lesson Learned',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Picture Book Structure',
    bestFor: 'Picture Books',
    genre: Genre.childrensPictureBook,
    cover: 'assets/covers/children_book.jpg',
    phases: [
      NarrativePhase(steps: [
        'Setup',
        'Problem',
        'Escalation',
        'Turning Point',
        'Resolution',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Memoir Structure',
    bestFor: 'Memoir',
    genre: Genre.memoir,
    cover: 'assets/covers/my_memoir.png',
    phases: [
      NarrativePhase(steps: [
        'Early Life',
        'Defining Moment',
        'Struggles',
        'Transformation',
        'Reflection',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Biography Structure',
    bestFor: 'Biography',
    genre: Genre.biography,
    cover: 'assets/covers/biography.png',
    phases: [
      NarrativePhase(steps: [
        'Background',
        'Formative Years',
        'Major Achievements',
        'Challenges',
        'Legacy',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Business Book Structure',
    bestFor: 'Business',
    genre: Genre.businessBook,
    cover: 'assets/covers/code_desk.jpg',
    phases: [
      NarrativePhase(steps: [
        'Problem',
        'Framework',
        'Method',
        'Examples',
        'Implementation',
        'Conclusion',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Self-Help Structure',
    bestFor: 'Self Improvement',
    genre: Genre.nonFiction,
    cover: 'assets/covers/reading.jpg',
    phases: [
      NarrativePhase(steps: [
        'Pain Point',
        'Mindset Shift',
        'Framework',
        'Action Steps',
        'Case Studies',
        'Transformation',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Educational Book Structure',
    bestFor: 'Academic',
    genre: Genre.researchPaper,
    cover: 'assets/covers/non_fiction.png',
    phases: [
      NarrativePhase(steps: [
        'Introduction',
        'Concepts',
        'Lessons',
        'Exercises',
        'Summary',
      ]),
    ],
  ),
  NarrativeStructure(
    name: 'Authority Book Structure',
    bestFor: 'Experts, Consultants',
    genre: Genre.nonFiction,
    cover: 'assets/covers/writing_nook.jpg',
    phases: [
      NarrativePhase(steps: [
        'Problem',
        'Why It Matters',
        'Framework',
        'Case Studies',
        'Implementation',
        'Future State',
      ]),
    ],
  ),
];
