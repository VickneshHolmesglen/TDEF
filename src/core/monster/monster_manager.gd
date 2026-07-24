class_name MonsterManager
extends Node

## Scene-instanced manager for all active monster entities.
##
## GDD source: design/gdd/monster.md
## ADR-0006: 4-pass centralized _physics_process:
##   Pass 1 — damage drain       (sets DEAD before Pass 3 checks breach)
##   Pass 2 — BOSS logic         (scan throttle, telegraph countdown, cooldown)
##   Pass 3 — movement           (advance ACTIVE entities; detect breach; filter list)
##   Pass 4 — absorbed flush     (emit monster_hp_absorbed per entity per frame)
##
## MonsterManager is NOT an Autoload. It lives in the mission scene.
## Dependencies are injected by _ready() from Autoloads and overrideable in tests.

# ---------------------------------------------------------------------------
# Tuning constants (match GDD Tuning Knobs section)
# ---------------------------------------------------------------------------

const PATH_ARRIVAL_THRESHOLD := 4.0        ## world units
const MAX_ACTIVE_MONSTERS := 150
const BOSS_SCAN_INTERVAL_FRAMES := 6
const BOSS_ATTACK_PREPARE_FRAMES := 4
const HP_WAVE_GROWTH_RATE := 0.15
const HP_DIFFICULTY_GROWTH_RATE := 0.35
const SPEED_WAVE_GROWTH_RATE := 0.06
const CELL_SIZE := 64.0                    ## world units per grid cell

# ---------------------------------------------------------------------------
# Public state (readable by other systems; do not write externally)
# ---------------------------------------------------------------------------

var active_monsters: Array[MonsterEntity] = []
var spawning_entities: Array[MonsterEntity] = []

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

## Pre-allocated swap buffer for Pass 3 filter — avoids 60 heap allocations/sec.
var _active_monsters_next: Array[MonsterEntity] = []

var _pending_damage: Array[MonsterDamageTaken] = []
var _pending_absorbed: Dictionary = {}   # entity_id(int) -> float accumulator
var _entity_lookup: Dictionary = {}      # entity_id(int) -> MonsterEntity
var _entity_id_counter: int = 0
var _current_wave_index: int = -1
var _is_wave_active: bool = false
var _tarot_speed_scalar: float = 1.0

## Dependency injection — set from Autoloads in _ready(), overrideable in tests.
## Untyped so RefCounted stubs can be injected in unit tests (autoloads are Nodes in production).
var _grid = null
var _pathfinding = null

## Resource lookup. Populated from GGameDataRegistry in production (_ready(),
## S5-01) if empty at that point. Tests that add_child() this node before
## injecting data will see it briefly self-populate from the real registry;
## reset _resource_table to {} after add_child() if the test needs a clean,
## disk-independent table (see tests/unit/monster/monster_spawn_test.gd's
## before_test() for the established convention).
var _resource_table: Dictionary = {}     # StringName -> MonsterResource

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_grid = GGrid
	_pathfinding = GPathfindingSystem
	if _resource_table.is_empty():
		_resource_table = GGameDataRegistry.get_all_monster_resources()
	GEventBus.monster_spawn_requested.connect(_on_monster_spawn_requested)
	GEventBus.wave_started.connect(_on_wave_started)
	GEventBus.wave_completed.connect(_on_wave_completed)
	GEventBus.mission_modifier_applied.connect(_on_mission_modifier_applied)
	GEventBus.path_invalidated.connect(_on_path_invalidated)
	GEventBus.monster_damage_taken.connect(_on_monster_damage_taken)


func _exit_tree() -> void:
	GEventBus.monster_spawn_requested.disconnect(_on_monster_spawn_requested)
	GEventBus.wave_started.disconnect(_on_wave_started)
	GEventBus.wave_completed.disconnect(_on_wave_completed)
	GEventBus.mission_modifier_applied.disconnect(_on_mission_modifier_applied)
	GEventBus.path_invalidated.disconnect(_on_path_invalidated)
	GEventBus.monster_damage_taken.disconnect(_on_monster_damage_taken)

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _is_wave_active:
		return
	_pass1_damage()
	_pass2_boss_logic(delta)
	_pass3_movement(delta)
	_pass4_absorbed_flush()

# ---------------------------------------------------------------------------
# Pass 1 — Damage
# ---------------------------------------------------------------------------

func _pass1_damage() -> void:
	for dmg in _pending_damage:
		var entity: MonsterEntity = _entity_lookup.get(dmg.entity_id) as MonsterEntity
		if entity == null or entity.lifecycle_state == MonsterEntity.State.DEAD:
			continue
		var pre_hit_hp: float = entity.current_hp
		entity.current_hp -= float(dmg.amount)
		entity.last_hit_source = &"hero" if dmg.source_type == 1 else &"tower"
		if entity.current_hp <= 0.0:
			entity.current_hp = 0.0
			entity.lifecycle_state = MonsterEntity.State.DEAD
			_pending_absorbed.erase(entity.entity_id)
			_emit_death(entity, entity.last_hit_source)
		else:
			if entity.resource.tier == 2:
				GEventBus.boss_hp_changed.emit(entity.entity_id, entity.current_hp, entity.scaled_hp)
			var absorbed: float = minf(float(dmg.amount), pre_hit_hp)
			_pending_absorbed[entity.entity_id] = (_pending_absorbed.get(entity.entity_id, 0.0) as float) + absorbed
	_pending_damage.clear()


func _emit_death(entity: MonsterEntity, kill_source: StringName) -> void:
	if entity.resource.tier == 2:
		GEventBus.boss_died.emit(entity.entity_id, entity.resource.monster_id,
				entity.wave_index, &"killed")
	var ev := MonsterDiedEvent.new()
	ev.entity_id = entity.entity_id
	ev.monster_id = entity.resource.monster_id
	ev.tier = entity.resource.tier
	ev.drop_table_id = entity.resource.drop_table_id
	ev.menagerie_attraction_drop_chance = entity.resource.menagerie_attraction_drop_chance
	ev.world_position = entity.global_position
	ev.kill_source = kill_source
	ev.wave_reward_scalar = entity.spawn_wave_reward_scalar
	GEventBus.monster_died.emit(ev)
	entity.queue_free()

# ---------------------------------------------------------------------------
# Pass 2 — BOSS Logic
# ---------------------------------------------------------------------------

func _pass2_boss_logic(delta: float) -> void:
	for entity in active_monsters:
		if entity.lifecycle_state == MonsterEntity.State.DEAD:
			continue
		if entity.resource.tier != 2:
			continue
		# Step 1: decrement scan throttle (if > 0), then check scan
		if entity.boss_scan_frames_remaining > 0:
			entity.boss_scan_frames_remaining -= 1
		if entity.boss_scan_frames_remaining <= 0:
			_boss_execute_scan(entity)
			entity.boss_scan_frames_remaining = BOSS_SCAN_INTERVAL_FRAMES
		# Step 2: telegraph countdown — decrement, fire when it hits 0
		if entity.boss_attack_prepare_remaining > 0:
			entity.boss_attack_prepare_remaining -= 1
			if entity.boss_attack_prepare_remaining == 0:
				GEventBus.boss_tower_attack_attempted.emit(
						entity.entity_id,
						entity.boss_locked_target_id,
						entity.resource.base_damage,
						entity.wave_index)
				entity.boss_attack_cooldown_remaining = entity.resource.base_attack_interval
				entity.boss_locked_target_id = -1
		# Step 3: tick cooldown
		entity.boss_attack_cooldown_remaining = maxf(0.0, entity.boss_attack_cooldown_remaining - delta)


func _boss_execute_scan(entity: MonsterEntity) -> void:
	var boss_cell: Vector2i = _grid.world_to_cell(entity.global_position)
	var towers: Array[int] = _grid.get_towers_in_range(boss_cell, entity.resource.boss_attack_range_cells)
	if towers.is_empty():
		return
	# Only enter prepare phase when cooldown is clear and not already preparing
	if entity.boss_attack_cooldown_remaining > 0.0:
		return
	if entity.boss_attack_prepare_remaining > 0:
		return
	entity.boss_attack_prepare_remaining = BOSS_ATTACK_PREPARE_FRAMES
	entity.boss_locked_target_id = towers[0]

# ---------------------------------------------------------------------------
# Pass 3 — Movement
# ---------------------------------------------------------------------------

func _pass3_movement(delta: float) -> void:
	for entity in active_monsters:
		if entity.lifecycle_state != MonsterEntity.State.ACTIVE:
			continue
		_advance_entity(entity, delta)
	# Swap-buffer rebuild: no heap allocation, combined filter + lookup rebuild in one pass.
	_active_monsters_next.clear()
	_entity_lookup.clear()
	for e: MonsterEntity in active_monsters:
		if e.lifecycle_state == MonsterEntity.State.ACTIVE:
			_active_monsters_next.append(e)
			_entity_lookup[e.entity_id] = e
	# SPAWNING entities (no path yet) remain damage-eligible — re-add to lookup.
	for e: MonsterEntity in spawning_entities:
		_entity_lookup[e.entity_id] = e
	var _swap := active_monsters
	active_monsters = _active_monsters_next
	_active_monsters_next = _swap


func _advance_entity(entity: MonsterEntity, delta: float) -> void:
	# Convert cells/sec to world-units/sec using CELL_SIZE
	var budget: float = entity.scaled_speed * CELL_SIZE * delta
	while budget > 0.0 and entity.path_step_index < entity.current_path.size():
		var target_world: Vector2 = _grid.cell_to_world(entity.current_path[entity.path_step_index])
		var dist: float = entity.global_position.distance_to(target_world)
		if dist <= PATH_ARRIVAL_THRESHOLD or budget >= dist:
			# Arrived at this step
			entity.global_position = target_world
			GEventBus.monster_cell_entered.emit(entity.entity_id,
					entity.current_path[entity.path_step_index], entity.path_step_index)
			entity.path_step_index += 1
			budget -= maxf(0.0, dist)
			if entity.path_step_index >= entity.current_path.size():
				# Reached GOAL — only BREACHED if still ACTIVE (not killed this frame)
				if entity.lifecycle_state == MonsterEntity.State.ACTIVE:
					entity.lifecycle_state = MonsterEntity.State.BREACHED
					GEventBus.monster_breached.emit(entity.entity_id,
							entity.resource.monster_id, entity.resource.tier)
					entity.queue_free()
				return
		else:
			var dir: Vector2 = entity.global_position.direction_to(target_world)
			entity.global_position += dir * budget
			budget = 0.0

# ---------------------------------------------------------------------------
# Pass 4 — Absorbed flush
# ---------------------------------------------------------------------------

func _pass4_absorbed_flush() -> void:
	for entity_id: int in _pending_absorbed:
		GEventBus.monster_hp_absorbed.emit(entity_id, int(floor(_pending_absorbed[entity_id] as float)))
	_pending_absorbed.clear()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Spawns a monster by id. Returns the entity on success, null on failure.
## Tests can call this directly after populating _resource_table and injecting stubs.
func spawn_monster(monster_id: StringName, spawn_cell: Vector2i, wave_index: int,
		difficulty_tier: int, wave_reward_scalar: float = 1.0) -> MonsterEntity:
	if not _resource_table.has(monster_id):
		push_error("[MonsterManager] ERROR: Unknown monster_id '%s'. Aborting spawn." % monster_id)
		return null
	if _grid.get_cell_type(spawn_cell) != Grid.CellType.SPAWN:
		push_error("[MonsterManager] ERROR: spawn_cell %s is not a SPAWN cell (type: %d). Aborting." % [
				spawn_cell, _grid.get_cell_type(spawn_cell)])
		return null
	if active_monsters.size() >= MAX_ACTIVE_MONSTERS:
		push_warning("[MonsterManager] WARN: active_monsters at cap (%d). Spawn of '%s' discarded." % [
				MAX_ACTIVE_MONSTERS, monster_id])
		return null
	return _spawn_entity(_resource_table[monster_id] as MonsterResource,
			spawn_cell, wave_index, difficulty_tier, wave_reward_scalar)


func _spawn_entity(res: MonsterResource, spawn_cell: Vector2i, wave_index: int,
		difficulty_tier: int, wave_reward_scalar: float) -> MonsterEntity:
	# HP scaling: base_hp × (1 + rate × (wave-1)) × (1 + diff_rate × (diff-1))
	var hp_mult := 1.0 + HP_WAVE_GROWTH_RATE * float(wave_index - 1)
	var diff_mult := 1.0 + HP_DIFFICULTY_GROWTH_RATE * float(difficulty_tier - 1)
	var scaled_hp := maxf(1.0, res.base_hp * hp_mult * diff_mult)
	# Speed scaling: base_speed × (1 + rate × (wave-1)) × tarot_scalar
	var speed_mult := 1.0 + SPEED_WAVE_GROWTH_RATE * float(wave_index - 1)
	var scaled_speed := maxf(0.1, res.base_speed * speed_mult * _tarot_speed_scalar)

	_entity_id_counter += 1
	var entity := MonsterEntity.new()
	entity.resource = res
	entity.entity_id = _entity_id_counter
	entity.current_hp = scaled_hp
	entity.scaled_hp = scaled_hp
	entity.scaled_speed = scaled_speed
	entity.lifecycle_state = MonsterEntity.State.SPAWNING
	entity.spawn_wave_reward_scalar = wave_reward_scalar
	entity.wave_index = wave_index
	entity.global_position = _grid.cell_to_world(spawn_cell)
	if res.tier == 2:
		entity.boss_scan_frames_remaining = 0
		entity.boss_attack_cooldown_remaining = 0.0

	# TD-monster-003 fix: parent every spawned entity into the scene tree so it is a
	# real Godot node (not an orphan) from creation — required for queue_free() in
	# _emit_death()/_clear_all_state() to take effect correctly against the scene
	# tree, and for gdUnit4's orphan-node detector to stop flagging spawns. Parented
	# to MonsterManager itself (extends Node, no 2D transform) rather than a
	# dedicated container — safe because MonsterManager has no transform to compose
	# against, so entity.global_position (set above) is unaffected by parent order.
	add_child(entity)

	var path: Array[Vector2i] = _pathfinding.find_path(spawn_cell, res.tier)
	if path.is_empty():
		push_warning("[MonsterManager] No path for entity_id=%d at %s. Entity stays SPAWNING." % [
				entity.entity_id, spawn_cell])
		spawning_entities.append(entity)
		_entity_lookup[entity.entity_id] = entity
		return entity

	entity.current_path = path
	entity.path_step_index = 0
	entity.lifecycle_state = MonsterEntity.State.ACTIVE
	active_monsters.append(entity)
	_entity_lookup[entity.entity_id] = entity

	var ev := MonsterSpawnedEvent.new()
	ev.entity_id = entity.entity_id
	ev.monster_id = res.monster_id
	ev.wave_index = wave_index
	ev.grid_position = spawn_cell
	ev.hp_max = scaled_hp
	GEventBus.monster_spawned.emit(ev)
	return entity

# ---------------------------------------------------------------------------
# EventBus handlers
# ---------------------------------------------------------------------------

func _on_monster_spawn_requested(payload: MonsterSpawnRequest) -> void:
	spawn_monster(payload.monster_id, payload.spawn_cell, payload.wave_index,
			payload.difficulty_tier, payload.wave_reward_scalar)


func _on_wave_started(wave_number: int, _total_waves: int, _wave_difficulty: float) -> void:
	_current_wave_index = wave_number
	_is_wave_active = true
	if wave_number == 1:
		_entity_id_counter = 0
	active_monsters.clear()
	spawning_entities.clear()
	_entity_lookup.clear()
	_pending_absorbed.clear()
	_pending_damage.clear()


## Story 002 (epic-04-wave-manager): wave_completed gained a third
## was_boss_breached: bool field. Godot requires connected handlers to accept
## every argument a signal emits (arity must match exactly, extra args are
## NOT silently dropped) — this handler ignores the new field but must
## declare it to avoid a runtime "Method expected 2 argument(s)" error.
func _on_wave_completed(_wave_number: int, _enemies_remaining: int, _was_boss_breached: bool) -> void:
	_is_wave_active = false
	_pending_absorbed.clear()
	_pending_damage.clear()
	for entity in active_monsters:
		if entity.resource.tier == 2:
			GEventBus.boss_died.emit(entity.entity_id, entity.resource.monster_id,
					_current_wave_index, &"force_removed")
		var ev := MonsterDiedEvent.new()
		ev.entity_id = entity.entity_id
		ev.monster_id = entity.resource.monster_id
		ev.tier = entity.resource.tier
		ev.drop_table_id = entity.resource.drop_table_id
		ev.menagerie_attraction_drop_chance = entity.resource.menagerie_attraction_drop_chance
		ev.world_position = entity.global_position
		ev.kill_source = &"wave_end"
		ev.wave_reward_scalar = entity.spawn_wave_reward_scalar
		GEventBus.monster_died.emit(ev)
		entity.queue_free()
	active_monsters.clear()
	for entity in spawning_entities:
		entity.queue_free()
	spawning_entities.clear()
	_entity_lookup.clear()


func _on_mission_modifier_applied(modifier_type: StringName, modifier_value: float, _source: String) -> void:
	if modifier_type == &"monster_speed_scalar":
		_tarot_speed_scalar = modifier_value


## Dead code at MVP (Grid locks tower writes during WAVE_ACTIVE). Kept for post-MVP.
func _on_path_invalidated(_affected_cells: Array) -> void:
	pass


func _on_monster_damage_taken(payload: MonsterDamageTaken) -> void:
	_pending_damage.append(payload)
