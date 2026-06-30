# Sanctuary Defenders — Game Pillars

> **Status**: Accepted
> **Author**: Creative Director
> **Last Updated**: 2026-06-30
> **Implements**: Root creative direction for all 9 systems

## Overview

Three design pillars govern every feature decision in Sanctuary Defenders. When a
mechanic serves multiple pillars simultaneously, it is a core mechanic. When a
mechanic serves none, it does not ship. These pillars are not themes — they are
decision filters.

## The Three Pillars

---

### Pillar 1: Mastery-as-Vindication

**In one sentence**: Victory is earned through correct prediction and preparation,
not reflexes or raw power.

**Design intent**: The peak experience is the moment when the plan works —
when the hero covers the gap the towers couldn't, when the constellation bonus
fires at exactly the right moment, when the wave that seemed overwhelming
collapses because the player read the battlefield correctly. This is not the
satisfaction of overwhelming force. It is the satisfaction of being right.

Every mechanic must create situations where preparation can be vindicated. Scout
Phase exists to make planning possible. Intermissions exist to allow correction.
The penultimate wave is an elite-only test of the build, not a random spike.

**Design test**: "Does this feature create a moment where a player can feel they
read the battlefield correctly — and be rewarded for it?"

**Anti-patterns that violate this pillar**:
- Randomness that negates preparation (RNG wipes the plan without recourse)
- Wins that feel lucky rather than earned
- Mechanics where all approaches are equally valid (removes the satisfaction of choosing correctly)
- Difficulty that is opaque — players must be able to diagnose what went wrong

---

### Pillar 2: Everything Connects

**In one sentence**: Nine systems form a combinatorial web of synergies; discovery
is the progression loop.

**Design intent**: The question "what happens when I pair X with Y?" must always
have a meaningful, learnable answer. A Tarot card that doubles enemy speed also
doubles their drops. A creature bred for silk becomes a Focus component that changes
how a tower fires. A hero affix that nobody has paired with that constellation
becomes a discovery. Cross-system interactions feel like inventions, not accidents.

The EventBus architecture is not just technical infrastructure — it is the mechanical
expression of this pillar. All nine systems communicate through a single channel
so that any two systems can interact without special-casing. New synergies are
structural, not hard-coded.

**Design test**: "Does this feature open at least one new synergy path with an
existing system? Does discovering it feel earned, not arbitrary?"

**Anti-patterns that violate this pillar**:
- Self-contained systems with no cross-system hooks
- Interactions that produce noise rather than emergent strategy
- Features that add options without adding meaningful decisions
- Synergies that are invisible — players must be able to learn them through play

---

### Pillar 3: The Sanctuary Is Your Statement

**In one sentence**: The player's base is a visible record of choices and theory
of play, not a progression meter.

**Design intent**: Two players who complete ten missions each should have visually
and functionally distinct sanctuaries — because they made different choices, not
because one played longer. Sanctuary growth reflects strategy: a player who invests
in the Menagerie sees different structures than one who focused on the tech tree.
The sanctuary is proof of theory.

Between missions, every investment is a choice about what to prioritize. The
sanctuary shows those choices. It is the player's workshop, and it looks like
how they chose to play.

**Design test**: "Does this feature leave a visible and mechanically meaningful
trace in the sanctuary that is specific to how the player chose to use it — not
just that they used it?"

**Anti-patterns that violate this pillar**:
- Progress that is purely numerical with no visual or structural expression
- Systems that funnel all players through identical sanctuary evolution paths
- Sanctuary changes that are cosmetic only, with no mechanical reflection of the player's strategic direction
- Sanctuary state that resets on defeat (defeats must not strip base investment)

---

## Pillar Interaction Matrix

| Feature | Mastery-as-Vindication | Everything Connects | The Sanctuary Is Your Statement |
|---------|----------------------|--------------------|---------------------------------|
| Pre-placement tower perk (Scout Phase only) | ✅ Rewards advance planning | ✅ Tower × Scout Phase timing synergy | — |
| Menagerie → crafting material quality | — | ✅ Creature happiness × material tier | ✅ Menagerie investment is structurally visible |
| Constellation bonus | ✅ Rewards spatial planning | ✅ Tower × grid position × pattern type | ✅ Pattern layout reflects build theory |
| Tarot deck composition | ✅ Pre-mission commitment to a prediction | ✅ Tarot × wave composition × drop rate | ✅ Deck is a statement of playstyle |
| Defeat preserves Sanctuary | ✅ Removes fear-of-failure barrier to learning | — | ✅ All investment is permanent |

A feature that fills two or more cells is a candidate for core mechanic status.
A feature that fills zero cells requires justification before entering production.

## Design Tests (Consolidated)

A feature passes if it satisfies **at least one** of the following:

1. It creates a moment where preparation is vindicated — the player can feel they
   read the battlefield correctly and be rewarded for it
2. It opens a meaningful cross-system synergy path that players can discover and learn
3. It leaves a player-specific, mechanically meaningful trace in the Sanctuary

A feature that satisfies all three is a priority candidate for the Vertical Slice.

Use this checklist before writing any story in Sprint 3 or later:
- [ ] Which pillar(s) does this feature serve?
- [ ] What is the specific player moment this feature creates?
- [ ] What cross-system connection does it open (if any)?
- [ ] What does the player's sanctuary look like differently because of it?

## Dependencies

- `design/gdd/game-concept.md` — root vision; pillars derive from the Player Fantasy section
- All 9 system GDDs reference these pillars to justify mechanical choices
- `production/vertical-slice-target.md` — "The Gap" scripted moment serves all 3 pillars simultaneously

## Acceptance Criteria

- [x] 3 named pillars defined, each with: design intent, design test, anti-patterns
- [x] Pillar Interaction Matrix populated for 5 confirmed mechanics
- [x] Design Tests Consolidated section usable as a single-page checklist for feature decisions
- [x] No pillar contradicts any Core Rule in `design/gdd/game-concept.md`
