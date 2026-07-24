class_name TowerMasteryArc
extends Node2D

## Story 013 (TR-towermast-001, ADR-0029): in-combat proximity arc — a
## world-space, tower-anchored, non-color-legible visual for one
## build_signature's live mastery progress. Pure view component: owns no
## EventBus subscriptions itself. `TowerMasteryFeedback` (the scene-instanced
## manager) creates, positions, and drives instances of this class from
## Story 010's `mastery_progress_updated`/`skill_unlocked` events.
##
## Colors sourced from design/art/art-bible.md — Sanctum Amber #C8801A,
## Fieldstone Grey #7E8590. Herald Gold is explicitly excluded per this
## story's ADR Decision Summary (reserved for a different semantic register
## — MISSION_COMPLETE/crit, not live mastery progress).
##
## Accessibility (art bible Section 4.5, this story's Guardrail): every
## state differs via opacity and/or animated motion, never hue alone —
## ACCRUING vs PAUSED_OUT_OF_RANGE differ only by opacity; PAUSED_DESTROYED
## and UNLOCKED_PULSE each add an animated transition on top of any color
## shift.
##
## Archetype glyph: no real per-archetype glyph asset catalogue exists yet
## (mirrors the skill catalogue's own deferred-content status, Story
## 010/ADR-0030) — the center glyph renders as a placeholder filled circle.
## Swap `_draw_glyph()`'s body when real glyph assets land.
##
## Exact timing/opacity values below are a first-pass, honestly-flagged
## placeholder tuning — this story's own manual QA checks (arc legibility,
## colorblind-filter pass) require a human tester to actually verify look
## and feel; see production/qa/evidence/tower-mastery-visual-audio-feedback-evidence.md
## for what could and could not be verified without one.

enum State { ACCRUING, PAUSED_OUT_OF_RANGE, PAUSED_DESTROYED, UNLOCKED_PULSE }

## Fixed screen-space size — does not scale with camera zoom (this story's
## own "never scale with zoom" requirement). Counter-scaling against a live
## Camera2D.zoom is left as a TODO for whoever wires this into a real
## mission scene with an actual camera to read from; this class renders at
## a fixed local-pixel radius, which is correct as long as the camera never
## zooms (true of every mission scene shipped in this project so far).
const ARC_RADIUS_PX: float = 18.0
const ARC_WIDTH_PX: float = 3.0
const ARC_SEGMENTS: int = 48

const SANCTUM_AMBER: Color = Color(0.784313725, 0.501960784, 0.101960784, 1.0)
const FIELDSTONE_GREY: Color = Color(0.494117647, 0.52156863, 0.564705882, 1.0)
const TRACK_COLOR: Color = Color(0.494117647, 0.52156863, 0.564705882, 0.25)
const GLYPH_PLACEHOLDER_COLOR: Color = Color(0.784313725, 0.501960784, 0.101960784, 0.9)

## AC: paused-out-of-range freezes fill, opacity ~100%->~55%, no motion/color shift.
const PAUSED_OUT_OF_RANGE_OPACITY: float = 0.55

## AC: source-tower-destroyed -> Fieldstone Grey desaturate-and-fade (~0.5s).
const DESTROYED_FADE_SECONDS: float = 0.5

## AC: skill_unlocked -> brief intensify-and-pulse (~0.5-1s), matching
## Constellation's own pacing rule, then clears back to normal ACCRUING fill.
const PULSE_DURATION_SECONDS: float = 0.75

var progress_percent: float = 0.0
var state: State = State.ACCRUING

var _destroyed_fade_elapsed: float = 0.0
var _pulse_elapsed: float = 0.0


func set_progress(percent: float) -> void:
	progress_percent = clampf(percent, 0.0, 100.0)
	queue_redraw()


func set_state(new_state: State) -> void:
	state = new_state
	if new_state == State.PAUSED_DESTROYED:
		_destroyed_fade_elapsed = 0.0
	elif new_state == State.UNLOCKED_PULSE:
		_pulse_elapsed = 0.0
	queue_redraw()


## True once the destroyed-fade has fully played out — the manager frees
## the arc at this point rather than leaving a fully-faded node lingering.
func is_fade_complete() -> bool:
	return state == State.PAUSED_DESTROYED and _destroyed_fade_elapsed >= DESTROYED_FADE_SECONDS


func _process(delta: float) -> void:
	match state:
		State.PAUSED_DESTROYED:
			if _destroyed_fade_elapsed < DESTROYED_FADE_SECONDS:
				_destroyed_fade_elapsed = minf(_destroyed_fade_elapsed + delta, DESTROYED_FADE_SECONDS)
				queue_redraw()
		State.UNLOCKED_PULSE:
			_pulse_elapsed += delta
			if _pulse_elapsed >= PULSE_DURATION_SECONDS:
				state = State.ACCRUING
			queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, ARC_RADIUS_PX, 0.0, TAU, ARC_SEGMENTS, TRACK_COLOR, ARC_WIDTH_PX, true)

	if progress_percent > 0.0:
		var start_angle: float = -PI / 2.0  # 12 o'clock
		var end_angle: float = start_angle + (progress_percent / 100.0) * TAU
		var segment_count: int = maxi(2, int(ARC_SEGMENTS * progress_percent / 100.0))
		draw_arc(Vector2.ZERO, ARC_RADIUS_PX, start_angle, end_angle, segment_count, _current_fill_color(), ARC_WIDTH_PX, true)

	_draw_glyph()


func _current_fill_color() -> Color:
	match state:
		State.PAUSED_OUT_OF_RANGE:
			return Color(SANCTUM_AMBER.r, SANCTUM_AMBER.g, SANCTUM_AMBER.b, SANCTUM_AMBER.a * PAUSED_OUT_OF_RANGE_OPACITY)
		State.PAUSED_DESTROYED:
			var t: float = _destroyed_fade_elapsed / DESTROYED_FADE_SECONDS
			var desaturated: Color = SANCTUM_AMBER.lerp(FIELDSTONE_GREY, t)
			return Color(desaturated.r, desaturated.g, desaturated.b, lerpf(1.0, 0.0, t))
		State.UNLOCKED_PULSE:
			var pulse_t: float = _pulse_elapsed / PULSE_DURATION_SECONDS
			var intensity: float = sin(pulse_t * PI)  # single 0->1->0 hump, one pulse
			return SANCTUM_AMBER.lerp(Color.WHITE, intensity * 0.5)
		_:
			return SANCTUM_AMBER


func _draw_glyph() -> void:
	draw_circle(Vector2.ZERO, ARC_RADIUS_PX * 0.35, GLYPH_PLACEHOLDER_COLOR)
