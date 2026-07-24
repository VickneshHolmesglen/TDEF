# Story 003: Hero Auto-Attack

> **Epic**: Core Combat Engine
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-16
> **Estimate**: 3–4 hours

## Context

**GDD**: `design/gdd/hero.md`
**Requirement**: `TR-hero-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Hero Tower-Synced Class + Tower Affinity
**ADR Decision Summary**: Hero System never holds a direct reference to Monster nodes. Target acquisition and targeting priority are computed from the hero's local monster cache (populated via `monster_spawned`/`monster_died` EventBus events, same pattern as Tower System's monster cache in ADR-0007). The hero emits `hero_auto_attacked` as a `HeroAutoAttackEvent` Resource — D&S resolves the actual damage arithmetic.

**Engine**: Godot 4.6.2 | **Risk**: HIGH
**Engine Notes**: `Timer` node (attack cooldown) — unchanged through 4.6. Emitting EventBus signals from non-physics callers uses synchronous `emit()` — auto-attack fires from `_on_attack_timer_timeout()` which is a non-physics callback. `randf()` for crit roll — stable API.

**Control Manifest Rules (Core layer)**:
- Required: Hero holds a local monster cache; target acquisition reads only from cache — no direct Monster node access
- Required: `hero_auto_attacked` emitted synchronously (`EventBus.hero_auto_attacked.emit(payload)`) from Timer timeout — non-physics caller
- Forbidden: Hero calling `monster.apply_damage()` or any direct Monster method
- Guardrail: Target selection is O(monster_cache_size) — acceptable; not per-physics-frame

---

## Acceptance Criteria

*From `design/gdd/hero.md`, scoped to this story:*

- [ ] Rule 3: Hero auto-attacks without player input. One attack fires per attack cycle. CDR does NOT affect auto-attack rate.
- [ ] Rule 4: Target priority: (1) enemy closest to GOAL (furthest along path) within Attack Range; (2) on tie: lower current HP; (3) on tie: first in internal list.
- [ ] Rule 5: Auto-attack always hits the current target — no miss chance.
- [ ] Rule 6: On each swing, Hero: (a) rolls crit against `effective_crit_chance`; (b) reads target archetype tags for `hero_bonus_tier` (0=STANDARD, 1=ELITE, 2=BOSS); (c) computes `crit_multiplier_effective = CRIT_MULTIPLIER_BASE + crit_multiplier_bonus`; (d) emits `hero_auto_attacked` as a `HeroAutoAttackEvent` with exactly 6 fields: `base_damage`, `is_crit`, `target_id`, `crit_multiplier_effective`, `hero_lifesteal_fraction`, `hero_bonus_tier: int`.
- [ ] Rule 7: A swing in progress completes even if the hero moves out of range mid-animation.

---

## Implementation Notes

*Derived from ADR-0010 Implementation Guidelines and hero.md Rules 3–7:*

```gdscript
# Monster cache: same pattern as Tower System (ADR-0007)
var _monster_cache: Dictionary = {}
# Key: monster_id: int
# Value: { path_progress: float, hp: float, archetype_tags: Array[StringName] }

func _ready() -> void:
    EventBus.monster_spawned.connect(_on_monster_spawned)
    EventBus.monster_died.connect(_on_monster_died)
    EventBus.monster_hp_changed.connect(_on_monster_hp_changed)

func _on_attack_timer_timeout() -> void:
    var target_id := _select_target()
    if target_id == -1:
        return  # No target in range
    var entry := _monster_cache[target_id]
    var is_crit: bool = randf() < get_effective_stat(&"crit_chance")
    var bonus_tier: int = _resolve_bonus_tier(entry.archetype_tags)
    var payload := HeroAutoAttackEvent.new()
    payload.base_damage = get_effective_stat(&"damage")
    payload.is_crit = is_crit
    payload.target_id = target_id
    payload.crit_multiplier_effective = CRIT_MULTIPLIER_BASE + get_effective_stat(&"crit_multiplier")
    payload.hero_lifesteal_fraction = get_effective_stat(&"lifesteal")
    payload.hero_bonus_tier = bonus_tier
    EventBus.hero_auto_attacked.emit(payload)
```

`_select_target()` iterates `_monster_cache` and returns the `monster_id` of the monster with highest `path_progress` within `get_effective_stat(&"attack_range")` world units. Requires that `monster_spawned` provides the monster's world position for range checking.

`CRIT_MULTIPLIER_BASE: float = 1.75` — constant, not a stat.

The `hero_bonus_tier` mapping: `[&"BOSS"] → 2`, `[&"ELITE"] → 1`, else `0`.

**HeroAutoAttackEvent** is a Resource subclass (5+ fields — ADR-0001 Rule 3). Define in `src/core/hero/hero_auto_attack_event.gd`.

---

## Out of Scope

- **Story 004**: Damage arithmetic (AC-03, AC-04 — owned by D&S System via ADR-0007)
- **Story 006**: Proximity accumulation (uses monster cache indirectly via position, not targeting)
- Attack animation VFX — deferred to Visual/Feel story (art bible dependency)

---

## QA Test Cases

- **Rule 3**: Auto-attack rate independence from CDR
  - Given: Hero with `cdr = 0.75` (max) and `attack_speed = 1.0` (1 attack/sec)
  - When: Attack timer fires twice over 2 seconds
  - Then: Attack timer interval is unchanged by CDR — fires at base rate
  - Edge cases: CDR = 0.0 (no change); CDR = 1.0 (clamped to 0.75 — still no effect on attack rate)

- **Rule 4**: Target priority — path progress
  - Given: Two monsters in range: Monster A at path_progress=0.8 (near goal), Monster B at path_progress=0.3
  - When: `_select_target()` is called
  - Then: Monster A is selected (highest path_progress)
  - Edge cases: Tie on path_progress → lower HP wins; tie on path_progress AND hp → first in cache

- **Rule 6**: HeroAutoAttackEvent payload correctness
  - Given: Hero with `damage=90`, `crit_chance=1.0` (always crit), `crit_multiplier=0.25` (bonus), targeting an ELITE monster
  - When: `_on_attack_timer_timeout()` fires
  - Then: `payload.base_damage = 90.0`, `payload.is_crit = true`, `payload.crit_multiplier_effective = 2.0` (1.75 + 0.25), `payload.hero_bonus_tier = 1` (ELITE), `payload.hero_lifesteal_fraction = get_effective_stat(&"lifesteal")`
  - Edge cases: No target in range → no event emitted; BOSS tag → `hero_bonus_tier = 2`

- **Rule 7**: In-progress swing completes
  - Given: Hero mid-swing (timer fires, event queued)
  - When: Hero moves out of attack range before the event propagates
  - Then: `hero_auto_attacked` event still fires with original target_id
  - (Note: This is a non-blocking advisory test — the Timer callback fires atomically)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/hero/hero_auto_attack_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (stat resolution — `get_effective_stat(&"damage")` etc. must exist)
- Unlocks: Story 004 (combat formula integration — needs Hero emitting correct payload first)

## Completion Notes
**Completed**: 2026-07-03
**Criteria**: 5/5 passing (Rule 3, Rule 4, Rule 5, Rule 6, Rule 7). 13/13 automated tests passing, 0 errors, 0 failures, 0 orphans.
**Deviations**: Advisory only — story's pseudocode referenced a nonexistent `monster_hp_changed` signal and fictional `archetype_tags` data model, corrected to mirror `TowerSystem`'s shipped monster-cache pattern (real `tier: int` via GameDataRegistry, `path_step_index` as the path-progress substitute); Rule 6's QA test assumed `crit_chance=1.0` guarantees a crit, but the already-shipped stat cap clamps it to 0.8 — resolved with a deterministic no-crit test plus a statistically-safe smoke test; auto-attack has no phase-gating yet (safely inert today, story-008 will add it once `HeroPhase` exists — anticipated by the epic's own dependency order, not a defect).
**Test Evidence**: Logic — `tests/unit/hero/hero_auto_attack_test.gd` (13 tests, all passing)
**Code Review**: Complete — 1 Required Change found and fixed (no test proved the real `Timer` node's wiring end-to-end; all prior tests invoked the callback manually). Re-reviewed, verdict APPROVED.
