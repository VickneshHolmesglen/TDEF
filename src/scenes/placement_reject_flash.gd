class_name PlacementRejectFlash
extends Node2D

## Purely cosmetic footprint-cell flash for a rejected tower placement.
## design/gdd/tower.md "Placement Rejected" Visual/Audio Requirements:
## "Footprint cells flash red (2–3 rapid pulses, ~0.4s), then return to
## normal grid state." Spawned directly by mission_scene.gd's
## _attempt_placement_at() on a false return from TowerSystem.place_tower()
## — that call already has the exact cell/footprint the player tried and
## rejects silently otherwise (no rejection event exists to hook into
## instead, nor is one needed for a purely cosmetic reaction).

const DURATION: float = 0.4  ## seconds, per the GDD's own "~0.4s" spec
const PULSE_COUNT: float = 2.5  ## "2-3 rapid pulses" — 2.5 full cycles reads as 2-3 flashes
const FLASH_COLOR: Color = Color(0.9, 0.15, 0.15, 0.5)

var _footprint_size: Vector2 = Vector2(64.0, 64.0)  ## world units
var _elapsed: float = 0.0


## footprint_size: world units (WeaponComponent footprint already scaled by
## CELL_SIZE by the caller) — the rect this flash covers, centered on this
## node's own position (which the caller sets to the attempted footprint's
## world-space center, matching TowerInstance's own centering convention).
func configure(footprint_size: Vector2) -> void:
	_footprint_size = footprint_size


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = _elapsed / DURATION
	# Pulses via a rectified sine wave -- visible for roughly the first half
	# of each pulse cycle, invisible for the second half, fading the whole
	# thing out toward the end so the last pulse doesn't cut off abruptly.
	var wave: float = sin(t * PULSE_COUNT * TAU)
	if wave <= 0.0:
		return
	var color: Color = FLASH_COLOR
	color.a *= wave * (1.0 - t)
	var half: Vector2 = _footprint_size * 0.5
	draw_rect(Rect2(-half, _footprint_size), color, true)
