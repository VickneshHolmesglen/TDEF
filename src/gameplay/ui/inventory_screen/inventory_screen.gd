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
## Out of scope for this story (see story doc's "Out of Scope" section): Story 002's
## tab-switching content/categorization logic (TabStripPlaceholder below is a static,
## non-interactive strip only), Crafting panel's real content (AC-14, deferred — no
## Crafting GDD exists), slot-expansion-driven live grid growth (Story 003), any
## drag-and-drop/context-menu interaction, and all scene-transition/navigation wiring.

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
@onready var _tab_strip: HBoxContainer = $MainLayout/LeftPanel/TabStripPlaceholder
@onready var _slot_grid: GridContainer = $MainLayout/LeftPanel/SlotGrid
@onready var _crafting_placeholder_label: Label = $MainLayout/RightPanel/CraftingPlaceholderLabel

var _slot_buttons: Array[Button] = []
var _slot_focus_rings: Array[Panel] = []


func _ready() -> void:
	if inventory == null:
		inventory = GInventory

	_crafting_placeholder_label.text = tr("INVENTORY_CRAFTING_PLACEHOLDER")

	_build_tab_strip_placeholder()
	_build_slot_grid()
	_wire_focus_neighbors()

	# Single connection for the whole grid — Signal.connect() dedups by
	# (target object, method) and does NOT treat differing .bind() arguments
	# as distinct connections. Connecting the same _on_input_mode_changed
	# method once per slot (10x) silently drops connections 2-10 at runtime
	# ("already connected" errors) — confirmed via live Godot MCP test. One
	# connection here, fanning out to every slot inside the handler, is the
	# correct pattern; focus_entered/focus_exited remain per-button below
	# since those ARE legitimately distinct signals per Button instance.
	_input_mode_tracker.input_mode_changed.connect(_on_input_mode_changed)


# ---------------------------------------------------------------------------
# Left panel — tab-strip placeholder (static, non-interactive; AC-13 framing only)
# ---------------------------------------------------------------------------

func _build_tab_strip_placeholder() -> void:
	for tab: StringName in Inventory.TAB_ORDER:
		var label := Label.new()
		label.text = tr(TAB_LABEL_KEYS.get(tab, String(tab)))
		label.focus_mode = Control.FOCUS_NONE  ## non-interactive per this story's scope
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tab_strip.add_child(label)


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


## Computed once at slot-build time, matching this screen's existing
## one-time-at-mount rendering convention (the pre-existing text rendering
## this replaces was never live-refreshed either — a known limitation this
## spec doesn't fix or worsen). Empty slot: no text, no frame, no icon.
## Occupied slot with a real icon: icon + corner quantity label, no text —
## the icon carries the "what this is" meaning the text used to. Occupied
## slot with no icon yet (every material today, until Phase 3 art lands):
## falls back to the exact pre-existing "item_id xN" text, zero regression.
## Rarity frame renders independently of the icon/text branch, whenever the
## resolved definition has non-empty rarity data.
func _apply_slot_visual(button: Button, rarity_frame: RarityFrame, item_icon: TextureRect, quantity_label: Label, index: int) -> void:
	var contents: Dictionary = inventory.get_slot_contents(index)
	if contents.is_empty():
		button.text = ""
		return

	var item_id: String = contents["item_id"]
	var quantity: int = contents["quantity"]
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(item_id))

	if definition != null and definition.rarity != "":
		rarity_frame.rarity = definition.rarity

	if definition != null and definition.icon != null:
		button.text = ""
		item_icon.texture = definition.icon
		item_icon.visible = true
		quantity_label.text = "x%d" % quantity
		quantity_label.visible = true
	else:
		button.text = "%s x%d" % [item_id, quantity]


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
