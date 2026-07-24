# ADR-0019: Projectile Pooling Strategy

## Status
Accepted (2026-07-13, via `/architecture-review` Pass 4 follow-up — all dependency ADRs already Accepted, no blocking issues from `godot-specialist` validation, Ordering Note confirms it may be implemented immediately)

## Date
2026-07-13

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core / Object Lifecycle (Gameplay Systems) |
| **Knowledge Risk** | LOW — object pooling via `visible`/`process_mode` toggling on plain `Node2D` is a stable pre-4.x pattern; no post-cutoff API is required by this decision. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` (no `Node2D`/`process_mode`/pooling-relevant breaking changes found 4.4–4.6) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm `process_mode = PROCESS_MODE_DISABLED` on a pooled `Projectile` reliably halts its own `_process`/`_physics_process` (if any exist on the node itself — see Decision, which centralizes all per-instance update logic in `ProjectileManager` instead, making this a belt-and-suspenders measure rather than a hard dependency). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Autoload/scene-instanced boundary — `ProjectileManager` is scene-instanced, composed within Tower System); ADR-0006 (Monster movement — precedent for centralized-manager-owns-all-physics-process pattern); ADR-0007 (Damage pipeline — `tower_attacked` deferred-dispatch contract this ADR preserves, only delays *when* it fires); ADR-0009 (Resource data model — `WeaponComponent.projectile_type` field already exists as the schema this ADR consumes); ADR-0013 (Draw-call batching — pooled projectile visuals must follow the shared-atlas convention) |
| **Enables** | Tower System implementation stories for `HOMING`/`BALLISTIC` weapon combat (currently unimplemented — `_try_attack()` fires all weapon types instantly); closes `TR-tower-007` |
| **Blocks** | Any story implementing `HOMING` or `BALLISTIC` weapon-type combat behavior — cannot proceed until this ADR is Accepted. `BEAM` and `AURA` weapon types are unaffected and already work as shipped. |
| **Ordering Note** | All dependency ADRs are Accepted. This ADR may be implemented immediately. |

## Context

### Problem Statement

`tower.md`'s Tuning Knobs table (`projectile_pool_size=192`, `max_reacquisitions_per_frame=8`, `base_flight_time_sec=0.5s`, `max_active_towers_homing`, provisional 32) and Rules 19–20 firmly imply that `HOMING` and `BALLISTIC` tower weapons fire a flight-time-delayed, poolable projectile entity that can re-acquire its target mid-flight. No ADR defines this entity's pool ownership, lifecycle, movement model, or how it integrates with Tower System's existing fire-timing and the `tower_attacked` → Damage & Status dispatch contract (ADR-0007). The shipped `TowerSystem._try_attack()` currently emits `tower_attacked` immediately at fire time for **every** weapon type — there is no flight-time delay and no `projectile*.gd` file exists anywhere in the codebase. This is a real, unimplemented gap (`TR-tower-007`), not a refinement of existing code.

`BEAM` weapons resolve damage instantly per Rule 20 ("hitscan/beam: immediate") — they need no change and are out of scope. `AURA` weapons (Support archetype) have no projectiles at all (Rule 5a) — also out of scope.

### Constraints
- `HOMING` projectiles re-acquire "the highest-priority target currently in range" of the **originating tower** on target death — re-acquisition is bounded by the tower's own range/cone, not a global search (tower.md EC: "the projectile does not extend its search area").
- Re-acquisition throttle: `max_reacquisitions_per_frame = 8` — a mass-kill event (AoE wiping 20+ targets) must not let re-acquisitions spike frame cost.
- Pool must be fixed-size, sized at mission start via `projectile_pool_size = ceil(max_active_towers_homing × max_attack_speed × base_flight_time_sec × 3.0)` (default 192) — no runtime growth.
- Pool exhaustion must degrade gracefully (dropped shot, not a crash) — consistent with the project's `.claude/rules/engine-code.md` "all engine systems must support graceful degradation" rule.
- No per-instance `_physics_process` on pooled entities — the project's established `per_monster_physics_process` forbidden pattern (ADR-0006) bans exactly this shape of per-entity update for the same reason (non-deterministic scene-tree ordering); the same reasoning applies to a 192-instance projectile pool.
- Zero allocations in the hot path (`.claude/rules/engine-code.md`) — no `instantiate()`/`queue_free()` per shot after mission-start pool warm-up.
- Cosmetic visuals must never gate damage delivery (Rule 20) — the logical arrival event (which triggers `tower_attacked`) and the visual sprite/animation are two decoupled concerns.

### Requirements
- A fixed-size pool of reusable projectile entities, warmed up once at mission start.
- `HOMING`: tracks a live target by entity ID (not a Monster node reference — forbidden pattern `direct_cross_system_node_reference`), re-acquires within the firing tower's range/cone on target death, self-destructs with no damage/detonation/error if no valid target exists.
- `BALLISTIC`: continues to the target's last-known world position; deals no damage if the position is empty on arrival; AoE-tagged `BALLISTIC` weapons still detonate (possibly on zero targets).
- On arrival, damage is delivered through the **existing** `tower_attacked` → Damage & Status pipeline (ADR-0007) — this ADR changes *when* that signal fires for pooled weapon types, never *how* damage resolves downstream.
- Pooled visuals must share a per-projectile-type atlas, consistent with ADR-0013's draw-call batching convention.

## Decision

### Ownership: `ProjectileManager` composed within Tower System's domain

`ProjectileManager` is a scene-instanced node, **child of Tower System's own node tree** in the mission scene — not a top-level peer/sibling system, and not an Autoload. Only Tower System ever fires projectiles; no other system queries or references in-flight projectile state. Composing `ProjectileManager` inside Tower System's own domain (the same relationship `_monster_cache` has to Tower System — an owned internal implementation detail) means `TowerSystem → ProjectileManager.fire(...)` is an **intra-system method call, not a cross-system reference**, and requires no new EventBus contract or exception to `direct_cross_system_node_reference`.

`ProjectileManager` still owns a single **centralized** `_physics_process` pass over the entire pool — this mirrors `MonsterManager`'s centralized-update pattern (ADR-0006) and satisfies the same architectural reasoning as the `per_monster_physics_process` forbidden pattern: pooled `Projectile` nodes never define their own `_physics_process`.

```gdscript
# ProjectileManager — child node of TowerSystem, NOT Autoload, NOT a scene-tree peer system.
class_name ProjectileManager
extends Node

const POOL_SIZE: int = 192   # ceil(max_active_towers_homing(32) × max_attack_speed(4.0) × base_flight_time_sec(0.5) × 3.0)
const MAX_REACQUISITIONS_PER_FRAME: int = 8

var _pool: Array[Projectile] = []       # pre-instantiated at mission start, never freed mid-mission
var _free_indices: Array[int] = []      # stack of available pool slots — O(1) acquire/release
var _reacquisitions_this_frame: int = 0

func _ready() -> void:
    for i in POOL_SIZE:
        var p: Projectile = PROJECTILE_SCENE.instantiate()
        p.visible = false
        p.process_mode = Node.PROCESS_MODE_DISABLED
        add_child(p)
        _pool.append(p)
        _free_indices.append(i)

func fire(tower_id: int, weapon: WeaponComponent, origin: Vector2,
        target_entity_id: int, target_position: Vector2,
        damage_payload: Dictionary) -> bool:
    # Returns false (dropped shot) if the pool is exhausted — never grows the pool at runtime.
    if _free_indices.is_empty():
        push_warning("ProjectileManager: pool exhausted, shot dropped")   # debug builds only
        return false
    var idx: int = _free_indices.pop_back()
    var p: Projectile = _pool[idx]
    p.activate(idx, tower_id, weapon.projectile_type, origin, target_entity_id, target_position, damage_payload)
    return true

# Note: push_warning() above has no built-in debug/release gating in Godot — it always
# executes in both build types. If genuinely debug-only logging is desired, guard the
# call with `if OS.is_debug_build():` explicitly at the call site rather than assuming
# release builds suppress it.

func _physics_process(delta: float) -> void:
    _reacquisitions_this_frame = 0
    for p in _pool:
        if p.active:
            _update_projectile(p, delta)

func _release(p: Projectile) -> void:
    p.active = false
    p.visible = false
    p.process_mode = Node.PROCESS_MODE_DISABLED
    _free_indices.push_back(p.pool_index)
```

### `Projectile` node — plain `Node2D`, no collision node

Arrival and re-acquisition are cache/ID-driven, not spatial-overlap-driven — `HOMING` re-acquisition already reads from Tower System's own `_monster_cache` (populated via `monster_spawned`/`monster_died`, already shipped), and `BALLISTIC` arrival is a fixed-position-and-timer check. Neither needs `Area2D` monitoring. This avoids Physics-server overhead for 192 pooled instances and sidesteps `monitoring`/`monitorable` toggle-on-reuse complexity entirely — a plain `Node2D` with manual position math is sufficient and cheaper.

```gdscript
class_name Projectile
extends Node2D

var pool_index: int = -1
var active: bool = false
var projectile_type: StringName        # &"HOMING" or &"BALLISTIC" — BEAM/AURA never reach this pool
var _tower_id: int = -1
var _target_entity_id: int = -1        # HOMING only; -1 once no target is tracked
var _target_position: Vector2          # BALLISTIC: fixed aim point set at fire time. HOMING: last-known tracked position.
var _elapsed: float = 0.0
var _flight_time: float = 0.5          # from base_flight_time_sec (tuning knob)
var _damage_payload: Dictionary        # amount, is_siege, is_armored — same fields tower_attacked already carries

func activate(idx: int, tower_id: int, p_type: StringName, origin: Vector2,
        target_entity_id: int, target_position: Vector2, damage_payload: Dictionary) -> void:
    pool_index = idx
    active = true
    visible = true
    process_mode = Node.PROCESS_MODE_INHERIT
    rotation = 0.0                # reset stale transform carried over from this slot's prior use
    modulate = Color.WHITE        # reset stale tint/alpha carried over from this slot's prior use
    projectile_type = p_type
    _tower_id = tower_id
    _target_entity_id = target_entity_id
    _target_position = target_position
    _damage_payload = damage_payload
    _elapsed = 0.0
    global_position = origin
```

**Why both `visible` and `process_mode` are set on release/activate** (godot-specialist-confirmed): `visible = false` alone does not stop a child `AnimatedSprite2D`'s internal animation-frame timer from advancing — a hidden node still processes unless `process_mode` also disables it. `Node.PROCESS_MODE_DISABLED` (not `PROCESS_MODE_PAUSABLE`, which only reacts to `SceneTree.paused`) correctly suspends the entire subtree, including the visual child, on release. Both flags are required — do not simplify to one.

### In-flight update (driven by `ProjectileManager._physics_process`)

```
For each active Projectile p, each physics frame:

  p._elapsed += delta

  if p.projectile_type == &"HOMING":
    if p._target_entity_id != -1 and TowerSystem._monster_cache.has(p._target_entity_id):
      p._target_position = TowerSystem._monster_cache[p._target_entity_id]["cell_world_pos"]  # tracked target still alive
    else:
      # Target died or was never valid this frame — attempt re-acquisition, throttled.
      if _reacquisitions_this_frame < MAX_REACQUISITIONS_PER_FRAME:
        _reacquisitions_this_frame += 1
        var new_target := _find_reacquisition_target(p._tower_id, p.global_position)  # bounded to firing tower's range/cone
        if new_target != -1:
          p._target_entity_id = new_target
        else:
          _release(p)   # no valid target in re-acquisition pool — self-destruct, no damage/detonation/error
          continue
      # else: budget exhausted this frame — projectile continues drifting toward its last tracked
      # position and retries re-acquisition next frame, rather than being denied outright.

  # Move toward _target_position (linear interpolation over _flight_time; BALLISTIC never re-targets)
  var t: float = clampf(p._elapsed / p._flight_time, 0.0, 1.0)
  p.global_position = p.global_position.lerp(p._target_position, ...)  # exact easing TBD at implementation

  if p._elapsed >= p._flight_time:
    if p.projectile_type == &"BALLISTIC" and target position empty on arrival:
      # AoE-tagged BALLISTIC still detonates with zero damage instances (tower.md EC)
      pass
    EventBus.tower_attacked.emit.call_deferred(p._tower_id, p._target_entity_id,
        p._damage_payload.amount, p._damage_payload.is_siege, p._damage_payload.is_armored)
    _release(p)
```

`tower_attacked` is the **existing, unmodified** signal (ADR-0007) — this ADR only changes when it is emitted for `HOMING`/`BALLISTIC` weapons (delayed by `_flight_time` instead of immediate), never its downstream handling in Damage & Status.

### Fire-path integration — `TowerSystem._try_attack()`

```
_try_attack(state) branches on weapon.projectile_type:
  AURA   → unchanged (Support only, no projectile)
  BEAM   → unchanged: EventBus.tower_attacked.emit.call_deferred(...) immediately, no pool involvement
  HOMING | BALLISTIC → ProjectileManager.fire(state.tower_id, weapon, tower_world_position,
                            target_entity_id, target_world_position, damage_payload)
                        # tower_attacked is NOT emitted here — the pooled Projectile emits it on arrival
```

### Visual layer (decoupled, per Rule 20)

Each `Projectile`'s child `AnimatedSprite2D` references a shared per-projectile-type atlas (one atlas for all `HOMING` visuals, one for all `BALLISTIC`), following ADR-0013's shared-atlas / `z_index`-layering convention exactly — no `CanvasLayer` per instance, no unique per-instance texture. At 192 pooled instances × 1–2 visual layers each, this stays inside ADR-0013's existing draw-call budget model (same-class-same-atlas batches to one draw call regardless of active instance count).

### Architecture Diagram

```
TowerSystem (scene-instanced)
  ├── _monster_cache (existing, internal — no change)
  ├── _try_attack(state)
  │     ├── BEAM/AURA → EventBus.tower_attacked.emit.call_deferred(...)   [unchanged]
  │     └── HOMING/BALLISTIC → ProjectileManager.fire(...)
  │
  └── ProjectileManager (child node — Tower System's own domain, not a cross-system peer)
        ├── _pool: Array[Projectile]  (192, pre-instantiated at mission start)
        ├── _free_indices: Array[int] (O(1) acquire/release stack)
        └── _physics_process(delta)   [single centralized pass — mirrors MonsterManager pattern]
              for each active Projectile:
                HOMING  → track/re-acquire via TowerSystem._monster_cache (throttled, 8/frame)
                BALLISTIC → advance to fixed last-known position
                on arrival → EventBus.tower_attacked.emit.call_deferred(...) → D&S (ADR-0007, unchanged)
                            → _release() back to pool
```

### Key Interfaces

```gdscript
# ProjectileManager — child of TowerSystem, internal (no cross-system EventBus contract added)
func fire(tower_id: int, weapon: WeaponComponent, origin: Vector2,
        target_entity_id: int, target_position: Vector2, damage_payload: Dictionary) -> bool
    # Returns false if pool exhausted (shot silently dropped, tower's attack timer still resets)

# EventBus signal used (existing, unmodified — ADR-0001/ADR-0007):
signal tower_attacked(tower_id: int, target_id: int, damage: float, is_siege: bool, is_armored: bool)
```

## Alternatives Considered

### Alternative 1: Per-tower local pool
- **Description**: Each `TowerInstance` owns its own small pool of projectiles it fires.
- **Pros**: Simple 1:1 ownership; no shared-resource contention.
- **Cons**: Fragments the pool across N towers (N small pools vs. one shared 192-slot pool) — wastes memory at low per-tower attack rates and can still exhaust locally even while the project-wide pool has capacity. Duplicates movement/collision logic per tower instance. Breaks from the established `MonsterManager` centralized-manager precedent (ADR-0006).
- **Rejection Reason**: A shared pool matches the GDD's own sizing formula (`max_active_towers_homing × max_attack_speed × base_flight_time_sec × 3.0`) — that formula is explicitly a *global* budget, not a per-tower one.

### Alternative 2: Generic reusable `NodePool` utility class
- **Description**: A general-purpose object-pooling utility (not projectile-specific), usable later for VFX, damage numbers, or other pooled entity types.
- **Pros**: More reusable long-term; avoids projectile-specific pooling logic being duplicated if a second pooled entity type is added later.
- **Cons**: Adds an abstraction layer for what is currently a single consumer at MVP scope — no other pooled entity type exists yet or is planned in any Accepted ADR. Premature generalization.
- **Rejection Reason**: Project convention (per `CLAUDE.md`'s "no premature abstraction" guidance) favors building the concrete case first. If a second pooled entity type is designed later, its ADR can extract a shared utility from this one's proven pattern.

### Alternative 3: `Area2D`-based `Projectile` (matches Monster's scene-root convention)
- **Description**: Give each pooled `Projectile` an `Area2D` root, enabling physical overlap detection as an arrival trigger, consistent with ADR-0006's `Area2D`-for-entities pattern.
- **Pros**: Consistency with the Monster entity convention; physical overlap as a secondary correctness check.
- **Cons**: Re-acquisition and arrival are already fully cache/ID-driven per the GDD (bounded by the firing tower's range/cone, not spatial detection) — an `Area2D` would add Physics-server monitoring overhead for 192 instances with no functional benefit, plus `monitoring`/`monitorable` toggle-on-reuse complexity that a plain `Node2D` avoids entirely.
- **Rejection Reason**: No requirement in `tower.md` needs physical collision detection for projectile arrival — the design is already logical/cache-driven. Adding `Area2D` would be unused overhead, not consistency for its own sake.

### Alternative 4: No pooling — `instantiate()`/`queue_free()` per shot
- **Description**: Skip pooling entirely; create and destroy a `Projectile` scene instance on every fire.
- **Pros**: Simplest possible implementation; no pool-sizing formula to maintain.
- **Cons**: Directly violates `tower.md`'s explicit tuning knobs (`projectile_pool_size`, `max_reacquisitions_per_frame` presuppose a pool) and `.claude/rules/engine-code.md`'s zero-allocation-hot-path rule — at peak wave volume (32 towers × up to 4 attacks/sec), this is dozens of `instantiate()`/`queue_free()` calls per second, a known GC-pressure and instantiation-cost hot path in Godot.
- **Rejection Reason**: Explicitly ruled out by the GDD's own tuning knobs; this ADR exists specifically because that gap needed closing.

## Consequences

### Positive
- Zero runtime `instantiate()`/`queue_free()` after mission-start pool warm-up — satisfies the project's zero-allocation-hot-path rule.
- Centralized `_physics_process` (mirrors `MonsterManager`) keeps update ordering deterministic and consistent with the project's established anti-per-entity-physics-process convention.
- `ProjectileManager` composed as a child of Tower System avoids introducing any new cross-system EventBus contract — `tower_attacked` remains the single, unmodified damage-delivery signal.
- Graceful pool-exhaustion degradation (dropped shot, `push_warning` in debug only) — no crash, matches project conventions.
- Re-acquisition throttle prevents a mass-kill event from spiking frame cost, while still letting a throttled projectile retry next frame instead of losing its target permanently.

### Negative
- `ProjectileManager`'s pool is sized by a formula with a **provisional** input (`max_active_towers_homing = 32`, not yet finalized per the GDD's own tuning knob table) — the 192-instance default must be revisited once map design finalizes PLACEABLE cell counts.
- A throttled re-acquisition (budget exhausted this frame) leaves the projectile drifting toward a stale position for up to one extra frame — a minor, GDD-unspecified behavior this ADR introduces to avoid an outright "denied" re-acquisition; should be flagged to game-design for confirmation it reads correctly during playtesting.
- Composing `ProjectileManager` inside Tower System (rather than as a top-level scene-tree peer) means any future system needing to observe in-flight projectile state (e.g., a VFX system wanting real projectile positions rather than fire-and-forget particle trails) would need a new, explicit interface — none exists today because none is needed.

### Risks
- **Risk**: Pool exhaustion during a mass-fire scenario (e.g., 32 HOMING towers all firing near-simultaneously at max attack speed) causes visible dropped shots. **Mitigation**: `projectile_pool_size` formula already applies a 3.0× safety multiplier over the naive concurrent-flight estimate; `push_warning` on exhaustion makes this visible during tuning/playtesting before it reaches release.
- **Risk**: The linear-interpolation movement model (position lerp over `_flight_time`) may look visually wrong for `HOMING` projectiles whose target relocates significantly mid-flight (sharp direction snap rather than a curve). **Mitigation**: This ADR defines the *logical* arrival/re-acquisition contract; the exact interpolation/easing curve is a visual-polish decision left to implementation and art review, not gated by this ADR.
- **Risk**: `max_active_towers_homing` is provisional (32) — if actual concurrent HOMING tower counts exceed it at higher map/PLACEABLE-cell counts, the pool could be undersized. **Mitigation**: Already flagged as an open tuning-knob risk in `tower.md` itself; this ADR's pool-exhaustion graceful-degradation path means an undersized pool degrades to dropped shots, not a crash, while the knob is recalibrated.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `tower.md` | Rule 19: HOMING re-acquisition on target death, bounded by tower's own range/cone, self-destructs if no valid target | In-flight update logic — re-acquisition reads `TowerSystem._monster_cache`, throttled, self-destructs via `_release()` with no damage/detonation/error |
| `tower.md` | Rule 19: BALLISTIC/BEAM continue to last-known position; BEAM is immediate | BALLISTIC handled by pooled `Projectile`; BEAM explicitly bypasses the pool entirely (unchanged fire path) |
| `tower.md` | Rule 20: Damage resolved at logical arrival; visuals are cosmetic and non-gating | `tower_attacked` emission moved to arrival (not fire time) for pooled types; visual `AnimatedSprite2D` layer fully decoupled from arrival logic |
| `tower.md` | Tuning Knob: `projectile_pool_size` (192, formula-derived) | `ProjectileManager.POOL_SIZE` constant, pre-instantiated at mission start |
| `tower.md` | Tuning Knob: `max_reacquisitions_per_frame` (8) | `_reacquisitions_this_frame` counter, reset each `_physics_process`, throttles re-acquisition attempts |
| `tower.md` | Tuning Knob: `base_flight_time_sec` (0.5s) | `Projectile._flight_time`, drives the arrival timer |
| `tower.md` | Tuning Knob: `max_active_towers_homing` (provisional 32) | Consumed by the pool-sizing formula; flagged as a revisit risk (see Risks) |

**Technical Requirements covered**: TR-tower-007

## Performance Implications
- **CPU**: `ProjectileManager._physics_process` iterates the full 192-slot pool each physics frame, skipping inactive slots (`if p.active`) — worst case ≈192 cheap position/timer updates per frame, an order of magnitude cheaper per-instance than Monster's 4-pass logic at comparable counts (no damage-buffer flush, no BOSS-specific logic, no breach detection). Estimated well under 0.1 ms/frame at MVP entity counts; no dedicated performance budget is registered in `docs/registry/architecture.yaml` by this ADR (not requested this pass) — recommend profiling once implemented.
- **Memory**: 192 pre-instantiated `Node2D` + `AnimatedSprite2D` pairs, allocated once at mission start. Freed at mission end along with the rest of the mission scene tree — no persistent growth across missions.
- **Load Time**: Pool warm-up (`_ready()`, 192 `instantiate()` calls) happens once at mission scene load — bounded, one-time cost, not per-frame.
- **Network**: Not applicable (single-player only).

## Migration Plan
Greenfield — no existing `Projectile`/`ProjectileManager` code to migrate. `TowerSystem._try_attack()`'s existing unconditional `EventBus.tower_attacked.emit.call_deferred(...)` call must be branched by `weapon.projectile_type` as described in Decision — this is the only change to already-shipped code, and it is additive (BEAM/AURA paths are byte-for-byte unchanged).

## Validation Criteria
- [ ] Unit test: `ProjectileManager._ready()` pre-instantiates exactly `POOL_SIZE` (192) `Projectile` instances; no `instantiate()` call occurs afterward for the life of the mission scene.
- [ ] Unit test: `fire()` on an exhausted pool returns `false` and does not grow `_pool`.
- [ ] Unit test: a HOMING projectile whose target dies mid-flight re-acquires a new valid target within the firing tower's range/cone; if none exists, `_release()` is called with no `tower_attacked` emission.
- [ ] Unit test: `_reacquisitions_this_frame` never exceeds `MAX_REACQUISITIONS_PER_FRAME` (8) in a single `_physics_process` call, even when more than 8 projectiles need to re-acquire simultaneously.
- [ ] Unit test: a BALLISTIC projectile arriving at an empty last-known position deals zero damage instances but still emits its arrival event for AoE-tagged weapons (detonation with zero targets).
- [ ] Unit test: `tower_attacked` fires exactly once per successful projectile arrival, deferred one frame (matches ADR-0007's existing pattern) — never synchronously.
- [ ] Integration test: BEAM-weapon fire path is byte-for-byte unchanged (no `ProjectileManager` involvement, `tower_attacked` still emitted immediately at fire time).
- [ ] Static analysis (grep): no `Projectile` or `ProjectileManager` script defines its own `_physics_process` outside `ProjectileManager`'s single centralized pass.

## Related Decisions
- ADR-0002 — Scene and Autoload structure (`ProjectileManager` composed as a scene-instanced child of Tower System, not Autoload)
- ADR-0006 — Monster movement (precedent for centralized-manager-owns-all-physics-process; `per_monster_physics_process` forbidden pattern reasoning applied here to projectiles)
- ADR-0007 — Damage pipeline (`tower_attacked` deferred-dispatch contract this ADR preserves unmodified)
- ADR-0008 — Tower placement gate (`TowerSystem._try_attack()` fire-path this ADR branches)
- ADR-0009 — Resource data model (`WeaponComponent.projectile_type` schema field this ADR consumes)
- ADR-0013 — Draw-call batching (pooled projectile visuals follow the shared-atlas convention)
- `design/gdd/tower.md` — Rules 17–20, Tuning Knobs table (`projectile_pool_size`, `max_reacquisitions_per_frame`, `base_flight_time_sec`, `max_active_towers_homing`)
