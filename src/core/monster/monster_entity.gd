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

var lifecycle_state: int = State.SPAWNING

## &"hero" or &"tower" — set from last MonsterDamageTaken.source_type; forwarded in monster_died.
var last_hit_source: StringName = &"tower"

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

## Independent in-flight burn/poison DoT instances (design/gdd/damage-status.md
## Rule I.3 amendment; ADR-0006 5th pass). Stacks, does not refresh — see
## ActiveStatusEffect's own doc comment for why.
var active_status_effects: Array[ActiveStatusEffect] = []

## Independent in-flight slow instances (design/gdd/damage-status.md Formula D6,
## amended 2026-08-13). Combines multiplicatively, does not refresh — see
## ActiveSlowEffect's own doc comment for why. Read by Monster System's movement
## pass to compute effective speed; never mutates scaled_speed itself.
var active_slow_effects: Array[ActiveSlowEffect] = []
