extends CanvasLayer

## Pause Menu — ADR-0014 (Accepted 2026-07-08), closes TD-pause-001.
##
## GDD source: design/gdd/event-bus.md Pause System section.
## UX source: design/ux/pause-menu.md (scoped down: Resume + Quit to Sanctuary only —
## Settings, Objective, and Quit to Main Menu deferred per user decision 2026-07-08,
## since none of Settings, Objective, or a Main Menu scene exist as systems yet).
##
## SceneTree.paused is the single source of truth for "the game is paused" — every
## other node in the tree uses the default process_mode (PROCESS_MODE_INHERIT) and
## halts automatically. This node is the ONLY process_mode override in the codebase:
## PROCESS_MODE_ALWAYS keeps it receiving input and rendering while the tree is paused.
##
## No class_name declared — deliberately, per TD-workflow-001 (a recurring Godot
## 4.6.2 class-cache fragility where a fresh class_name isn't picked up by a bare
## headless boot). This scene is only ever instanced directly, never referenced by
## static type, so a class_name is not needed.

@onready var _dim_overlay: ColorRect = $DimOverlay
@onready var _resume_button: Button = $ButtonStack/ResumeButton
@onready var _quit_to_sanctuary_button: Button = $ButtonStack/QuitToSanctuaryButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_resume_button.pressed.connect(_on_resume_pressed)
	_quit_to_sanctuary_button.pressed.connect(_on_quit_to_sanctuary_pressed)


func _exit_tree() -> void:
	_resume_button.pressed.disconnect(_on_resume_pressed)
	_quit_to_sanctuary_button.pressed.disconnect(_on_quit_to_sanctuary_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()


## Toggle convention (UX spec): the same `pause` input both opens and closes this
## screen — pressing it again resumes without navigating to the Resume button.
func _toggle_pause() -> void:
	var new_paused: bool = not get_tree().paused
	get_tree().paused = new_paused
	visible = new_paused
	if new_paused:
		GEventBus.game_paused.emit()
	else:
		GEventBus.game_unpaused.emit()


func _on_resume_pressed() -> void:
	_toggle_pause()


func _on_quit_to_sanctuary_pressed() -> void:
	# Unpause before leaving — a mission scene must never hand control to
	# SceneManager while the tree is still paused.
	get_tree().paused = false
	visible = false
	GEventBus.game_unpaused.emit()
	GSceneManager.transition_to_sanctuary()
