class_name MonsterResource
extends Resource

## Data definition for a single monster archetype.
##
## GDD source: design/gdd/monster.md — Group 1 (Entity Data Schema)
## ADR-0009: Resource data model — one class_name per file, exported fields only.
##
## tier values: 0=STANDARD  1=ELITE  2=BOSS
## archetype_tag: &"" (untagged, default) or &"armored" (50% tower damage mitigation).
## base_damage / base_attack_interval / boss_attack_range_cells: BOSS-only; set 0 for others.

@export_group("Identity")
@export var monster_id: StringName = &""
@export var display_name: String = ""
@export_range(0, 2) var tier: int = 0
@export var archetype_tag: StringName = &""

@export_group("Combat Stats")
@export var base_hp: float = 100.0
@export var base_speed: float = 1.0  ## cells per second at wave 1

@export_group("Drop / Economy")
@export var drop_table_id: StringName = &""
@export_range(0.0, 1.0, 0.01) var menagerie_attraction_drop_chance: float = 0.0

@export_group("BOSS Settings")
@export var boss_attack_range_cells: int = 0
@export var base_damage: float = 0.0
@export var base_attack_interval: float = 0.0


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
	return errors
