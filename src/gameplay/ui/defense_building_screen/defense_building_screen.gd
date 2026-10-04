extends Control

## Defense Building Screen (Sanctuary UI Story 005's Room Hosting scope, epic-10).
##
## GDD source: design/gdd/defense-building.md — UI Requirements section (two
## linked views: tech tree, structure build; single-confirm convention for
## both, matching Crafting's precedent, NOT Menagerie's two-step sacrifice
## style — Defense Building's own justification: additive/never-destructive
## investments, not unique-entity loss).
## ADR: docs/architecture/adr-0011-ui-dual-focus-handling.md (focus/hover),
##      docs/architecture/adr-0024-defense-building-tech-tree-data-model.md (data side)
##
## Scope, honestly bounded: the GDD's own tech-tree view specifies a literal
## branching-graph layout with edge-following directional traversal — no
## graph-layout/node-position art exists anywhere in this project. This
## screen implements the tech tree as a flat list ordered by
## (tech_category, branch_tier) instead, which preserves the real
## prerequisite-chain semantics (a node's prerequisite is always listed
## before it) without the graph's visual/traversal complexity. Shoulder-
## button view-switch (GDD) is implemented as an explicit button instead
## (matches menagerie_screen.gd's own precedent of explicit buttons over
## exact gamepad-context fidelity). Re-skin around real graph art once it
## exists; the underlying eligibility/cost/confirm logic here should not
## need to change.
##
## Root is a plain Control. No class_name — matches inventory_screen.gd/
## menagerie_screen.gd's TD-workflow-001 precedent.

const FOCUS_RING_COLOR: Color = Color(1.0, 0.85, 0.2, 1.0)  ## placeholder — art-director TBD

## Human-readable labels for the two real tech_category / structure_type
## values in assets/data/defense_building/ (verified via grep, not guessed —
## no third value exists in authored content). The GDD never names individual
## tech/structure nodes beyond their snake_case ids (design/gdd/
## defense-building.md's Tech Tree Content table has no "display name"
## column), so this derives a title from the two fields the GDD DOES define
## (category/type + tier) rather than inventing flavor names with no design
## backing. Falls back to .capitalize() on the raw string for any future
## category/type this map doesn't yet cover, so new content never regresses
## to a raw snake_case id even if this list isn't updated alongside it.
const TECH_CATEGORY_LABELS: Dictionary[String, String] = {
	"production_tech": "Production",
	"structural_tech": "Structural",
}
const STRUCTURE_TYPE_LABELS: Dictionary[String, String] = {
	"habitat_expansion": "Habitat Expansion",
	"watchtower": "Watchtower",
}
const ROMAN_NUMERALS: Array[String] = ["", "I", "II", "III", "IV", "V"]

## Injectable for tests; defaults to the real GDefenseBuilding Autoload.
@export var defense_building: DefenseBuilding

@onready var _input_mode_tracker: InputModeTracker = $InputModeTracker
@onready var _view_switch_button: Button = $MainLayout/HeaderRow/ViewSwitchButton
@onready var _tech_list: VBoxContainer = $MainLayout/TechTreeView/TechList
@onready var _structure_list: VBoxContainer = $MainLayout/StructureBuildView/StructureList
@onready var _tech_tree_view: Control = $MainLayout/TechTreeView
@onready var _structure_build_view: Control = $MainLayout/StructureBuildView

var _tech_buttons: Dictionary[StringName, Button] = {}
var _structure_buttons: Dictionary[StringName, Button] = {}
var _showing_tech_tree: bool = true


func _ready() -> void:
	if defense_building == null:
		defense_building = GDefenseBuilding

	_view_switch_button.pressed.connect(_on_view_switch_pressed)
	_input_mode_tracker.input_mode_changed.connect(_on_input_mode_changed)

	GEventBus.tech_unlocked.connect(_on_ledger_changed)
	GEventBus.sanctuary_structure_built.connect(_on_ledger_changed)

	_rebuild_tech_list()
	_rebuild_structure_list()
	_apply_view_visibility()


func disconnect_own_subscriptions() -> void:
	GEventBus.tech_unlocked.disconnect(_on_ledger_changed)
	GEventBus.sanctuary_structure_built.disconnect(_on_ledger_changed)


func _on_ledger_changed(_a: Variant = null, _b: Variant = null) -> void:
	_rebuild_tech_list()
	_rebuild_structure_list()


# ---------------------------------------------------------------------------
# View switch
# ---------------------------------------------------------------------------

func _on_view_switch_pressed() -> void:
	_showing_tech_tree = not _showing_tech_tree
	_apply_view_visibility()


func _apply_view_visibility() -> void:
	_tech_tree_view.visible = _showing_tech_tree
	_structure_build_view.visible = not _showing_tech_tree


func is_showing_tech_tree() -> bool:
	return _showing_tech_tree


# ---------------------------------------------------------------------------
# Tech tree view — flat list, ordered (tech_category, branch_tier) so a
# prerequisite always appears before its dependent (see class doc comment).
# ---------------------------------------------------------------------------

func _rebuild_tech_list() -> void:
	for child: Node in _tech_list.get_children():
		child.queue_free()
	_tech_buttons.clear()

	var all_tech: Dictionary[StringName, TechNodeResource] = GGameDataRegistry.get_all_tech_nodes()
	var tech_ids: Array = all_tech.keys()
	tech_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var node_a: TechNodeResource = all_tech[a]
		var node_b: TechNodeResource = all_tech[b]
		if node_a.tech_category != node_b.tech_category:
			return node_a.tech_category < node_b.tech_category
		return node_a.branch_tier < node_b.branch_tier
	)

	for tech_id: StringName in tech_ids:
		var node: TechNodeResource = all_tech[tech_id]
		var button: Button = _create_tech_button(node)
		_tech_list.add_child(button)
		_tech_buttons[tech_id] = button


func _create_tech_button(node: TechNodeResource) -> Button:
	var button := Button.new()
	button.name = "Tech_%s" % String(node.tech_id)
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = true
	button.text = _tech_entry_text(node)
	button.pressed.connect(_on_tech_pressed.bind(node.tech_id))
	_wire_focus_ring(button)
	return button


## "Production II", "Structural I" — see TECH_CATEGORY_LABELS' own doc
## comment for why this is derived from data fields, not a per-id name.
func _tech_display_name(node: TechNodeResource) -> String:
	var category_label: String = TECH_CATEGORY_LABELS.get(node.tech_category, node.tech_category.capitalize())
	var tier_label: String = ROMAN_NUMERALS[node.branch_tier] if node.branch_tier < ROMAN_NUMERALS.size() else str(node.branch_tier)
	return "%s %s" % [category_label, tier_label]


## GDD UI Requirements: cost + prerequisite-eligibility state, non-color
## affordability backup (text tag here, pending real iconography).
func _tech_entry_text(node: TechNodeResource) -> String:
	var state_tag: String
	if defense_building.is_tech_unlocked(node.tech_id):
		state_tag = tr("DEFENSE_TECH_STATE_UNLOCKED")
	elif defense_building.can_unlock_tech(node.tech_id):
		state_tag = tr("DEFENSE_TECH_STATE_AVAILABLE")
	else:
		state_tag = tr("DEFENSE_TECH_STATE_LOCKED")
	# Localized player-facing tags (2026-10-04 smoke check) -- previously raw
	# enum-style "LOCKED_PREREQ" / "gold:90" debug text.
	return tr("DEFENSE_ENTRY_FORMAT") % [_tech_display_name(node), state_tag, node.gold_cost]


## GDD: "confirm on a locked/unaffordable target opens a context tooltip
## stating what's missing" rather than a silent no-op. resolve_tech_unlock()
## itself already safely no-ops on an ineligible target (zero side effects);
## this handler adds the explanatory surface on top for the rejection case.
func _on_tech_pressed(tech_id: StringName) -> void:
	var resolved: bool = defense_building.resolve_tech_unlock(tech_id)
	if not resolved:
		_show_rejection_tooltip(tech_id, true)


# ---------------------------------------------------------------------------
# Structure build view — flat list (GDD: "small, enumerable set", no graph)
# ---------------------------------------------------------------------------

func _rebuild_structure_list() -> void:
	for child: Node in _structure_list.get_children():
		child.queue_free()
	_structure_buttons.clear()

	var all_structures: Dictionary[StringName, StructureResource] = GGameDataRegistry.get_all_structures()
	var structure_ids: Array = all_structures.keys()
	structure_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var struct_a: StructureResource = all_structures[a]
		var struct_b: StructureResource = all_structures[b]
		if struct_a.structure_type != struct_b.structure_type:
			return struct_a.structure_type < struct_b.structure_type
		return struct_a.tier < struct_b.tier
	)

	for structure_id: StringName in structure_ids:
		var structure: StructureResource = all_structures[structure_id]
		var button: Button = _create_structure_button(structure)
		_structure_list.add_child(button)
		_structure_buttons[structure_id] = button


func _create_structure_button(structure: StructureResource) -> Button:
	var button := Button.new()
	button.name = "Structure_%s" % String(structure.structure_id)
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = true
	button.text = _structure_entry_text(structure)
	button.pressed.connect(_on_structure_pressed.bind(structure.structure_id))
	_wire_focus_ring(button)
	return button


## "Habitat Expansion II", "Watchtower I" — see TECH_CATEGORY_LABELS' own doc
## comment for why this is derived from data fields, not a per-id name.
func _structure_display_name(structure: StructureResource) -> String:
	var type_label: String = STRUCTURE_TYPE_LABELS.get(structure.structure_type, structure.structure_type.capitalize())
	var tier_label: String = ROMAN_NUMERALS[structure.tier] if structure.tier < ROMAN_NUMERALS.size() else str(structure.tier)
	return "%s %s" % [type_label, tier_label]


## GDD: built/unbuilt status glyph + tech-gate read-only reference so the
## player never has to alt-tab between views to see why a structure is locked.
func _structure_entry_text(structure: StructureResource) -> String:
	var status_tag: String = tr("DEFENSE_STRUCTURE_BUILT") if defense_building.is_structure_built(structure.structure_id) else tr("DEFENSE_STRUCTURE_UNBUILT")
	var gate_tag: String = ""
	if structure.tech_gate != &"":
		var gate_node: TechNodeResource = GGameDataRegistry.get_all_tech_nodes().get(structure.tech_gate)
		var gate_label: String = _tech_display_name(gate_node) if gate_node != null else String(structure.tech_gate)
		gate_tag = tr("DEFENSE_STRUCTURE_GATE") % gate_label
	return (tr("DEFENSE_ENTRY_FORMAT") % [_structure_display_name(structure), status_tag, structure.gold_cost]) + gate_tag


func _on_structure_pressed(structure_id: StringName) -> void:
	var resolved: bool = defense_building.resolve_structure_build(structure_id)
	if not resolved:
		_show_rejection_tooltip(structure_id, false)


# ---------------------------------------------------------------------------
# Shared rejection tooltip (Inventory/Crafting/Menagerie's established
## "confirm on non-actionable target explains why" pattern)
# ---------------------------------------------------------------------------

var _last_rejection_id: StringName = &""
var _last_rejection_was_tech: bool = false


func _show_rejection_tooltip(id: StringName, is_tech: bool) -> void:
	_last_rejection_id = id
	_last_rejection_was_tech = is_tech


func get_last_rejection_id() -> StringName:
	return _last_rejection_id


# ---------------------------------------------------------------------------
# Focus ring (ADR-0011, matches inventory_screen.gd/menagerie_screen.gd)
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
	for tech_id: StringName in _tech_buttons.keys():
		var button: Button = _tech_buttons[tech_id]
		var ring: Panel = button.get_node_or_null("FocusRing") as Panel
		if ring != null:
			ring.visible = button.has_focus() and _input_mode_tracker.is_focus_ring_visible()
	for structure_id: StringName in _structure_buttons.keys():
		var button: Button = _structure_buttons[structure_id]
		var ring: Panel = button.get_node_or_null("FocusRing") as Panel
		if ring != null:
			ring.visible = button.has_focus() and _input_mode_tracker.is_focus_ring_visible()


# ---------------------------------------------------------------------------
# Test/inspection accessors
# ---------------------------------------------------------------------------

func get_tech_button(tech_id: StringName) -> Button:
	return _tech_buttons.get(tech_id)


func get_structure_button(structure_id: StringName) -> Button:
	return _structure_buttons.get(structure_id)
