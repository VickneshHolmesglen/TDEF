class_name MonsterSpawnedEvent
extends Resource

## Event-payload Resource for the monster_spawned EventBus signal.
##
## ADR-0001 Rule 3: 5 fields — requires Resource subclass payload.
## ADR-0009: Event-payload Resources are short-lived; never saved as .tres files.
## GDD source: design/gdd/event-bus.md — Monster System event catalogue.
##
## Emitted by: Monster System (when a monster enters the field).
## Key subscribers: Pathfinding, Wave Manager, Mission HUD, Tower System.
##
## IMPORTANT — hp_max:
##   Tower System uses hp_max to seed the HP-tracking cache entry at spawn time.
##   Subscriber must be connected Synchronous (Tower GDD Rule 14a) — Tower System
##   must receive this before any tower_attacked events reference this entity.

@export var entity_id: int = -1
@export var monster_id: StringName = &""
@export var wave_index: int = -1
@export var grid_position: Vector2i = Vector2i(-1, -1)
@export var hp_max: float = 1.0
