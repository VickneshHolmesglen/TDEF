class_name TopComponent
extends Resource

## Top slot component (new 2026-09-01, player-requested — see
## shaft_component.gd's class doc comment for the full context/scope-boundary
## rationale, which applies identically here).
##
## GDD source: design/gdd/tower.md's Top table (Component Schema Amendment,
## 2026-09-01).
##
## Design decision (AskUserQuestion, player's own words): "Depending on the
## top type, it could be any offensive stat ... flat damage, critical strike
## chance, critical strike damage." Modeled as a typed bonus (`bonus_type` +
## `bonus_value`) rather than 3 separate float fields, mirroring
## PowerComponent's existing effect_type/effect_value idiom — a Top can only
## ever amplify ONE of Weapon's stats, never several at once, matching the
## "depending on the type" framing (a player chooses which offensive identity
## a Top gives a build, not a Top that does everything).
##
## Required starting at Tier 2 (Tower Assembly's tier-gated slot count:
## Tier 1 = Foundation+Weapon+Shaft, Tier 2 adds Top, Tier 3 adds Focus,
## Tier 4 adds Power).

## Content-authored identifier for this named component asset — see
## FoundationComponent.component_id's doc comment.
@export var component_id: String = ""

## "" (inert — matches every other component's none-convention) | "damage" |
## "crit_chance" | "crit_damage". Applied at tower_system.gd::_try_attack()
## to WeaponComponent's weapon_damage/crit_chance/crit_multiplier respectively,
## additively, never replacing the Weapon's own base values.
@export var bonus_type: String = ""
## Magnitude interpreted per bonus_type's own valid range (see validate()) —
## a single float field rather than 3 separately-ranged ones since only one
## is ever active per instance (bonus_type gates which range applies).
@export var bonus_value: float = 0.0
@export var damaged: bool = false

const VALID_BONUS_TYPES: Array[String] = ["", "damage", "crit_chance", "crit_damage"]


func validate() -> bool:
	var valid: bool = true
	if not VALID_BONUS_TYPES.has(bonus_type):
		push_error("[TopComponent] bonus_type '%s' must be one of %s" % [bonus_type, VALID_BONUS_TYPES])
		valid = false
	match bonus_type:
		"":
			if not is_zero_approx(bonus_value):
				push_error("[TopComponent] bonus_type '' (inert) requires bonus_value == 0.0, got %.2f" % bonus_value)
				valid = false
		"damage":
			if bonus_value < 0.0 or bonus_value > 40.0:
				push_error("[TopComponent] bonus_value %.2f outside [0.0, 40.0] for bonus_type 'damage'" % bonus_value)
				valid = false
		"crit_chance":
			if bonus_value < 0.0 or bonus_value > 0.3:
				push_error("[TopComponent] bonus_value %.2f outside [0.0, 0.3] for bonus_type 'crit_chance'" % bonus_value)
				valid = false
		"crit_damage":
			if bonus_value < 0.0 or bonus_value > 1.0:
				push_error("[TopComponent] bonus_value %.2f outside [0.0, 1.0] for bonus_type 'crit_damage'" % bonus_value)
				valid = false
	return valid
