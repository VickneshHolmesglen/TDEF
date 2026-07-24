# ADR-0010: Hero Tower-Synced Class + Tower Affinity

## Status
Accepted

## Date
2026-05-24

> **Revised 2026-07-13** — resolves part of the BLOCKING "`tower_id` type & signal arity"
> conflict found by `/architecture-review` (`docs/architecture/architecture-review-2026-07-13b.md`).
> Checked against the shipped `src/core/hero/hero.gd`, `src/core/tower/tower_system.gd`, and
> `src/foundation/event_bus/event_bus.gd`: the actual `tower_placed`/`tower_removed`/
> `tower_destroyed` signal signatures (5/3/4 typed args respectively) are richer than what
> this ADR's Key Interfaces section originally sketched, and the shipped Hero subscriber
> handlers already match them exactly. The sections below are corrected to show the real,
> already-catalogued signatures instead of the placeholder guesses — no behavioral/code
> change. Also fixes two unrelated one-line drifts found while revising: a phantom
> "after Grid = 25" restore_order reference (Grid has no save state — ADR-0005/ADR-0003
> both confirm this), and a citation of `docs/engine-reference/godot/modules/core.md`,
> which does not exist (confirmed by godot-specialist consultation during the review).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | HIGH — post-LLM-cutoff |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | `Dictionary` typed hints (`Dictionary[K, V]` — 4.4+); `maxi()` builtin (4.x confirmed); `@export` on Resource subclass fields (ADR-0009 pattern) |
| **Verification Required** | Confirm `Dictionary[int, Dictionary]` typed-hint syntax accepted in Godot 4.6 GDScript; confirm `_physics_process(delta)` accumulation does not exceed 0.3 ms frame budget when 1 hero active |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (EventBus signal contract), ADR-0002 (Autoload structure + mission state), ADR-0005 (Grid world_to_cell), ADR-0007 (damage dispatch — Hero receives damage via EventBus), ADR-0008 (Tower placement gate — WAVE_ACTIVE context), ADR-0009 (Resource data model — HeroResource, TowerResource) |
| **Enables** | — (ADR-0011's original framing cited this ADR's "Hero stat display" as its driver; ADR-0011 itself corrects this — Hero's HUD elements are non-interactive Labels/ProgressBars needing no focus handling. ADR-0011's actual driver was Inventory's Story 007.) |
| **Blocks** | None — Hero System implementation may now begin |
| **Ordering Note** | Accepted 2026-05-24. ADR-0001 through ADR-0009 (excl. ADR-0010/0011) must all be Accepted before Hero System is authored. ADR-0011 (UI dual-focus) may be deferred until first Presentation GDD lands. |

## Context

### Problem Statement

The Hero system requires two closely related subsystems that both depend on live
tower data during a mission:

1. **Tower-Synced Class** — The hero accumulates proximity time near towers of a
   given archetype during WAVE_ACTIVE and INTERMISSION phases. Once a threshold is
   met the corresponding class is unlocked. A "primary class" locks in at SCOUT
   phase entry and gates Tower Affinity filtering.

2. **Tower Affinity** — A stat multiplier (`tower_affinity_bonus`) that scales with
   the count of qualifying towers currently placed on the grid. Qualifying = matching
   the hero's primary class archetype.

Both subsystems need to know, at all times, the archetype and cell position of every
live tower. The Hero System cannot hold a direct reference to the Tower System
(forbidden pattern: `direct_cross_system_state_write` — ADR-0001). This ADR defines
how the Hero System tracks tower state, computes proximity accumulation, and derives
Tower Affinity without any cross-system coupling.

### Constraints

- Hero System is scene-instanced (`CharacterBody2D`, per ADR-0002); Tower System is also scene-instanced — no reverse dependency allowed.
- EventBus cascade depth ≤ 2 (ADR-0001 Rule 2).
- `_physics_process` budget for all non-physics systems: ≤ 0.3 ms/frame.
- Class designation must persist across save/load (`restore_order = 30` — Core band 10–49 per ADR-0003's `SaveRestorer` band table; Grid has no save state, so there is no "after Grid" ordering dependency).
- Tower Affinity recomputation must not run every frame — only on tower lifecycle events.
- Chebyshev radius constant `CLASS_PROXIMITY_RADIUS = 3` is a tuning knob (GDD).
- `TOWERS_AFFINITY_REFERENCE = 16` is a tuning knob (GDD).
- `tower_affinity_bonus` is capped at 2.0.

### Requirements

- Must track archetype + cell for every live tower (TR-hero-002).
- Must accumulate per-archetype proximity time in physics process (TR-hero-002).
- Must unlock class at 30 s threshold and "deep unlock" at 90 s (TR-hero-002).
- Must compute Tower Affinity via `affinity_stat × sqrt(qualifying / REFERENCE)` (TR-hero-003, TR-hero-006).
- Must recalculate Tower Affinity on every tower lifecycle event, not per-frame (TR-hero-003).
- Must filter qualifying towers by primary class archetype (TR-hero-003).
- Must emit `hero_class_unlocked` via EventBus when a class unlocks (TR-hero-002).
- Must persist `_proximity_time`, `_unlocked_classes`, `_primary_class`, `_secondary_class` (TR-hero-002).

## Decision

### Tower Cache (unified for both subsystems)

The Hero System maintains a single local cache of all live towers:

```gdscript
var _tower_cache: Dictionary = {}
# Key:   tower_id: int
# Value: { "archetype": StringName, "cell": Vector2i }
```

The cache is populated and maintained exclusively through EventBus subscriptions.
The signal signatures below are the canonical, already-catalogued ones from
`event-bus.md`/`event_bus.gd` (see ADR-0008 for the emitting side) — this ADR's
original text sketched narrower placeholder signatures before the full contract
was finalized; corrected here to match what was actually built and shipped in
`src/core/hero/hero.gd`:

```gdscript
func _ready() -> void:
    EventBus.tower_placed.connect(_on_tower_placed)
    EventBus.tower_removed.connect(_on_tower_removed)
    EventBus.tower_destroyed.connect(_on_tower_destroyed)

func _exit_tree() -> void:
    EventBus.tower_placed.disconnect(_on_tower_placed)
    EventBus.tower_removed.disconnect(_on_tower_removed)
    EventBus.tower_destroyed.disconnect(_on_tower_destroyed)

func _on_tower_placed(tower_id: int, grid_position: Vector2i, archetype: String,
        _footprint: Vector2i, _placed_in_scout: bool) -> void:
    _tower_cache[tower_id] = {"archetype": StringName(archetype), "cell": grid_position}
    _recompute_tower_affinity()

func _on_tower_removed(tower_id: int, _grid_position: Vector2i, _archetype: String) -> void:
    _tower_cache.erase(tower_id)
    _recompute_tower_affinity()

func _on_tower_destroyed(tower_id: int, _grid_position: Vector2i, _archetype: String,
        _footprint: Array) -> void:
    _tower_cache.erase(tower_id)
    _recompute_tower_affinity()
```

`_on_tower_placed` explicitly converts the signal's `archetype: String` payload to
`StringName` for the cache entry, since `_recompute_tower_affinity()`'s archetype
filter compares against `_primary_class: StringName`. `tower_destroyed` fires from
Tower System's boss-attack HP-zero path (see ADR-0008's "Tower Destroyed" section)
— a real, shipped emitter, not a dangling reference.

This mirrors the monster cache pattern in Tower System (ADR-0007) and requires no
Grid API extension.

### Tower-Synced Class — Proximity Accumulation

Proximity time is accumulated per-archetype in `_physics_process`. Accumulation only
occurs when the hero is on the grid and the mission is in WAVE_ACTIVE or INTERMISSION.

```gdscript
# Per-archetype proximity time in seconds
var _proximity_time: Dictionary = {}
# StringName → float

var _proximity_active: bool = false  # true during WAVE_ACTIVE + INTERMISSION

func _physics_process(delta: float) -> void:
    if not _proximity_active:
        return
    var hero_cell: Vector2i = Grid.world_to_cell(global_position)
    for tower_id: int in _tower_cache:
        var entry: Dictionary = _tower_cache[tower_id]
        var tower_cell: Vector2i = entry.cell
        var dist: int = maxi(
            abs(hero_cell.x - tower_cell.x),
            abs(hero_cell.y - tower_cell.y)
        )
        if dist <= CLASS_PROXIMITY_RADIUS:
            var arch: StringName = entry.archetype
            _proximity_time[arch] = _proximity_time.get(arch, 0.0) + delta
            _check_class_unlock(arch)
```

`CLASS_PROXIMITY_RADIUS` is a tuning knob (default 3). No Grid helper is needed —
Chebyshev distance is computed inline.

### Tower-Synced Class — Unlock Logic

```gdscript
const CLASS_UNLOCK_THRESHOLD_S: float = 30.0
const CLASS_DEEP_UNLOCK_THRESHOLD_S: float = 90.0

var _unlocked_classes: Dictionary = {}  # StringName → true
var _deep_unlocked_classes: Dictionary = {}  # StringName → true
var _primary_class: StringName = &""
var _secondary_class: StringName = &""

func _check_class_unlock(arch: StringName) -> void:
    var t: float = _proximity_time.get(arch, 0.0)
    if t >= CLASS_UNLOCK_THRESHOLD_S and not _unlocked_classes.has(arch):
        _unlocked_classes[arch] = true
        EventBus.hero_class_unlocked.emit(arch, false)
    if t >= CLASS_DEEP_UNLOCK_THRESHOLD_S and not _deep_unlocked_classes.has(arch):
        _deep_unlocked_classes[arch] = true
        EventBus.hero_class_unlocked.emit(arch, true)
```

### Class Designation — Primary and Secondary Lock

```gdscript
# Called when mission enters SCOUT phase (via EventBus.mission_phase_changed)
func _on_scout_phase_entered() -> void:
    _proximity_active = false
    # Determine primary from highest proximity_time among unlocked classes
    var best_arch: StringName = &""
    var best_time: float = -1.0
    for arch: StringName in _unlocked_classes:
        var t: float = _proximity_time.get(arch, 0.0)
        if t > best_time:
            best_time = t
            best_arch = arch
    _primary_class = best_arch
    # Secondary = second-highest if unlocked; else empty
    var second_arch: StringName = &""
    var second_time: float = -1.0
    for arch: StringName in _unlocked_classes:
        if arch == _primary_class:
            continue
        var t: float = _proximity_time.get(arch, 0.0)
        if t > second_time:
            second_time = t
            second_arch = arch
    _secondary_class = second_arch
    _recompute_tower_affinity()

# Called when mission state restores to Sanctuary (between missions)
func _on_sanctuary_state_restored() -> void:
    _primary_class = &""
    _secondary_class = &""
    _unlocked_classes.clear()
    _deep_unlocked_classes.clear()
    _proximity_time.clear()
    _recompute_tower_affinity()
```

`_proximity_active` is set true when `mission_phase_changed` signals WAVE_ACTIVE or
INTERMISSION, false for all other phases.

### Tower Affinity — Event-Triggered Recomputation

```gdscript
const TOWERS_AFFINITY_REFERENCE: float = 16.0
const TOWER_AFFINITY_BONUS_CAP: float = 2.0

var _tower_affinity_bonus: float = 1.0  # multiplier applied after F1

func _recompute_tower_affinity() -> void:
    if _primary_class == &"":
        # No primary class: all towers qualify
        var count: int = _tower_cache.size()
        _tower_affinity_bonus = clampf(
            sqrt(float(count) / TOWERS_AFFINITY_REFERENCE),
            0.0,
            TOWER_AFFINITY_BONUS_CAP
        )
        return
    var qualifying: int = 0
    for tower_id: int in _tower_cache:
        if _tower_cache[tower_id].archetype == _primary_class:
            qualifying += 1
    _tower_affinity_bonus = clampf(
        sqrt(float(qualifying) / TOWERS_AFFINITY_REFERENCE),
        0.0,
        TOWER_AFFINITY_BONUS_CAP
    )
```

Full Tower Affinity value as applied to a stat:
`tower_affinity_bonus = affinity_stat × _tower_affinity_bonus`

where `affinity_stat` is itself resolved by Formula 1 below.

### Stat Resolution — Formula 1

For every hero stat (HP, Damage, Movement Speed, CDR, Crit Chance, Armor,
Skill Power, Attack Range, Elemental Resistances, Lifesteal cap, Crit Multiplier):

```
effective = max(0, max(0, base + flat) × clamp(1 + additive, 0.25, 4.0))
```

`affinity_stat` feeds Formula 2; Hero System owns the final affinity multiplication.
Formulas 4 (auto-attack damage), 5 (armor reduction), and 6 (lifesteal healing) are
resolved entirely within the Damage & Status System (ADR-0007) — Hero System only
provides the stat values.

### Architecture Diagram

```
EventBus
  ├─ tower_placed ──────────────┐
  ├─ tower_removed ─────────────┤
  ├─ tower_destroyed ───────────┤──→ HeroSystem._tower_cache (Dictionary)
  ├─ mission_phase_changed ─────┤──→ _proximity_active flag
  └─ sanctuary_state_restored ──┘──→ class reset

HeroSystem._physics_process(delta)
  └─ [if _proximity_active]
       └─ iterate _tower_cache → Chebyshev check → _proximity_time accumulate
            └─ threshold met → EventBus.hero_class_unlocked.emit(arch, is_deep)

HeroSystem._recompute_tower_affinity()  [called on every cache mutation]
  └─ count qualifying towers → sqrt formula → _tower_affinity_bonus
```

### Key Interfaces

```gdscript
# EventBus signals consumed by Hero System (canonical signatures, event-bus.md/event_bus.gd):
#   tower_placed(tower_id: int, grid_position: Vector2i, archetype: String, footprint: Vector2i, placed_in_scout: bool)
#   tower_removed(tower_id: int, grid_position: Vector2i, archetype: String)
#   tower_destroyed(tower_id: int, grid_position: Vector2i, archetype: String, footprint: Array)
#   mission_phase_changed(phase: StringName)
#   sanctuary_state_restored()

# EventBus signals emitted by Hero System (catalogued in event-bus.md):
#   hero_class_unlocked(archetype: StringName, is_deep: bool)
#   hero_hp_changed(current: float, maximum: float)
#   hero_skill_cooldown_updated(skill_index: int, ratio: float)

# Public read API (no write API — all state is internal):
func get_effective_stat(stat_name: StringName) -> float: ...
func get_tower_affinity_bonus() -> float: ...
func get_primary_class() -> StringName: ...

# Constants (tuning knobs):
const CLASS_PROXIMITY_RADIUS: int = 3
const CLASS_UNLOCK_THRESHOLD_S: float = 30.0
const CLASS_DEEP_UNLOCK_THRESHOLD_S: float = 90.0
const TOWERS_AFFINITY_REFERENCE: float = 16.0
const TOWER_AFFINITY_BONUS_CAP: float = 2.0
```

## Alternatives Considered

### Alternative 1: Query Grid + Tower System each physics frame
- **Description**: Hero System calls `TowerSystem.get_all_towers()` each frame to
  compute proximity and affinity.
- **Pros**: Always fresh data; no cache consistency risk.
- **Cons**: Violates `direct_cross_system_state_write` forbidden pattern (ADR-0001);
  creates hard Autoload→non-Autoload dependency; runtime cost scales with tower count
  each frame even for affinity (which only changes on tower events).
- **Rejection Reason**: Forbidden coupling pattern. Cache-on-event is strictly cheaper
  and architecturally consistent with ADR-0007's monster cache pattern.

### Alternative 2: Separate proximity cache and affinity cache
- **Description**: Two Dictionaries — one for proximity (tower_id → cell) and one
  for affinity (tower_id → archetype).
- **Pros**: Slightly more explicit separation of concerns.
- **Cons**: Both subsystems need both fields; splitting doubles subscription handler
  complexity for no runtime benefit.
- **Rejection Reason**: Unified cache is simpler and both subsystems read both fields.

### Alternative 3: Grid.get_tower_at_cell() scan each frame for proximity
- **Description**: Hero System iterates all grid cells within Chebyshev radius each
  frame to find nearby towers.
- **Pros**: No cache; always current.
- **Cons**: Grid API does not expose tower data (Grid owns cell type only — ADR-0005);
  would require a new Grid API that violates the Grid's defined scope.
- **Rejection Reason**: Out of Grid's responsibility; cache-on-event is correct.

## Consequences

### Positive
- Zero cross-system coupling: Hero System is self-contained.
- Tower Affinity recomputation is O(tower_count) only on tower lifecycle events —
  not every frame.
- Proximity accumulation loop is O(tower_count) per frame but early-exits via
  `_proximity_active` flag during SCOUT and post-mission phases.
- Pattern is identical to ADR-0007 monster cache — consistent codebase idiom.

### Negative
- One-frame cache lag: If a tower is placed and destroyed in the same frame, the
  cache will be inconsistent for that frame. Acceptable — tower lifecycle events
  are rare (human placement speed).
- `_physics_process` loop cost scales with live tower count. At max tower density
  (16×12 grid; realistic max ~30–50 towers) the Chebyshev check is trivially fast.

### Risks
- ~~**Risk**: `hero_class_unlocked` signal not yet in EventBus catalogue.~~ **RESOLVED** —
  catalogued in `event-bus.md`/`event_bus.gd`, shipped.
- ~~**Risk**: `tower_placed` signal shape must be verified against ADR-0008.~~ **RESOLVED
  2026-07-13** — verified against the shipped implementation; both ADRs and the code now
  agree on the 5-arg `tower_placed`/3-arg `tower_removed`/4-arg `tower_destroyed`
  signatures (see Tower Cache section above and ADR-0008's revised Decision).
- **Risk**: Proximity accumulation running in `_physics_process` could spike if
  `_tower_cache` grows unexpectedly large (bug scenario).
  **Mitigation**: Add `assert(_tower_cache.size() <= 200)` guard in debug builds.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| hero.md | 12 stats; Tower-Synced Class (Chebyshev 3-cell) (TR-hero-002) | Unified tower cache + `_physics_process` proximity accumulation + class unlock at 30 s/90 s thresholds |
| hero.md | Tower Affinity `affinity_stat × sqrt(qualifying / REFERENCE)` (TR-hero-003) | Event-triggered `_recompute_tower_affinity()` with primary-class archetype filter |
| hero.md | 6 stat formulas — F1 effective stat; F2 Tower Affinity; F4/F5/F6 resolved by D&S (TR-hero-006) | Formula 1 defined here; Formula 2 defined here; F4/F5/F6 explicitly delegated to ADR-0007 |

## Performance Implications

- **CPU**: `_physics_process` loop: O(tower_count) Chebyshev checks. At 50 towers: ~50
  integer comparisons per frame ≈ negligible (<0.01 ms). `_recompute_tower_affinity()`
  is called only on tower lifecycle events (rare) — not per-frame.
- **Memory**: `_tower_cache` at 50 towers: ~50 × (8 + 8 + 16) bytes ≈ ~1.6 KB.
  `_proximity_time` at 4 archetypes: ~4 × 16 bytes = 64 bytes. Negligible.
- **Load Time**: No impact — cache is rebuilt from `tower_placed` events on mission load.
- **Network**: N/A (single-player).

## Migration Plan

No existing code to migrate — Hero System has not been implemented. This ADR defines
the initial architecture for all Hero subsystem implementations.

The following EventBus catalogue additions must be made to `design/gdd/event-bus.md`
before implementation begins:
- `hero_class_unlocked(archetype: StringName, is_deep: bool)` — emitted by Hero System
- Verify `hero_hp_changed` and `hero_skill_cooldown_updated` are catalogued (flagged
  in mission-hud.md OQ-1/OQ-2)

## Validation Criteria

1. **Proximity accumulation**: Place 1 tower of archetype "Support" at Chebyshev ≤ 3 from
   hero. Run simulation for 30 s WAVE_ACTIVE. Assert `hero_class_unlocked("Support", false)`
   fires. Run to 90 s. Assert `hero_class_unlocked("Support", true)` fires.
2. **Primary class lock**: Enter SCOUT phase after unlocking "Support". Assert
   `get_primary_class() == "Support"`. Place "Cannon" tower. Assert affinity filter
   uses "Support" only.
3. **Tower Affinity formula**: With `affinity_stat = 1.0`, 4 qualifying towers placed.
   Assert `get_tower_affinity_bonus() ≈ sqrt(4/16) = 0.5`. Add 12 more. Assert
   `get_tower_affinity_bonus() = 1.0`. Add 48 more. Assert bonus capped at 2.0.
4. **Cache consistency**: Place tower → cache size +1. Remove tower → cache size -1.
   Destroy tower mid-wave → cache size -1 and affinity recomputed.
5. **No cross-system coupling**: Static analysis (grep) must find zero direct calls to
   TowerSystem from HeroSystem source files.
6. **Save/load round-trip**: Save mid-WAVE_ACTIVE with `_proximity_time["Support"] = 25.0`.
   Load. Assert `_proximity_time["Support"] == 25.0` and class not yet unlocked. Simulate
   5 more seconds. Assert class unlocks.

## Related Decisions

- ADR-0001 — EventBus signal contract and cascade rules
- ADR-0002 — Autoload structure (Hero System boot position and mission state context)
- ADR-0005 — Grid system (`world_to_cell` for hero position; Grid cell ownership)
- ADR-0007 — Damage & Status pipeline (owns formulas F4/F5/F6; monster cache pattern)
- ADR-0008 — Tower placement gate (`tower_placed` signal origin; WAVE_ACTIVE definition)
- ADR-0009 — Resource data model (HeroResource, TowerResource schema)
- `design/gdd/hero.md` — source of all constants, formulas, and unlock rules
