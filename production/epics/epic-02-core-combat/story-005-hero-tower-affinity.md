# Story 005: Hero Tower Affinity

> **Epic**: Core Combat Engine
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-16
> **Estimate**: 3–4 hours

## Context

**GDD**: `design/gdd/hero.md`
**Requirements**: `TR-hero-002`, `TR-hero-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Hero Tower-Synced Class + Tower Affinity
**ADR Decision Summary**: Hero maintains a `_tower_cache: Dictionary` (tower_id → {archetype, cell}). Tower Affinity stat bonus = `tower_affinity_stat × clampf(sqrt(float(qualifying_towers) / TOWERS_AFFINITY_REFERENCE), 0.0, 2.0)`. Only towers whose archetype matches the hero's primary class archetype count as "qualifying". TOWERS_AFFINITY_REFERENCE = 16.

**Engine**: Godot 4.6.2 | **Risk**: HIGH
**Engine Notes**: `Dictionary[int, Dictionary]` typed-hint syntax requires Godot 4.4+ — not adopted here; implementation uses an untyped `Dictionary` matching `_monster_cache`'s existing convention. **Corrected during implementation**: `sqrtf()` is NOT a valid Godot 4.6.2 GDScript builtin — confirmed by a real headless test run that failed with `Parse Error: Function "sqrtf()" not found in base self.` Use plain `sqrt()` instead (it already accepts/returns float). `clampf()` confirmed available and correctly used. The tower cache is populated via EventBus events (`tower_placed`, `tower_removed`, `tower_destroyed`) — these are non-physics callers; connect in `_ready()`. Note: `tower_placed`/`tower_removed`/`tower_destroyed` all carry `archetype: String`, not `StringName` — cast at cache-insert time to match `_primary_class`'s `StringName` type.

**Control Manifest Rules (Core layer)**:
- Required: Hero never accesses Tower nodes directly — `_tower_cache` is populated exclusively via EventBus (`tower_placed`, `tower_removed`, `tower_destroyed`)
- Required: Affinity bonus is computed in `get_effective_stat(&"tower_affinity")` using `_count_qualifying_towers()` — not cached as a field
- Forbidden: Hero calling `TowerSystem.get_towers_in_range()` or any TowerSystem method
- Guardrail: `_count_qualifying_towers()` is O(tower_cache_size) — acceptable; called only on affinity stat read or class change, not per-frame

---

## Acceptance Criteria

*From `design/gdd/hero.md`, scoped to this story:*

- [ ] AC-07: GIVEN a hero with Tower Affinity stat = 1.0 and 4 qualifying towers placed, WHEN `get_effective_stat(&"tower_affinity")` is called, THEN result = `1.0 × sqrt(4/16) = 1.0 × 0.5 = 0.5`
- [ ] AC-08: GIVEN the hero's primary class is FROST, WHEN affinity is computed, THEN only FROST-archetype towers count as qualifying — FIRE towers and BASIC towers in `_tower_cache` do not contribute to the qualifying count
- [ ] EC-1 (corrected — see ADR-0010): GIVEN enough qualifying towers that `sqrt(N/16)` exceeds `TOWER_AFFINITY_BONUS_CAP`, WHEN affinity is computed, THEN the multiplier is clamped to `TOWER_AFFINITY_BONUS_CAP = 2.0` (ADR-0010's real cap constant, not the story's original stale 1.0 figure — e.g. 100 qualifying towers → sqrt(100/16)≈2.5, clamped to 2.0)
- [ ] EC-2 (corrected — see ADR-0010): GIVEN no primary class is designated (`_primary_class == &""`, the pre-Story-006 default), WHEN affinity is computed, THEN ALL cached towers count as qualifying (unfiltered) per ADR-0010's `_recompute_tower_affinity()` — result is 0.0 only when the tower cache is also empty, not merely because no primary class is set

---

## Implementation Notes

*Derived from ADR-0010 Implementation Guidelines:*

```gdscript
const TOWERS_AFFINITY_REFERENCE: float = 16.0
const TOWER_AFFINITY_BONUS_CAP: float = 2.0

var _tower_cache: Dictionary = {}
# _tower_cache[tower_id: int] = { "archetype": StringName, "cell": Vector2i }
# Untyped Dictionary — matches _monster_cache's existing convention.

var _primary_class: StringName = &""
# Default empty means no primary class designated yet (pre-Story-006 state).

func _ready() -> void:
    GEventBus.tower_placed.connect(_on_tower_placed)
    GEventBus.tower_removed.connect(_on_tower_removed)
    GEventBus.tower_destroyed.connect(_on_tower_destroyed)

func _on_tower_placed(tower_id: int, grid_position: Vector2i, archetype: String, _footprint: Vector2i, _placed_in_scout: bool) -> void:
    _tower_cache[tower_id] = { "archetype": StringName(archetype), "cell": grid_position }

func _on_tower_removed(tower_id: int, _grid_position: Vector2i, _archetype: String) -> void:
    _tower_cache.erase(tower_id)

func _on_tower_destroyed(tower_id: int, _grid_position: Vector2i, _archetype: String, _footprint: Array) -> void:
    _tower_cache.erase(tower_id)

# Per ADR-0010: when no primary class is set, ALL cached towers qualify (unfiltered) —
# NOT zero. True zero only occurs when the cache is also empty.
func _count_qualifying_towers() -> int:
    if _primary_class == &"":
        return _tower_cache.size()
    var count: int = 0
    for tower_id: int in _tower_cache:
        var entry: Dictionary = _tower_cache[tower_id] as Dictionary
        if entry["archetype"] == _primary_class:
            count += 1
    return count

# Override in get_effective_stat for tower_affinity:
func get_effective_stat(stat_name: StringName) -> float:
    var base_result := _compute_stat_formula(stat_name)
    if stat_name == &"tower_affinity":
        return _apply_tower_affinity_bonus(base_result)
    return base_result

func _apply_tower_affinity_bonus(base_result: float) -> float:
    var qualifying: int = _count_qualifying_towers()
    # sqrt(), not sqrtf() — sqrtf() is NOT a valid Godot 4.6.2 GDScript builtin
    # (confirmed by a real headless test run that failed to parse). clampf() is real.
    var bonus_multiplier: float = clampf(
        sqrt(float(qualifying) / TOWERS_AFFINITY_REFERENCE),
        0.0,
        TOWER_AFFINITY_BONUS_CAP
    )
    return base_result * bonus_multiplier
```

**Important (corrected)**: `_primary_class` is a plain `StringName` field (not a method call), defaulting to `&""` until Story 006 populates it via class unlock. When empty, `_count_qualifying_towers()` returns the full unfiltered cache size — this is the ADR-0010-correct behavior, not zero.

The `tower_placed` event must include the archetype in its payload. Verify this is consistent with the Tower System's implementation from Sprint 3 (`production/stories/core/s3-03-tower-system.md`) before implementing.

---

## Out of Scope

- **Story 006**: Class designation and unlock (needed before `_get_primary_class_archetype()` returns a real value)
- **Story 001**: Formula 1 effective stat foundation (must exist first)
- Tower placement visuals — tower_placed event is already wired in the Tower System (Sprint 3 Complete)

---

## QA Test Cases

- **AC-07**: Affinity formula with 4 qualifying towers
  - Given: Hero with `_base_stats[&"tower_affinity"] = 1.0`; primary class = &"FROST"; 4 FROST towers in `_tower_cache`
  - When: `get_effective_stat(&"tower_affinity")` is called
  - Then: Result ≈ 0.5 (`1.0 × sqrt(4/16) = 0.5`)
  - Edge cases: 1 tower → ≈ 0.25; 9 towers → 0.75; 16 towers → 1.0; 25 towers → 1.0 (clamped)

- **AC-08**: Primary class archetype filter
  - Given: Hero primary class = &"FROST"; `_tower_cache` has 2 FROST towers + 3 FIRE towers + 1 BASIC tower
  - When: `_count_qualifying_towers()` is called
  - Then: Returns 2 (only FROST towers qualify)
  - Edge cases: No primary class designated (`&""`) → returns `_tower_cache.size()` (all towers count, unfiltered — corrected per ADR-0010; the story's original "returns 0" text was wrong)

- **EC-1 (corrected)**: Cap at `TOWER_AFFINITY_BONUS_CAP`
  - Given: 100 FROST towers in cache, primary class = &"FROST"
  - When: `get_effective_stat(&"tower_affinity")` is called
  - Then: `multiplier = 2.0` (clamped from sqrt(100/16) ≈ 2.5)
  - Note: 20 towers is NOT enough to clamp — sqrt(20/16) ≈ 1.118, well under the 2.0 cap; only included here as a non-clamped regression check, not the cap-triggering case

- **EC-2 (corrected)**: No primary class vs. true zero
  - Given: No primary class set, 4 mixed-archetype towers in cache
  - When: `get_effective_stat(&"tower_affinity")` is called
  - Then: All 4 count unfiltered — result = sqrt(4/16) = 0.5, NOT 0.0
  - True zero case: no primary class AND empty cache → result = 0.0

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/hero/hero_tower_affinity_test.gd` — must exist and pass
**Status**: [x] `tests/unit/hero/hero_tower_affinity_test.gd` — 12/12 passing (verified via headless gdUnit4 run)

---

## Dependencies

- Depends on: Story 001 (stat formula foundation must exist)
- Unlocks: Story 006 (class proximity accumulation — uses `_tower_cache` indirectly for archetype matching)

---

## Completion Notes
**Completed**: 2026-07-04
**Criteria**: 4/4 passing (AC-07, AC-08, EC-1, EC-2)
**Deviations**: Advisory only — (1) affinity computed fresh on every read rather than cached per ADR-0010's literal text (approved, avoids stale-cache risk before Story 006); (2) TD-hero-001 logged below (Formula 2's Damage/Skill Power application not yet wired up)
**Test Evidence**: Logic — `tests/unit/hero/hero_tower_affinity_test.gd`, 12/12 passing; full suite 398/398, 0 errors/failures
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (godot-gdscript-specialist, godot-specialist, qa-tester all clean/no blocking issues; 2 recommended follow-up edge-case tests, non-blocking)
