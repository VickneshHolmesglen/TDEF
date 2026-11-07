class_name PlacementPreview
extends Resource

## Result of get_placement_preview() — returned for each hover position.
##
## ADR-0008: Gate 4 (path integrity) is NEVER checked on preview; only Gates 1–3.
## valid=true means Gates 1–3 passed. Gate 4 runs only on place_tower() commit.

enum PlacementBlockReason {
	NONE = 0,
	WAVE_ACTIVE = 1,
	INSUFFICIENT_RESOURCES = 2,
	FOOTPRINT_BLOCKED = 3,
	PATH_BLOCKED = 4,
}

var valid: bool = false
## Price at the hovered spot, hill premium included (spec 2026-11-07-3d-terrain §4.2).
var cost: int = 0
var reason: PlacementBlockReason = PlacementBlockReason.NONE
