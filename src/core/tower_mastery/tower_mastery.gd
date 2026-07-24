class_name TowerMastery
extends Node

## Tower Mastery proximity-detection layer (Story 007, TR-towermast-001,
## ADR-0029). Scene-instanced — NOT an Autoload.
##
## GDD source: design/gdd/tower-mastery.md
##
## Scope of Sprint 6 S6-10: the shared proximity radius constant and the
## Hero-independent accumulator contract (Story 007, AC-01 through AC-06).
## Story 008 (Sprint 7, S7-implement-story-008) was Blocked on a genuine
## Tower System data-model gap at S6-10 time — confirmed via direct source
## inspection that `TowerData` had NO component-slot fields at all. That gap
## was resolved in ADR-0008's implementation catch-up (Sprint 7, S7-01):
## `FoundationComponent`/`WeaponComponent`/`FocusComponent`/`PowerComponent`
## now exist, each with a `component_id` field, and `tower_placed`/
## `tower_component_equipped` were promoted to Resource payloads carrying
## the 4 `*_component_id` fields Formula 4 needs.
##
## `_active_signature_by_tower` is now populated for real from
## `tower_placed`/`tower_component_equipped`'s payloads (AC-11/AC-12) — no
## longer a test-injected-only seam, though tests may still set it directly
## for scenarios that don't need the full event round-trip.
##
## Story 009 (TR-towermast-001, ADR-0029/ADR-0005/ADR-0020): `_signatures_in_range`
## is recomputed on `hero_position_changed` (cell-boundary crossing) AND
## immediately on all 4 tower lifecycle events (tower_placed, tower_removed,
## tower_destroyed, tower_component_equipped), using the hero's last-known
## in-bounds cell — never on a per-frame tick (GDD Rule 9's load-bearing
## performance claim). tower_removed/tower_destroyed now also erase the
## affected tower_id from `_active_signature_by_tower`.
##
## bonus/skill placeholder note: `skill_unlocked`/`mastery_progress_updated`'s
## real `skill_id` requires a build_signature -> skill catalogue lookup that
## is explicitly deferred content (Story 010/ADR-0030, "Skill catalogue
## content... deferred as a content deliverable"). This file emits both
## events using the signature itself as a placeholder `skill_id` — inert
## until a real catalogue exists, matching Constellation's own
## BONUS_TYPE_PLACEHOLDER precedent (ADR-0022 gap, same session). Both
## events' `tower_id`/`source_tower_id` use the lowest live tower_id
## currently sharing that signature (`_representative_tower_id_for`,
## Story 010 Rules 12/13), not a hardcoded value.
##
## Story 011 (TR-towermast-003, ADR-0029, ADR-0003): implements the
## SaveRestorer interface — `mastery_time`/`unlocked_skills` are the two
## persisted, cross-mission structures, registered at `restore_order=34`
## (corrected from the GDD's self-proposed 31, which collided with Hero
## Skill Build's already-assigned 31 — see `save-persistence.md`'s
## authoritative band table). Neither structure is ever cleared by mission
## end (COMPLETE/DEFEAT/abandon) — only `reset_to_defaults()` (a brand-new
## adventure) clears them. "Pause, not reset" (AC-13/14/15) requires no
## special-casing here: mastery_time/_active_signature_by_tower are already
## never mutated by a tower vanishing (Story 009) or the hero leaving range
## (Story 007/009) — only `_signatures_in_range` changes, so accrual simply
## stops until a matching-signature tower re-enters range.

## AC-01: same registered radius as Hero's Tower-Synced Class proximity —
## a single shared source (Hero.CLASS_PROXIMITY_RADIUS), not an
## independently-tuned literal that happens to match (ADR-0029 Decision).
const TOWER_MASTERY_PROXIMITY_RADIUS: int = Hero.CLASS_PROXIMITY_RADIUS

const MASTERY_THRESHOLD_SECONDS: float = 45.0

## Story 011: `save-persistence.md`'s authoritative, collision-corrected
## value — restores after Hero (30), Hero Skill Build (31), Equipment
## Forge (32).
const RESTORE_ORDER: int = 34

## AC-04/AC-05: fully independent of Hero's own `_proximity_time` — a
## separate Dictionary, keyed by `build_signature` (not archetype/tower_type).
var mastery_time: Dictionary[String, float] = {}

## Populated by tower_placed/tower_component_equipped; erased on
## tower_removed/tower_destroyed (Story 009).
var _active_signature_by_tower: Dictionary[int, String] = {}

## Recomputed on hero_position_changed (cell-boundary crossing) and
## immediately on all 4 tower lifecycle events (Story 009), using the
## hero's last-known in-bounds cell.
var _signatures_in_range: Dictionary[String, bool] = {}

var _current_phase: String = ""
var _unlocked_signatures: Dictionary[String, bool] = {}

## Story 009: hero's last-known IN-BOUNDS cell, used to recompute
## `_signatures_in_range` immediately on tower lifecycle events (a tower
## vanishing/appearing under a stationary hero must be reflected the same
## frame). `_has_hero_cell` distinguishes "never received a valid position
## yet" from Vector2i.ZERO being a legitimate cell.
var _last_hero_cell: Vector2i = Vector2i.ZERO
var _has_hero_cell: bool = false

## Story 011 (AC-18): orphaned-skill_id handling on restore. No real skill
## catalogue (`SkillDefinitionResource`) exists yet — deferred content,
## Rule 7/ADR-0030. This pair is a DI seam (mirrors `_grid`'s pattern):
## `_has_skill_catalogue` defaults false, meaning no catalogue exists to
## check against yet, so restore never false-flags a legitimately-earned
## skill_id as unknown. Tests (and, later, the real catalogue system) set
## `_has_skill_catalogue = true` and populate `_known_skill_ids` to exercise
## the orphan path.
var _has_skill_catalogue: bool = false
var _known_skill_ids: Dictionary[String, bool] = {}

## Orphaned `unlocked_skills` entries from the most recent restore — never
## discarded, but excluded from any future Hero Skill Build UI consumption
## while unknown (AC-18).
var _unknown_skills: Dictionary[String, bool] = {}

## DI seam — untyped so a RefCounted test double works in unit tests
## (mirrors tower_system.gd's `_grid = null` convention).
var _grid = null


func _ready() -> void:
	_grid = GGrid
	GEventBus.hero_position_changed.connect(_on_hero_position_changed)
	GEventBus.mission_phase_changed.connect(_on_mission_phase_changed)
	GEventBus.tower_placed.connect(_on_tower_placed)
	GEventBus.tower_component_equipped.connect(_on_tower_component_equipped)
	GEventBus.tower_removed.connect(_on_tower_removed)
	GEventBus.tower_destroyed.connect(_on_tower_destroyed)
	GSavePersistence.register(self, RESTORE_ORDER)


func _exit_tree() -> void:
	GEventBus.hero_position_changed.disconnect(_on_hero_position_changed)
	GEventBus.mission_phase_changed.disconnect(_on_mission_phase_changed)
	GEventBus.tower_placed.disconnect(_on_tower_placed)
	GEventBus.tower_component_equipped.disconnect(_on_tower_component_equipped)
	GEventBus.tower_removed.disconnect(_on_tower_removed)
	GEventBus.tower_destroyed.disconnect(_on_tower_destroyed)
	GSavePersistence.unregister(self)


## Formula 4 (Story 008): build_signature = the 4 slots' component_id values
## joined by "|". Assumption (flagged in the story's own Implementation
## Notes): component_id strings never contain a "|" delimiter.
static func compute_build_signature(foundation_component_id: String, weapon_component_id: String,
		focus_component_id: String, power_component_id: String) -> String:
	return "%s|%s|%s|%s" % [foundation_component_id, weapon_component_id, focus_component_id, power_component_id]


## AC-11: reads the 4 loadout fields directly from the payload and populates
## _active_signature_by_tower[tower_id] per Formula 4 — no separate query call.
## Story 009: also recomputes _signatures_in_range immediately (a tower
## appearing under a stationary hero must be reflected the same frame).
func _on_tower_placed(payload: TowerPlacedEvent) -> void:
	_active_signature_by_tower[payload.tower_id] = compute_build_signature(
		payload.foundation_component_id, payload.weapon_component_id,
		payload.focus_component_id, payload.power_component_id
	)
	_recompute_if_hero_known()


## AC-12: component swap recomputes build_signature for the affected tower_id.
## mastery_time under the OLD signature is left untouched (no retroactive
## transfer) — mastery_time is keyed by signature, not tower_id, so simply
## repointing _active_signature_by_tower to the new signature achieves this
## with no extra bookkeeping: future accrual credits the new signature,
## past accrual under the old signature remains exactly where it was.
## Story 009: also recomputes _signatures_in_range immediately.
func _on_tower_component_equipped(payload: TowerComponentEquippedEvent) -> void:
	_active_signature_by_tower[payload.tower_id] = compute_build_signature(
		payload.foundation_component_id, payload.weapon_component_id,
		payload.focus_component_id, payload.power_component_id
	)
	_recompute_if_hero_known()


## Story 009: a voluntarily-removed tower stops counting toward any
## in-range signature immediately — erase its loadout mapping and
## recompute (a tower vanishing under a stationary hero must be reflected
## the same frame, no grace period).
func _on_tower_removed(tower_id: int, _grid_position: Vector2i, _archetype: String,
		_constellation_eligibility_tag: String) -> void:
	_active_signature_by_tower.erase(tower_id)
	_recompute_if_hero_known()


## Story 009: same treatment as _on_tower_removed — a destroyed tower's
## mapping is erased and the in-range set recomputed immediately.
func _on_tower_destroyed(tower_id: int, _grid_position: Vector2i, _archetype: String,
		_footprint: Array, _constellation_eligibility_tag: String) -> void:
	_active_signature_by_tower.erase(tower_id)
	_recompute_if_hero_known()


func _physics_process(delta: float) -> void:
	tick(delta)


func _on_mission_phase_changed(_previous_phase: String, new_phase: String, _timestamp: float) -> void:
	_current_phase = new_phase


## AC-25: out-of-bounds cell guard — skip the recompute entirely, retain the
## previously cached _signatures_in_range, and never pass an invalid cell to
## the Grid API. Only in-bounds cells update _last_hero_cell, so a
## subsequent tower lifecycle event's immediate recompute also never uses a
## stale/invalid cell.
func _on_hero_position_changed(grid_position: Vector2i) -> void:
	if not _grid.is_in_bounds(grid_position):
		return
	_last_hero_cell = grid_position
	_has_hero_cell = true
	_recompute_signatures_in_range(grid_position)


func _recompute_if_hero_known() -> void:
	if _has_hero_cell:
		_recompute_signatures_in_range(_last_hero_cell)


## AC-02: Chebyshev metric (Grid's own semantics, not Euclidean) — a cell at
## Chebyshev distance == radius is included, one at Euclidean-only-shorter-
## seeming distance is still evaluated correctly since Grid computes the
## metric, this method never re-derives distance itself.
## AC-03: only these two Grid calls are ever invoked here — no Euclidean-
## named Grid method exists as a dependency.
func _recompute_signatures_in_range(hero_cell: Vector2i) -> void:
	var occupied: Array[Vector2i] = _grid.get_occupied_cells_in_radius(hero_cell, TOWER_MASTERY_PROXIMITY_RADIUS)
	var in_range: Dictionary[String, bool] = {}
	for cell: Vector2i in occupied:
		var tower_id: int = _grid.get_occupant(cell)
		var signature: String = _active_signature_by_tower.get(tower_id, "")
		if signature != "":
			in_range[signature] = true
	_signatures_in_range = in_range


## Story 010: lowest live tower_id in _active_signature_by_tower sharing
## `signature` — the deterministic "representative live tower_id" the GDD
## (Rules 12/13) requires as mastery_progress_updated/skill_unlocked's
## payload tower_id. Returns -1 if no live tower currently shares it (can
## happen if the sole tower was destroyed but mastery_time/unlock state
## persists — Edge Cases: accrual pauses, doesn't reset).
func _representative_tower_id_for(signature: String) -> int:
	var lowest: int = -1
	for tower_id: int in _active_signature_by_tower:
		if _active_signature_by_tower[tower_id] != signature:
			continue
		if lowest == -1 or tower_id < lowest:
			lowest = tower_id
	return lowest


## AC-06: independently-tracked threshold/timer from Hero's own
## CLASS_UNLOCK_THRESHOLD_S — no shared gate, no shared dictionary.
## Accrual gated to WAVE_ACTIVE/INTERMISSION only (SCOUT never accrues),
## mirroring Hero's own phase-gate precedent (hero.gd Rule 15).
##
## Story 010 — Formula 1 (mastery_time, AC-19/AC-22/AC-23): unbounded,
## per-signature accrual, independent and parallel across every currently-
## accruing signature — never "nearest tower wins".
##
## Formula 2 (progress_percent, AC-20): mastery_progress_updated is emitted
## for every currently-accruing signature, clamped to [0, 100] for display
## while the underlying mastery_time keeps accumulating unbounded.
## Skill-catalogue lookup (Rule 12/`SkillDefinitionResource`) is explicitly
## deferred content (Rule 7/ADR-0030) — no real catalogue exists yet, so
## (matching this file's own pre-existing skill_unlocked placeholder
## precedent) the build_signature itself stands in for `skill_id` until
## real content lands. If/when a real catalogue exists, this lookup should
## gate the emission (no catalogue entry = no event) rather than always
## firing.
##
## Formula 3 (unlock, AC-21): unlocked_signatures[signature] is set true
## BEFORE skill_unlocked is emitted — this ordering is what makes same-frame
## re-evaluation idempotent (a second call within the same tick sees the
## flag already true and does not re-fire).
func tick(delta: float) -> void:
	if _current_phase == "SCOUT":
		return
	for signature: String in _signatures_in_range:
		if not (_signatures_in_range[signature] as bool):
			continue
		mastery_time[signature] = mastery_time.get(signature, 0.0) + delta

		var representative_tower_id: int = _representative_tower_id_for(signature)
		var progress_percent: float = clampf(
			100.0 * mastery_time[signature] / MASTERY_THRESHOLD_SECONDS, 0.0, 100.0
		)
		GEventBus.mastery_progress_updated.emit(representative_tower_id, signature, progress_percent)

		if mastery_time[signature] >= MASTERY_THRESHOLD_SECONDS and not _unlocked_signatures.get(signature, false):
			_unlocked_signatures[signature] = true
			GEventBus.skill_unlocked.emit(signature, representative_tower_id)


## AC-18: true if the most recent restore_save_data() flagged `skill_id` as
## an orphaned/unknown catalogue entry — the Hero Skill Build UI should
## exclude any skill_id this returns true for, once that UI exists.
func is_skill_unknown(skill_id: String) -> bool:
	return _unknown_skills.get(skill_id, false)


# ---------------------------------------------------------------------------
# SaveRestorer interface (ADR-0003, ADR-0029) — Story 011
# ---------------------------------------------------------------------------

func get_save_key() -> String:
	return "tower_mastery"


func get_save_data() -> Dictionary:
	return {
		"mastery_time": mastery_time.duplicate(),
		"unlocked_skills": _unlocked_signatures.duplicate(),
	}


## Returns false (not void!) on any malformed/missing data so SavePersistence
## falls back to reset_to_defaults() for this system, matching every other
## SaveRestorer in this project (see hero.gd/constellation.gd). Validates
## shape before mutating any field — no partial-restore side effects on a
## rejected payload.
##
## AC-10: mastery_time reads correctly immediately after this call, with no
## dependency on a live tower existing yet — this method only ever mutates
## mastery_time/_unlocked_signatures/_unknown_skills, never anything that
## depends on _grid or a live tower_id.
##
## AC-18: orphaned skill_id handling. `_has_skill_catalogue` defaults false
## in production (no real catalogue exists yet — see the field's own doc
## comment), so no entry is ever false-flagged as unknown today; when a
## catalogue is eventually wired (or in a test that sets `_known_skill_ids`
## directly), any restored skill_id absent from it is retained (never
## discarded), tracked in `_unknown_skills`, and logged — the load never
## blocks on this.
func restore_save_data(data: Dictionary) -> bool:
	var raw_mastery: Variant = data.get("mastery_time", {})
	if typeof(raw_mastery) != TYPE_DICTIONARY:
		return false
	var raw_unlocked: Variant = data.get("unlocked_skills", {})
	if typeof(raw_unlocked) != TYPE_DICTIONARY:
		return false

	var restored_mastery: Dictionary[String, float] = {}
	for key: Variant in (raw_mastery as Dictionary):
		if not (key is String):
			return false
		var value: Variant = (raw_mastery as Dictionary)[key]
		if not (value is float or value is int):
			return false
		restored_mastery[key as String] = float(value)

	var restored_unlocked: Dictionary[String, bool] = {}
	var restored_unknown: Dictionary[String, bool] = {}
	for key: Variant in (raw_unlocked as Dictionary):
		if not (key is String):
			return false
		var value: Variant = (raw_unlocked as Dictionary)[key]
		if not (value is bool):
			return false
		var skill_id: String = key as String
		if _has_skill_catalogue and not _known_skill_ids.has(skill_id):
			restored_unknown[skill_id] = true
			push_warning(
				"TowerMastery: restored unlocked_skills entry '%s' is not in the current skill catalogue — marked UNKNOWN, retained, excluded from UI." % skill_id
			)
		restored_unlocked[skill_id] = value as bool

	mastery_time = restored_mastery
	_unlocked_signatures = restored_unlocked
	_unknown_skills = restored_unknown
	return true


## Clears both persisted structures to their starting (brand-new-adventure)
## state. Never called by mission end (COMPLETE/DEFEAT/abandon) — only by
## SavePersistence when no save data exists yet, or when restore_save_data()
## rejects malformed data (AC-16/AC-17: mission outcome has no bearing on
## whether this fires).
func reset_to_defaults() -> void:
	mastery_time.clear()
	_unlocked_signatures.clear()
	_unknown_skills.clear()
