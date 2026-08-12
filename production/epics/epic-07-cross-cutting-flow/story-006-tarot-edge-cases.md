# Story 006: Edge Cases

> **Epic**: Epic 07 — Cross-Cutting Flow Systems
> **Status**: Complete (all 4 ACs — AC-37/38 unblocked 2026-08-12 by ADR-0036)
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/tarot.md`
**Requirement**: `TR-tarot-001`

**ADR Governing Implementation**: ADR-0027 (Tarot Modifier Aggregation Pipeline)
**ADR Decision Summary**: Covers the GDD's 9 documented edge cases (EC-1 through EC-9) — 0-card decks, out-of-range clamping, REPLACE-type conflicts, structurally-impossible mid-mission unlocks, DEFEAT mastery accrual, invalid `WaveConfig` overrides, additive rune stacking, and intended double-dipping.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No new engine subsystem — this story exercises already-built logic (Stories 001–004) against boundary/degenerate inputs.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0027/tarot.md Edge Cases directly.
- Forbidden: Never crash or block mission launch on an invalid `tarot_wave_config_override` target — log and gracefully degrade, mirroring wave-manager.md's own established content-error pattern.
- Guardrail: A 0-card deck is not necessarily a 0-modifier mission — previously-discovered rune bonuses still apply, since runes are permanent and deck-composition-independent.

---

## Acceptance Criteria

*From GDD `design/gdd/tarot.md`, scoped to this story:*

- [x] AC-36 *(EC-1)* — 0 equipped cards at `mission_launched`: zero `mission_modifier_applied` events, previously-discovered rune bonuses still apply (`tarot_speed_scalar` itself is Monster System's own value, not Tarot's — Tarot has no way to assert it stays at 1.0 from its own file)
- [x] AC-37 *(EC-2)* — aggregate outside `[0.50, 2.00]` clamps at the boundary, no mission-launch block. **RESOLVED 2026-08-12 (ADR-0036)**: implemented in Monster System's `_on_mission_modifier_applied()` — F2 multiplicative aggregate, clamped [0.50, 2.00]. Also fixed a real pre-existing bug found during the ADR's authoring: the handler previously checked `modifier_type == "monster_speed_scalar"`, a string that matched nothing Tarot ever emits. Tested in `tests/unit/monster/monster_tarot_speed_scalar_test.gd`.
- [x] AC-38 *(EC-6)* — invalid `tarot_wave_config_override` target: override discarded, content-error logged, mission proceeds with original `WaveConfig`. **RESOLVED 2026-08-12 (ADR-0036)**: implemented in Wave Manager's `_on_mission_modifier_applied()`. Every event of this type currently takes the fallback path by construction — `mission_modifier_applied`'s payload has no field capable of encoding a target `WaveConfig` variant identifier, a data-model gap flagged in ADR-0036, not fixed by it. Tested in `tests/unit/wave_manager/wave_manager_reward_scalar_test.gd::test_tarot_wave_config_override_always_takes_fallback_path`.
- [x] AC-39 *(EC-9)* — a card whose rune is `DISCOVERED` later unequipped and never re-equipped: rune's F5 bonus continues applying every mission

---

## Implementation Notes

*Derived from ADR-0027 Implementation Guidelines / tarot.md's Edge Cases section:*

- **EC-1**: 0-card deck emits zero `mission_modifier_applied` events. Wave Manager's `WaveConfig`/F1 output used unmodified (Mission-Select modifiers still apply per Rule 8 step 1). `tarot_speed_scalar` remains at registered default `1.0`. Not an error state. Previously-discovered rune bonuses (Rule 16) still apply since they're permanent and deck-composition-independent.
- **EC-2**: aggregate clamp at boundary, warning log format: `"tarot_speed_scalar aggregate [raw value] clamped to [0.50|2.00] — equipped cards: [list of source_card_id]."` Mission proceeds with the clamped value.
- **EC-3**: covered in Story 002 (AC-16) — REPLACE single-card enforcement.
- **EC-4**: structurally impossible (mid-mission card discovery) — no runtime guard needed, `_active_mission_deck` is locked and Sanctuary is unreachable during a mission.
- **EC-5**: covered in Story 003/004 (AC-22) — DEFEAT preserves mastery/discovery identically to MISSION_COMPLETE.
- **EC-6**: `tarot_wave_config_override` target invalid/missing → Wave Manager discards the override, logs: `"tarot_wave_config_override targeting [variant_id] has no valid alternate WaveConfig for mission [mission_id] — using mission's default WaveConfig."` Mirrors wave-manager.md's own established content-error pattern (its own EC-6, EC-11).
- **EC-7**: covered in Story 005 (AC-34) — additive rune stacking, clamped `[0.00, 0.30]`.
- **EC-8**: covered in Story 004 (AC-31) — intended double-dip.
- **EC-9**: unequipping a card with a `DISCOVERED` rune never revokes the rune's bonus — discovery is permanent and deck-composition-independent by design.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002 (AC-16, EC-3), Story 003/004 (AC-22, EC-5), Story 004 (AC-31, EC-8), Story 005 (AC-34, EC-7) — this story covers only the edge cases not already assigned elsewhere (EC-1, EC-2, EC-6, EC-9)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-36**: 0-card deck, EC-1
  - Given: a deck with 0 cards equipped at `mission_launched`
  - When: SCOUT entry resolves
  - Then: zero `mission_modifier_applied` events, `tarot_speed_scalar` remains `1.0`, `WaveConfig`/F1 output affected only by Mission Select modifiers (if any), any previously-discovered rune bonuses still apply

- **AC-37**: Out-of-range clamp, EC-2
  - Given: an aggregate raw value outside `[0.50, 2.00]` for `tarot_speed_scalar`
  - When: it is clamped
  - Then: mission proceeds with the clamped boundary value, warning logged listing every offending `source_card_id`, no mission-launch block

- **AC-38**: Invalid wave config override, EC-6
  - Given: a `tarot_wave_config_override` card whose target variant does not exist for the current mission
  - When: Wave Manager attempts to apply it
  - Then: override discarded, specified content-error log fires, mission proceeds with originally-authored `WaveConfig` unmodified — no crash, no launch block
  - Edge cases: only this negative/fallback path is currently testable; the positive path (Story 002's AC-15) is blocked on missing content

- **AC-39**: Rune bonus survives permanent unequip, EC-9
  - Given: a card whose rune is `DISCOVERED` is later unequipped and never re-equipped
  - When: subsequent missions resolve
  - Then: the rune's F5 bonus continues to apply every mission, unaffected by the card's absence from the deck

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/tarot/edge-cases_test.gd` — 3 tests covering AC-36/39. AC-37/38 explicitly not implemented (no placeholder tests — an empty passing test would misrepresent coverage that doesn't exist), tracked here instead.

**Status**: [x] Created and passing for AC-36/39 (2026-07-19). **AC-37/38 evidence added 2026-08-12 (ADR-0036)** — `tests/unit/monster/monster_tarot_speed_scalar_test.gd` (6 tests) and `tests/unit/wave_manager/wave_manager_reward_scalar_test.gd` (8 new tests). Full regression: 2084/2084 passing.

---

## Dependencies

- Depends on: Story 001, Story 002, Story 004
- Unlocks: Story 007 (persistence, which relies on these boundary behaviors being correct)

**Unblocked**: ADR-0027 accepted 2026-07-18 (Sprint 6, S6-03).

**Implemented (2026-07-19, Sprint 7)**: AC-36 (0-card deck emits nothing; previously-discovered rune bonuses still apply via `compute_rune_bonus()`, deck-composition-independent) and AC-39 (a permanently-unequipped card's discovered rune keeps contributing every subsequent mission, while its mastery counter correctly freezes since Rule 10 only increments while equipped) both verified against real Tarot production code — no new production code was needed, both already fell out of Stories 001-005's existing design. **AC-37/38 are genuinely blocked**, not fabricated: both require Monster System's/Wave Manager's own `mission_modifier_applied` consumption-side aggregation/clamp logic, and neither subscribes to that signal anywhere in this codebase (confirmed by inspection) — the same downstream gap Story 002's own AC-15/17 already flagged. Live-verified via gdUnit4: 3/3 new tests passing (38/38 across all 6 Tarot test files); full regression 1171/1172 (same pre-existing unrelated `TD-menag-006` failure). **Unblocks Story 007** (persistence) for the parts of this story that are Complete.
