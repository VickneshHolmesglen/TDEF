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
## Update: the Equipment tab's item detail is now the fixed EquipmentInfoPanel
## (equipment-display spec); floating tooltips remain out of scope.
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
## assemble_tower() consumes 3-6 owned Tower Component items (Foundation/
## Weapon/Focus/Power/Shaft/Top, tier-gated per tower.md Rule 4c since
## 2026-09-01), which Crafting's own recipes produce, not anything
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

const EquipmentInfoPanelScript := preload("res://src/gameplay/ui/inventory_screen/equipment_info_panel.gd")

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
## RELOCATED HERE" note). "shaft"/"top" added 2026-09-01 — Foundation+Weapon
## remain always-required; Shaft/Top/Focus/Power phase in by the selected
## Foundation's tier (tower_assembly.gd's REQUIRED_AT_TIER) — see
## _all_slots_selected()'s own doc comment for the exact gating.
const SLOT_KEYS: Array[String] = ["foundation", "weapon", "focus", "power", "shaft", "top"]

## Tower Component tab — "Bases"/"Shafts"/"Tops" subpanels (2026-08-21,
## player-requested; Shafts/Tops added 2026-09-01, same player request
## extended to the tower's other two vertical sections): a visual reference
## gallery of every tower-part shape currently authored in assets/art/towers/
## (see that folder's own commit history -- "Slice tower base sheet into 9
## alpha-cut pedestal pieces", 2026-08-17 -- and
## design/art/asset-generation-prompts.md's own note: "Usage (shared vs.
## per-tier vs. per-archetype) is not yet decided, so these are named by
## shape rather than wired into any tower-components pipeline code"). This
## is deliberately a pure asset-preview gallery, NOT an inventory/ownership
## list like the rest of this screen -- these shapes have no
## ItemDefinitionResource, no FoundationComponent link, and are not
## craftable/ownable in any way yet, so there is no "owned" state to filter
## on. Shown alongside SlotGrid on the TowerComponent tab only, mirroring
## EquipmentPaperdoll's own "extra panel on one specific tab" precedent
## above. All three panels share the same 9 shape names and sizing/layout
## constants (renamed TOWER_BASE_* -> TOWER_PART_* 2026-09-01 to reflect
## that shared reuse honestly, now that "base" would otherwise ambiguously
## mean both "the bottom section" and "the shape id") -- only the art path
## format differs per panel (tower_base_/tower_shaft_/tower_top_).
const TOWER_PART_SHAPES: Array[String] = [
	"round", "square", "octagon", "hexplank", "triangle",
	"tiered", "scalloped", "stump", "stonemound",
]
const TOWER_BASE_ART_PATH_FORMAT: String = "res://assets/art/towers/tower_base_%s.png"
const TOWER_SHAFT_ART_PATH_FORMAT: String = "res://assets/art/towers/tower_shaft_%s.png"
const TOWER_TOP_ART_PATH_FORMAT: String = "res://assets/art/towers/tower_top_%s.png"
## 96.0 -> 76.8 (20% smaller, player-requested 2026-08-21) -> 40.0 -> 24.0
## (player-requested 2026-09-12 twice in the same session: first "still
## oversized at 76.8," then -- after the name labels below the icon were
## removed -- "some components are out of bounds on screen," since all 3
## panels' 9-shape grids stacked in LeftPanel still overflowed the viewport
## at 40.0 with no scroll to reach the clipped rows) -> 31.2 -> 40.56 -> 48.672
## (player-requested "+30%" twice then "+20%", all 2026-09-15 -- each request
## applied on top of the prior value, not back to the 24.0 baseline;
## re-verified live each time that all 3 panels' 27 shapes still fit the
## viewport with no scroll needed).
const TOWER_PART_DISPLAY_HEIGHT: float = 48.672
## 6 -> 4 alongside the 40.0 icon-size reduction, then 14 (spread-out
## request), settled back down to 8 alongside the 24.0 reduction + label
## removal -- less per-entry height now needs less breathing room to avoid
## reading as cramped.
const TOWER_PART_GRID_SEPARATION: int = 8

## Fixed footprint every preview slot shares regardless of its shape's own
## native art aspect ratio (2026-09-15, player-requested "match in terms of
## size... appear attached to the other part") -- see
## _build_tower_preview_slot's own doc comment.
const TOWER_PREVIEW_SLOT_SIZE: Vector2 = Vector2(140.0, 64.0)
## Player-specified: "Blue for bases, green for shafts, and yellow for tops."
## Placeholder alpha -- art-director TBD, matches FOCUS_RING_COLOR-style
## precedent elsewhere in this codebase for an unlocked visual-polish value.
const TOWER_PREVIEW_BASE_COLOR: Color = Color(0.2, 0.45, 0.9, 0.45)
const TOWER_PREVIEW_SHAFT_COLOR: Color = Color(0.25, 0.75, 0.35, 0.45)
const TOWER_PREVIEW_TOP_COLOR: Color = Color(0.95, 0.85, 0.15, 0.45)

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
@onready var _equipment_paperdoll: Control = $MainLayout/LeftPanel/EquipmentRow/EquipmentPaperdoll
var _info_panel: PanelContainer
## "Bases"/"Shafts"/"Tops" subpanels (see TOWER_PART_SHAPES' own doc
## comment) -- built entirely in code in _build_tower_part_panel(), same
## reason EquipmentPaperdoll builds itself in code (equipment_paperdoll.gd's
## own header comment): purely static content, no .tscn structure needed
## beyond these three placeholder Controls for them to attach to.
##
## Order reversed top-to-bottom (2026-09-15, player-requested) from the
## original Bases/Shafts/Tops reading order to Tops/Shafts/Bases -- so the
## on-screen stacking visually matches a real tower (foundation at the
## bottom of the screen, top piece at the top), and lines up with
## TowerPreviewPanel's own Top/Shaft/Base slot order to its right.
## TowerComponentRow (new wrapper, replaces the 3 panels' own individual
## .visible toggling) holds TowerPartsColumn (these 3 panels) side-by-side
## with TowerPreviewPanel -- see that var's own doc comment.
@onready var _tower_component_row: Control = $MainLayout/LeftPanel/TowerComponentRow
@onready var _tower_tops_panel: Control = $MainLayout/LeftPanel/TowerComponentRow/TowerPartsColumn/TowerTopsPanel
@onready var _tower_shafts_panel: Control = $MainLayout/LeftPanel/TowerComponentRow/TowerPartsColumn/TowerShaftsPanel
@onready var _tower_bases_panel: Control = $MainLayout/LeftPanel/TowerComponentRow/TowerPartsColumn/TowerBasesPanel
## Live tower-assembly preview (2026-09-15, player-requested): shows the
## currently-selected shape from each of the 3 galleries stacked as one
## silhouette (Top/Shaft/Base, top to bottom -- see _tower_tops_panel's own
## doc comment for the ordering rationale), each slot tinted by category
## (TOWER_PREVIEW_TOP_COLOR/_SHAFT_COLOR/_BASE_COLOR) to match the player's
## own yellow/green/blue color scheme. Built in _build_tower_preview_panel().
@onready var _tower_preview_panel: Control = $MainLayout/LeftPanel/TowerComponentRow/TowerPreviewPanel
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
@onready var _repair_tab_button: Button = $MainLayout/RightPanel/RightPanelContent/CraftingTabStrip/RepairTabButton
@onready var _recipe_scroll: ScrollContainer = $MainLayout/RightPanel/RightPanelContent/RecipeScroll
@onready var _recipe_list_host: VBoxContainer = $MainLayout/RightPanel/RightPanelContent/RecipeScroll/RecipeListHost
@onready var _repair_view: ScrollContainer = $MainLayout/RightPanel/RightPanelContent/RepairView
@onready var _repair_list_host: VBoxContainer = $MainLayout/RightPanel/RightPanelContent/RepairView/RepairListHost
@onready var _repair_empty_label: Label = $MainLayout/RightPanel/RightPanelContent/RepairView/RepairListHost/RepairEmptyLabel
@onready var _assemble_view: Control = $MainLayout/RightPanel/RightPanelContent/AssembleView
@onready var _assemble_slot_lists: Dictionary[String, VBoxContainer] = {
	"foundation": $MainLayout/RightPanel/RightPanelContent/AssembleView/FoundationColumn/FoundationScroll/FoundationList,
	"weapon": $MainLayout/RightPanel/RightPanelContent/AssembleView/WeaponColumn/WeaponScroll/WeaponList,
	"focus": $MainLayout/RightPanel/RightPanelContent/AssembleView/FocusColumn/FocusScroll/FocusList,
	"power": $MainLayout/RightPanel/RightPanelContent/AssembleView/PowerColumn/PowerScroll/PowerList,
	"shaft": $MainLayout/RightPanel/RightPanelContent/AssembleView/ShaftColumn/ShaftScroll/ShaftList,
	"top": $MainLayout/RightPanel/RightPanelContent/AssembleView/TopColumn/TopScroll/TopList,
}
@onready var _assembled_list: VBoxContainer = $MainLayout/RightPanel/RightPanelContent/AssembleView/AssembledColumn/AssembledScroll/AssembledList
@onready var _assemble_name_edit: LineEdit = $MainLayout/RightPanel/RightPanelContent/AssembleView/AssembleFooter/AssembleNameEdit
@onready var _assemble_button: Button = $MainLayout/RightPanel/RightPanelContent/AssembleView/AssembleFooter/AssembleButton
@onready var _assemble_confirm_dialog: ConfirmationDialog = $AssembleConfirmDialog

## Assemble Towers tab's own sub-tab strip (2026-09-12, player-requested): the
## 7 component/assembled-tower categories no longer render as 7 simultaneous
## side-by-side columns -- at RightPanel's real ~420px width that squeezed
## every column to unreadable, overlapping-label narrowness before a single
## owned component button was even added (confirmed via live Godot MCP
## screenshot: "Assembled Towers" clipped off the right edge with the panel
## still empty). One category visible at a time, selected by this tab strip,
## mirrors CraftingTabStrip's own established Recipes/Assemble/Repair
## sub-tab convention one level up (_on_crafting_tab_pressed).
@onready var _assemble_slot_tab_buttons: Dictionary[String, Button] = {
	"foundation": $MainLayout/RightPanel/RightPanelContent/AssembleView/AssembleSlotTabStrip/FoundationTabButton,
	"weapon": $MainLayout/RightPanel/RightPanelContent/AssembleView/AssembleSlotTabStrip/WeaponTabButton,
	"focus": $MainLayout/RightPanel/RightPanelContent/AssembleView/AssembleSlotTabStrip/FocusTabButton,
	"power": $MainLayout/RightPanel/RightPanelContent/AssembleView/AssembleSlotTabStrip/PowerTabButton,
	"shaft": $MainLayout/RightPanel/RightPanelContent/AssembleView/AssembleSlotTabStrip/ShaftTabButton,
	"top": $MainLayout/RightPanel/RightPanelContent/AssembleView/AssembleSlotTabStrip/TopTabButton,
	"assembled": $MainLayout/RightPanel/RightPanelContent/AssembleView/AssembleSlotTabStrip/AssembledTabButton,
}
## Same 7 keys as _assemble_slot_tab_buttons -- "assembled" here maps to
## AssembledColumn (owned Tower Components use _assemble_slot_lists, keyed by
## SLOT_KEYS only; this dict additionally covers the read-only Assembled
## Towers panel so both share one visibility-toggle code path).
@onready var _assemble_slot_columns: Dictionary[String, Control] = {
	"foundation": $MainLayout/RightPanel/RightPanelContent/AssembleView/FoundationColumn,
	"weapon": $MainLayout/RightPanel/RightPanelContent/AssembleView/WeaponColumn,
	"focus": $MainLayout/RightPanel/RightPanelContent/AssembleView/FocusColumn,
	"power": $MainLayout/RightPanel/RightPanelContent/AssembleView/PowerColumn,
	"shaft": $MainLayout/RightPanel/RightPanelContent/AssembleView/ShaftColumn,
	"top": $MainLayout/RightPanel/RightPanelContent/AssembleView/TopColumn,
	"assembled": $MainLayout/RightPanel/RightPanelContent/AssembleView/AssembledColumn,
}
var _active_assemble_slot: String = "foundation"

## Set by _build_tower_preview_panel() (called before the 3 galleries build
## their own entries -- see _ready()'s own comment) and read by
## _build_tower_part_panel()/_create_tower_part_entry() to wire each shape's
## selection straight to its matching preview slot.
var _preview_top_icon: TextureRect
var _preview_shaft_icon: TextureRect
var _preview_base_icon: TextureRect

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
## slot ("foundation"/"weapon"/"focus"/"power"/"shaft"/"top") -> selected
## instance_id, or -1 if that slot has no selection yet. Reset on every
## successful assembly and on tab-away-and-back is deliberately NOT done --
## a player switching tabs mid-selection (e.g. to check Recipes) should not
## lose their picks.
var _assemble_selection: Dictionary[String, int] = {"foundation": -1, "weapon": -1, "focus": -1, "power": -1, "shaft": -1, "top": -1}
## true = Assemble Towers sub-tab showing, false = Recipes or Repair sub-tab
## showing. Kept exactly as-is (not widened to a 3-way enum) so existing
## callers of is_showing_assemble() keep their current true-only-for-Assemble
## contract -- _showing_repair (below) is a separate, orthogonal flag.
var _showing_assemble: bool = false

## true = Repair sub-tab showing (2026-08-23, closes crafting.md Rule 6's
## missing UI half -- Crafting.resolve_repair()/Inventory.clear_damaged_flag()
## were already fully implemented and tested, nothing anywhere ever called
## them). Independent of _showing_assemble by design -- see that var's own
## comment.
var _showing_repair: bool = false


func _ready() -> void:
	if inventory == null:
		inventory = GInventory
	if crafting == null:
		crafting = get_tree().get_first_node_in_group(&"crafting") as Crafting
	if tower_assembly == null:
		tower_assembly = get_tree().get_first_node_in_group(&"tower_assembly") as TowerAssembly

	_build_tab_strip()
	_build_equipment_info_panel()
	_build_slot_grid()
	_wire_focus_neighbors()
	_refresh_slot_visibility()
	_set_equipment_widgets_visible(_active_tab == &"Equipment")
	# Preview panel built BEFORE the 3 galleries -- each gallery entry wires
	# its own toggled signal straight to the matching preview slot's icon
	# (see _build_tower_part_panel's own doc comment), so the icon reference
	# must already exist by the time gallery entries are constructed.
	_build_tower_preview_panel()
	_build_tower_bases_panel()
	_build_tower_shafts_panel()
	_build_tower_tops_panel()
	_tower_component_row.visible = _active_tab == &"TowerComponent"
	_build_crafting_panel()

	_recipes_tab_button.pressed.connect(_on_crafting_tab_pressed.bind(false))
	_assemble_tab_button.pressed.connect(_on_crafting_tab_pressed.bind(true))
	_repair_tab_button.pressed.connect(_on_repair_tab_pressed)
	_assemble_button.pressed.connect(_on_assemble_button_pressed)
	_assemble_confirm_dialog.confirmed.connect(_on_assemble_confirmed)
	for slot: String in _assemble_slot_tab_buttons:
		_assemble_slot_tab_buttons[slot].pressed.connect(_on_assemble_slot_tab_pressed.bind(slot))
	_rebuild_assemble_lists()
	_rebuild_repair_list()

	GEventBus.recipe_discovered.connect(_on_recipe_discovered)
	GEventBus.item_added.connect(_on_inventory_item_changed)
	GEventBus.item_removed.connect(_on_inventory_item_changed)
	GEventBus.component_crafted.connect(_on_component_crafted)
	GEventBus.tower_assembled.connect(_on_tower_assembled)
	GEventBus.component_repaired.connect(_on_component_repaired)

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
	if GEventBus.component_repaired.is_connected(_on_component_repaired):
		GEventBus.component_repaired.disconnect(_on_component_repaired)


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
	_set_equipment_widgets_visible(tab == &"Equipment")
	_tower_component_row.visible = tab == &"TowerComponent"


## Adds the info panel next to the paperdoll (EquipmentRow, declared in the
## .tscn so the paperdoll is never reparented -- reparenting would fire its
## _exit_tree() and drop its equipment_slot_changed subscription) and
## forwards the paperdoll's hover signals to it (equipment-display spec §3.3).
func _build_equipment_info_panel() -> void:
	_info_panel = EquipmentInfoPanelScript.new()
	_info_panel.name = "EquipmentInfoPanel"
	$MainLayout/LeftPanel/EquipmentRow.add_child(_info_panel)
	_equipment_paperdoll.connect(&"slot_info_requested", _on_paperdoll_slot_info_requested)
	_equipment_paperdoll.connect(&"slot_info_cleared", _on_slot_info_cleared)


func _set_equipment_widgets_visible(shown: bool) -> void:
	_equipment_paperdoll.visible = shown
	if _info_panel != null:
		_info_panel.visible = shown


func _on_paperdoll_slot_info_requested(slot_name: String) -> void:
	var contents: Dictionary = GInventory.get_equipped_item(slot_name)
	if contents.is_empty():
		_info_panel.show_bonuses()
		return
	_info_panel.show_item(contents, slot_name)


## Slot-grid button hover/focus. Empty slots and non-equipment items fall
## back to the Bonuses state; an item sitting in one of the 10 equipment
## slot indices is treated as equipped (no swap preview).
func _on_slot_info_requested(index: int) -> void:
	if _info_panel == null:
		return
	var contents: Dictionary = inventory.get_slot_contents(index)
	var item_id: String = contents.get("item_id", "") as String
	if item_id == "":
		_info_panel.show_bonuses()
		return
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(item_id))
	if definition == null or definition.equipment_category == "":
		_info_panel.show_bonuses()
		return
	_info_panel.show_item(contents, _equipped_slot_name_for_index(index))


func _on_slot_info_cleared() -> void:
	if _info_panel != null:
		_info_panel.show_bonuses()


func _equipped_slot_name_for_index(index: int) -> String:
	for slot_name: String in Inventory.EQUIPMENT_SLOT_INDEX:
		if Inventory.EQUIPMENT_SLOT_INDEX[slot_name] == index:
			return slot_name
	return ""


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
			visible_on_tab = definition != null and _tab_for_item_type(definition.item_type) == _active_tab
		_slot_buttons[i].visible = visible_on_tab


## hero-skill-build.md Rule 13: skill-modifier items are filed under the
## Equipment tab rather than a 5th tab of their own — the only item_type
## whose tab membership isn't its own name. Every other item_type maps to
## itself, matching Inventory.TAB_ORDER's existing 1:1 identity convention
## (see that const's own doc comment) unchanged.
func _tab_for_item_type(item_type: StringName) -> StringName:
	if item_type == &"skill_modifier":
		return &"Equipment"
	return item_type


# ---------------------------------------------------------------------------
# Left panel — Tower Component tab's "Bases"/"Shafts"/"Tops" subpanels (see
# TOWER_PART_SHAPES' own doc comment). Pure static asset galleries, built
# once at _ready() -- no refresh trigger needed, unlike every other panel in
# this screen, since there is no owned/live game state behind these images
# to go stale. All three panels share one generic builder (_build_tower_part_
# panel) and one generic entry constructor (_create_tower_part_entry) --
# only the target panel, translation key, name prefix, and art path format
# differ per panel.
# ---------------------------------------------------------------------------

func _build_tower_bases_panel() -> void:
	_build_tower_part_panel(_tower_bases_panel, "BasesHeader", "INVENTORY_TOWER_BASES_HEADER", "BasesGrid", "Base", TOWER_BASE_ART_PATH_FORMAT, _preview_base_icon)


func _build_tower_shafts_panel() -> void:
	_build_tower_part_panel(_tower_shafts_panel, "ShaftsHeader", "INVENTORY_TOWER_SHAFTS_HEADER", "ShaftsGrid", "Shaft", TOWER_SHAFT_ART_PATH_FORMAT, _preview_shaft_icon)


func _build_tower_tops_panel() -> void:
	_build_tower_part_panel(_tower_tops_panel, "TopsHeader", "INVENTORY_TOWER_TOPS_HEADER", "TopsGrid", "Top", TOWER_TOP_ART_PATH_FORMAT, _preview_top_icon)


# ---------------------------------------------------------------------------
# Left panel — Tower Component tab's live assembly preview (2026-09-15,
# player-requested). Shows the currently-selected shape from each of the 3
# galleries stacked into one silhouette -- Top/Shaft/Base, top to bottom,
# same order as the reordered galleries to their left -- each slot tinted by
# category to match the player's own yellow/green/blue color scheme. All 3
# slots share one fixed size (TOWER_PREVIEW_SLOT_SIZE) regardless of each
# shape's own native art aspect ratio, and the slot stack has zero
# separation, so a Base+Shaft+Top selection reads as one continuous tower
# rather than three mismatched pieces.
# ---------------------------------------------------------------------------

func _build_tower_preview_panel() -> void:
	var header := Label.new()
	header.name = "PreviewHeader"
	header.text = tr("INVENTORY_TOWER_PREVIEW_HEADER")
	header.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
	_tower_preview_panel.add_child(header)

	var stack := VBoxContainer.new()
	stack.name = "SlotStack"
	stack.add_theme_constant_override("separation", 0)
	_tower_preview_panel.add_child(stack)

	_preview_top_icon = _build_tower_preview_slot(stack, "TopSlot", TOWER_PREVIEW_TOP_COLOR)
	_preview_shaft_icon = _build_tower_preview_slot(stack, "ShaftSlot", TOWER_PREVIEW_SHAFT_COLOR)
	_preview_base_icon = _build_tower_preview_slot(stack, "BaseSlot", TOWER_PREVIEW_BASE_COLOR)


## One preview slot: a color-tinted PanelContainer (its stylebox background
## IS the category color) hosting a single TextureRect that PanelContainer
## stretches to fill the slot -- STRETCH_KEEP_ASPECT_CENTERED then centers
## whichever shape's art within that fixed rect, so every slot presents at
## the same footprint no matter the source art's own proportions.
func _build_tower_preview_slot(parent: Control, slot_name: String, color: Color) -> TextureRect:
	var slot := PanelContainer.new()
	slot.name = slot_name
	slot.custom_minimum_size = TOWER_PREVIEW_SLOT_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	slot.add_theme_stylebox_override("panel", style)
	parent.add_child(slot)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)
	return icon


## Shared builder for the three tower-part galleries (Bases/Shafts/Tops).
## `panel` is the placeholder Control from the .tscn to attach into;
## `header_name`/`translation_key` label the panel's own title;
## `grid_name` names the HFlowContainer node for scene-tree legibility;
## `entry_prefix` names each individual entry ("Base_round", "Shaft_round",
## "Top_round"); `art_path_format` selects which of the three asset sets
## (tower_base_/tower_shaft_/tower_top_) this panel draws from -- all three
## use the identical TOWER_PART_SHAPES id list, since the source art was
## authored as three matched sets of the same 9 shapes. `preview_icon` is
## this panel's matching slot in TowerPreviewPanel (built beforehand by
## _build_tower_preview_panel(), see _ready()'s own comment) -- each entry
## wires its own selection straight to it.
func _build_tower_part_panel(panel: Control, header_name: String, translation_key: String, grid_name: String, entry_prefix: String, art_path_format: String, preview_icon: TextureRect) -> void:
	var header := Label.new()
	header.name = header_name
	header.text = tr(translation_key)
	header.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
	panel.add_child(header)

	# HFlowContainer, not GridContainer (2026-09-15, player-requested): a
	# fixed 3-column GridContainer only ever used about a third of the real
	# available width next to RightPanel, leaving the rest blank (confirmed
	# by the player's own annotated screenshot, docs/Tower Components
	# Layout.PNG, at a much wider actual window size than this project's
	# 1280x720 MCP test resolution). HFlowContainer wraps entries
	# left-to-right based on whatever width it's actually given, so it fills
	# that space now and keeps reflowing correctly as more shapes are added
	# later (the player's stated plan) without a column count to retune.
	var grid := HFlowContainer.new()
	grid.name = grid_name
	grid.add_theme_constant_override("h_separation", TOWER_PART_GRID_SEPARATION)
	grid.add_theme_constant_override("v_separation", TOWER_PART_GRID_SEPARATION)
	panel.add_child(grid)

	# One ButtonGroup per panel (Bases/Shafts/Tops each select independently)
	# -- same toggle-strip convention _build_tab_strip already uses one level
	# up, so at most one shape is highlighted per panel at a time.
	var group := ButtonGroup.new()
	for shape: String in TOWER_PART_SHAPES:
		grid.add_child(_create_tower_part_entry(shape, entry_prefix, art_path_format, group, preview_icon))


## One tower-part entry: the alpha-cut art only -- no name label underneath
## (removed 2026-09-12, player-requested: with all 3 panels' 9-shape grids
## stacked in LeftPanel, the label's added per-entry height was pushing the
## Tops panel's bottom row off the bottom of the viewport with no scroll to
## reach it). The shape id is still discoverable via tooltip_text rather
## than lost outright -- these have no display_name anywhere (no
## ItemDefinitionResource exists for them, see TOWER_PART_SHAPES' own doc
## comment), so the shape id itself, title-cased, is the only name available.
##
## Clickable/selectable (2026-09-12, player-requested): previously a plain
## VBoxContainer with no focus_mode and no pressed signal -- these shapes
## still have no linked game data (no ItemDefinitionResource, not craftable/
## ownable, per this class's own doc comment above), so selecting one has no
## downstream effect yet. This makes the gallery a real focusable/toggleable
## UI element rather than static art -- root is a Button so a click/focus
## anywhere in the entry's rect registers, with the icon overlaid as a
## MOUSE_FILTER_IGNORE child so it doesn't steal the click from the Button
## underneath.
func _create_tower_part_entry(shape: String, entry_prefix: String, art_path_format: String, group: ButtonGroup, preview_icon: TextureRect) -> Control:
	var entry := Button.new()
	entry.name = "%s_%s" % [entry_prefix, shape]
	entry.toggle_mode = true
	entry.button_group = group
	entry.focus_mode = Control.FOCUS_ALL
	entry.tooltip_text = shape.capitalize()

	var texture: Texture2D = load(art_path_format % shape) as Texture2D
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var icon_width: float = TOWER_PART_DISPLAY_HEIGHT
	if texture != null:
		var aspect: float = float(texture.get_width()) / float(texture.get_height())
		icon_width = TOWER_PART_DISPLAY_HEIGHT * aspect
		icon.custom_minimum_size = Vector2(icon_width, TOWER_PART_DISPLAY_HEIGHT)

	# CenterContainer, not an anchor preset on the icon itself (2026-09-12,
	# fixes a real misalignment player found live): Control.set_anchors_preset
	# computes its offset from the control's CURRENT size at call time, but
	# `icon` is freshly constructed here with no size yet (zero), and Button
	# -- unlike the VBoxContainer this used to be -- is not a Container, so
	# those anchors/offsets are never recalculated once the icon's real size
	# is known later. The icon ended up with its top-left corner pinned to
	# the button's center point rather than actually centered. CenterContainer
	# is a real Container -- it centers `icon` correctly regardless of when
	# the icon's size becomes known.
	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(icon)
	entry.add_child(center)
	# entry.custom_minimum_size is set explicitly rather than relying on
	# Button's own minimum-size calculation, which (unlike the VBoxContainer
	# this used to be) does NOT account for arbitrary child Controls -- a
	# real bug this project already found live: leaving it unset let
	# GridContainer collapse every cell to Button's near-zero default,
	# spilling icons into neighboring entries.
	entry.custom_minimum_size = Vector2(icon_width, TOWER_PART_DISPLAY_HEIGHT)

	# Selected-state ring (2026-09-15, player-requested "make it clickable"
	# after confirming live that entry.button_pressed genuinely does flip on
	# click -- the gap was never the click itself, it was that nothing ever
	# rendered the selection: the default Button pressed/normal styleboxes
	# read as visually identical against this tile's icon-filled content, so
	# a real, working click looked like it did nothing. ADR-0011's own
	# FocusRingFactory overlay pattern (used elsewhere in this file for
	# keyboard focus) applied here to selection instead -- toggled tracks
	# button_pressed directly, including ButtonGroup-driven deselection when
	# a sibling shape in the same panel is picked instead.
	var selected_ring: Panel = FocusRingFactory.build(entry)
	selected_ring.name = "SelectedRing"
	entry.toggled.connect(func(is_selected: bool) -> void: selected_ring.visible = is_selected)

	# Live preview wiring (2026-09-15, player-requested "when i click on a
	# tower component, it should show up on the right panel"). Only reacts to
	# is_selected == true -- ButtonGroup fires toggled(false) on the
	# previously-selected sibling right around the same time as this entry's
	# toggled(true), so reacting to both would just overwrite the slot twice
	# with the same final texture; reacting only to the true case is both
	# simpler and correct regardless of which shape was shown before.
	entry.toggled.connect(func(is_selected: bool) -> void:
		if is_selected:
			preview_icon.texture = texture)

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

	# Equipment info panel (equipment-display spec §3.4): hover AND focus both
	# drive it, so K/M and gamepad share one path.
	button.mouse_entered.connect(_on_slot_info_requested.bind(index))
	button.mouse_exited.connect(_on_slot_info_cleared)
	button.focus_entered.connect(_on_slot_info_requested.bind(index))
	button.focus_exited.connect(_on_slot_info_cleared)

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


## resolve_repair() deliberately does not fire item_added/item_removed for
## its Common-material cost payment (AC-6, crafting.gd's own doc comment) --
## component_repaired is the only signal marking a successful repair, so this
## screen must listen for it directly rather than relying on the existing
## item_added/item_removed refresh path.
func _on_component_repaired(_item_id: String, _component_type: String) -> void:
	_refresh_crafting_panel()  ## Common material count changed
	_refresh_all_slot_visuals()  ## the repaired item's damaged state changed
	_rebuild_repair_list()


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
	craft_button.set_meta(UiAudioBinder.META_KEY, UiAudioBinder.KIND_NONE)
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
	_showing_repair = false
	_recipes_tab_button.button_pressed = not show_assemble
	_assemble_tab_button.button_pressed = show_assemble
	_repair_tab_button.button_pressed = false
	_recipe_scroll.visible = not show_assemble
	_assemble_view.visible = show_assemble
	_repair_view.visible = false


func is_showing_assemble() -> bool:
	return _showing_assemble


## One category column visible at a time (see _assemble_slot_tab_buttons/
## _assemble_slot_columns' own doc comment for why). Selections already made
## in other categories are untouched -- _assemble_selection is keyed
## independently of which column is currently on screen.
func _on_assemble_slot_tab_pressed(slot: String) -> void:
	_active_assemble_slot = slot
	for key: String in _assemble_slot_columns:
		_assemble_slot_columns[key].visible = key == slot
		_assemble_slot_tab_buttons[key].button_pressed = key == slot


func get_active_assemble_slot() -> String:
	return _active_assemble_slot


# ---------------------------------------------------------------------------
# Right panel — Repair tab (2026-08-23, closes crafting.md Rule 6's missing
# UI half). Crafting.resolve_repair()/Inventory.clear_damaged_flag()/
# component_repaired were already fully implemented and tested (Story 005) --
# no production logic added here, purely the display + button wiring that
# never existed for any of it.
# ---------------------------------------------------------------------------

func _on_repair_tab_pressed() -> void:
	_showing_assemble = false
	_showing_repair = true
	_recipes_tab_button.button_pressed = false
	_assemble_tab_button.button_pressed = false
	_repair_tab_button.button_pressed = true
	_recipe_scroll.visible = false
	_assemble_view.visible = false
	_repair_view.visible = true
	_rebuild_repair_list()


func is_showing_repair() -> bool:
	return _showing_repair


## Lists every damaged Inventory slot (locked items excluded -- a damaged
## component can never be equipped/locked simultaneously per crafting.md's
## own documented Edge Case, but the filter is defensive, matching
## _compute_owned_totals()'s identical locked-exclusion convention).
func _rebuild_repair_list() -> void:
	for child: Node in _repair_list_host.get_children():
		if child == _repair_empty_label:
			continue
		_repair_list_host.remove_child(child)
		child.queue_free()

	if crafting == null:
		_repair_empty_label.visible = true
		return

	var by_rarity: Dictionary = _compute_owned_totals()["by_rarity"]
	var owned_common: int = by_rarity.get(&"Common", 0)
	var any_damaged: bool = false
	for i: int in range(inventory.get_slot_count()):
		var contents: Dictionary = inventory.get_slot_contents(i)
		if contents.is_empty() or contents.get("locked", false):
			continue
		if not (contents.get("damaged", false) as bool):
			continue
		var stat_overrides: Dictionary = contents.get("stat_overrides", {})
		if not stat_overrides.has(&"quality_tier"):
			continue
		var quality_tier: int = int(stat_overrides[&"quality_tier"])
		if quality_tier < 1 or quality_tier > 4:
			continue
		any_damaged = true
		_repair_list_host.add_child(_create_repair_row(contents, quality_tier, owned_common))

	_repair_empty_label.visible = not any_damaged


func _create_repair_row(contents: Dictionary, quality_tier: int, owned_common: int) -> Control:
	var instance_id: int = contents["instance_id"] as int
	var item_id: String = contents["item_id"] as String
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(item_id))
	var cost: int = Crafting.repair_common_cost(quality_tier)
	var sufficient: bool = owned_common >= cost

	var row := PanelContainer.new()
	row.name = "Repair_%d" % instance_id
	row.add_theme_stylebox_override("panel", ShellChromeStyle.chrome_panel_stylebox())

	var content := VBoxContainer.new()
	row.add_child(content)

	var title_row := HBoxContainer.new()
	content.add_child(title_row)

	var name_label := Label.new()
	name_label.text = definition.display_name if definition != null else item_id
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
	title_row.add_child(name_label)

	var repair_button := Button.new()
	repair_button.text = "Repair"
	repair_button.disabled = not sufficient
	repair_button.focus_mode = Control.FOCUS_ALL
	repair_button.add_theme_stylebox_override("normal", ShellChromeStyle.chrome_button_stylebox(sufficient))
	repair_button.pressed.connect(_on_repair_button_pressed.bind(instance_id))
	repair_button.set_meta(UiAudioBinder.META_KEY, UiAudioBinder.KIND_NONE)
	title_row.add_child(repair_button)

	var cost_label := Label.new()
	cost_label.text = "Common %d/%d" % [owned_common, cost]
	cost_label.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT if sufficient else ShellChromeStyle.UI_WARNING_ORANGE)
	content.add_child(cost_label)

	return row


func _on_repair_button_pressed(instance_id: int) -> void:
	# No direct refresh call needed here: resolve_repair() emits
	# component_repaired on success (already subscribed above, see
	# _on_component_repaired), and a rejected/no-op attempt changes nothing
	# to refresh.
	crafting.resolve_repair(instance_id)


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
	if component is ShaftComponent:
		return "shaft"
	if component is TopComponent:
		return "top"
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


## Foundation+Weapon+Shaft are always required; Top/Focus/Power phase in as
## the SELECTED Foundation's own tier rises (mirrors tower_assembly.gd's
## REQUIRED_AT_TIER exactly — this is a client-side pre-check only, the real
## gate is TowerAssembly.assemble_tower() itself, which rejects independently
## if this ever drifts out of sync). No Foundation selected, or a selected
## Foundation whose component fails to resolve, is always "not ready."
func _all_slots_selected() -> bool:
	if _assemble_selection.get("foundation", -1) == -1:
		return false
	if _assemble_selection.get("weapon", -1) == -1:
		return false
	if _assemble_selection.get("shaft", -1) == -1:
		return false
	var tier: int = _resolve_selected_foundation_tier()
	if tier == -1:
		return false
	if tier >= 2 and _assemble_selection.get("top", -1) == -1:
		return false
	if tier >= 3 and _assemble_selection.get("focus", -1) == -1:
		return false
	if tier >= 4 and _assemble_selection.get("power", -1) == -1:
		return false
	return true


## Resolves the currently-selected Foundation's own `tier` field, or -1 if
## nothing is selected or the selection no longer resolves to a real
## FoundationComponent (e.g. consumed elsewhere since selection).
func _resolve_selected_foundation_tier() -> int:
	var instance_id: int = _assemble_selection.get("foundation", -1)
	if instance_id == -1:
		return -1
	var contents: Dictionary = inventory.get_slot_contents_by_instance_id(instance_id)
	if contents.is_empty():
		return -1
	var item_id: String = contents.get("item_id", "") as String
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(item_id))
	if definition == null or definition.component_resource_path == "":
		return -1
	var component: Resource = ResourceLoader.load(definition.component_resource_path)
	if component is FoundationComponent:
		return (component as FoundationComponent).tier
	return -1


func _on_assemble_confirmed() -> void:
	if tower_assembly == null or not _all_slots_selected():
		return
	var display_name: String = _assemble_name_edit.text.strip_edges()
	tower_assembly.assemble_tower(
			_assemble_selection["foundation"], _assemble_selection["weapon"],
			_assemble_selection["focus"], _assemble_selection["power"], display_name,
			_assemble_selection["shaft"], _assemble_selection["top"])
	# Reset regardless of the call's own success/rejection -- a rejected
	# assembly (e.g. a selected component was consumed elsewhere between
	# selection and confirm) leaves nothing meaningful to keep selected; the
	# rebuild below re-lists whatever the player still actually owns.
	_assemble_selection = {"foundation": -1, "weapon": -1, "focus": -1, "power": -1, "shaft": -1, "top": -1}
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
