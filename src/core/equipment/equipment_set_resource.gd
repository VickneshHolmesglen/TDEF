class_name EquipmentSetResource
extends Resource

## One equipment set (equipment-set-bonuses spec §3.1): a family of items whose
## distinct equipped count earns cumulative stat bonuses. `bonuses` maps a
## pieces_required threshold to a stat delta using the same key rules as gear
## and runes -- a named stat is a flat bonus, `additive_bonus_total` fans out
## to every stat's additive bucket (equipment-stats-wiring spec §3.3).

@export var set_id: StringName = &""
@export var display_name: String = ""
@export var member_item_ids: Array[StringName] = []
@export var bonuses: Dictionary[int, Dictionary] = {}


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
	return errors
