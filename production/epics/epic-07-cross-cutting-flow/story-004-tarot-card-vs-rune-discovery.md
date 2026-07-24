# Story 004: Card vs. Rune Distinction & Discovery

> **Epic**: Epic 07 — Cross-Cutting Flow Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/tarot.md`
**Requirement**: `TR-tarot-003`

**ADR Governing Implementation**: ADR-0027 (Tarot Modifier Aggregation Pipeline)
**ADR Decision Summary**: `_rune_discovered: Dictionary[StringName, bool]` is a one-way-terminal ledger, identical shape and semantics to Constellation's (ADR-0022) and Crafting's (ADR-0023) Discovery Ledgers. The same `_on_mission_terminal(outcome)` method that accrues mastery (Story 003) also checks first-ever mission attempt and fires `tarot_rune_discovered` exactly once per `linked_rune_id`.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No new engine subsystem — mirrors the already-established Discovery Ledger pattern.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0027 directly.
- Forbidden: Never re-fire `tarot_rune_discovered` for an already-`DISCOVERED` `linked_rune_id`, even if `mastery_time` is somehow reset (it never legitimately is).
- Guardrail: A discovered rune's fixed additive bonus (Formula F5) applies every mission thereafter, unconditionally — regardless of current deck composition.

---

## Acceptance Criteria

*From GDD `design/gdd/tarot.md`, scoped to this story:*

- [x] AC-27 — an unequipped card fires no `mission_modifier_applied` at SCOUT entry
- [x] AC-28 — first-ever mission attempt with a card equipped fires `tarot_rune_discovered` exactly once, ledger transitions to `DISCOVERED`
- [x] AC-29 — an already-`DISCOVERED` rune never re-fires `tarot_rune_discovered`, regardless of further mission attempts
- [x] AC-30 *(data-level — F5's actual bonus math is Story 005's scope)* — a `DISCOVERED` rune's ledger state is readable independent of whether its linked card is currently equipped
- [x] AC-31 *(data-level — F5's actual bonus math is Story 005's scope)* — a `DISCOVERED` rune whose card IS equipped: the card's own Group 3 effect still emits normally, unsuppressed by discovery bookkeeping

---

## Implementation Notes

*Derived from ADR-0027 Implementation Guidelines:*

- A **card** is the deck-building unit (many exist, player chooses ≤5 to slot per mission, effect active only while equipped). A **rune** is a permanent, discovery-gated, always-on bonus layer tied 1:1 to a specific card via `linked_rune_id`, independent of whether that card is currently equipped.
- `_on_mission_terminal(outcome)` (shared with Story 003's mastery accrual): for each `card_id` in `_active_mission_deck`, if this is the card's first-ever mission attempt (counter was `0` before this increment) and `_rune_discovered[card.linked_rune_id]` is not yet `true`, set it `true` and emit `tarot_rune_discovered(rune_id, card_id)`.
- Discovery bar is deliberately the permissive "any mission attempt" (MISSION_COMPLETE **or** DEFEAT) — engagement, not victory, is what proves the card out. This is flagged in the GDD as its single most swappable assumption (see Open Questions) — if playtesting shows first-rune discovery happens too early, this would need to move to `MISSION_COMPLETE`-only.
- Unequipping a card only removes its own Group 3 effect — it can never "undiscover" a rune (EC-9).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: the mastery-counter half of `_on_mission_terminal` (shares the same handler, different concern)
- Story 005: Formula F5's additive rune-bonus aggregate computation and clamp (this story covers discovery firing, not the bonus math)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-27**: Unequipped card produces no modifier
  - Given: a card is unequipped
  - When: SCOUT entry resolves
  - Then: no `mission_modifier_applied` fires for that card's entries

- **AC-28**: First discovery
  - Given: a card's linked rune is `UNDISCOVERED`, card completes its first mission attempt while equipped
  - When: the terminal `mission_phase_changed` fires
  - Then: `tarot_rune_discovered(rune_id, card_id)` fires exactly once, ledger transitions to `DISCOVERED` permanently

- **AC-29**: No re-fire once discovered
  - Given: a rune already `DISCOVERED`
  - When: the same card completes further mission attempts (equipped or not)
  - Then: `tarot_rune_discovered` does not fire again for that `rune_id`

- **AC-30**: Deck-independent bonus application
  - Given: a `DISCOVERED` rune whose linked card is NOT currently equipped
  - When: a mission resolves
  - Then: the rune's fixed additive bonus (F5) still applies to its `modifier_type`

- **AC-31**: Intended double-dip
  - Given: a `DISCOVERED` rune whose linked card IS also currently equipped
  - When: a mission resolves
  - Then: both the card's own Group 3 effect and the rune's F5 additive bonus apply together — neither suppresses the other

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/tarot/card-vs-rune-discovery_test.gd` — 8 tests covering AC-27/28/29/30/31 plus EC-9 and an orphaned-card-id guard. All passing.

**Status**: [x] Created and passing (2026-07-19). Full project regression re-run: 1161/1162 (the sole failure is the same pre-existing, unrelated Menagerie `CreatureInstance.CreatureState` enum-value mismatch, `TD-menag-006` — untouched by this story).

---

## Dependencies

- Depends on: Story 001 (card/deck model), Story 003 (shares `_on_mission_terminal`)
- Unlocks: Story 005 (F5 bonus math consumes this discovery state), Encyclopedia/Equipment Forge downstream (Epic 08)

**Unblocked**: ADR-0027 accepted 2026-07-18 (Sprint 6, S6-03).

**Implemented (2026-07-19, Sprint 7)**: added `_rune_discovered: Dictionary[StringName, bool]` (one-way-terminal, identical shape to Constellation's/Crafting's Discovery Ledgers). Extended the shared `_on_mission_terminal()` handler: "first-ever attempt" is checked BEFORE the mastery counter increments (a card whose counter reads 0 this call), then `_maybe_discover_rune()` fires `tarot_rune_discovered` exactly once per `linked_rune_id`, permanently. Added `is_rune_discovered()` query. AC-30/31 tested at the data level this story actually owns (ledger state is deck-independent; a card's own Group 3 effect keeps emitting normally after its rune is discovered) — Formula F5's real additive-bonus aggregation math is explicitly Story 005's own scope, not fabricated here. Live-verified via gdUnit4: 8/8 new tests passing (43/43 across all 4 Tarot test files); full regression 1161/1162 (same pre-existing unrelated `TD-menag-006` failure). **Unblocks Story 005**.
