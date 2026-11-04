class_name HeroTreeNodeResource
extends Resource

## One purchasable node of the expanded Hero Skill Tree that is not a spine
## skill: an archetype Root, a fork node, a keystone, or a cross-archetype
## bridge (design/quick-specs/hero-skill-tree-expansion-2026-11-04.md §5, §6a).
##
## Stats come in two buckets so the "additive % of a zero base is nothing"
## trap can be caught at load time (AC-X6):
## - `flat_stats`: added to the stat's base (the only way to raise a stat
##   whose base is 0, e.g. armor, lifesteal, cdr, crit_multiplier, resists).
## - `additive_stats`: additive fractions in the Formula 1 multiplier
##   (0.06 = +6%). Negative values are keystone penalties.
## `effect` (optional) uses the set-effect schema ({&"name", &"type",
## &"params"}) and runs through SetEffectController unchanged.
##
## Example: `var node := catalog.find("physical", &"fork_1", "L", 2)`

const SLOTS: Array[StringName] = [&"root", &"fork_1", &"fork_2", &"keystone", &"bridge"]
const FORK_SIDES: Array[String] = ["L", "R"]
const KEYSTONE_SIDES: Array[String] = ["A", "B"]

@export var id: StringName = &""
@export var display_name: String = ""
## One of HeroSkillTree.ARCHETYPES; empty for a bridge.
@export var archetype: String = ""
@export var slot: StringName = &""
## "L"/"R" for forks, "A"/"B" for keystones, "" for root and bridges.
@export var side: String = ""
## 0-2 inside a fork side; 0 otherwise.
@export var depth: int = 0
## Bridge only: its two archetypes.
@export var bridge_archetypes: PackedStringArray = PackedStringArray()
@export var flat_stats: Dictionary[StringName, float] = {}
@export var additive_stats: Dictionary[StringName, float] = {}
@export var effect: Dictionary = {}


## Load-time validation (registry convention: returns error strings, empty = valid).
func validate() -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("id must not be empty")
	if display_name.is_empty():
		errors.append("display_name must not be empty")
	if not SLOTS.has(slot):
		errors.append("unknown slot '%s'" % slot)
	if slot == &"bridge":
		if not archetype.is_empty():
			errors.append("a bridge has no archetype")
		if bridge_archetypes.size() != 2 or bridge_archetypes[0] == bridge_archetypes[1]:
			errors.append("a bridge needs 2 different bridge_archetypes")
		for a: String in bridge_archetypes:
			if not HeroSkillTree.ARCHETYPES.has(a):
				errors.append("unknown bridge archetype '%s'" % a)
	elif not HeroSkillTree.ARCHETYPES.has(archetype):
		errors.append("unknown archetype '%s'" % archetype)
	match slot:
		&"fork_1", &"fork_2":
			if not FORK_SIDES.has(side):
				errors.append("fork side must be L or R")
			if depth < 0 or depth >= HeroSkillTree.FORK_DEPTH:
				errors.append("fork depth must be 0-%d" % (HeroSkillTree.FORK_DEPTH - 1))
		&"keystone":
			if not KEYSTONE_SIDES.has(side):
				errors.append("keystone side must be A or B")
	if flat_stats.is_empty() and additive_stats.is_empty() and effect.is_empty():
		errors.append("node has no effect at all")
	for stat: StringName in flat_stats:
		if not EquipmentBonuses.FAN_OUT_STATS.has(stat):
			errors.append("unknown flat stat '%s'" % stat)
		elif flat_stats[stat] <= 0.0:
			errors.append("flat stat '%s' must be > 0" % stat)
	for stat: StringName in additive_stats:
		if not EquipmentBonuses.FAN_OUT_STATS.has(stat):
			errors.append("unknown additive stat '%s'" % stat)
		elif is_zero_base_stat(stat):
			errors.append("additive '%s' does nothing: its base is 0, use flat_stats" % stat)
		elif is_zero_approx(additive_stats[stat]):
			errors.append("additive stat '%s' must not be 0" % stat)
	if not effect.is_empty():
		errors.append_array(EquipmentSetResource._validate_effect(0, effect))
	return errors


## True for stats whose Hero base is 0, where an additive fraction multiplies nothing.
static func is_zero_base_stat(stat: StringName) -> bool:
	return is_zero_approx(Hero.PLACEHOLDER_BASE_STATS.get(stat, 0.0))
