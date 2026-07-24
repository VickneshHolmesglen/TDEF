class_name DeckTabStrip
extends VBoxContainer

## Tarot Deck UI tab strip (Story 001, ADR-0011, epic-11-tarot-deck-ui).
##
## GDD source: design/gdd/tarot-deck-ui.md -- Core Rule 2, AC Group 1.
## Story: production/epics/epic-11-tarot-deck-ui/story-001-structural-model-and-tab-strip.md
##
## 2-entry persistent navigation surface (Hero Skill Build / Tarot Deck, in
## that order -- Player Fantasy's "build, then deck" reading). Same
## trigger/bumper split as Sanctuary UI's own TabStrip (triggers switch
## screens, bumpers stay owned by each screen's own internal category-
## cycling) -- reuses the identical `[`/`]`/LT-RT physical bindings via
## dedicated tarot_tab_prev/tarot_tab_next InputMap actions (never
## simultaneously active with Sanctuary UI's own sanctuary_tab_prev/next, so
## no conflict, but kept as distinct named actions matching this project's
## per-screen action-naming convention). No hotkeys 1/2 exist for this shell
## (unlike Sanctuary UI's 1-6) -- the GDD's own Core Rule 2 only specifies
## click and LT/RT/[/] for this 2-entry strip.
##
## Bumpers (LB/RB) intentionally absent here too, same reasoning as
## Sanctuary UI's TabStrip: the simplest way to guarantee AC-3 (bumpers never
## switch screens) is for no code path here to reference them at all.
##
## InputModeTracker + focus-ring gating mirrors Sanctuary UI's TabStrip
## exactly (ADR-0011) -- reuses the same shared script (src/ui/input_mode_tracker.gd).

signal tab_target_selected(target_state: StringName)

const TAB_TARGETS: Array[StringName] = [
	&"HERO_SKILL_BUILD",
	&"TAROT_DECK",
]

const TAB_LABEL_KEYS: Array[String] = [
	"TAROT_DECK_UI_TAB_HERO_SKILL_BUILD",
	"TAROT_DECK_UI_TAB_TAROT_DECK",
]

var _current_index: int = 0
var _buttons: Array[Button] = []
var _focus_rings: Array[Panel] = []
var _input_mode_tracker: InputModeTracker


func _ready() -> void:
	_input_mode_tracker = InputModeTracker.new()
	add_child(_input_mode_tracker)
	_input_mode_tracker.input_mode_changed.connect(_on_input_mode_changed)
	_build_buttons()
	_wire_focus_neighbors()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"tarot_tab_next"):
		_select_index((_current_index + 1) % TAB_TARGETS.size())
		return
	if event.is_action_pressed(&"tarot_tab_prev"):
		_select_index((_current_index - 1 + TAB_TARGETS.size()) % TAB_TARGETS.size())
		return


func get_current_index() -> int:
	return _current_index


func get_tab_button(index: int) -> Button:
	return _buttons[index]


func is_focus_ring_visible(index: int) -> bool:
	return _focus_rings[index].visible


func get_input_mode_tracker() -> InputModeTracker:
	return _input_mode_tracker


func _on_input_mode_changed(_mode: InputModeTracker.InputMode) -> void:
	for index: int in _buttons.size():
		_update_focus_ring(index)


func _select_index(index: int) -> void:
	_current_index = index
	tab_target_selected.emit(TAB_TARGETS[index])


func _build_buttons() -> void:
	for index: int in TAB_TARGETS.size():
		var button := Button.new()
		button.text = tr(TAB_LABEL_KEYS[index])
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_button_pressed.bind(index))
		button.focus_entered.connect(_update_focus_ring.bind(index))
		button.focus_exited.connect(_update_focus_ring.bind(index))
		add_child(button)
		_buttons.append(button)

		var ring := Panel.new()
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ring.visible = false
		button.add_child(ring)
		_focus_rings.append(ring)


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


func _on_button_pressed(index: int) -> void:
	_select_index(index)
