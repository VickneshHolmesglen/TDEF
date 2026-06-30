class_name MonsterDiedEvent
extends Resource

## Event-payload Resource for the monster_died EventBus signal.
##
## ADR-0001 Rule 3: 8 fields — requires Resource subclass payload.
## ADR-0009: Event-payload Resources are short-lived; never saved as .tres files.
## GDD source: design/gdd/event-bus.md — Monster System event catalogue.
##
## Emitted by: Monster System (on HP reaching 0 or wave_completed force-removal).
## Key subscribers: Resource Economy, Wave Manager, Constellation, Mission HUD.
##
## IMPORTANT — wave_reward_scalar:
##   Forwarded from the original monster_spawn_requested payload.
##   Monster System must NOT apply it to combat stats.
##   Resource Economy owns all drop scaling via this field.
##
## IMPORTANT — kill_source values:
##   "tower"      — killed by tower damage
##   "hero"       — killed by hero damage
##   "wave_end"   — force-removed at wave_completed
##   Resource Economy must filter kill_source == "wave_end" and suppress drop resolution.

@export var entity_id: int = -1
@export var monster_id: StringName = &""
@export var tier: int = 0  ## 0 = STANDARD, 1 = ELITE, 2 = BOSS
@export var drop_table_id: StringName = &""
@export var menagerie_attraction_drop_chance: float = 0.0
@export var world_position: Vector2 = Vector2.ZERO
@export var kill_source: String = ""
@export var wave_reward_scalar: float = 1.0
