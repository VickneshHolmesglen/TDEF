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

## Revised 2026-09-01 for hero-skill-tree.md's Rule 13 revision: no longer a
## one-shot unlock flag. `points_granted_count[signature]` tracks how many
## skill_tree_point_earned grants have already fired for this signature, so
## tick() can grant the difference every time mastery_time crosses a further
## whole multiple of MASTERY_THRESHOLD_SECONDS (Rule 14's past-100%
## continuation), never re-granting the same crossing twice.
var points_granted_count: Dictionary[String, int] = {}

## Foundation.archetype for the signature's Foundation slot (physical|ranged|
## elemental|support), populated from tower_placed/tower_component_equipped's
## payload — the same source Hero Skill Tree's own Formula 3 dependency note
## says to derive archetype from (Rule 13's revised Formula 3).
var _archetype_by_signature: Dictionary[String, String] = {}

## Story 009: hero's last-known IN-BOUNDS cell, used to recompute
## `_signatures_in_range` immediately on tower lifecycle events (a tower
## vanishing/appearing under a stationary hero must be reflected the same
## frame). `_has_hero_cell` distinguishes "never received a valid position
## yet" from Vector2i.ZERO being a legitimate cell.
var _last_hero_cell: Vector2i = Vector2i.ZERO
var _has_hero_cell: bool = false

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
	var signature: String = compute_build_signature(
		payload.foundation_component_id, payload.weapon_component_id,
		payload.focus_component_id, payload.power_component_id
	)
	_active_signature_by_tower[payload.tower_id] = signature
	# Rule 13 revision: archetype for a signature is derived from the same
	# source Formula 4 already uses to identify the Foundation slot — the
	# payload's own `archetype` field (TowerPlacedEvent, tower.md's Foundation
	# archetype). Never overwritten once set for a given signature — every
	# tower sharing a signature shares the same Foundation, so this is stable.
	if not _archetype_by_signature.has(signature):
		_archetype_by_signature[signature] = payload.archetype
	_recompute_if_hero_known()


## AC-12: component swap recomputes build_signature for the affected tower_id.
## mastery_time under the OLD signature is left untouched (no retroactive
## transfer) — mastery_time is keyed by signature, not tower_id, so simply
## repointing _active_signature_by_tower to the new signature achieves this
## with no extra bookkeeping: future accrual credits the new signature,
## past accrual under the old signature remains exactly where it was.
## Story 009: also recomputes _signatures_in_range immediately.
func _on_tower_component_equipped(payload: TowerComponentEquippedEvent) -> void:
	var old_signature: String = _active_signature_by_tower.get(payload.tower_id, "")
	var new_signature: String = compute_build_signature(
		payload.foundation_component_id, payload.weapon_component_id,
		payload.focus_component_id, payload.power_component_id
	)
	_active_signature_by_tower[payload.tower_id] = new_signature
	# No real emitter exists yet for this event (see class doc comment) and
	# its payload carries no `archetype` field the way TowerPlacedEvent's
	# does. Best-effort carry-forward: a non-Foundation slot swap can't have
	# changed the archetype, so reuse whatever archetype the tower's OLD
	# signature was already tracked under. A Foundation-slot swap (archetype
	# potentially changed) has no data to derive a new archetype from here —
	# left unset rather than guessed, matching this file's own
	# never-guess-at-missing-data convention (see _grid seam doc comment).
	if not _archetype_by_signature.has(new_signature) and payload.slot != "foundation":
		var carried_archetype: String = _archetype_by_signature.get(old_signature, "")
		if carried_archetype != "":
			_archetype_by_signature[new_signature] = carried_archetype
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

	# tower_mastery_proximity_changed (2026-08-13, Story 013 Audio d): a
	# discrete edge-detection diff against the PREVIOUS in-range set --
	# fires once per actual transition, never on every recompute (a
	# recompute that doesn't change a signature's membership must stay
	# silent, or every hero step would spam the stinger).
	for signature: String in in_range:
		if not _signatures_in_range.get(signature, false):
			GEventBus.tower_mastery_proximity_changed.emit(signature, true)
	for signature: String in _signatures_in_range:
		if _signatures_in_range[signature] and not in_range.get(signature, false):
			GEventBus.tower_mastery_proximity_changed.emit(signature, false)

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
## Formula 3, revised 2026-09-01 (hero-skill-tree.md Rule 13/tower-mastery.md
## Rule 13): no longer unlocks a skill directly. Every whole multiple of
## MASTERY_THRESHOLD_SECONDS crossed grants exactly one
## skill_tree_point_earned(archetype, source_tower_id) — unconditional,
## forever, never checking or mutating Hero Skill Tree's own state (that
## system owns all further mutation, per ADR-0041's emission-only split).
## `points_granted_count[signature]` tracks how many grants have already
## fired so a large `delta` that crosses more than one multiple in a single
## tick grants the correct number of points, not just one, and a repeat
## evaluation within the same tick never double-grants (mirrors the previous
## `_unlocked_signatures` idempotency guarantee, generalized to a counter).
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

		var crossings_reached: int = int(mastery_time[signature] / MASTERY_THRESHOLD_SECONDS)
		var already_granted: int = points_granted_count.get(signature, 0)
		if crossings_reached <= already_granted:
			continue
		var archetype: String = _archetype_by_signature.get(signature, "")
		if archetype == "":
			continue
		points_granted_count[signature] = crossings_reached
		for _i: int in (crossings_reached - already_granted):
			GEventBus.skill_tree_point_earned.emit(archetype, representative_tower_id)


# ---------------------------------------------------------------------------
# SaveRestorer interface (ADR-0003, ADR-0029) — Story 011
# ---------------------------------------------------------------------------

func get_save_key() -> String:
	return "tower_mastery"


## Migrated 2026-09-01 (hero-skill-tree.md's Dependencies migration note): the
## old one-shot `unlocked_skills: Dictionary[String, bool]` is retired and
## replaced by `points_granted_count` — a different key space (still keyed by
## build_signature, but an int grant-count, not a bool). `archetype_by_signature`
## is new: Hero Skill Tree's own point-crediting handler never re-derives
## archetype itself, only this system does (Formula 4's own source of truth),
## so it must survive a save/load cycle for `skill_tree_point_earned` grants
## after a reload to resolve to the correct pool.
func get_save_data() -> Dictionary:
	return {
		"mastery_time": mastery_time.duplicate(),
		"points_granted_count": points_granted_count.duplicate(),
		"archetype_by_signature": _archetype_by_signature.duplicate(),
	}


## Returns false (not void!) on any malformed/missing data so SavePersistence
## falls back to reset_to_defaults() for this system, matching every other
## SaveRestorer in this project (see hero.gd/constellation.gd). Validates
## shape before mutating any field — no partial-restore side effects on a
## rejected payload.
##
## AC-10: mastery_time reads correctly immediately after this call, with no
## dependency on a live tower existing yet — this method only ever mutates
## mastery_time/points_granted_count/_archetype_by_signature, never anything
## that depends on _grid or a live tower_id.
##
## Migration case (hero-skill-tree.md AC-12, Dependencies migration note): a
## save written before this revision carries the old `unlocked_skills` key,
## which this method no longer reads at all — `points_granted_count` simply
## defaults to an empty Dictionary via `data.get()`, matching every
## signature's accrued `mastery_time` as "0 grants issued yet." The player's
## pre-revision unlocked skills are not retroactively re-granted as tree
## points — an accepted, explicitly out-of-scope one-time loss for this
## pre-Alpha project, per that GDD's own migration note.
func restore_save_data(data: Dictionary) -> bool:
	var raw_mastery: Variant = data.get("mastery_time", {})
	if typeof(raw_mastery) != TYPE_DICTIONARY:
		return false
	var raw_counts: Variant = data.get("points_granted_count", {})
	if typeof(raw_counts) != TYPE_DICTIONARY:
		return false
	var raw_archetypes: Variant = data.get("archetype_by_signature", {})
	if typeof(raw_archetypes) != TYPE_DICTIONARY:
		return false

	var restored_mastery: Dictionary[String, float] = {}
	for key: Variant in (raw_mastery as Dictionary):
		if not (key is String):
			return false
		var value: Variant = (raw_mastery as Dictionary)[key]
		if not (value is float or value is int):
			return false
		restored_mastery[key as String] = float(value)

	var restored_counts: Dictionary[String, int] = {}
	for key: Variant in (raw_counts as Dictionary):
		if not (key is String):
			return false
		var value: Variant = (raw_counts as Dictionary)[key]
		if not (value is int or value is float):
			return false
		restored_counts[key as String] = int(value)

	var restored_archetypes: Dictionary[String, String] = {}
	for key: Variant in (raw_archetypes as Dictionary):
		if not (key is String):
			return false
		var value: Variant = (raw_archetypes as Dictionary)[key]
		if not (value is String):
			return false
		restored_archetypes[key as String] = value as String

	mastery_time = restored_mastery
	points_granted_count = restored_counts
	_archetype_by_signature = restored_archetypes
	return true


## Clears both persisted structures to their starting (brand-new-adventure)
## state. Never called by mission end (COMPLETE/DEFEAT/abandon) — only by
## SavePersistence when no save data exists yet, or when restore_save_data()
## rejects malformed data (AC-16/AC-17: mission outcome has no bearing on
## whether this fires).
func reset_to_defaults() -> void:
	mastery_time.clear()
	points_granted_count.clear()
	_archetype_by_signature.clear()
