# Story 003: Mastery Progression

> **Epic**: Epic 07 — Cross-Cutting Flow Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/tarot.md`
**Requirement**: `TR-tarot-002`

**ADR Governing Implementation**: ADR-0027 (Tarot Modifier Aggregation Pipeline)
**ADR Decision Summary**: `mastery_tier` is never independently stored — it is always derived from `_mastery_missions_played` via Formula F6's threshold lookup (`{0, 3, 8, 15, 25}` → tiers 0–4). A single method `_on_mission_terminal(outcome)` increments the counter for every card present in `_active_mission_deck` at mission end, regardless of outcome.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No new engine subsystem — pure Dictionary-counter logic.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0027 directly.
- Forbidden: Never store `mastery_tier` as an independent field — always recompute from `_mastery_missions_played` (guarantees "no tier-desync risk" structurally, not by convention).
- Guardrail: Mastery scaling affects magnitude only — never changes `modifier_type`, never adds modifier entries, never affects deck-slot cost.

---

## Acceptance Criteria

*From GDD `design/gdd/tarot.md`, scoped to this story:*

- [x] AC-21 — an equipped card's `mastery_missions_played` increments by exactly 1 on `MISSION_COMPLETE`
- [x] AC-22 — mastery/discovery persist through `DEFEAT`, byte-identical to `MISSION_COMPLETE`'s side effects
- [x] AC-23 — a card NOT present in `_active_mission_deck` for a mission has no `mastery_missions_played` change
- [x] AC-24 — F6 tier lookup: `mastery_missions_played = 10` resolves to tier `2` (Adept), identically whether read immediately or later
- [x] AC-25 — F1 mastery scaling: verified with `swift_current`'s real content value (`base_modifier_value=1.69`) at tier 2 (`m=1.30`) → `effective_modifier_value = 2.197`, exercising the exact formula the AC's own `1.30`-example specifies
- [x] AC-26 — mastery tier-up changes magnitude only: `modifier_type` unchanged, no new entries, deck-slot cost unchanged

---

## Implementation Notes

*Derived from ADR-0027 Implementation Guidelines:*

```gdscript
const MASTERY_TIER_THRESHOLDS := [0, 3, 8, 15, 25]
const MASTERY_TIER_SCALARS := [1.00, 1.15, 1.30, 1.50, 1.75]

func _lookup_mastery_tier(card_id: StringName) -> int:
    var p: int = _mastery_missions_played.get(card_id, 0)
    var tier := 0
    for t in range(MASTERY_TIER_THRESHOLDS.size()):
        if p >= MASTERY_TIER_THRESHOLDS[t]:
            tier = t
    return tier
```

- `_on_mission_terminal(outcome)`: invoked on `mission_phase_changed → MISSION_COMPLETE` or `→ DEFEAT` (both trigger identically — Rule 10/EC-5's explicit no-outcome-gate). For each `card_id` in `_active_mission_deck`, increment `_mastery_missions_played[card_id]`.
- Formula F6: `mastery_tier = max { t : p >= threshold[t] }`, thresholds `{0:0, 1:3, 2:8, 3:15, 4:25}` — monotonic non-decreasing, terminal at 4.
- Formula F1: `effective_modifier_value = base_modifier_value × mastery_tier_scalar` — unbounded at this stage, clamped downstream at F2 aggregation (Story 002), never per-card.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: rune discovery firing (the same `_on_mission_terminal` handler triggers both — this story covers only the mastery-counter half)
- Story 002: F1's consumption at emission time (this story only produces the tier the emission reads)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-21**: Mastery XP increments on completion
  - Given: an equipped card present in `_active_mission_deck` at `MISSION_COMPLETE`
  - When: the terminal `mission_phase_changed` fires
  - Then: `mastery_missions_played` increments by exactly 1, exactly once

- **AC-22**: Mastery persists through defeat
  - Given: an equipped card present at `DEFEAT`
  - When: the terminal `mission_phase_changed` fires
  - Then: `mastery_missions_played` still increments by exactly 1 — byte-identical to `MISSION_COMPLETE` — test both terminal states and assert identical side effects, differing only in which phase triggered them

- **AC-23**: Non-equipped cards unaffected
  - Given: a card NOT present in `_active_mission_deck`
  - When: the mission ends (either outcome)
  - Then: its `mastery_missions_played` does not change

- **AC-24**: F6 boundary lookup
  - Given: `mastery_missions_played = 10`
  - When: `mastery_tier` is read
  - Then: resolves to `2` (Adept) — identically whether read immediately after increment or independently later

- **AC-25**: F1 scaling computation
  - Given: a `tarot_speed_scalar_mult` card with `base_modifier_value = 1.30` at `mastery_tier = 2` (`m=1.30`)
  - When: `effective_modifier_value` is computed at SCOUT entry
  - Then: equals exactly `1.30 × 1.30 = 1.69`

- **AC-26**: Tier-up affects magnitude only
  - Given: a card's `mastery_tier` increases across missions
  - When: its `mission_modifier_applied` output is compared before/after the tier-up
  - Then: `modifier_type` unchanged, no new modifier entry appears, deck-slot cost unchanged

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/tarot/mastery-progression_test.gd` — 8 tests covering AC-21/22/23/24/25/26. All passing.

**Status**: [x] Created and passing (2026-07-19). Full project regression re-run: 1153/1154 (the sole failure is the same pre-existing, unrelated Menagerie `CreatureInstance.CreatureState` enum-value mismatch, `TD-menag-006` — untouched by this story).

---

## Dependencies

- Depends on: Story 001 (card/deck model)
- Unlocks: Story 002 (consumes tier lookup), Story 004 (shares the same terminal-event handler)

**Unblocked**: ADR-0027 accepted 2026-07-18 (Sprint 6, S6-03).

**Implemented (2026-07-19, Sprint 7)**: added `_mastery_missions_played: Dictionary[StringName, int]` and replaced Story 002's `_lookup_mastery_tier()` stub with the real Formula F6 threshold lookup (`MASTERY_TIER_THRESHOLDS = [0, 3, 8, 15, 25]`). Added `_on_mission_terminal(outcome)`, wired into `_on_mission_phase_changed`'s existing MISSION_COMPLETE/DEFEAT branch alongside Story 001's deck-unlock — increments every `_active_mission_deck` card's counter by 1, identically regardless of outcome (Rule 10/EC-5's explicit no-outcome-gate). Added `get_mastery_missions_played()`/`get_mastery_tier()` public queries. `mastery_tier` is never stored — always recomputed, exactly per the ADR's structural no-desync guarantee. Live-verified via gdUnit4: 8/8 new tests passing (35/35 across all 3 Tarot test files); full regression 1153/1154 (same pre-existing unrelated `TD-menag-006` failure). **Unblocks Story 004** (shares the same `_on_mission_terminal()` handler for rune discovery).
