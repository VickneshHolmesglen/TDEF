# Story 010: Mastery Progress & Skill Unlock

> **Epic**: Epic 06 — Mission Combat Extensions
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/tower-mastery.md`
**Requirement**: `TR-towermast-001`

**ADR Governing Implementation**: ADR-0029 (Tower Mastery Proximity-Detection Strategy)
**ADR Decision Summary**: Per-frame work is bounded to `_physics_process` iterating only the already-cached `_signatures_in_range` (O(distinct accruing signatures)), never re-deriving the set itself per frame. `mastery_time` accrues unbounded past 100% to support future multi-tier skills; `progress_percent` is clamped for display only; `skill_unlocked` fires exactly once per `skill_id`, permanently.

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM — live profiling still outstanding (Story 012); this story's own architecture (iterate cached set, not re-derive) is confirmed sound by ADR review
**Engine Notes**: Typed `Dictionary[String, float]` accumulator, no post-cutoff API concerns beyond what `VERSION.md` already verifies.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0029 Key Interfaces directly.
- Forbidden: Never hard-stop `mastery_time` at the unlock threshold — it must continue accumulating past 100% to support a future next-tier skill without a data migration (Rule 14).
- Guardrail: `unlocked_skills[skill_id]` is set to `true` *before* `skill_unlocked` is emitted (Formula 3) — order matters for idempotency.

---

## Acceptance Criteria

*From GDD `design/gdd/tower-mastery.md`, scoped to this story:*

- [x] AC-19 — `mastery_time` sums correctly across mission boundaries (Formula 1 worked example: 18 + 30 = 48)
- [x] AC-20 — `progress_percent` clamps at 100.0 for display even though underlying `mastery_time` exceeds threshold
- [x] AC-21 — `unlocked_skills[skill_id]` set `true` before `skill_unlocked` emits; idempotent same-frame re-evaluation
- [x] AC-22 — Post-unlock accrual continues unbounded; `skill_unlocked` never re-fires for the same `skill_id`
- [x] AC-23 — Two different build signatures accrue independently and in parallel (no "nearest tower wins")

---

## Implementation Notes

*Derived from ADR-0029 Implementation Guidelines:*

```gdscript
func _physics_process(delta: float) -> void:
    if _mission_phase != Phase.WAVE_ACTIVE and _mission_phase != Phase.INTERMISSION:
        return
    for sig in _signatures_in_range:
        _mastery_time[sig] = _mastery_time.get(sig, 0.0) + delta   # Formula 1, O(accruing signatures)
```

- **Formula 2** (progress percent): `progress_percent = clamp(100.0 × mastery_time[build_signature] / mastery_threshold_seconds, 0.0, 100.0)` — emitted via `mastery_progress_updated(tower_id, skill_id, progress_percent)` for each currently-accruing signature with a defined catalogue entry, using the lowest live `tower_id` sharing that signature as the payload's representative `tower_id`. If no catalogue entry exists yet for a signature, no event fires — valid silent no-op.
- **Formula 3** (unlock): `skill_unlocked_event_fires = (mastery_time[build_signature] ≥ mastery_threshold_seconds) AND (unlocked_skills[skill_id] != true)`. Set `unlocked_skills[skill_id] = true` immediately when true, **before** emitting `skill_unlocked(skill_id, source_tower_id)` — this ordering is what makes same-frame re-evaluation idempotent.
- If the hero is simultaneously within radius of two or more different build signatures, each accrues independently and in parallel — never "nearest tower wins."
- Skill catalogue (`SkillDefinitionResource` entries) is a deferred content deliverable per Rule 7/ADR-0030 — this story's tests must treat `"frost_bolt_skill_a"` as an illustrative example, not a real catalogue entry (per the GDD's own Open Questions).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009: the `_signatures_in_range` cache this story iterates (must land first)
- Story 011: cross-mission persistence of `mastery_time`/`unlocked_skills` through save/load and defeat
- Actual skill catalogue content authoring (deferred, Game Designer-owned)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-19**: Cross-mission mastery_time summation
  - Given: `mastery_time["S1"] = 18.0` at Mission 1 end, a different `tower_id` with the same `build_signature` accrues `30.0` more seconds in Mission 2
  - When: Mission 2's accrual completes
  - Then: `mastery_time["S1"] = 48.0` exactly

- **AC-20**: Display clamp, unbounded accumulator
  - Given: `mastery_time["S1"] = 48.0`, `mastery_threshold_seconds = 45.0`
  - When: `mastery_progress_updated` is emitted
  - Then: `progress_percent = 100.0` (clamped) even though the underlying `48.0` exceeds threshold

- **AC-21**: Set-before-emit idempotency
  - Given: `mastery_time["S1"]` crosses `45.0` for the first time the same frame `unlocked_skills["frost_bolt_skill_a"]` is `false`
  - When: that frame resolves
  - Then: `unlocked_skills["frost_bolt_skill_a"]` set `true` before `skill_unlocked` emits, and re-evaluating the same frame's condition afterward yields `false` (cannot double-fire same frame)

- **AC-22**: Unbounded post-unlock accrual, no re-fire
  - Given: `unlocked_skills["frost_bolt_skill_a"] = true`, hero continues accruing proximity to `S1` past threshold
  - When: further physics frames elapse
  - Then: `mastery_time["S1"]` keeps incrementing past `45.0` unbounded, `mastery_progress_updated` keeps firing clamped at `100.0`, `skill_unlocked` never fires again for `"frost_bolt_skill_a"`

- **AC-23**: Parallel multi-signature accrual
  - Given: hero simultaneously within radius of a frost tower (`S1`) and a siege tower (`S2`)
  - When: a physics frame elapses during `WAVE_ACTIVE`
  - Then: both `mastery_time["S1"]` and `mastery_time["S2"]` increment independently and in parallel by the same `delta_time` — neither treated as "nearest tower wins"

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/tower-mastery/mastery-progress-skill-unlock_test.gd` — 7 tests covering AC-19/20/21/22/23. All passing.

**Status**: [x] Created and passing (2026-07-19). Full project regression re-run: 1066/1067 (the sole failure is the same pre-existing, unrelated Menagerie `CreatureInstance.CreatureState` enum-value mismatch, `TD-menag-006` — untouched by this story).

---

## Dependencies

- Depends on: Story 009 (`_signatures_in_range` cache)
- Unlocks: Story 011, Story 013 (visual feedback consumes `mastery_progress_updated`/`skill_unlocked`)

**Unblocked**: ADR-0029 accepted 2026-07-18 (Sprint 6, S6-02).

**Implemented (2026-07-19, Sprint 7 S7-07)**: `tower_mastery.gd`'s `tick()` now emits `mastery_progress_updated(tower_id, skill_id, progress_percent)` every frame for each currently-accruing signature (Formula 2, clamped `[0, 100]` via `clampf`), using a new `_representative_tower_id_for(signature)` helper (lowest live `tower_id` in `_active_signature_by_tower` sharing that signature) for both this event and `skill_unlocked`'s `source_tower_id` — previously hardcoded to `0`. The set-before-emit unlock ordering (Formula 3) and unbounded per-signature accrual (Formula 1, independent/parallel across signatures) were already correct from Story 007/008/009's implementation; this story added explicit regression coverage for them alongside the new Formula 2 behavior. **Skill catalogue caveat** (unchanged from the file's pre-existing placeholder precedent): no real `SkillDefinitionResource` catalogue exists yet (deferred content, Rule 7/ADR-0030) — both `mastery_progress_updated` and `skill_unlocked` use the `build_signature` itself as a placeholder `skill_id` rather than gating on a catalogue lookup. This is documented in the class doc comment as a known simplification to revisit once real catalogue content lands.
