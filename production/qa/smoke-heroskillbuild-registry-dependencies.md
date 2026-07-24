# Smoke Check: Hero Skill Build Cross-GDD Interface & Registry Dependencies

**Story**: `production/epics/epic-08-meta-progression-convergence/story-007-heroskillbuild-registry-dependencies.md`
**Type**: Config/Data — content-validation smoke check, not a runtime assertion.
**Date**: 2026-07-19

## Scope

Tracks 3 pre-implementation blockers this GDD/ADR explicitly flagged as unresolved outside its own authoring scope. Re-checked against current repo state rather than assumed from the story's original text.

## AC-18: Inventory `item_type = "skill_modifier"` — STILL BLOCKED

`grep -n "skill_modifier" design/gdd/inventory.md` returns no matches. `skill_modifier` is not a valid `item_type` anywhere in `inventory.md`'s tab-to-item_type mapping today.

**Result: still BLOCKED**, as the story originally stated. Requires an `inventory.md` revision (adding `skill_modifier` under the Equipment tab) before Hero Skill Build's passive-slot items can be equipped/unequipped via Inventory's real API. Tracked, not silently assumed resolved.

## AC-19: `category`/`archetype` registry cross-reference — RESOLVED (finding, not assumed)

**The story's original premise was stale.** `design/registry/entities.yaml` already contains a `hero_skill_category` entry (`added: 2026-07-17` — authored during the GDD/ADR session, before this story was written), with `referenced_by: [design/gdd/tower.md, design/gdd/hero-skill-build.md]` and explicit notes confirming `category` is "reused verbatim from tower.md's Foundation component 'archetype' field... not a new taxonomy."

This differs structurally from what the story's Implementation Notes requested (a `referenced_by` addition to an existing `archetype` entry) — no standalone `archetype` entity entry exists in the registry; `hero_skill_category` is its own entry instead, achieving the same traceability goal via a different (still valid) registry pattern.

**Result: RESOLVED.** No further action needed — re-verified against the live registry file, not assumed from the story text.

## AC-20: 19-value `ultimate_id` registry entry — RESOLVED (finding, not assumed)

**Also stale in the story's original premise.** `entities.yaml` already contains a `hero_ultimate_id_derivation` entry (`added: 2026-07-17`), documenting Formula 1-3's full derivation pipeline and the 19-fixed-ID/35-raw-profile proof, with `referenced_by: [design/gdd/hero-skill-build.md, design/gdd/hero.md]`.

**Result: RESOLVED.** `src/core/hero_skill_build/hero_skill_build.gd`'s `_ultimate_id_for_shape()` (Story 002) is the single production implementation of the 19-ID set — confirmed no second, independently-hardcoded copy exists anywhere in `src/` (the Forbidden rule this AC exists to guard against).

## Verdict

**PARTIAL — 2 of 3 originally-tracked blockers found already resolved during this smoke check; 1 (AC-18, Inventory) remains genuinely open.** This story's value was in re-verifying against live repo state rather than trusting the story text as authoritative — the registry gaps closed between GDD-authoring and story-writing sessions, and nothing in the `/create-stories` pass had re-checked before writing AC-19/AC-20 as blocked. AC-18 requires a real `inventory.md` revision before Hero Skill Build's passive-slot Inventory integration (Story 004's own flagged dependency) can move forward.
