class_name EquipmentSetResource
extends Resource

## One equipment set (equipment-set-bonuses spec §3.1): a family of items whose
## distinct equipped count earns cumulative stat bonuses. `bonuses` maps a
## pieces_required threshold to a stat delta using the same key rules as gear
## and runes -- a named stat is a flat bonus, `additive_bonus_total` fans out
## to every stat's additive bucket (equipment-stats-wiring spec §3.3).
## A set may also carry capstone `effects` (equipment-set-effects spec §3.2).

@export var set_id: StringName = &""
@export var display_name: String = ""
@export var member_item_ids: Array[StringName] = []
@export var bonuses: Dictionary[int, Dictionary] = {}

const EFFECT_TYPES: Array[StringName] = [
	&"on_kill_stack_buff", &"on_crit_status", &"on_wave_start_buff",
	&"on_skill_cast_buff", &"phase_state",
	# Set defensive effects spec §3.1 (second-tier effects, live since Hero damage shipped).
	&"on_kill_heal", &"on_hurt_shield", &"low_hp_state",
]
## MAINTENANCE POINT: must equal WaveManager.Phase.keys(); a test enforces it.
## Kept here (not read from WaveManager) so core data never depends on gameplay code.
const KNOWN_PHASES: Array[String] = [
	"IDLE", "SCOUT", "PRE_WAVE", "WAVE_ACTIVE", "INTERMISSION", "MISSION_COMPLETE", "DEFEAT",
]
const CRIT_STATUS_EFFECT_TYPES: Array[String] = ["burn", "poison"]
const REQUIRED_PARAMS: Dictionary = {
	&"on_kill_stack_buff": [&"stats", &"max_stacks", &"duration"],
	&"on_crit_status": [&"effect_type", &"effect_value", &"effect_duration"],
	&"on_wave_start_buff": [&"stats", &"duration"],
	&"on_skill_cast_buff": [&"stats", &"duration"],
	&"phase_state": [&"stats", &"phases"],
	&"on_kill_heal": [&"heal_fraction"],
	&"on_hurt_shield": [&"shield_fraction", &"duration", &"cooldown"],
	&"low_hp_state": [&"hp_fraction", &"stats"],
}
## Params that are fractions of the Hero's max HP: must be in (0, 1].
const FRACTION_PARAMS: Array[StringName] = [&"heal_fraction", &"shield_fraction", &"hp_fraction"]

## Set effects: pieces_required -> {&"name": String, &"type": StringName,
## &"params": Dictionary}. Empty is valid (a set with no effects). By content
## convention (set defensive effects spec §3.3) the top threshold holds the
## capstone and at most one lower threshold holds a second-tier effect.
@export var effects: Dictionary[int, Dictionary] = {}


## Load-time validation (registry convention: returns error strings).
func validate() -> Array[String]:
	var errors: Array[String] = []
	if set_id == &"":
		errors.append("set_id must not be empty")
	if display_name == "":
		errors.append("display_name must not be empty")
	var unique: Dictionary = {}
	for item_id: StringName in member_item_ids:
		unique[item_id] = true
	if unique.size() < 2:
		errors.append("must have at least 2 unique member_item_ids (has %d)" % unique.size())
	if unique.size() != member_item_ids.size():
		errors.append("member_item_ids contains duplicates")
	if bonuses.is_empty():
		errors.append("bonuses must not be empty")
	for threshold: int in bonuses:
		if threshold < 2 or threshold > unique.size():
			errors.append("threshold %d must be between 2 and %d" % [threshold, unique.size()])
		var delta: Dictionary = bonuses[threshold]
		if delta.is_empty():
			errors.append("threshold %d has an empty delta" % threshold)
		for stat: Variant in delta:
			var key: StringName = StringName(stat)
			if key != &"additive_bonus_total" and not EquipmentBonuses.FAN_OUT_STATS.has(key):
				errors.append("threshold %d: unknown stat key '%s'" % [threshold, key])
			if float(delta[stat]) <= 0.0:
				errors.append("threshold %d: value for '%s' must be > 0" % [threshold, key])
	for threshold: int in effects:
		if threshold < 2 or threshold > unique.size():
			errors.append("effect threshold %d must be between 2 and %d" % [threshold, unique.size()])
		errors.append_array(_validate_effect(threshold, effects[threshold]))
	return errors


static func _is_positive_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and float(value) > 0.0


static func _validate_effect(threshold: int, effect: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var prefix: String = "effect %d: " % threshold
	if String(effect.get(&"name", "")) == "":
		errors.append(prefix + "name must not be empty")
	var type: StringName = StringName(effect.get(&"type", &""))
	if not EFFECT_TYPES.has(type):
		errors.append(prefix + "unknown type '%s'" % type)
		return errors
	var raw_params: Variant = effect.get(&"params", null)
	if not raw_params is Dictionary:
		errors.append(prefix + "params must be a Dictionary")
		return errors
	var params: Dictionary = raw_params
	var required: Array = REQUIRED_PARAMS[type]
	for key: StringName in required:
		if not params.has(key):
			errors.append(prefix + "missing param '%s'" % key)
	for key: Variant in params:
		if not required.has(StringName(key)):
			errors.append(prefix + "unknown param '%s'" % key)
	if params.has(&"stats"):
		errors.append_array(_validate_stats(prefix, params[&"stats"]))
	if params.has(&"max_stacks"):
		var stacks: Variant = params[&"max_stacks"]
		if typeof(stacks) != TYPE_INT or int(stacks) < 1:
			errors.append(prefix + "max_stacks must be an int >= 1")
	for key: StringName in [&"duration", &"effect_value", &"effect_duration", &"cooldown"]:
		if params.has(key) and not _is_positive_number(params[key]):
			errors.append(prefix + "%s must be a number > 0" % key)
	for key: StringName in FRACTION_PARAMS:
		if params.has(key) and (not _is_positive_number(params[key]) or float(params[key]) > 1.0):
			errors.append(prefix + "%s must be a number in (0, 1]" % key)
	# Raising max HP lowers the HP fraction, so a low-HP state that grants max_hp could flicker.
	if type == &"low_hp_state" and params.get(&"stats") is Dictionary and (params[&"stats"] as Dictionary).has(&"max_hp"):
		errors.append(prefix + "low_hp_state stats must not include max_hp")
	if params.has(&"effect_type") and not CRIT_STATUS_EFFECT_TYPES.has(String(params[&"effect_type"])):
		errors.append(prefix + "effect_type must be burn or poison")
	if params.has(&"phases"):
		errors.append_array(_validate_phases(prefix, params[&"phases"]))
	return errors


static func _validate_stats(prefix: String, stats: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not stats is Dictionary or (stats as Dictionary).is_empty():
		errors.append(prefix + "stats must be a non-empty Dictionary")
		return errors
	for stat: Variant in (stats as Dictionary):
		var key: StringName = StringName(stat)
		if not EquipmentBonuses.FAN_OUT_STATS.has(key):
			errors.append(prefix + "unknown stat key '%s'" % key)
		if not _is_positive_number((stats as Dictionary)[stat]):
			errors.append(prefix + "stat '%s' must be a number > 0" % key)
	return errors


static func _validate_phases(prefix: String, phases: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not phases is Array or (phases as Array).is_empty():
		errors.append(prefix + "phases must be a non-empty Array")
		return errors
	for phase: Variant in (phases as Array):
		if not KNOWN_PHASES.has(String(phase)):
			errors.append(prefix + "unknown phase '%s'" % phase)
	return errors
