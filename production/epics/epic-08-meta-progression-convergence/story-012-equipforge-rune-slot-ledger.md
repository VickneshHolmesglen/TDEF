# Story 012: Rune Slot Model & Available Rune Ledger

> **Epic**: Epic 08 — Meta-Progression Convergence
> **Status**: Complete
> **Layer**: Advanced
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/equipment-forge.md`
**Requirement**: `TR-equipforge-003`

**ADR Governing Implementation**: ADR-0025 (Equipment Forge Cross-System Aggregation)
**ADR Decision Summary**: Every Equipment item has a fixed rune slot count determined solely by `output_slot` category. The Available Rune Ledger (`Dictionary[StringName, Dictionary]` keyed `rune_id`) is populated exclusively by `constellation_rune_discovered`/`tarot_rune_discovered` subscriptions — Menagerie-sourced runes are explicitly excluded by construction, never staged here.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No new engine subsystem — typed Dictionary logic only.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0025 directly.
- Forbidden: Menagerie-sourced runes must never enter `available_runes` — Rule 19's sacrifice resolution flow never writes into it, closing Rule 13's asymmetry at the data-structure level, not left as a convention a future maintainer could violate.
- Guardrail: `stat_delta` (Formula 3) is authored entirely by Equipment Forge itself — deliberately decoupled from whatever internal mechanical effect Constellation or Tarot separately apply for that same discovery.

---

## Acceptance Criteria

*From GDD `design/gdd/equipment-forge.md`, scoped to this story:*

- [x] AC-13 — `rune_slot_count` per `output_slot` matches Rule 11's table exactly: weapon=2, armor=2, accessory_a/b=1, trinket=1
- [x] AC-14 — `constellation_rune_discovered`/`tarot_rune_discovered` populate `available_runes` in state `AVAILABLE` with the correct `rune_source` and an Equipment-Forge-authored `stat_delta`
- [x] AC-15 — `creature_sacrificed` never adds a new entry to `available_runes` — Menagerie-sourced runes are never staged as a separate imbuable entry

---

## Implementation Notes

*Derived from ADR-0025 Implementation Guidelines:*

```gdscript
var _available_runes: Dictionary[StringName, Dictionary] = {}   # rune_id -> {rune_source, stat_delta}
```

- Rune slot count table (Rule 11): `weapon`=2, `armor`=2, `accessory_a`/`accessory_b`=1, `trinket`=1. Total possible simultaneously-imbued runes across a full 5-slot loadout: 7. Small, fixed counts are deliberate — "which item gets this rune" must stay a real decision.
- **Formula 3** (rune stat bonus magnitude, guideline not strict formula): `additive` bonus 0.02–0.08 per rune (feeds Hero's `additive_bonus_total`); `flat` bonus hand-authored per targeted stat, ~3–10% of that stat's typical mid-game value (feeds Hero's `flat_bonus` term). Not formula-derived — a content-authoring decision constrained by a guideline range.
- Deliberately decoupled from source-system internals: these values are authored entirely within Equipment Forge's own data, independent of Constellation's `bonus_value` or Tarot's `mastery_tier_scalar` — the same discovery event legitimately feeds two unrelated bonus systems at two different magnitudes.
- A Menagerie-sourced rune is never added to `available_runes` as a separate imbuable entry — it's consumed immediately, in the same operation that creates it, into a newly-crafted Equipment item (Story 014). This is the one deliberate asymmetry between the three rune sources, flagged explicitly, not an oversight.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 013: the actual Rune Imbuing action that consumes ledger entries
- Story 014: Menagerie-sourced rune creation itself (this story only confirms it never touches this ledger)
- Story 016: persistence of this ledger across save/load

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-13**: Rune slot count table
  - Given: a freshly-crafted item for each `output_slot` value
  - When: `rune_slot_count` is read
  - Then: matches Rule 11's table exactly — weapon=2, armor=2, accessory_a/accessory_b=1, trinket=1

- **AC-14**: Ledger population from Constellation/Tarot
  - Given: `constellation_rune_discovered(rune_id, pattern_id)` fires for a `rune_id` not previously in `available_runes`
  - When: the event is processed
  - Then: the rune enters `available_runes` in state `AVAILABLE` with `rune_source="constellation"` and an Equipment-Forge-authored `stat_delta`, independent of any value Constellation applies internally
  - Edge cases: given the same sequence for `tarot_rune_discovered(rune_id, card_id)`, the equivalent holds with `rune_source="tarot"`

- **AC-15**: Menagerie runes never staged in ledger
  - Given: a `creature_sacrificed` event fires
  - When: `available_runes` is inspected immediately after
  - Then: no new entry was added to it — a Menagerie-sourced rune is never staged as a separate imbuable entry

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/equipment-forge/rune-slot-model-ledger_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/equipment-forge/rune-slot-model-ledger_test.gd` (9 tests, passing)

---

## Dependencies

- Depends on: Story 010 (crafted items provide the `rune_slot_count` this story validates)
- Unlocks: Story 013, Story 016

**Unblocked**: ADR-0025 accepted 2026-07-18 (Sprint 6, S6-04).

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 3/3 passing (9 unit tests, all passing).
**Deviations**: Implemented BEFORE Story 011 despite the numbering — Story 011's own Dependencies section lists this story as a prerequisite (its persistence payload needs this ledger to exist first), a real sequencing correction found while working the epic, not an arbitrary reordering.
**Test Evidence**: Logic — `tests/unit/equipment-forge/rune-slot-model-ledger_test.gd`.
**Code Review**: Pending — deferred to a batch pass at a later Equipment Forge checkpoint, per this session's established pattern.
