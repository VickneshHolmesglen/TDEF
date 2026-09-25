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

## ADR-0038, Epic 16 Story 7: this entity's handle into
## MonsterSwarmRenderer3D's dense batch, or null if this entity was never
## registered (BOSS tier — still uses the legacy monster_instance 3D
## companion until Story 9 — or registration failed, e.g. an unmapped
## monster_id; either way, presentation absence is non-fatal to simulation,
## same policy as monster_instance itself). Set by
## MonsterManager._spawn_entity(), cleared implicitly on death/breach (the
## entity itself is queue_free()'d, so this field simply goes with it — no
## separate clear step needed, matching monster_instance's own lifecycle).
var swarm_handle: MonsterPresentationHandle = null

## ADR-0038, Epic 16 Story 9: this BOSS entity's handle into
## MonsterSwarmRenderer3D's capped BossCreaturePresenter3D pool. Mutually
## exclusive with swarm_handle above — a given entity is registered with
## AT MOST ONE of the two presentation systems (BOSS tier uses this field
## exclusively; STANDARD/ELITE use swarm_handle exclusively; see
## MonsterManager._spawn_entity()). Null if unregistered, registration
## failed (pool at capacity, unmapped monster_id), or this entity isn't
## BOSS tier.
var boss_presenter_handle: MonsterPresentationHandle = null

## ADR-0038, Epic 16 Story 8: seconds remaining in this entity's swarm
## hit-flash decay, counting down from MonsterInstance.HIT_FLASH_DURATION to
## 0.0 (manager-owned, per-frame decrement in
## MonsterManager._pass3c_visual_sync() — never a Tween). Feeds
## MonsterPresentationSnapshot.hit_flash (INSTANCE_CUSTOM.y) for
## swarm-registered (STANDARD/ELITE) entities only; BOSS's legacy
## companion keeps its own independent, unchanged
## MonsterInstance.play_hit_flash() Tween (see monster_manager.gd's
## _pass1_damage() doc comment for why these two are deliberately NOT
## unified in this story).
var hit_flash_remaining_seconds: float = 0.0

## ADR-0038, Epic 16 Story 8: true when this entity's most recent movement
## step had a negative X direction. Feeds
## MonsterPresentationSnapshot.facing_variant (INSTANCE_CUSTOM.w) for
## swarm-registered entities — updated every frame movement actually occurs
## in MonsterManager._advance_entity(), read (never written) by
## _pass3c_visual_sync(). Has no effect on the legacy 2D sprite or 3D
## companion (neither implements a facing flip).
var facing_left: bool = false

## ADR-0038, Epic 16 Story 8 follow-up: this swarm-registered (STANDARD/
## ELITE) entity's cached "walk" CreatureAnimationClip, resolved once at
## spawn time (MonsterManager._spawn_entity()) rather than looked up from
## GGameDataRegistry every frame in _pass3c_visual_sync() — keeps the
## per-frame visual-sync pass allocation/lookup-free per
## .claude/rules/engine-code.md's "ZERO allocations in hot paths" rule.
## Null if this creature's CreatureAtlasMappingResource has no "walk" clip
## (non-fatal — atlas_frame simply stays at the clip's absence default,
## matching monster_instance's own "presentation absence is non-fatal"
## policy) or this entity has no swarm_handle at all (BOSS tier).
var walk_clip: CreatureAnimationClip = null

## Seconds accumulated toward walk_clip's frame-cycling since this entity
## last had a live swarm_handle — mirrors BossCreaturePresenter3D's own
## _base_elapsed[slot] pattern (src/core/visual_presentation/
## boss_creature_presenter_3d.gd), just entity-owned instead of slot-array-owned
## since the swarm path has one MonsterEntity per creature rather than a
## capped presenter pool.
var walk_anim_elapsed_seconds: float = 0.0

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
