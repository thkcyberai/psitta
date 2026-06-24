/// Authored content for the Writing Nook guide chat — a pre-configured
/// (non-AI) decision tree. Every message is hand-written; quick-reply options
/// move the conversation between nodes. Edit copy or add nodes here only —
/// the UI in guide_chat.dart is content-agnostic.

class GuideOption {
  const GuideOption(this.label, this.next);

  /// The chip text the writer taps.
  final String label;

  /// The id of the node to go to next.
  final String next;
}

class GuideNode {
  const GuideNode(this.message, this.options);

  /// What the guide says at this step.
  final String message;

  /// The quick replies offered after the message.
  final List<GuideOption> options;
}

/// The id of the opening node.
const String kGuideRoot = 'root';

/// The whole scripted conversation, keyed by node id.
const Map<String, GuideNode> kGuideScript = {
  'root': GuideNode(
    "Hi! I'm your Writing Nook guide. I can show you how anything here works "
        '— pick a topic to get started.',
    [
      GuideOption('Getting started', 'start'),
      GuideOption('Writing & editing', 'writing'),
      GuideOption('Structure my book (Blueprints)', 'blueprints'),
      GuideOption('Listen to my draft', 'listen'),
      GuideOption('Plan with AI', 'ai'),
      GuideOption('Organize my work', 'organize'),
      GuideOption('Scribbles (quick notes)', 'scribbles'),
      GuideOption('Plans & account', 'plans'),
      GuideOption('Talk to support', 'support'),
    ],
  ),

  'start': GuideNode(
    'Here is the path from idea to finished book:\n'
        '1) Add or create a document in your Library.\n'
        '2) Open it in the Writing Desk to write, edit, and listen.\n'
        '3) Use Blueprints to give the book a structure.\n'
        '4) Group documents into a Project as it grows.\n'
        'Where shall we dig in?',
    [
      GuideOption('Add a document', 'addDoc'),
      GuideOption('The Writing Desk', 'writing'),
      GuideOption('Blueprints', 'blueprints'),
      GuideOption('Back to start', 'root'),
    ],
  ),

  'addDoc': GuideNode(
    'In the Library, tap New Document to start fresh, or drag in a .docx, '
        '.pdf, .txt, .md, or .html file. Each becomes a document you can open, '
        'edit, and listen to. Free includes 10 documents a month; Writing Nook '
        'gives you 50.',
    [
      GuideOption('The Writing Desk', 'writing'),
      GuideOption('Organize into Projects', 'projects'),
      GuideOption('Back to start', 'root'),
    ],
  ),

  'writing': GuideNode(
    'The Writing Desk is where you write and edit. You get rich formatting '
        '(bold, italics, headings, lists, colors, fonts), find-and-replace, and '
        'on-device spell-check that flags words and suggests fixes. You can also '
        'listen while you write to catch what your eyes miss.',
    [
      GuideOption('Listen while writing', 'listen'),
      GuideOption("Set a file's beat", 'beat'),
      GuideOption('Story-Coach', 'coach'),
      GuideOption('Back to start', 'root'),
    ],
  ),

  'beat': GuideNode(
    'Any document can be tagged with a story beat (the PLACED IN panel → Beat '
        'row). That maps your file to a point in your narrative and powers Scene '
        'Mapping and the Progress Tracker, so you can see how far along the book '
        'is.',
    [
      GuideOption('Blueprints & beats', 'blueprints'),
      GuideOption('Progress Tracker', 'progress'),
      GuideOption('Back to start', 'root'),
    ],
  ),

  'blueprints': GuideNode(
    "Blueprints are your book's architecture — not templates, but the "
        'structural foundation. Open Blueprints to explore 25+ proven frameworks '
        "(Hero's Journey, Save the Cat, Three Act, Seven Point, Snowflake and "
        'more), pick the one that fits, and build around its beats. Three tools '
        'sit on top:',
    [
      GuideOption('Interactive Guide', 'guide'),
      GuideOption('Scene Mapper', 'sceneMapper'),
      GuideOption('Progress Tracker', 'progress'),
      GuideOption('Structure Analyzer (AI)', 'analyzer'),
      GuideOption('Back to start', 'root'),
    ],
  ),

  'guide': GuideNode(
    'The Interactive Guide explains every beat of a structure — what each one '
        'does for your story and a concrete craft tip for writing it well. It is '
        'curated craft advice (no AI), so it is instant and free. Perfect when '
        "you're staring at a beat wondering what goes here.",
    [
      GuideOption('Scene Mapper', 'sceneMapper'),
      GuideOption('Back to start', 'root'),
    ],
  ),

  'sceneMapper': GuideNode(
    "Scene Mapper lets you assign each document to a beat, so your book's "
        'spine fills in. Mapped files appear under each beat on the Narrative '
        'screen and you can click straight through to the Writing Desk. It shows '
        'which beats are covered and which are still empty.',
    [
      GuideOption('Progress Tracker', 'progress'),
      GuideOption('Back to start', 'root'),
    ],
  ),

  'progress': GuideNode(
    'The Progress Tracker shows how far along your manuscript is — a bar that '
        'fills as more beats get covered, plus a per-beat checklist of what is '
        'done and what is left. It accumulates left to right so you can watch the '
        'book come together.',
    [
      GuideOption('Structure Analyzer (AI)', 'analyzer'),
      GuideOption('Back to start', 'root'),
    ],
  ),

  'analyzer': GuideNode(
    'The Structure Analyzer is an AI tool: it reads your whole manuscript and '
        'grades each beat as Present, Thin, or Missing, with a short note and an '
        'overall read. Use it for an objective second opinion on your structure. '
        'It uses your monthly AI allowance (Writing Nook: 1M tokens).',
    [
      GuideOption('Story-Coach', 'coach'),
      GuideOption('Back to start', 'root'),
    ],
  ),

  'ai': GuideNode(
    'Writing Nook has two AI helpers (both draw on your monthly token '
        'allowance):\n'
        '• Story-Coach — nudges you while you write if a passage drifts from '
        'your chosen arc.\n'
        '• Structure Analyzer — grades your whole manuscript beat by beat.\n'
        'There is also Summarize-it for quick summaries.',
    [
      GuideOption('Story-Coach', 'coach'),
      GuideOption('Structure Analyzer', 'analyzer'),
      GuideOption('Back to start', 'root'),
    ],
  ),

  'coach': GuideNode(
    'Story-Coach watches what you are writing and, if it wanders off your '
        'narrative arc, shows a gentle thinking-balloon nudge on the right — like '
        'a grammar checker, but for story structure. It is optional: toggle it in '
        'Settings, or mute it for one file. It judges what you just wrote, not '
        'chapter one.',
    [
      GuideOption('Structure Analyzer', 'analyzer'),
      GuideOption('Plans & limits', 'plans'),
      GuideOption('Back to start', 'root'),
    ],
  ),

  'listen': GuideNode(
    'This is Psitta\'s heart: your ears catch what your eyes miss. Open any '
        'document and press Read / Listen — Psitta narrates it in a natural '
        'voice, with word-by-word and sentence highlighting so you can hear '
        'awkward phrasing. Choose voices in the Voices section; speed goes up to '
        '4× on Writing Nook.',
    [
      GuideOption('Choose a voice', 'voices'),
      GuideOption('Back to start', 'root'),
    ],
  ),

  'voices': GuideNode(
    'The Voices section is your voice library — premium natural voices on '
        'Writing Nook, plus standard voices on Free. Preview any voice and set '
        'your default; your choice carries into the Writing Desk and the player.',
    [
      GuideOption('Listen while writing', 'writing'),
      GuideOption('Back to start', 'root'),
    ],
  ),

  'organize': GuideNode(
    'Two layers keep your work tidy:\n'
        '• Library — every document lives here; upload, open, archive, '
        'download.\n'
        '• Projects — group documents into a book, each with its own Blueprint '
        'and Narrative.\n'
        'Blueprint, Project, and Documents are three views of the same book: '
        'structure, organization, and content.',
    [
      GuideOption('Projects', 'projects'),
      GuideOption('Blueprints', 'blueprints'),
      GuideOption('Back to start', 'root'),
    ],
  ),

  'projects': GuideNode(
    'A Project is your book or writing initiative. Add documents to it, attach '
        'a Blueprint for structure, and track Narrative (beats, scene mapping, '
        'progress) plus an Activity feed of what has happened. Writing Nook gives '
        'you unlimited projects.',
    [
      GuideOption('Blueprints', 'blueprints'),
      GuideOption('Back to start', 'root'),
    ],
  ),

  'scribbles': GuideNode(
    'Scribbles are colored sticky notes for quick ideas — jot, color, and '
        'keep. Tap New scribble to add one and pick a color; you can also stick a '
        'note on top so it floats over every Psitta screen while you work. Find '
        'them under Library → Scribbles.',
    [
      GuideOption('Organize my work', 'organize'),
      GuideOption('Back to start', 'root'),
    ],
  ),

  'plans': GuideNode(
    'Psitta has three tiers:\n'
        '• Free — listen with basic voices, 10 docs a month.\n'
        '• Reading Nook — premium voices, highlighting, edit & download, 50 '
        'docs.\n'
        '• Writing Nook — everything plus the writing platform (Desk, '
        'Blueprints, Narrative, Story-Coach, Analyzer) and 1M AI tokens.\n'
        '• Creative Nook — coming soon; adds a creative studio.\n'
        'Manage anytime under Plans in the sidebar.',
    [
      GuideOption('What is a Blueprint?', 'blueprints'),
      GuideOption('Back to start', 'root'),
    ],
  ),

  'support': GuideNode(
    'Need a human? Email the team at support@psitta.ai, or open Help for '
        'guides and FAQs. I am a scripted guide, so for anything I did not cover, '
        'support is your best bet.',
    [
      GuideOption('Back to start', 'root'),
    ],
  ),
};
