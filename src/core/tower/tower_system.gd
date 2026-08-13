class_name TowerSystem
extends Node

## Scene-instanced Tower System. NOT an Autoload.
##
## Control manifest rule: Autoloads must not own per-mission state.
## TowerSystem owns _current_phase, _placed_towers, _monster_cache —
## all per-mission state — so it is scene-instanced (same pattern as MonsterManager).
##
## Gold balance is NOT owned here — GMissionEconomy (Autoload, ADR-0018) is the
## sole owner. Gate 2 reads it live via GMissionEconomy.can_afford(); place_tower()/
## sell_tower() emit signed resources_changed deltas (never absolute balances) —
## TowerSystem does not subscribe to resources_changed.
##
## ADR-0008: 4-gate placement, duplicate_deep() component isolation at commit,
##   get_placement_preview() runs Gates 1–3 only (never Gate 4).
## Amendment 2026-07-19 (implementation catch-up): _tower_table now holds
##   TowerBlueprintData (4-component-composed) instead of the flat TowerData;
##   duplicate_deep() is genuinely called at placement commit now, not deferred.

enum Phase { UNKNOWN, SCOUT, INTERMISSION, WAVE_ACTIVE, MISSION_COMPLETE, DEFEAT }

# ---------------------------------------------------------------------------
# Public state — readable by tests and other mission-scene systems
# ---------------------------------------------------------------------------

## Placed towers keyed by integer instance id (auto-increments from 1).
var placed_towers: Dictionary = {}  # int tower_id → TowerMissionState

## Blueprint lookup table. Populated from GGameDataRegistry in production
## (_ready(), S5-01) if empty at that point; tests inject directly into this
## table before add_child() triggers _ready(), which leaves it non-empty and
## therefore skips the production population step below.
var _tower_table: Dictionary = {}   # StringName blueprint_id → TowerBlueprintData

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

var _tower_id_counter: int = 0
var _current_phase: Phase = Phase.UNKNOWN

## Entity position/HP cache (TR-tower-003: no direct MonsterEntity refs).
## Keyed by entity_id: int → {cell: Vector2i, hp: float, is_armored: bool}
var _monster_cache: Dictionary = {}

## DI seams — untyped so RefCounted stubs work in unit tests.
var _grid = null
var _pathfinding = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_grid = GGrid
	_pathfinding = GPathfindingSystem
	if _tower_table.is_empty():
		_tower_table = GGameDataRegistry.get_all_tower_blueprints()
	GEventBus.mission_phase_changed.connect(_on_mission_phase_changed)
	GEventBus.monster_spawned.connect(_on_monster_spawned)
	GEventBus.monster_cell_entered.connect(_on_monster_cell_entered)
	GEventBus.monster_died.connect(_on_monster_died)
	GEventBus.boss_tower_attack_attempted.connect(_on_boss_tower_attack_attempted)
	GEventBus.tower_sell_requested.connect(_on_tower_sell_requested)


func _exit_tree() -> void:
	GEventBus.mission_phase_changed.disconnect(_on_mission_phase_changed)
	GEventBus.monster_spawned.disconnect(_on_monster_spawned)
	GEventBus.monster_cell_entered.disconnect(_on_monster_cell_entered)
	GEventBus.monster_died.disconnect(_on_monster_died)
	GEventBus.boss_tower_attack_attempted.disconnect(_on_boss_tower_attack_attempted)
	GEventBus.tower_sell_requested.disconnect(_on_tower_sell_requested)


## Combat tick. Called by engine each physics frame. Public for test injection.
func _tick_combat(delta: float) -> void:
	if _current_phase != Phase.WAVE_ACTIVE:
		return
	for id: int in placed_towers:
		var state: TowerMissionState = placed_towers[id] as TowerMissionState
		state.attack_timer_remaining -= delta
		if state.attack_timer_remaining <= 0.0:
			_try_attack(state)
			state.attack_timer_remaining += 1.0 / state.weapon.attack_speed


func _physics_process(delta: float) -> void:
	_tick_combat(delta)

# ---------------------------------------------------------------------------
# Placement gate (ADR-0008)
# ---------------------------------------------------------------------------

## Place a tower blueprint at top_left. Returns true on success.
##
## 4-gate sequence: Phase → Resource → Footprint → Path.
## Emits tower_placed (and pre_placement_perk_activated if SCOUT).
func place_tower(blueprint_id: StringName, top_left: Vector2i) -> bool:
	# Gate 1 — Phase
	if _current_phase == Phase.WAVE_ACTIVE:
		return false
	if not _tower_table.has(blueprint_id):
		push_error("[TowerSystem] Unknown blueprint_id '%s'" % blueprint_id)
		return false
	var data: TowerBlueprintData = _tower_table[blueprint_id] as TowerBlueprintData
	# Gate 2 — Resource
	if not GMissionEconomy.can_afford(data.placement_cost):
		return false
	# Gate 3 — Grid footprint
	if not _grid.is_footprint_placeable(top_left, data.foundation.footprint):
		return false
	# Gate 4 — Path integrity (NEVER skipped on commit)
	var cells: Array[Vector2i] = _get_footprint_cells(top_left, data.foundation.footprint)
	if _pathfinding.would_block_all_paths(cells):
		return false
	# Commit
	_tower_id_counter += 1
	var tower_id: int = _tower_id_counter
	var err: int = _grid.place_tower(tower_id, top_left, data.foundation.footprint)
	if err != OK:
		_tower_id_counter -= 1
		return false
	var state := TowerMissionState.new()
	state.tower_id = tower_id
	state.placement_cost = data.placement_cost
	# ADR-0008 Component Deep-Copy Policy: independent mission-instance copies,
	# isolated from the inventory-owned blueprint — mutations (e.g. `damaged`)
	# never write back to `data`.
	state.foundation = data.foundation.duplicate_deep()
	state.weapon = data.weapon.duplicate_deep()
	state.focus = data.focus.duplicate_deep()
	state.power = data.power.duplicate_deep()
	state.grid_position = top_left
	state.max_hp = state.foundation.hp_base * state.foundation.tier_multiplier
	state.current_hp = state.max_hp
	state.attack_timer_remaining = 0.0  # Fire on first combat frame
	placed_towers[tower_id] = state
	GEventBus.resources_changed.emit(-data.placement_cost, &"tower_placed")
	var placed_in_scout: bool = _current_phase == Phase.SCOUT
	var payload := TowerPlacedEvent.new()
	payload.tower_id = tower_id
	payload.grid_position = top_left
	payload.archetype = String(state.foundation.archetype)
	payload.footprint = state.foundation.footprint
	payload.placed_in_scout = placed_in_scout
	payload.constellation_eligibility_tag = state.power.constellation_eligibility_tag
	payload.foundation_component_id = state.foundation.component_id
	payload.weapon_component_id = state.weapon.component_id
	payload.focus_component_id = state.focus.component_id
	payload.power_component_id = state.power.component_id
	GEventBus.tower_placed.emit(payload)
	# Real bug fixed here (2026-08-13, found while implementing the
	# perk-badge VFX): this previously fired unconditionally for every
	# Scout-Phase placement, using the tower's ARCHETYPE as perk_type. Per
	# this file's own schema table ("pre_placement_perk: any perk type id,
	# or '' -- empty string = no perk") and Rule 12's own text ("A Foundation
	# component with pre_placement_perk = '' has no perk"), a tower with no
	# perk configured must not fire this event at all. No shipped blueprint
	# currently sets a non-empty pre_placement_perk, so this bug produced no
	# visibly wrong behavior yet -- it would have the moment content authors
	# added a real perk.
	if placed_in_scout and state.foundation.pre_placement_perk != "":
		GEventBus.pre_placement_perk_activated.emit(tower_id, state.foundation.pre_placement_perk)
	return true


## Returns a preview result for hover display.
##
## Runs Gates 1–3 only. Gate 4 (path integrity) is NEVER called here — AC-8.
func get_placement_preview(blueprint_id: StringName, top_left: Vector2i) -> PlacementPreview:
	var preview := PlacementPreview.new()
	if not _tower_table.has(blueprint_id):
		preview.valid = false
		preview.reason = PlacementPreview.PlacementBlockReason.FOOTPRINT_BLOCKED
		return preview
	var data: TowerBlueprintData = _tower_table[blueprint_id] as TowerBlueprintData
	# Gate 1
	if _current_phase == Phase.WAVE_ACTIVE:
		preview.valid = false
		preview.reason = PlacementPreview.PlacementBlockReason.WAVE_ACTIVE
		return preview
	# Gate 2
	if not GMissionEconomy.can_afford(data.placement_cost):
		preview.valid = false
		preview.reason = PlacementPreview.PlacementBlockReason.INSUFFICIENT_RESOURCES
		return preview
	# Gate 3
	if not _grid.is_footprint_placeable(top_left, data.foundation.footprint):
		preview.valid = false
		preview.reason = PlacementPreview.PlacementBlockReason.FOOTPRINT_BLOCKED
		return preview
	# Gate 4 intentionally omitted
	preview.valid = true
	preview.reason = PlacementPreview.PlacementBlockReason.NONE
	return preview


## Sell a placed tower. Returns true on success.
##
## Refund = round(placement_cost × 0.4). Blocked during WAVE_ACTIVE (AC-21).
## Emits tower_removed (not tower_destroyed).
func sell_tower(tower_id: int) -> bool:
	if _current_phase == Phase.WAVE_ACTIVE:
		return false
	if not placed_towers.has(tower_id):
		push_error("[TowerSystem] sell_tower: unknown tower_id %d" % tower_id)
		return false
	var state: TowerMissionState = placed_towers[tower_id] as TowerMissionState
	var refund: int = roundi(state.placement_cost * 0.4)
	_grid.remove_tower(tower_id)
	placed_towers.erase(tower_id)
	GEventBus.resources_changed.emit(refund, &"tower_sold")
	GEventBus.tower_removed.emit(tower_id, state.grid_position,
			String(state.foundation.archetype), state.power.constellation_eligibility_tag)
	return true

# ---------------------------------------------------------------------------
# Combat formulas (AC-9 to AC-17)
# ---------------------------------------------------------------------------

## DPS formula: weapon_damage × attack_speed × tier_dps_multiplier.
## Amendment 2026-07-19: tier_dps_multiplier lives on FoundationComponent per
## tower.md's schema (not WeaponComponent), split accordingly.
func compute_dps(weapon: WeaponComponent, foundation: FoundationComponent) -> float:
	return weapon.weapon_damage * weapon.attack_speed * foundation.tier_dps_multiplier


## True when enemy_cell is within the tower's effective range.
##
## Effective range = attack_range_cells + 2 if cone_half_angle ≤ 30°.
## Distance metric: Chebyshev (diagonals equal to cardinals).
func is_in_range(tower_cell: Vector2i, enemy_cell: Vector2i, focus: FocusComponent) -> bool:
	var chebyshev: int = max(
		abs(tower_cell.x - enemy_cell.x), abs(tower_cell.y - enemy_cell.y)
	)
	return chebyshev <= _get_effective_range(focus)


## Effective range after cone bonus.
func _get_effective_range(focus: FocusComponent) -> int:
	if focus.cone_half_angle <= 30.0:
		return focus.attack_range_cells + 2
	return focus.attack_range_cells

# ---------------------------------------------------------------------------
# Attack resolution
# ---------------------------------------------------------------------------

func _try_attack(state: TowerMissionState) -> void:
	var target_id: int = _find_lowest_hp_target(state)
	if target_id == -1:
		return
	if not _monster_cache.has(target_id):
		return
	var entry: Dictionary = _monster_cache[target_id] as Dictionary
	var is_armored: bool = entry["is_armored"] as bool
	var is_siege: bool = state.foundation.tier == 4
	var damage: float = state.weapon.weapon_damage * state.foundation.tier_dps_multiplier
	GEventBus.tower_attacked.emit.call_deferred(state.tower_id, target_id, damage, is_siege, is_armored,
			state.power.effect_type, state.power.effect_value, state.power.effect_duration)


## Returns the entity_id of the lowest-HP monster in range, or -1 if none.
func _find_lowest_hp_target(state: TowerMissionState) -> int:
	var best_id: int = -1
	var best_hp: float = INF
	for entity_id: int in _monster_cache:
		var entry: Dictionary = _monster_cache[entity_id] as Dictionary
		var cell: Vector2i = entry["cell"] as Vector2i
		if not is_in_range(state.grid_position, cell, state.focus):
			continue
		var hp: float = entry["hp"] as float
		if hp < best_hp:
			best_hp = hp
			best_id = entity_id
	return best_id

# ---------------------------------------------------------------------------
# Boss damage receiver
# ---------------------------------------------------------------------------

func _on_boss_tower_attack_attempted(_boss_entity_id: int, target_tower_id: int,
		base_damage: float, _wave_id: int) -> void:
	if not placed_towers.has(target_tower_id):
		return
	var state: TowerMissionState = placed_towers[target_tower_id] as TowerMissionState
	state.current_hp -= base_damage
	state.damaged = true
	if state.current_hp <= 0.0:
		state.current_hp = 0.0
		_grid.remove_tower(target_tower_id)
		placed_towers.erase(target_tower_id)
		var cells: Array[Vector2i] = _get_footprint_cells(state.grid_position, state.foundation.footprint)
		GEventBus.tower_destroyed.emit(target_tower_id, state.grid_position,
				String(state.foundation.archetype), cells, state.power.constellation_eligibility_tag)
	else:
		GEventBus.tower_damaged.emit(target_tower_id, base_damage,
				state.current_hp, state.max_hp)

# ---------------------------------------------------------------------------
# Monster cache (TR-tower-003: no direct MonsterEntity refs)
# ---------------------------------------------------------------------------

## Synchronous subscription (Tower GDD Rule 14a: must receive before tower_attacked).
func _on_monster_spawned(payload: MonsterSpawnedEvent) -> void:
	_monster_cache[payload.entity_id] = {
		"cell": payload.grid_position,
		"hp": payload.hp_max,
		"is_armored": false,
	}


func _on_monster_cell_entered(entity_id: int, grid_cell: Vector2i, _step: int) -> void:
	if _monster_cache.has(entity_id):
		(_monster_cache[entity_id] as Dictionary)["cell"] = grid_cell


func _on_monster_died(payload: MonsterDiedEvent) -> void:
	_monster_cache.erase(payload.entity_id)

# ---------------------------------------------------------------------------
# Phase and resource tracking
# ---------------------------------------------------------------------------

func _on_mission_phase_changed(_previous_phase: String, new_phase: String,
		_timestamp: float) -> void:
	match new_phase:
		"SCOUT":            _current_phase = Phase.SCOUT
		"INTERMISSION":     _current_phase = Phase.INTERMISSION
		"WAVE_ACTIVE":      _current_phase = Phase.WAVE_ACTIVE
		"MISSION_COMPLETE": _current_phase = Phase.MISSION_COMPLETE
		"DEFEAT":           _current_phase = Phase.DEFEAT
		_:                  _current_phase = Phase.UNKNOWN


func _on_tower_sell_requested(tower_id: int) -> void:
	sell_tower(tower_id)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _get_footprint_cells(top_left: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for col: int in range(size.x):
		for row: int in range(size.y):
			cells.append(top_left + Vector2i(col, row))
	return cells
