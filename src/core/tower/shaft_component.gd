class_name ShaftComponent
extends Resource

## Shaft slot component (new 2026-09-01, player-requested — "wire the
## midsection ... into sanctuary" real-component follow-up to the visual-only
## Tower Component gallery added earlier the same day).
##
## GDD source: design/gdd/tower.md's Shaft table (Component Schema Amendment,
## 2026-09-01).
##
## Design decisions locked via AskUserQuestion before implementation:
## - Carries a real stat (not purely cosmetic): `range_bonus_cells`, added to
##   Focus's own `attack_range_cells` at attack-resolution time
##   (tower_system.gd::_get_effective_range()) — "a taller midsection sees
##   further."
## - Required at EVERY tier (Tower Assembly's tier-gated slot count starts at
##   3: Foundation + Weapon + Shaft), unlike Top/Focus/Power, which phase in
##   at tiers 2/3/4 respectively.
##
## Deliberately excluded from Tower Mastery's `build_signature` (Formula 4,
## tower-mastery.md) and from `TowerPlacedEvent`/`TowerComponentEquippedEvent`
## payloads — those stay scoped to the pre-existing 4-component core loadout.
## Shaft/Top are a combat-stat layer on top of that loadout, not part of the
## mastery-tracked identity of a tower. This is a deliberate scope boundary,
## not an oversight — extending build_signature to 6 components would ripple
## into Hero Skill Tree's archetype-crediting and every already-shipped
## mastery save, for no stated design benefit.

## Content-authored identifier for this named component asset — see
## FoundationComponent.component_id's doc comment.
@export var component_id: String = ""

## Added to Focus's attack_range_cells before the existing cone-bonus check
## (tower_system.gd::_get_effective_range()). 0.0 default = inert, matching
## every other component's "just use the export defaults" none-convention
## (FocusComponent/PowerComponent's own defaults are already inert the same way).
@export var range_bonus_cells: int = 0       # [0, 3]
@export var damaged: bool = false


func validate() -> bool:
	if range_bonus_cells < 0 or range_bonus_cells > 3:
		push_error("[ShaftComponent] range_bonus_cells %d outside [0, 3]" % range_bonus_cells)
		return false
	return true
