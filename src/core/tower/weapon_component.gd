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
## Elemental archetype — "" | fire | frost | poison | lightning | arcane
## (design/gdd/tower.md "Elemental sub-type color language"). Drives
## ProjectileVisual's VFX color AND, as of the Tower Stats System Phase 1
## (player-requested 2026-08-16), real damage resolution: TowerSystem looks
## up the target's MonsterResource.elemental_resistances by this key and
## reduces damage accordingly (see tower_system.gd::_try_attack()). "" means
## physical — no resistance lookup, matches every monster's default (missing-
## key) resistance of 0.0. Poison/lightning/arcane have no assigned VFX color
## yet (Vertical Slice/Alpha scope); an unrecognized value falls back to the
## generic elemental placeholder color in ProjectileVisual but still resolves
## correctly for damage (resistance lookup and VFX color are independent).
@export var element: String = ""
@export var aura_effect_type: String = ""   # Support/AURA only, any effect id or ""
@export var aura_effect_value: float = 0.0  # Support/AURA only, [0.0, ...]
@export var aura_radius_cells: int = 0      # Support/AURA only, [1, 6]
@export var aoe_radius_cells: int = 0       # BALLISTIC only, [0, 4]
## Tower Stats System Phase 1 (player-requested 2026-08-16). Chance per
## attack to land a critical hit, applying crit_multiplier to that hit's
## damage. Mirrors Hero's crit concept (hero.gd's CRIT_CHANCE_CAP=0.8) but
## as a plain flat field, not Hero's Dictionary+get_effective_stat() runtime-
## modifier system — towers have no equipment/rune modifier stack today, so
## introducing one just for crit would be disproportionate scope.
@export var crit_chance: float = 0.0        # [0.0, 0.8]
## Flat multiplier applied to a hit's damage when crit_chance rolls true.
## No base-plus-bonus split (unlike Hero's CRIT_MULTIPLIER_BASE) — see
## crit_chance's own doc comment for why.
@export var crit_multiplier: float = 1.5    # [1.0, 3.0]
## Fraction of armored-monster damage mitigation (ARMORED_MITIGATION_
## MULTIPLIER in damage_status.gd, currently a flat 50%) this weapon negates.
## 0.0 = no change to today's mitigation; 1.0 = mitigation fully countered.
@export var armor_penetration: float = 0.0  # [0.0, 1.0]
## Chance per attack that this weapon's Power effect (PowerComponent.
## effect_type) actually applies. Previously effects always applied on every
## hit (no roll existed) — 1.0 preserves that behavior for existing content;
## values below 1.0 make status-effect towers a real probabilistic choice
## rather than a guarantee.
@export var status_proc_chance: float = 1.0 # [0.0, 1.0]
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
	if crit_chance < 0.0 or crit_chance > 0.8:
		push_error("[WeaponComponent] crit_chance %.2f outside [0.0, 0.8]" % crit_chance)
		valid = false
	if crit_multiplier < 1.0 or crit_multiplier > 3.0:
		push_error("[WeaponComponent] crit_multiplier %.2f outside [1.0, 3.0]" % crit_multiplier)
		valid = false
	if armor_penetration < 0.0 or armor_penetration > 1.0:
		push_error("[WeaponComponent] armor_penetration %.2f outside [0.0, 1.0]" % armor_penetration)
		valid = false
	if status_proc_chance < 0.0 or status_proc_chance > 1.0:
		push_error("[WeaponComponent] status_proc_chance %.2f outside [0.0, 1.0]" % status_proc_chance)
		valid = false
	return valid
