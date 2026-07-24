class_name TowerPlacedEvent
extends Resource

## Event-payload Resource for the tower_placed EventBus signal.
##
## Promoted from 6 bare params to a Resource subclass (event-bus.md Core Rule
## 4: 5+ fields require a Resource subclass) as part of Epic 06 Story 008
## (Build Signature via Event-Payload Extension, Sprint 7): the 4 new
## foundation/weapon/focus/power_component_id fields pushed the signal well
## past the bare-param threshold it was already at (6 params pre-existing
## from Sprint 6 S6-08's constellation_eligibility_tag fix).
## ADR-0009: Event-payload Resources are short-lived; never saved as .tres files.
##
## Emitted by: Tower System (place_tower() commit).
## Key subscribers: Constellation, Hero, Pathfinding, Mission HUD, Audio,
##   Tower Mastery (derives build_signature from the 4 *_component_id fields
##   via Formula 4 — see tower_mastery.gd).

@export var tower_id: int = -1
@export var grid_position: Vector2i = Vector2i.ZERO
@export var archetype: String = ""
@export var footprint: Vector2i = Vector2i.ZERO
@export var placed_in_scout: bool = false
@export var constellation_eligibility_tag: String = ""
@export var foundation_component_id: String = ""
@export var weapon_component_id: String = ""
@export var focus_component_id: String = ""
@export var power_component_id: String = ""


## Convenience factory — lets callers that only care about the pre-existing
## 6 fields (most test call sites predating Story 008) construct a payload
## without naming every property individually. The 4 component_id fields
## default to "" (matching PowerComponent's own "unequipped" convention) for
## callers that don't need Formula 4's build_signature derivation.
static func make(tower_id: int, grid_position: Vector2i, archetype: String,
		footprint: Vector2i, placed_in_scout: bool, constellation_eligibility_tag: String = "",
		foundation_component_id: String = "", weapon_component_id: String = "",
		focus_component_id: String = "", power_component_id: String = "") -> TowerPlacedEvent:
	var payload := TowerPlacedEvent.new()
	payload.tower_id = tower_id
	payload.grid_position = grid_position
	payload.archetype = archetype
	payload.footprint = footprint
	payload.placed_in_scout = placed_in_scout
	payload.constellation_eligibility_tag = constellation_eligibility_tag
	payload.foundation_component_id = foundation_component_id
	payload.weapon_component_id = weapon_component_id
	payload.focus_component_id = focus_component_id
	payload.power_component_id = power_component_id
	return payload
