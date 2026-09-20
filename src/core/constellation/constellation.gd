class_name Constellation
extends Node

## Pattern-detection layer sitting on top of Tower System (Stories 001-003,
## TR-const-001/TR-const-003, ADR-0022). Scene-instanced — NOT an Autoload
## (subscribes to EventBus, calls Grid directly per ADR-0020 Criterion A).
##
## GDD source: design/gdd/constellation.md — Core Rules 1-9, Formula 1/2.
##
## Content gap found and fixed while implementing this story (Sprint 6,
## S6-08): constellation.md's own OQ-4 claimed to be "resolved 2026-07-17" by
## adding constellation_eligibility_tag to tower_placed/tower_removed/
## tower_destroyed's EventBus payloads, and ADR-0022 assumed this was already
## live — but the actual event_bus.gd signal declarations were never updated
## to match. Fixed in the same pass: the field is now a real trailing param
## on all three signals, sourced from a new TowerData.constellation_eligibility_tag
## field (default "" — no existing tower blueprint opts in yet).
##
## Canonicalization note (Core Rule 1: anchor = lexicographically smallest
## cell, "lowest row(y) then lowest column(x)"): AC-4's own worked example in
## constellation.md states the final activation anchor as "(5,6)" for a
## cross_plus completed by cells {(6,6),(6,5),(7,6),(6,7),(5,6)} — but by the
## GDD's own stated rule, the smallest-y cell among those 5 is (6,5), not
## (5,6). This implementation follows Core Rule 1's actual textual rule (not
## the AC-4 worked example's specific anchor, which appears to be an
## authoring slip); this file's own test suite asserts the mathematically
## consistent anchor (6,5) instead of blindly reproducing the AC text.
##
## bonus_type placeholder (OQ-2/OQ-3, unresolved game-designer content
## questions in constellation.md): Tower System has no Power-component/
## stat-application handler for constellation_activated yet (confirmed absent
## from tower_system.gd), so bonus_type is inert data today — BONUS_TYPE_PLACEHOLDER
## is a directionally-correct placeholder ("damage_pct", per OQ-2's own
## example), not a real content decision, pending a future game-designer pass.
##
## restore_order = 24 (design/gdd/save-persistence.md) — Discovery Ledger
## only; the active-instance table is mission-scoped and never persisted (it
## rebuilds from Grid/Tower state each mission, per ADR-0022 Key Interfaces).

const RESTORE_ORDER: int = 24
const PATTERN_SEARCH_RADIUS: int = 3

# Formula 1 tuning (constellation.md, default values)
const BASE_UNIT_BONUS: float = 0.10
const SIZE_GROWTH_RATE: float = 0.35
const N_MIN: int = 3
const BONUS_CAP: float = 0.25

const SHAPE_N: Dictionary[String, int] = {
	"triad_line": 3,
	"quad_line": 4,
	"l_corner": 4,
	"cross_plus": 5,
}

const SHAPE_COMPLEXITY_BONUS: Dictionary[String, float] = {
	"triad_line": 0.00,
	"quad_line": 0.00,
	"l_corner": 0.02,
	"cross_plus": 0.03,
}

## Equipment-Forge rune bonus per shape (rune-variety spec §3.1/§4), keyed by
## SHAPE_N's keys. Read by EquipmentForge.resolve_rune_stat_delta() for
## rune_id "rune_<shape_id>". Deliberately decoupled from BASE_UNIT_BONUS/
## complexity above (constellation.md Core Rule 12). cross_plus is the
## all-stats wildcard. A shape missing here falls back to the generic +5%.
const SHAPE_RUNE_STAT_DELTA: Dictionary[String, Dictionary] = {
	"triad_line": {&"physical_attack": 5.0},
	"quad_line": {&"attack_range": 24.0, &"physical_attack": 2.5},
	"l_corner": {&"magic_attack": 7.5},
	"cross_plus": {&"additive_bonus_total": 0.05},
}

const BONUS_TYPE_PLACEHOLDER: String = "damage_pct"

## 4 axis directions per Core Rule 1: 0°(horizontal), 90°(vertical),
## 45°(diagonal), 135°(anti-diagonal). Chosen so the first cell (i=0) is
## always the lexicographically-smallest member of the resulting offset list
## (non-negative y, and non-negative x when y=0) — matches every worked
## example in the GDD (AC-1, AC-2, AC-9).
const LINE_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(1, 1),
	Vector2i(-1, 1),
]

## Base L-tetromino: a 3-cell run along x at y=0, plus one perpendicular cell
## below the run's own anchor end. All 8 orientations (4 rotations × 2
## mirrors) are generated from this base at catalogue-build time.
const L_CORNER_BASE: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1),
]

const CROSS_PLUS_OFFSETS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

static var _catalogue_cache: Dictionary = {}  # shape_id -> Array[Array[Vector2i]]

var _active_instances: Dictionary[String, ConstellationInstance] = {}
var _tower_membership: Dictionary[int, Array] = {}  # tower_id -> Array[String] pattern_ids
var _tag_cache: Dictionary[int, String] = {}
var _discovery_ledger: Dictionary[String, bool] = {}

## DI seam — untyped so a RefCounted test double works in unit tests
## (mirrors tower_system.gd's `_grid = null` convention).
var _grid = null


func _ready() -> void:
	_grid = GGrid
	GEventBus.tower_placed.connect(_on_tower_placed)
	GEventBus.tower_removed.connect(_on_tower_removed)
	GEventBus.tower_destroyed.connect(_on_tower_destroyed)
	GSavePersistence.register(self, RESTORE_ORDER)


func _exit_tree() -> void:
	GEventBus.tower_placed.disconnect(_on_tower_placed)
	GEventBus.tower_removed.disconnect(_on_tower_removed)
	GEventBus.tower_destroyed.disconnect(_on_tower_destroyed)
	GSavePersistence.unregister(self)


# ---------------------------------------------------------------------------
# Pattern catalogue (Core Rule 1) — built once, cached statically
# ---------------------------------------------------------------------------

static func _get_catalogue() -> Dictionary:
	if _catalogue_cache.is_empty():
		_catalogue_cache["triad_line"] = _line_orientations(3)
		_catalogue_cache["quad_line"] = _line_orientations(4)
		_catalogue_cache["l_corner"] = _l_corner_orientations()
		_catalogue_cache["cross_plus"] = [CROSS_PLUS_OFFSETS]
	return _catalogue_cache


static func _line_orientations(n: int) -> Array:
	var variants: Array = []
	for direction: Vector2i in LINE_DIRECTIONS:
		var offsets: Array[Vector2i] = []
		for i in range(n):
			offsets.append(direction * i)
		variants.append(offsets)
	return variants


static func _rotate90(offset: Vector2i) -> Vector2i:
	return Vector2i(-offset.y, offset.x)


static func _mirror_x(offset: Vector2i) -> Vector2i:
	return Vector2i(-offset.x, offset.y)


## Generates all 8 distinct D4-symmetry transforms (4 rotations × 2 mirrors)
## of L_CORNER_BASE, deduplicated by their translation-normalized cell set
## (a shape that happens to be symmetric under some transform would otherwise
## produce duplicate variants — not the case for L, but this guards the
## general case, matching cross_plus's own single-orientation collapse logic
## if it were run through this same generator).
static func _l_corner_orientations() -> Array:
	var variants: Array = []
	var seen: Array[String] = []
	for mirror_flag in [false, true]:
		var current: Array[Vector2i] = L_CORNER_BASE.duplicate()
		if mirror_flag:
			var mirrored: Array[Vector2i] = []
			for o: Vector2i in current:
				mirrored.append(_mirror_x(o))
			current = mirrored
		for _k in range(4):
			var key: String = _normalize_key(current)
			if not seen.has(key):
				seen.append(key)
				variants.append(current.duplicate())
			var rotated: Array[Vector2i] = []
			for o: Vector2i in current:
				rotated.append(_rotate90(o))
			current = rotated
	return variants


## Translates `offsets` so its own minimum corner sits at (0,0), then returns
## a sorted, stringified key — used only to deduplicate generated orientation
## variants, never for real anchor computation (that always uses actual grid
## cell positions via _lexicographic_min()).
static func _normalize_key(offsets: Array[Vector2i]) -> String:
	var min_x: int = offsets[0].x
	var min_y: int = offsets[0].y
	for o: Vector2i in offsets:
		min_x = mini(min_x, o.x)
		min_y = mini(min_y, o.y)
	var normalized: Array[Vector2i] = []
	for o: Vector2i in offsets:
		normalized.append(Vector2i(o.x - min_x, o.y - min_y))
	normalized.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	var parts: Array[String] = []
	for o: Vector2i in normalized:
		parts.append("%d,%d" % [o.x, o.y])
	return "|".join(parts)


## Core Rule 1: anchor = lexicographically smallest cell (lowest row/y, then
## lowest column/x) — see this file's class doc comment for the AC-4 worked
## example discrepancy this rule deliberately does NOT reproduce.
static func _lexicographic_min(cells: Array[Vector2i]) -> Vector2i:
	var best: Vector2i = cells[0]
	for cell: Vector2i in cells:
		if cell.y < best.y or (cell.y == best.y and cell.x < best.x):
			best = cell
	return best


static func _format_pattern_id(shape_id: String, anchor: Vector2i) -> String:
	return "%s@(%d,%d)" % [shape_id, anchor.x, anchor.y]


## Formula 1: constellation_bonus_value = min(bonus_cap, base_unit_bonus *
## (1 + size_growth_rate * (N - N_min)) + shape_complexity_bonus)
static func _compute_bonus_value(shape_id: String) -> float:
	var n: int = SHAPE_N[shape_id]
	var complexity: float = SHAPE_COMPLEXITY_BONUS[shape_id]
	var raw: float = BASE_UNIT_BONUS * (1.0 + SIZE_GROWTH_RATE * (n - N_MIN)) + complexity
	return minf(raw, BONUS_CAP)


# ---------------------------------------------------------------------------
# EventBus handlers (Core Rule 3: synchronous, per-event, non-batched)
# ---------------------------------------------------------------------------

## Amendment 2026-07-19 (Epic 06 Story 008): tower_placed promoted to a
## TowerPlacedEvent Resource payload.
func _on_tower_placed(payload: TowerPlacedEvent) -> void:
	_tag_cache[payload.tower_id] = payload.constellation_eligibility_tag
	_recheck_patterns_near(payload.grid_position)


func _on_tower_removed(tower_id: int, _grid_position: Vector2i, _archetype: String,
		_constellation_eligibility_tag: String) -> void:
	_handle_tower_departed(tower_id, "tower_removed")


func _on_tower_destroyed(tower_id: int, _grid_position: Vector2i, _archetype: String,
		_footprint: Array, _constellation_eligibility_tag: String) -> void:
	_handle_tower_departed(tower_id, "tower_destroyed")


## .duplicate() is required: _deactivate_instance() mutates the same
## _tower_membership array in place (scrubbing pattern_id from every
## member's entry, including this one), which would cause a
## mutate-during-iterate skip otherwise (ADR-0022 Risks).
func _handle_tower_departed(tower_id: int, reason: String) -> void:
	var affected: Array = (_tower_membership.get(tower_id, []) as Array).duplicate()
	for pattern_id: String in affected:
		_deactivate_instance(pattern_id, reason)
	_tag_cache.erase(tower_id)


# ---------------------------------------------------------------------------
# Detection (Core Rule 8: localized, radius-bounded — the only Grid call)
# ---------------------------------------------------------------------------

func _recheck_patterns_near(changed_cell: Vector2i) -> void:
	var neighborhood: Array[Vector2i] = _grid.get_occupied_cells_in_radius(changed_cell, PATTERN_SEARCH_RADIUS)
	var occupied_set: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in neighborhood:
		occupied_set[cell] = true

	var catalogue: Dictionary = _get_catalogue()
	for shape_id: String in catalogue:
		for variant: Array in (catalogue[shape_id] as Array):
			for offset: Vector2i in variant:
				var anchor_candidate: Vector2i = changed_cell - offset
				var member_cells: Array[Vector2i] = []
				for o: Vector2i in variant:
					member_cells.append(anchor_candidate + o)
				var canonical_anchor: Vector2i = _lexicographic_min(member_cells)
				var pattern_id: String = _format_pattern_id(shape_id, canonical_anchor)
				if _active_instances.has(pattern_id):
					continue
				var result: Dictionary = _check_eligibility(member_cells, occupied_set)
				if not (result["valid"] as bool):
					continue
				_activate_instance(shape_id, canonical_anchor, pattern_id, member_cells,
						result["member_tower_ids"] as Array[int])


## Core Rule 2: every cell must be occupied by an eligible (non-empty-tag)
## tower, AND all member towers must share the identical tag value.
func _check_eligibility(member_cells: Array[Vector2i], occupied_set: Dictionary) -> Dictionary:
	var tag: String = ""
	var member_tower_ids: Array[int] = []
	for cell: Vector2i in member_cells:
		if not occupied_set.get(cell, false):
			return {"valid": false}
		var tower_id: int = _grid.get_occupant(cell)
		var cell_tag: String = _tag_cache.get(tower_id, "")
		if cell_tag == "":
			return {"valid": false}
		if tag == "":
			tag = cell_tag
		elif tag != cell_tag:
			return {"valid": false}
		member_tower_ids.append(tower_id)
	return {"valid": true, "member_tower_ids": member_tower_ids}


# ---------------------------------------------------------------------------
# Activation / Deactivation (Core Rules 4-7)
# ---------------------------------------------------------------------------

func _activate_instance(shape_id: String, anchor: Vector2i, pattern_id: String,
		member_cells: Array[Vector2i], member_tower_ids: Array[int]) -> void:
	var instance := ConstellationInstance.new()
	instance.shape_id = shape_id
	instance.anchor_cell = anchor
	instance.member_cells = member_cells
	instance.member_tower_ids = member_tower_ids
	instance.bonus_type = BONUS_TYPE_PLACEHOLDER
	instance.bonus_value = _compute_bonus_value(shape_id)

	_active_instances[pattern_id] = instance
	for tower_id: int in member_tower_ids:
		if not _tower_membership.has(tower_id):
			_tower_membership[tower_id] = []
		(_tower_membership[tower_id] as Array).append(pattern_id)

	GEventBus.constellation_activated.emit(pattern_id, anchor, instance.bonus_type, instance.bonus_value)

	if not _discovery_ledger.get(shape_id, false):
		_discovery_ledger[shape_id] = true
		GEventBus.constellation_rune_discovered.emit("rune_%s" % shape_id, pattern_id)


## Scrubs pattern_id from EVERY member tower's reverse-index entry, not only
## the triggering tower's — otherwise non-triggering members retain a stale
## pattern_id after the instance is gone (ADR-0022 Risks).
func _deactivate_instance(pattern_id: String, reason: String) -> void:
	var instance: ConstellationInstance = _active_instances.get(pattern_id)
	if instance == null:
		return
	for member_tower_id: int in instance.member_tower_ids:
		var entry: Array = _tower_membership.get(member_tower_id)
		if entry != null:
			entry.erase(pattern_id)
			if entry.is_empty():
				_tower_membership.erase(member_tower_id)
	_active_instances.erase(pattern_id)
	GEventBus.constellation_deactivated.emit(pattern_id, reason)


func is_active(pattern_id: String) -> bool:
	return _active_instances.has(pattern_id)


func is_discovered(shape_id: String) -> bool:
	return _discovery_ledger.get(shape_id, false)


# ---------------------------------------------------------------------------
# SaveRestorer interface (ADR-0003, ADR-0022) — Discovery Ledger only
# ---------------------------------------------------------------------------

func get_save_key() -> String:
	return "constellation"


func get_save_data() -> Dictionary:
	return {"discovery_ledger": _discovery_ledger.duplicate()}


func restore_save_data(data: Dictionary) -> bool:
	var raw_ledger: Variant = data.get("discovery_ledger", {})
	if typeof(raw_ledger) != TYPE_DICTIONARY:
		return false
	var restored: Dictionary[String, bool] = {}
	for key: Variant in (raw_ledger as Dictionary):
		if not (key is String):
			return false
		var value: Variant = (raw_ledger as Dictionary)[key]
		if not (value is bool):
			return false
		restored[key as String] = value as bool
	_discovery_ledger = restored
	return true


func reset_to_defaults() -> void:
	_discovery_ledger = {}
