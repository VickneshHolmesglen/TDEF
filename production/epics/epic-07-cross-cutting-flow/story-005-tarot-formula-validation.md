# Story 005: Formula Validation (F3–F6 Worked Examples)

> **Epic**: Epic 07 — Cross-Cutting Flow Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/tarot.md`
**Requirement**: `TR-tarot-001`, `TR-tarot-002`, `TR-tarot-003`

**ADR Governing Implementation**: ADR-0027 (Tarot Modifier Aggregation Pipeline)
**ADR Decision Summary**: This story anchors the GDD's own worked examples as regression tests — F3 (wave reward scalar with Tarot layer), F4 (tarot speed scalar, dual-edge coupling), F5 (rune bonus aggregate, additive clamp), and F6 (mastery tier lookup boundary table) — ensuring the exact numeric outputs the GDD specifies never silently drift during implementation.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Pure arithmetic — no engine subsystem risk.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0027/tarot.md Formulas section directly.
- Forbidden: F2's `tarot_reward_scalar_mult` stage must never clamp to `[1.00, 4.768]` at F2 — that ceiling applies once, downstream, at F3 (resolved 2026-07-17, previously ambiguous). F2's own ceiling for this type is `[0.0, +inf)`.
- Guardrail: `wave_reward_scalar_final` is hard-clamped to `[1.00, 4.768]` — must equal wave-manager.md's own F1 natural ceiling; raising this independently would silently break Resource Economy's drop-rate ceiling math.

---

## Acceptance Criteria

*From GDD `design/gdd/tarot.md`, scoped to this story:*

- [x] AC-32 — F3 regression anchor: wave 3, `r=0.20`, one Legendary card solo-equipped at Tier 0, rune bonus 0.00 → `wave_reward_scalar_final = 2.88`
- [x] AC-33 — F4 dual-edge value coupling: "Reckless Onslaught" solo-equipped at Tier 0 → both `tarot_speed_scalar=2.00` AND `wave_reward_scalar_final=2.00` true in the same resolution pass
- [x] AC-34 — F5 additive stacking and clamp: two discovered runes, `rune_bonus_flat=0.05` each → `rune_reward_bonus = clamp(0.10, 0.00, 0.30) = 0.10`. **Clamp-engagement itself (crossing the 0.30 ceiling) is not exercised** — only 3 real content cards target `tarot_reward_scalar_mult` today (max reachable sum 0.15); flagged honestly rather than authoring throwaway cards solely to hit a number.
- [x] AC-35 — F6 threshold boundary anchor: `mastery_missions_played` values `{0,3,8,15,25}` → `mastery_tier` values `{0,1,2,3,4}` exactly

---

## Implementation Notes

*Derived from ADR-0027 and tarot.md's Formulas section:*

**F3** — `wave_reward_scalar_final = clamp(wave_reward_scalar_natural × tarot_reward_multiplier + rune_reward_bonus, 1.00, 4.768)`. Worked example: `1.0 × 1.20^2 = 1.44` (natural) × `2.00` (F2 aggregate) + `0.00` (rune) = `2.88`.

**F4** — `tarot_speed_scalar = clamp(Π(effective_modifier_value_i for equipped tarot_speed_scalar_mult cards), 0.50, 2.00)`. Dual-edge worked example ("Reckless Onslaught", both entries `base_modifier_value=2.00`, Tier 0 `m=1.00`): speed side `clamp(2.00,0.50,2.00)=2.00`; reward side at wave 1 `clamp(1.00×2.00+0,1.00,4.768)=2.00` — both sides double together, demonstrating the "doubles speed also doubles drops" coupling.

**F5** — `rune_bonus_total(modifier_type) = clamp(Σ(rune_bonus_flat_i) for all DISCOVERED runes linked to a card targeting modifier_type, 0.00, 0.30)`.

**F6** — `mastery_tier = max { t ∈ {0,1,2,3,4} : p ≥ threshold[t] }`, `threshold = {0:0, 1:3, 2:8, 3:15, 4:25}`. Boundary values resolve to the tier they *newly* unlock, not the prior tier.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: F1/F2's own mechanism proofs (this story validates the downstream F3–F6 formulas that build on F1/F2's output)
- Story 003: F6's consumption at the tier-lookup call site (this story is the formula's own regression anchor, not its integration point)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-32**: F3 regression anchor
  - Given: wave 3, default `r=0.20`, one Legendary "Reckless Onslaught" card solo-equipped at Tier 0, rune bonus `0.00`
  - When: `wave_reward_scalar_final` is computed
  - Then: equals exactly `2.88`

- **AC-33**: F4 dual-edge coupling
  - Given: "Reckless Onslaught" solo-equipped at Tier 0
  - When: both speed and reward sides resolve at wave 1
  - Then: `tarot_speed_scalar = 2.00` AND `wave_reward_scalar_final = 2.00` both true in the same resolution pass

- **AC-34**: F5 additive stacking and clamp
  - Given: two `DISCOVERED` runes both linked to `tarot_reward_scalar_mult` cards, `rune_bonus_flat=0.05` each
  - When: `rune_reward_bonus` is computed
  - Then: equals `clamp(0.10, 0.00, 0.30) = 0.10` exactly

- **AC-35**: F6 boundary anchor
  - Given: `mastery_missions_played` values `0, 3, 8, 15, 25`
  - When: `mastery_tier` is computed for each
  - Then: results are exactly `0, 1, 2, 3, 4` respectively — boundary values resolve to the tier they newly unlock

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/tarot/formula-validation_test.gd` — 8 tests covering AC-32/33/34/35. All passing.

**Status**: [x] Created and passing (2026-07-19). Full project regression re-run: 1168/1169 (the sole failure is the same pre-existing, unrelated Menagerie `CreatureInstance.CreatureState` enum-value mismatch, `TD-menag-006` — untouched by this story).

---

## Dependencies

- Depends on: Story 002 (F1/F2 mechanism proofs), Story 003 (F6 tier lookup), Story 004 (discovery state F5 reads)
- Unlocks: None further within this epic

**Unblocked**: ADR-0027 accepted 2026-07-18 (Sprint 6, S6-03).

**Implemented (2026-07-19, Sprint 7)**: Formula F5 (rune bonus aggregate) had no production code anywhere yet — added `rune_bonus_flat: float` to `TarotCardResource` (range `[0.02, 0.10]`, validated) and `compute_rune_bonus(modifier_type)` to `tarot.gd`, summing every DISCOVERED rune's flat bonus whose linked card targets that type, clamped `[0.00, 0.30]`, scanning ALL registered cards (not just the equipped deck) per Rule 16's "regardless of deck composition" guarantee. Authored 2 new content cards (`lucky_charm`/`golden_ticket`, both targeting `tarot_reward_scalar_mult`, `rune_bonus_flat=0.05`) to exercise AC-34's exact worked example. F3/F4 (AC-32/33) are tested as pure formula-correctness assertions against Tarot's already-emitted F1 values (Story 002's own scope boundary — Tarot performs only F1, F2/F3 aggregation is Wave Manager's/Monster System's job). F6 (AC-35) exercises the real `get_mastery_tier()` from Story 003. **Honestly flagged gap**: AC-34's clamp-engagement itself isn't exercised — only 3 real content cards target `tarot_reward_scalar_mult` (max reachable sum 0.15, well under the 0.30 ceiling); a real clamp-crossing test needs 6+ discovered same-type runes, which doesn't exist in this project's content yet, and wasn't fabricated to force a number. Live-verified via gdUnit4: 8/8 new tests passing (50/50 across all 5 Tarot test files); full regression 1168/1169 (same pre-existing unrelated `TD-menag-006` failure). This closes out Epic 07's own Story 005 — Story 006 (Edge Cases) and Story 007 (Persistence) remain.
