extends Control

## Forge Screen (Sanctuary UI Story 005's Room Hosting scope, epic-10;
## restructured 2026-08-12, Building Upgrade Story 003, into a 3-tab Forge:
## Craft / Imbue / Upgrade Buildings).
##
## GDD source: design/gdd/equipment-forge.md — UI Requirements section
## (Craft/Imbue tab toggle; Craft reuses Crafting's own recipe-list panel;
## Imbue is a sequential item -> slot -> rune selection with a
## Menagerie-sacrifice-style two-step confirmation, since a consumed rune is
## non-fungible and unique) plus design/gdd/building-upgrade.md (Upgrade tab,
## Rule 2a's per-requirement legibility).
## ADR: docs/architecture/adr-0011-ui-dual-focus-handling.md (focus/hover),
##      docs/architecture/adr-0025-equipment-forge-cross-system-aggregation.md
##      (data side — EquipmentForge is scene-instanced, not an Autoload; this
##      screen discovers the shell-owned instance via the "equipment_forge"
##      group, see equipment_forge.gd's own doc comment). BuildingUpgrade is
##      discovered the identical way, via its own "building_upgrade" group —
##      same shell-instancing reason (RoomHost's generic mount mechanism has
##      no room-specific injection seam).
##
## Tower Assembly 4th tab (design/quick-specs/tower-assembly-2026-08-11.md,
## player-requested 2026-08-14): a prior pass drafted this tab, then reverted
## it as out of scope for this screen's GDD/Story 003 (see git history) —
## re-added on direct player request. Discovers TowerAssembly the same way
## as EquipmentForge/BuildingUpgrade, via the "tower_assembly" group.
## 4-column slot pickers (Foundation/Weapon/Focus/Power); an owned
## TowerComponent item is classified into its column by loading its
## component_resource_path and checking its resolved Resource's runtime
## type (FoundationComponent/WeaponComponent/FocusComponent/PowerComponent)
## — not by trusting a naming convention, matching TowerAssembly.
## assemble_tower()'s own cross-check discipline.
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

const TAB_CRAFT: int = 0
const TAB_IMBUE: int = 1
const TAB_ASSEMBLE: int = 2
const TAB_UPGRADE: int = 3

## Slot key -> component script's global class_name, used to classify an
## owned TowerComponent item into its assembly column purely from its
## resolved Resource's runtime type.
const SLOT_KEYS: Array[String] = ["foundation", "weapon", "focus", "power"]

## Non-color-safe, distinct-shape textual tags per requirement category
## (Rule 2a/AC-6b) — this project has no authored icon set for these 4
## categories yet, so a bracketed text tag (matching this screen's own
## existing "[CRAFTABLE]"/"[MISSING_MATERIALS]" tag convention) is used
## instead of a graphical icon. Revisit once real icon assets exist.
const REQUIREMENT_CATEGORY_TAGS: Dictionary[String, String] = {
	"building": "[Bldg]",
	"equipment": "[Equip]",
	"tarot": "[Tarot]",
	"creature": "[Creature]",
}

## Injectable for tests; defaults to the shell-owned instances discovered via
## the "equipment_forge"/"building_upgrade"/"tower_assembly" groups (see each
## system's own doc comment for why these can't be direct Autoload references).
@export var equipment_forge: EquipmentForge
@export var building_upgrade: BuildingUpgrade
@export var tower_assembly: TowerAssembly

@onready var _input_mode_tracker: InputModeTracker = $InputModeTracker
@onready var _craft_tab_button: Button = $MainLayout/HeaderRow/CraftTabButton
@onready var _imbue_tab_button: Button = $MainLayout/HeaderRow/ImbueTabButton
@onready var _assemble_tab_button: Button = $MainLayout/HeaderRow/AssembleTabButton
@onready var _upgrade_tab_button: Button = $MainLayout/HeaderRow/UpgradeTabButton
@onready var _craft_view: Control = $MainLayout/CraftView
@onready var _recipe_list: VBoxContainer = $MainLayout/CraftView/RecipeList
@onready var _imbue_view: Control = $MainLayout/ImbueView
@onready var _item_list: VBoxContainer = $MainLayout/ImbueView/ItemColumn/ItemList
@onready var _rune_list: VBoxContainer = $MainLayout/ImbueView/RuneColumn/RuneList
@onready var _imbue_cancel_button: Button = $MainLayout/ImbueView/ItemColumn/CancelSelectionButton
@onready var _imbue_confirm_dialog: ConfirmationDialog = $ImbueConfirmDialog
@onready var _upgrade_view: Control = $MainLayout/UpgradeView
@onready var _upgrade_list: VBoxContainer = $MainLayout/UpgradeView/UpgradeList
@onready var _upgrade_confirm_dialog: ConfirmationDialog = $UpgradeConfirmDialog
@onready var _assemble_view: Control = $MainLayout/AssembleView
@onready var _assemble_slot_lists: Dictionary[String, VBoxContainer] = {
	"foundation": $MainLayout/AssembleView/SlotColumns/FoundationColumn/FoundationList,
	"weapon": $MainLayout/AssembleView/SlotColumns/WeaponColumn/WeaponList,
	"focus": $MainLayout/AssembleView/SlotColumns/FocusColumn/FocusList,
	"power": $MainLayout/AssembleView/SlotColumns/PowerColumn/PowerList,
}
@onready var _assembled_list: VBoxContainer = $MainLayout/AssembleView/SlotColumns/AssembledColumn/AssembledList
@onready var _assemble_name_edit: LineEdit = $MainLayout/AssembleView/AssembleFooter/AssembleNameEdit
@onready var _assemble_button: Button = $MainLayout/AssembleView/AssembleFooter/AssembleButton
@onready var _assemble_confirm_dialog: ConfirmationDialog = $AssembleConfirmDialog

var _recipe_buttons: Dictionary[StringName, Button] = {}
var _item_buttons: Dictionary[int, Button] = {}
var _rune_buttons: Dictionary[StringName, Button] = {}
var _upgrade_buttons: Dictionary[StringName, Button] = {}      ## upgrade_id -> the row's purchase Button
var _upgrade_chip_rows: Dictionary[StringName, Control] = {}   ## upgrade_id -> its per-requirement chip HBoxContainer
var _assemble_component_buttons: Dictionary[String, Dictionary] = {}  ## slot -> {instance_id: Button}

var _active_tab: int = TAB_CRAFT
var _selected_instance_id: int = -1
var _pending_imbue_rune_id: StringName = &""
var _pending_upgrade_id: StringName = &""
## slot ("foundation"/"weapon"/"focus"/"power") -> selected instance_id, or
## -1 if that slot has no selection yet. Reset on every successful assembly
## and on tab-away-and-back is deliberately NOT done -- a player switching
## tabs mid-selection (e.g. to check Craft) should not lose their picks.
var _assemble_selection: Dictionary[String, int] = {"foundation": -1, "weapon": -1, "focus": -1, "power": -1}


func _ready() -> void:
	if equipment_forge == null:
		equipment_forge = get_tree().get_first_node_in_group(&"equipment_forge") as EquipmentForge
	if building_upgrade == null:
		building_upgrade = get_tree().get_first_node_in_group(&"building_upgrade") as BuildingUpgrade
	if tower_assembly == null:
		tower_assembly = get_tree().get_first_node_in_group(&"tower_assembly") as TowerAssembly

	_craft_tab_button.pressed.connect(_on_tab_button_pressed.bind(TAB_CRAFT))
	_imbue_tab_button.pressed.connect(_on_tab_button_pressed.bind(TAB_IMBUE))
	_assemble_tab_button.pressed.connect(_on_tab_button_pressed.bind(TAB_ASSEMBLE))
	_upgrade_tab_button.pressed.connect(_on_tab_button_pressed.bind(TAB_UPGRADE))
	_imbue_cancel_button.pressed.connect(_on_cancel_item_selection_pressed)
	_imbue_confirm_dialog.confirmed.connect(_on_imbue_confirmed)
	_upgrade_confirm_dialog.confirmed.connect(_on_upgrade_confirmed)
	_assemble_button.pressed.connect(_on_assemble_button_pressed)
	_assemble_confirm_dialog.confirmed.connect(_on_assemble_confirmed)
	_input_mode_tracker.input_mode_changed.connect(_on_input_mode_changed)

	GEventBus.recipe_discovered.connect(_on_forge_state_changed)
	GEventBus.hero_equipment_crafted.connect(_on_forge_state_changed)
	GEventBus.item_rune_imbued.connect(_on_forge_state_changed)
	GEventBus.constellation_rune_discovered.connect(_on_forge_state_changed)
	GEventBus.tarot_rune_discovered.connect(_on_forge_state_changed)
	GEventBus.structure_upgraded.connect(_on_forge_state_changed)
	GEventBus.item_added.connect(_on_forge_state_changed)
	GEventBus.item_removed.connect(_on_forge_state_changed)
	GEventBus.tower_assembled.connect(_on_forge_state_changed)

	_rebuild_recipe_list()
	_rebuild_item_list()
	_rebuild_rune_list()
	_rebuild_upgrade_list()
	_rebuild_assemble_lists()
	_apply_view_visibility()


func disconnect_own_subscriptions() -> void:
	GEventBus.recipe_discovered.disconnect(_on_forge_state_changed)
	GEventBus.hero_equipment_crafted.disconnect(_on_forge_state_changed)
	GEventBus.item_rune_imbued.disconnect(_on_forge_state_changed)
	GEventBus.constellation_rune_discovered.disconnect(_on_forge_state_changed)
	GEventBus.tarot_rune_discovered.disconnect(_on_forge_state_changed)
	GEventBus.structure_upgraded.disconnect(_on_forge_state_changed)
	GEventBus.item_added.disconnect(_on_forge_state_changed)
	GEventBus.item_removed.disconnect(_on_forge_state_changed)
	GEventBus.tower_assembled.disconnect(_on_forge_state_changed)


func _on_forge_state_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_rebuild_recipe_list()
	_rebuild_item_list()
	_rebuild_rune_list()
	_rebuild_upgrade_list()
	_rebuild_assemble_lists()


# ---------------------------------------------------------------------------
# 3-way tab strip (Craft / Imbue / Upgrade Buildings)
# ---------------------------------------------------------------------------

func _on_tab_button_pressed(tab: int) -> void:
	_active_tab = tab
	_apply_view_visibility()


func _apply_view_visibility() -> void:
	_craft_view.visible = _active_tab == TAB_CRAFT
	_imbue_view.visible = _active_tab == TAB_IMBUE
	_assemble_view.visible = _active_tab == TAB_ASSEMBLE
	_upgrade_view.visible = _active_tab == TAB_UPGRADE


func get_active_tab() -> int:
	return _active_tab


## Back-compat accessor — Craft was tab 0 both before and after this
## restructure, so this still reads correctly for any existing caller.
func is_showing_craft() -> bool:
	return _active_tab == TAB_CRAFT


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
# Upgrade Buildings tab — Defense Building structures gated on a
# recipe-style combination of building/equipment/tarot/creature requirements.
# See design/gdd/building-upgrade.md Rule 2/2a/6a.
# ---------------------------------------------------------------------------

func _rebuild_upgrade_list() -> void:
	for child: Node in _upgrade_list.get_children():
		child.queue_free()
	_upgrade_buttons.clear()
	_upgrade_chip_rows.clear()

	if building_upgrade == null:
		return
	var all_upgrades: Dictionary[StringName, BuildingUpgradeResource] = GGameDataRegistry.get_all_building_upgrades()
	var upgrade_ids: Array = all_upgrades.keys()
	upgrade_ids.sort()

	for upgrade_id: StringName in upgrade_ids:
		if not building_upgrade.is_visible(upgrade_id):
			continue  # target structure not yet built -- Rule 3
		var upgrade: BuildingUpgradeResource = all_upgrades[upgrade_id]
		var row: VBoxContainer = _create_upgrade_row(upgrade)
		_upgrade_list.add_child(row)


## Rule 2a/AC-6/AC-6b: each upgrade renders as a header purchase Button
## (unchanged single-confirm interaction) plus one chip row beneath it with
## an independent Label per requirements entry -- category tag, resolved
## display name, and satisfied/unmet state, never a single collapsed
## pass/fail flag for the whole upgrade (the previous READY/
## REQUIREMENTS_UNMET binary tag this replaces).
func _create_upgrade_row(upgrade: BuildingUpgradeResource) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.name = "UpgradeRow_%s" % String(upgrade.upgrade_id)

	var header := Button.new()
	header.name = "Header"
	header.focus_mode = Control.FOCUS_ALL
	header.clip_text = true
	header.text = _upgrade_header_text(upgrade)
	header.disabled = building_upgrade.is_purchased(upgrade.upgrade_id)
	header.pressed.connect(_on_upgrade_pressed.bind(upgrade.upgrade_id))
	_wire_focus_ring(header)
	row.add_child(header)
	_upgrade_buttons[upgrade.upgrade_id] = header

	var chip_row := HBoxContainer.new()
	chip_row.name = "RequirementChips"
	var status: Dictionary[String, bool] = building_upgrade.get_requirement_status(upgrade.upgrade_id)
	for category: String in upgrade.requirements:
		var identifier: StringName = upgrade.requirements[category]
		var satisfied: bool = status.get(category, false)
		var chip := Label.new()
		chip.name = "Chip_%s" % category
		chip.text = _requirement_chip_text(category, identifier, satisfied)
		chip_row.add_child(chip)
	row.add_child(chip_row)
	_upgrade_chip_rows[upgrade.upgrade_id] = chip_row

	return row


func _upgrade_header_text(upgrade: BuildingUpgradeResource) -> String:
	if building_upgrade.is_purchased(upgrade.upgrade_id):
		return "%s [PURCHASED]" % String(upgrade.upgrade_id)
	var tag: String = "PURCHASABLE" if building_upgrade.can_purchase(upgrade.upgrade_id) else "VISIBLE_LOCKED"
	return "%s [%s]" % [String(upgrade.upgrade_id), tag]


## AC-6: satisfied (checkmark) vs unmet (cross), non-color-safe by symbol
## alone. AC-6b: REQUIREMENT_CATEGORY_TAGS gives each category its own
## distinct bracketed text tag (no icon assets exist for these 4 categories
## yet -- see the const's own doc comment), so a colorblind player can tell
## categories apart without relying on color.
func _requirement_chip_text(category: String, identifier: StringName, satisfied: bool) -> String:
	var state_glyph: String = "✓" if satisfied else "✗"  # checkmark / cross
	var category_tag: String = REQUIREMENT_CATEGORY_TAGS.get(category, "[%s]" % category)
	return "%s %s %s" % [state_glyph, category_tag, _resolve_requirement_display_name(category, identifier)]


## AC-6: resolves the specific target's player-facing name, never a raw
## StringName id. Only ItemDefinitionResource ("equipment") has a real
## display_name field in this project today -- StructureResource,
## SpeciesResource, and TarotCardResource carry no display-name field at
## all (confirmed by reading each Resource script directly, not assumed).
## Adding one to any of those 3 is a data-model change outside this UI
## story's own scope, so a title-cased id is used as an honest fallback for
## those categories -- still player-facing text, not the flat internal id,
## but not a genuinely authored name either. Flagged here, not silently
## passed off as equivalent to the equipment case.
func _resolve_requirement_display_name(category: String, identifier: StringName) -> String:
	match category:
		"building":
			return _title_case(String(identifier))
		"equipment":
			var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(identifier)
			return definition.display_name if definition != null else _title_case(String(identifier))
		"tarot":
			return _title_case(String(identifier))
		"creature":
			return _title_case(String(identifier))
		_:
			return String(identifier)


func _title_case(raw_id: String) -> String:
	var words: PackedStringArray = raw_id.replace("_", " ").split(" ", false)
	var titled: PackedStringArray = []
	for word: String in words:
		titled.append(word.capitalize())
	return " ".join(titled)


func _on_upgrade_pressed(upgrade_id: StringName) -> void:
	if not building_upgrade.can_purchase(upgrade_id):
		return
	_pending_upgrade_id = upgrade_id
	_upgrade_confirm_dialog.dialog_text = tr("FORGE_UPGRADE_CONFIRM_TEXT")
	_upgrade_confirm_dialog.popup_centered()


func _on_upgrade_confirmed() -> void:
	if _pending_upgrade_id == &"":
		return
	building_upgrade.resolve_upgrade(_pending_upgrade_id)
	_pending_upgrade_id = &""


func get_upgrade_button(upgrade_id: StringName) -> Button:
	return _upgrade_buttons.get(upgrade_id)


## Test/inspection accessor (Story 003, AC-6/AC-6b) -- the HBoxContainer
## holding one Label chip per requirements entry for this upgrade, or null
## if the upgrade isn't currently listed (e.g. HIDDEN, Rule 3).
func get_upgrade_chip_row(upgrade_id: StringName) -> Control:
	return _upgrade_chip_rows.get(upgrade_id)


# ---------------------------------------------------------------------------
# Assemble Towers tab — combines 4 owned crafted tower components into a new
# placeable TowerBlueprintData. See design/quick-specs/tower-assembly-
# 2026-08-11.md and TowerAssembly.assemble_tower()'s own doc comment.
# ---------------------------------------------------------------------------

func _rebuild_assemble_lists() -> void:
	for slot: String in SLOT_KEYS:
		var list: VBoxContainer = _assemble_slot_lists[slot]
		for child: Node in list.get_children():
			child.queue_free()
		_assemble_component_buttons[slot] = {}

	for i: int in range(GInventory.get_slot_count()):
		var contents: Dictionary = GInventory.get_slot_contents(i)
		if contents.is_empty():
			continue
		if (contents.get("quantity", 0) as int) <= 0 or contents.get("damaged", false):
			continue
		var item_id: StringName = StringName(contents["item_id"] as String)
		var slot: String = _classify_component_slot(item_id)
		if slot == "":
			continue
		var instance_id: int = contents["instance_id"] as int
		var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(item_id)
		var button: Button = _create_assemble_component_button(slot, instance_id, definition)
		_assemble_slot_lists[slot].add_child(button)
		_assemble_component_buttons[slot][instance_id] = button

	_rebuild_assembled_list()


## Classifies an owned TowerComponent item into its assembly column by
## loading its component_resource_path and checking the resolved Resource's
## runtime type -- matches TowerAssembly._resolve_component_resource()'s own
## cross-check discipline (never trusts a naming convention). Returns "" for
## any non-TowerComponent item or an item with no valid component link.
func _classify_component_slot(item_id: StringName) -> String:
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(item_id)
	if definition == null or definition.item_type != &"TowerComponent" or definition.component_resource_path == "":
		return ""
	var component: Resource = ResourceLoader.load(definition.component_resource_path)
	if component is FoundationComponent:
		return "foundation"
	if component is WeaponComponent:
		return "weapon"
	if component is FocusComponent:
		return "focus"
	if component is PowerComponent:
		return "power"
	return ""


func _create_assemble_component_button(slot: String, instance_id: int, definition: ItemDefinitionResource) -> Button:
	var button := Button.new()
	button.name = "Component_%d" % instance_id
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = true
	var display_name: String = definition.display_name if definition != null else str(instance_id)
	var selected: bool = _assemble_selection.get(slot, -1) == instance_id
	button.text = "%s [SELECTED]" % display_name if selected else display_name
	button.pressed.connect(_on_assemble_component_pressed.bind(slot, instance_id))
	_wire_focus_ring(button)
	return button


## Pressing an already-selected component in its own slot deselects it --
## every slot always has a way back to "none selected" without a modal,
## mirroring Imbue's CancelSelectionButton role but inline on the button
## itself rather than a separate control (this tab has 4 independent
## selections, not 1).
func _on_assemble_component_pressed(slot: String, instance_id: int) -> void:
	_assemble_selection[slot] = -1 if _assemble_selection.get(slot, -1) == instance_id else instance_id
	_rebuild_assemble_lists()


func _rebuild_assembled_list() -> void:
	for child: Node in _assembled_list.get_children():
		child.queue_free()
	if tower_assembly == null:
		return
	var tower_ids: Array[StringName] = tower_assembly.get_all_assembled_tower_ids()
	tower_ids.sort()
	for tower_id: StringName in tower_ids:
		var blueprint: TowerBlueprintData = tower_assembly.get_assembled_blueprint(tower_id)
		if blueprint == null:
			continue
		var label := Label.new()
		label.name = "Assembled_%s" % String(tower_id)
		label.text = blueprint.display_name
		_assembled_list.add_child(label)


## GDD: single press arms the confirmation modal -- assembly consumes 4 real
## crafted items, a hard-to-reverse action in the same category as Imbue/
## Upgrade, which both already use ConfirmationDialog rather than a bare
## single-press commit. A no-op with any slot unselected or an empty name --
## matches this file's established "safe no-op on an ineligible target"
## convention (_on_recipe_pressed's own comment).
func _on_assemble_button_pressed() -> void:
	if not _all_slots_selected() or _assemble_name_edit.text.strip_edges() == "":
		return
	_assemble_confirm_dialog.dialog_text = tr("FORGE_ASSEMBLE_CONFIRM_TEXT")
	_assemble_confirm_dialog.popup_centered()


func _all_slots_selected() -> bool:
	for slot: String in SLOT_KEYS:
		if _assemble_selection.get(slot, -1) == -1:
			return false
	return true


func _on_assemble_confirmed() -> void:
	if tower_assembly == null or not _all_slots_selected():
		return
	var display_name: String = _assemble_name_edit.text.strip_edges()
	tower_assembly.assemble_tower(
			_assemble_selection["foundation"], _assemble_selection["weapon"],
			_assemble_selection["focus"], _assemble_selection["power"], display_name)
	# Reset regardless of the call's own success/rejection -- a rejected
	# assembly (e.g. a selected component was consumed elsewhere between
	# selection and confirm) leaves nothing meaningful to keep selected; the
	# rebuild below re-lists whatever the player still actually owns.
	_assemble_selection = {"foundation": -1, "weapon": -1, "focus": -1, "power": -1}
	_assemble_name_edit.text = ""
	_rebuild_assemble_lists()


# ---------------------------------------------------------------------------
# Assemble tab test/inspection accessors
# ---------------------------------------------------------------------------

func get_assemble_component_button(slot: String, instance_id: int) -> Button:
	return (_assemble_component_buttons.get(slot, {}) as Dictionary).get(instance_id)


func get_assemble_selection(slot: String) -> int:
	return _assemble_selection.get(slot, -1)


func get_assembled_list() -> VBoxContainer:
	return _assembled_list


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
	for buttons: Dictionary in [_recipe_buttons, _item_buttons, _rune_buttons, _upgrade_buttons]:
		for key: Variant in buttons.keys():
			var button: Button = buttons[key]
			var ring: Panel = button.get_node_or_null("FocusRing") as Panel
			if ring != null:
				ring.visible = button.has_focus() and _input_mode_tracker.is_focus_ring_visible()
	for slot: String in _assemble_component_buttons:
		var slot_buttons: Dictionary = _assemble_component_buttons[slot]
		for instance_id: Variant in slot_buttons:
			var button: Button = slot_buttons[instance_id]
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
