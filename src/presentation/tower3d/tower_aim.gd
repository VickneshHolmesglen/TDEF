class_name TowerAim
extends RefCounted

## Aim and sentry-sweep maths for a 3D tower crown (ADR-0043,
## docs/superpowers/specs/2026-11-07-3d-towers-design.md §5.3).
##
## Pure state, no scene access, so the behaviour is testable without the
## engine running a scene. The owner (TowerModel3D) calls step() every frame
## and applies the returned yaw to the crown pivot.
##
## Yaw is radians about the 3D up axis; 0 means the crown front faces the
## camera (+Z, which is "down the screen" in 2D gameplay space).
## Aiming is visual only: nothing here gates firing.

## Current crown yaw, wrapped to [-PI, PI).
var yaw: float = 0.0
## Hd2dScenery's ground depth stretch (1 / sin(pitch)). 2D gameplay
## directions are converted to 3D angles through it so a crown points where a
## target is drawn, not where its unstretched 2D coordinates would put it.
var z_stretch: float = 1.0

var _idle_speed: float
var _track_speed: float
var _aims: bool
var _tracking: bool = false
var _target_yaw: float = 0.0
var _hold_left: float = 0.0


## idle_speed_deg / track_speed_deg: degrees per second while sweeping /
## while turning toward a target. aims: false for crowns that only idle
## (e.g. a spinning crystal) and never turn to face targets.
func _init(start_yaw: float, idle_speed_deg: float, track_speed_deg: float, aims: bool) -> void:
	yaw = wrapf(start_yaw, -PI, PI)
	_idle_speed = deg_to_rad(idle_speed_deg)
	_track_speed = deg_to_rad(track_speed_deg)
	_aims = aims


## Starts or refreshes tracking toward a 2D gameplay-space direction. Tracking
## ends when hold_seconds pass without another call. Ignored when the crown
## does not aim.
func set_target(direction_2d: Vector2, hold_seconds: float) -> void:
	if not _aims or direction_2d == Vector2.ZERO:
		return
	_target_yaw = yaw_for_direction(direction_2d, z_stretch)
	_hold_left = hold_seconds
	_tracking = true


## Drops the current target; the crown resumes sweeping from where it points.
func clear_target() -> void:
	_tracking = false
	_hold_left = 0.0


func is_tracking() -> bool:
	return _tracking


## Advances by delta seconds and returns the new yaw.
func step(delta: float) -> float:
	if _tracking:
		yaw = turn_toward(yaw, _target_yaw, _track_speed * delta)
		_hold_left -= delta
		if _hold_left <= 0.0:
			_tracking = false
	else:
		yaw += _idle_speed * delta
	yaw = wrapf(yaw, -PI, PI)
	return yaw


## Yaw that points the crown front along a 2D gameplay direction, with the
## depth axis stretched the way Hd2dScenery.to_world() stretches it.
static func yaw_for_direction(direction_2d: Vector2, stretch: float) -> float:
	return atan2(direction_2d.x, direction_2d.y * stretch)


## Moves current toward target by at most max_step radians, the short way
## round, without overshooting.
static func turn_toward(current: float, target: float, max_step: float) -> float:
	var diff: float = wrapf(target - current, -PI, PI)
	if absf(diff) <= max_step:
		return current + diff
	return current + signf(diff) * max_step
