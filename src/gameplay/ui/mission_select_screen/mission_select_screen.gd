extends Control

## Mission Select Screen — the browsing/configuring content of MissionScene's
## shell (src/scenes/mission_scene.gd), shown while GMissionSelect.state is
## BROWSING or CONFIGURING.
##
## GDD source: design/gdd/mission-select.md — UI Requirements section (one
## continuous screen: mission list + difficulty/modifiers panel + persistent
## launch bar with a lightweight "arm, then confirm" two-step on Launch
## itself, not a modal).
## Governing ADR: docs/architecture/adr-0028-mission-select-runtime-state.md
##
## Scope, honestly bounded:
## - No mission-card art, no completion mini-table rendering (checkmark/dash/
##   lock per tier) — no art exists anywhere in this project. Completion
##   state is shown as plain text (best time or "--" per tier).
## - Shoulder-button mission-category cycling is not implemented — the GDD
##   itself notes this only applies "if the catalogue is large enough to
##   warrant grouping" (Open Questions), and the Alpha-scope catalogue (2
##   missions) does not.
##
## Root is a plain Control. No class_name — matches the other room/screen
## scripts' TD-workflow-001 precedent.

## Rule 5's fixed 3-position stepper values, keyed by modifier_id.
const RUN_MODIFIER_STEPS: Dictionary[StringName, Array] = {
	&"extend_waves": [0.0, 1.0, 2.0],
	&"difficulty_growth_boost": [0.0, 0.03, 0.05],
}

## Injectable for tests; defaults to the real GMissionSelect Autoload.
@export var mission_select: MissionSelect

## Player-reported 2026-08-16 (see sanctuary_ui.gd's _content_background for
## the matching Sanctuary-side fix): this screen had no background fill at
## all, rendering on Godot's raw default clear color instead of anything
## intentional -- reuses the same UI Chrome Dark token every other screen-
## space chrome in this project already uses (ShellChromeStyle.UI_CHROME).
@onready var _background: ColorRect = $Background
@onready var _input_mode_tracker: InputModeTracker = $InputModeTracker
@onready var _mission_list: VBoxContainer = $MainLayout/TopRow/MissionListPanel/MissionList
@onready var _config_panel: Control = $MainLayout/TopRow/ConfigPanel
@onready var _objective_label: Label = $MainLayout/TopRow/ConfigPanel/ObjectiveLabel
@onready var _tier_row: HBoxContainer = $MainLayout/TopRow/ConfigPanel/TierRow
@onready var _modifier_row: VBoxContainer = $MainLayout/TopRow/ConfigPanel/ModifierRow
@onready var _back_button: Button = $MainLayout/TopRow/ConfigPanel/BackButton
@onready var _launch_button: Button = $MainLayout/LaunchBar/LaunchButton
@onready var _launch_recap_label: Label = $MainLayout/LaunchBar/RecapLabel

var _mission_buttons: Dictionary[String, Button] = {}
var _tier_buttons: Dictionary[int, Button] = {}
var _modifier_buttons: Dictionary[StringName, Button] = {}
var _launch_armed: bool = false


func _ready() -> void:
	if mission_select == null:
		mission_select = GMissionSelect

	_background.color = ShellChromeStyle.UI_CHROME

	_input_mode_tracker.input_mode_changed.connect(_on_input_mode_changed)
	_back_button.pressed.connect(_on_back_pressed)
	_launch_button.pressed.connect(_on_launch_pressed)
	for tier: int in [1, 2, 3]:
		_tier_buttons[tier] = _create_tier_button(tier)
	for modifier_id: StringName in RUN_MODIFIER_STEPS.keys():
		_modifier_buttons[modifier_id] = _create_modifier_button(modifier_id)

	GEventBus.mission_selected.connect(_on_mission_selected)
	GEventBus.run_modifier_selected.connect(_on_run_modifier_selected)

	_rebuild_mission_list()
	_refresh_config_panel()


func _exit_tree() -> void:
	# Idempotent against mission_scene.gd's own _on_mission_launched() already
	# having called disconnect_own_subscriptions() this instance's lifetime
	# (Godot errors on disconnecting an already-disconnected signal) --
	# mirrors sanctuary_ui.gd's own _departing-guarded _exit_tree() pattern.
	if not GEventBus.mission_selected.is_connected(_on_mission_selected):
		return
	disconnect_own_subscriptions()


## Idempotent: mission_scene.gd calls this from every mission_launched, and a Retry re-emits
## mission_launched, so the second call must not error on already-disconnected signals.
func disconnect_own_subscriptions() -> void:
	if GEventBus.mission_selected.is_connected(_on_mission_selected):
		GEventBus.mission_selected.disconnect(_on_mission_selected)
	if GEventBus.run_modifier_selected.is_connected(_on_run_modifier_selected):
		GEventBus.run_modifier_selected.disconnect(_on_run_modifier_selected)


func _on_mission_selected(_mission_id: String) -> void:
	_disarm_launch()
	_refresh_config_panel()


func _on_run_modifier_selected(_modifier_id: String, _modifier_value: float) -> void:
	_disarm_launch()
	_refresh_modifier_button_labels()


# ---------------------------------------------------------------------------
# Mission list (primary/left region, always visible)
# ---------------------------------------------------------------------------

## design/gdd/mission-select.md "small flat environment-motif icon" — Art
## Bible 3.3's 24x24px minimum readable size, with headroom for this list's
## row height.
const MISSION_ICON_SIZE: Vector2 = Vector2(32.0, 32.0)


func _rebuild_mission_list() -> void:
	for child: Node in _mission_list.get_children():
		child.queue_free()
	_mission_buttons.clear()

	var entries: Dictionary[String, MissionEntry] = GGameDataRegistry.get_all_mission_entries()
	var mission_ids: Array = entries.keys()
	mission_ids.sort()

	for mission_id: String in mission_ids:
		var entry: MissionEntry = entries[mission_id]
		var button: Button = _create_mission_button(entry)
		_mission_list.add_child(_build_mission_row(entry, button))
		_mission_buttons[mission_id] = button


func _create_mission_button(entry: MissionEntry) -> Button:
	var button := Button.new()
	button.name = "Mission_%s" % entry.mission_id
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = true
	button.text = _mission_entry_text(entry)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_mission_pressed.bind(entry.mission_id))
	_wire_focus_ring(button)
	return button


## Wraps the button with its optional card icon in an HBoxContainer. The
## button itself remains the direct target of _mission_buttons/
## get_mission_button() (test/focus accessor) — this wrapper is purely
## presentational and doesn't change what's tracked or how focus/press wiring
## works. entry.icon == null (not yet art-authored for this mission) renders
## as no icon, not an error — matches MissionEntry.icon's own doc comment.
func _build_mission_row(entry: MissionEntry, button: Button) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Row_%s" % entry.mission_id
	if entry.icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.name = "Icon"
		icon_rect.texture = entry.icon
		icon_rect.custom_minimum_size = MISSION_ICON_SIZE
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon_rect)
	row.add_child(button)
	return row


## GDD: "fully covered on the mission card itself" — 3-tier best-time summary,
## plain text (no mini-table art, see class doc comment).
func _mission_entry_text(entry: MissionEntry) -> String:
	var parts: Array[String] = []
	for tier: int in [1, 2, 3]:
		var record: MissionCompletionRecord = mission_select.get_completion_record(entry.mission_id, tier)
		parts.append("T%d:%s" % [tier, ("%.1fs" % record.best_time_seconds) if record.completed else "--"])
	return "%s (%s)" % [entry.display_name, " ".join(parts)]


func _on_mission_pressed(mission_id: String) -> void:
	mission_select.select_mission(mission_id)


# ---------------------------------------------------------------------------
# Difficulty + modifiers panel (right region) — empty until a mission is
# selected, per the GDD's own progressive-disclosure requirement
# ---------------------------------------------------------------------------

func _refresh_config_panel() -> void:
	var configuring: bool = mission_select.state == MissionSelect.State.CONFIGURING
	_config_panel.visible = configuring
	if not configuring:
		return
	_refresh_objective_label()
	_refresh_tier_button_labels()
	_refresh_modifier_button_labels()


## TD-mission-001: MissionResource.objective_text had no display path
## anywhere in the project despite the loader/schema being fully built and
## tested — this closes that gap. Falls back to an empty string (label
## renders blank, not an error) for a mission_id with no authored
## MissionResource, matching get_mission_resource()'s own documented
## does-not-abort-at-boot policy for missing/invalid content.
func _refresh_objective_label() -> void:
	var mission_id: StringName = StringName(mission_select.get_current_mission_id())
	var resource: MissionResource = GGameDataRegistry.get_mission_resource(mission_id)
	_objective_label.text = resource.objective_text if resource != null else ""


func _create_tier_button(tier: int) -> Button:
	var button := Button.new()
	button.name = "Tier_%d" % tier
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(_on_tier_pressed.bind(tier))
	_wire_focus_ring(button)
	_tier_row.add_child(button)
	return button


func _refresh_tier_button_labels() -> void:
	for tier: int in _tier_buttons.keys():
		var button: Button = _tier_buttons[tier]
		var selected_tag: String = " [SELECTED]" if mission_select.difficulty_tier == tier else ""
		button.text = "%s%s" % [_tier_display_name(tier), selected_tag]


func _tier_display_name(tier: int) -> String:
	match tier:
		1: return "Normal"
		2: return "Hard"
		3: return "Brutal"
		_: return "Tier %d" % tier


func _on_tier_pressed(tier: int) -> void:
	mission_select.set_difficulty_tier(tier)
	_disarm_launch()
	_refresh_tier_button_labels()


## Rule 5: a 3-position stepper (off/low/high), not a slider — implemented
## as one button that cycles through RUN_MODIFIER_STEPS on each press.
func _create_modifier_button(modifier_id: StringName) -> Button:
	var button := Button.new()
	button.name = "Modifier_%s" % String(modifier_id)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(_on_modifier_pressed.bind(modifier_id))
	_wire_focus_ring(button)
	_modifier_row.add_child(button)
	return button


func _refresh_modifier_button_labels() -> void:
	for modifier_id: StringName in _modifier_buttons.keys():
		var button: Button = _modifier_buttons[modifier_id]
		var current_value: float = mission_select.get_run_modifier_value(modifier_id)
		var steps: Array = RUN_MODIFIER_STEPS[modifier_id]
		var step_index: int = steps.find(current_value)
		if step_index == -1:
			step_index = 0
		button.text = "%s: %s" % [String(modifier_id), _step_label(step_index)]


func _step_label(step_index: int) -> String:
	match step_index:
		0: return "OFF"
		1: return "LOW"
		2: return "HIGH"
		_: return "?"


func _on_modifier_pressed(modifier_id: StringName) -> void:
	var steps: Array = RUN_MODIFIER_STEPS[modifier_id]
	var current_value: float = mission_select.get_run_modifier_value(modifier_id)
	var step_index: int = steps.find(current_value)
	if step_index == -1:
		step_index = 0
	var next_index: int = (step_index + 1) % steps.size()
	mission_select.set_run_modifier(modifier_id, steps[next_index])


func _on_back_pressed() -> void:
	mission_select.back_out_to_browsing()
	_disarm_launch()
	_refresh_config_panel()


# ---------------------------------------------------------------------------
# Persistent launch bar — lightweight arm/confirm two-step (GDD: NOT a modal)
# ---------------------------------------------------------------------------

## GDD: pressing any other control while armed silently disarms it. All the
## handlers above (mission press, tier press, modifier press, back) already
## call this.
func _disarm_launch() -> void:
	_launch_armed = false
	_launch_recap_label.text = ""
	_launch_button.text = "Launch"


func _on_launch_pressed() -> void:
	if not _launch_armed:
		if mission_select.state != MissionSelect.State.CONFIGURING:
			return  # disabled/no-op until both a mission and tier are selected
		_launch_armed = true
		_launch_recap_label.text = _build_recap_text()
		_launch_button.text = "Confirm Launch"
		return

	# Second press: commit.
	_launch_armed = false
	mission_select.confirm_launch()


func _build_recap_text() -> String:
	var entry: MissionEntry = GGameDataRegistry.get_mission_entry(mission_select.get_current_mission_id())
	var mission_name: String = entry.display_name if entry != null else mission_select.get_current_mission_id()
	var modifier_parts: Array[String] = []
	for modifier_id: StringName in RUN_MODIFIER_STEPS.keys():
		var value: float = mission_select.get_run_modifier_value(modifier_id)
		if value != 0.0:
			modifier_parts.append("%s=%s" % [String(modifier_id), value])
	var modifier_text: String = ", ".join(modifier_parts) if not modifier_parts.is_empty() else "none"
	return "%s / %s / modifiers: %s" % [mission_name, _tier_display_name(mission_select.difficulty_tier), modifier_text]


func is_launch_armed() -> bool:
	return _launch_armed


# ---------------------------------------------------------------------------
# Focus ring (ADR-0011)
# ---------------------------------------------------------------------------

func _wire_focus_ring(button: Button) -> void:
	button.focus_entered.connect(_on_button_focus_changed.bind(button))
	button.focus_exited.connect(_on_button_focus_changed.bind(button))


func _on_button_focus_changed(_button: Button) -> void:
	pass  # focus-ring visual overlay omitted here -- no per-button ring node wired (see class doc comment on art scope); has_focus() itself still drives real keyboard/gamepad navigation correctly.


func _on_input_mode_changed(_mode: InputModeTracker.InputMode) -> void:
	pass


# ---------------------------------------------------------------------------
# Test/inspection accessors
# ---------------------------------------------------------------------------

func get_mission_button(mission_id: String) -> Button:
	return _mission_buttons.get(mission_id)


func get_tier_button(tier: int) -> Button:
	return _tier_buttons.get(tier)


func get_modifier_button(modifier_id: StringName) -> Button:
	return _modifier_buttons.get(modifier_id)


func get_background_color() -> Color:
	return _background.color


func get_launch_button() -> Button:
	return _launch_button
