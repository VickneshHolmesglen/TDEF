# Story 010: Run Modifiers & Sole-Emitter Correction

> **Epic**: Epic 07 — Cross-Cutting Flow Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/mission-select.md`
**Requirement**: `TR-missel-001`

**ADR Governing Implementation**: ADR-0028 (Mission Select Runtime State and Retry Architecture)
**ADR Decision Summary**: Mission Select is confirmed as the sole emitter of `run_modifier_selected` — correcting `wave-manager.md`'s previously-loose Interactions table, which listed "Tarot System" as also sending this event. `tarot.md`'s own Rule 8/AC-18 already establishes Tarot as subscribe-only; this GDD is the other half of that correction from the sending side.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No new engine subsystem — pure EventBus emission logic.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0028/mission-select.md Rule 9 directly.
- Forbidden: Mission Select must never clamp, warn, or reject a run modifier's raw value against Wave Manager's own safe ranges (Rule 9's non-duplication decision) — Wave Manager's own existing validation is the sole authority.
- Guardrail: Each modifier toggle emits `run_modifier_selected` immediately (live, on toggle) — never batched or deferred to Launch confirm.

---

## Acceptance Criteria

*From GDD `design/gdd/mission-select.md`, scoped to this story:*

- [x] AC-9 — Mission Select is the only system that ever appears as the `run_modifier_selected` emitter across a full mission lifecycle
- [x] AC-10 — toggling `"extend_waves"` to high fires `run_modifier_selected("extend_waves", 2.0)` immediately, not batched
- [x] AC-11 — Formula 1 worked example: `base_wave_count=6`, `extend_waves_value=2.0` → `requested_wave_count=8` (conceptual only, never transmitted as its own field)
- [x] AC-12 — Formula 2 worked example: `base_r=0.20`, `difficulty_growth_boost_value=0.05` → `requested_r=0.25` (conceptual only)
- [x] AC-13 — no composition-altering modifier exists among the emittable `modifier_id` values (confirms Rule 5's deferral is honored, not just stated)
- [x] AC-14 *(non-duplication)* — emitted payload is bit-identical to the raw stepper selection, regardless of mission's authored `base_wave_count`/`base_r` — emission is not a function of Wave Manager's safe-range constants

---

## Implementation Notes

*Derived from ADR-0028 Implementation Guidelines:*

- Exactly 2 generic run modifiers at Alpha scope: `"extend_waves"` (`0.0`/`1.0`/`2.0`, requests `+0`/`+1`/`+2` waves) and `"difficulty_growth_boost"` (`0.0`/`0.03`/`0.05`, requests additive increase to `difficulty_growth_rate`). Each presented as a 3-position stepper (off/low/high), not a free-form slider.
- Changing a stepper's position emits `run_modifier_selected(modifier_id, modifier_value)` immediately (live, not batched on confirm) — `0.0` serves as the "off" value for both.
- **Formula 1**: `requested_wave_count = base_wave_count + extend_waves_value` — unclamped by this GDD; Wave Manager's own 5–8 safe range is its own clamp responsibility.
- **Formula 2**: `requested_r = base_r + difficulty_growth_boost_value` — unclamped by this GDD; Wave Manager's own 0.10–0.25 hard range is its own clamp responsibility.
- **Non-duplication (Rule 9)**: Mission Select emits raw requested values without clamping against Wave Manager's internal safe ranges — this GDD deliberately does not re-implement or shadow that logic.
- No composition-altering runtime modifier exists at Alpha scope (`game-concept.md`'s "alter wave composition" purpose is achieved at the content-authoring layer instead, per Rule 5's flagged deferral) — deferred to a future revision if a runtime composition modifier is wanted post-Alpha.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 011: the two-step select→configure→launch flow itself (this story covers only the modifier-toggle emission mechanics within CONFIGURING)
- Tarot's own read-only subscription and conflict-indicator logic (Epic 07 Story 002, `tarot.md` Rule 8) — this story is the sending side only

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-9**: Sole-emitter correction
  - Given: a full mission lifecycle (BROWSING → CONFIGURING with modifier toggling → LAUNCHED → mission end)
  - When: every EventBus emission on `run_modifier_selected` across the session is recorded and attributed to its emitter
  - Then: Mission Select is the only system that ever appears as the emitter — Tarot never emits on this channel, nor does any other system

- **AC-10**: Live, immediate emission
  - Given: the `"extend_waves"` stepper set to its high position
  - When: the player toggles it
  - Then: `run_modifier_selected("extend_waves", 2.0)` fires immediately, not batched or deferred to Launch confirm

- **AC-11**: Formula 1 worked example
  - Given: `base_wave_count=6`, `extend_waves_value=2.0`
  - When: `requested_wave_count` is computed
  - Then: equals `8` — never transmitted as its own field, only the raw `modifier_value` (`2.0`) is sent

- **AC-12**: Formula 2 worked example
  - Given: `base_r=0.20`, `difficulty_growth_boost_value=0.05`
  - When: `requested_r` is computed
  - Then: equals `0.25` — never transmitted as its own field

- **AC-13**: No composition modifier exists
  - Given: the Alpha run modifier catalogue (`"extend_waves"`, `"difficulty_growth_boost"`)
  - When: the full set of emittable `modifier_id` values is enumerated
  - Then: no composition-altering modifier (elite density, monster mix) exists among them

- **AC-14**: Non-duplication of clamps
  - Given: a toggle whose resulting `requested_wave_count` (10) or `requested_r` (0.30) would exceed Wave Manager's safe ranges
  - When: Mission Select emits `run_modifier_selected`
  - Then: the raw, unclamped `modifier_value` is sent exactly as selected — no clamping, rejection, or warning at Mission Select's own layer; the emitted payload is bit-identical to the raw stepper selection regardless of the mission's authored base values

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/mission-select/run-modifiers-sole-emitter_test.gd` — must exist and pass

**Status**: [x] Created — `tests/integration/mission-select/run-modifiers-sole-emitter_test.gd` (7 tests, passing)

---

## Dependencies

- Depends on: Story 008 (`MissionEntry` provides `base_wave_count`)
- Unlocks: Story 011 (the flow this modifier logic operates within)

**Unblocked**: ADR-0028 accepted 2026-07-18 (Sprint 6, S6-03).

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 6/6 passing (7 integration tests, all passing, including a static grep-based confirmation that no other src/ file emits run_modifier_selected).
**Deviations**: None.
**Test Evidence**: Integration — `tests/integration/mission-select/run-modifiers-sole-emitter_test.gd`.
**Code Review**: Complete (batch review across Stories 009-014) — APPROVED WITH SUGGESTIONS, all required fixes applied.
