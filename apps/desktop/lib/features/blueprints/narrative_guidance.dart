/// Curated craft guidance for narrative beats — the data behind the Interactive
/// Guide. Keyed by the (lowercased) beat label so one well-written guide can
/// serve a structure's parallel beats across its audience variants (e.g. the
/// Hero's Journey's "Ordinary World" / "Ordinary Life" / "Ordinary World or
/// colony" all share one guide). Beats without a curated entry fall back to
/// [_genericGuide] so the guide is never empty; coverage grows by adding entries
/// here — data only, no code changes.
library;

class BeatGuide {
  const BeatGuide({required this.purpose, required this.tip});

  /// What this beat does for the story.
  final String purpose;

  /// One concrete craft tip for writing it well.
  final String tip;
}

// ── Canonical Hero's Journey guides (shared across its variants) ──────────────

const _ordinaryWorld = BeatGuide(
  purpose:
      "Establishes your hero's everyday life and what's missing from it, so the "
      'adventure to come has something to disrupt — and something to heal.',
  tip:
      "Plant a flaw, wound, or quiet longing here. It's the thread the whole "
      'journey will pay off.',
);

const _prophecy = BeatGuide(
  purpose:
      'Seeds the larger destiny or mythic stakes the hero will grow into, giving '
      'the story a sense of weight beyond the personal.',
  tip:
      "Hint, don't explain. A fragment of legend is more haunting than a full "
      'briefing — let the meaning land later.',
);

const _call = BeatGuide(
  purpose:
      'The inciting event that breaks the normal world and presents the central '
      'problem, quest, or question of the story.',
  tip:
      'Make the call specific and personal — a stake the reader can feel, not '
      'just an abstract threat to the world.',
);

const _refusal = BeatGuide(
  purpose:
      'The hero hesitates or resists, revealing their fear and exactly what they '
      'stand to lose by leaving.',
  tip:
      'Let the refusal be reasonable. The stronger the reason to stay, the '
      'braver — and more earned — the choice to go.',
);

const _mentor = BeatGuide(
  purpose:
      'A guide gives the hero wisdom, a tool, or the confidence to cross into '
      'the unknown.',
  tip:
      'Give the mentor a flaw or a limit. Perfect mentors are forgettable, and '
      'the hero must eventually outgrow them.',
);

const _threshold = BeatGuide(
  purpose:
      'The hero commits and leaves the familiar world behind, entering the new '
      'and dangerous one for real.',
  tip:
      "Make it a door that won't reopen. A clear point of no return raises the "
      'tension of everything that follows.',
);

const _tests = BeatGuide(
  purpose:
      'The hero learns the rules of the new world, gathers allies and enemies, '
      'and faces rising challenges.',
  tip:
      "Use these trials to force growth and to forge the bonds you'll later put "
      "at risk. Escalate — don't repeat.",
);

const _approach = BeatGuide(
  purpose:
      'The hero prepares for the central ordeal; the stakes and dread tighten '
      'before the worst moment.',
  tip:
      'Slow down and let the dread build. The calm before the ordeal makes the '
      'ordeal itself land far harder.',
);

const _ordeal = BeatGuide(
  purpose:
      'The hero faces their greatest fear or a brush with death — the emotional '
      'low point and true turning point of the story.',
  tip:
      'Make the hero lose something real here. A victory without cost feels '
      'unearned and drains the climax of weight.',
);

const _reward = BeatGuide(
  purpose:
      'Having survived, the hero seizes the prize — an object, a truth, a '
      'reconciliation — and is changed by it.',
  tip:
      'Pair the reward with a new complication. Triumph that creates the next '
      'problem keeps the momentum alive.',
);

const _roadBack = BeatGuide(
  purpose:
      'The hero turns toward home, often pursued, as the stakes widen from the '
      'personal back out to the larger world.',
  tip:
      'Re-raise the external pressure here so the climax never feels like a '
      'victory lap.',
);

const _resurrection = BeatGuide(
  purpose:
      'The final, hardest test, where the hero proves they have truly changed '
      "and the story's theme is settled.",
  tip:
      'Echo an earlier failure and have the hero meet it differently. That '
      'contrast IS the transformation, shown not told.',
);

const _return = BeatGuide(
  purpose:
      'The hero comes home transformed, bringing back something that heals or '
      'renews the ordinary world they left.',
  tip:
      'Show the ordinary world again, changed by what the hero carries back. '
      'That mirror closes the loop you opened in beat one.',
);

// ── Three Act Structure guides ───────────────────────────────────────────────

const _actISetup = BeatGuide(
  purpose:
      'Grounds the reader in the world, tone, and the protagonist’s normal '
      'before anything disrupts it.',
  tip:
      'Open close to the moment of change. Establish just enough normal to make '
      'the coming disruption land — not a slow tour.',
);

const _mcIntroduced = BeatGuide(
  purpose:
      'Introduces the protagonist with a clear want, voice, and flaw, so the '
      'reader has someone to follow and root for.',
  tip:
      'Show them doing something active in the first scene. Character is '
      'revealed through choice under pressure, not description.',
);

const _everydayConflict = BeatGuide(
  purpose:
      "Shows the friction already in the hero's ordinary life — the small "
      'problem that hints at the bigger one to come.',
  tip:
      "Make the everyday trouble rhyme with the story's real theme, so the "
      'opening quietly sets up the ending.',
);

const _incitingIncident = BeatGuide(
  purpose:
      'The event that disturbs the status quo and sets the story in motion '
      '— the moment the real problem arrives.',
  tip:
      'Land it early and make it irreversible. The hero should not be able to '
      'simply walk back to how things were.',
);

const _firstPlotPoint = BeatGuide(
  purpose:
      'The hero commits to the central conflict and crosses out of Act I — '
      'the point of no return into the main story.',
  tip:
      'Force a decision, not an accident. The hero choosing to engage is more '
      'powerful than being dragged in.',
);

const _actIIRising = BeatGuide(
  purpose:
      'The long middle where the hero pursues the goal, the stakes climb, and '
      'obstacles grow harder.',
  tip:
      'Keep raising the cost. Each setback should close an easy exit and push '
      'the hero toward the hardest version of the problem.',
);

const _complications = BeatGuide(
  purpose:
      'New obstacles, reversals, and rising pressure that test the hero and '
      'deepen the conflict.',
  tip:
      'Make complications grow out of earlier choices, not random bad luck '
      '— consequence is more satisfying than coincidence.',
);

const _midpoint = BeatGuide(
  purpose:
      "A major shift at the story's center — a false victory or false "
      "defeat that changes the hero's understanding and raises the stakes.",
  tip:
      'Turn something here: a truth revealed, a win that costs, a loss that '
      'clarifies. The second half should not feel like more of the first.',
);

const _crisis = BeatGuide(
  purpose:
      "The lowest point, where the hero's plan collapses and everything seems "
      'lost before the final push.',
  tip:
      'Strip the hero of their crutch. Real change comes when the old way of '
      'coping finally fails them.',
);

const _climax = BeatGuide(
  purpose:
      'The final confrontation where the central conflict is settled and the '
      'hero faces the problem head-on.',
  tip:
      'Make the hero the one who acts. The climax should turn on a choice only '
      'this changed character could make.',
);

const _resolution = BeatGuide(
  purpose:
      'The aftermath that shows how the hero and their world have changed, and '
      'ties off the emotional threads.',
  tip:
      'Mirror the opening. Returning to an early image — now transformed '
      '— gives the reader a felt sense of completion.',
);

// ── Save the Cat guides (shared across Commercial / Screenwriting wordings) ───

const _openingImage = BeatGuide(
  purpose:
      'A vivid first snapshot that sets the tone, mood, and the "before" '
      'version of the hero and their world.',
  tip:
      "Design it as a deliberate before-shot. You'll answer it with the Final "
      'Image, so make it specific enough to contrast later.',
);

const _themeStated = BeatGuide(
  purpose:
      "Someone states (often in passing) the story's thematic truth — the "
      'lesson the hero will resist and finally learn.',
  tip:
      'Bury it in dialogue the hero brushes off. The theme should feel like a '
      'seed, not a thesis statement.',
);

const _setupStc = BeatGuide(
  purpose:
      "Establishes the hero's world, flaws, and what's missing — every "
      'thing that will need to change by the end.',
  tip:
      'Plant the things that need fixing here so the payoff later feels set up '
      'rather than convenient.',
);

const _catalyst = BeatGuide(
  purpose:
      'The life-changing event that knocks the hero out of their routine and '
      "kicks off the story's real problem.",
  tip:
      'Make it big and external. The catalyst should leave the hero unable to '
      'keep living the old way.',
);

const _debate = BeatGuide(
  purpose:
      'The hero hesitates, weighing whether to act — the last stretch of '
      'doubt before committing to the journey.',
  tip:
      'Give the doubt a real question (Can I? Should I? Dare I?). The debate '
      'earns the leap that follows.',
);

const _breakIntoTwo = BeatGuide(
  purpose:
      'The hero makes a choice and steps into the new world of Act Two, '
      'leaving the old situation behind.',
  tip:
      'Have the hero act, not react. Walking through this door by choice '
      'commits them — and the reader — to the adventure.',
);

const _bStory = BeatGuide(
  purpose:
      'A secondary thread — often a relationship — that carries the '
      'theme and gives the hero a place to grow.',
  tip:
      "Use the B Story to say out loud what the A Story is really about. It's "
      'where the heart of the theme lives.',
);

const _funAndGames = BeatGuide(
  purpose:
      'The "promise of the premise" — the set-pieces and scenes the reader '
      "came for, exploring the story's hook.",
  tip:
      'Deliver what the cover and title promised here. This is the most '
      'marketable stretch — lean into the concept.',
);

const _badGuysCloseIn = BeatGuide(
  purpose:
      "External pressure and internal doubt tighten together as the hero's "
      'situation steadily worsens.',
  tip:
      'Squeeze from both sides — outside enemies and inside cracks — '
      'so the coming collapse feels inevitable.',
);

const _allIsLost = BeatGuide(
  purpose:
      'The rock bottom, where the hero loses what matters most and the goal '
      'looks impossible.',
  tip:
      'Include a "whiff of death" — an ending, loss, or symbolic death '
      'that clears the way for rebirth.',
);

const _darkNight = BeatGuide(
  purpose:
      "The hero's darkest moment of despair, sitting in the loss before "
      'finding a new way forward.',
  tip:
      'Let the hero be genuinely defeated here. The insight that lifts them '
      'should come from the bottom, not arrive on schedule.',
);

const _breakIntoThree = BeatGuide(
  purpose:
      'The hero finds the answer — usually by fusing the A and B stories '
      '— and commits to the final act.',
  tip:
      'Let the solution come from what the hero learned through the B Story. '
      'Theme and plot should click together here.',
);

const _finale = BeatGuide(
  purpose:
      "The hero executes the plan, proves they've changed, and resolves the "
      'central conflict for good.',
  tip:
      'Have the hero dismantle the problem at every level. A finale that fixes '
      'the world AND the hero feels complete.',
);

const _finalImage = BeatGuide(
  purpose:
      'The closing snapshot that mirrors the Opening Image and shows how far '
      'the hero and their world have come.',
  tip:
      'Echo the opening shot deliberately. The contrast between first and last '
      'image is the proof of transformation.',
);

// ── Seven Point Story Structure guides ───────────────────────────────────────

const _hook = BeatGuide(
  purpose:
      "The starting state — the hero's life and situation at the opposite "
      "end of where they'll finish.",
  tip:
      'Start as far from the ending as you can. The Seven Point method builds '
      'backward, so a strong contrast powers the whole arc.',
);

const _plotTurn1 = BeatGuide(
  purpose:
      'The call to adventure that moves the hero from their starting world '
      'into the main conflict.',
  tip:
      "Use it to introduce the central conflict and change the hero's "
      'direction — the moment the real story begins.',
);

const _pinch1 = BeatGuide(
  purpose:
      'Applies pressure by showing the force of the antagonist or central '
      'threat, pushing the hero to act.',
  tip:
      "Reveal the opposition's strength here. A pinch point reminds the reader "
      'the stakes are real and the enemy is capable.',
);

const _pinch2 = BeatGuide(
  purpose:
      'A harder squeeze — the antagonist gains the upper hand and the '
      "hero's support falls away.",
  tip:
      'Make this pinch worse than the first: lose an ally, a plan, or a safety '
      'net to drive the hero toward the low point.',
);

const _plotTurn2 = BeatGuide(
  purpose:
      'The hero moves from reaction to action, gaining the final piece needed '
      'to face the climax.',
  tip:
      'Hand the hero what they need to win — a tool, a truth, or resolve '
      '— so the ending turns on their effort, not luck.',
);

// ── Snowflake Method guides ──────────────────────────────────────────────────

const _oneSentence = BeatGuide(
  purpose:
      'A single sentence that captures the whole novel — the foundation '
      'the entire Snowflake plan expands from.',
  tip:
      'Keep it under about 15 words, name no characters, and tie the big '
      'picture to the ending. This is your north star.',
);

const _oneParagraph = BeatGuide(
  purpose:
      'Expands the one-sentence summary into a paragraph covering the setup, '
      'major disasters, and ending.',
  tip:
      'Aim for five sentences: setup, then three rising disasters, then '
      'resolution. Each disaster forces the next.',
);

const _charSummaries = BeatGuide(
  purpose:
      'A short summary for each major character — their goal, motivation, '
      'conflict, and arc in one place.',
  tip:
      'Give every key character a one-line goal and the thing standing in its '
      'way. Clashing goals create plot.',
);

const _expandedSynopsis = BeatGuide(
  purpose:
      'Grows each sentence of the paragraph summary into a full paragraph, '
      'building a page-long story spine.',
  tip:
      'Expand one sentence at a time so structure stays balanced. End each '
      'paragraph on the disaster that drives the next.',
);

const _charArcs = BeatGuide(
  purpose:
      'Details how each character changes across the story — their '
      'internal journey alongside the external plot.',
  tip:
      'Map where each character starts and ends emotionally. The strongest '
      'arcs change belief, not just circumstance.',
);

const _sceneList = BeatGuide(
  purpose:
      'A list of every scene — its POV character and what happens — '
      'turning the synopsis into a build plan.',
  tip:
      "Give each scene a clear purpose and a change. If a scene doesn't shift "
      'something, cut it or combine it.',
);

const _firstDraft = BeatGuide(
  purpose:
      'The drafting phase, where the detailed plan becomes actual prose — '
      'the payoff of all the planning steps.',
  tip:
      'Trust the outline and keep moving forward. Draft to finish, not to '
      'perfect; revision is a separate pass.',
);

// ── Label → guide map. Lowercased keys; parallel variant wordings share a guide.

const Map<String, BeatGuide> _beatGuides = {
  // Ordinary world
  'ordinary world': _ordinaryWorld,
  'ordinary life': _ordinaryWorld,
  'ordinary world or colony': _ordinaryWorld,
  // Prophecy / legend (Fantasy)
  'prophecy or ancient legend': _prophecy,
  // Call to adventure
  'call to adventure': _call,
  'mission or challenge appears': _call,
  'signal, anomaly, or discovery': _call,
  // Refusal
  'refusal of the call': _refusal,
  'refusal or hesitation': _refusal,
  'refusal or fear of the unknown': _refusal,
  // Mentor
  'magical mentor': _mentor,
  'guide or experienced ally': _mentor,
  'scientist, ai, or commander mentor': _mentor,
  // Crossing the threshold
  'crossing into the enchanted world': _threshold,
  'departure': _threshold,
  'crossing into space, simulation, or future world': _threshold,
  // Tests, allies, enemies
  'trials, allies, and monsters': _tests,
  'dangerous route': _tests,
  'tests, allies, and rivals': _tests,
  'tests with technology and alien forces': _tests,
  // Approach
  'approach to the dark power': _approach,
  'approach to final obstacle': _approach,
  'approach to core mystery': _approach,
  // Ordeal
  'ordeal or sacrifice': _ordeal,
  'ordeal': _ordeal,
  'system failure or existential ordeal': _ordeal,
  // Reward
  'reward or magical knowledge': _reward,
  'prize or discovery': _reward,
  'revelation or data reward': _reward,
  // Road back
  'road back': _roadBack,
  'return journey': _roadBack,
  'escape or return route': _roadBack,
  // Resurrection / final test
  'resurrection': _resurrection,
  'final test': _resurrection,
  'final transformation': _resurrection,
  // Return with the elixir
  'return with the elixir': _return,
  'return changed': _return,
  'new future for humanity': _return,

  // ── Three Act Structure ──
  'act i setup': _actISetup,
  'main character introduced': _mcIntroduced,
  'everyday conflict': _everydayConflict,
  'inciting incident': _incitingIncident,
  'first plot point': _firstPlotPoint,
  'act ii rising action': _actIIRising,
  'complications': _complications,
  'midpoint shift': _midpoint,
  'crisis': _crisis,
  'act iii climax': _climax,
  'resolution': _resolution,

  // ── Save the Cat (Commercial Fiction + Screenwriting wordings) ──
  'opening image': _openingImage,
  'theme stated': _themeStated,
  'theme stated visually': _themeStated,
  'setup': _setupStc,
  'setup scenes': _setupStc,
  'catalyst': _catalyst,
  'catalyst scene': _catalyst,
  'debate': _debate,
  'debate sequence': _debate,
  'break into two': _breakIntoTwo,
  'act two break': _breakIntoTwo,
  'b story': _bStory,
  'b story introduction': _bStory,
  'fun and games': _funAndGames,
  'promise of premise sequence': _funAndGames,
  'midpoint': _midpoint,
  'midpoint twist': _midpoint,
  'bad guys close in': _badGuysCloseIn,
  'pressure increases': _badGuysCloseIn,
  'all is lost': _allIsLost,
  'all is lost beat': _allIsLost,
  'dark night of the soul': _darkNight,
  'dark night scene': _darkNight,
  'break into three': _breakIntoThree,
  'act three solution': _breakIntoThree,
  'finale': _finale,
  'finale sequence': _finale,
  'final image': _finalImage,

  // ── Seven Point Story Structure ──
  'hook': _hook,
  'plot turn 1': _plotTurn1,
  'pinch point 1': _pinch1,
  'pinch point 2': _pinch2,
  'plot turn 2': _plotTurn2,

  // ── Snowflake Method ──
  'one sentence summary': _oneSentence,
  'one paragraph summary': _oneParagraph,
  'character summaries': _charSummaries,
  'expanded synopsis': _expandedSynopsis,
  'character arcs': _charArcs,
  'scene list': _sceneList,
  'first draft': _firstDraft,
};

const _genericGuide = BeatGuide(
  purpose:
      "A step in your story's arc — it should move the character or the stakes "
      'forward, not just mark time.',
  tip:
      "Keep the character's goal active and let the tension rise. Every beat "
      'should change something — a stake, a relationship, or what we know.',
);

/// Guidance for a beat label, falling back to a general craft note when the
/// beat has no curated entry yet (so the guide is never empty).
BeatGuide guideForBeat(String beatLabel) =>
    _beatGuides[beatLabel.trim().toLowerCase()] ?? _genericGuide;
