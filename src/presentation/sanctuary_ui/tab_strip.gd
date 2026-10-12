class_name TabStrip
extends VBoxContainer

## Sanctuary UI tab strip (Story 002, ADR-0011, epic-10-sanctuary-ui).
##
## GDD source: design/gdd/sanctuary-ui.md -- Core Rule 2 (Navigation), AC Group 2.
## Story: production/epics/epic-10-sanctuary-ui/story-002-tab-strip-navigation.md
##
## 6-entry persistent navigation surface (Overview / Inventory & Crafting /
## Menagerie / Defense Building / Equipment Forge / Loadout). Owns direct-click
## routing, the global 1-6 hotkeys, `[`/`]` and gamepad LT/RT prev/next cycling,
## and the one-time session-local onboarding tooltip. Deliberately does NOT own
## Connection Badges (Story 003) or the actual DEPARTING_TO_LOADOUT hand-off
## sequence (Story 010) -- this story only emits the routing signal; SanctuaryUI
## (and, later, Story 010's hand-off code) decides what to do with it.
##
## Plain VBoxContainer, not TabBar/TabContainer (GDD Core Rule 2's explicit
## implementation-ambiguity closure -- TabBar's auto-fit/overflow behavior is a
## sizing risk this shell doesn't need; height grows to fit 6 fixed entries).
##
## Bumpers (LB/RB) are intentionally absent from this class and from
## project.godot's InputMap: AC-5 requires them to never switch tabs, and the
## simplest, most literal way to guarantee that is for no code path here to
## reference them at all -- each room owns its own internal bumper-driven
## category cycling independently (out of this story's scope).
##
## Button.icon + Button.text for all 6 entries (icon set added 2026-08-04,
## `design/art/asset-UI-prompt.md`'s "Sanctuary Room Tab Strip" batch --
## previously text-only, matching Story 001's Diorama-placeholder precedent).
## Text remains always-visible rather than the GDD's own "icon-first,
## label-on-focus-only" ideal (design/ux/sanctuary-ui.md Component
## Inventory) -- that reveal behavior is a separate presentation change this
## pass doesn't make; only the icon asset is being wired into the existing
## always-on-text button. Text is still routed through tr() with
## SANCTUARY_TAB_* keys, matching inventory_screen.gd's real localization
## precedent -- no hardcoded user-facing strings even though no translation
## catalog exists yet.
##
## Connection Badges (Story 003, GDD Core Rule 2 + Tuning Knobs table): the 4
## room-tab entries (indices 1-4) each carry a live EventBus-driven badge
## count, cleared the instant that tab is selected. Overview (0) and Loadout
## (5) never carry one -- Loadout's carve-out is explicit in the GDD (OQ-8,
## deferred design choice); Overview never had a trigger event to begin with.
##
## REAL SIGNAL SUBSTITUTION, FLAGGED PER THIS STORY'S OWN INSTRUCTION ("flag
## any mismatch found during implementation rather than silently
## reinterpreting it"): the GDD's Tuning Knobs table names 4 trigger events as
## a first-pass guess (OQ-6, "not confirmed against each room's own owning
## designer") -- 2 of the 4 (`recipe_unlocked`, `rune_socket_unlocked`) do not
## exist in the real EventBus catalogue (src/foundation/event_bus/event_bus.gd)
## and a literal "creature reaches READY state" signal does not exist either.
## Implemented against the closest real, already-shipped signal for each:
##   Inventory & Crafting -> recipe_discovered(recipe_id, recipe_category)
##   Menagerie             -> creature_returned_from_breeding_pen(creature_id)
##                             (closest real analog to "READY" -- a creature
##                             becoming available again after breeding)
##   Defense Building      -> sanctuary_structure_built(structure_id, type)
##                             (exact match, no substitution needed)
##   Equipment Forge        -> item_rune_imbued(item_id, rune_id, rune_source)
##                             (2026-08-12: also building_upgrade_became_
##                             purchasable(upgrade_id), added by
##                             building-upgrade.md Rule 6a/Story 004 for the
##                             same tab -- an exact match, no substitution)
## This substitution should be confirmed against each room's own owning
## designer before this GDD is treated as fully Approved, exactly as OQ-6
## already asks -- not silently treated as settled by this implementation.

signal tab_target_selected(target_state: StringName)

## Index-ordered 1:1 with the GDD's 7-entry tab strip layout. `ROOM_HERO_SKILLS`
## added 2026-09-01 (Claude Code) at position 5 (between Equipment Forge and
## Loadout, per sanctuary-ui.md Core Rule 11) -- Loadout shifts from hotkey 6
## to hotkey 7. Real gap closed: this entry (and the matching ROOM_SCENES row
## in sanctuary_ui.gd) is what makes hero_skill_build_screen.gd/hero_skill_
## tree_screen.gd reachable from the live game for the first time -- both
## screens existed, fully built and live-verified standalone, with no way to
## actually reach them before this change.
const TAB_TARGETS: Array[StringName] = [
	&"OVERVIEW",
	&"ROOM_INVENTORY_CRAFTING",
	&"ROOM_MENAGERIE",
	&"ROOM_DEFENSE_BUILDING",
	&"ROOM_EQUIPMENT_FORGE",
	&"ROOM_HERO_SKILLS",
	&"DEPARTING_TO_LOADOUT",
]

## Index-ordered 1:1 with TAB_TARGETS.
const TAB_LABEL_KEYS: Array[String] = [
	"SANCTUARY_TAB_OVERVIEW",
	"SANCTUARY_TAB_INVENTORY_CRAFTING",
	"SANCTUARY_TAB_MENAGERIE",
	"SANCTUARY_TAB_DEFENSE_BUILDING",
	"SANCTUARY_TAB_EQUIPMENT_FORGE",
	"SANCTUARY_TAB_HERO_SKILLS",
	"SANCTUARY_TAB_LOADOUT",
]

## Index-ordered 1:1 with TAB_TARGETS -- `design/art/asset-UI-prompt.md`'s
## "Sanctuary Room Tab Strip" icon set (2026-08-04) plus the Skills glyph
## (index 5, generated 2026-10-07).
const TAB_ICON_TEXTURES: Array[Texture2D] = [
	preload("res://assets/art/ui/tab_overview.png"),
	preload("res://assets/art/ui/tab_inventory_crafting.png"),
	preload("res://assets/art/ui/tab_menagerie.png"),
	preload("res://assets/art/ui/tab_defense_building.png"),
	preload("res://assets/art/ui/tab_equipment_forge.png"),
	preload("res://assets/art/ui/tab_hero_skills.png"),
	preload("res://assets/art/ui/tab_loadout.png"),
]

## Index-ordered 1:1 with TAB_TARGETS -- InputMap actions added in project.godot.
## sanctuary_tab_7 added 2026-09-01 alongside the new Skills entry.
const HOTKEY_ACTIONS: Array[StringName] = [
	&"sanctuary_tab_1", &"sanctuary_tab_2", &"sanctuary_tab_3",
	&"sanctuary_tab_4", &"sanctuary_tab_5", &"sanctuary_tab_6", &"sanctuary_tab_7",
]

## The 5 room-tab indices eligible for a Connection Badge (Overview=0 and
## Loadout=6 are never eligible -- see class doc). Skills (5) added
## 2026-09-01 per sanctuary-ui.md Core Rule 11's explicit badge spec
## (driven by skill_unlocked / skill_tree_point_earned /
## skill_tree_overflow_point_earned).
const BADGE_ELIGIBLE_INDICES: Array[int] = [1, 2, 3, 4, 5]

## Session-local onboarding flag (GDD Core Rule 2's onboarding paragraph):
## "has a Sanctuary UI instance mounted before this session" -- explicitly
## NOT persisted (Save & Persistence's "no UI state saved" rule), so a static
## var (survives across instances of this class, resets on process restart)
## is the correct tool here, not an exported flag or a saved field.
static var _has_shown_onboarding_this_session: bool = false

var _current_index: int = 0
var _buttons: Array[Button] = []
var _focus_rings: Array[Panel] = []
var _onboarding_tooltip: Label
var _input_mode_tracker: InputModeTracker

## Index-keyed (only 1-4 ever populated) -- badge overlay Label per room tab.
var _badges: Dictionary = {}
## Index-keyed live count -- 0 means "no badge shown," matching the GDD's
## "purely informational... no unread/dismiss state to persist" rule (this is
## in-memory only, never saved, reset fresh on every mount).
var _badge_counts: Dictionary = {}


func _ready() -> void:
	# Without this, Button's own minimum-size-from-text can force this
	# container wider than its anchored TAB_STRIP_WIDTH rect (sanctuary_ui.gd)
	# whenever a label is long -- confirmed via live MCP screenshot during
	# Story 013's visual pass, where the untranslated placeholder keys (no
	# translation catalog exists yet, matching every prior story's flagged
	# gap) are long enough to trigger exactly this. Now that a real
	# translation catalog exists (2026-08-09), real label text is even
	# longer than those placeholder keys were -- clip_contents alone isn't
	# enough (it clips rendering, not the Container's own minimum-size-driven
	# rect growth), so _build_buttons() below also sets each Button's
	# text_overrun_behavior to ellipsis-truncate within TAB_STRIP_WIDTH.
	clip_contents = true
	_input_mode_tracker = InputModeTracker.new()
	add_child(_input_mode_tracker)
	_input_mode_tracker.input_mode_changed.connect(_on_input_mode_changed)
	_build_buttons()
	_wire_focus_neighbors()
	_build_onboarding_tooltip()
	_connect_badge_triggers()


func _exit_tree() -> void:
	GEventBus.recipe_discovered.disconnect(_on_recipe_discovered)
	GEventBus.creature_returned_from_breeding_pen.disconnect(_on_creature_returned_from_breeding_pen)
	GEventBus.sanctuary_structure_built.disconnect(_on_sanctuary_structure_built)
	GEventBus.item_rune_imbued.disconnect(_on_item_rune_imbued)
	GEventBus.building_upgrade_became_purchasable.disconnect(_on_building_upgrade_became_purchasable)
	GEventBus.skill_unlocked.disconnect(_on_skill_unlocked)
	GEventBus.skill_tree_point_earned.disconnect(_on_skill_tree_point_earned)
	GEventBus.skill_tree_overflow_point_earned.disconnect(_on_skill_tree_overflow_point_earned)


func _input(event: InputEvent) -> void:
	# Dismissing the tooltip is a passive side effect of any input, never a
	# consumed action -- a player's first real press (e.g. a hotkey straight
	# to a room) must still take effect in this same event, not be swallowed
	# by dismissal alone. GDD Core Rule 2: "Dismisses on any input," not
	# "any input dismisses instead of doing its own thing."
	if _onboarding_tooltip.visible and _is_dismiss_event(event):
		_onboarding_tooltip.visible = false

	for index: int in HOTKEY_ACTIONS.size():
		if event.is_action_pressed(HOTKEY_ACTIONS[index]):
			_select_index(index)
			return

	if event.is_action_pressed(&"sanctuary_tab_next"):
		_select_index((_current_index + 1) % TAB_TARGETS.size())
		return

	if event.is_action_pressed(&"sanctuary_tab_prev"):
		_select_index((_current_index - 1 + TAB_TARGETS.size()) % TAB_TARGETS.size())
		return


## Current tab-strip position (0-based) -- for tests and any future external
## sync needs (e.g. a later story reflecting a non-tab-strip-driven state
## change, such as Story 007's diorama-click entry, back into this index).
func get_current_index() -> int:
	return _current_index


## Test/inspection accessor for a specific entry's Button (AC-1 direct-click
## routing tests drive this directly rather than simulating a real mouse click).
func get_tab_button(index: int) -> Button:
	return _buttons[index]


## Test/inspection accessor for AC-6's onboarding-tooltip visibility.
func is_onboarding_tooltip_visible() -> bool:
	return _onboarding_tooltip.visible


## Test/inspection accessor (ADR-0011) — whether entry `index`'s focus ring
## overlay is currently visible. Gated on has_focus() AND
## tracker.is_focus_ring_visible(), per ADR-0011's Decision: mouse hover stays
## a fully separate signal (mouse_entered/mouse_exited, styled via the Button's
## own theme, not this overlay) and is never merged into this "highlighted"
## state.
func is_focus_ring_visible(index: int) -> bool:
	return _focus_rings[index].visible


## Test-only accessor: the engine normally calls _input() on every node in
## the tree independently each frame -- a test that calls TabStrip._input()
## directly (bypassing engine dispatch, as this suite does throughout) must
## reach the InputModeTracker sibling explicitly too, since it is its own
## Node with its own _input() override, not something TabStrip forwards to.
func get_input_mode_tracker() -> InputModeTracker:
	return _input_mode_tracker


func _on_input_mode_changed(_mode: InputModeTracker.InputMode) -> void:
	for index: int in _buttons.size():
		_update_focus_ring(index)


## Test-only: resets the session-local onboarding flag so each test starts
## from "never shown this session" regardless of prior tests in the same run.
static func reset_onboarding_flag_for_tests() -> void:
	_has_shown_onboarding_this_session = false


## Selects the tab for `target_state` exactly as a click on it would (styling,
## badge clear, tab_target_selected). Used by the Overview's town buildings.
## Unknown targets are ignored. Example: `tab_strip.select_target(&"ROOM_MENAGERIE")`
func select_target(target_state: StringName) -> void:
	var index: int = TAB_TARGETS.find(target_state)
	if index != -1:
		_select_index(index)


func _select_index(index: int) -> void:
	_current_index = index
	_refresh_active_tab_styling()
	# Badges clear the instant their own room is entered -- no fade-out beat
	# (GDD Core Rule 2). Entering any other tab (including Overview/Loadout)
	# leaves other rooms' badges untouched.
	if index in BADGE_ELIGIBLE_INDICES:
		_clear_badge(index)
	tab_target_selected.emit(TAB_TARGETS[index])


## Filled-vs-outline actionable convention (never color-only) -- re-applied
## on every switch since the initial construction pass only knows entry 0 is
## active at mount time.
func _refresh_active_tab_styling() -> void:
	for index: int in _buttons.size():
		var is_active: bool = index == _current_index
		_buttons[index].add_theme_stylebox_override("normal", ShellChromeStyle.skin_button_for(is_active))
		_buttons[index].add_theme_stylebox_override("hover", ShellChromeStyle.skin_button_for(is_active))


## Test/inspection accessor -- current live count for a badge-eligible index
## (0 for ineligible indices or a never-triggered eligible one).
func get_badge_count(index: int) -> int:
	return _badge_counts.get(index, 0)


## Test/inspection accessor -- whether index's badge overlay is currently shown.
func is_badge_visible(index: int) -> bool:
	return _badges.has(index) and _badges[index].visible


func _connect_badge_triggers() -> void:
	GEventBus.recipe_discovered.connect(_on_recipe_discovered)
	GEventBus.creature_returned_from_breeding_pen.connect(_on_creature_returned_from_breeding_pen)
	GEventBus.sanctuary_structure_built.connect(_on_sanctuary_structure_built)
	GEventBus.item_rune_imbued.connect(_on_item_rune_imbued)
	GEventBus.building_upgrade_became_purchasable.connect(_on_building_upgrade_became_purchasable)
	GEventBus.skill_unlocked.connect(_on_skill_unlocked)
	GEventBus.skill_tree_point_earned.connect(_on_skill_tree_point_earned)
	GEventBus.skill_tree_overflow_point_earned.connect(_on_skill_tree_overflow_point_earned)


func _on_recipe_discovered(_recipe_id: String, _recipe_category: String) -> void:
	_increment_badge(1)  # ROOM_INVENTORY_CRAFTING


func _on_creature_returned_from_breeding_pen(_creature_id: int) -> void:
	_increment_badge(2)  # ROOM_MENAGERIE


func _on_sanctuary_structure_built(_structure_id: String, _structure_type: String) -> void:
	_increment_badge(3)  # ROOM_DEFENSE_BUILDING


func _on_item_rune_imbued(_item_id: String, _rune_id: String, _rune_source: String) -> void:
	_increment_badge(4)  # ROOM_EQUIPMENT_FORGE


## Story 004 (TR-buildupgrade-004, Rule 6a, AC-8): Building Upgrade's own
## screen is hosted as a tab inside Equipment Forge (building-upgrade.md's
## Status line), not a room of its own -- same tab index as
## _on_item_rune_imbued above, added 2026-08-12.
func _on_building_upgrade_became_purchasable(_upgrade_id: String) -> void:
	_increment_badge(4)  # ROOM_EQUIPMENT_FORGE


## Core Rule 11's own badge spec (2026-09-01, Claude Code): a newly-learned,
## not-yet-equipped skill.
func _on_skill_unlocked(_skill_id: String, _source_tower_id: int) -> void:
	_increment_badge(5)  # ROOM_HERO_SKILLS


## Core Rule 11's own badge spec: an unspent banked skill tree point.
func _on_skill_tree_point_earned(_archetype: String, _source_tower_id: int) -> void:
	_increment_badge(5)  # ROOM_HERO_SKILLS


func _on_skill_tree_overflow_point_earned(_source_tower_id: int) -> void:
	_increment_badge(5)  # ROOM_HERO_SKILLS


## Fires regardless of the currently active tab -- a badge-triggering event
## for a room other than the active one is the entire point (Core Rule 9's
## tab-strip-level cross-system legibility); if the triggered room happens to
## already be active, the badge is set then immediately cleared next frame by
## the player's own presence there -- harmless, matches "no badge while
## looking straight at the thing it points to" intuitively.
func _increment_badge(index: int) -> void:
	_badge_counts[index] = int(_badge_counts.get(index, 0)) + 1
	_badges[index].text = str(_badge_counts[index])
	_badges[index].visible = true
	_play_scale_pop(_badges[index])


## Existing project-wide scale-pop treatment (~1.0->1.15->1.0 over ~0.2s),
## reused verbatim for badge arrivals -- GDD Visual/Audio Requirements'
## explicit "matching the resource header's existing treatment" instruction.
func _play_scale_pop(node: Control) -> void:
	node.scale = Vector2.ONE
	var tween: Tween = create_tween()
	tween.tween_property(node, "scale", Vector2(1.15, 1.15), 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _clear_badge(index: int) -> void:
	_badge_counts[index] = 0
	_badges[index].visible = false


func _build_buttons() -> void:
	for index: int in TAB_TARGETS.size():
		var button := Button.new()
		button.text = tr(TAB_LABEL_KEYS[index])
		button.icon = TAB_ICON_TEXTURES[index]
		button.expand_icon = true
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size = Vector2(56, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Tabs share the strip's full height (2026-10-10 UI pass) -- they
		# used to stop two-thirds down, leaving a dead block under them.
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal", ShellChromeStyle.skin_button_for(index == 0))
		button.add_theme_stylebox_override("hover", ShellChromeStyle.skin_button_for(index == 0))
		button.add_theme_stylebox_override("pressed", ShellChromeStyle.skin_button(&"active"))
		button.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
		button.pressed.connect(_on_button_pressed.bind(index))
		button.focus_entered.connect(_update_focus_ring.bind(index))
		button.focus_exited.connect(_update_focus_ring.bind(index))
		add_child(button)
		_buttons.append(button)

		# Overlay-only visual, gated per ADR-0011: has_focus() AND
		# tracker.is_focus_ring_visible() -- never merged with mouse hover.
		var ring := Panel.new()
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ring.add_theme_stylebox_override("panel", ShellChromeStyle.focus_ring_stylebox())
		ring.visible = false
		button.add_child(ring)
		_focus_rings.append(ring)

		if index in BADGE_ELIGIBLE_INDICES:
			var badge := Label.new()
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(badge)
			# Explicit fixed 20x20 rect, anchored to the button's top-right
			# corner and inset 4px on both axes (found 2026-09-08, S9-02
			# playtest): the original bare Label had no min size and no
			# offset, so it shrank to fit only its own digit glyph pinned
			# flush to the button's exact corner -- a near-invisible sliver
			# against a 56x56 button. Set AFTER add_child so the anchor math
			# resolves against the real parent rect, not an unparented
			# Control's stale/zeroed size (set_anchors_and_offsets_preset
			# before add_child was tried first and produced a badge
			# positioned outside the button's own bounds entirely).
			badge.anchor_left = 1.0
			badge.anchor_right = 1.0
			badge.anchor_top = 0.0
			badge.anchor_bottom = 0.0
			badge.offset_right = -4.0
			badge.offset_left = -24.0
			badge.offset_top = 4.0
			badge.offset_bottom = 24.0
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			badge.add_theme_font_size_override("font_size", 14)
			badge.add_theme_stylebox_override("normal", ShellChromeStyle.badge_stylebox())
			badge.add_theme_color_override("font_color", ShellChromeStyle.UI_CHROME)
			badge.pivot_offset = Vector2(10, 10)
			badge.visible = false
			_badges[index] = badge
			_badge_counts[index] = 0


## ADR-0011: focus_neighbor_top/bottom must be wired explicitly for this
## vertical strip's wrap-at-edge traversal -- Godot's automatic nearest-
## neighbor traversal does not wrap, and this strip's own top<->bottom wrap
## is a named requirement (design/ux/sanctuary-ui.md Focus Traversal Order).
func _wire_focus_neighbors() -> void:
	var count: int = _buttons.size()
	for index: int in count:
		var next_index: int = (index + 1) % count
		var prev_index: int = (index - 1 + count) % count
		_buttons[index].focus_neighbor_bottom = _buttons[index].get_path_to(_buttons[next_index])
		_buttons[index].focus_neighbor_top = _buttons[index].get_path_to(_buttons[prev_index])
		_buttons[index].focus_neighbor_left = _buttons[index].get_path_to(_buttons[index])
		_buttons[index].focus_neighbor_right = _buttons[index].get_path_to(_buttons[index])


func _update_focus_ring(index: int) -> void:
	_focus_rings[index].visible = (
		_buttons[index].has_focus() and _input_mode_tracker.is_focus_ring_visible()
	)


func _build_onboarding_tooltip() -> void:
	_onboarding_tooltip = Label.new()
	_onboarding_tooltip.text = tr("SANCTUARY_TAB_STRIP_ONBOARDING_TOOLTIP")
	_onboarding_tooltip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_onboarding_tooltip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_onboarding_tooltip.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
	_onboarding_tooltip.visible = not _has_shown_onboarding_this_session
	_has_shown_onboarding_this_session = true
	add_child(_onboarding_tooltip)


## "Any input" per the GDD's dismiss rule, narrowed to discrete press events
## -- mouse motion alone doesn't count as a dismiss (matches AC-6's "dismiss
## via any input type: mouse click, key, gamepad button").
func _is_dismiss_event(event: InputEvent) -> bool:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		return event.is_pressed()
	if event is InputEventAction:
		return event.is_pressed()
	return false


func _on_button_pressed(index: int) -> void:
	_select_index(index)
