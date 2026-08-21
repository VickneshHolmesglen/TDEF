extends Control

## Inventory Screen — Two-Panel Presentation (Epic 03, Story 007).
##
## GDD source: design/gdd/inventory.md
## ADR: docs/architecture/adr-0011-ui-dual-focus-handling.md (focus/hover mechanism)
##      docs/architecture/adr-0016-inventory-storage-model.md (data side, read-only here)
## Story: production/epics/epic-03-core-economy/story-007-two-panel-screen-presentation.md
##
## AC-13: left inventory grid and right-hand panel are simultaneously visible with
## no extra navigation — both panels are permanent siblings under MainLayout, never
## tabbed/paged/scrolled-to-reveal.
## AC-14-focus: every slot's focus-ring overlay is gated on
## has_focus() AND InputModeTracker.is_focus_ring_visible(); mouse hover is a fully
## separate signal (HoverHighlight overlay, driven only by mouse_entered/exited) —
## the two visual states are never merged into one boolean (ADR-0011 Decision).
##
## Root is a plain Control (not CanvasLayer, unlike pause_menu.gd): this screen has
## no pause-while-open requirement (unlike Pause Menu's PROCESS_MODE_ALWAYS-while-
## SceneTree.paused need), so the extra CanvasLayer indirection isn't justified here.
##
## No class_name declared — matches pause_menu.gd's TD-workflow-001 precedent (a
## recurring Godot 4.6.2 class-cache fragility where a fresh class_name isn't
## picked up by a bare headless boot). This scene is only ever instanced directly.
##
## Out of scope for this story (see story doc's "Out of Scope" section):
## slot-expansion-driven live grid growth (Story 003), any drag-and-drop/
## context-menu interaction, and all scene-transition/navigation wiring.
##
## Tab switching (2026-08-10, player-requested): Story 002's own deferred
## "tab-switching content/categorization logic" is now implemented — each
## TAB_ORDER entry is a real toggle button that filters the slot grid to
## that item_type. Per inventory.md Rule 3, tabs are a view over ONE shared
## slot pool (capacity/locks/expansion are never per-category), not four
## separate slot ranges — so an EMPTY slot is not yet "assigned" to any
## category and remains visible on every tab (it's available capacity for
## whatever gets placed there next); only OCCUPIED slots hide when their
## item's item_type doesn't match the active tab. Deferred by the same
## "core functionality" scope decision as the Crafting panel: keyboard/
## gamepad focus-neighbor rewiring per tab switch (inventory.md's own
## D-pad-wraps-to-cycle-tabs spec), drag-and-drop, and tooltips are all
## pre-existing gaps this change doesn't newly introduce or attempt to close.
##
## Crafting panel's real content (2026-08-10, player-requested): AC-14's
## former "deferred — no Crafting GDD exists" note is stale — design/gdd/
## crafting.md exists and is Designed. Implements crafting.md's "core
## functionality" scope only (deliberately deferred by explicit user
## decision): the unlock-cascade one-shot VFX flash, material-drain pulse
## animation, and full gamepad D-pad spatial-adjacency crossing between the
## recipe list and this grid (mouse/keyboard-tab navigation works via each
## recipe row's own focusable Craft button).
##
## Assemble Towers tab, RELOCATED HERE (2026-08-21, player-requested): moved
## out of Equipment Forge (equipment_forge_screen.gd) — TowerAssembly.
## assemble_tower() consumes 4 owned Tower Component items (Foundation/
## Weapon/Focus/Power), which Crafting's own recipes produce, not anything
## Forge-specific (equipment/runes/sacrifices). Its prior placement in Forge
## had no stated architectural reason (design/quick-specs/tower-assembly-
## 2026-08-11.md never gives one — it just says "Forge tab"), and moving it
## here is the actual system it's downstream of. TowerAssembly itself
## (src/core/tower_assembly/tower_assembly.gd) needed zero code changes to
## move — it was already a standalone, group-discovered system with its own
## SaveRestorer, exactly like Crafting's own discovery pattern. The Crafting
## right-hand panel gains a 2-way sub-tab strip (Recipes / Assemble Towers)
## for this — AC-13's "never tabbed" requirement governs the LEFT-vs-RIGHT
## panel relationship (both remain simultaneously visible), not sub-content
## within the right panel, which already had precedent in LeftPanel's own
## category TabStrip.

const GRID_COLUMNS: int = 5
const SLOT_SIZE: Vector2 = Vector2(64, 64)

## Tab display-label localization keys, keyed by Inventory.TAB_ORDER's identifiers
## (Story 002 data, read-only — this story only reads TAB_ORDER to build a static
## placeholder strip, it does not add tab-switching logic).
const TAB_LABEL_KEYS: Dictionary[StringName, String] = {
	&"Equipment": "INVENTORY_TAB_EQUIPMENT",
	&"TowerComponent": "INVENTORY_TAB_TOWER_COMPONENT",
	&"Material": "INVENTORY_TAB_MATERIAL",
	&"CraftedGood": "INVENTORY_TAB_CRAFTED_GOOD",
}

## Crafting panel — category grouping order. Matches Inventory.TAB_ORDER's
## own TowerComponent-before-CraftedGood ordering (design/gdd/crafting.md UI
## Requirements: "mirrors the left panel's fixed tabs where applicable").
const RECIPE_CATEGORY_ORDER: Array[String] = ["tower_component", "crafted_good"]
const RECIPE_CATEGORY_LABEL_KEYS: Dictionary[String, String] = {
	"tower_component": "CRAFTING_CATEGORY_TOWER_COMPONENT",
	"crafted_good": "CRAFTING_CATEGORY_CRAFTED_GOOD",
}

## Assemble Towers tab — slot key -> component script's global class_name,
## used to classify an owned TowerComponent item into its assembly column
## purely from its resolved Resource's runtime type. Ported unchanged from
## equipment_forge_screen.gd (see this file's own "Assemble Towers tab,
## RELOCATED HERE" note).
const SLOT_KEYS: Array[String] = ["foundation", "weapon", "focus", "power"]

## Tower Component tab — "Bases" subpanel (2026-08-21, player-requested): a
## visual reference gallery of every tower-base pedestal shape currently
## authored in assets/art/towers/ (see that folder's own commit history --
## "Slice tower base sheet into 9 alpha-cut pedestal pieces", 2026-08-17 --
## and design/art/asset-generation-prompts.md's own note: "Usage (shared vs.
## per-tier vs. per-archetype) is not yet decided, so these are named by
## shape rather than wired into any tower-components pipeline code"). This
## is deliberately a pure asset-preview gallery, NOT an inventory/ownership
## list like the rest of this screen -- these 9 shapes have no
## ItemDefinitionResource, no FoundationComponent link, and are not
## craftable/ownable in any way yet, so there is no "owned" state to filter
## on. Shown alongside SlotGrid on the TowerComponent tab only, mirroring
## EquipmentPaperdoll's own "extra panel on one specific tab" precedent
## above.
const TOWER_BASE_SHAPES: Array[String] = [
	"round", "square", "octagon", "hexplank", "triangle",
	"tiered", "scalloped", "stump", "stonemound",
]
const TOWER_BASE_ART_PATH_FORMAT: String = "res://assets/art/towers/tower_base_%s.png"
## 20% smaller than the original 96.0 (player-requested, 2026-08-21).
const TOWER_BASE_DISPLAY_HEIGHT: float = 76.8
const TOWER_BASE_GRID_COLUMNS: int = 3
## Spacing readjusted alongside the 20% size reduction -- tighter gaps read
## correctly at the smaller scale instead of leaving the same absolute gap
## proportionally larger than before.
const TOWER_BASE_GRID_SEPARATION: int = 6
const TOWER_BASE_ENTRY_SEPARATION: int = 2

## Injectable for tests (a caller may still supply an isolated Inventory
## instance). In real use, defaults to the real GInventory Autoload (ADR-0016,
## Story 019 — Inventory is Autoload #9) rather than instancing a fresh,
## disconnected Inventory: prior to Story 019, Inventory's Autoload-vs-scene-
## instanced status was still "TBD," so this screen instanced its own local
## Inventory as a self-sufficient fallback. Now that GInventory is the single
## canonical instance, that fallback would silently create a second Inventory
## that independently registers with GSavePersistence under the same
## "inventory" save key (no duplicate-key guard exists there) — a real
## split-brain risk, not just a cosmetic one. Fixed as part of Story 019's
## code review.
@export var inventory: Inventory

@onready var _input_mode_tracker: InputModeTracker = $InputModeTracker
@onready var _tab_strip: HBoxContainer = $MainLayout/LeftPanel/TabStrip
## Player-requested 2026-08-16 (equipment_paperdoll.gd's own class doc
## comment has the full rationale/scope). Player decision: shown ALONGSIDE
## _slot_grid on the Equipment tab, not instead of it — visible only while
## _active_tab == &"Equipment", toggled in _on_tab_pressed() next to
## _refresh_slot_visibility()'s own filtering.
@onready var _equipment_paperdoll: Control = $MainLayout/LeftPanel/EquipmentPaperdoll
## "Bases" subpanel (see TOWER_BASE_SHAPES' own doc comment) -- built
## entirely in code in _build_tower_bases_panel(), same reason
## EquipmentPaperdoll builds itself in code (equipment_paperdoll.gd's own
## header comment): purely static content, no .tscn structure needed beyond
## this one placeholder Control for it to attach to.
@onready var _tower_bases_panel: Control = $MainLayout/LeftPanel/TowerBasesPanel
@onready var _slot_grid: GridContainer = $MainLayout/LeftPanel/SlotGrid
## Crafting is deliberately NOT an Autoload (ADR-0023: "Scene-instanced,
## Sanctuary-only") — unlike Inventory, there is no GCrafting global to fall
## back to. Real gap found and fixed here (2026-08-10, mirrors this same
## session's ResourceEconomy discovery): Crafting had a fully-implemented,
## fully-unit-tested backend (resolve_craft(), discovery ledger, save/restore)
## but was never instanced in any real scene. Fixed by giving it a shell-
## owned instance as a child of SanctuaryUI.tscn (persists across room
## switches within one Sanctuary visit) and following EquipmentForge's own
## already-established discovery pattern — NOT a direct $Crafting child of
## this scene, which RoomHost destroys and recreates on every room switch;
## a Crafting instance living there would silently wipe its discovery
## ledger every time the player left and returned to this tab.
@export var crafting: Crafting
## TowerAssembly is likewise scene-instanced, not an Autoload — discovered
## via the "tower_assembly" group, matching Crafting's own pattern exactly
## (see this file's "Assemble Towers tab, RELOCATED HERE" note above).
@export var tower_assembly: TowerAssembly
@onready var _recipes_tab_button: Button = $MainLayout/RightPanel/RightPanelContent/CraftingTabStrip/RecipesTabButton
@onready var _assemble_tab_button: Button = $MainLayout/RightPanel/RightPanelContent/CraftingTabStrip/AssembleTabButton
@onready var _recipe_scroll: ScrollContainer = $MainLayout/RightPanel/RightPanelContent/RecipeScroll
@onready var _recipe_list_host: VBoxContainer = $MainLayout/RightPanel/RightPanelContent/RecipeScroll/RecipeListHost
@onready var _assemble_view: Control = $MainLayout/RightPanel/RightPanelContent/AssembleView
@onready var _assemble_slot_lists: Dictionary[String, VBoxContainer] = {
	"foundation": $MainLayout/RightPanel/RightPanelContent/AssembleView/SlotColumns/FoundationColumn/FoundationList,
	"weapon": $MainLayout/RightPanel/RightPanelContent/AssembleView/SlotColumns/WeaponColumn/WeaponList,
	"focus": $MainLayout/RightPanel/RightPanelContent/AssembleView/SlotColumns/FocusColumn/FocusList,
	"power": $MainLayout/RightPanel/RightPanelContent/AssembleView/SlotColumns/PowerColumn/PowerList,
}
@onready var _assembled_list: VBoxContainer = $MainLayout/RightPanel/RightPanelContent/AssembleView/SlotColumns/AssembledColumn/AssembledList
@onready var _assemble_name_edit: LineEdit = $MainLayout/RightPanel/RightPanelContent/AssembleView/AssembleFooter/AssembleNameEdit
@onready var _assemble_button: Button = $MainLayout/RightPanel/RightPanelContent/AssembleView/AssembleFooter/AssembleButton
@onready var _assemble_confirm_dialog: ConfirmationDialog = $AssembleConfirmDialog

var _slot_buttons: Array[Button] = []
var _slot_focus_rings: Array[Panel] = []
## Second overlay ring per slot, distinct from _slot_focus_rings (keyboard
## focus) — lights up while a Crafting recipe row is hovered/focused,
## highlighting which left-panel slots that recipe would consume
## (design/gdd/crafting.md UI Requirements: "Selecting a recipe row
## highlights ... the specific Inventory slots on the left panel that would
## be consumed"). Kept as a separate node/color (Accent Cyan, not the
## keyboard ring's gold) so both can be visible at once without one
## overwriting the other's state.
var _slot_craft_preview_rings: Array[Panel] = []
var _crafting_rarity_frames: Array[RarityFrame] = []
var _crafting_item_icons: Array[TextureRect] = []
var _crafting_quantity_labels: Array[Label] = []

var _tab_buttons: Dictionary[StringName, Button] = {}
var _tab_button_group := ButtonGroup.new()
var _active_tab: StringName = Inventory.TAB_ORDER[0]

## Assemble Towers tab state — ported unchanged from equipment_forge_screen.gd.
var _assemble_component_buttons: Dictionary[String, Dictionary] = {}  ## slot -> {instance_id: Button}
## slot ("foundation"/"weapon"/"focus"/"power") -> selected instance_id, or
## -1 if that slot has no selection yet. Reset on every successful assembly
## and on tab-away-and-back is deliberately NOT done -- a player switching
## tabs mid-selection (e.g. to check Recipes) should not lose their picks.
var _assemble_selection: Dictionary[String, int] = {"foundation": -1, "weapon": -1, "focus": -1, "power": -1}
## true = Assemble Towers sub-tab showing, false = Recipes sub-tab showing.
var _showing_assemble: bool = false


func _ready() -> void:
	if inventory == null:
		inventory = GInventory
	if crafting == null:
		crafting = get_tree().get_first_node_in_group(&"crafting") as Crafting
	if tower_assembly == null:
		tower_assembly = get_tree().get_first_node_in_group(&"tower_assembly") as TowerAssembly

	_build_tab_strip()
	_build_slot_grid()
	_wire_focus_neighbors()
	_refresh_slot_visibility()
	_equipment_paperdoll.visible = _active_tab == &"Equipment"
	_build_tower_bases_panel()
	_tower_bases_panel.visible = _active_tab == &"TowerComponent"
	_build_crafting_panel()

	_recipes_tab_button.pressed.connect(_on_crafting_tab_pressed.bind(false))
	_assemble_tab_button.pressed.connect(_on_crafting_tab_pressed.bind(true))
	_assemble_button.pressed.connect(_on_assemble_button_pressed)
	_assemble_confirm_dialog.confirmed.connect(_on_assemble_confirmed)
	_rebuild_assemble_lists()

	GEventBus.recipe_discovered.connect(_on_recipe_discovered)
	GEventBus.item_added.connect(_on_inventory_item_changed)
	GEventBus.item_removed.connect(_on_inventory_item_changed)
	GEventBus.component_crafted.connect(_on_component_crafted)
	GEventBus.tower_assembled.connect(_on_tower_assembled)

	# Single connection for the whole grid — Signal.connect() dedups by
	# (target object, method) and does NOT treat differing .bind() arguments
	# as distinct connections. Connecting the same _on_input_mode_changed
	# method once per slot (10x) silently drops connections 2-10 at runtime
	# ("already connected" errors) — confirmed via live Godot MCP test. One
	# connection here, fanning out to every slot inside the handler, is the
	# correct pattern; focus_entered/focus_exited remain per-button below
	# since those ARE legitimately distinct signals per Button instance.
	_input_mode_tracker.input_mode_changed.connect(_on_input_mode_changed)


## RoomHost contract (ADR-0032 Section 1): any hosted room that owns EventBus
## subscriptions must expose this exact method, called synchronously before
## teardown. This room previously had none — now that _ready() connects 4
## signals, omitting this would leak them into a freed node the next time the
## player navigates away from this room.
func disconnect_own_subscriptions() -> void:
	if GEventBus.recipe_discovered.is_connected(_on_recipe_discovered):
		GEventBus.recipe_discovered.disconnect(_on_recipe_discovered)
	if GEventBus.item_added.is_connected(_on_inventory_item_changed):
		GEventBus.item_added.disconnect(_on_inventory_item_changed)
	if GEventBus.item_removed.is_connected(_on_inventory_item_changed):
		GEventBus.item_removed.disconnect(_on_inventory_item_changed)
	if GEventBus.component_crafted.is_connected(_on_component_crafted):
		GEventBus.component_crafted.disconnect(_on_component_crafted)
	if GEventBus.tower_assembled.is_connected(_on_tower_assembled):
		GEventBus.tower_assembled.disconnect(_on_tower_assembled)


# ---------------------------------------------------------------------------
# Left panel — tab-strip placeholder (static, non-interactive; AC-13 framing only)
# ---------------------------------------------------------------------------

func _build_tab_strip() -> void:
	for tab: StringName in Inventory.TAB_ORDER:
		var button := Button.new()
		button.name = "Tab_%s" % String(tab)
		button.text = tr(TAB_LABEL_KEYS.get(tab, String(tab)))
		button.toggle_mode = true
		button.button_group = _tab_button_group
		button.button_pressed = tab == _active_tab
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_tab_pressed.bind(tab))
		_tab_strip.add_child(button)
		_tab_buttons[tab] = button


func _on_tab_pressed(tab: StringName) -> void:
	_active_tab = tab
	_refresh_slot_visibility()
	_equipment_paperdoll.visible = tab == &"Equipment"
	_tower_bases_panel.visible = tab == &"TowerComponent"


## Rule 3: tabs filter ONE shared slot pool by item_type, not four separate
## ranges — an occupied slot hides when its item's item_type doesn't match
## the active tab. Called at build time and after every event that can
## change slot contents (_refresh_all_slot_visuals()'s own call sites).
##
## Player-requested 2026-08-16: empty slots no longer stay visible on any
## tab (the prior behavior — "empty slots are unassigned capacity, always
## shown" — was never actually mandated by inventory.md's GDD text; it was
## an implementation-time choice made when tab-switching was first added,
## now reversed). This also removes an accepted duplication equipment_
## paperdoll.gd's own doc comment flagged: the 10 reserved Hero equip-slot
## placeholders (see the next paragraph) used to render in both this flat
## grid AND the paperdoll — hiding them here makes the paperdoll the sole
## visualization of equip-slot state, which is what it was built for.
##
## get_slot_contents() returns a non-empty Dictionary for a real,
## already-allocated InventorySlot even when nothing is placed in it yet
## (Rule 5's pre-locked mandatory equip slots: item_id == "", locked ==
## true, instance_id == -1) — found live via Godot MCP: `contents.is_empty()`
## alone treated these as "occupied by an unrecognized item" (item_id ""
## resolves to no ItemDefinitionResource) and hid them on every tab except
## whichever one null item_type coincidentally matched. Checking item_id
## directly is the correct "is this slot actually holding something" test.
##
## quantity <= 0 is also treated as empty — real bug found and fixed
## 2026-08-10 (live MCP repro): Inventory.consume_by_type()/consume_by_rarity()
## emit item_removed BEFORE nulling out an exhausted slot (decrementing
## slot.quantity to 0 happens first, the `_slots[i] = null` line runs after
## the emit() call returns), so a handler reacting synchronously to
## item_removed — as this one does — observes a transient "quantity 0 but
## item_id still populated" state, not the final cleared slot. Filtering on
## quantity as well makes this correct regardless of that emit ordering.
func _refresh_slot_visibility() -> void:
	for i: int in range(_slot_buttons.size()):
		var contents: Dictionary = inventory.get_slot_contents(i)
		var item_id: String = contents.get("item_id", "") as String
		var quantity: int = contents.get("quantity", 0) as int
		var visible_on_tab: bool = false
		if item_id != "" and quantity > 0:
			var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(item_id))
			visible_on_tab = definition != null and definition.item_type == _active_tab
		_slot_buttons[i].visible = visible_on_tab


# ---------------------------------------------------------------------------
# Left panel — Tower Component tab's "Bases" subpanel (see TOWER_BASE_SHAPES'
# own doc comment). Pure static asset gallery, built once at _ready() -- no
# refresh trigger needed, unlike every other panel in this screen, since
# there is no owned/live game state behind these 9 images to go stale.
# ---------------------------------------------------------------------------

func _build_tower_bases_panel() -> void:
	var header := Label.new()
	header.name = "BasesHeader"
	header.text = tr("INVENTORY_TOWER_BASES_HEADER")
	header.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
	_tower_bases_panel.add_child(header)

	var grid := GridContainer.new()
	grid.name = "BasesGrid"
	grid.columns = TOWER_BASE_GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", TOWER_BASE_GRID_SEPARATION)
	grid.add_theme_constant_override("v_separation", TOWER_BASE_GRID_SEPARATION)
	_tower_bases_panel.add_child(grid)

	for shape: String in TOWER_BASE_SHAPES:
		grid.add_child(_create_tower_base_entry(shape))


## One base entry: the alpha-cut pedestal art plus its shape name underneath
## (e.g. "Round", "Hexplank") -- these have no display_name anywhere (no
## ItemDefinitionResource exists for them, see TOWER_BASE_SHAPES' own doc
## comment), so the shape id itself, title-cased, is the only name available.
func _create_tower_base_entry(shape: String) -> Control:
	var entry := VBoxContainer.new()
	entry.name = "Base_%s" % shape
	entry.add_theme_constant_override("separation", TOWER_BASE_ENTRY_SEPARATION)

	var texture: Texture2D = load(TOWER_BASE_ART_PATH_FORMAT % shape) as Texture2D
	var icon := TextureRect.new()
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# EXPAND_IGNORE_SIZE: the default expand_mode (EXPAND_KEEP_SIZE) reports a
	# TextureRect's own native texture size as its minimum size, silently
	# clamping a manually-set `.size` right back to native pixel dimensions --
	# a real bug this project already found and fixed twice this session
	# (diorama.gd's watchtower/habitat sprites, both ~450px source art
	# rendering at full native resolution instead of the intended display
	# size until this fix landed). Applying it here proactively rather than
	# rediscovering the same bug a third time.
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture = texture
	if texture != null:
		var aspect: float = float(texture.get_width()) / float(texture.get_height())
		icon.custom_minimum_size = Vector2(TOWER_BASE_DISPLAY_HEIGHT * aspect, TOWER_BASE_DISPLAY_HEIGHT)
	entry.add_child(icon)

	var label := Label.new()
	label.text = shape.capitalize()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entry.add_child(label)

	return entry


# ---------------------------------------------------------------------------
# Left panel — slot grid
# ---------------------------------------------------------------------------

## Builds exactly get_slot_count() slot widgets (10 at STARTING_SLOT_COUNT today).
## Deliberately reads slot count at build time rather than hardcoding 10 in the
## scene file — Story 003's tier-driven growth isn't this story's concern, but
## there's no reason to hardcode a count this screen can just ask Inventory for.
## SIZE_SHRINK_BEGIN (TD-ui-002 item 2): GridContainer's default
## size_flags_horizontal (SIZE_FILL) stretches its own bounding rect to fill
## LeftPanel's full width, but does NOT stretch its columns to match — live-
## verified via Godot MCP this left up to ~675px of dead space between the
## slot grid and RightPanel at the default viewport, with all 10 fixed-size
## 64x64 slot buttons still clustered in the top-left corner of that
## oversized rect. Shrinking SlotGrid to its own natural content size
## collapses that dead space; the slots themselves are unaffected (fixed
## SLOT_SIZE by design, not meant to grow to fill available width).
func _build_slot_grid() -> void:
	_slot_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_slot_grid.columns = GRID_COLUMNS
	var slot_count: int = inventory.get_slot_count()
	for i: int in range(slot_count):
		var slot_button: Button = _create_slot_button(i)
		_slot_grid.add_child(slot_button)
		_slot_buttons.append(slot_button)


## One slot widget: a Button plus overlay children — HoverHighlight
## (mouse-driven), FocusRing (keyboard/gamepad-driven, gated on
## InputModeTracker, ADR-0011's explicit "never merge into one boolean"
## requirement), RarityFrame, and ItemIcon/QuantityLabel (2026-08-06, design/
## quick-specs/inventory-slot-icons-2026-08-06.md).
func _create_slot_button(index: int) -> Button:
	var button := Button.new()
	button.name = "Slot%d" % index
	button.custom_minimum_size = SLOT_SIZE
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = true

	var hover_highlight := ColorRect.new()
	hover_highlight.name = "HoverHighlight"
	hover_highlight.color = Color(1.0, 1.0, 1.0, 0.15)
	hover_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_highlight.visible = false
	hover_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(hover_highlight)

	var rarity_frame := RarityFrame.new()
	rarity_frame.name = "RarityFrame"
	rarity_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rarity_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(rarity_frame)

	var item_icon := TextureRect.new()
	item_icon.name = "ItemIcon"
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.visible = false
	button.add_child(item_icon)

	# Explicit small fixed-offset corner badge rather than relying on anchor
	# presets alone -- PRESET_BOTTOM_RIGHT let the label's own natural
	# (unclipped) text size overflow below the slot's real bounds, caught
	# live via Godot MCP screenshot before shipping.
	var quantity_label := Label.new()
	quantity_label.name = "QuantityLabel"
	quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quantity_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	quantity_label.offset_left = -28.0
	quantity_label.offset_top = -18.0
	quantity_label.offset_right = -2.0
	quantity_label.offset_bottom = -2.0
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	quantity_label.clip_text = true
	quantity_label.add_theme_font_size_override("font_size", 14)
	quantity_label.visible = false
	button.add_child(quantity_label)

	_apply_slot_visual(button, rarity_frame, item_icon, quantity_label, index)
	_crafting_rarity_frames.append(rarity_frame)
	_crafting_item_icons.append(item_icon)
	_crafting_quantity_labels.append(quantity_label)

	# Crafting preview ring (see _slot_craft_preview_rings' own doc comment) —
	# built manually rather than via FocusRingFactory.build(), which hardcodes
	# the child name "FocusRing"; this slot already has one of those for
	# keyboard focus, so a second call would collide.
	var craft_preview_ring := Panel.new()
	craft_preview_ring.name = "CraftPreviewRing"
	var craft_preview_style := StyleBoxFlat.new()
	craft_preview_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	craft_preview_style.border_width_left = 3
	craft_preview_style.border_width_right = 3
	craft_preview_style.border_width_top = 3
	craft_preview_style.border_width_bottom = 3
	craft_preview_style.border_color = ShellChromeStyle.UI_ACCENT_CYAN
	craft_preview_ring.add_theme_stylebox_override("panel", craft_preview_style)
	craft_preview_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	craft_preview_ring.visible = false
	craft_preview_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(craft_preview_ring)
	_slot_craft_preview_rings.append(craft_preview_ring)

	# Shared builder (extracted 2026-07-20 from Mission HUD's identical ~15-line
	# StyleBoxFlat construction, originally duplicated here too — see
	# FocusRingFactory's own doc comment). Returns the built Panel directly,
	# so no fragile get_node("FocusRing") string lookup is needed afterward
	# (TD-ui-002 item 3 — a future rename of this child's name would
	# previously have failed silently instead of at compile time).
	var focus_ring: Panel = FocusRingFactory.build(button)
	_slot_focus_rings.append(focus_ring)

	# Hover: fully independent of focus, driven only by mouse_entered/exited.
	button.mouse_entered.connect(_on_slot_mouse_entered.bind(hover_highlight))
	button.mouse_exited.connect(_on_slot_mouse_exited.bind(hover_highlight))

	# Focus ring: has_focus() AND input_mode_tracker.is_focus_ring_visible() —
	# recomputed on focus change (per-button — legitimately distinct signals,
	# no dedup issue) and on input-mode change (ADR-0011 Key Interfaces
	# consumer pattern — that connection is made ONCE for the whole grid in
	# _ready(), not here; see _ready()'s comment for why).
	button.focus_entered.connect(_on_slot_focus_changed.bind(button, focus_ring))
	button.focus_exited.connect(_on_slot_focus_changed.bind(button, focus_ring))

	return button


## Called once at slot-build time AND on every live refresh since the
## Crafting panel was added (2026-08-10) — buying/crafting changes left-panel
## contents, so this can no longer be a one-time render (previously a
## documented, accepted limitation; now load-bearing correctness for
## design/gdd/crafting.md's "left-panel drain feedback" requirement). Empty
## slot: no text, no frame, no icon — explicitly reset, not just skipped, so
## a slot that WAS occupied and just emptied out (its last unit consumed by a
## craft) doesn't keep showing stale icon/quantity/rarity-frame state.
## Occupied slot with a real icon: icon + corner quantity label, no text —
## the icon carries the "what this is" meaning the text used to. Occupied
## slot with no icon yet (every material today, until Phase 3 art lands):
## falls back to the exact pre-existing "item_id xN" text, zero regression.
## Rarity frame renders independently of the icon/text branch, whenever the
## resolved definition has non-empty rarity data.
func _apply_slot_visual(button: Button, rarity_frame: RarityFrame, item_icon: TextureRect, quantity_label: Label, index: int) -> void:
	var contents: Dictionary = inventory.get_slot_contents(index)
	var item_id: String = contents.get("item_id", "") as String
	var quantity: int = contents.get("quantity", 0) as int
	# Real bugs found and fixed 2026-08-10 (while adding category tab
	# filtering): (1) get_slot_contents() returns a non-empty Dictionary for
	# a real, already-allocated but not-yet-filled InventorySlot (Rule 5's
	# pre-locked mandatory equip slots: item_id == "", locked == true) --
	# contents.is_empty() alone missed this and fell through to the
	# occupied-slot branch below with an empty item_id, rendering a stray
	# " x0" on every such slot. (2) Inventory.consume_by_type()/
	# consume_by_rarity() emit item_removed BEFORE nulling out an exhausted
	# slot, so a handler reacting synchronously (as _refresh_all_slot_
	# visuals() does) can observe a transient "quantity 0 but item_id still
	# populated" state -- treating quantity <= 0 as empty too closes that.
	if contents.is_empty() or item_id == "" or quantity <= 0:
		button.text = ""
		rarity_frame.rarity = ""
		item_icon.texture = null
		item_icon.visible = false
		quantity_label.visible = false
		return

	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(item_id))

	rarity_frame.rarity = definition.rarity if definition != null else ""

	if definition != null and definition.icon != null:
		button.text = ""
		item_icon.texture = definition.icon
		item_icon.visible = true
		quantity_label.text = "x%d" % quantity
		quantity_label.visible = true
	else:
		button.text = "%s x%d" % [item_id, quantity]
		item_icon.texture = null
		item_icon.visible = false
		quantity_label.visible = false


func _on_slot_mouse_entered(highlight: ColorRect) -> void:
	highlight.visible = true


func _on_slot_mouse_exited(highlight: ColorRect) -> void:
	highlight.visible = false


func _on_slot_focus_changed(button: Button, ring: Panel) -> void:
	ring.visible = button.has_focus() and _input_mode_tracker.is_focus_ring_visible()


## Single handler for the whole grid (one connection made in _ready(), not
## per-slot — see that comment for why). Re-evaluates has_focus() AND
## is_focus_ring_visible() for every slot; at most one slot has_focus() at a
## time, but iterating all of them is the only way one shared connection can
## keep every slot's ring correct without per-slot Callables (which is what
## caused the dedup bug this replaces).
func _on_input_mode_changed(_mode: InputModeTracker.InputMode) -> void:
	for i: int in range(_slot_buttons.size()):
		var button: Button = _slot_buttons[i]
		var ring: Panel = _slot_focus_rings[i]
		ring.visible = button.has_focus() and _input_mode_tracker.is_focus_ring_visible()


## Explicit focus_neighbor_top/bottom/left/right wiring per ADR-0011 — never
## left to Godot's automatic nearest-neighbor traversal. Edge slots (no
## neighbor in that direction) get a self-referencing NodePath rather than an
## empty one: an empty focus_neighbor_* path re-enables Godot's automatic
## fallback (engine reference docs confirm focus_neighbor_* resolution itself
## is unchanged in 4.6, but the automatic-traversal FALLBACK only activates
## when a path is unset) — a self-reference is an explicit "no movement past
## this edge" sentinel instead. Tab-wrap-at-edge (inventory.md's fuller
## requirement) is out of this story's scope (no interactive tab bar exists
## yet); this wiring is the deliberately simpler N-column-grid case only.
func _wire_focus_neighbors() -> void:
	var count: int = _slot_buttons.size()
	for i: int in range(count):
		var button: Button = _slot_buttons[i]
		var row: int = i / GRID_COLUMNS
		var col: int = i % GRID_COLUMNS
		var has_top: bool = row > 0
		var has_bottom: bool = i + GRID_COLUMNS < count
		var has_left: bool = col > 0
		var has_right: bool = col < GRID_COLUMNS - 1 and i + 1 < count
		button.focus_neighbor_top = _neighbor_path(button, i - GRID_COLUMNS, has_top)
		button.focus_neighbor_bottom = _neighbor_path(button, i + GRID_COLUMNS, has_bottom)
		button.focus_neighbor_left = _neighbor_path(button, i - 1, has_left)
		button.focus_neighbor_right = _neighbor_path(button, i + 1, has_right)


func _neighbor_path(button: Button, neighbor_index: int, has_neighbor: bool) -> NodePath:
	if has_neighbor:
		return button.get_path_to(_slot_buttons[neighbor_index])
	return button.get_path_to(button)


# ---------------------------------------------------------------------------
# Right panel — Crafting (design/gdd/crafting.md)
# ---------------------------------------------------------------------------

func _build_crafting_panel() -> void:
	_refresh_crafting_panel()


func _on_recipe_discovered(_recipe_id: String, _recipe_category: String) -> void:
	_refresh_crafting_panel()


## Fires for both Crafting's own consume/output calls (resolve_craft()) and
## every other Inventory mutation in the game — a live left-panel refresh is
## correct regardless of source, and re-checking craftability on every
## material change is exactly Rule 4's own "craftability flickers on and off
## with the player's current material stock" requirement.
func _on_inventory_item_changed(_item_id: String, _item_type: String, _quantity: int) -> void:
	_refresh_crafting_panel()
	_refresh_all_slot_visuals()
	_rebuild_assemble_lists()  ## owned Tower Components change with every Inventory mutation, same reasoning as _refresh_crafting_panel()'s own comment


func _on_component_crafted(_component_id: String, _component_type: String, _quality_tier: int) -> void:
	_refresh_crafting_panel()


func _on_tower_assembled(_tower_id: String, _display_name: String) -> void:
	_rebuild_assemble_lists()


func _refresh_all_slot_visuals() -> void:
	for i: int in range(_slot_buttons.size()):
		_apply_slot_visual(_slot_buttons[i], _crafting_rarity_frames[i], _crafting_item_icons[i], _crafting_quantity_labels[i], i)
	_refresh_slot_visibility()


## Rebuilds the entire recipe list from scratch — simplest correct approach
## given this panel only refreshes on discrete discovery/inventory events
## (never per-frame), matching this screen's existing rebuild-on-change
## precedent (_build_tab_strip()/_build_slot_grid() are also
## build-once-then-static outside their own refresh triggers).
func _refresh_crafting_panel() -> void:
	for child: Node in _recipe_list_host.get_children():
		_recipe_list_host.remove_child(child)
		child.queue_free()

	# Matches equipment_forge_screen.gd's identical guard: real gameplay
	# always finds the shell-owned instance via the "crafting" group, but an
	# isolated test mounting InventoryScreen.tscn on its own (no SanctuaryUI
	# in its tree) has nothing to discover — an empty recipe list, not a
	# crash, is the correct fallback.
	if crafting == null:
		return

	var owned_totals: Dictionary = _compute_owned_totals()

	for category: String in RECIPE_CATEGORY_ORDER:
		var recipes_in_category: Array[RecipeResource] = _discovered_recipes_in_category(category)
		if recipes_in_category.is_empty():
			continue
		# Rule 4 / UI Requirements "Default sort": Ready-to-craft first, then
		# Material-insufficient. Tech-locked is omitted -- a recipe is only
		# ever listed here once DISCOVERED (Rule 4), and discovery requires
		# the tech gate to already be satisfied, so a discovered-but-tech-
		# locked row can never actually occur (flagged as a pre-existing GDD
		# inconsistency between Rule 4 and the Visual/Audio table, not
		# something this implementation needs to resolve).
		recipes_in_category.sort_custom(_is_recipe_ready_first)

		var header := Label.new()
		header.text = tr(RECIPE_CATEGORY_LABEL_KEYS[category])
		header.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
		_recipe_list_host.add_child(header)

		for recipe: RecipeResource in recipes_in_category:
			_recipe_list_host.add_child(_create_recipe_row(recipe, owned_totals))


func _is_recipe_ready_first(a: RecipeResource, b: RecipeResource) -> bool:
	var a_ready: bool = crafting.is_craftable(a.recipe_id)
	var b_ready: bool = crafting.is_craftable(b.recipe_id)
	return a_ready and not b_ready


func _discovered_recipes_in_category(category: String) -> Array[RecipeResource]:
	var result: Array[RecipeResource] = []
	for recipe: RecipeResource in GGameDataRegistry.get_all_recipes().values():
		if recipe.recipe_category == category and crafting.is_discovered(recipe.recipe_id):
			result.append(recipe)
	return result


## Sums current holdings by both item_type and rarity, using the exact same
## unlocked+stackable filter as Inventory.has_items()/has_items_by_rarity()
## (ADR-0016) -- displayed "current" counts must match what actually gates
## craftability, not a naive raw sum across every slot.
func _compute_owned_totals() -> Dictionary:
	var by_item_type: Dictionary[StringName, int] = {}
	var by_rarity: Dictionary[StringName, int] = {}
	for i: int in range(inventory.get_slot_count()):
		var contents: Dictionary = inventory.get_slot_contents(i)
		if contents.is_empty():
			continue
		if contents.get("locked", false) or contents.get("instance_id", -1) != -1:
			continue
		var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(contents["item_id"] as String))
		if definition == null:
			continue
		var quantity: int = contents["quantity"] as int
		by_item_type[definition.item_type] = by_item_type.get(definition.item_type, 0) + quantity
		if definition.rarity != "":
			var rarity_key := StringName(definition.rarity)
			by_rarity[rarity_key] = by_rarity.get(rarity_key, 0) + quantity
	return {"by_item_type": by_item_type, "by_rarity": by_rarity}


## One recipe row: output icon + name, a Craft button (filled when
## craftable, outlined otherwise -- ShellChromeStyle's established filled-
## vs-outline actionable convention), and one cost line per input material
## ("[key] current/required", UI Parchment if sufficient else UI Warning
## Orange with a "!" badge -- both signals present per the GDD's own
## colorblind-safety requirement, never color-only).
func _create_recipe_row(recipe: RecipeResource, owned_totals: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.name = "Recipe_%s" % String(recipe.recipe_id)
	row.add_theme_stylebox_override("panel", ShellChromeStyle.chrome_panel_stylebox())

	var content := VBoxContainer.new()
	row.add_child(content)

	var title_row := HBoxContainer.new()
	content.add_child(title_row)

	var output_definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(recipe.output_item_id)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if output_definition != null and output_definition.icon != null:
		icon.texture = output_definition.icon
	title_row.add_child(icon)

	var name_label := Label.new()
	name_label.text = output_definition.display_name if output_definition != null else String(recipe.output_item_id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
	title_row.add_child(name_label)

	var craftable: bool = crafting.is_craftable(recipe.recipe_id)

	var craft_button := Button.new()
	craft_button.text = tr("CRAFTING_CRAFT_BUTTON")
	craft_button.disabled = not craftable
	craft_button.focus_mode = Control.FOCUS_ALL
	craft_button.add_theme_stylebox_override("normal", ShellChromeStyle.chrome_button_stylebox(craftable))
	craft_button.pressed.connect(_on_craft_button_pressed.bind(recipe.recipe_id))
	# Craft button focus doubles as this row's "selected" state for keyboard/
	# gamepad users (UI Requirements: "Focus rendering: same visible
	# non-color highlight ... applied identically to recipe rows") -- full
	# D-pad spatial-adjacency crossing into the left-panel grid is deferred
	# (see this file's class doc comment), but Tab/Shift+Tab and mouse hover
	# both already reach the left-panel-highlight preview through this.
	craft_button.focus_entered.connect(_on_recipe_row_hover.bind(recipe.recipe_id, true))
	craft_button.focus_exited.connect(_on_recipe_row_hover.bind(recipe.recipe_id, false))
	title_row.add_child(craft_button)

	var by_item_type: Dictionary = owned_totals["by_item_type"]
	var by_rarity: Dictionary = owned_totals["by_rarity"]
	for key: StringName in recipe.inputs:
		var required: int = recipe.inputs[key]
		var current: int = by_rarity.get(key, 0) if RecipeResource.VALID_RARITIES.has(key) else by_item_type.get(key, 0)
		var sufficient: bool = current >= required

		var cost_line := HBoxContainer.new()
		content.add_child(cost_line)

		var cost_label := Label.new()
		cost_label.text = "%s %d/%d" % [String(key), current, required]
		cost_label.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT if sufficient else ShellChromeStyle.UI_WARNING_ORANGE)
		cost_line.add_child(cost_label)

		if not sufficient:
			var badge := Label.new()
			badge.text = "!"
			badge.add_theme_stylebox_override("normal", ShellChromeStyle.badge_stylebox())
			cost_line.add_child(badge)

	row.mouse_entered.connect(_on_recipe_row_hover.bind(recipe.recipe_id, true))
	row.mouse_exited.connect(_on_recipe_row_hover.bind(recipe.recipe_id, false))

	return row


func _on_craft_button_pressed(recipe_id: StringName) -> void:
	# No direct refresh call needed here: resolve_craft() on success emits
	# component_crafted plus item_removed/item_added (both already
	# subscribed above), and a rejected/no-op attempt changes nothing to
	# refresh -- see resolve_craft()'s own doc comment for its exact
	# success/failure event contract.
	crafting.resolve_craft(recipe_id)


## Highlights (Accent Cyan ring, distinct from the keyboard-focus gold ring)
## every left-panel slot holding a material this recipe's inputs would
## consume -- "what could I make" made concrete per the GDD's own Player
## Fantasy section. Best-effort: a recipe cost of "8 Common" doesn't map to
## a specific 8 units across possibly-many Common-tier slots, so every slot
## matching ANY of the recipe's input keys lights up, not a quantity-exact
## subset.
func _on_recipe_row_hover(recipe_id: StringName, hovering: bool) -> void:
	for ring: Panel in _slot_craft_preview_rings:
		ring.visible = false
	if not hovering:
		return
	var recipe: RecipeResource = GGameDataRegistry.get_recipe(recipe_id)
	if recipe == null:
		return
	for i: int in _slots_matching_cost(recipe.inputs):
		_slot_craft_preview_rings[i].visible = true


func _slots_matching_cost(cost: Dictionary) -> Array[int]:
	var matches: Array[int] = []
	for i: int in range(inventory.get_slot_count()):
		var contents: Dictionary = inventory.get_slot_contents(i)
		if contents.is_empty():
			continue
		var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(contents["item_id"] as String))
		if definition == null:
			continue
		for key: StringName in cost:
			var is_match: bool = StringName(definition.rarity) == key if RecipeResource.VALID_RARITIES.has(key) else definition.item_type == key
			if is_match:
				matches.append(i)
				break
	return matches


# ---------------------------------------------------------------------------
# Right panel — Assemble Towers tab, RELOCATED FROM equipment_forge_screen.gd
# (2026-08-21) — combines 4 owned crafted tower components into a new
# placeable TowerBlueprintData. See design/quick-specs/tower-assembly-
# 2026-08-11.md and TowerAssembly.assemble_tower()'s own doc comment. Logic
# below is otherwise unchanged from its prior Forge implementation.
# ---------------------------------------------------------------------------

func _on_crafting_tab_pressed(show_assemble: bool) -> void:
	_showing_assemble = show_assemble
	_recipes_tab_button.button_pressed = not show_assemble
	_assemble_tab_button.button_pressed = show_assemble
	_recipe_scroll.visible = not show_assemble
	_assemble_view.visible = show_assemble


func is_showing_assemble() -> bool:
	return _showing_assemble


func _rebuild_assemble_lists() -> void:
	for slot: String in SLOT_KEYS:
		var list: VBoxContainer = _assemble_slot_lists[slot]
		for child: Node in list.get_children():
			child.queue_free()
		_assemble_component_buttons[slot] = {}

	for i: int in range(inventory.get_slot_count()):
		var contents: Dictionary = inventory.get_slot_contents(i)
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
	return button


## Pressing an already-selected component in its own slot deselects it --
## every slot always has a way back to "none selected" without a modal.
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


## Single press arms the confirmation modal -- assembly consumes 4 real
## crafted items, a hard-to-reverse action. A no-op with any slot unselected
## or an empty name, matching this screen's existing "safe no-op on an
## ineligible target" convention (_on_craft_button_pressed's own sibling
## resolve_craft() no-op behavior).
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
