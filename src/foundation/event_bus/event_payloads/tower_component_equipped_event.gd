class_name TowerComponentEquippedEvent
extends Resource

## Event-payload Resource for the tower_component_equipped EventBus signal.
##
## Promoted from 3 bare params to a Resource subclass (event-bus.md Core Rule
## 4) as part of Epic 06 Story 008 (Sprint 7). Carries the tower's COMPLETE
## current loadout after the equip, not just the single changed slot —
## Tower Mastery's build_signature is a function of all 4 slots
## simultaneously (Formula 4), and receiving only the changed slot would
## reintroduce the exact query-API need this Resource promotion avoids.
## ADR-0009: Event-payload Resources are short-lived; never saved as .tres files.
##
## No real emitter exists yet — Equipment Forge (Epic 08), which owns
## in-mission component swapping, has not been implemented. This Resource's
## shape is defined now so Tower Mastery's consuming handler
## (_on_tower_component_equipped) has a stable contract to build against;
## `slot`/`component_id` identify the single slot that changed, the 4
## `*_component_id` fields are the tower's resulting complete loadout.
##
## Key subscribers: Constellation, Mission HUD, Tower Mastery.

@export var tower_id: int = -1
@export var slot: String = ""
@export var component_id: String = ""
@export var foundation_component_id: String = ""
@export var weapon_component_id: String = ""
@export var focus_component_id: String = ""
@export var power_component_id: String = ""
