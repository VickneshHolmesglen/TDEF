class_name FocusComponent
extends Resource

## Focus slot component (ADR-0008 Amendment 2026-07-19 — implementation
## catch-up). Schema per design/gdd/tower.md's Focus table (lines ~77-84).

## Content-authored identifier for this named component asset — see
## FoundationComponent.component_id's doc comment.
@export var component_id: String = ""

@export var targeting_mode: String = "CLOSEST_TO_GOAL"  # CLOSEST_TO_GOAL | SPAWN_ORDER | LOWEST_HP | HIGHEST_HP | SCATTER
@export var attack_range_cells: int = 3       # [1, 8]
@export var cone_half_angle: float = 180.0    # [22.5, 180.0]
@export var facing_direction: String = "N"    # N|NE|E|SE|S|SW|W|NW
@export var damaged: bool = false


func validate() -> bool:
	var valid: bool = true
	if attack_range_cells < 1 or attack_range_cells > 8:
		push_error("[FocusComponent] attack_range_cells %d outside [1, 8]" % attack_range_cells)
		valid = false
	if cone_half_angle < 22.5 or cone_half_angle > 180.0:
		push_error("[FocusComponent] cone_half_angle %.1f outside [22.5, 180.0]" % cone_half_angle)
		valid = false
	return valid
