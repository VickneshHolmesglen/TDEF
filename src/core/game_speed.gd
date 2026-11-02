class_name GameSpeed
extends Node
## Mission fast-forward: cycles Engine.time_scale through SPEEDS (1x, 2x, 3x).
##
## Mission-scoped: MissionScene creates one in _ready(). Joins GROUP_NAME so the
## HUD's speed button can find it without a scene-path dependency (the same
## group-lookup pattern as SetEffectController). Always restores 1x when the
## mission ends (outcome screens and the Sanctuary run at normal speed) and when
## it leaves the tree, so a 3x setting can never leak into menus.
##
## Engine.time_scale scales every process/physics delta, Tween and SceneTreeTimer,
## so combat, cooldowns, wave timers and VFX all speed up together. Pausing is
## separate (SceneTree.paused) and unaffected.
##
## Usage: GameSpeed.find(get_tree()).cycle()

signal speed_changed(multiplier: float)

const GROUP_NAME: StringName = &"game_speed"
const SPEEDS: Array[float] = [1.0, 2.0, 3.0]
const END_PHASES: Array[String] = ["MISSION_COMPLETE", "DEFEAT", "SANCTUARY"]

var _index: int = 0


static func find(tree: SceneTree) -> GameSpeed:
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP_NAME) as GameSpeed


func _ready() -> void:
	add_to_group(GROUP_NAME)
	GEventBus.mission_phase_changed.connect(_on_mission_phase_changed)


func _exit_tree() -> void:
	if GEventBus.mission_phase_changed.is_connected(_on_mission_phase_changed):
		GEventBus.mission_phase_changed.disconnect(_on_mission_phase_changed)
	Engine.time_scale = 1.0


func get_multiplier() -> float:
	return SPEEDS[_index]


## Advances to the next speed, wrapping 3x back to 1x. Returns the new multiplier.
func cycle() -> float:
	set_speed_index((_index + 1) % SPEEDS.size())
	return get_multiplier()


func set_speed_index(index: int) -> void:
	_index = clampi(index, 0, SPEEDS.size() - 1)
	Engine.time_scale = SPEEDS[_index]
	speed_changed.emit(SPEEDS[_index])


func _on_mission_phase_changed(_previous_phase: String, new_phase: String, _timestamp: float) -> void:
	if new_phase in END_PHASES and _index != 0:
		set_speed_index(0)
