class_name MonsterEntity
extends Area2D

## Runtime instance data for a single monster on the field.
##
## GDD source: design/gdd/monster.md — Group 1 (runtime entity fields, Rule 5)
## ADR-0006: Area2D root. No _physics_process — all per-entity logic runs in
##   MonsterManager._physics_process (4-pass centralized architecture).
##
## lifecycle_state transitions:
##   SPAWNING → ACTIVE (path received)
##   ACTIVE   → DEAD    (current_hp <= 0)
##   ACTIVE   → BREACHED (path exhausted with hp > 0)

enum State { SPAWNING, ACTIVE, DEAD, BREACHED }

## The authoritative definition for this entity's type (immutable after spawn).
var resource: MonsterResource = null

## Monotonically incrementing ID, never recycled within a mission.
var entity_id: int = -1

## Current HP — starts at scaled_hp; decremented by damage pass.
var current_hp: float = 0.0

## Immutable after spawn. Calculated by MonsterManager at spawn time.
var scaled_hp: float = 0.0

## Immutable after spawn (cells/sec). Calculated by MonsterManager at spawn time.
var scaled_speed: float = 0.0

## Ordered path cells from spawn toward GOAL. Populated at ACTIVE transition.
var current_path: Array[Vector2i] = []

## Index of the next target cell within current_path.
var path_step_index: int = 0

## Free-flow movement (ADR-0006 amendment 2026-11-04): the unsmoothed route
## position. It walks cell centre to cell centre exactly as Pass 3 always did,
## and drives path_step_index / monster_cell_entered. global_position is derived
## from it every frame (rounded corners + lane offset) and is what everything
## else reads. Write this, not global_position, to move a monster along its route.
var path_anchor: Vector2 = Vector2.ZERO

## Where the route starts (the spawn cell's world position; current_path does
## not include it). Used as the point before current_path[0] when rounding a
## turn at the first route cell. Split children inherit their parent's.
var route_origin: Vector2 = Vector2.ZERO

## Signed sideways offset from the route centre line, as a fraction of
## MonsterManager.lane_spread_cells (-1..1). Fixed at spawn; 0 for bosses.
var lane_offset: float = 0.0

var lifecycle_state: int = State.SPAWNING

## &"hero" or &"tower" — set from last MonsterDamageTaken.source_type; forwarded in monster_died.
var last_hit_source: StringName = &"tower"
## Tower veterancy: last tower whose direct hit landed (-1 = none yet). Kept
## through DoT ticks so a tower's burn/poison kill still credits it.
var last_hit_tower_id: int = -1

## Elite affix (design/quick-specs/elite-affixes-2026-11-04.md): one of
## MonsterManager.ELITE_AFFIXES rolled at spawn for ELITE tier, else &"".
var affix: StringName = &""

## Forwarded from MonsterSpawnRequest into MonsterDiedEvent for Resource Economy.
var spawn_wave_reward_scalar: float = 1.0

## The wave this entity was spawned on (forwarded in boss_died and monster_died).
var wave_index: int = -1

## Art & Animation Pipeline Upgrade, vertical slice (2026-08-17): cached
## reference to this entity's presentation-layer child (set by
## MonsterManager._spawn_entity() right after instantiation) so
## _pass1_damage() can trigger play_hit_flash() without a string-based
## get_node() lookup. Null-safe — an entity with no visible sprite (art
## missing for its monster_id) is still a fully correct simulation entity,
## per MonsterInstance's own "non-fatal to spawning" doc comment.
var monster_instance: MonsterInstance = null

# ---- BOSS-only runtime fields (safe to leave at defaults for STANDARD/ELITE) ----

## Frames remaining before next tower scan. Initialized to 0 so BOSS scans on its first frame.
var boss_scan_frames_remaining: int = 0

## Frames remaining in the attack-telegraph animation before boss_tower_attack_attempted emits.
var boss_attack_prepare_remaining: int = 0

## Seconds until the BOSS can start another attack sequence. Starts at 0 (can attack immediately).
var boss_attack_cooldown_remaining: float = 0.0

## tower_id locked in when the prepare phase starts. -1 = no locked target.
var boss_locked_target_id: int = -1

## Seconds remaining in an in-flight Hero-targeted wind-up (hero-damage spec §4.2).
## 0 = no Hero wind-up. A monster has at most one wind-up in flight (tower or Hero);
## boss_locked_target_id holds MonsterManager.HERO_TARGET_ID while this is > 0.
var hero_windup_remaining: float = 0.0

## Independent in-flight burn/poison DoT instances (design/gdd/damage-status.md
## Rule I.3 amendment; ADR-0006 5th pass). Stacks, does not refresh — see
## ActiveStatusEffect's own doc comment for why.
var active_status_effects: Array[ActiveStatusEffect] = []

## Independent in-flight slow instances (design/gdd/damage-status.md Formula D6,
## amended 2026-08-13). Combines multiplicatively, does not refresh — see
## ActiveSlowEffect's own doc comment for why. Read by Monster System's movement
## pass to compute effective speed; never mutates scaled_speed itself.
var active_slow_effects: Array[ActiveSlowEffect] = []

## Skill secondary effects spec (2026-10-07). Seconds left stunned: no movement,
## and attack scans/wind-ups are frozen until it reaches 0.
var stun_remaining: float = 0.0
## Armor shred as vulnerability: while vulnerability_remaining > 0, every hit
## and DoT tick on this monster is multiplied by (1 + vulnerability_bonus).
var vulnerability_remaining: float = 0.0
var vulnerability_bonus: float = 0.0
## Status pips (2026-11-03): last bitmask pushed to MonsterInstance.set_statuses()
## (bit i = MonsterInstance.STATUS_ORDER[i]); compared each frame so the
## pip list is only rebuilt when a status starts or ends.
var status_bits: int = 0

## Archetype behaviours (2026-11-02). Seconds until a healer's next heal pulse.
var heal_cooldown_remaining: float = 0.0
## True while a stealthed monster is hidden from towers (Hero not within its
## reveal radius). TowerSystem applies the same rule for targeting; this copy
## only drives the sprite fade.
var stealth_hidden: bool = false
## Dash (2026-11-04): seconds until the next burst, and seconds left in the
## current one (> 0 while dashing).
var dash_cooldown_remaining: float = 0.0
var dash_remaining: float = 0.0
## Haste from a drummer (2026-11-04): seconds left and the multiplier. A new
## pulse refreshes the timer and keeps the larger multiplier; hastes never stack.
var haste_remaining: float = 0.0
var haste_multiplier: float = 1.0
