extends Control

## Equipment Forge Screen (Sanctuary UI Story 005's Room Hosting scope, epic-10).
##
## GDD source: design/gdd/equipment-forge.md — UI Requirements section
## (persistent Craft/Imbue tab toggle; Craft reuses Crafting's own recipe-
## list panel; Imbue is a sequential item -> slot -> rune selection with a
## Menagerie-sacrifice-style two-step confirmation, since a consumed rune is
## non-fungible and unique).
## ADR: docs/architecture/adr-0011-ui-dual-focus-handling.md (focus/hover),
##      docs/architecture/adr-0025-equipment-forge-cross-system-aggregation.md
##      (data side — EquipmentForge is scene-instanced, not an Autoload; this
##      screen discovers the shell-owned instance via the "equipment_forge"
##      group, see equipment_forge.gd's own doc comment)
##
## Scope, honestly bounded:
## - "Reuses Crafting's own recipe-list panel wholesale" (GDD) is not
##   literally possible — no Crafting screen/panel exists anywhere in this
##   project yet (InventoryScreen's own Crafting-side panel is still an
##   explicit placeholder, per inventory_screen.gd's own doc comment). This
##   screen implements its own equivalent equipment-recipe list instead,
##   matching the same single-confirm convention Crafting's own GDD
##   specifies — not a placeholder, a real independent implementation of the
##   same interaction shape.
## - The GDD's 3-way Imbue selection (item -> rune SLOT -> rune) is
##   implemented as a 2-way selection (item -> rune): Inventory.
##   apply_rune_to_item() itself has no parameter for choosing a SPECIFIC
##   slot index — it fills the item's next free slot internally — so an
##   explicit slot-selection UI step would have nothing real to bind to.
##   This is not a shortcut around a real mechanic; the underlying system
##   genuinely has no per-slot targeting to select.
## - Center diorama (anvil/workbench staging visual) does not exist — no
##   diorama/equipment-sprite art exists anywhere in this project, matching
##   Sanctuary UI's own diorama gap (Story 013).
##
## Root is a plain Control. No class_name — matches the other room screens'
## TD-workflow-001 precedent.

const FOCUS_RING_COLOR: Color = Color(1.0, 0.85, 0.2, 1.0)  ## placeholder — art-director TBD

## Injectable for tests; defaults to the shell-owned instance discovered via
## the "equipment_forge" group (see equipment_forge.gd's own doc comment for
## why this can't be a direct Autoload reference).
@export var equipment_forge: EquipmentForge

@onready var _input_mode_tracker: InputModeTracker = $InputModeTracker
@onready var _tab_toggle_button: Button = $MainLayout/HeaderRow/TabToggleButton
@onready var _craft_view: Control = $MainLayout/CraftView
@onready var _recipe_list: VBoxContainer = $MainLayout/CraftView/RecipeList
@onready var _imbue_view: Control = $MainLayout/ImbueView
@onready var _item_list: VBoxContainer = $MainLayout/ImbueView/ItemColumn/ItemList
@onready var _rune_list: VBoxContainer = $MainLayout/ImbueView/RuneColumn/RuneList
@onready var _imbue_cancel_button: Button = $MainLayout/ImbueView/ItemColumn/CancelSelectionButton
@onready var _imbue_confirm_dialog: ConfirmationDialog = $ImbueConfirmDialog

var _recipe_buttons: Dictionary[StringName, Button] = {}
var _item_buttons: Dictionary[int, Button] = {}
var _rune_buttons: Dictionary[StringName, Button] = {}
var _showing_craft: bool = true
var _selected_instance_id: int = -1
var _pending_imbue_rune_id: StringName = &""


func _ready() -> void:
	if equipment_forge == null:
		equipment_forge = get_tree().get_first_node_in_group(&"equipment_forge") as EquipmentForge

	_tab_toggle_button.pressed.connect(_on_tab_toggle_pressed)
	_imbue_cancel_button.pressed.connect(_on_cancel_item_selection_pressed)
	_imbue_confirm_dialog.confirmed.connect(_on_imbue_confirmed)
	_input_mode_tracker.input_mode_changed.connect(_on_input_mode_changed)

	GEventBus.recipe_discovered.connect(_on_forge_state_changed)
	GEventBus.hero_equipment_crafted.connect(_on_forge_state_changed)
	GEventBus.item_rune_imbued.connect(_on_forge_state_changed)
	GEventBus.constellation_rune_discovered.connect(_on_forge_state_changed)
	GEventBus.tarot_rune_discovered.connect(_on_forge_state_changed)

	_rebuild_recipe_list()
	_rebuild_item_list()
	_rebuild_rune_list()
	_apply_view_visibility()


func disconnect_own_subscriptions() -> void:
	GEventBus.recipe_discovered.disconnect(_on_forge_state_changed)
	GEventBus.hero_equipment_crafted.disconnect(_on_forge_state_changed)
	GEventBus.item_rune_imbued.disconnect(_on_forge_state_changed)
	GEventBus.constellation_rune_discovered.disconnect(_on_forge_state_changed)
	GEventBus.tarot_rune_discovered.disconnect(_on_forge_state_changed)


func _on_forge_state_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_rebuild_recipe_list()
	_rebuild_item_list()
	_rebuild_rune_list()


# ---------------------------------------------------------------------------
# Craft / Imbue tab toggle (GDD: shoulder-button LB/RB convention on a real
# gamepad -- implemented as an explicit button, matching menagerie_screen.gd/
# defense_building_screen.gd's own precedent of buttons over exact gamepad-
# context fidelity)
# ---------------------------------------------------------------------------

func _on_tab_toggle_pressed() -> void:
	_showing_craft = not _showing_craft
	_apply_view_visibility()


func _apply_view_visibility() -> void:
	_craft_view.visible = _showing_craft
	_imbue_view.visible = not _showing_craft


func is_showing_craft() -> bool:
	return _showing_craft


# ---------------------------------------------------------------------------
# Craft tab — equipment recipe list (see class doc comment for why this is
# not literally Crafting's own reused panel)
# ---------------------------------------------------------------------------

func _rebuild_recipe_list() -> void:
	for child: Node in _recipe_list.get_children():
		child.queue_free()
	_recipe_buttons.clear()

	if equipment_forge == null:
		return
	var all_recipes: Dictionary[StringName, EquipmentRecipeResource] = GGameDataRegistry.get_all_equipment_recipes()
	var recipe_ids: Array = all_recipes.keys()
	recipe_ids.sort()

	for recipe_id: StringName in recipe_ids:
		if not equipment_forge.is_discovered(recipe_id):
			continue  # undiscovered recipes are not shown -- matches Crafting's own discovery-gated visibility
		var recipe: EquipmentRecipeResource = all_recipes[recipe_id]
		var button: Button = _create_recipe_button(recipe)
		_recipe_list.add_child(button)
		_recipe_buttons[recipe_id] = button


func _create_recipe_button(recipe: EquipmentRecipeResource) -> Button:
	var button := Button.new()
	button.name = "Recipe_%s" % String(recipe.recipe_id)
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = true
	button.text = _recipe_entry_text(recipe)
	button.pressed.connect(_on_recipe_pressed.bind(recipe.recipe_id))
	_wire_focus_ring(button)
	return button


func _recipe_entry_text(recipe: EquipmentRecipeResource) -> String:
	var craftable_tag: String = "CRAFTABLE" if equipment_forge.is_craftable(recipe.recipe_id) else "MISSING_MATERIALS"
	return "%s [%s]" % [String(recipe.recipe_id), craftable_tag]


## GDD: single-confirm, matching Crafting's own convention. resolve_craft()
## is itself already a safe no-op on an ineligible target.
func _on_recipe_pressed(recipe_id: StringName) -> void:
	equipment_forge.resolve_craft(recipe_id)


# ---------------------------------------------------------------------------
# Imbue tab — item selection (step 1 of 2, see class doc comment for the
# 3-way -> 2-way scoping note)
# ---------------------------------------------------------------------------

func _rebuild_item_list() -> void:
	for child: Node in _item_list.get_children():
		child.queue_free()
	_item_buttons.clear()

	for i: int in range(GInventory.get_slot_count()):
		var contents: Dictionary = GInventory.get_slot_contents(i)
		if contents.is_empty():
			continue
		var rune_slot_count: int = contents.get("rune_slot_count", 0) as int
		var imbued_runes: Array = contents.get("imbued_runes", [])
		if rune_slot_count <= 0 or imbued_runes.size() >= rune_slot_count:
			continue  # not an imbuable item, or no free slot remains
		var instance_id: int = contents["instance_id"] as int
		var button: Button = _create_item_button(instance_id, contents)
		_item_list.add_child(button)
		_item_buttons[instance_id] = button


func _create_item_button(instance_id: int, contents: Dictionary) -> Button:
	var button := Button.new()
	button.name = "Item_%d" % instance_id
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = true
	var rune_slot_count: int = contents.get("rune_slot_count", 0) as int
	var imbued_count: int = (contents.get("imbued_runes", []) as Array).size()
	button.text = "%s (%d/%d slots free)" % [contents["item_id"], rune_slot_count - imbued_count, rune_slot_count]
	button.pressed.connect(_on_item_pressed.bind(instance_id))
	_wire_focus_ring(button)
	return button


func _on_item_pressed(instance_id: int) -> void:
	_selected_instance_id = instance_id
	_imbue_cancel_button.visible = true


func _on_cancel_item_selection_pressed() -> void:
	_selected_instance_id = -1
	_imbue_cancel_button.visible = false


func get_selected_instance_id() -> int:
	return _selected_instance_id


# ---------------------------------------------------------------------------
# Imbue tab — rune pool (step 2 of 2) + two-step confirmation
# ---------------------------------------------------------------------------

func _rebuild_rune_list() -> void:
	for child: Node in _rune_list.get_children():
		child.queue_free()
	_rune_buttons.clear()

	if equipment_forge == null:
		return
	var all_runes: Dictionary[StringName, Dictionary] = equipment_forge.get_all_available_runes()
	var rune_ids: Array = all_runes.keys()
	rune_ids.sort()

	for rune_id: StringName in rune_ids:
		var entry: Dictionary = all_runes[rune_id]
		if not (entry.get("is_known", true) as bool):
			continue  # orphaned rune -- retained but unselectable (Story 015 AC-25)
		var button: Button = _create_rune_button(rune_id, entry)
		_rune_list.add_child(button)
		_rune_buttons[rune_id] = button


func _create_rune_button(rune_id: StringName, entry: Dictionary) -> Button:
	var button := Button.new()
	button.name = "Rune_%s" % String(rune_id)
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = true
	button.text = "%s (source: %s)" % [String(rune_id), entry.get("rune_source", "")]
	button.pressed.connect(_on_rune_pressed.bind(rune_id))
	_wire_focus_ring(button)
	return button


## GDD: selecting a rune (step 3 of the original 3-way flow, step 2 here)
## opens the two-step confirmation modal -- never imbues directly on this
## press. Requires an item already selected (step 1); a rune press with no
## item selected is a no-op, matching the project's "confirm on non-
## actionable target" pattern rather than a silent crash.
func _on_rune_pressed(rune_id: StringName) -> void:
	if _selected_instance_id == -1:
		return
	_pending_imbue_rune_id = rune_id
	_imbue_confirm_dialog.dialog_text = tr("EQUIPFORGE_IMBUE_CONFIRM_TEXT")
	_imbue_confirm_dialog.popup_centered()


func _on_imbue_confirmed() -> void:
	if _selected_instance_id == -1 or _pending_imbue_rune_id == &"":
		return
	equipment_forge.resolve_imbue(_selected_instance_id, _pending_imbue_rune_id)
	_pending_imbue_rune_id = &""
	_selected_instance_id = -1
	_imbue_cancel_button.visible = false


# ---------------------------------------------------------------------------
# Focus ring (ADR-0011, matches the other room screens)
# ---------------------------------------------------------------------------

func _wire_focus_ring(button: Button) -> void:
	var focus_ring := Panel.new()
	focus_ring.name = "FocusRing"
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	ring_style.border_width_left = 2
	ring_style.border_width_right = 2
	ring_style.border_width_top = 2
	ring_style.border_width_bottom = 2
	ring_style.border_color = FOCUS_RING_COLOR
	focus_ring.add_theme_stylebox_override("panel", ring_style)
	focus_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_ring.visible = false
	focus_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(focus_ring)
	button.focus_entered.connect(_on_button_focus_changed.bind(button, focus_ring))
	button.focus_exited.connect(_on_button_focus_changed.bind(button, focus_ring))


func _on_button_focus_changed(button: Button, ring: Panel) -> void:
	ring.visible = button.has_focus() and _input_mode_tracker.is_focus_ring_visible()


func _on_input_mode_changed(_mode: InputModeTracker.InputMode) -> void:
	for buttons: Dictionary in [_recipe_buttons, _item_buttons, _rune_buttons]:
		for key: Variant in buttons.keys():
			var button: Button = buttons[key]
			var ring: Panel = button.get_node_or_null("FocusRing") as Panel
			if ring != null:
				ring.visible = button.has_focus() and _input_mode_tracker.is_focus_ring_visible()


# ---------------------------------------------------------------------------
# Test/inspection accessors
# ---------------------------------------------------------------------------

func get_recipe_button(recipe_id: StringName) -> Button:
	return _recipe_buttons.get(recipe_id)


func get_item_button(instance_id: int) -> Button:
	return _item_buttons.get(instance_id)


func get_rune_button(rune_id: StringName) -> Button:
	return _rune_buttons.get(rune_id)
