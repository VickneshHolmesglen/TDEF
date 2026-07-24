# Story 015: Concurrency Guard & Orphaned Rune References

> **Epic**: Epic 08 — Meta-Progression Convergence
> **Status**: Complete
> **Layer**: Advanced
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/equipment-forge.md`
**Requirement**: `TR-equipforge-001`

**ADR Governing Implementation**: ADR-0025 (Equipment Forge Cross-System Aggregation)
**ADR Decision Summary**: A single `_forge_resolving: bool` flag guards all three operation types (equipment crafting, rune imbuing, creature sacrifice) — set at the start of any operation's first validation step, cleared only after its final event emission. A second confirmation received while resolving is rejected outright, no queueing. Orphaned rune references follow the established `hero.md`/`tower-mastery.md` orphan-preserve pattern.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Mirrors Crafting's `_craft_resolving` (ADR-0023) and Defense Building's `_action_resolving` (ADR-0024) precedent, generalized across three operation types instead of two.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0023/0024/0025 directly.
- Forbidden: Never queue a second confirmation received while `_forge_resolving == true` — reject outright, regardless of which two of the three operation types are involved.
- Guardrail: An orphaned `rune_id` already imbued never becomes free again — a rune was historically spent there, and the "never re-imbuable" guarantee must hold even across an orphaning event.

---

## Acceptance Criteria

*From GDD `design/gdd/equipment-forge.md`, scoped to this story:*

- [x] AC-23 — any two of {craft, imbue, sacrifice} confirmed in the same frame: the second is rejected outright, no queueing (at minimum, one same-type pair and one cross-type pair exercised)
- [~] AC-24 — orphaned `rune_id` already imbued: entry retained, slot marked `UNKNOWN`, stat contribution resolves to zero, warning logged, slot does not become free, load not blocked — **PARTIAL, see Completion Notes**
- [x] AC-25 — orphaned `rune_id` still `AVAILABLE`/unimbued: ledger entry retained as `UNKNOWN`/unselectable (greyed out), load not blocked

---

## Implementation Notes

*Derived from ADR-0025 Implementation Guidelines:*

```gdscript
var _forge_resolving: bool = false
# set at start of any operation's first validation step, cleared only after final event emission
```

- The guard spans all three operation types as one shared flag — not three independently-guarded operations that could race against each other. This directly generalizes Crafting's/Defense Building's single-operation-type guards to Equipment Forge's three.
- **Orphaned rune, already imbued**: mirrors `hero.md`'s `class_id` orphan handling. If a save references an item whose `imbued_runes` contains a `rune_id` no longer defined in current game data: retain (don't discard), mark the slot internally as occupied by an `UNKNOWN` rune, its stat contribution resolves to zero (Hero's stat recalculation must defensively treat `UNKNOWN` as a no-op, not a crash), log a warning. The slot does **not** become free again — Rule 15's "never re-imbuable" guarantee must hold even across an orphaning event.
- **Orphaned rune, still `AVAILABLE`**: the ledger entry is retained as `UNKNOWN`/unselectable in the Imbuing UI (greyed out, not deleted) rather than silently vanishing, so a future content patch reintroducing the same `rune_id` can seamlessly reactivate it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 010, 013, 014: the three operation types' own resolution logic (this story covers only the shared guard and orphan handling)
- Story 016: cross-document persistence-ordering (this story covers orphan-on-load handling for content removed from the catalogue, not save/load ordering)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-23**: Concurrency guard rejects second confirmation
  - Given: any two of {equipment craft, rune imbue, creature sacrifice} confirmed in the same frame
  - When: the second confirmation arrives while `_forge_resolving == true` from the first
  - Then: rejected outright with no queueing, regardless of which two of the three types are involved
  - Edge cases: exercise at minimum one same-type pair (craft+craft) and one cross-type pair (imbue+sacrifice)

- **AC-24**: Orphaned imbued rune
  - Given: a save references an item whose `imbued_runes` contains a `rune_id` no longer defined
  - When: the save loads
  - Then: entry retained (not discarded), slot marked internally `UNKNOWN`, stat contribution resolves to zero (no crash on Hero's recalculation), warning logged, slot does not become free again, load not blocked

- **AC-25**: Orphaned available rune
  - Given: a save references a `rune_id` still in `available_runes` that is no longer defined
  - When: the save loads
  - Then: ledger entry retained as `UNKNOWN`/unselectable (greyed out) in the Imbuing UI, load not blocked

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/equipment-forge/concurrency-guard-orphaned-references_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/equipment-forge/concurrency-guard-orphaned-references_test.gd` (15 tests, passing)

---

## Dependencies

- Depends on: Story 010, Story 013, Story 014 (the three operation types this story's guard spans)
- Unlocks: None further within this epic

**Unblocked**: ADR-0025 accepted 2026-07-18 (Sprint 6, S6-04).

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 5/6 fully passing, 1 partial (see below). 15 unit tests, all passing.
**Deviations**:
- **AC-23**: fully implemented — `_forge_resolving` replaces Story 010's narrower `_craft_resolving`, now guarding all 3 of `resolve_craft()`/`resolve_imbue()`/`resolve_sacrifice()`. A real pre-existing test (`tests/unit/equipment-forge/crafting-resolution-material-cost_test.gd`) referenced the old field name directly and was updated as part of this rename, not a new regression.
- **New `is_rune_id_known(rune_id)` single source-of-truth classifier** — this codebase has no unified rune catalogue Resource; the 3 sources are checked individually: Constellation runes (`"rune_<shape_id>"`) against `Constellation.SHAPE_N`'s fixed, code-defined keys (not data-driven content — there is no removable catalogue to orphan against, so any compiled shape is always known); Tarot runes against `TarotCardResource.linked_rune_id`; Menagerie runes against `SacrificeRecipeResource.rune_id`.
- **AC-25 fully implemented**: `_available_runes` entries gain an `is_known` field, re-derived (never persisted) against current game data at `restore_save_data()` time. An orphaned entry is retained (not discarded) and `resolve_imbue()` rejects it — unselectable without being deleted, load is never blocked.
- **AC-24 PARTIAL, real gap not silently solved**: "stat contribution resolves to zero" presumes a rune_id → stat_delta lookup for *already-imbued* items, which is exactly the gap Story 013's Completion Notes already flagged as unresolved (`InventorySlot.imbued_runes` stores only `rune_id` strings, no stat data, and `_available_runes` — the only place `stat_delta` ever lived — is erased on imbue). This story cannot retroactively invent that lookup without expanding its own scope into Story 013's territory. What IS implemented and tested: `is_rune_id_known()` is the correct, reusable classification primitive a future Inventory/Hero-side consumer would call; Inventory's `restore_save_data()` does not currently examine `imbued_runes` for orphans at all (out of this story's reach — that data belongs to Inventory, not Equipment Forge) and does not crash on any rune_id, known or not, since nothing currently reads a stat value from it. Documented here as the same class of pre-existing gap as Story 013's, not a new one introduced by this story.
**Test Evidence**: Logic — `tests/unit/equipment-forge/concurrency-guard-orphaned-references_test.gd`.
**Code Review**: Pending — deferred to a batch pass at a later Equipment Forge checkpoint, per this session's established pattern.
