extends Node

## Minimal fixture scene for S4-01 SceneManager tests. Content is irrelevant —
## only used to prove transition_to_mission()/transition_to_sanctuary() can
## load and swap to a real PackedScene since MissionScene.tscn/SanctuaryScene.tscn
## don't exist yet (assembled in S4-09).

var ready_fired: bool = false


func _ready() -> void:
	ready_fired = true
