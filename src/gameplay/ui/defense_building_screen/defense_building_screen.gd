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

const FOCUS_RING_COLOR: Color = FocusRingFactory.FOCUS_RING_COLOR  ## HD-2D skin gold

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
## Values are strings.csv keys (2026-10-11 localization pass).
const TECH_CATEGORY_LABELS: Dictionary[String, String] = {
	"production_tech": "DEFENSE_CATEGORY_PRODUCTION",
	"structural_tech": "DEFENSE_CATEGORY_STRUCTURAL",
}
const STRUCTURE_TYPE_LABELS: Dictionary[String, String] = {
	"habitat_expansion": "DEFENSE_STRUCTURE_HABITAT_EXPANSION",
	"watchtower": "DEFENSE_STRUCTURE_WATCHTOWER",
}
const ROMAN_NUMERALS: Array[String] = ["", "I", "II", "III", "IV", "V"]

## Injectable for tests; defaults to the real GDefenseBuilding Autoload.
@export var defense_building: DefenseBuilding

@onready var _input_mode_tracker: InputModeTracker = $InputModeTracker
@onready var _view_title: Label = $MainLayout/HeaderRow/ViewTitle
@onready var _view_switch_button: Button = $MainLayout/HeaderRow/ViewSwitchButton
@onready var _tech_list: HBoxContainer = $MainLayout/TechTreeView/TechList
@onready var _structure_list: HBoxContainer = $MainLayout/StructureBuildView/StructureList
@onready var _tech_tree_view: PanelContainer = $MainLayout/TechTreeView
@onready var _structure_build_view: PanelContainer = $MainLayout/StructureBuildView

## 2026-10-10 UI pass: one column per tech_category / structure_type, each
## tier a tall card, instead of one thin full-width row per node (which left
## ~70% of the room empty). Top-to-bottom order within a column is still the
## prerequisite chain, so the flat-list semantics above are unchanged.
const LOCKED_CARD_ALPHA: float = 0.55
const CARD_MIN_HEIGHT: float = 104.0
const CONNECTOR_HEIGHT: float = 18.0
const GOLD_COIN_TEXTURE: Texture2D = preload("res://assets/art/ui/gold_coin.png")

## Card state, shared by tech and structure cards (see _compose_card()).
enum CardState { DONE, AVAILABLE, LOCKED }

var _tech_buttons: Dictionary[StringName, Button] = {}
var _structure_buttons: Dictionary[StringName, Button] = {}
var _showing_tech_tree: bool = true


func _ready() -> void:
	if defense_building == null:
		defense_building = GDefenseBuilding

	_view_switch_button.pressed.connect(_on_view_switch_pressed)
	_view_switch_button.tooltip_text = tr("DEFENSE_BUILDING_SWITCH_VIEW")
	_view_switch_button.add_theme_stylebox_override("normal", ShellChromeStyle.skin_button_for(false))
	_view_title.theme_type_variation = &"TitleLabel"
	for view: PanelContainer in [_tech_tree_view, _structure_build_view]:
		var box: StyleBoxFlat = ShellChromeStyle.chrome_panel_stylebox()
		box.bg_color = ShellChromeStyle.UI_CHROME.darkened(0.25)
		box.set_content_margin_all(16.0)
		view.add_theme_stylebox_override("panel", box)
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
	# Title names the current view; the switch button names the other one.
	_view_title.text = tr("DEFENSE_VIEW_TECH_TREE") if _showing_tech_tree else tr("DEFENSE_VIEW_STRUCTURES")
	_view_switch_button.text = tr("DEFENSE_VIEW_STRUCTURES") if _showing_tech_tree else tr("DEFENSE_VIEW_TECH_TREE")


func is_showing_tech_tree() -> bool:
	return _showing_tech_tree


# ---------------------------------------------------------------------------
# Tech tree view — flat list, ordered (tech_category, branch_tier) so a
# prerequisite always appears before its dependent (see class doc comment).
# ---------------------------------------------------------------------------

func _rebuild_tech_list() -> void:
	for child: Node in _tech_list.get_children():
		_tech_list.remove_child(child)
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

	var columns: Dictionary[String, VBoxContainer] = {}
	for tech_id: StringName in tech_ids:
		var node: TechNodeResource = all_tech[tech_id]
		if not columns.has(node.tech_category):
			columns[node.tech_category] = _create_column(_tech_list, _tech_category_label(node.tech_category))
		var button: Button = _create_tech_button(node)
		_add_card(columns[node.tech_category], button)
		_tech_buttons[tech_id] = button


func _create_tech_button(node: TechNodeResource) -> Button:
	var button := Button.new()
	button.name = "Tech_%s" % String(node.tech_id)
	button.focus_mode = Control.FOCUS_ALL
	# The full sentence ("Production II · Available · 90 gold") is the card's
	# accessible name; the card itself shows the same facts laid out visually.
	button.accessibility_name = _tech_entry_text(node)
	var state: CardState
	if defense_building.is_tech_unlocked(node.tech_id):
		state = CardState.DONE
	elif defense_building.can_unlock_tech(node.tech_id):
		state = CardState.AVAILABLE
	else:
		state = CardState.LOCKED
	var detail: String = _tech_unlocks_text(node.tech_id)
	if state == CardState.LOCKED and node.prerequisite_tech_id != &"":
		var prerequisite: TechNodeResource = GGameDataRegistry.get_all_tech_nodes().get(node.prerequisite_tech_id)
		if prerequisite != null:
			detail = tr("DEFENSE_CARD_REQUIRES") % _tech_display_name(prerequisite)
	_compose_card(button, _tech_display_name(node), state, tr("DEFENSE_PILL_RESEARCHED"), detail, node.gold_cost, node.material_costs)
	button.pressed.connect(_on_tech_pressed.bind(node.tech_id))
	_wire_focus_ring(button)
	return button


## What researching this node actually opens, from live data: structures whose
## tech_gate is this node, then recipes (crafting + equipment) whose
## tech_prerequisite is. TechNodeResource.gates is documentation-only, so it is
## deliberately not read here.
func _tech_unlocks_text(tech_id: StringName) -> String:
	var parts: PackedStringArray = []
	for structure: StructureResource in GGameDataRegistry.get_all_structures().values():
		if structure.tech_gate == tech_id:
			parts.append(_structure_display_name(structure))
	var recipe_count: int = 0
	for recipe: Variant in GGameDataRegistry.get_all_recipes().values() + GGameDataRegistry.get_all_equipment_recipes().values():
		if recipe != null and recipe.get(&"tech_prerequisite") == tech_id:
			recipe_count += 1
	if recipe_count > 0:
		parts.append(tr("DEFENSE_CARD_RECIPE_COUNT") % recipe_count)
	return "" if parts.is_empty() else tr("DEFENSE_CARD_UNLOCKS") % ", ".join(parts)


## "Production II", "Structural I" — see TECH_CATEGORY_LABELS' own doc
## comment for why this is derived from data fields, not a per-id name.
func _tech_category_label(category: String) -> String:
	return tr(TECH_CATEGORY_LABELS[category]) if TECH_CATEGORY_LABELS.has(category) else category.capitalize()


func _structure_type_label(structure_type: String) -> String:
	return tr(STRUCTURE_TYPE_LABELS[structure_type]) if STRUCTURE_TYPE_LABELS.has(structure_type) else structure_type.capitalize()


func _tech_display_name(node: TechNodeResource) -> String:
	var category_label: String = _tech_category_label(node.tech_category)
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
		_structure_list.remove_child(child)
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

	var columns: Dictionary[String, VBoxContainer] = {}
	for structure_id: StringName in structure_ids:
		var structure: StructureResource = all_structures[structure_id]
		if not columns.has(structure.structure_type):
			columns[structure.structure_type] = _create_column(_structure_list, _structure_type_label(structure.structure_type))
		var button: Button = _create_structure_button(structure)
		_add_card(columns[structure.structure_type], button)
		_structure_buttons[structure_id] = button


func _create_structure_button(structure: StructureResource) -> Button:
	var button := Button.new()
	button.name = "Structure_%s" % String(structure.structure_id)
	button.focus_mode = Control.FOCUS_ALL
	button.accessibility_name = _structure_entry_text(structure)
	var built: bool = defense_building.is_structure_built(structure.structure_id)
	var gate_open: bool = structure.tech_gate == &"" or defense_building.is_tech_unlocked(structure.tech_gate)
	var state: CardState = CardState.DONE if built else (CardState.AVAILABLE if gate_open else CardState.LOCKED)
	var detail: String = ""
	if not gate_open:
		var gate_node: TechNodeResource = GGameDataRegistry.get_all_tech_nodes().get(structure.tech_gate)
		detail = tr("DEFENSE_CARD_REQUIRES") % (_tech_display_name(gate_node) if gate_node != null else String(structure.tech_gate))
	_compose_card(button, _structure_display_name(structure), state, tr("DEFENSE_STRUCTURE_BUILT"), detail, structure.gold_cost, structure.material_costs)
	button.pressed.connect(_on_structure_pressed.bind(structure.structure_id))
	_wire_focus_ring(button)
	return button


## "Habitat Expansion II", "Watchtower I" — see TECH_CATEGORY_LABELS' own doc
## comment for why this is derived from data fields, not a per-id name.
func _structure_display_name(structure: StructureResource) -> String:
	var type_label: String = _structure_type_label(structure.structure_type)
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
# Card layout (2026-10-10 UI pass)
# ---------------------------------------------------------------------------

## One expanding column: a Cinzel header over a gold rule; tier cards below,
## joined by connectors (see _add_card()).
func _create_column(parent: HBoxContainer, title: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 0)
	var header := Label.new()
	header.text = title
	header.theme_type_variation = &"HeaderLabel"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 22)
	column.add_child(header)
	var rule := TextureRect.new()
	rule.texture = load(ShellChromeStyle.SKIN_DIR + "divider.png") as Texture2D
	rule.stretch_mode = TextureRect.STRETCH_SCALE
	rule.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rule.custom_minimum_size = Vector2(0, 6)
	column.add_child(rule)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	column.add_child(gap)
	parent.add_child(column)
	return column


## Appends a card to its column. Every card after the first gets a connector
## above it -- the prerequisite chain drawn as a line -- lit gold when the tier
## above is done, dim when the chain is still closed there.
func _add_card(column: VBoxContainer, button: Button) -> void:
	# has_meta() first: get_meta() with a null default still errors on a missing key.
	if column.has_meta(&"last_card"):
		var previous: Button = column.get_meta(&"last_card") as Button
		column.add_child(_make_connector(previous.get_meta(&"card_state") == CardState.DONE))
	column.add_child(button)
	column.set_meta(&"last_card", button)


func _make_connector(lit: bool) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0, CONNECTOR_HEIGHT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(4, CONNECTOR_HEIGHT)
	line.color = ShellChromeStyle.UI_ACCENT if lit else Color(ShellChromeStyle.UI_RULE, 0.6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(line)
	return holder


## Builds a tier card inside `button` (text stays empty; accessibility_name
## carries the full sentence):
##   [state pill]                  e.g. RESEARCHED / AVAILABLE / LOCKED + padlock
##   Title (Cinzel)                e.g. "Structural II"
##   detail line                   "Unlocks ..." or "Requires ..."
##   cost row                      gold coin + materials, hidden once done
## Done = amber skin frame; available = normal frame, gold title, slow glow
## pulse; locked = disabled frame, dimmed. Frame + pill wording are the
## non-color state signals.
func _compose_card(button: Button, title: String, state: CardState, done_label: String, detail: String, gold_cost: int, material_costs: Dictionary) -> void:
	button.set_meta(&"card_state", state)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, CARD_MIN_HEIGHT)
	var frame: StringName = &"active" if state == CardState.DONE else (&"normal" if state == CardState.AVAILABLE else &"disabled")
	for style_state: String in ["normal", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(style_state, ShellChromeStyle.skin_button(frame))
	button.add_theme_stylebox_override("hover", ShellChromeStyle.skin_button(&"active" if state == CardState.DONE else &"hover"))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	button.add_child(margin)
	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 4)
	margin.add_child(body)
	if state == CardState.LOCKED:
		body.modulate.a = LOCKED_CARD_ALPHA

	var pill_row := HBoxContainer.new()
	pill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_row.add_theme_constant_override("separation", 6)
	body.add_child(pill_row)
	if state == CardState.LOCKED:
		var lock := PixelLockGlyph.new()
		lock.custom_minimum_size = Vector2(10, 12)
		lock.color = ShellChromeStyle.UI_PARCHMENT
		pill_row.add_child(lock)
	var pill := Label.new()
	pill.name = &"StatePill"
	pill.uppercase = true
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_font_size_override("font_size", 13)
	match state:
		CardState.DONE:
			pill.text = done_label
			pill.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
		CardState.AVAILABLE:
			pill.text = tr("DEFENSE_PILL_AVAILABLE")
			pill.add_theme_color_override("font_color", ShellChromeStyle.UI_ACCENT)
		CardState.LOCKED:
			pill.text = tr("DEFENSE_PILL_LOCKED")
			pill.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
	pill_row.add_child(pill)

	var title_label := Label.new()
	title_label.name = &"Title"
	title_label.text = title
	title_label.theme_type_variation = &"HeaderLabel"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", ShellChromeStyle.UI_ACCENT if state == CardState.AVAILABLE else ShellChromeStyle.UI_PARCHMENT)
	body.add_child(title_label)

	if not detail.is_empty():
		var detail_label := Label.new()
		detail_label.name = &"Detail"
		detail_label.text = detail
		detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_label.add_theme_font_size_override("font_size", 15)
		detail_label.add_theme_color_override("font_color", Color(ShellChromeStyle.UI_PARCHMENT, 0.75))
		body.add_child(detail_label)

	if state != CardState.DONE:
		body.add_child(_build_cost_row(gold_cost, material_costs))

	if state == CardState.AVAILABLE and not ReduceMotion.enabled():
		var pulse: Tween = button.create_tween().set_loops()
		pulse.tween_property(button, "self_modulate", Color(1.18, 1.12, 0.95), 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(button, "self_modulate", Color.WHITE, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Gold coin + amount, then one icon + count per material.
func _build_cost_row(gold_cost: int, material_costs: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = &"CostRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	if gold_cost > 0:
		row.add_child(_cost_icon(GOLD_COIN_TEXTURE))
		row.add_child(_cost_label(str(gold_cost), ShellChromeStyle.UI_ACCENT))
	for material_id: Variant in material_costs:
		var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(material_id))
		if definition != null and definition.icon != null:
			row.add_child(_cost_icon(definition.icon))
			row.add_child(_cost_label(str(material_costs[material_id]), ShellChromeStyle.UI_PARCHMENT))
		else:
			var material_name: String = definition.display_name if definition != null else String(material_id)
			row.add_child(_cost_label("%s %d" % [material_name, material_costs[material_id]], ShellChromeStyle.UI_PARCHMENT))
	return row


static func _cost_icon(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


static func _cost_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	return label


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
