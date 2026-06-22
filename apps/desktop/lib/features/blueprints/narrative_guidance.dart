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
