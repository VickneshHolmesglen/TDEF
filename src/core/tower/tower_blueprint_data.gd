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
## Shaft/Top (new 2026-09-01) — see shaft_component.gd/top_component.gd's own
## class doc comments. Deliberately NULLABLE, unlike the 4 components above:
## every one of this project's 18 pre-existing, already-shipped static
## blueprints (assets/data/towers/blueprints/) predates this feature and has
## no Shaft/Top authored at all. Rather than a breaking content migration,
## null is treated as "inert" everywhere this Resource is consumed
## (validate() below, and tower_system.gd's place_tower(), which substitutes
## a fresh ShaftComponent.new()/TopComponent.new() — both types' own export
## defaults are already inert) — a null Shaft/Top behaves identically to an
## explicit +0/"" one.
@export var shaft: ShaftComponent
@export var top: TopComponent


## Validates all populated components plus this Resource's own top-level
## fields. Foundation/Weapon/Focus/Power remain required (non-null); Shaft/
## Top are optional (null = inert, see their own field doc comment above) —
## if present, they must still individually validate.
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
	if shaft != null and not shaft.validate():
		valid = false
	if top != null and not top.validate():
		valid = false
	return valid


## Formula 4 (tower.md): placement_cost must equal round(base_cost *
## archetype_cost_factor * tier_cost_factor) for STATIC, content-authored
## blueprints (the .tres catalogue under assets/data/towers/blueprints/).
## Deliberately NOT folded into validate() above -- TowerAssembly.gd's
## assemble_tower() produces TowerBlueprintData at runtime using its own,
## intentionally different pricing formula (BASE_ASSEMBLY_COST *
## tier_cost_factor * 1.75, a "quick-spec" assembly markup unrelated to
## Formula 4) from the same FoundationComponent.base_cost field, which is
## legitimately correct and must still pass validate() (see
## tower_assembly_test.gd::test_assembled_blueprint_is_immediately_registered_and_placeable).
## Call this only at the GameDataRegistry content-load boundary (TD-tower-009,
## docs/tech-debt-register.md), never on a dynamically-assembled blueprint.
func validate_placement_cost_matches_formula_4() -> bool:
	if foundation == null:
		return true  # validate() already reports the null-foundation error
	var expected_cost: int = roundi(foundation.base_cost * foundation.archetype_cost_factor * foundation.tier_cost_factor)
	if placement_cost != expected_cost:
		push_error("[TowerBlueprintData '%s'] placement_cost %d does not match Formula 4 (base_cost %d * archetype_cost_factor %.2f * tier_cost_factor %.2f = %d)" % [tower_id, placement_cost, foundation.base_cost, foundation.archetype_cost_factor, foundation.tier_cost_factor, expected_cost])
		return false
	return true
