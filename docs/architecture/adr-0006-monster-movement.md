# ADR-0006: Monster Movement — Position-Based Area2D with Centralized 4-Pass Physics

## Status
Proposed

## Date
2026-05-22

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core / 2D Scene / Animation |
| **Knowledge Risk** | LOW — Area2D, AnimatedSprite2D, `_physics_process`, and `Array.filter()` are 2D APIs unchanged through Godot 4.6. Jolt physics default (4.6) affects 3D only; 2D physics is unaffected. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm `AnimatedSprite2D` overlay alpha-compositing renders correctly on pinned Godot 4.6.2 build before shipping BOSS art. Confirm `Array.filter()` behaves as expected on `Array[MonsterEntity]` typed arrays. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (EventBus — Accepted: all cross-system comms via EventBus); ADR-0004 (Pathfinding — Accepted: `get_path(from_cell, tier)` API contract); ADR-0005 (Grid — Accepted: direct-call exception for spatial queries) |
| **Enables** | ADR-0007 (Damage pipeline — `_pending_damage` buffer pattern locked here; D&S ADR references it) |
| **Blocks** | Monster System implementation stories cannot start until this ADR is Accepted |
| **Ordering Note** | Must be Accepted before ADR-0007 so the damage buffer and absorbed-accumulator pattern are established before the Damage & Status pipeline ADR references them |

## Context

### Problem Statement

The Monster System must move 100+ entities simultaneously each physics frame, buffer incoming damage without mutating state mid-iteration, and guarantee that a monster whose HP reaches 0 in the same frame it arrives at a GOAL cell is treated as DEAD — not BREACHED. These three requirements combine to demand a specific processing architecture; an uncoordinated approach (per-entity `_physics_process`) cannot enforce the ordering guarantee.

Additionally, BOSS entities require overlaid walk and attack animations that play simultaneously without mutual interruption. Godot's `AnimationTree` additive blend nodes cannot blend two independent `SpriteFrames` frame-index timelines. An alternative must be chosen before art asset production begins.

### Constraints

- 100+ simultaneous entities at 60 FPS — per-entity scene nodes that each run `_physics_process` independently carry significant overhead and make DEAD-priority ordering across entities non-deterministic
- `CharacterBody2D.move_and_slide()` physically separates entities sharing a cell — monsters must be able to co-occupy PATH and SPAWN cells (GDD Rule 9 / EC-1.3)
- The `_pending_damage` buffer must drain in a single deterministic pass before movement executes, or a lethal hit and GOAL arrival in the same frame may produce a BREACHED entity with `current_hp <= 0` — an invalid state
- BOSS animation must layer walk + attack without `AnimationTree` additive blending (not supported for `SpriteFrames` in Godot 4.6)

### Requirements

- Must support 100+ simultaneous entities at 60 FPS within 2 ms/frame (AC-28)
- Must enforce DEAD-priority over BREACHED when both conditions occur in the same frame (EC-3.1)
- Must buffer damage events and apply them in a single pass before movement executes
- Must allow unlimited co-occupancy of grid cells by monster entities
- Must produce at most one `monster_hp_absorbed` event per entity per frame regardless of hit count (AC-35)
- BOSS entities must play walk and attack animations simultaneously without interrupting each other

## Decision

### Movement Model: Position-Based via `global_position`

Monster entities use `Area2D` as their scene root (established by ADR-0002) and move by directly setting `global_position` each physics frame rather than using `CharacterBody2D.move_and_slide()`. Velocity is computed as `direction × scaled_speed × delta`; `global_position` is set to the result. This is "position-based movement" — the entity teleports by a small delta each frame rather than interacting with Godot's physics solver.

**Why not `CharacterBody2D.move_and_slide()`**: `move_and_slide()` invokes the physics solver to push overlapping bodies apart. This violates the co-occupancy requirement (EC-1.3) and would prevent multiple monsters from occupying the same cell simultaneously. It also makes position deterministic only if the physics solver state is deterministic, which it is not when entities interact.

### Processing Architecture: 4-Pass Centralized `MonsterManager._physics_process`

All per-entity logic — damage application, BOSS attack, movement, absorbed flush — runs in a single centralized `_physics_process` method on `MonsterManager`. Individual `MonsterEntity` scene nodes do NOT define their own `_physics_process`. The four passes execute sequentially in fixed order every frame:

```
MonsterManager._physics_process(delta):

  PASS 1 — DAMAGE PASS
  ├─ Drain _pending_damage: Array[MonsterDamageTaken] (buffered since last frame)
  ├─ For each MonsterDamageTaken event in order:
  │    apply amount to current_hp
  │    if current_hp <= 0: set lifecycle_state = DEAD (do NOT remove from active_monsters yet)
  └─ Do not modify active_monsters during this pass (undefined behaviour in GDScript iteration)

  PASS 2 — BOSS LOGIC PASS
  ├─ For each non-DEAD BOSS in active_monsters:
  │    (a) if boss_scan_frames_remaining > 0: decrement
  │    (b) if boss_scan_frames_remaining <= 0: execute Grid.get_towers_in_range() scan;
  │         reset to boss_scan_interval_frames after scan fires
  │    (c) if boss_attack_prepare_remaining > 0: decrement; if reaches 0, emit boss_tower_attack_attempted
  │         using _locked_target_id; clear _locked_target_id = -1; reset boss_attack_cooldown_remaining
  │    (d) decrement boss_attack_cooldown_remaining by delta, clamp to 0
  │    (e) if scan results available + cooldown=0 + prepare=0: enter prepare phase (set
  │         boss_attack_prepare_remaining = boss_attack_prepare_frames; set _locked_target_id)
  └─ BOSS movement continues — boss is never halted to attack (Rule 16)

  PASS 3 — MOVEMENT PASS
  ├─ Skip DEAD entities
  ├─ Advance all ACTIVE entities toward current_path[path_step_index]
  ├─ On arrival (within PATH_ARRIVAL_THRESHOLD): increment path_step_index
  ├─ If path_step_index >= current_path.size(): trigger breach (BREACHED wins only if not DEAD)
  └─ Rebuild active_monsters as single filter pass:
       active_monsters = active_monsters.filter(func(e): return e.lifecycle_state != DEAD)
       (Replaces Array.erase() in a loop — avoids undefined iteration behaviour)

  PASS 4 — ABSORBED FLUSH PASS
  ├─ For each (entity_id, total_absorbed) in _pending_absorbed:
  │    emit monster_hp_absorbed (payload: entity_id, absorbed = floor(total_absorbed))
  └─ Clear _pending_absorbed entirely
```

**DEAD-priority guarantee**: Because Pass 1 (damage) always runs before Pass 3 (movement), a lethal hit sets `lifecycle_state = DEAD` before the movement pass checks for GOAL arrival. A DEAD entity is skipped in Pass 3 — BREACHED is never reached. This is deterministic and implementable: the ordering is structural, not conditional.

### Damage Buffer: `_pending_damage: Array[MonsterDamageTaken]`

The EventBus `monster_damage_taken` subscriber on `MonsterManager` appends the event to `_pending_damage` immediately on receipt. It does NOT apply damage inline. All damage resolution happens in Pass 1 of `_physics_process`. This decouples damage delivery timing (EventBus dispatch, which can happen from anywhere) from damage application timing (always Pass 1).

`_pending_damage` is cleared at the end of Pass 1 each frame.

### Absorbed Accumulator: `_pending_absorbed: Dictionary[int, float]`

When a monster absorbs damage but survives (`current_hp > 0` after hit), the hit amount is accumulated into `_pending_absorbed[entity_id]` rather than emitting `monster_hp_absorbed` immediately. Multiple hits on the same entity in one frame sum into one dictionary entry. Pass 4 emits exactly one `monster_hp_absorbed` event per entity per frame regardless of hit count, then clears the dictionary.

`_pending_absorbed` is also cleared by the `wave_completed` handler as a safety measure (handles the edge case where `wave_completed` fires mid-frame before Pass 4 runs). An entity is never in this map when `lifecycle_state == DEAD` — the lethal-hit handler erases the entity's entry from `_pending_absorbed` before triggering the death sequence.

### BOSS Animation: Two Stacked `AnimatedSprite2D` Nodes

BOSS entities use two stacked `AnimatedSprite2D` child nodes rather than `AnimationTree`. This enables simultaneous walk and attack animation without requiring additive blending:

```
Area2D  (BOSS root)
├── AnimatedSprite2D  (base layer — "walk" animation, always playing during ACTIVE)
└── AnimatedSprite2D  (overlay layer)
      SpriteFrames: "idle_overlay" (single transparent frame, looped), "attack_prepare", "attack"
```

The overlay plays `"idle_overlay"` during non-attack phases (invisible by default). On prepare-phase entry it plays `"attack_prepare"`; on fire it plays `"attack"`. Base layer is never interrupted.

**Why not `AnimationTree`**: Godot 4 `AnimationTree` additive blend nodes blend keyframe values (transforms, properties) but cannot additively blend `SpriteFrames` frame-index timelines. There is no `AnimationTree` node that drives two independent `AnimatedSprite2D.frame` properties simultaneously from two separate `SpriteFrames` resources. The two-node approach is simpler and produces the correct visual result with no engine API risk.

### Architecture Diagram

```
WAVE_ACTIVE frame (60 Hz):

EventBus                       MonsterManager._physics_process(delta)
   │                           ┌──────────────────────────────────────────┐
   │ monster_damage_taken ──►  │ [Pass 1] Drain _pending_damage           │
   │                           │  apply → mark DEAD if hp ≤ 0             │
   │                           ├──────────────────────────────────────────┤
   │ Grid.get_towers_in_range ◄─┤ [Pass 2] BOSS Logic: scan throttle,     │
   │                           │  attack-prime, cooldown, prepare-count    │
   │ boss_tower_attack_attempted►                                          │
   │                           ├──────────────────────────────────────────┤
   │ PathfindingSystem.get_path─► [Pass 3] Movement: advance each ACTIVE  │
   │ Grid.cell_to_world ◄──────┤  entity; check GOAL arrival; rebuild     │
   │ Grid.world_to_cell ◄──────┤  active_monsters (filter pass)           │
   │ monster_breached ─────────►                                          │
   │ monster_died ─────────────►                                          │
   │ boss_died ────────────────►                                          │
   │                           ├──────────────────────────────────────────┤
   │ monster_hp_absorbed ──────► [Pass 4] Flush _pending_absorbed          │
   │                           └──────────────────────────────────────────┘
```

### Key Interfaces

```gdscript
# MonsterManager (scene-instanced node, not Autoload)

# Called by EventBus subscriber (buffered — not applied inline):
func _on_monster_damage_taken(event: MonsterDamageTaken) -> void:
    _pending_damage.append(event)

# Called by EventBus subscriber (wave lifecycle):
func _on_wave_started(wave_index: int) -> void   # clears active_monsters; resets counter if wave_index==1
func _on_wave_completed() -> void               # force-removes all entities; clears accumulators

# Called by EventBus subscriber (spawn):
func _on_monster_spawn_requested(event: MonsterSpawnRequestedEvent) -> void

# Internal (centralized processing):
func _physics_process(delta: float) -> void     # 4 passes as described above

# MonsterEntity (Area2D scene root — no _physics_process)
var lifecycle_state: int                        # SPAWNING / ACTIVE / DEAD / BREACHED
var current_hp: float
var scaled_hp: float                            # immutable after spawn
var scaled_speed: float                         # immutable after spawn
var current_path: Array[Vector2i]
var path_step_index: int
var spawn_wave_reward_scalar: float             # forwarded in monster_died; never applied to stats
```

## Alternatives Considered

### Alternative 1: CharacterBody2D + `move_and_slide()`

- **Description**: Use `CharacterBody2D` as scene root; set `velocity` and call `move_and_slide()` each frame.
- **Pros**: Standard Godot movement pattern; automatic collision response.
- **Cons**: Physics solver separates overlapping bodies — violates co-occupancy requirement (EC-1.3). All 100+ monsters would push each other off their path routes. Cannot be disabled per-entity without removing all collision from the body.
- **Rejection Reason**: Incompatible with the co-occupancy requirement. Monsters must be able to share SPAWN and PATH cells simultaneously.

### Alternative 2: Per-Entity `_physics_process` (one per `MonsterEntity` node)

- **Description**: Each `MonsterEntity` runs its own `_physics_process`, handles its own damage and movement.
- **Pros**: Standard Godot scene architecture; each entity is self-contained.
- **Cons**: No deterministic ordering between entities — the engine calls each node's `_physics_process` in scene-tree order, which is not guaranteed stable. A lethal hit and GOAL arrival in the same frame for the same entity can be processed in either order depending on node tree position. DEAD-priority cannot be structurally guaranteed.
- **Rejection Reason**: Cannot enforce the DEAD-priority invariant (EC-3.1). The four-pass centralized approach is the only way to guarantee that damage is applied before movement in the same frame, for all entities, without conditional per-entity state checks.

### Alternative 3: `AnimationTree` Additive Blend for BOSS Animation

- **Description**: Use an `AnimationTree` with additive blend to overlay attack animations on top of the walk animation.
- **Pros**: Godot's intended animation composition system.
- **Cons**: `AnimationTree` additive blend works on keyframe property values (position, rotation, color), not on `AnimatedSprite2D.frame` integer indices. Two independent `SpriteFrames` animation timelines cannot be additively blended — the system does not support blending discrete frame indices from two separate sprite sheets.
- **Rejection Reason**: Engine limitation. Two stacked `AnimatedSprite2D` nodes produce the correct result with no additional complexity and no engine API risk.

## Consequences

### Positive

- DEAD-priority guarantee is structural and unconditional — no per-entity conditional checks needed
- Single centralized `_physics_process` makes the full per-frame pass visible in the profiler as one call tree, simplifying performance analysis
- `Array.filter()` for active_monsters rebuild is safer than `Array.erase()` in a loop (no mid-iteration removal)
- Two-stacked-AnimatedSprite2D approach is simpler to implement and author than AnimationTree setup
- `_pending_absorbed` batching means D&S receives at most one `monster_hp_absorbed` per entity per frame regardless of hit burst size

### Negative

- `MonsterManager._physics_process` is a large method — must be carefully organized by pass to stay readable; a future 5th pass would require deliberate design
- Entities must not define their own `_physics_process` — this is a non-obvious constraint that code review must enforce
- Art pipeline must produce BOSS overlay sprites with transparent backgrounds and pixel-aligned pivots — additional art spec required (documented in monster.md Visual/Audio Requirements)

### Risks

- **`Array.filter()` on typed arrays**: Confirm `active_monsters.filter(func(e): ...)` works on `Array[MonsterEntity]` in Godot 4.6.2 typed GDScript. Mitigation: include in engine API verification pass (S1-10).
- **150-entity pass overhead**: 4 sequential passes over 150 entities each frame could exceed the 2 ms budget under extreme conditions. Mitigation: AC-28 and AC-40 require profiler evidence before implementation stories are signed off.
- **BOSS overlay alpha-compositing**: Confirm the overlay `AnimatedSprite2D` transparent frames render correctly (no grey fringing or blend-mode artifact) on the Godot 4.6.2 Vulkan renderer. Mitigation: visual verification AC before art assets are finalized.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| monster.md Rule 5 | Area2D scene root; `CharacterBody2D` prohibited | Position-based movement on `Area2D` is the decision. No physics solver involvement. |
| monster.md Rule 8 | `_pending_damage: Array[MonsterDamageTaken]` — buffered, not applied on receipt | Pass 1 drain pattern is the decision. Buffer appended by subscriber, drained by `_physics_process`. |
| monster.md EC-3.1 | Four-pass centralized `_physics_process`; DEAD-priority over BREACHED | Structural ordering: Pass 1 (damage) always before Pass 3 (movement) ensures DEAD is set before GOAL arrival is checked. |
| monster.md Rules 11–12 | Position-based movement; overshoot handling | `global_position` set directly from `direction × scaled_speed × delta`. Overshoot loop advances `path_step_index` for each overshot cell in one frame. |
| monster.md Rules 17, 17d | BOSS two-layer AnimatedSprite2D; walk uninterrupted during attack | Two-stacked-node architecture; overlay controls attack animations; base layer never paused. |
| monster.md Rules 1–5 | MonsterResource as data-driven Resource subclass | MonsterEntity holds an immutable MonsterResource reference; mutable runtime state is held on the entity instance separately. |
| monster.md Rule 21e | `_pending_absorbed` frame-scoped accumulator | Dictionary accumulates per-entity across Pass 1; flushed as one event per entity in Pass 4; cleared after flush. |
| monster.md Rule 17a | BOSS scan throttle: decrement-then-check each pass | Pass 2 structure: `if boss_scan_frames_remaining > 0: decrement` then `if boss_scan_frames_remaining <= 0: scan` — two sequential independent checks. |

## Performance Implications

- **CPU**: 4 passes × 100–150 entities/frame × 60 FPS. Target: ≤ 2 ms/frame for 150 STANDARD entities (AC-28); ≤ 4 ms/frame for 22-entity lethal AoE frame (AC-40). BOSS Logic Pass adds `Grid.get_towers_in_range()` calls at throttled interval (default: 6 frames / 10 calls per second per BOSS).
- **Memory**: `_pending_damage: Array[MonsterDamageTaken]` — bounded by hit events per frame; cleared each frame. `_pending_absorbed: Dictionary[int, float]` — bounded by entity count; cleared each frame. No persistent allocation growth.
- **Load Time**: None — no precomputed data structures.
- **Network**: N/A (single-player).

## Migration Plan

Pre-production — no existing Monster System code to migrate. This ADR is written before implementation begins.

## Validation Criteria

- AC-28: 150 ACTIVE monsters ≤ 2 ms/frame (profiler evidence required)
- AC-35: Two hits on same entity in same frame → exactly one `monster_hp_absorbed` emitted
- AC-40: 22-entity lethal AoE frame ≤ 4 ms/frame
- EC-3.1 / AC-18: Lethal hit + GOAL arrival in same frame → DEAD wins; entity not marked BREACHED
- BOSS overlay AnimatedSprite2D: visual verification that walk and attack animations display simultaneously without alpha-compositing artifacts

## Related Decisions

- ADR-0001 — EventBus architecture (cross-system communication via typed signals)
- ADR-0002 — Scene and Autoload structure (Area2D as Monster scene root; MonsterManager scene-instanced)
- ADR-0004 — Pathfinding strategy (`get_path(from_cell, tier)` API consumed by Monster System in Pass 1 / spawn)
- ADR-0005 — Grid system data model (Grid direct-call exception; `cell_to_world()`, `world_to_cell()`, `get_towers_in_range()` called from Pass 2 and Pass 3)
- ADR-0007 — Damage pipeline (references `_pending_damage` buffer established here)
- `design/gdd/monster.md` — full monster GDD; all Rules and ACs cited above
