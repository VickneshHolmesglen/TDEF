class_name WeaponComponent
extends Resource

## Weapon slot component (ADR-0008 Amendment 2026-07-19 — implementation
## catch-up). Schema per design/gdd/tower.md's Weapon table (lines ~65-75).

## Content-authored identifier for this named component asset (e.g.
## "weap_frost_bolt") — see FoundationComponent.component_id's doc comment.
@export var component_id: String = ""

@export var weapon_damage: float = 10.0     # [8.0, 120.0]
@export var attack_speed: float = 1.0       # [0.5, 4.0]
@export var projectile_type: String = "BALLISTIC"  # HOMING | BALLISTIC | BEAM | AURA
@export var aura_effect_type: String = ""   # Support/AURA only, any effect id or ""
@export var aura_effect_value: float = 0.0  # Support/AURA only, [0.0, ...]
@export var aura_radius_cells: int = 0      # Support/AURA only, [1, 6]
@export var aoe_radius_cells: int = 0       # BALLISTIC only, [0, 4]
@export var damaged: bool = false


func validate() -> bool:
	var valid: bool = true
	if weapon_damage < 8.0 or weapon_damage > 120.0:
		push_error("[WeaponComponent] weapon_damage %.1f outside [8.0, 120.0]" % weapon_damage)
		valid = false
	if attack_speed < 0.5 or attack_speed > 4.0:
		push_error("[WeaponComponent] attack_speed %.2f outside [0.5, 4.0]" % attack_speed)
		valid = false
	if aoe_radius_cells < 0 or aoe_radius_cells > 4:
		push_error("[WeaponComponent] aoe_radius_cells %d outside [0, 4]" % aoe_radius_cells)
		valid = false
	return valid
