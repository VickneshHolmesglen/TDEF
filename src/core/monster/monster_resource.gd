class_name MonsterResource
extends Resource

## Data definition for a single monster archetype.
##
## GDD source: design/gdd/monster.md — Group 1 (Entity Data Schema)
## ADR-0009: Resource data model — one class_name per file, exported fields only.
##
## tier values: 0=STANDARD  1=ELITE  2=BOSS
## archetype_tag: &"" (untagged, default) or &"armored" (50% tower damage mitigation).
## base_damage / base_attack_interval / boss_attack_range_cells / hero_attack_windup_seconds:
## attack settings for the attack-capable tiers (hero-damage spec §4.1). ELITE attacks the
## Hero only; BOSS attacks towers and the Hero. STANDARD must leave them at 0.

@export_group("Identity")
@export var monster_id: StringName = &""
@export var display_name: String = ""
@export_range(0, 2) var tier: int = 0
@export var archetype_tag: StringName = &""

@export_group("Combat Stats")
@export var base_hp: float = 100.0
@export var base_speed: float = 1.0  ## cells per second at wave 1
## Tower Stats System Phase 1 (player-requested 2026-08-16): StringName
## element (matching WeaponComponent.element -- "fire"/"ice"/"poison"/
## "lightning"/"arcane", per HeroSkillEffectResource.VALID_DAMAGE_TYPES'
## canonical "frost" -> "ice" rename, 2026-09-04 -- corrected here 2026-09-18,
## this doc comment was stale) -> float resist fraction [0.0, 0.9]. Missing
## key = 0.0 (no resistance) -- fully backward-compatible, no data migration
## needed for existing monster content. Read by TowerSystem's monster cache
## (see tower_system.gd::_on_monster_spawned()) and applied in
## _try_attack()'s damage formula; physical hits (WeaponComponent.element ==
## "") never consult this dictionary at all. Capped at 0.9, not 1.0, so no
## element can make a monster fully damage-immune. Hero Combat & Stats
## Redesign (2026-09-18): this same dict now also mitigates the Hero's own
## Magic Attack damage (Hero._on_monster_spawned() caches it for that
## purpose too) -- one shared resistance value per element, not a separate
## tower-vs-hero pair.
@export var elemental_resistances: Dictionary = {}
## Hero Combat & Stats Redesign (2026-09-18), Section 3.3: mitigates the
## Hero's own outgoing PHYSICAL Attack damage only (never tower damage --
## that stays on archetype_tag/is_armored, untouched by this field). Formula:
## Mitigation% = Armor / (Armor + 50 x hero_level), hero_level hardcoded to 1
## in damage_status.gd pending the not-yet-designed Hero Leveling system.
## Default 0.0 = no mitigation (fully backward-compatible with every existing
## monster .tres, none of which author this field yet).
@export var armor: float = 0.0
## Hero Combat & Stats Redesign (2026-09-18), Section 3.3: flat percentage
## [0, 100] chance the Hero's attack (any damage_type) misses this monster
## entirely -- rolled before any damage math in damage_status.gd. Default 0.0
## = never evades (fully backward-compatible).
@export_range(0.0, 100.0, 0.1) var evasion: float = 0.0

@export_group("Drop / Economy")
@export var drop_table_id: StringName = &""
@export_range(0.0, 1.0, 0.01) var menagerie_attraction_drop_chance: float = 0.0

@export_group("Attack Settings (ELITE / BOSS)")
@export var boss_attack_range_cells: int = 0
@export var base_damage: float = 0.0
@export var base_attack_interval: float = 0.0
## Seconds between an attacker locking the Hero and the hit resolving (hero-damage spec §4.2).
## The boss-to-tower wind-up is a separate fixed frame count in MonsterManager.
@export var hero_attack_windup_seconds: float = 0.0


## Archetype behaviours (2026-11-02, enemy-variety pass). All default to "off", so
## existing monsters are unchanged. Each one exists to counter a build:
##   flying  -- crosses the map in a straight line, ignoring the maze; BALLISTIC
##              (lobbed) weapons cannot hit it, HOMING/BEAM can.
##   heal_*  -- periodically heals every other monster within the radius; kill it first.
##   split_* -- on death (not breach) releases split_count of split_into_monster_id
##              where it fell, continuing along its path.
##   stealth -- towers cannot target it unless the Hero is within
##              stealth_reveal_radius_cells (Chebyshev); the Hero can always hit it.
##   dash_*  -- (2026-11-04) every dash_interval_seconds it runs at
##              dash_speed_multiplier for dash_duration_seconds. Slows multiply
##              on top and a stun cancels the burst, so control blunts it.
##   haste_* -- (2026-11-04) every haste_interval_seconds it hastes every OTHER
##              monster within haste_radius_cells (Chebyshev) to
##              haste_speed_multiplier for haste_duration_seconds; kill it first.
@export_group("Archetype Behaviour")
@export_enum("ground", "flying") var movement_type: String = "ground"
@export var heal_radius_cells: int = 0
## Fraction of each ally's max HP restored per pulse.
@export_range(0.0, 1.0, 0.01) var heal_fraction: float = 0.0
@export var heal_interval_seconds: float = 0.0
@export var split_into_monster_id: StringName = &""
@export var split_count: int = 0
@export var stealthed: bool = false
@export var stealth_reveal_radius_cells: int = 0
@export var dash_speed_multiplier: float = 1.0
@export var dash_duration_seconds: float = 0.0
@export var dash_interval_seconds: float = 0.0
@export var haste_radius_cells: int = 0
@export var haste_speed_multiplier: float = 1.0
@export var haste_duration_seconds: float = 0.0
@export var haste_interval_seconds: float = 0.0


## True when this monster flies (straight-line path, untargetable by BALLISTIC).
func is_flying() -> bool:
	return movement_type == "flying"


## True when this monster heals nearby allies.
func is_healer() -> bool:
	return heal_radius_cells > 0 and heal_fraction > 0.0 and heal_interval_seconds > 0.0


## True when this monster splits on death.
func is_splitter() -> bool:
	return split_into_monster_id != &"" and split_count > 0


## True when this monster dashes (periodic speed burst).
func is_dasher() -> bool:
	return dash_speed_multiplier > 1.0 and dash_duration_seconds > 0.0 and dash_interval_seconds > 0.0


## True when this monster hastes nearby allies.
func is_haster() -> bool:
	return haste_radius_cells > 0 and haste_speed_multiplier > 1.0 			and haste_duration_seconds > 0.0 and haste_interval_seconds > 0.0


## Load-time validation. Called by GameDataRegistry at boot (ADR-0009).
## Returns [] when valid; one string per invalid field otherwise. Note:
## tier's valid range is also enforced here even though @export_range(0, 2)
## already constrains the editor UI — that constraint is not a runtime
## guarantee for values assigned programmatically.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if monster_id == &"":
		errors.append("monster_id must not be empty")
	if base_hp <= 0.0:
		errors.append("base_hp must be > 0 (got %.2f)" % base_hp)
	if base_speed <= 0.0:
		errors.append("base_speed must be > 0 (got %.2f)" % base_speed)
	if tier < 0 or tier > 2:
		errors.append("tier must be 0/1/2 (got %d)" % tier)
	if tier == 2:  # BOSS
		if base_damage <= 0.0:
			errors.append("BOSS tier requires base_damage > 0")
		if base_attack_interval <= 0.0:
			errors.append("BOSS tier requires base_attack_interval > 0")
		if boss_attack_range_cells <= 0:
			errors.append("BOSS tier requires boss_attack_range_cells > 0")
		if hero_attack_windup_seconds <= 0.0:
			errors.append("BOSS tier requires hero_attack_windup_seconds > 0")
	if tier == 1 and base_damage > 0.0:  # ELITE attacker (base_damage == 0 is a valid non-attacker)
		if base_attack_interval <= 0.0:
			errors.append("ELITE attacker requires base_attack_interval > 0")
		if boss_attack_range_cells <= 0:
			errors.append("ELITE attacker requires boss_attack_range_cells > 0")
		if hero_attack_windup_seconds <= 0.0:
			errors.append("ELITE attacker requires hero_attack_windup_seconds > 0")
	if tier == 0 and base_damage > 0.0:
		errors.append("STANDARD tier must have base_damage == 0")
	if hero_attack_windup_seconds < 0.0:
		errors.append("hero_attack_windup_seconds must not be negative (got %.2f)" % hero_attack_windup_seconds)
	for element: Variant in elemental_resistances:
		var resistance: float = elemental_resistances[element] as float
		if resistance < 0.0 or resistance > 0.9:
			errors.append("elemental_resistances[%s] must be in [0.0, 0.9] (got %.2f)" % [element, resistance])
	if armor < 0.0:
		errors.append("armor must not be negative (got %.2f)" % armor)
	if evasion < 0.0 or evasion > 100.0:
		errors.append("evasion must be in [0.0, 100.0] (got %.2f)" % evasion)
	if movement_type != "ground" and movement_type != "flying":
		errors.append("movement_type must be ground/flying (got %s)" % movement_type)
	if heal_radius_cells < 0 or heal_fraction < 0.0 or heal_interval_seconds < 0.0:
		errors.append("heal_* fields must not be negative")
	if split_count < 0 or split_count > 8:
		errors.append("split_count must be in [0, 8] (got %d)" % split_count)
	if split_into_monster_id == monster_id and monster_id != &"":
		errors.append("split_into_monster_id must not be the monster itself (infinite split)")
	if stealthed and stealth_reveal_radius_cells <= 0:
		errors.append("stealthed monsters need stealth_reveal_radius_cells > 0")
	if dash_speed_multiplier < 1.0 or dash_speed_multiplier > 5.0:
		errors.append("dash_speed_multiplier must be in [1.0, 5.0] (got %.2f)" % dash_speed_multiplier)
	if dash_duration_seconds < 0.0 or dash_interval_seconds < 0.0:
		errors.append("dash_* durations must not be negative")
	if haste_speed_multiplier < 1.0 or haste_speed_multiplier > 3.0:
		errors.append("haste_speed_multiplier must be in [1.0, 3.0] (got %.2f)" % haste_speed_multiplier)
	if haste_radius_cells < 0 or haste_duration_seconds < 0.0 or haste_interval_seconds < 0.0:
		errors.append("haste_* fields must not be negative")
	return errors
