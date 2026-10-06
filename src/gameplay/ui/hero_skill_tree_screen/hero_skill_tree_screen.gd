extends Control

## Hero Skill Tree Spend Screen (new 2026-09-01, Claude Code).
##
## GDD source: design/gdd/hero-skill-tree.md — the tree's own Visual/UI
## treatment is explicitly deferred (OQ-3: "node layout, connector art,
## locked/unlocked states... covered by a separate art-generation delegation
## plan"). This implementation is the SAME honestly-scoped answer this
## session already gave hero_skill_build_screen.gd: a plain, functional
## column/grid layout with letter-badge archetype accents (see that
## screen's own doc comment for the full "no bespoke art invented"
## rationale) — not the bespoke node-layout/connector-art OQ-3 describes,
## which remains genuinely separate, unscoped art-direction work.
##
## **Wired into Sanctuary UI's live room-hosting shell, same session
## (2026-09-01).** The gap this comment originally flagged — `sanctuary_ui.gd`'s
## `ROOM_SCENES` had no `ROOM_HERO_SKILLS` entry, and no tab-strip 7th entry
## or LB/RB bumper toggle existed anywhere in code, despite `sanctuary-ui.md`
## Core Rule 11 describing it as "Approved" — is now closed: see
## `src/gameplay/ui/hero_skills_room/hero_skills_room.gd` (the new composite
## room hosting this screen alongside hero_skill_build_screen.gd) and
## `tab_strip.gd`'s Skills entry. Live-verified end-to-end via Godot MCP,
## including a regression check of the other 4 pre-existing rooms.
##
## Scope, honestly bounded:
## - Choice-node candidate selection uses an inline expand-in-place panel
##   (press the purchasable Choice node -> its 2-3 candidates appear as a
##   selectable list directly below it -> press one to confirm, or press
##   the node again to collapse without purchasing) rather than the GDD's
##   fuller "spend screen" wording, which doesn't specify UI mechanics.
##   Mirrors hero_skill_build_screen.gd's own "simplify to a single-action
##   model where the data layer has no pick-up/place primitive to bind a
##   2-step flow to" precedent.
## - LOCKED_OUT siblings (Edge Cases: the unchosen options of an already-
##   resolved Choice node) are surfaced as a small "(locked out: X, Y)" text
##   line under an already-purchased node, not a distinct visual treatment —
##   informative, not a separate interaction surface.
##
## Root is a plain Control. No class_name — matches the other room/screen
## scripts' TD-workflow-001 precedent.

const NODE_LABELS: Array[String] = ["Minor", "Choice I", "Choice II", "Choice III"]
const NODE_TIER_LABELS: Dictionary[int, String] = {1: "Opener", 2: "Core", 3: "Capstone"}

## Injectable for tests; defaults to the real GHeroSkillTree Autoload.
@export var hero_skill_tree: HeroSkillTree

@onready var _input_mode_tracker: InputModeTracker = $InputModeTracker
@onready var _pool_row: HBoxContainer = $MainLayout/PoolRow
@onready var _visit_spend_label: Label = $MainLayout/VisitSpendLabel
@onready var _chains_row: HBoxContainer = $MainLayout/ChainsRow

## archetype -> the 4 VBoxContainer columns, each holding that chain's node buttons.
var _chain_columns: Dictionary[String, VBoxContainer] = {}
## "archetype:node_index" -> the node's own Button, for test/inspection access.
var _node_buttons: Dictionary[String, Button] = {}
## Which Choice node (if any) currently has its candidate-selection panel
## expanded. Empty string = none expanded. Format "archetype:node_index".
var _expanded_choice_key: String = ""


func _ready() -> void:
	if hero_skill_tree == null:
		hero_skill_tree = GHeroSkillTree
	_input_mode_tracker.input_mode_changed.connect(_on_input_mode_changed)
	GEventBus.skill_tree_point_earned.connect(_on_state_changed)
	GEventBus.skill_tree_overflow_point_earned.connect(_on_state_changed)
	GEventBus.skill_tree_node_unlocked.connect(_on_state_changed)
	GEventBus.skill_unlocked.connect(_on_state_changed)
	_rebuild_everything()


func disconnect_own_subscriptions() -> void:
	GEventBus.skill_tree_point_earned.disconnect(_on_state_changed)
	GEventBus.skill_tree_overflow_point_earned.disconnect(_on_state_changed)
	GEventBus.skill_tree_node_unlocked.disconnect(_on_state_changed)
	GEventBus.skill_unlocked.disconnect(_on_state_changed)


func _on_state_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_rebuild_everything()


func _rebuild_everything() -> void:
	_rebuild_pool_row()
	_rebuild_visit_spend_label()
	_rebuild_chains()


# ---------------------------------------------------------------------------
# Pool summary
# ---------------------------------------------------------------------------

func _rebuild_pool_row() -> void:
	for child: Node in _pool_row.get_children():
		child.queue_free()
	if hero_skill_tree == null:
		return
	for archetype: String in HeroSkillTree.ARCHETYPES:
		_pool_row.add_child(_make_pool_label(archetype, hero_skill_tree.skill_tree_points.get(archetype, 0)))
	_pool_row.add_child(_make_pool_label("", hero_skill_tree.overflow_points, "Overflow"))


func _make_pool_label(category: String, count: int, override_text: String = "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	if not category.is_empty():
		row.add_child(_make_glyph_badge(category, 18))
	var label := Label.new()
	label.text = "%s: %d" % [override_text if not override_text.is_empty() else category.capitalize(), count]
	row.add_child(label)
	return row


func _rebuild_visit_spend_label() -> void:
	if hero_skill_tree == null:
		_visit_spend_label.text = ""
		return
	_visit_spend_label.text = tr(&"SKILL_TREE_VISIT_AVAILABLE") if hero_skill_tree.visit_spend_count == 0 else tr(&"SKILL_TREE_VISIT_SPENT")


# ---------------------------------------------------------------------------
# Chains
# ---------------------------------------------------------------------------

func _rebuild_chains() -> void:
	for child: Node in _chains_row.get_children():
		child.queue_free()
	_chain_columns.clear()
	_node_buttons.clear()

	if hero_skill_tree == null:
		return

	for archetype: String in HeroSkillTree.ARCHETYPES:
		var column := VBoxContainer.new()
		column.name = "Chain_%s" % archetype
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var header := HBoxContainer.new()
		header.add_child(_make_glyph_badge(archetype, 20))
		var header_label := Label.new()
		header_label.text = archetype.capitalize()
		header.add_child(header_label)
		column.add_child(header)

		for node_index: int in HeroSkillTree.NODES_PER_CHAIN:
			column.add_child(_build_node_row(archetype, node_index))

		_chains_row.add_child(column)
		_chain_columns[archetype] = column


func _build_node_row(archetype: String, node_index: int) -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.name = "NodeRow_%d" % node_index

	var node_state: Dictionary = hero_skill_tree.get_node_state(archetype, node_index)
	var unlocked: bool = node_state.get("unlocked", false) as bool
	var is_choice: bool = HeroSkillTree.TIER_FOR_CHOICE_NODE.has(node_index)
	var purchasable: bool = hero_skill_tree.is_node_purchasable(archetype, node_index)

	var button := Button.new()
	button.name = "Node_%s_%d" % [archetype, node_index]
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = true
	button.custom_minimum_size.y = 36.0
	button.text = _node_button_text(archetype, node_index, node_state, unlocked, is_choice)
	button.disabled = not (purchasable or (is_choice and _expanded_choice_key == "%s:%d" % [archetype, node_index]))
	_style_node_button(button, unlocked, purchasable)
	button.pressed.connect(_on_node_pressed.bind(archetype, node_index))
	wrapper.add_child(button)
	_node_buttons["%s:%d" % [archetype, node_index]] = button

	if unlocked and is_choice:
		var locked_out: Array[String] = hero_skill_tree.get_locked_out_skill_ids(archetype, node_index)
		if not locked_out.is_empty():
			var names: Array[String] = []
			for skill_id: String in locked_out:
				names.append(_skill_label(skill_id))
			var locked_out_label := Label.new()
			locked_out_label.text = "(locked out: %s)" % ", ".join(names)
			locked_out_label.add_theme_font_size_override("font_size", 11)
			wrapper.add_child(locked_out_label)

	if is_choice and purchasable and _expanded_choice_key == "%s:%d" % [archetype, node_index]:
		wrapper.add_child(_build_choice_candidates_panel(archetype, node_index))

	return wrapper


func _node_button_text(archetype: String, node_index: int, node_state: Dictionary, unlocked: bool, is_choice: bool) -> String:
	if not is_choice:
		return "%s %s" % [NODE_LABELS[node_index], "[UNLOCKED]" if unlocked else "[LOCKED]"]
	if unlocked:
		var chosen: String = node_state.get("chosen_skill_id", "") as String
		return "%s: %s" % [NODE_LABELS[node_index], _skill_label(chosen)]
	var tier_label: String = NODE_TIER_LABELS.get(node_index, "")
	return "%s (%s) [LOCKED]" % [NODE_LABELS[node_index], tier_label]


func _style_node_button(button: Button, unlocked: bool, purchasable: bool) -> void:
	var style := StyleBoxFlat.new()
	if unlocked:
		style.bg_color = Color(0.15, 0.35, 0.15, 0.6)
		style.border_color = Color(0.4, 0.8, 0.4)
	elif purchasable:
		style.bg_color = Color(0.25, 0.22, 0.1, 0.6)
		style.border_color = Color(0.85, 0.7, 0.25)
	else:
		style.bg_color = Color(0.15, 0.15, 0.15, 0.6)
		style.border_color = Color(0.4, 0.4, 0.4)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	button.add_theme_stylebox_override("normal", style)


## Minor node: purchase directly. Choice node: toggle the inline candidate
## panel open/closed (purchase happens from _on_candidate_pressed() instead).
func _on_node_pressed(archetype: String, node_index: int) -> void:
	if hero_skill_tree == null:
		return
	if not hero_skill_tree.is_node_purchasable(archetype, node_index):
		return
	var is_choice: bool = HeroSkillTree.TIER_FOR_CHOICE_NODE.has(node_index)
	if not is_choice:
		hero_skill_tree.purchase_node(archetype, node_index)
		return
	var key: String = "%s:%d" % [archetype, node_index]
	_expanded_choice_key = "" if _expanded_choice_key == key else key
	_rebuild_chains()


func _build_choice_candidates_panel(archetype: String, node_index: int) -> Control:
	var panel := VBoxContainer.new()
	panel.name = "CandidatesPanel"
	for skill_id: String in hero_skill_tree.get_tier_skill_ids(archetype, node_index):
		var candidate_button := Button.new()
		candidate_button.text = _candidate_text(skill_id)
		candidate_button.focus_mode = Control.FOCUS_ALL
		candidate_button.pressed.connect(_on_candidate_pressed.bind(archetype, node_index, skill_id))
		panel.add_child(candidate_button)
	return panel


## Skill effect UI (2026-10-07): the choice shows the skill name and, on a
## second line, its secondary effect, so the player sees what they're picking.
func _candidate_text(skill_id: String) -> String:
	var skill: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(StringName(skill_id))
	var effect: String = SkillEffectText.describe_effect(skill.effect_data) if skill != null else ""
	return _skill_label(skill_id) if effect.is_empty() else "%s
%s" % [_skill_label(skill_id), effect]


func _on_candidate_pressed(archetype: String, node_index: int, skill_id: String) -> void:
	if hero_skill_tree == null:
		return
	hero_skill_tree.purchase_node(archetype, node_index, skill_id)
	_expanded_choice_key = ""
	_rebuild_everything()


# ---------------------------------------------------------------------------
# Shared helpers (letter-glyph badges — see hero_skill_build_screen.gd's own
# doc comment for the "no bespoke art invented" rationale this mirrors)
# ---------------------------------------------------------------------------

const ARCHETYPE_GLYPHS: Dictionary[String, String] = {
	"physical": "P", "ranged": "R", "elemental": "E", "support": "S",
}


func _make_glyph_badge(category: String, size: int) -> Label:
	var badge := Label.new()
	badge.text = ARCHETYPE_GLYPHS.get(category, "?")
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(size, size)
	badge.add_theme_font_size_override("font_size", int(size * 0.65))
	var accent: Color = ProjectileVisual.ARCHETYPE_COLORS.get(category, Color(0.5, 0.5, 0.5))
	var style := StyleBoxFlat.new()
	style.bg_color = accent
	style.set_corner_radius_all(int(size * 0.2))
	badge.add_theme_color_override("font_color", Color.BLACK if accent.get_luminance() > 0.5 else Color.WHITE)
	badge.add_theme_stylebox_override("normal", style)
	return badge


func _skill_label(skill_id: String) -> String:
	if skill_id.is_empty():
		return skill_id
	var definition: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(StringName(skill_id))
	if definition == null or definition.display_name.is_empty():
		return skill_id
	return definition.display_name


func _on_input_mode_changed(_mode: InputModeTracker.InputMode) -> void:
	pass  # No focus-ring overlay on this screen yet — see class doc comment scope note.


# ---------------------------------------------------------------------------
# Test/inspection accessors
# ---------------------------------------------------------------------------

func get_node_button(archetype: String, node_index: int) -> Button:
	return _node_buttons.get("%s:%d" % [archetype, node_index])


func get_pool_row() -> HBoxContainer:
	return _pool_row


func get_visit_spend_label_text() -> String:
	return _visit_spend_label.text


func get_expanded_choice_key() -> String:
	return _expanded_choice_key
