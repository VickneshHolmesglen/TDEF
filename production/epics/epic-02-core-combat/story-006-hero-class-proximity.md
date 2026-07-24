# Story 006: Tower-Synced Class Proximity

> **Epic**: Core Combat Engine
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-05-16
> **Estimate**: 4–5 hours

## Context

**GDD**: `design/gdd/hero.md`
**Requirement**: `TR-hero-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Hero Tower-Synced Class + Tower Affinity
**ADR Decision Summary**: During WAVE_ACTIVE and INTERMISSION phases, `_physics_process` checks each tower in `_tower_cache` using Chebyshev distance. If any tower is within CLASS_PROXIMITY_RADIUS (3 cells), its archetype accumulates time in `_proximity_time[archetype] += delta`. When `_proximity_time[archetype] >= CLASS_UNLOCK_THRESHOLD_S`, that archetype is unlocked as a primary class. During SCOUT phase, no accumulation occurs. Once a class is designated (at SCOUT start), it locks and cannot change.

**Engine**: Godot 4.6.2 | **Risk**: HIGH
**Engine Notes**: Physics process proximity accumulation — must use `call_deferred` for any EventBus emissions from `_physics_process`. `Vector2i` Chebyshev distance = `maxi(abs(a.x - b.x), abs(a.y - b.y))` — `maxi()` confirmed available. Integration test timing: use `await get_tree().create_timer(N).timeout` to simulate elapsed time, OR directly manipulate `_proximity_time` dictionary for deterministic unit-level testing. **Corrected during readiness review**: `mission_phase_changed` is `(previous_phase: String, new_phase: String, timestamp: float)` — 3 args, `String` not `StringName` — not the 1-arg `StringName` stub this story originally sketched. `hero.gd` does not yet subscribe to `mission_phase_changed` at all; this story must add that subscription.

**Control Manifest Rules (Core layer)**:
- Required: `_physics_process` budget ≤ 0.3 ms/frame — proximity check is O(tower_cache_size); for MVP this is acceptable at typical tower counts (≤50)
- Required: `hero_class_unlocked` emitted via `EventBus.hero_class_unlocked.emit.call_deferred(archetype, is_deep)` from `_physics_process` — physics caller
- **Resolved during readiness review**: `hero_class_unlocked` now exists in the EventBus catalogue as `signal hero_class_unlocked(archetype: StringName, is_deep: bool)` (updated from a stale `class_id: String` 1-arg declaration to match ADR-0010's 2-arg contract — `is_deep` supports a future 90s deep-unlock story; this story always passes `false`).
- Forbidden: Accumulating proximity time outside of WAVE_ACTIVE and INTERMISSION mission phases
- Guardrail: `_proximity_active` bool flag gates the physics process proximity loop — flip once on phase change, not per-frame

---

## Acceptance Criteria

*From `design/gdd/hero.md`, scoped to this story:*

- [ ] AC-09: GIVEN the hero is within CLASS_PROXIMITY_RADIUS (3 Chebyshev cells) of a FROST tower for 30 cumulative seconds during WAVE_ACTIVE, WHEN the threshold is reached, THEN `hero_class_unlocked` is emitted with `(archetype=&"FROST", is_deep=false)` and `_primary_class` is set
- [ ] AC-10: GIVEN the hero is within range of a FROST tower during the SCOUT phase, WHEN time passes, THEN `_proximity_time[&"FROST"]` does NOT accumulate — SCOUT phase is excluded from proximity tracking
- [ ] AC-11: GIVEN a primary class is already designated (e.g., from a previous run or on SCOUT start), WHEN a new WAVE_ACTIVE begins, THEN the class designation is locked — no new class can be designated even if another archetype hits 30 seconds

---

## Implementation Notes

*Derived from ADR-0010 Implementation Guidelines:*

```gdscript
const CLASS_PROXIMITY_RADIUS: int = 3
const CLASS_UNLOCK_THRESHOLD_S: float = 30.0  # primary class
const CLASS_UNLOCK_THRESHOLD_ADVANCED_S: float = 90.0  # advanced class (if applicable)

var _proximity_time: Dictionary[StringName, float] = {}
var _proximity_active: bool = false   # true only during WAVE_ACTIVE/INTERMISSION
var _primary_class: StringName = &""  # locked once set
var _class_locked: bool = false

func _physics_process(delta: float) -> void:
    if not _proximity_active or _class_locked:
        return
    var hero_cell: Vector2i = GGrid.world_to_cell(global_position)
    for tower_id: int in _tower_cache:
        var entry: Dictionary = _tower_cache[tower_id] as Dictionary
        var tower_cell: Vector2i = entry["cell"] as Vector2i
        var dist: int = maxi(abs(hero_cell.x - tower_cell.x), abs(hero_cell.y - tower_cell.y))
        if dist <= CLASS_PROXIMITY_RADIUS:
            var arch: StringName = entry["archetype"] as StringName
            _proximity_time[arch] = _proximity_time.get(arch, 0.0) + delta
            if _proximity_time[arch] >= CLASS_UNLOCK_THRESHOLD_S:
                _primary_class = arch
                _class_locked = true
                # is_deep=false: this story only implements the 30s primary unlock.
                # The 90s deep-unlock case (is_deep=true) is out of scope here — see
                # CLASS_UNLOCK_THRESHOLD_ADVANCED_S below, deferred to a future story.
                GEventBus.hero_class_unlocked.emit.call_deferred(arch, false)
                break  # class locked — stop accumulating

## Real signal (verified against src/foundation/event_bus/event_bus.gd):
##   mission_phase_changed(previous_phase: String, new_phase: String, timestamp: float)
## 3 args, String not StringName — corrected from this story's original 1-arg
## StringName stub, which does not match the actual EventBus signature.
##
## BUG FIX (found in code review, after initial implementation): the SCOUT
## branch originally force-set _class_locked = true unconditionally, matching
## this sketch's earlier text. Since SCOUT is the FIRST phase of every mission
## (design/gdd/hero.md's phase table), that permanently disabled Tower-Synced
## Class unlocking after the very first SCOUT transition for any playthrough
## that hadn't already unlocked a class — i.e. nearly all of them. Fixed: only
## force-lock on SCOUT entry if a primary class has actually been designated
## (design/gdd/hero.md:337 — "no classes unlocked when SCOUT begins... is a
## valid early-game state", not a permanent one).
func _on_mission_phase_changed(_previous_phase: String, new_phase: String, _timestamp: float) -> void:
    match new_phase:
        "WAVE_ACTIVE", "INTERMISSION":
            _proximity_active = true
        "SCOUT":
            _proximity_active = false
            if _primary_class != &"":
                _class_locked = true  # AC-11: re-affirm lock, only if already designated
        _:
            _proximity_active = false
```

**EventBus prerequisite (resolved)**: `EventBus.hero_class_unlocked(archetype: StringName, is_deep: bool)` already exists in `src/foundation/event_bus/event_bus.gd` — added during this story's readiness review.

**Integration test strategy**: Rather than waiting 30 real seconds, directly inject `_proximity_time[&"FROST"] = 29.9` into the Hero instance after `add_child()` and then call `_physics_process(0.2)` to trigger the threshold crossing. This is valid deterministic integration testing.

---

## Out of Scope

- **Story 005**: Tower cache maintenance (prerequisite — `_tower_cache` must be populated)
- **Story 007**: Skill system (advanced class unlock at 90s may feed Ultimate recompute — not covered here)
- **Story 008**: Save/load of `_proximity_time` and `_primary_class` state

---

## QA Test Cases

- **AC-09**: Class unlock at threshold
  - Given: Hero with `_tower_cache` containing one FROST tower at Chebyshev distance 2 from hero; `_proximity_active = true`; `_proximity_time[&"FROST"] = 29.9`
  - When: `_physics_process(0.2)` is called
  - Then: `_primary_class == &"FROST"`; `hero_class_unlocked` signal emitted with `(&"FROST", false)`; `_class_locked = true`
  - Edge cases: Distance exactly 3 → counts; distance 4 → does not count; `_proximity_time = 29.5 + 0.3` → unlock fires on the frame that crosses 30.0

- **AC-10**: Scout phase guard
  - Given: `_proximity_active = false` (SCOUT phase); FROST tower in range
  - When: `_physics_process(30.0)` is called (simulating 30 full seconds)
  - Then: `_proximity_time` is empty or zero — no accumulation occurred; no `hero_class_unlocked` emitted

- **AC-11**: Class lock on SCOUT phase start
  - Given: Hero in WAVE_ACTIVE; `_primary_class = &"FROST"`; `_class_locked = true`
  - When: `_on_mission_phase_changed("SCOUT", "WAVE_ACTIVE", 0.0)` called again (re-enter wave)
  - Then: `_primary_class` remains `&"FROST"` — FIRE proximity cannot displace it even if FIRE accumulates past 30s
  - **Bug-fix companion case**: Given a SCOUT entry with NO primary class designated yet (`_primary_class == &""`), `_class_locked` must NOT be force-set — otherwise proximity accumulation is permanently disabled for the rest of the playthrough after the first mission (found in code review, fixed; see `test_class_proximity_bugfix_scout_before_any_unlock_does_not_permanently_disable_unlocking`)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/hero/hero_class_proximity_test.gd` — must exist and pass
**Status**: [x] `tests/integration/hero/hero_class_proximity_test.gd` — 8/8 passing (verified via headless gdUnit4 run)

---

## Dependencies

- Depends on: Story 005 (tower cache must be populated before proximity can use it); Story 002 (hero position tracking — `Grid.world_to_cell` must work)
- **Prerequisite action (done)**: `hero_class_unlocked(archetype: StringName, is_deep: bool)` signal added to `src/foundation/event_bus/event_bus.gd` during readiness review
- Unlocks: Story 007 (advanced class state feeds Ultimate recompute); Story 008 (class state saved in lifecycle story)

---

## Completion Notes
**Completed**: 2026-07-04
**Criteria**: 3/3 passing (AC-09, AC-10, AC-11)
**Deviations**: Advisory only — pre-approved scope narrowing to ADR-0010's simpler 30s-primary-unlock subset (90s deep-unlock and SCOUT-entry secondary-class computation deferred to Story 007/008)
**Test Evidence**: Integration — `tests/integration/hero/hero_class_proximity_test.gd`, 8/8 passing; full suite 406/406, 0 errors/failures
**Code Review**: Complete — first pass found a BLOCKING bug (SCOUT phase unconditionally force-locking class designation, permanently disabling unlocking after the first mission for nearly all playthroughs); fixed and re-reviewed to APPROVED (godot-gdscript-specialist, godot-specialist, qa-tester all confirmed the fix and its regression tests)
