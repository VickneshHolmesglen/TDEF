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
## - Mission cards show each MissionEntry.icon (painted mission_card art) in a
##   2-column grid (2026-10-10 relayout). No completion mini-table rendering
##   (checkmark/dash/lock per tier) — completion state is plain text on the
##   card (best time or "—" per tier).
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
@onready var _header_label: Label = $MainLayout/HeaderLabel
@onready var _mission_list_panel: PanelContainer = $MainLayout/TopRow/MissionListPanel
@onready var _mission_list: GridContainer = $MainLayout/TopRow/MissionListPanel/MissionList
@onready var _right_panel: PanelContainer = $MainLayout/TopRow/RightPanel
@onready var _browse_hint: Label = $MainLayout/TopRow/RightPanel/BrowseHint
@onready var _config_panel: Control = $MainLayout/TopRow/RightPanel/ConfigPanel
@onready var _mission_title_label: Label = $MainLayout/TopRow/RightPanel/ConfigPanel/MissionTitleLabel
@onready var _objective_label: Label = $MainLayout/TopRow/RightPanel/ConfigPanel/ObjectiveLabel
@onready var _difficulty_header: Label = $MainLayout/TopRow/RightPanel/ConfigPanel/DifficultyHeader
@onready var _tier_row: HBoxContainer = $MainLayout/TopRow/RightPanel/ConfigPanel/TierRow
@onready var _modifier_header: Label = $MainLayout/TopRow/RightPanel/ConfigPanel/ModifierHeader
@onready var _modifier_row: VBoxContainer = $MainLayout/TopRow/RightPanel/ConfigPanel/ModifierRow
@onready var _back_button: Button = $MainLayout/TopRow/RightPanel/ConfigPanel/BackButton
@onready var _launch_button: Button = $MainLayout/LaunchBar/LaunchButton
@onready var _launch_recap_label: Label = $MainLayout/LaunchBar/RecapLabel

## Panels sit one shade darker than the UI_CHROME background so the two
## regions read as distinct surfaces (2026-10-10 relayout, docs/images/UX
## fix.PNG -- the old list panel used Godot's default panel, the config
## column had no surface at all).
const PANEL_SHADE: float = 0.25
const MISSION_CARD_FONT_SIZE: int = 18
const SECTION_HEADER_ALPHA: float = 0.7

var _mission_buttons: Dictionary[String, Button] = {}
var _tier_buttons: Dictionary[int, Button] = {}
var _modifier_buttons: Dictionary[StringName, Button] = {}
var _launch_armed: bool = false


func _ready() -> void:
	if mission_select == null:
		mission_select = GMissionSelect

	_background.color = ShellChromeStyle.UI_CHROME
	_apply_chrome_styles()

	_input_mode_tracker.input_mode_changed.connect(_on_input_mode_changed)
	_back_button.pressed.connect(_on_back_pressed)
	_back_button.set_meta(UiAudioBinder.META_KEY, UiAudioBinder.KIND_CANCEL)
	_launch_button.pressed.connect(_on_launch_pressed)
	_launch_button.set_meta(UiAudioBinder.META_KEY, UiAudioBinder.KIND_CONFIRM)
	for tier: int in [1, 2, 3]:
		_tier_buttons[tier] = _create_tier_button(tier)
	for modifier_id: StringName in RUN_MODIFIER_STEPS.keys():
		_modifier_buttons[modifier_id] = _create_modifier_button(modifier_id)

	GEventBus.mission_selected.connect(_on_mission_selected)
	GEventBus.run_modifier_selected.connect(_on_run_modifier_selected)

	_rebuild_mission_list()
	_refresh_config_panel()


func _apply_chrome_styles() -> void:
	# HD-2D UI skin (2026-10-12): studded gold-rule panels, Cinzel headings.
	for panel: PanelContainer in [_mission_list_panel, _right_panel]:
		var box: StyleBoxTexture = ShellChromeStyle.skin_panel()
		box.set_content_margin_all(16.0)
		panel.add_theme_stylebox_override("panel", box)

	_header_label.theme_type_variation = &"TitleLabel"
	_mission_title_label.theme_type_variation = &"HeaderLabel"
	for label: Label in [_browse_hint, _objective_label, _launch_recap_label]:
		label.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
	for header: Label in [_difficulty_header, _modifier_header]:
		header.theme_type_variation = &"HeaderLabel"

	_back_button.custom_minimum_size = Vector2(0, 40)
	_back_button.add_theme_stylebox_override("normal", _padded_outline_stylebox())

	# Primary action: the same Sanctum Amber launch styling the Sanctuary's
	# own Launch Mission button uses; disabled (dimmed) until a mission is
	# chosen so it never reads as live-but-inert while browsing.
	var launch_box: StyleBoxTexture = ShellChromeStyle.skin_button(&"active")
	launch_box.content_margin_left = 24
	launch_box.content_margin_right = 24
	_launch_button.add_theme_stylebox_override("normal", launch_box)
	_launch_button.add_theme_stylebox_override("hover", launch_box)
	_launch_button.add_theme_stylebox_override("pressed", ShellChromeStyle.skin_button(&"pressed"))
	_launch_button.add_theme_stylebox_override("disabled", ShellChromeStyle.skin_button(&"disabled"))
	_launch_button.add_theme_stylebox_override("focus", ShellChromeStyle.skin_focus())


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

## One card per mission in a 2-column grid that fills the whole left panel
## (2026-10-10 relayout -- the old one-line text rows left ~75% of the panel
## blank and showed the painted mission_card art only as a 32 px icon). The
## card IS the Button (art as its expand_icon, name + status as its text), so
## _mission_buttons/get_mission_button() and press/focus wiring are unchanged.
## entry.icon == null renders a text-only card, not an error -- matches
## MissionEntry.icon's own doc comment.
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
		_mission_list.add_child(button)
		_mission_buttons[mission_id] = button


func _create_mission_button(entry: MissionEntry) -> Button:
	var button := Button.new()
	button.name = "Mission_%s" % entry.mission_id
	button.focus_mode = Control.FOCUS_ALL
	button.toggle_mode = true  # pressed state marks the selected mission
	button.text = _mission_entry_text(entry)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.icon = entry.icon
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", MISSION_CARD_FONT_SIZE)
	button.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
	button.add_theme_color_override("font_pressed_color", ShellChromeStyle.UI_PARCHMENT)
	button.add_theme_color_override("font_hover_pressed_color", ShellChromeStyle.UI_PARCHMENT)
	var selected_box: StyleBox = _mission_card_stylebox(true)
	button.add_theme_stylebox_override("normal", _mission_card_stylebox(false))
	button.add_theme_stylebox_override("hover", ShellChromeStyle.skin_button(&"hover"))
	button.add_theme_stylebox_override("pressed", selected_box)
	button.add_theme_stylebox_override("hover_pressed", selected_box)
	button.add_theme_stylebox_override("focus", ShellChromeStyle.skin_focus())
	button.pressed.connect(_on_mission_pressed.bind(entry.mission_id))
	_wire_focus_ring(button)
	return button


## Outlined chrome button with side padding so left-aligned text doesn't sit
## on the border.
static func _padded_outline_stylebox() -> StyleBox:
	return ShellChromeStyle.skin_button(&"normal")


## Selected = warm amber fill with a lit gold rule, idle = navy with a bronze
## rule -- a fill change, not colour of a line alone (filled-vs-outline
## convention). HD-2D skin frames since 2026-10-12.
static func _mission_card_stylebox(selected: bool) -> StyleBox:
	var box: StyleBoxTexture = ShellChromeStyle.skin_button(&"active" if selected else &"normal")
	box.set_content_margin_all(10.0)
	return box


## GDD: "fully covered on the mission card itself" — 3-tier best-time summary,
## plain text (no mini-table art, see class doc comment).
## Readable form (2026-10-04 smoke check; was "The Gap (T1:-- T2:-- T3:--)"):
## "Not yet cleared" until any tier is beaten, then per-tier best times.
## Name and summary on separate lines so the card never truncates either.
func _mission_entry_text(entry: MissionEntry) -> String:
	var parts: Array[String] = []
	var any_completed: bool = false
	for tier: int in [1, 2, 3]:
		var record: MissionCompletionRecord = mission_select.get_completion_record(entry.mission_id, tier)
		any_completed = any_completed or record.completed
		var time_text: String = ("%.1fs" % record.best_time_seconds) if record.completed else tr("MISSION_SELECT_TIER_UNCLEARED")
		parts.append(tr("MISSION_SELECT_TIER_TIME") % [_tier_display_name(tier), time_text])
	var summary: String = "   ".join(parts) if any_completed else tr("MISSION_SELECT_NOT_CLEARED")
	return "%s\n%s" % [entry.display_name, summary]


func _on_mission_pressed(mission_id: String) -> void:
	mission_select.select_mission(mission_id)


# ---------------------------------------------------------------------------
# Difficulty + modifiers panel (right region) — empty until a mission is
# selected, per the GDD's own progressive-disclosure requirement
# ---------------------------------------------------------------------------

func _refresh_config_panel() -> void:
	var configuring: bool = mission_select.state == MissionSelect.State.CONFIGURING
	_config_panel.visible = configuring
	_browse_hint.visible = not configuring
	_launch_button.disabled = not configuring
	var current_id: String = mission_select.get_current_mission_id() if configuring else ""
	for mission_id: String in _mission_buttons:
		_mission_buttons[mission_id].set_pressed_no_signal(mission_id == current_id)
	if not configuring:
		return
	var entry: MissionEntry = GGameDataRegistry.get_mission_entry(current_id)
	_mission_title_label.text = entry.display_name if entry != null else current_id
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
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # 3 equal-width buttons, never clipped
	button.custom_minimum_size = Vector2(0, 40)
	button.add_theme_stylebox_override("focus", ShellChromeStyle.skin_focus())
	button.pressed.connect(_on_tier_pressed.bind(tier))
	_wire_focus_ring(button)
	_tier_row.add_child(button)
	return button


## Selected tier = filled the accent colour, others outlined (filled-vs-outline,
## never color-only). Replaces the old "Normal (selected)" text tag, which
## pushed the tier row wider than the column and clipped it.
func _refresh_tier_button_labels() -> void:
	for tier: int in _tier_buttons.keys():
		var button: Button = _tier_buttons[tier]
		var selected: bool = mission_select.difficulty_tier == tier
		button.text = _tier_display_name(tier)
		var box: StyleBox = ShellChromeStyle.skin_button_for(selected)
		button.add_theme_stylebox_override("normal", box)
		button.add_theme_stylebox_override("hover", box)


func _tier_display_name(tier: int) -> String:
	match tier:
		1: return tr("MISSION_SELECT_TIER_NORMAL")
		2: return tr("MISSION_SELECT_TIER_HARD")
		3: return tr("MISSION_SELECT_TIER_BRUTAL")
		_: return tr("MISSION_SELECT_TIER_GENERIC") % tier


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
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 40)
	button.add_theme_stylebox_override("normal", _padded_outline_stylebox())
	button.add_theme_stylebox_override("focus", ShellChromeStyle.skin_focus())
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
		button.text = "%s: %s" % [_modifier_display_name(modifier_id), _step_label(step_index)]


func _step_label(step_index: int) -> String:
	match step_index:
		0: return tr("MISSION_SELECT_STEP_OFF")
		1: return tr("MISSION_SELECT_STEP_LOW")
		2: return tr("MISSION_SELECT_STEP_HIGH")
		_: return "?"


## Readable modifier name ("Extend Waves") instead of the raw id.
static func _modifier_display_name(modifier_id: StringName) -> String:
	return String(modifier_id).capitalize()


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
	_launch_button.text = tr("MISSION_SELECT_LAUNCH")


func _on_launch_pressed() -> void:
	if not _launch_armed:
		if mission_select.state != MissionSelect.State.CONFIGURING:
			return  # disabled/no-op until both a mission and tier are selected
		_launch_armed = true
		_launch_recap_label.text = _build_recap_text()
		_launch_button.text = tr("MISSION_SELECT_CONFIRM_LAUNCH")
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
			var step_index: int = (RUN_MODIFIER_STEPS[modifier_id] as Array).find(value)
			modifier_parts.append("%s: %s" % [_modifier_display_name(modifier_id), _step_label(step_index) if step_index != -1 else str(value)])
	var modifier_text: String = ", ".join(modifier_parts) if not modifier_parts.is_empty() else tr("MISSION_SELECT_MODIFIERS_NONE")
	return tr("MISSION_SELECT_RECAP") % [mission_name, _tier_display_name(mission_select.difficulty_tier), modifier_text]


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
