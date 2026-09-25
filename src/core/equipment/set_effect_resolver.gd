class_name SetEffectResolver
extends RefCounted

## Pure, static answer to "which set capstone effects are active for this
## equipment?" (equipment-set-effects spec §3.3). Same access pattern as
## EquipmentBonuses: reads the registry, holds no state, emits nothing.
## "slot_contents" is the Inventory.get_equipped_item() shape.


static func effect_key(set_id: StringName, threshold: int) -> StringName:
	return StringName("%s:%d" % [set_id, threshold])


## One entry per earned effect: {&"key", &"set_id", &"threshold", &"name",
## &"type", &"params"}, sorted by set_id then threshold. Piece counting reuses
## EquipmentBonuses.set_piece_counts() (distinct item_ids), so the controller
## and the info panel can never disagree.
static func active_effects(slot_contents: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var counts: Dictionary = EquipmentBonuses.set_piece_counts(slot_contents)
	var set_ids: Array = counts.keys()
	# StringName's < is not lexical; compare as String for a stable order.
	set_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for set_id: StringName in set_ids:
		var set_res: EquipmentSetResource = GGameDataRegistry.get_equipment_set(set_id)
		if set_res == null:
			continue
		var thresholds: Array = set_res.effects.keys()
		thresholds.sort()
		for threshold: int in thresholds:
			if (counts[set_id] as int) < threshold:
				continue
			var effect: Dictionary = set_res.effects[threshold]
			out.append({
				&"key": effect_key(set_id, threshold),
				&"set_id": set_id,
				&"threshold": threshold,
				&"name": effect[&"name"],
				&"type": effect[&"type"],
				&"params": effect[&"params"],
			})
	return out


## The set's declared effects (threshold -> effect), earned or not, for the
## info panel's muted rendering. {} for an unknown set.
static func effects_for_set(set_id: StringName) -> Dictionary:
	var set_res: EquipmentSetResource = GGameDataRegistry.get_equipment_set(set_id)
	if set_res == null:
		return {}
	return set_res.effects.duplicate()
