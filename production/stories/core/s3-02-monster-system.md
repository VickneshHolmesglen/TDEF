# S3-02 — Monster System Implementation

**Story ID**: S3-02
**Epic**: Core
**Layer**: Core
**Type**: Logic + Integration
**Owner**: godot-gdscript-specialist
**Sprint**: 3
**Estimate**: 2.0 days
**Status**: Complete
**Manifest Version**: 2026-05-16

## TR Coverage

| TR-ID | Requirement |
|-------|-------------|
| TR-monster-001 | Spawn via EventBus `monster_spawn_requested`; entity_id assignment |
| TR-monster-002 | HP and speed scaling formulas (wave_index, difficulty_tier) |
| TR-monster-003 | Path consumption via `global_position` update each physics frame |
| TR-monster-004 | Breach detection at path exhaustion (hp > 0 → BREACHED) |
| TR-monster-005 | DEAD-priority guarantee: lethal hit prevents BREACHED in same frame |
| TR-monster-006 | BOSS attack: telegraph delay, locked target, immunity window |

## ADR Governing Implementation

`docs/architecture/adr-0006-monster-movement.md` (Accepted)

**ADR Decision Summary**: Monsters use `Area2D` as root. Movement is position-based
(`global_position` set each physics frame — no `move_and_slide()`). All per-entity
logic runs in `MonsterManager._physics_process` as 4 sequential passes:
Pass 1 (damage drain), Pass 2 (BOSS logic), Pass 3 (movement), Pass 4 (absorbed flush).
Individual `MonsterEntity` nodes define NO `_physics_process`.

**Engine**: Godot 4.6.2 | **Risk**: LOW — Area2D, _physics_process, Array.filter() unchanged through 4.6

## Dependencies

- S2-01 EventBus Autoload — Complete
- S2-03 Grid System — Complete
- S2-04 Pathfinding — Complete

## Files to Create

- `src/core/monster/monster_manager.gd` — MonsterManager autoload (all entity logic)
- `src/core/monster/monster_entity.gd` — MonsterEntity scene script (Area2D root, data only)
- `src/core/monster/monster_damage_taken.gd` — MonsterDamageTaken Resource subclass
- `src/core/monster/MonsterEntity.tscn` — entity scene (Area2D + collision + sprite)
- `tests/unit/monster/monster_spawn_test.gd`
- `tests/unit/monster/monster_movement_test.gd`
- `tests/unit/monster/monster_boss_test.gd`
- `tests/integration/monster/monster_spawn_integration_test.gd`

## Acceptance Criteria

### Spawn (AC-1 to AC-7)
- [ ] AC-1: Monster spawns when `EventBus.monster_spawn_requested` fires with valid args
- [ ] AC-2: Invalid `monster_id` → no entity created, `push_error()` called
- [ ] AC-3: Spawn cell is not of type SPAWN → no entity created, `push_error()` called
- [ ] AC-4: HP scaling: base_hp=300, wave_index=4, difficulty_tier=1, rate=0.15 → scaled_hp=**435.0** exactly
  Formula: `scaled_hp = base_hp × (1 + hp_wave_growth_rate × (wave_index - 1))`
- [ ] AC-5: Speed scaling: base_speed=1.5, wave_index=4, rate=0.06 → scaled_speed=**1.77** (±0.001)
  Formula: `scaled_speed = base_speed × (1 + speed_wave_growth_rate × (wave_index - 1)) × tarot_speed_scalar`
- [ ] AC-6: Empty path from Pathfinding → entity stays in SPAWNING state, not added to `active_monsters`
- [ ] AC-7: Five sequential spawns → entity_ids strictly ascending, no duplicates

### Path Consumption (AC-8 to AC-11)
- [ ] AC-8: 120 physics frames at delta=1/60, speed=2.0 cells/sec → `path_step_index == 4`
  (2.0 cells/sec × 2.0s = 4 cells consumed, assuming path steps are 1 cell apart)
- [ ] AC-9: Path exhausted with hp > 0 → `lifecycle_state == BREACHED`, `monster_breached` fires,
  `monster_died` does NOT fire
- [ ] AC-10: [POST-MVP] `path_invalidated` mid-path reroute — EXCLUDED from this sprint
- [ ] AC-11: Overshoot scenario: speed high enough to skip step → `path_step_index` increments
  by correct amount; GOAL reached mid-overshoot triggers BREACHED same frame

### BOSS Attack (AC-12 to AC-16)
- [ ] AC-12: BOSS `boss_tower_attack_attempted` fires after `boss_attack_prepare_frames` delay
- [ ] AC-13: Attack immunity window: second attack cannot fire within `immunity_duration_sec`
- [ ] AC-14: BOSS movement never halted during attack sequence

### DEAD-Priority (AC-17)
- [ ] AC-17: Monster takes lethal damage in Pass 1 → `lifecycle_state = DEAD` before Pass 3 runs;
  `monster_breached` does NOT fire even if path would be exhausted that same frame

### Performance (deferred to S3-05)
- [ ] AC-28: 150 active monsters processed in `_physics_process` ≤ 4ms — **measured at S3-05**
- [ ] AC-40: `monster_spawned` event propagation ≤ 0.5ms — **measured at S3-05**
- [ ] AC-43: 25 simultaneous `monster_died` emissions within 2ms — **measured at S3-05**

## Implementation Notes (from ADR-0006)

### 4-Pass Architecture

```
MonsterManager._physics_process(delta):
  PASS 1 — DAMAGE PASS
    Drain _pending_damage: Array[MonsterDamageTaken]
    Apply to current_hp; if <= 0 set lifecycle_state = DEAD
    Do NOT remove from active_monsters during iteration

  PASS 2 — BOSS LOGIC PASS
    Decrement scan/prepare/cooldown counters
    Emit boss_tower_attack_attempted when prepare timer hits 0
    Lock _locked_target_id at prepare entry; clear on fire

  PASS 3 — MOVEMENT PASS
    Skip DEAD entities
    Advance ACTIVE entities: velocity = direction × scaled_speed × delta
    global_position += velocity
    On arrival within PATH_ARRIVAL_THRESHOLD: increment path_step_index
    If path exhausted AND not DEAD: lifecycle_state = BREACHED
    Rebuild: active_monsters = active_monsters.filter(func(e): return e.lifecycle_state != DEAD)

  PASS 4 — ABSORBED FLUSH PASS
    Emit monster_hp_absorbed per entity (summed hits from this frame)
    Clear _pending_absorbed
```

### Damage Buffer

`EventBus.monster_damage_taken` subscriber on MonsterManager appends to
`_pending_damage: Array[MonsterDamageTaken]` — does NOT apply inline.
`_pending_damage` cleared at end of Pass 1 each frame.

### MonsterDamageTaken Resource

`monster_damage_taken` signal carries a `MonsterDamageTaken` Resource subclass
(≥5 fields per ADR-0001 → Resource required):
- `entity_id: int`
- `amount: float`
- `source_tower_id: String`
- `is_armored: bool`
- `damage_type: String`

### Co-Occupancy Rule

Use `Area2D` root — NEVER `CharacterBody2D`. Multiple monsters may occupy the
same cell simultaneously. `move_and_slide()` is FORBIDDEN for this system.

## Out of Scope

- AC-10 (path_invalidated reroute) — post-MVP
- Monster animation/VFX (Visual/Feel story, Sprint 4+)
- Tarot scalar application (balance data not yet authored)
- `monster_breached` → sanctuary HP reduction (Hero/Sanctuary system, Sprint 4)

## QA Test Cases

- **AC-4**: HP scaling formula
  - Given: MonsterManager with monster config (base_hp=300, hp_wave_growth_rate=0.15)
  - When: `spawn_monster("goblin", wave_index=4, difficulty_tier=1)` is called
  - Then: entity.scaled_hp == 435.0
  - Edge cases: wave_index=1, difficulty_tier=1 → scaled_hp == base_hp

- **AC-5**: Speed scaling formula
  - Given: monster config (base_speed=1.5, speed_wave_growth_rate=0.06, tarot_speed_scalar=1.0)
  - When: spawned with wave_index=4
  - Then: entity.scaled_speed is within 0.001 of 1.77
  - Edge cases: speed must never fall below 0.1 cells/sec

- **AC-8**: Path consumption timing
  - Given: entity spawned with speed=2.0 cells/sec, path of 10 steps each 1 cell apart
  - When: 120 physics ticks simulated at delta=1/60 (~2.0 seconds)
  - Then: entity.path_step_index == 4
  - Edge cases: PATH_ARRIVAL_THRESHOLD boundary (entity exactly at threshold vs 1 pixel past)

- **AC-9**: Breach detection
  - Given: entity at last path step with hp=1 (alive)
  - When: physics tick causes arrival at final waypoint
  - Then: lifecycle_state == BREACHED; monster_breached fires; monster_died does NOT fire
  - Edge cases: hp=0 at same tick → lifecycle_state = DEAD wins (not BREACHED)

- **AC-17**: DEAD-priority
  - Given: entity at last path step, receives lethal damage in same physics frame
  - When: _physics_process runs (Pass 1 sets DEAD before Pass 3)
  - Then: lifecycle_state == DEAD; monster_died fires; monster_breached does NOT fire

## Test Evidence

**Story Type**: Logic + Integration
**Required evidence**:
- `tests/unit/monster/monster_spawn_test.gd` — AC-1 through AC-7
- `tests/unit/monster/monster_movement_test.gd` — AC-8 through AC-11, AC-17
- `tests/unit/monster/monster_boss_test.gd` — AC-12 through AC-14
- `tests/integration/monster/monster_spawn_integration_test.gd` — EventBus-driven spawn with Grid+Pathfinding stubs

**Status**: [ ] Not yet created

## Dependencies

- Depends on: S2-01 (EventBus), S2-03 (Grid), S2-04 (Pathfinding) — all Complete
- Unlocks: S3-04 (Damage & Status), S3-05 (Combat loop integration), S3-06 (Wave Manager)

## Completion Notes
**Completed**: 2026-07-01
**Criteria**: 14/14 in-scope passing (AC-28/40/43 performance deferred to S3-05 per story spec)
**Deviations**: MonsterDamageTaken pre-existed at `src/foundation/event_bus/event_payloads/` with int source_type enum instead of String fields — consumed correctly, no behavioral impact
**Test Evidence**: Logic: 3 unit test files (spawn, movement, boss) + Integration: monster_spawn_integration_test.gd — all passing (197/197)
**Code Review**: Complete (3-specialist parallel review: GDScript, Engine, QA — all findings applied)
**Tech Debt Logged**: TD-monster-001 (ADR-0001 deferred dispatch), TD-monster-002 (pass4/wave_completed coverage gaps)
