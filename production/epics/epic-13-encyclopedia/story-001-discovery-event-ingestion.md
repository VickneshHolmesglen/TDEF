# Story 001: Discovery Event Ingestion — 7 Events, Duplicate-Safe Insert

> **Epic**: Encyclopedia System
> **Status**: Ready
> **Layer**: Advanced Feature
> **Type**: Integration
> **Estimate**: 3h
> **Manifest Version**: 2026-07-13b
> **Last Updated**: 2026-07-25

## Context

**GDD**: `design/gdd/encyclopedia.md`
**Requirement**: `TR-encyclopedia-???` (no TR-ID registered — scoped from GDD Core Rules 1 and 3, AC Groups 1-2)

**ADR Governing Implementation**: N/A — no dedicated architecture ADR exists for this system yet. Matches Sanctuary UI/Tarot Deck UI/Audio System's own precedent (all three shipped stories without one, scoping directly from the GDD's own Core Rules).

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: None beyond standard EventBus subscription discipline (7 inbound signals, no post-cutoff API risk per `architecture.md`'s own "Save read + EventBus" note).

**Control Manifest Rules (this layer)**:
- Required: every EventBus subscriber must disconnect in `_exit_tree()` — no exceptions (this project's own zero-exception EventBus rule)

---

## Acceptance Criteria

*From GDD `design/gdd/encyclopedia.md`, AC Groups 1-2:*

- [ ] **AC-1**: GIVEN Encyclopedia is subscribed to EventBus, WHEN `skill_unlocked(skill_id, source_tower_id)` fires, THEN exactly one new `DISCOVERED` entry is added to the `skill` category keyed by `skill_id`.
- [ ] **AC-2**: WHEN `constellation_rune_discovered(rune_id, pattern_id)` fires, THEN exactly one new `DISCOVERED` entry is added to the `constellation_rune` category keyed by `rune_id`.
- [ ] **AC-3**: WHEN `tarot_rune_discovered(rune_id, card_id)` fires, THEN exactly one new `DISCOVERED` entry is added to the `tarot_rune` category keyed by `rune_id`.
- [ ] **AC-4**: WHEN `recipe_discovered(recipe_id, recipe_category)` fires (any `recipe_category` value, both Crafting- and Equipment-Forge-sourced), THEN exactly one new `DISCOVERED` entry is added to the `recipe` category keyed by `recipe_id`, with the entry's stored shape exactly `{category: "recipe", entry_id: recipe_id, discovered_at: <timestamp>}` — `recipe_category` is **not** persisted on the entry (resolved by lookup at render time, per Core Rule 2).
- [ ] **AC-5**: WHEN `creature_acquired(creature_id, species)` fires for a species with no existing `creature` entry, THEN a `DISCOVERED` entry is added to the `creature` category keyed by `species` — **not** `creature_id` (Core Rule 8).
- [ ] **AC-6**: WHEN `creature_bred(offspring_id, species)` fires for a species with no existing `creature` entry, THEN the same species-keyed entry is added, following AC-5's rule.
- [ ] **AC-7**: WHEN `tech_unlocked(tech_id, tech_category)` fires, THEN a `DISCOVERED` entry is added to the `tech` category keyed by `tech_id`.
- [ ] **AC-8**: GIVEN a species already has a `DISCOVERED` `creature` entry, WHEN a second `creature_bred` or `creature_acquired` fires for that same species (different `offspring_id`/`creature_id`), THEN no new entry is created and the existing entry is untouched.
- [ ] **AC-9**: GIVEN any category, WHEN a discovery event fires for a `category`+`entry_id` combination already `DISCOVERED`, THEN the entry ledger's size for that category is unchanged.

---

## Implementation Notes

6 categories (Core Rule 1), each mapped 1:1 to an already-frozen EventBus event — no new event is invented. Entry data model (Core Rule 2): exactly `{category: String, entry_id: String, discovered_at: int}`, no more/fewer fields for any category. `constellation_rune` and `tarot_rune` stay distinct categories (unrelated systems, unrelated unlock conditions); `tech` stays distinct from `recipe` (a tech unlock carries information a recipe unlock doesn't, e.g. `sanctuary_structure_built` eligibility).

**Collision safety** (stated explicitly in the GDD): entries are keyed by the `(category, entry_id)` composite, never `entry_id` alone — a `constellation_rune`'s `rune_id` and a `tarot_rune`'s `rune_id` can never collide even if they reuse the same string, since they land in different category buckets.

**Core Rule 8 (species-level creature discovery)**: `creature_acquired`/`creature_bred` both key the `creature` category entry by `species`, never the per-instance `creature_id`/`offspring_id` — the first individual of a species logs the entry; every subsequent individual (bred or acquired) is a no-op against an already-`DISCOVERED` entry.

**Duplicate suppression** (Core Rule 3, Edge Cases): ledger membership is checked before insert — a repeat event for an already-`DISCOVERED` `(category, entry_id)` never creates a duplicate entry and never mutates the existing one's `discovered_at`.

**Unvalidated `recipe_category`** (Edge Cases): Encyclopedia stores whatever `recipe_id` arrives without validating `recipe_category` against any taxonomy — Crafting/Equipment Forge own that validation, not this system.

---

## Out of Scope

- Story 002: the `encyclopedia_entry_added` emission contract and the read-only query contract (`get_entries()`/`is_discovered()`) — this story only owns the ledger's own insert/no-op behavior
- Story 003: Save & Persistence integration (`restore_order = 35`) — this story can assume an in-memory ledger only
- Bestiary/monster codex, completion-percentage tracking — explicitly deferred by the GDD itself (Core Rules 6-7), not this epic's scope at all

---

## QA Test Cases

- **AC-1 to AC-7** (one test per category)
  - Given: a fresh Encyclopedia instance with an empty ledger
  - When: the category's real mapped EventBus signal fires with a representative payload
  - Then: exactly one `DISCOVERED` entry exists in that category, keyed correctly (species for `creature`, not instance ID)
  - Edge cases: `recipe` category — assert the persisted shape has exactly 3 keys and no `recipe_category` field

- **AC-8**
  - Given: a `creature` entry already `DISCOVERED` for species `"glimmer_hare"`
  - When: `creature_bred` fires with a different `offspring_id` but the same species
  - Then: no new entry created; `creature` category count unchanged; existing entry's `discovered_at` unchanged
  - Edge cases: repeat via `creature_acquired` too, not just `creature_bred`

- **AC-9**
  - Given: any category with one `DISCOVERED` entry
  - When: the same `(category, entry_id)` discovery event fires again
  - Then: category size unchanged
  - Edge cases: test at least 2 different categories, not just one

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/encyclopedia/discovery-event-ingestion_test.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (foundational story for this epic)
- Unlocks: Story 002 (query contract reads this story's own ledger), Story 003 (persistence saves/restores this story's own ledger)
