class_name TowerMasteryFeedback
extends Node

## Story 013 (TR-towermast-001, ADR-0029): scene-instanced manager that
## creates, positions, and drives one TowerMasteryArc per currently-active
## build_signature. Driven entirely by EventBus events — never reaches into
## TowerMastery's private state, matching this project's EventBus-only
## cross-system convention (and avoiding any signal-connection-order
## dependency between this manager and the sibling TowerMastery node).
##
## Out of scope (this story's own Dependencies/Out-of-Scope, confirmed via
## codebase inspection before implementation): the skill_unlocked HUD
## corner callout — blocked, Mission HUD has no implementation anywhere in
## this codebase yet (only a placeholder Panel, per mission-hud.md's own
## tracked status) — and real audio stingers — blocked, no audio bible or
## sound assets exist yet. Both are documented gaps here and in
## production/qa/evidence/tower-mastery-visual-audio-feedback-evidence.md,
## not silently skipped.
##
## Paused-out-of-range detection: Story 010's tick() only emits
## mastery_progress_updated while a signature is actively accruing — there
## is no explicit "hero left range" event anywhere in event-bus.md's Tower
## Mastery row. This manager infers the out-of-range pause via a
## per-signature staleness timeout (no update received for
## STALE_THRESHOLD_SECONDS) rather than inventing a new EventBus signal not
## specified in that contract. This is a documented, testable heuristic —
## not frame-perfect detection — flagged for whoever revisits this if a
## real explicit "paused" signal is added later.

const STALE_THRESHOLD_SECONDS: float = 0.5

var _arcs: Dictionary[String, TowerMasteryArc] = {}
var _signature_by_tower: Dictionary[int, String] = {}
var _archetype_by_tower: Dictionary[int, String] = {}
var _cell_by_tower: Dictionary[int, Vector2i] = {}
var _last_update_seconds_by_signature: Dictionary[String, float] = {}
var _elapsed_seconds: float = 0.0

## DI seam — untyped so a RefCounted test double works in unit tests
## (mirrors tower_mastery.gd's own `_grid = null` convention).
var _grid = null


func _ready() -> void:
	_grid = GGrid
	GEventBus.tower_placed.connect(_on_tower_placed)
	GEventBus.tower_component_equipped.connect(_on_tower_component_equipped)
	GEventBus.tower_removed.connect(_on_tower_removed)
	GEventBus.tower_destroyed.connect(_on_tower_destroyed)
	GEventBus.mastery_progress_updated.connect(_on_mastery_progress_updated)
	GEventBus.skill_tree_point_earned.connect(_on_skill_tree_point_earned)
	GEventBus.skill_tree_overflow_point_earned.connect(_on_skill_tree_overflow_point_earned)


func _exit_tree() -> void:
	GEventBus.tower_placed.disconnect(_on_tower_placed)
	GEventBus.tower_component_equipped.disconnect(_on_tower_component_equipped)
	GEventBus.tower_removed.disconnect(_on_tower_removed)
	GEventBus.tower_destroyed.disconnect(_on_tower_destroyed)
	GEventBus.mastery_progress_updated.disconnect(_on_mastery_progress_updated)
	GEventBus.skill_tree_point_earned.disconnect(_on_skill_tree_point_earned)
	GEventBus.skill_tree_overflow_point_earned.disconnect(_on_skill_tree_overflow_point_earned)


func _on_tower_placed(payload: TowerPlacedEvent) -> void:
	_signature_by_tower[payload.tower_id] = TowerMastery.compute_build_signature(
		payload.foundation_component_id, payload.weapon_component_id,
		payload.focus_component_id, payload.power_component_id
	)
	_archetype_by_tower[payload.tower_id] = payload.archetype
	_cell_by_tower[payload.tower_id] = payload.grid_position


func _on_tower_component_equipped(payload: TowerComponentEquippedEvent) -> void:
	_signature_by_tower[payload.tower_id] = TowerMastery.compute_build_signature(
		payload.foundation_component_id, payload.weapon_component_id,
		payload.focus_component_id, payload.power_component_id
	)


func _on_tower_removed(tower_id: int, _grid_position: Vector2i, _archetype: String, _tag: String) -> void:
	_handle_tower_gone(tower_id)


func _on_tower_destroyed(tower_id: int, _grid_position: Vector2i, _archetype: String, _footprint: Array, _tag: String) -> void:
	_handle_tower_gone(tower_id)


## A tower vanishing while it was the visual anchor for its signature's arc
## plays the destroyed treatment immediately (no waiting for the next
## mastery_progress_updated). If another live tower still shares the
## signature and remains in range, TowerMastery's own next tick will emit a
## fresh mastery_progress_updated for it, which _on_mastery_progress_updated
## below repositions the arc to and reverts out of PAUSED_DESTROYED
## automatically — no special-casing needed here for that resumption case.
func _handle_tower_gone(tower_id: int) -> void:
	var signature: String = _signature_by_tower.get(tower_id, "")
	_signature_by_tower.erase(tower_id)
	_archetype_by_tower.erase(tower_id)
	_cell_by_tower.erase(tower_id)
	if signature == "":
		return
	var arc: TowerMasteryArc = _arcs.get(signature)
	if arc != null:
		arc.set_state(TowerMasteryArc.State.PAUSED_DESTROYED)


func _on_mastery_progress_updated(tower_id: int, skill_id: String, progress_percent: float) -> void:
	# Story 010's own placeholder scheme: build_signature doubles as skill_id
	# until a real skill catalogue exists (Rule 7/ADR-0030) — see
	# tower_mastery.gd's class doc comment for the precedent this follows.
	var signature: String = skill_id
	var arc: TowerMasteryArc = _get_or_create_arc(signature)
	arc.set_archetype(_archetype_by_tower.get(tower_id, ""))
	var cell: Vector2i = _cell_by_tower.get(tower_id, Vector2i.ZERO)
	arc.position = _grid.cell_to_world(cell)
	if arc.state != TowerMasteryArc.State.UNLOCKED_PULSE:
		arc.set_state(TowerMasteryArc.State.ACCRUING)
	arc.set_progress(progress_percent)
	_last_update_seconds_by_signature[signature] = _elapsed_seconds


## Pulses the source tower's own arc when its mastery threshold crossing
## grants an archetype-pool skill tree point. Replaces the pre-2026-08-31
## `skill_unlocked` hookup this manager originally shipped with: Tower
## Mastery no longer emits `skill_unlocked` at all (event-bus.md's own
## catalogue note) — a threshold crossing now grants a point via
## `skill_tree_point_earned`/`skill_tree_overflow_point_earned` instead, and
## Hero Skill Tree, not Tower Mastery, is the sole remaining emitter of
## `skill_unlocked` (fired on a node purchase, keyed by a real catalogue
## `skill_id`, not a build_signature — the old handler's `_arcs.get(skill_id)`
## lookup could never actually match this manager's signature-keyed `_arcs`
## dict once that redesign landed, silently dead code until this fix).
func _on_skill_tree_point_earned(_archetype: String, source_tower_id: int) -> void:
	_pulse_arc_for_tower(source_tower_id)


func _on_skill_tree_overflow_point_earned(source_tower_id: int) -> void:
	_pulse_arc_for_tower(source_tower_id)


func _pulse_arc_for_tower(tower_id: int) -> void:
	var signature: String = _signature_by_tower.get(tower_id, "")
	if signature == "":
		return
	var arc: TowerMasteryArc = _arcs.get(signature)
	if arc != null:
		arc.set_state(TowerMasteryArc.State.UNLOCKED_PULSE)


func _get_or_create_arc(signature: String) -> TowerMasteryArc:
	if _arcs.has(signature):
		return _arcs[signature]
	var arc := TowerMasteryArc.new()
	add_child(arc)
	_arcs[signature] = arc
	return arc


func _process(delta: float) -> void:
	_elapsed_seconds += delta
	var signatures_to_free: Array[String] = []
	for signature: String in _arcs:
		var arc: TowerMasteryArc = _arcs[signature]
		if arc.state == TowerMasteryArc.State.ACCRUING:
			var last: float = _last_update_seconds_by_signature.get(signature, 0.0)
			if _elapsed_seconds - last > STALE_THRESHOLD_SECONDS:
				arc.set_state(TowerMasteryArc.State.PAUSED_OUT_OF_RANGE)
		elif arc.is_fade_complete():
			signatures_to_free.append(signature)

	for signature: String in signatures_to_free:
		var arc: TowerMasteryArc = _arcs[signature]
		_arcs.erase(signature)
		_last_update_seconds_by_signature.erase(signature)
		arc.queue_free()
