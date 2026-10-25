class_name ResourceHeader
extends Control

## Sanctuary UI persistent resource header (Story 004, ADR-0001, epic-10-sanctuary-ui).
##
## GDD source: design/gdd/sanctuary-ui.md -- Core Rule 3, AC Group 3.
## Story: production/epics/epic-10-sanctuary-ui/story-004-resource-header.md
##
## Read-only pure subscriber to materials deltas -- owns no authoritative
## data, validates nothing, has no interactive affordance (never focusable,
## per Core Rule 3's explicit "not a 6th navigable region"). Renders at the
## top edge of the screen in every state, including OVERVIEW (Story 001's
## chrome layer already guarantees this header is always present/rendering).
##
## Gold deliberately NOT shown here (2026-08-06, design/quick-specs/
## sanctuary-header-drop-gold-2026-08-06.md), closing a real cross-GDD
## inconsistency found while investigating this class's own previously-
## flagged "no balance owner" gap: gold is mission-scoped ephemeral budget
## (resource-economy.md Rule 1, ADR-0018) -- reset to 0 on every
## mission_launched, no save/restore obligation, no carry-over mechanic to
## the Sanctuary anywhere in the codebase. A persistent Sanctuary gold
## display was never correct, regardless of who "owned" the balance; the
## fix is removing the display, not inventing a new balance-owning system to
## serve a display that shouldn't exist. Materials remain here since
## Inventory is their real ledger of record and they genuinely do persist
## into the Sanctuary.

var _materials: Dictionary = {}

## strings.csv key for the plaque title. Set before adding to the tree; the
## Loadout shell reuses this header with its own title so both screens share
## one chrome (2026-10-25 AAA UI pass).
var title_key: String = "SANCTUARY_HEADER_TITLE"

@onready var _background: Panel = Panel.new()
@onready var _row: HBoxContainer = HBoxContainer.new()
@onready var _title_label: Label = Label.new()
## 2026-10-25 AAA UI pass: the readout was one joined text string ("Goblin Hide 254 ·
## Iron Ore 21 · ..."), which reads as debug output. Now one chip per material --
## inset frame, item icon, count -- with the display name as a hover tooltip.
@onready var _materials_row: HBoxContainer = HBoxContainer.new()

const CHIP_ICON_SIZE: float = 26.0


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.add_theme_stylebox_override("panel", ShellChromeStyle.resource_header_stylebox())
	add_child(_background)

	_row.name = &"ResourceRow"
	add_child(_row)
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Inset past resource_header_stylebox()'s own texture_margin_left/right
	# (30px) -- the row previously ignored the header art's decorative
	# corner-flourish frame entirely, so text rendered flush against (and
	# under) the gold bevel instead of inside it.
	_row.offset_left = 32.0
	_row.offset_right = -32.0
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 8)

	## Plaque title -- the header art was designed as a "compact title
	## plaque" (shell_chrome_style.gd's own doc comment) but no title text
	## was ever added, leaving it a blank gold-bordered bar. Not a GDD
	## requirement (Core Rule 3 only specifies the materials readout); this
	## is the plaque's own identifying label.
	_title_label.name = &"TitleLabel"
	_row.add_child(_title_label)
	_title_label.text = tr(title_key)
	_title_label.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_materials_row.name = &"MaterialsRow"
	# 2026-10-07 (player-reported): inside the 320 px title plaque there was only
	# room for one material, the rest ellipsized away. The plaque now carries just
	# its title, and the readout sits in the empty top strip to the plaque's right,
	# sized to the window (see _layout_materials()). Clipped, never wrapped: the
	# header has a fixed height.
	add_child(_materials_row)
	_materials_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_materials_row.add_theme_constant_override("separation", 10)
	_materials_row.clip_contents = true
	_materials_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout_materials)
	get_viewport().size_changed.connect(_layout_materials)
	_layout_materials()

	_seed_from_inventory()
	_refresh_label()
	GEventBus.materials_earned.connect(_on_materials_earned)
	GEventBus.materials_spent.connect(_on_materials_spent)
	GEventBus.item_added.connect(_on_inventory_changed)
	GEventBus.item_removed.connect(_on_inventory_changed)


## Gap between the plaque's right edge and the materials readout.
const MATERIALS_GAP: float = 16.0


## Places the materials readout right of the plaque, spanning the rest of the
## window's width (the header Control itself is only the plaque's 320 px).
func _layout_materials() -> void:
	var available: float = get_viewport_rect().size.x - global_position.x - size.x - MATERIALS_GAP * 2.0
	_materials_row.position = Vector2(size.x + MATERIALS_GAP, 0.0)
	_materials_row.size = Vector2(maxf(available, 0.0), size.y)


func _exit_tree() -> void:
	if get_viewport() != null and get_viewport().size_changed.is_connected(_layout_materials):
		get_viewport().size_changed.disconnect(_layout_materials)
	GEventBus.materials_earned.disconnect(_on_materials_earned)
	GEventBus.materials_spent.disconnect(_on_materials_spent)
	if GEventBus.item_added.is_connected(_on_inventory_changed):
		GEventBus.item_added.disconnect(_on_inventory_changed)
	if GEventBus.item_removed.is_connected(_on_inventory_changed):
		GEventBus.item_removed.disconnect(_on_inventory_changed)


## Test/inspection accessor -- current locally-accumulated quantity for one
## material type (0 if never seen).
func get_material_quantity(material_type: String) -> int:
	return int(_materials.get(material_type, 0))


func _on_materials_earned(material_type: String, quantity: int, _source: String) -> void:
	_materials[material_type] = int(_materials.get(material_type, 0)) + quantity
	_refresh_label()
	_play_scale_pop()


func _on_materials_spent(material_type: String, quantity: int, _destination: String) -> void:
	_materials[material_type] = int(_materials.get(material_type, 0)) - quantity
	_refresh_label()
	_play_scale_pop()


## GDD Visual/Audio Requirements: numeric changes reuse Inventory's existing
## scale-pop treatment (~1.0->1.15->1.0 over ~0.2s).
func _play_scale_pop() -> void:
	if ReduceMotion.enabled():
		return
	# Pops the chips, not the title plaque; pivots on the left edge so the first chip
	# doesn't push back under the plaque.
	_materials_row.pivot_offset = Vector2(0.0, _materials_row.size.y / 2.0)
	_materials_row.scale = Vector2.ONE
	var tween: Tween = create_tween()
	tween.tween_property(_materials_row, "scale", Vector2(1.08, 1.08), 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_materials_row, "scale", Vector2.ONE, 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## Starts from what the player actually owns (2026-10-04 smoke check): the header
## used to begin empty on every Sanctuary load and only accumulate deltas, so a
## Lure showed "menagerie_lure -6" rather than the real remaining count. Inventory
## is the ledger of record (class doc comment); deltas still apply on top.
func _seed_from_inventory() -> void:
	_materials.clear()
	for i: int in range(GInventory.get_slot_count()):
		var contents: Dictionary = GInventory.get_slot_contents(i)
		if contents.is_empty() or contents.get("instance_id", -1) != -1:
			continue
		var item_id: String = String(contents.get("item_id", ""))
		var quantity: int = int(contents.get("quantity", 0))
		var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(item_id))
		if item_id.is_empty() or quantity <= 0 or definition == null or definition.item_type != &"Material":
			continue
		_materials[item_id] = int(_materials.get(item_id, 0)) + quantity


## Crafting consumes by type without emitting materials_spent, so also resync
## from the ledger whenever Inventory itself reports a change.
func _on_inventory_changed(_item_id: String, _item_type: String, _quantity: int) -> void:
	_seed_from_inventory()
	_refresh_label()


func _refresh_label() -> void:
	# free(), not queue_free(): chips are plain leaf Controls, never the signal emitter
	# being handled, and a detached-but-queued node lingers as an orphan until frame end.
	for child: Node in _materials_row.get_children():
		child.free()
	for material_type: String in _materials:
		_materials_row.add_child(_build_chip(material_type, int(_materials[material_type])))


## One material chip: inset frame, icon, count; the name lives in the tooltip. A
## material with no icon yet falls back to "Name N" text (content can lag code, the
## same tolerance as MissionHud's loot chips).
func _build_chip(material_type: String, quantity: int) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = StringName("Chip_%s" % material_type)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.focus_mode = Control.FOCUS_NONE
	chip.mouse_filter = Control.MOUSE_FILTER_PASS  # tooltip only; never focusable (Core Rule 3)
	chip.tooltip_text = _material_label(material_type)
	var box := ShellChromeStyle.skin_inset()
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	box.content_margin_right = 10
	chip.add_theme_stylebox_override("panel", box)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	chip.add_child(row)

	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(material_type))
	var count := Label.new()
	count.name = &"Count"
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
	if definition != null and definition.icon != null:
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = definition.icon
		icon.custom_minimum_size = Vector2(CHIP_ICON_SIZE, CHIP_ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
		count.text = str(quantity)
	else:
		count.text = "%s %d" % [_material_label(material_type), quantity]
	row.add_child(count)
	return chip


## Registry display name ("Menagerie Lure"); unknown ids are shown as-is.
static func _material_label(material_type: String) -> String:
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(material_type))
	return definition.display_name if definition != null and definition.display_name != "" else material_type
