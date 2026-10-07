extends PanelContainer

## Equipment info panel (equipment-display spec §3.3-3.6). Two states:
## "Equipment Bonuses" (default) and an item detail card with a swap preview.
## No class_name -- same class-cache-fragility reason as equipment_paperdoll.gd;
## inventory_screen.gd loads it via preload().

const STAT_DISPLAY_ORDER: Array[StringName] = [
	&"max_hp", &"armor", &"physical_attack", &"magic_attack", &"move_speed",
	&"attack_range", &"crit_chance", &"crit_multiplier", &"luck", &"cdr",
	&"lifesteal", &"elemental_resist_fire", &"elemental_resist_frost",
]
const INTEGER_STATS: Array[StringName] = [&"max_hp", &"armor", &"move_speed", &"attack_range"]
const PERCENT_STATS: Array[StringName] = [
	&"crit_chance", &"crit_multiplier", &"luck", &"cdr", &"lifesteal",
	&"elemental_resist_fire", &"elemental_resist_frost",
]
const COLOR_GAIN: String = "#5fd35f"
const COLOR_LOSS: String = "#e5534b"
const COLOR_MUTED: String = "#9aa3b2"

enum State { BONUSES, ITEM }

var _state: State = State.BONUSES
var _shown_equipped_slot: String = ""
var _header: Label
var _body: RichTextLabel


func _ready() -> void:
	custom_minimum_size = Vector2(260, 0)
	add_theme_stylebox_override("panel", ShellChromeStyle.chrome_panel_stylebox())
	var column := VBoxContainer.new()
	add_child(column)
	_header = Label.new()
	column.add_child(_header)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	# Fills the row and scrolls (2026-10-07): with fit_content a full kit's
	# stat + set-bonus list grew the panel past the window and pushed the
	# whole Inventory screen (tabs included) off the top.
	_body.fit_content = false
	_body.scroll_active = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.mouse_filter = Control.MOUSE_FILTER_PASS  # wheel scroll
	_body.custom_minimum_size = Vector2(240, 0)
	column.add_child(_body)
	GEventBus.equipment_slot_changed.connect(_on_equipment_slot_changed)
	GEventBus.item_rune_imbued.connect(_on_item_rune_imbued)
	show_bonuses()


func _exit_tree() -> void:
	if GEventBus.equipment_slot_changed.is_connected(_on_equipment_slot_changed):
		GEventBus.equipment_slot_changed.disconnect(_on_equipment_slot_changed)
	if GEventBus.item_rune_imbued.is_connected(_on_item_rune_imbued):
		GEventBus.item_rune_imbued.disconnect(_on_item_rune_imbued)


func _on_equipment_slot_changed(_slot: String, _new_item_id: String, _previous_item_id: String) -> void:
	refresh()


func _on_item_rune_imbued(_item_id: String, _rune_id: String, _rune_source: String) -> void:
	refresh()


# ---------------------------------------------------------------------------
# Formatting (static, unit-tested directly)
# ---------------------------------------------------------------------------

## Signed display string: integers for HP/armor/speed/range, percent (value
## x 100, one decimal) for fractional stats, one decimal for everything else
## (attack stats and any unknown key, so a content typo stays visible).
static func format_value(stat: StringName, value: float) -> String:
	var sign_char: String = "+" if value >= 0.0 else "-"
	var magnitude: float = absf(value)
	if INTEGER_STATS.has(stat):
		return "%s%d" % [sign_char, int(roundf(magnitude))]
	if PERCENT_STATS.has(stat):
		return "%s%.1f%%" % [sign_char, magnitude * 100.0]
	return "%s%.1f" % [sign_char, magnitude]


static func stat_label(stat: StringName) -> String:
	if STAT_DISPLAY_ORDER.has(stat):
		return TranslationServer.translate("INVENTORY_STAT_%s" % String(stat).to_upper())
	return String(stat)


## STAT_DISPLAY_ORDER entries present in `stats`, then any other keys sorted.
static func ordered_stats(stats: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for stat: StringName in STAT_DISPLAY_ORDER:
		if stats.has(stat):
			out.append(stat)
	var extras: Array[String] = []
	for key: Variant in stats:
		if not STAT_DISPLAY_ORDER.has(StringName(key)):
			extras.append(String(key))
	extras.sort()
	for extra: String in extras:
		out.append(StringName(extra))
	return out


static func _colored(text: String, color: String) -> String:
	return "[color=%s]%s[/color]" % [color, text]


static func _delta_suffix(stat: StringName, delta: float) -> String:
	if absf(delta) < 0.00001:
		return ""
	return " " + _colored("(%s)" % format_value(stat, delta), COLOR_GAIN if delta > 0.0 else COLOR_LOSS)


static func _stat_line(stat: StringName, value: float, suffix: String = "") -> String:
	return "%s %s%s" % [stat_label(stat), format_value(stat, value), suffix]


## "Max HP +60, Armor +25" style text for a stat delta; additive_bonus_total
## renders as "All stats +X%". Static, so it uses TranslationServer, not tr().
static func _delta_text(delta: Dictionary) -> String:
	var parts: Array[String] = []
	for stat: StringName in ordered_stats(delta):
		if stat == &"additive_bonus_total":
			parts.append("%s +%.1f%%" % [TranslationServer.translate("INVENTORY_INFO_ALL_STATS"), float(delta[stat]) * 100.0])
		else:
			parts.append(_stat_line(stat, float(delta[stat])))
	return ", ".join(parts)


## "Physical Attack +35%, Attack Range +15%" for an effect's additive stats.
static func _effect_stats_text(stats: Dictionary) -> String:
	var parts: Array[String] = []
	for stat: StringName in ordered_stats(stats):
		parts.append("%s +%d%%" % [stat_label(stat), int(roundf(float(stats[stat]) * 100.0))])
	return ", ".join(parts)


## "6s" for whole seconds, "2.5s" otherwise (String.num(6.0) would give "6.0").
static func _seconds_text(seconds: Variant) -> String:
	var value: float = float(seconds)
	if is_equal_approx(value, roundf(value)):
		return "%ds" % int(roundf(value))
	return "%ss" % String.num(value)


## Player-facing description of one capstone effect ({&"name", &"type",
## &"params"}). Lives here (UI layer) because it needs stat_label(); static, so
## it uses TranslationServer rather than tr().
static func describe_effect(effect: Dictionary) -> String:
	var params: Dictionary = effect[&"params"]
	match StringName(effect[&"type"]):
		&"on_kill_stack_buff":
			return TranslationServer.translate("SET_EFFECT_ON_KILL_STACK_BUFF") % [
				_effect_stats_text(params[&"stats"]), int(params[&"max_stacks"]), _seconds_text(params[&"duration"])]
		&"on_crit_status":
			var status: String = TranslationServer.translate("SET_EFFECT_STATUS_%s" % String(params[&"effect_type"]).to_upper())
			return TranslationServer.translate("SET_EFFECT_ON_CRIT_STATUS") % [
				status, int(roundf(float(params[&"effect_value"]) * 100.0)), _seconds_text(params[&"effect_duration"])]
		&"on_wave_start_buff":
			return TranslationServer.translate("SET_EFFECT_ON_WAVE_START_BUFF") % [
				_effect_stats_text(params[&"stats"]), _seconds_text(params[&"duration"])]
		&"on_skill_cast_buff":
			return TranslationServer.translate("SET_EFFECT_ON_SKILL_CAST_BUFF") % [
				_effect_stats_text(params[&"stats"]), _seconds_text(params[&"duration"])]
		&"phase_state":
			var names: Array[String] = []
			for phase: Variant in (params[&"phases"] as Array):
				names.append(TranslationServer.translate("SET_EFFECT_PHASE_%s" % String(phase)))
			return TranslationServer.translate("SET_EFFECT_PHASE_STATE") % [
				" / ".join(names), _effect_stats_text(params[&"stats"])]
		&"on_kill_heal":
			return TranslationServer.translate("SET_EFFECT_ON_KILL_HEAL") % _percent_text(params[&"heal_fraction"])
		&"on_hurt_shield":
			return TranslationServer.translate("SET_EFFECT_ON_HURT_SHIELD") % [
				_percent_text(params[&"shield_fraction"]), _seconds_text(params[&"duration"]), _seconds_text(params[&"cooldown"])]
		&"low_hp_state":
			return TranslationServer.translate("SET_EFFECT_LOW_HP_STATE") % [
				_percent_text(params[&"hp_fraction"]), _effect_stats_text(params[&"stats"])]
	return String(effect.get(&"type", ""))


## A fraction as a percentage without a trailing ".0": 0.08 -> "8", 0.015 -> "1.5".
static func _percent_text(fraction: Variant) -> String:
	var pct: float = snappedf(float(fraction) * 100.0, 0.1)
	if is_equal_approx(pct, roundf(pct)):
		return str(int(roundf(pct)))
	return String.num(pct, 1)


static func _additive_gain(additive_delta: Dictionary) -> bool:
	for stat: Variant in additive_delta:
		return float(additive_delta[stat]) > 0.0
	return false


# ---------------------------------------------------------------------------
# States
# ---------------------------------------------------------------------------

func show_bonuses() -> void:
	_state = State.BONUSES
	_shown_equipped_slot = ""
	_header.text = tr("INVENTORY_INFO_BONUSES_HEADER")
	var result: Dictionary = EquipmentBonuses.compute_equipped()
	var lines: Array[String] = []
	for stat: StringName in ordered_stats(result["flat"]):
		lines.append(_stat_line(stat, result["flat"][stat]))
	var additive_max: float = 0.0
	for stat: Variant in result["additive"]:
		additive_max = maxf(additive_max, float(result["additive"][stat]))
	if additive_max > 0.0:
		lines.append("%s +%.1f%%" % [tr("INVENTORY_INFO_ALL_STATS"), additive_max * 100.0])
	var set_lines: Array[String] = _set_section_lines()
	lines.append_array(set_lines)
	if lines.is_empty():
		lines.append(_colored(tr("INVENTORY_INFO_NO_BONUSES"), COLOR_MUTED))
	_body.text = "\n".join(lines)


## Set Bonuses section (spec §3.5): one header line per partially/fully
## equipped set, then one line per threshold, earned thresholds normal and
## unearned ones muted. Empty when no set piece is equipped.
func _set_section_lines() -> Array[String]:
	var lines: Array[String] = []
	var counts: Dictionary = EquipmentBonuses.set_piece_counts(EquipmentBonuses.equipped_contents())
	if counts.is_empty():
		return lines
	lines.append("")
	lines.append(tr("INVENTORY_INFO_SET_BONUSES_HEADER"))
	var ids: Array = counts.keys()
	ids.sort()
	for set_id: StringName in ids:
		var set_res: EquipmentSetResource = GGameDataRegistry.get_equipment_set(set_id)
		if set_res == null:
			continue
		var count: int = counts[set_id] as int
		lines.append(tr("INVENTORY_INFO_SET_HEADER_LINE") % [set_res.display_name, count, set_res.member_item_ids.size()])
		var thresholds: Array = set_res.bonuses.keys()
		thresholds.sort()
		for threshold: int in thresholds:
			var text: String = "  %s %s" % [tr("INVENTORY_INFO_SET_THRESHOLD") % threshold, _delta_text(set_res.bonuses[threshold])]
			lines.append(text if count >= threshold else _colored(text, COLOR_MUTED))
		var declared: Dictionary = SetEffectResolver.effects_for_set(set_id)
		var effect_thresholds: Array = declared.keys()
		effect_thresholds.sort()
		var top: int = 0
		for threshold: int in set_res.bonuses:
			top = maxi(top, threshold)
		for threshold: int in effect_thresholds:
			var effect: Dictionary = declared[threshold]
			# Set defensive effects spec §3.6: the top threshold is the capstone; a lower one is a second-tier effect.
			var label_key: String = "SET_EFFECT_CAPSTONE_LINE" if threshold >= top else "SET_EFFECT_TIER_LINE"
			var line: String = "  " + tr(label_key) % [threshold, effect[&"name"], describe_effect(effect)]
			lines.append(line if count >= threshold else _colored(line, COLOR_MUTED))
	return lines


## `equipped_slot` non-empty => the item is currently equipped (no swap
## preview); empty => an inventory item (swap preview vs. its target slot).
func show_item(contents: Dictionary, equipped_slot: String = "") -> void:
	_state = State.ITEM
	_shown_equipped_slot = equipped_slot
	var item_id: String = contents.get("item_id", "") as String
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(item_id))
	_header.text = definition.display_name if definition != null and definition.display_name != "" else item_id

	var lines: Array[String] = []
	if definition != null and definition.equipment_category != "":
		lines.append(_colored(definition.equipment_category.capitalize(), COLOR_MUTED))

	var set_id: StringName = EquipmentBonuses.set_id_for_item(StringName(item_id))
	if set_id != &"":
		var set_res: EquipmentSetResource = GGameDataRegistry.get_equipment_set(set_id)
		var would_be: Array[Dictionary]
		var target_slot: String = "" if definition == null else EquipmentBonuses.target_slot_for(definition.equipment_category)
		if equipped_slot == "" and target_slot != "":
			would_be = EquipmentBonuses.swapped_contents(target_slot, contents)
		else:
			would_be = EquipmentBonuses.equipped_contents()
		var count: int = EquipmentBonuses.set_piece_counts(would_be).get(set_id, 0) as int
		lines.append(tr("INVENTORY_INFO_SET_LINE") % [set_res.display_name, count, set_res.member_item_ids.size()])

	var own: Dictionary[StringName, float] = EquipmentBonuses.item_stats(contents)
	var preview: Dictionary = {"flat": {}, "additive": {}}
	if equipped_slot == "" and definition != null:
		var target: String = EquipmentBonuses.target_slot_for(definition.equipment_category)
		if target != "":
			preview = EquipmentBonuses.preview_swap(target, contents)

	if own.is_empty():
		lines.append(_colored(tr("INVENTORY_INFO_NO_STATS"), COLOR_MUTED))
	for stat: StringName in ordered_stats(own):
		lines.append(_stat_line(stat, own[stat], _delta_suffix(stat, preview["flat"].get(stat, 0.0))))
	# Stats the swap changes that the candidate itself lacks (a removed item's
	# stat, or a set bonus completed/broken by the swap): gains and losses,
	# signed, never color alone.
	for stat: StringName in ordered_stats(preview["flat"]):
		if not own.has(stat) and absf(preview["flat"][stat]) > 0.00001:
			var change: float = preview["flat"][stat]
			lines.append(_colored(_stat_line(stat, change), COLOR_GAIN if change > 0.0 else COLOR_LOSS))
	var additive_change: float = 0.0
	for stat: Variant in preview["additive"]:
		additive_change = maxf(additive_change, absf(float(preview["additive"][stat])))
	if additive_change > 0.00001:
		var sign_char: String = "+" if _additive_gain(preview["additive"]) else "-"
		lines.append(_colored("%s %s%.1f%%" % [tr("INVENTORY_INFO_ALL_STATS"), sign_char, additive_change * 100.0], COLOR_GAIN if sign_char == "+" else COLOR_LOSS))

	for rune_id: String in contents.get("imbued_runes", []):
		var delta: Dictionary = EquipmentForge.resolve_rune_stat_delta(StringName(rune_id))
		if delta.is_empty():
			lines.append("%s: %s" % [tr("INVENTORY_INFO_RUNE_LINE"), tr("INVENTORY_INFO_UNKNOWN_RUNE")])
			continue
		var parts: Array[String] = []
		for stat: Variant in delta:
			if StringName(stat) == &"additive_bonus_total":
				parts.append("%s +%.1f%%" % [tr("INVENTORY_INFO_ALL_STATS"), float(delta[stat]) * 100.0])
			else:
				parts.append(_stat_line(StringName(stat), float(delta[stat])))
		lines.append("%s: %s" % [tr("INVENTORY_INFO_RUNE_LINE"), ", ".join(parts)])

	var total_slots: int = contents.get("rune_slot_count", 0) as int
	if total_slots > 0:
		var used: int = (contents.get("imbued_runes", []) as Array).size()
		lines.append(_colored(tr("INVENTORY_INFO_RUNE_SLOTS") % [maxi(total_slots - used, 0), total_slots], COLOR_MUTED))
	_body.text = "\n".join(lines)


## Re-render after an equip/unequip/imbue. An equipped-item card is re-read
## from live inventory (falling back to Bonuses if its slot emptied); an
## inventory-item card falls back to Bonuses, since the item it described
## has likely just moved -- the next hover/focus re-shows a fresh card.
func refresh() -> void:
	if _state == State.ITEM and _shown_equipped_slot != "":
		var live: Dictionary = GInventory.get_equipped_item(_shown_equipped_slot)
		if not live.is_empty():
			show_item(live, _shown_equipped_slot)
			return
	show_bonuses()


## Plain (BBCode-stripped) body text, for tests.
func get_body_text() -> String:
	return _body.get_parsed_text()
