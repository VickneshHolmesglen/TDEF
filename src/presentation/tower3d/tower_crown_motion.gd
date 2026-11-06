class_name TowerCrownMotion
extends Resource

## How one tower crown moves (ADR-0043, spec 2026-11-07-3d-towers-design §5.3).
## One optional .tres per crown key in DATA_DIR; any crown without a file gets
## the defaults (slow sentry sweep that turns to aim). Crown keys are weapon
## keys (&"siege") or family tops (&"top_octagon").

enum IdleMode { SWEEP, SPIN, NONE }

const DATA_DIR: String = "res://assets/data/tower3d/crown_motion/"

## SWEEP turns the whole crown; SPIN turns only spin_node (e.g. a crystal);
## NONE holds still while idle.
@export var idle_mode: IdleMode = IdleMode.SWEEP
## Degrees per second while idle (60 = one turn per 6 s).
@export var idle_speed_deg: float = 60.0
## Whether the crown turns to face targets.
@export var aims: bool = true
## Maximum degrees per second while turning toward a target.
@export var track_speed_deg: float = 270.0
## Child node of the crown that spins in SPIN mode.
@export var spin_node: StringName = &""


## Returns the authored motion for crown_key, or a fresh default instance.
## Never null, and never a shared default, so tuning one tower can't leak.
static func for_crown(crown_key: StringName) -> TowerCrownMotion:
	var path: String = DATA_DIR + String(crown_key) + ".tres"
	if ResourceLoader.exists(path):
		var loaded: TowerCrownMotion = load(path) as TowerCrownMotion
		if loaded != null:
			return loaded
	return TowerCrownMotion.new()
