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
##   resolved Choice node) are surfaced as a small locked-out line (SKILL_TREE_LOCKED_OUT, e.g. (locked out: X, Y))
##   line under an already-purchased node, not a distinct visual treatment —
##   informative, not a separate interaction surface.
##
## Root is a plain Control. No class_name — matches the other room/screen
## scripts' TD-workflow-001 precedent.

## strings.csv keys (localized 2026-10-07; previously hardcoded English).
const NODE_LABELS: Array[String] = ["SKILL_TREE_NODE_MINOR", "SKILL_TREE_NODE_CHOICE_1", "SKILL_TREE_NODE_CHOICE_2", "SKILL_TREE_NODE_CHOICE_3"]
const NODE_TIER_LABELS: Dictionary[int, String] = {1: "SKILL_TREE_TIER_OPENER", 2: "SKILL_TREE_TIER_CORE", 3: "SKILL_TREE_TIER_CAPSTONE"}

## Injectable for tests; defaults to the real GHeroSkillTree Autoload.
@export var hero_skill_tree: HeroSkillTree

@onready var _input_mode_tracker: InputModeTracker = $InputModeTracker
@onready var _pool_row: HBoxContainer = $MainLayout/PoolRow
@onready var _visit_spend_label: Label = $MainLayout/VisitSpendLabel
@onready var _chains_row: HBoxContainer = $MainLayout/TreeScroll/TreeLayout/ChainsRow
@onready var _bridges_header: Label = $MainLayout/TreeScroll/TreeLayout/BridgesHeader
@onready var _bridges_grid: GridContainer = $MainLayout/TreeScroll/TreeLayout/BridgesGrid

## Shared stat/effect formatting (that script has no class_name, so preload it).
const _InfoPanel = preload("res://src/gameplay/ui/inventory_screen/equipment_info_panel.gd")

## archetype -> the 4 VBoxContainer columns, each holding that chain's node buttons.
var _chain_columns: Dictionary[String, VBoxContainer] = {}
## "archetype:node_index" -> the node's own Button, for test/inspection access.
var _node_buttons: Dictionary[String, Button] = {}
## Which Choice node (if any) currently has its candidate-selection panel
## expanded. Empty string = none expanded. Format "archetype:node_index".
var _expanded_choice_key: String = ""
## "archetype:slot:side:depth" -> branch node Button (tests/inspection).
var _branch_buttons: Dictionary[String, Button] = {}
## "archetype:slot" -> Retrain Button.
var _retrain_buttons: Dictionary[String, Button] = {}
## bridge id -> its Button.
var _bridge_buttons: Dictionary[String, Button] = {}
## Owned bridge being swapped out ("" = not swapping).
var _bridge_swap_from: String = ""


func _ready() -> void:
	if hero_skill_tree == null:
		hero_skill_tree = GHeroSkillTree
	_input_mode_tracker.input_mode_changed.connect(_on_input_mode_changed)
	GEventBus.skill_tree_point_earned.connect(_on_state_changed)
	GEventBus.skill_tree_overflow_point_earned.connect(_on_state_changed)
	GEventBus.skill_tree_node_unlocked.connect(_on_state_changed)
	GEventBus.skill_unlocked.connect(_on_state_changed)
	GEventBus.skill_tree_branch_changed.connect(_on_state_changed)
	_rebuild_everything()


func disconnect_own_subscriptions() -> void:
	GEventBus.skill_tree_point_earned.disconnect(_on_state_changed)
	GEventBus.skill_tree_overflow_point_earned.disconnect(_on_state_changed)
	GEventBus.skill_tree_node_unlocked.disconnect(_on_state_changed)
	GEventBus.skill_unlocked.disconnect(_on_state_changed)
	GEventBus.skill_tree_branch_changed.disconnect(_on_state_changed)


func _on_state_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_rebuild_everything()


func _rebuild_everything() -> void:
	_rebuild_pool_row()
	_rebuild_visit_spend_label()
	_rebuild_chains()
	_rebuild_bridges()


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
	_pool_row.add_child(_make_pool_label("", hero_skill_tree.overflow_points, tr("SKILL_TREE_OVERFLOW")))


func _make_pool_label(category: String, count: int, override_text: String = "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	if not category.is_empty():
		row.add_child(_make_glyph_badge(category, 18))
	var label := Label.new()
	label.text = tr("SKILL_TREE_POOL") % [override_text if not override_text.is_empty() else _archetype_name(category), count]
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
	_branch_buttons.clear()
	_retrain_buttons.clear()

	if hero_skill_tree == null:
		return

	for archetype: String in HeroSkillTree.ARCHETYPES:
		var column := VBoxContainer.new()
		column.name = "Chain_%s" % archetype
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var header := HBoxContainer.new()
		header.add_child(_make_glyph_badge(archetype, 20))
		var header_label := Label.new()
		header_label.text = _archetype_name(archetype)
		header.add_child(header_label)
		column.add_child(header)

		for node_index: int in HeroSkillTree.NODES_PER_CHAIN:
			column.add_child(_build_node_row(archetype, node_index))
			for slot: String in HeroSkillTree.BRANCH_SLOTS:
				if HeroSkillTree.BRANCH_OPENED_BY[slot] == node_index:
					column.add_child(_build_branch_panel(archetype, slot))

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
	# Wrap instead of clip (2026-10-07): "Choice III (Capstone) [LOCKED]" was cut
	# off at the column edge; wrapping also covers longer translations and 150% UI scale.
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
			locked_out_label.text = tr("SKILL_TREE_LOCKED_OUT") % ", ".join(names)
			locked_out_label.add_theme_font_size_override("font_size", 11)
			wrapper.add_child(locked_out_label)

	if is_choice and purchasable and _expanded_choice_key == "%s:%d" % [archetype, node_index]:
		wrapper.add_child(_build_choice_candidates_panel(archetype, node_index))

	return wrapper


func _node_button_text(archetype: String, node_index: int, node_state: Dictionary, unlocked: bool, is_choice: bool) -> String:
	var node_name: String = tr(NODE_LABELS[node_index])
	if not is_choice:
		# Root (expansion spec: closes GDD Rule 14) shows its name and effect.
		var root: HeroTreeNodeResource = hero_skill_tree.get_root_node(archetype)
		if root != null:
			node_name = tr("SKILL_TREE_NODE_CHOSEN") % [node_name, root.display_name]
		var text: String = tr("SKILL_TREE_NODE_STATE") % [node_name, tr("SKILL_TREE_TAG_UNLOCKED") if unlocked else tr("SKILL_TREE_TAG_LOCKED")]
		return text if root == null else "%s\n%s" % [text, describe_tree_node(root)]
	if unlocked:
		var chosen: String = node_state.get("chosen_skill_id", "") as String
		return tr("SKILL_TREE_NODE_CHOSEN") % [node_name, _skill_label(chosen)]
	var tier_label: String = tr(NODE_TIER_LABELS.get(node_index, ""))
	return tr("SKILL_TREE_NODE_TIER_LOCKED") % [node_name, tier_label, tr("SKILL_TREE_TAG_LOCKED")]


## "physical" -> "Physical" via strings.csv (SKILL_TREE_ARCHETYPE_*).
func _archetype_name(archetype: String) -> String:
	return tr("SKILL_TREE_ARCHETYPE_%s" % archetype.to_upper())


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
	# Owned and unaffordable nodes are disabled; without this they lose the colour.
	button.add_theme_stylebox_override("disabled", style)


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
# Branches (hero-skill-tree-expansion spec §3, §6, §7.6): each slot sits under
# the spine node that opens it. Two side columns; the unchosen side stays
# readable but greyed. Retrain swaps the side at the same depth.
# ---------------------------------------------------------------------------

const SLOT_LABELS: Dictionary[String, String] = {
	"fork_1": "SKILL_TREE_SLOT_FORK_1", "fork_2": "SKILL_TREE_SLOT_FORK_2", "keystone": "SKILL_TREE_SLOT_KEYSTONE",
}
const COLOR_DIM: Color = Color(0.6, 0.6, 0.6)


func _build_branch_panel(archetype: String, slot: String) -> Control:
	var panel := VBoxContainer.new()
	panel.name = "Branch_%s" % slot
	var open: bool = hero_skill_tree.is_branch_open(archetype, slot)
	var header := Label.new()
	header.text = tr(SLOT_LABELS[slot]) if open else tr("SKILL_TREE_SLOT_OPENS") % [tr(SLOT_LABELS[slot]),
		tr(NODE_LABELS[HeroSkillTree.BRANCH_OPENED_BY[slot]])]
	header.add_theme_font_size_override("font_size", 12)
	panel.add_child(header)

	var state: Dictionary = hero_skill_tree.get_branch_state(archetype, slot)
	var sides_row := HBoxContainer.new()
	sides_row.add_theme_constant_override("separation", 4)
	for side: String in HeroSkillTree.get_slot_sides(slot):
		var side_column := VBoxContainer.new()
		side_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for depth: int in HeroSkillTree.get_slot_depth(slot):
			side_column.add_child(_build_branch_button(archetype, slot, side, depth, state))
		sides_row.add_child(side_column)
	panel.add_child(sides_row)

	if int(state["depth"]) > 0:
		var retrain := Button.new()
		retrain.name = "Retrain_%s_%s" % [archetype, slot]
		retrain.text = tr("SKILL_TREE_RETRAIN")
		retrain.add_theme_font_size_override("font_size", 11)
		retrain.disabled = not hero_skill_tree.can_retrain(archetype, slot)
		retrain.pressed.connect(_on_retrain_pressed.bind(archetype, slot))
		panel.add_child(retrain)
		_retrain_buttons["%s:%s" % [archetype, slot]] = retrain
	return panel


func _build_branch_button(archetype: String, slot: String, side: String, depth: int, state: Dictionary) -> Button:
	var node: HeroTreeNodeResource = hero_skill_tree.get_branch_node(archetype, slot, side, depth)
	var chosen_side: String = state["side"]
	var owned: bool = chosen_side == side and depth < int(state["depth"])
	var other_side: bool = not chosen_side.is_empty() and chosen_side != side
	var next: bool = (chosen_side.is_empty() or chosen_side == side) and depth == int(state["depth"])
	var purchasable: bool = next and hero_skill_tree.is_branch_purchasable(archetype, slot, side)
	var button := _make_tree_button(node, owned, purchasable, tr("SKILL_TREE_TAG_OTHER_SIDE") if other_side else "")
	button.name = "Branch_%s_%s_%s%d" % [archetype, slot, side, depth]
	button.pressed.connect(_on_branch_pressed.bind(archetype, slot, side))
	_branch_buttons["%s:%s:%s:%d" % [archetype, slot, side, depth]] = button
	return button


## A wrapped node button: "<name> [TAG]" then the effect lines. Not owned and
## not purchasable = disabled but still readable (spec §7.6).
func _make_tree_button(node: HeroTreeNodeResource, owned: bool, purchasable: bool, extra_tag: String) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 11)
	var tag: String = extra_tag
	if tag.is_empty():
		tag = tr("SKILL_TREE_TAG_UNLOCKED") if owned else tr("SKILL_TREE_TAG_LOCKED")
	var title: String = node.display_name if node != null else "?"
	button.text = "%s %s\n%s" % [title, tag, describe_tree_node(node)]
	button.tooltip_text = button.text
	button.disabled = not purchasable
	if not extra_tag.is_empty():
		button.add_theme_color_override("font_disabled_color", COLOR_DIM)
	_style_node_button(button, owned, purchasable)
	return button


func _on_branch_pressed(archetype: String, slot: String, side: String) -> void:
	if hero_skill_tree != null and hero_skill_tree.purchase_branch_node(archetype, slot, side):
		_rebuild_everything()


func _on_retrain_pressed(archetype: String, slot: String) -> void:
	if hero_skill_tree != null and hero_skill_tree.retrain(archetype, slot):
		_rebuild_everything()


## Player-facing effect lines for a tree node: flat stats ("Armor +4"),
## additive stats ("Max HP +6%", penalties "-20%"), then the effect sentence.
static func describe_tree_node(node: HeroTreeNodeResource) -> String:
	if node == null:
		return ""
	var parts: Array[String] = []
	for stat: StringName in _InfoPanel.ordered_stats(node.flat_stats):
		parts.append("%s %s" % [_InfoPanel.stat_label(stat), _InfoPanel.format_value(stat, node.flat_stats[stat])])
	for stat: StringName in _InfoPanel.ordered_stats(node.additive_stats):
		var pct: int = roundi(node.additive_stats[stat] * 100.0)
		parts.append("%s %s%d%%" % [_InfoPanel.stat_label(stat), "+" if pct >= 0 else "-", absi(pct)])
	var lines: Array[String] = []
	if not parts.is_empty():
		lines.append(", ".join(parts))
	if not node.effect.is_empty():
		var effect_text: String = _InfoPanel.describe_effect(node.effect)
		# Notables share the effect's name; bridges and others prefix it.
		lines.append(effect_text if node.effect[&"name"] == node.display_name else "%s: %s" % [node.effect[&"name"], effect_text])
	return "\n".join(lines)


# ---------------------------------------------------------------------------
# Bridges strip (spec §6a UI): 6 tiles under the columns.
# ---------------------------------------------------------------------------

func _rebuild_bridges() -> void:
	for child: Node in _bridges_grid.get_children():
		child.queue_free()
	_bridge_buttons.clear()
	if hero_skill_tree == null:
		return
	_bridges_header.text = tr("SKILL_TREE_BRIDGES") % HeroSkillTree.MAX_BRIDGES
	var owned_ids: Array[String] = hero_skill_tree.get_owned_bridges()
	if not owned_ids.has(_bridge_swap_from):
		_bridge_swap_from = ""
	for node: HeroTreeNodeResource in hero_skill_tree.get_bridges():
		_bridges_grid.add_child(_build_bridge_tile(node, owned_ids))


func _build_bridge_tile(node: HeroTreeNodeResource, owned_ids: Array[String]) -> Control:
	var bridge_id: String = String(node.id)
	var a: String = node.bridge_archetypes[0]
	var b: String = node.bridge_archetypes[1]
	var owned: bool = owned_ids.has(bridge_id)
	var open: bool = hero_skill_tree.is_bridge_open(bridge_id)
	var tile := VBoxContainer.new()
	tile.name = "Bridge_%s" % bridge_id
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var badges := HBoxContainer.new()
	badges.add_child(_make_glyph_badge(a, 16))
	badges.add_child(_make_glyph_badge(b, 16))
	var status := Label.new()
	status.add_theme_font_size_override("font_size", 11)
	if owned:
		status.text = tr("SKILL_TREE_TAG_UNLOCKED")
	elif not open:
		status.text = tr("SKILL_TREE_BRIDGE_NEEDS") % [tr(NODE_LABELS[HeroSkillTree.BRIDGE_OPENED_BY]), _archetype_name(a), _archetype_name(b)]
	elif owned_ids.size() >= HeroSkillTree.MAX_BRIDGES:
		status.text = tr("SKILL_TREE_BRIDGE_FULL") % owned_ids.size()
	else:
		status.text = tr("SKILL_TREE_BRIDGE_COST") % [_archetype_name(a), _archetype_name(b)]
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badges.add_child(status)
	tile.add_child(badges)

	var swap_target: bool = not _bridge_swap_from.is_empty() and not owned and open \
		and hero_skill_tree.visit_spend_count == 0
	var purchasable: bool = hero_skill_tree.is_bridge_purchasable(bridge_id)
	var button := _make_tree_button(node, owned, purchasable or swap_target, "")
	button.name = "BridgeButton_%s" % bridge_id
	button.pressed.connect(_on_bridge_pressed.bind(bridge_id))
	tile.add_child(button)
	_bridge_buttons[bridge_id] = button

	if owned and hero_skill_tree.visit_spend_count == 0:
		var swap := Button.new()
		swap.name = "BridgeSwap_%s" % bridge_id
		swap.add_theme_font_size_override("font_size", 11)
		swap.text = tr("SKILL_TREE_BRIDGE_SWAP_CANCEL") if _bridge_swap_from == bridge_id else tr("SKILL_TREE_BRIDGE_SWAP")
		swap.pressed.connect(_on_bridge_swap_pressed.bind(bridge_id))
		tile.add_child(swap)
	elif swap_target:
		var hint := Label.new()
		hint.add_theme_font_size_override("font_size", 11)
		hint.text = tr("SKILL_TREE_BRIDGE_SWAP_IN") % _bridge_name(_bridge_swap_from)
		tile.add_child(hint)
	return tile


func _bridge_name(bridge_id: String) -> String:
	var node: HeroTreeNodeResource = hero_skill_tree.get_catalog().get_node_by_id(StringName(bridge_id))
	return node.display_name if node != null else bridge_id


func _on_bridge_pressed(bridge_id: String) -> void:
	if hero_skill_tree == null:
		return
	if not _bridge_swap_from.is_empty():
		if hero_skill_tree.retrain_bridge(_bridge_swap_from, bridge_id):
			_bridge_swap_from = ""
			_rebuild_everything()
		return
	if hero_skill_tree.purchase_bridge(bridge_id):
		_rebuild_everything()


## Toggles swap mode: the next open, unowned tile pressed replaces this bridge.
func _on_bridge_swap_pressed(bridge_id: String) -> void:
	_bridge_swap_from = "" if _bridge_swap_from == bridge_id else bridge_id
	_rebuild_bridges()


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


## Branch node button at a tree position (null when not built).
func get_branch_button(archetype: String, slot: String, side: String, depth: int) -> Button:
	return _branch_buttons.get("%s:%s:%s:%d" % [archetype, slot, side, depth])


func get_retrain_button(archetype: String, slot: String) -> Button:
	return _retrain_buttons.get("%s:%s" % [archetype, slot])


func get_bridge_button(bridge_id: String) -> Button:
	return _bridge_buttons.get(bridge_id)


func get_pool_row() -> HBoxContainer:
	return _pool_row


func get_visit_spend_label_text() -> String:
	return _visit_spend_label.text


func get_expanded_choice_key() -> String:
	return _expanded_choice_key
