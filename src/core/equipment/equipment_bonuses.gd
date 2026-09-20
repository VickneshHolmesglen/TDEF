class_name EquipmentBonuses
extends RefCounted

## Shared, pure equipment-bonus calculator (equipment-display spec §3.1-3.2).
## Extracted from Hero's private fold (equipment-stats-wiring spec §3.2-3.3)
## so Hero and the Inventory UI can never disagree. Static-only, no state.
## "contents" is the Inventory.get_equipped_item()/get_slot_contents() shape.

## Every real Hero _base_stats key (fan-out target for `additive_bonus_total`).
## MAINTENANCE POINT: add any new Hero stat here too. Hero.EQUIPMENT_FAN_OUT_STATS
## aliases this; hero_equipment_stats_test.gd checks it against PLACEHOLDER_BASE_STATS.
const FAN_OUT_STATS: Array[StringName] = [
	&"max_hp", &"physical_attack", &"move_speed", &"cdr", &"crit_chance",
	&"armor", &"magic_attack", &"attack_range", &"elemental_resist_fire",
	&"elemental_resist_frost", &"lifesteal", &"tower_affinity",
	&"crit_multiplier", &"luck",
]


## `additive_bonus_total` fans out into the additive bucket of every real
## stat; any other key is a flat bonus to that named stat. Unknown stat
## names are stored but never read by Hero (inert).
static func fold_stat_entry(stat: StringName, value: float, new_flat: Dictionary[StringName, float], new_additive: Dictionary[StringName, float]) -> void:
	if stat == &"additive_bonus_total":
		for real_stat: StringName in FAN_OUT_STATS:
			new_additive[real_stat] = new_additive.get(real_stat, 0.0) + value
	else:
		new_flat[stat] = new_flat.get(stat, 0.0) + value


static func _definition_for(contents: Dictionary) -> ItemDefinitionResource:
	var item_id: String = contents.get("item_id", "") as String
	if item_id == "":
		return null
	return GGameDataRegistry.get_item_definition(StringName(item_id))


## One item's own flat stats (no runes): base_stats template overlaid by
## stat_overrides (the real roll). {} if the item has no registered definition.
static func item_stats(contents: Dictionary) -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = {}
	var definition: ItemDefinitionResource = _definition_for(contents)
	if definition == null:
		return out
	for stat: StringName in definition.base_stats:
		out[stat] = definition.base_stats[stat]
	var overrides: Dictionary = contents.get("stat_overrides", {})
	for stat: Variant in overrides:
		out[StringName(stat)] = float(overrides[stat])
	return out


## The folded contribution of one item's imbued runes, resolved on demand.
static func rune_stats(contents: Dictionary) -> Dictionary:
	var flat: Dictionary[StringName, float] = {}
	var additive: Dictionary[StringName, float] = {}
	for rune_id: String in contents.get("imbued_runes", []):
		var delta: Dictionary = EquipmentForge.resolve_rune_stat_delta(StringName(rune_id))
		for stat: Variant in delta:
			fold_stat_entry(StringName(stat), float(delta[stat]), flat, additive)
	return {"flat": flat, "additive": additive}


## Full fold over any list of equipped-slot contents. Empty entries and
## items with no registered definition are skipped entirely (runes included),
## matching Hero's pre-extraction behavior.
static func compute(slot_contents: Array[Dictionary]) -> Dictionary:
	var flat: Dictionary[StringName, float] = {}
	var additive: Dictionary[StringName, float] = {}
	for contents: Dictionary in slot_contents:
		if contents.is_empty() or _definition_for(contents) == null:
			continue
		var stats: Dictionary[StringName, float] = item_stats(contents)
		for stat: StringName in stats:
			fold_stat_entry(stat, stats[stat], flat, additive)
		var runes: Dictionary = rune_stats(contents)
		for stat: StringName in runes["flat"]:
			flat[stat] = flat.get(stat, 0.0) + runes["flat"][stat]
		for stat: StringName in runes["additive"]:
			additive[stat] = additive.get(stat, 0.0) + runes["additive"][stat]
	var sets: Dictionary = set_bonuses(slot_contents)
	for stat: StringName in sets["flat"]:
		flat[stat] = flat.get(stat, 0.0) + sets["flat"][stat]
	for stat: StringName in sets["additive"]:
		additive[stat] = additive.get(stat, 0.0) + sets["additive"][stat]
	return {"flat": flat, "additive": additive}


static func _equipped_contents() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot_name: String in Inventory.EQUIPMENT_SLOT_NAMES:
		result.append(GInventory.get_equipped_item(slot_name))
	return result


static func compute_equipped() -> Dictionary:
	return compute(_equipped_contents())


## Public form of the equipped-slot list (10 entries in EQUIPMENT_SLOT_NAMES
## order, {} for empty slots).
static func equipped_contents() -> Array[Dictionary]:
	return _equipped_contents()


## The equipped list with `slot_name`'s entry replaced by `candidate_contents`
## (used by preview_swap() and by the panel's would-be set counts).
static func swapped_contents(slot_name: String, candidate_contents: Dictionary) -> Array[Dictionary]:
	var current: Array[Dictionary] = _equipped_contents()
	var swapped: Array[Dictionary] = []
	for i: int in range(Inventory.EQUIPMENT_SLOT_NAMES.size()):
		swapped.append(candidate_contents if Inventory.EQUIPMENT_SLOT_NAMES[i] == slot_name else current[i])
	return swapped


## Which set an item belongs to, or &"" (equipment-set-bonuses spec §3.4).
static func set_id_for_item(item_id: StringName) -> StringName:
	for set_res: EquipmentSetResource in GGameDataRegistry.get_all_equipment_sets().values():
		if set_res.member_item_ids.has(item_id):
			return set_res.set_id
	return &""


## {set_id: distinct equipped piece count} for sets with at least one piece
## equipped. Two copies of the same item count once; items with no registered
## definition are skipped, matching compute().
static func set_piece_counts(slot_contents: Array[Dictionary]) -> Dictionary:
	var equipped_ids: Dictionary = {}
	for contents: Dictionary in slot_contents:
		if contents.is_empty() or _definition_for(contents) == null:
			continue
		equipped_ids[StringName(contents.get("item_id", "") as String)] = true
	var counts: Dictionary = {}
	for set_res: EquipmentSetResource in GGameDataRegistry.get_all_equipment_sets().values():
		var n: int = 0
		for member: StringName in set_res.member_item_ids:
			if equipped_ids.has(member):
				n += 1
		if n > 0:
			counts[set_res.set_id] = n
	return counts


## Every earned set bonus (cumulative thresholds), folded with fold_stat_entry()
## so additive_bonus_total fans out like every other source. Returns the same
## {"flat","additive"} shape as compute().
static func set_bonuses(slot_contents: Array[Dictionary]) -> Dictionary:
	var flat: Dictionary[StringName, float] = {}
	var additive: Dictionary[StringName, float] = {}
	var counts: Dictionary = set_piece_counts(slot_contents)
	for set_id: StringName in counts:
		var set_res: EquipmentSetResource = GGameDataRegistry.get_equipment_set(set_id)
		if set_res == null:
			continue
		for threshold: int in set_res.bonuses:
			if (counts[set_id] as int) < threshold:
				continue
			var delta: Dictionary = set_res.bonuses[threshold]
			for stat: Variant in delta:
				fold_stat_entry(StringName(stat), float(delta[stat]), flat, additive)
	return {"flat": flat, "additive": additive}


static func _diff(after: Dictionary, before: Dictionary) -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = {}
	var keys: Dictionary = {}
	for k: Variant in after:
		keys[k] = true
	for k: Variant in before:
		keys[k] = true
	for k: Variant in keys:
		var d: float = float(after.get(k, 0.0)) - float(before.get(k, 0.0))
		if absf(d) > 0.00001:
			out[StringName(k)] = d
	return out


## Per-stat change in total equipment bonuses if `candidate_contents` replaced
## whatever is in `slot_name` (positive = gain). Zero differences omitted.
static func preview_swap(slot_name: String, candidate_contents: Dictionary) -> Dictionary:
	var before: Dictionary = compute(_equipped_contents())
	var after: Dictionary = compute(swapped_contents(slot_name, candidate_contents))
	return {
		"flat": _diff(after["flat"], before["flat"]),
		"additive": _diff(after["additive"], before["additive"]),
	}


## Which slot an inventory item of `category` would go into: the first empty
## slot of that category, else the first slot of that category; "" if none.
static func target_slot_for(category: String) -> String:
	var first_match: String = ""
	for slot_name: String in Inventory.EQUIPMENT_SLOT_NAMES:
		if Inventory.EQUIPMENT_SLOT_CATEGORY[slot_name] != category:
			continue
		if first_match == "":
			first_match = slot_name
		if GInventory.get_equipped_item(slot_name).is_empty():
			return slot_name
	return first_match
