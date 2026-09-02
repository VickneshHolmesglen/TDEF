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


## Rule 12a (tower.md) / TD-tower-004 (docs/tech-debt-register.md): the
## equip-time cross-component "wasted benefit" warning that entry's own fix
## left explicitly unimplemented, flagged there as needing "a cross-component
## view, not FoundationComponent.validate()'s single-resource view" — this
## Resource is exactly that view, since it already holds Foundation (owner
## of `pre_placement_perk`/`perk_power`) and Weapon/Focus (owners of the
## paired stat the perk boosts) simultaneously. A load-time WARNING, not a
## validate() failure — an over-authored perk_power that partially exceeds
## the paired stat's hard cap is still legal content, just suboptimal
## (matches tower.md's AC-Rule-12a wording exactly: "a load-time WARNING
## (not hard error)"). Formulas mirror tower_system.gd's
## `_apply_pre_placement_perk()` exactly, so a warning here means that
## function's real applied effect will also be partially wasted, not just a
## theoretical one.
##
## DAMAGE_BOOST is deliberately excluded — `weapon_damage` has no universal
## hard cap the way `attack_speed`/`attack_range_cells`/`aura_radius_cells`
## do elsewhere in this codebase (its [8.0, 120.0] range is a per-component
## content bound, not a boosted-value ceiling), matching Rule 12a's own AC
## wording (a SPEED_BOOST example only).
##
## Deliberately does not check the perk's `archetype_restrictions` (would
## require a `GGameDataRegistry` dependency this pure-data Resource
## otherwise has no need of) — an archetype-ineligible perk silently no-ops
## entirely at `_apply_pre_placement_perk()` (0% benefit realized), a
## different and more severe condition than "partially capped," and out of
## this warning's stated scope. Call only at the GameDataRegistry
## content-load boundary, matching `validate_placement_cost_matches_formula_4()`'s
## own convention above.
func warn_if_perk_benefit_wasted() -> void:
	if foundation == null or foundation.pre_placement_perk == "":
		return
	var power: float = foundation.perk_power
	match foundation.pre_placement_perk:
		"SPEED_BOOST":
			if weapon == null:
				return
			var boosted_speed: float = weapon.attack_speed * (1.0 + power)
			if boosted_speed > 4.0:
				push_warning("[TowerBlueprintData '%s'] SPEED_BOOST perk_power %.4f boosts attack_speed %.2f to %.4f, exceeding the 4.0 cap — partial perk benefit wasted" % [tower_id, power, weapon.attack_speed, boosted_speed])
		"RANGE_BOOST":
			if focus == null:
				return
			var boosted_range: int = focus.attack_range_cells + roundi(power * 8.0)
			if boosted_range > 8:
				push_warning("[TowerBlueprintData '%s'] RANGE_BOOST perk_power %.4f boosts attack_range_cells %d to %d, exceeding the 8 cap — partial perk benefit wasted" % [tower_id, power, focus.attack_range_cells, boosted_range])
		"AURA_EXTEND":
			if weapon == null:
				return
			var boosted_radius: int = weapon.aura_radius_cells + roundi(power * 6.0)
			if boosted_radius > 6:
				push_warning("[TowerBlueprintData '%s'] AURA_EXTEND perk_power %.4f boosts aura_radius_cells %d to %d, exceeding the 6 cap — partial perk benefit wasted" % [tower_id, power, weapon.aura_radius_cells, boosted_radius])
