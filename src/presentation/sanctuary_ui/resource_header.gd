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

@onready var _background: Panel = Panel.new()
@onready var _row: HBoxContainer = HBoxContainer.new()
@onready var _title_label: Label = Label.new()
@onready var _materials_label: Label = Label.new()


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
	_title_label.text = tr("SANCTUARY_HEADER_TITLE")
	_title_label.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_materials_label.name = &"MaterialsLabel"
	# 2026-10-07 (player-reported): inside the 320 px title plaque there was only
	# room for one material ("Goblin Hide 219 · ..."), the rest ellipsized away.
	# The plaque now carries just its title, and the readout sits in the empty
	# top strip to the plaque's right, sized to the window (see _layout_materials()).
	add_child(_materials_label)
	_materials_label.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
	_materials_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Pre-existing overflow, only exposed visually now that the Chrome
	# full-rect fix (sanctuary_ui.gd, 2026-08-04) lets this header actually
	# render at nonzero size: the untranslated placeholder key + material
	# list is long enough to autowrap to 2 lines and spill outside
	# HEADER_HEIGHT vertically. Single-line + ellipsis-trim + vertical
	# centering is a display-only fix (Story 004's own "read-only, no
	# authoritative data" scope) -- it doesn't touch the underlying text
	# content, which is a separate localization-catalogue gap every other
	# SANCTUARY_TAB_* key in this shell already has.
	_materials_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_materials_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_materials_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_materials_label.clip_contents = true
	_materials_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_materials_label.position = Vector2(size.x + MATERIALS_GAP, 0.0)
	_materials_label.size = Vector2(maxf(available, 0.0), size.y)


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
	_row.pivot_offset = _row.size / 2.0
	_row.scale = Vector2.ONE
	var tween: Tween = create_tween()
	tween.tween_property(_row, "scale", Vector2(1.15, 1.15), 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_row, "scale", Vector2.ONE, 0.1) \
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
	var parts: PackedStringArray = []
	for material_type: String in _materials:
		parts.append("%s %d" % [_material_label(material_type), _materials[material_type]])
	_materials_label.text = " · ".join(parts)


## Registry display name ("Menagerie Lure"); unknown ids are shown as-is.
static func _material_label(material_type: String) -> String:
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(material_type))
	return definition.display_name if definition != null and definition.display_name != "" else material_type
