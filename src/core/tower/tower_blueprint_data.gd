class_name TowerBlueprintData
extends Resource

## Blueprint Resource composing a tower's 4 component slots (ADR-0008
## Amendment 2026-07-19 — implementation catch-up). Replaces the flat
## TowerData model — the inventory-owned, persistent blueprint. At placement
## commit, TowerSystem calls Resource.duplicate_deep() on each of the 4
## component sub-resources to create independent mission-instance copies
## (see TowerMissionState) — this Resource itself is never mutated at
## runtime.
##
## All fields are set in the Godot editor or loaded from .tres files.
## Call validate() after construction/load to catch out-of-range values.

@export_group("Identity")
@export var tower_id: StringName = &""
@export var display_name: String = ""
@export var placement_cost: int = 10

@export_group("Components")
@export var foundation: FoundationComponent
@export var weapon: WeaponComponent
@export var focus: FocusComponent
@export var power: PowerComponent


## Validates all 4 components plus this Resource's own top-level fields.
## Returns true only if every component (and this Resource) is valid.
func validate() -> bool:
	var valid: bool = true
	if tower_id == &"":
		push_error("[TowerBlueprintData] tower_id must not be empty")
		valid = false
	if foundation == null:
		push_error("[TowerBlueprintData '%s'] foundation component is null" % tower_id)
		valid = false
	elif not foundation.validate():
		valid = false
	if weapon == null:
		push_error("[TowerBlueprintData '%s'] weapon component is null" % tower_id)
		valid = false
	elif not weapon.validate():
		valid = false
	if focus == null:
		push_error("[TowerBlueprintData '%s'] focus component is null" % tower_id)
		valid = false
	elif not focus.validate():
		valid = false
	if power == null:
		push_error("[TowerBlueprintData '%s'] power component is null" % tower_id)
		valid = false
	elif not power.validate():
		valid = false
	return valid
