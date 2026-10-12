extends Control

## No class_name declared -- matches grid_visual.gd's/pause_menu.gd's own
## established TD-workflow-001 precedent (a real, documented Godot 4.6.2
## class-cache fragility: a fresh class_name is not picked up by a purely
## headless MCP run until an editor-mode filesystem scan rebuilds
## .godot/global_script_class_cache.cfg -- see docs/engine-reference/godot/
## VERSION.md's "Global class_name resolution" row). This script is only
## ever instanced once, as InventoryScreen.tscn's own dedicated child node,
## so a class_name buys nothing here and risks exactly that fragility.
##
## Hero-centered equipment paperdoll (player-requested 2026-08-16) --
## design/gdd/equipment-forge.md's 10 named Hero equipment slots rendered
## as slot-icon frames flanking a full-body hero portrait, instead of the
## existing flat item grid's generic square buttons. Player explicitly
## asked to copy the LAYOUT STYLE of 3 reference screenshots they provided
## -- not to use those images. This project's own established Chrome/
## Parchment palette (shell_chrome_style.gd) is used for the frame styling
## instead of the references' own dark-fantasy gold skin.
##
## Exact slot arrangement is player-specified (2026-08-16 follow-up),
## matching the reference screenshots precisely: left column top-to-bottom
## is Helmet/Chest/Gloves/Pants/Boots, with Main Hand at the bottom of that
## same column; right column top-to-bottom is Neck/Ring 1/Ring 2, with
## Offhand at the bottom of that column. This required expanding Hero's
## equip-slot model itself from 5 to 10 real named slots (Inventory.
## EQUIPMENT_SLOT_NAMES) -- see that constant's own doc comment for the
## full data-model change (STARTING_SLOT_COUNT, SlotExpansionCostTable,
## Equipment/Sacrifice recipe categories, all updated to match).
##
## Player decision (2026-08-16, AskUserQuestion): paperdoll sits ALONGSIDE
## the existing filtered SlotGrid on the Equipment tab, not in place of it
## -- inventory_screen.gd's own tab-filter logic and its test coverage
## (tests/integration/inventory-screen/category-tab-filtering_test.gd) are
## untouched by this file. Some duplication is an accepted tradeoff: the 10
## equip slots still also appear as plain buttons in the flat grid below
## (they are real, always-present, pre-locked InventorySlot entries in the
## same shared pool per inventory.md Rule 5) -- this component is purely an
## additional, friendlier visualization of the exact same underlying state.
##
## Originally read-only (no click-to-unequip) for the data-safety reason below;
## 2026-10-07: double-click now REQUESTS an unequip via slot_unequip_requested,
## and the screen performs it with Inventory.unequip_to_bag(), an intact move
## that keeps stat_overrides/runes (unequip_item() is still never called). Inventory.unequip_
## item() wipes InventorySlot.stat_overrides as part of clearing the slot
## (inventory.gd line ~305) and returns bool, not the cleared state, before
## the caller gets any chance to preserve it -- there is no established,
## data-safe "unequip and return the item to a normal slot" pattern
## anywhere in this codebase yet (grepped: unequip_item() has zero UI call
## sites today). Wiring a click handler straight to it here would silently
## destroy a player's rolled item on click. Both un-equip and equip-from-
## grid interactions are a separate, larger feature the player did not ask
## for in this pass -- this component only shows what's equipped.

const HERO_PORTRAIT: Texture2D = preload("res://assets/art/characters/hero_warden_smith.png")
const SLOT_SIZE: Vector2 = Vector2(44, 44)  ## smaller than the old 48px tile -- 6 slots must fit one column's height
const FALLBACK_LABEL_FONT_SIZE: int = 10  ## fits "Main Hand"/"Offhand" inside SLOT_SIZE (see _build_slot_frame)
const PORTRAIT_SIZE: Vector2 = Vector2(160, 320)

## Left column top-to-bottom, right column top-to-bottom -- player-specified
## exact arrangement (2026-08-16 follow-up). Mirrors Inventory.EQUIPMENT_
## SLOT_NAMES' own 10 names exactly; never hardcodes a name not present there.
##
## Row-aligned (2026-08-21, player-requested): right column carries two ""
## spacer rows in place of Pants/Boots so its 6 rows share the exact same
## row grid as the left column -- Neck/Ring 1/Ring 2 land on Helmet/Chest/
## Gloves' rows, and Offhand lands on Main Hand's row. _build_column() below
## renders "" as an invisible, un-tracked spacer instead of a slot frame.
const LEFT_COLUMN_SLOTS: Array[String] = ["helmet", "chest", "gloves", "pants", "boots", "main_hand"]
const RIGHT_COLUMN_SLOTS: Array[String] = ["neck", "ring_1", "ring_2", "", "", "offhand"]

## Human-readable placeholder text for an empty slot -- shown until the slot
## has a real occupant with a display_name (or, for slots with no icon
## authored yet, permanently as the icon fallback). No slot-category icon
## art exists yet (Phase 3, same "content can lag code" tolerance this
## project's other slot/tile UIs already document) -- text is the honest
## placeholder, not a guessed-at icon.
## Values are strings.csv keys (2026-10-11 localization pass).
const SLOT_LABEL: Dictionary[String, String] = {
	"helmet": "EQUIP_SLOT_HELMET", "chest": "EQUIP_SLOT_CHEST", "gloves": "EQUIP_SLOT_GLOVES",
	"pants": "EQUIP_SLOT_PANTS", "boots": "EQUIP_SLOT_BOOTS", "main_hand": "EQUIP_SLOT_MAIN_HAND",
	"neck": "EQUIP_SLOT_NECK", "ring_1": "EQUIP_SLOT_RING_1", "ring_2": "EQUIP_SLOT_RING_2",
	"offhand": "EQUIP_SLOT_OFFHAND",
}

## Hover only: the frames are non-focusable Panels (existing design). Gamepad/
## keyboard reach the same equipped items through inventory_screen.gd's slot
## grid, whose focus events drive the same info panel.
signal slot_info_requested(slot_name: String)
signal slot_info_cleared()
## Double-click on an equipped frame (2026-10-07). The paperdoll stays
## data-read-only: the owning screen performs the intact move
## (Inventory.unequip_to_bag), never this component.
signal slot_unequip_requested(slot_name: String)

var _slot_frames: Dictionary[String, Panel] = {}
var _slot_icons: Dictionary[String, TextureRect] = {}
var _slot_labels: Dictionary[String, Label] = {}


func _ready() -> void:
	custom_minimum_size = Vector2(320, 400)
	_build_background()
	_build_portrait()
	_build_column(LEFT_COLUMN_SLOTS, true)
	_build_column(RIGHT_COLUMN_SLOTS, false)
	refresh_all()
	GEventBus.equipment_slot_changed.connect(_on_equipment_slot_changed)


func _exit_tree() -> void:
	if GEventBus.equipment_slot_changed.is_connected(_on_equipment_slot_changed):
		GEventBus.equipment_slot_changed.disconnect(_on_equipment_slot_changed)


func _build_background() -> void:
	var panel := Panel.new()
	panel.name = "Background"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", ShellChromeStyle.skin_panel())
	add_child(panel)
	move_child(panel, 0)


## Portrait is placed on top of the same UI_CHROME background color the
## panel uses -- hero_warden_smith.png's own corners are flat black
## (assets/source/ has no alpha-cut pass for this file yet), and UI_CHROME
## (#252D3D, near-black navy) reads close enough to blend the seam rather
## than showing an obvious black rectangle. A real alpha-cut pass (this
## project's established assets/source -> assets/art technique, see CLAUDE.
## md's Asset Generation section) would remove the need for this entirely --
## flagged as a follow-up, not attempted here since this story is layout,
## not art processing.
func _build_portrait() -> void:
	var portrait := TextureRect.new()
	portrait.name = "HeroPortrait"
	portrait.texture = HERO_PORTRAIT
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.set_anchors_preset(Control.PRESET_CENTER_TOP)
	portrait.position = Vector2(-PORTRAIT_SIZE.x / 2.0, 24.0)
	portrait.size = PORTRAIT_SIZE
	add_child(portrait)
	# Worn gear drawn on the hero (2026-10-07); also swaps in the base body.
	var appearance := HeroAppearance.new()
	appearance.name = "HeroAppearance"
	portrait.add_child(appearance)


const COLUMN_SEPARATION: float = 8.0


func _build_column(slot_names: Array[String], is_left: bool) -> void:
	var column := VBoxContainer.new()
	column.name = "LeftColumn" if is_left else "RightColumn"
	column.add_theme_constant_override("separation", int(COLUMN_SEPARATION))
	column.set_anchors_preset(Control.PRESET_CENTER_LEFT if is_left else Control.PRESET_CENTER_RIGHT)
	var x_offset: float = 12.0 if is_left else -12.0 - SLOT_SIZE.x
	# Row-aligned (2026-08-21): always centers against LEFT_COLUMN_SLOTS' row
	# count, never slot_names.size() -- both columns now carry the same
	# number of rows (real slots + "" spacers), so sharing one height/center
	# reference is what actually keeps their rows aligned. Computing each
	# column's own height independently (the pre-2026-08-21 approach) is
	# exactly what caused the two columns to center on different points.
	var row_count: int = LEFT_COLUMN_SLOTS.size()
	var column_height: float = float(row_count) * SLOT_SIZE.y + float(row_count - 1) * COLUMN_SEPARATION
	column.position = Vector2(x_offset, -column_height / 2.0)
	add_child(column)
	for slot_name: String in slot_names:
		if slot_name == "":
			column.add_child(_build_spacer(SLOT_SIZE))
		else:
			column.add_child(_build_slot_frame(slot_name, SLOT_SIZE))


## Invisible row-height placeholder -- occupies exactly one row in the
## shared VBoxContainer grid without rendering a frame or being tracked in
## _slot_frames/_slot_icons/_slot_labels (it has no slot_name, nothing ever
## refreshes it). See RIGHT_COLUMN_SLOTS' own doc comment for why this exists.
func _build_spacer(tile_size: Vector2) -> Control:
	var spacer := Control.new()
	spacer.name = "RowSpacer"
	spacer.custom_minimum_size = tile_size
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


## Panel, not Button -- this slot frame is read-only (see class doc comment
## on why click-to-unequip isn't wired up), so it deliberately carries no
## clickable affordance. Control.tooltip_text works on any Control, Panel
## included -- no functionality lost by not using Button here.
func _build_slot_frame(slot_name: String, tile_size: Vector2) -> Panel:
	var frame := Panel.new()
	frame.name = "Slot_%s" % slot_name
	frame.custom_minimum_size = tile_size
	# NOT chrome_panel_stylebox() as-is -- its bg_color is identical to the
	# paperdoll's own background panel, so a slot frame would be invisible
	# except for its text/icon (found live via the Godot MCP bridge). A
	# lighter fill + chrome_button_stylebox()'s established outlined-Parchment-
	# border convention (shell_chrome_style.gd) makes each slot read as its
	# own discrete bordered box, matching the reference layout's framed-slot
	# look with this project's own palette instead of copying their skin.
	var slot_style := StyleBoxFlat.new()
	slot_style.bg_color = Color(ShellChromeStyle.UI_CHROME, 1.0).lightened(0.15)
	slot_style.border_width_left = 2
	slot_style.border_width_right = 2
	slot_style.border_width_top = 2
	slot_style.border_width_bottom = 2
	slot_style.border_color = ShellChromeStyle.UI_PARCHMENT
	slot_style.set_corner_radius_all(ShellChromeStyle.CHAMFER_PX)
	frame.add_theme_stylebox_override("panel", slot_style)
	frame.mouse_filter = Control.MOUSE_FILTER_PASS  ## lets tooltip_text register on hover
	frame.mouse_entered.connect(_on_frame_mouse_entered.bind(slot_name))
	frame.gui_input.connect(_on_frame_gui_input.bind(slot_name))
	frame.mouse_exited.connect(_on_frame_mouse_exited)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 6)
	icon.visible = false
	frame.add_child(icon)
	_slot_icons[slot_name] = icon

	# Fallback label for the icon-not-authored-yet / empty-slot-name case
	# (inventory_screen.gd's established icon-with-text-fallback convention).
	var fallback_label := Label.new()
	fallback_label.name = "FallbackLabel"
	fallback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# The default ~16px theme font overflowed the 44px tile ("Main Hand",
	# "Offhand", "Ring 1" spilled past the frame -- 2026-10-04 smoke check).
	# 10px fits every slot name in at most two lines; clip_text guards long
	# item display_names that also land in this label.
	fallback_label.add_theme_font_size_override("font_size", FALLBACK_LABEL_FONT_SIZE)
	fallback_label.clip_text = true
	fallback_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 2)
	frame.add_child(fallback_label)
	_slot_labels[slot_name] = fallback_label

	_slot_frames[slot_name] = frame
	return frame


## Public: called once at mount (also self-invoked in _ready()) and
## reachable from tests/other screens that need to force a resync without
## waiting for an equipment_slot_changed event -- mirrors inventory_screen.
## gd's own _refresh_all_slot_visuals() precedent.
func refresh_all() -> void:
	for slot_name: String in _slot_frames:
		_refresh_slot(slot_name)


func _on_equipment_slot_changed(slot: String, _new_item_id: String, _previous_item_id: String) -> void:
	if _slot_frames.has(slot):
		_refresh_slot(slot)


func _on_frame_mouse_entered(slot_name: String) -> void:
	slot_info_requested.emit(slot_name)


func _on_frame_mouse_exited() -> void:
	slot_info_cleared.emit()


func _refresh_slot(slot_name: String) -> void:
	var frame: Panel = _slot_frames[slot_name]
	var icon: TextureRect = _slot_icons[slot_name]
	var fallback_label: Label = _slot_labels[slot_name]
	var contents: Dictionary = GInventory.get_equipped_item(slot_name)
	var item_id: String = contents.get("item_id", "") as String

	if item_id == "":
		icon.visible = false
		fallback_label.visible = true
		var slot_label: String = tr(SLOT_LABEL[slot_name]) if SLOT_LABEL.has(slot_name) else slot_name.capitalize()
		fallback_label.text = slot_label
		frame.tooltip_text = slot_label
		return

	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(item_id))
	if definition != null and definition.icon != null:
		icon.texture = definition.icon
		icon.visible = true
		fallback_label.visible = false
	else:
		# No icon authored yet -- same icon-with-text-fallback convention
		# inventory_screen.gd's _apply_slot_visual() already established.
		fallback_label.text = definition.display_name if definition != null else item_id
		fallback_label.visible = true
		icon.visible = false

	frame.tooltip_text = definition.display_name if definition != null else item_id


func _on_frame_gui_input(event: InputEvent, slot_name: String) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.double_click and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		slot_unequip_requested.emit(slot_name)
