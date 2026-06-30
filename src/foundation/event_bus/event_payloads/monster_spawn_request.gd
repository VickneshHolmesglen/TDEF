class_name MonsterSpawnRequest
extends Resource

## Event-payload Resource for the monster_spawn_requested EventBus signal.
##
## ADR-0001 Rule 3: 5 fields — requires Resource subclass payload.
## ADR-0009: Event-payload Resources are short-lived; never saved as .tres files.
## GDD source: design/gdd/event-bus.md — Wave Manager event catalogue.
##
## Emitted by: Wave Manager (per spawn entry during WAVE_ACTIVE, after pre_delay elapses).
## Key subscribers: Monster System (instantiate entity).
##
## IMPORTANT — wave_reward_scalar:
##   Consumed by Resource Economy only.
##   Monster System must NOT apply wave_reward_scalar to combat stats.
##   Monster System forwards this value unchanged into MonsterDiedEvent.

@export var monster_id: StringName = &""
@export var spawn_cell: Vector2i = Vector2i(-1, -1)
@export var wave_index: int = -1
@export var difficulty_tier: int = 0
@export var wave_reward_scalar: float = 1.0
