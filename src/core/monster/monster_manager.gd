class_name MonsterManager
extends Node

## Scene-instanced manager for all active monster entities.
##
## GDD source: design/gdd/monster.md
## ADR-0006: centralized _physics_process (amended 2026-08-13 — 5th pass added;
## amended 2026-08-20 — Epic 15 Story 004 visual-companion sync pass added):
##   Pass 1  — damage drain       (sets DEAD before Pass 3 checks breach)
##   Pass 1b — status effects     (burn/poison DoT ticks + slow duration decay —
##                                 ADR-0006 amendment; see damage-status.md
##                                 Rule I.3's exception note)
##   Pass 2  — BOSS logic         (scan throttle, telegraph countdown, cooldown)
##   Pass 3  — movement           (advance ACTIVE entities via effective speed —
##                                 scaled_speed x active slow multipliers;
##                                 detect breach; filter list)
##   Pass 3c — visual companion sync  (Epic 15 Story 004, ADR-0037: syncs each
##                                     still-ACTIVE entity's 3D visual-companion
##                                     mesh to its just-finalized 2D position via
##                                     VisualMath.map_to_3d() — one line per
##                                     monster inside THIS existing centralized
##                                     pass, never a new per-node _physics_process()
##                                     override on MonsterInstance/MonsterEntity;
##                                     see _pass3c_visual_sync()'s own doc comment)
##   Pass 4  — death & absorbed flush  (ADR-0033: monster_died or one monsters_died_batch
##                                      depending on frame death count; then monster_hp_absorbed)
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
const DEATH_BATCH_THRESHOLD := 20          ## ADR-0033 / event-bus.md Formula 2's F_per_frame > 20

## damage-status.md Formula D5: tick interval for burn/poison DoT ticks.
const STATUS_TICK_INTERVAL := 1.0          ## seconds
## damage-status.md Rule I.3: the effect_type values Monster System
## recognizes as a DoT. Anything else is silently ignored by the DoT path
## (may still be a recognized slow — see RECOGNIZED_SLOW_EFFECTS). "bleed"
## added by Tower Stats System Phase 1 (player-requested 2026-08-16) —
## reuses this DoT machinery verbatim, no other code change; it is
## authored as a physical effect (no elemental identity of its own), but
## note this DoT tick path does not currently read elemental resistance at
## all (burn/poison don't either) — "bleed is unresisted while poison
## isn't" is not yet a real distinction, see design/gdd/damage-status.md's
## Phase 1 addendum.
const RECOGNIZED_DOT_EFFECTS: Array[String] = ["burn", "poison", "bleed"]
## damage-status.md Formula D6: the only effect_type value Monster System
## recognizes as a slow. Kept as an array (not a single constant) for the
## same extensibility reason RECOGNIZED_DOT_EFFECTS is one.
const RECOGNIZED_SLOW_EFFECTS: Array[String] = ["slow"]
## damage-status.md Formula D6: minimum speed_multiplier a single
## ActiveSlowEffect instance may have, regardless of how large effect_value
## is. Prevents one extreme content value from freezing a monster in place
## entirely (0 speed is a stuck-forever state, not a strong slow).
const SPEED_MULTIPLIER_FLOOR := 0.05

const MONSTER_INSTANCE_SCENE: PackedScene = preload("res://src/core/monster/MonsterInstance.tscn")

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
var _pending_deaths: Array[MonsterDiedEvent] = []   ## ADR-0033 — frame-scoped, flushed each frame in Pass 4
var _entity_lookup: Dictionary = {}      # entity_id(int) -> MonsterEntity
var _entity_id_counter: int = 0
var _current_wave_index: int = -1
var _is_wave_active: bool = false
## ADR-0036: F2's unclamped running multiplicative product across all
## equipped tarot_speed_scalar_mult cards -- reset to 1.0 on every mission's
## (and retry's) wave 1, since MonsterManager is a static MissionScene child,
## never destroyed/recreated between attempts.
var _tarot_speed_scalar_raw: float = 1.0
## F4's clamped output ([0.50, 2.00]) -- what monster_speed_scaling actually reads.
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
	GEventBus.tower_attacked.connect(_on_tower_attacked_status)


func _exit_tree() -> void:
	GEventBus.monster_spawn_requested.disconnect(_on_monster_spawn_requested)
	GEventBus.wave_started.disconnect(_on_wave_started)
	GEventBus.wave_completed.disconnect(_on_wave_completed)
	GEventBus.mission_modifier_applied.disconnect(_on_mission_modifier_applied)
	GEventBus.path_invalidated.disconnect(_on_path_invalidated)
	GEventBus.monster_damage_taken.disconnect(_on_monster_damage_taken)
	GEventBus.tower_attacked.disconnect(_on_tower_attacked_status)

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _is_wave_active:
		return
	_pass1_damage()
	_pass1b_status_effects(delta)
	_pass2_boss_logic(delta)
	_pass3_movement(delta)
	_pass3c_visual_sync()
	_pass4_death_and_absorbed_flush()

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
		# Player-reported 2026-08-16: floating damage numbers rendered near the
		# boss bar instead of on the hit monster (Mission HUD's own KNOWN GAP
		# comment) -- this is the one place monster_damage_taken's entity_id
		# still resolves to a live entity with a real global_position, so the
		# HUD-facing position is sourced from here instead.
		GEventBus.monster_damage_number_requested.emit(entity.entity_id, entity.global_position, dmg.amount, dmg.is_crit)
		# Art & Animation Pipeline Upgrade, vertical slice (design/art/
		# animation-pipeline.md §2 "Monsters: procedural first") -- monster_
		# instance.gd previously had zero Tween usage at all despite being
		# the highest on-screen-frequency entity in the game; this is the
		# closest existing call site to "a monster just took a hit."
		if entity.monster_instance != null:
			entity.monster_instance.play_hit_flash()
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


## ADR-0033: no longer emits monster_died directly — buffers into
## _pending_deaths instead, so Pass 4 can decide once per frame whether to
## emit individually or as a single monsters_died_batch. boss_died and
## queue_free() stay immediate (boss kills are rare, not part of the
## batching problem; queue_free() defers actual deletion to end-of-frame
## regardless, per godot-gdscript-specialist's ADR-0033 review).
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
	_pending_deaths.append(ev)
	entity.queue_free()


## Applies a burn/poison hit as a new, independent ActiveStatusEffect instance
## (stacks, does not refresh existing instances of the same effect_type — see
## ActiveStatusEffect's own doc comment). Reads tower_attacked directly rather
## than going through D&S/_pending_damage — damage-status.md Rule I.3's
## exception note explains why status ticks are a named exception to D&S's
## "single pipeline" ownership.
## armor_penetration/is_crit (Tower Stats System Phase 1, 2026-08-16):
## irrelevant to DoT/slow application — accepted here only because GDScript
## requires exact signal arity match, not silently dropped extra args.
func _on_tower_attacked_status(_tower_id: int, target_monster_id: int, _damage_amount: float,
		_is_siege: bool, _is_armored: bool, effect_type: String, effect_value: float,
		effect_duration: float, _armor_penetration: float, _is_crit: bool) -> void:
	if RECOGNIZED_DOT_EFFECTS.has(effect_type):
		_apply_dot_effect(target_monster_id, effect_type, effect_value, effect_duration)
	elif RECOGNIZED_SLOW_EFFECTS.has(effect_type):
		_apply_slow_effect(target_monster_id, effect_value, effect_duration)
	# Anything else (including "" — no Power effect equipped, OR a failed
	# status_proc_chance roll as of Phase 1) is silently ignored.


func _apply_dot_effect(target_monster_id: int, effect_type: String, effect_value: float,
		effect_duration: float) -> void:
	var entity: MonsterEntity = _entity_lookup.get(target_monster_id) as MonsterEntity
	if entity == null or entity.lifecycle_state == MonsterEntity.State.DEAD:
		return
	var num_ticks: int = maxi(roundi(effect_duration / STATUS_TICK_INTERVAL), 1)
	var effect := ActiveStatusEffect.new()
	effect.effect_type = effect_type
	effect.ticks_remaining = num_ticks
	effect.tick_interval_remaining = STATUS_TICK_INTERVAL
	effect.tick_damage = (effect_value * entity.scaled_hp) / float(num_ticks)
	entity.active_status_effects.append(effect)


## damage-status.md Formula D6. speed_multiplier is 1.0 - effect_value, floored
## at SPEED_MULTIPLIER_FLOOR — never applied by mutating scaled_speed (immutable
## after spawn per ADR-0006).
func _apply_slow_effect(target_monster_id: int, effect_value: float, effect_duration: float) -> void:
	var entity: MonsterEntity = _entity_lookup.get(target_monster_id) as MonsterEntity
	if entity == null or entity.lifecycle_state == MonsterEntity.State.DEAD:
		return
	var slow := ActiveSlowEffect.new()
	slow.remaining_duration = effect_duration
	slow.speed_multiplier = maxf(SPEED_MULTIPLIER_FLOOR, 1.0 - effect_value)
	entity.active_slow_effects.append(slow)


## Product of every active slow instance's speed_multiplier (1.0 if none are
## active) — the multiplicative-stacking combination rule from Formula D6.
## Never mutates entity.scaled_speed itself.
func _effective_speed(entity: MonsterEntity) -> float:
	var multiplier: float = 1.0
	for slow: ActiveSlowEffect in entity.active_slow_effects:
		multiplier *= slow.speed_multiplier
	return entity.scaled_speed * multiplier


# ---------------------------------------------------------------------------
# Pass 1b — Status Effects (burn/poison DoT ticks + slow duration decay)
# ---------------------------------------------------------------------------

## damage-status.md Formulas D5 (DoT) and D6 (slow). Each active DoT instance
## ticks down independently; a tick that kills the entity stops processing
## that entity's remaining instances this frame (matches Pass 1's own
## DEAD-short-circuit convention). Slow instances have no ticks — they just
## decay by delta and are dropped once expired; the movement pass (Pass 3)
## reads active_slow_effects fresh every frame via _effective_speed(), so no
## separate "reapply" step is needed here. Iterates both arrays back-to-front
## so remove_at() during the loop is safe without a second filter pass.
func _pass1b_status_effects(delta: float) -> void:
	for entity in active_monsters:
		if entity.lifecycle_state == MonsterEntity.State.DEAD:
			continue
		_tick_dot_instances(entity, delta)
		if entity.lifecycle_state == MonsterEntity.State.DEAD:
			continue  # a DoT tick just killed this entity — skip its slow decay too
		_decay_slow_instances(entity, delta)


func _tick_dot_instances(entity: MonsterEntity, delta: float) -> void:
	if entity.active_status_effects.is_empty():
		return
	var i: int = entity.active_status_effects.size() - 1
	while i >= 0:
		var effect: ActiveStatusEffect = entity.active_status_effects[i]
		effect.tick_interval_remaining -= delta
		if effect.tick_interval_remaining <= 0.0:
			effect.tick_interval_remaining += STATUS_TICK_INTERVAL
			effect.ticks_remaining -= 1
			var pre_tick_hp: float = entity.current_hp
			entity.current_hp -= effect.tick_damage
			entity.last_hit_source = &"tower"
			if entity.current_hp <= 0.0:
				entity.current_hp = 0.0
				entity.lifecycle_state = MonsterEntity.State.DEAD
				_pending_absorbed.erase(entity.entity_id)
				_emit_death(entity, &"tower")
				return
			if entity.resource.tier == 2:
				GEventBus.boss_hp_changed.emit(entity.entity_id, entity.current_hp, entity.scaled_hp)
			var absorbed: float = minf(effect.tick_damage, pre_tick_hp)
			_pending_absorbed[entity.entity_id] = (_pending_absorbed.get(entity.entity_id, 0.0) as float) + absorbed
		if effect.ticks_remaining <= 0:
			entity.active_status_effects.remove_at(i)
		i -= 1


func _decay_slow_instances(entity: MonsterEntity, delta: float) -> void:
	if entity.active_slow_effects.is_empty():
		return
	var i: int = entity.active_slow_effects.size() - 1
	while i >= 0:
		var slow: ActiveSlowEffect = entity.active_slow_effects[i]
		slow.remaining_duration -= delta
		if slow.remaining_duration <= 0.0:
			entity.active_slow_effects.remove_at(i)
		i -= 1

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
	# Convert cells/sec to world-units/sec using CELL_SIZE. Reads effective
	# speed (scaled_speed x active slow multipliers, Formula D6) fresh every
	# frame — scaled_speed itself is never mutated (stays immutable per ADR-0006).
	var budget: float = _effective_speed(entity) * CELL_SIZE * delta
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
# Pass 3c — Visual Companion Sync (Epic 15 Story 004, ADR-0037)
# ---------------------------------------------------------------------------

## Syncs each still-ACTIVE monster's 3D visual-companion mesh position to its
## just-finalized 2D simulation position, via VisualMath.map_to_3d(). Runs
## immediately after Pass 3 (Movement) — chosen over "run after all 4 passes"
## (ADR-0037's/this story's other documented option) because Pass 3 is the
## ONLY pass that ever writes entity.global_position; placing the sync
## directly after it keeps the sync conceptually adjacent to the pass that
## produces the value it reads, with zero positional difference either way
## since Pass 4 never touches position.
##
## Iterates active_monsters AFTER Pass 3's own swap-buffer rebuild has
## already dropped BREACHED/no-longer-ACTIVE entities from it — a monster
## that breached or was set DEAD earlier this frame is skipped for free, with
## no extra lifecycle_state check needed here (its MonsterInstance/companion
## will be freed for free once its already-queue_free()'d MonsterEntity
## leaves the tree at end of frame, per ADR-0037's stated lifecycle-is-free
## consequence — no separate cleanup path).
##
## SPAWNING entities are intentionally NOT synced here: a SPAWNING entity has
## no path yet and its global_position never changes until it transitions to
## ACTIVE (Pass 3's own contract) — its companion was already seeded with
## the correct position by MonsterInstance._build_visual_companion() at spawn
## time (see that method's own doc comment), so a redundant per-frame sync
## would be wasted work, not a correctness fix.
##
## THIS IS NOT A NEW PER-NODE _physics_process()/_process() OVERRIDE — it is
## one additional method called from inside MonsterManager's own existing
## centralized _physics_process(), which is the single most important
## constraint of this story (ADR-0006's registered forbidden pattern,
## per_monster_physics_process — see this file's class doc comment above).
## No MonsterInstance/MonsterEntity scene script gains any new callback.
## Zero-allocation: map_to_3d() returns a value-type Vector3, and this loop
## reuses the existing active_monsters array (no new Array allocated).
func _pass3c_visual_sync() -> void:
	for entity: MonsterEntity in active_monsters:
		if entity.monster_instance == null:
			continue
		entity.monster_instance.sync_visual_companion_position(
				VisualMath.map_to_3d(entity.global_position, MonsterInstance.MONSTER_LAYER_HEIGHT))

# ---------------------------------------------------------------------------
# Pass 4 — Death & Absorbed flush
# ---------------------------------------------------------------------------

## ADR-0033: decides once per frame whether this frame's deaths emit
## individually (monster_died, the common case) or as a single
## monsters_died_batch (when count > DEATH_BATCH_THRESHOLD) — the two
## signals are mutually exclusive per frame, matching event-bus.md
## Formula 2 / AC-10 and the guarantee resource-economy.md/ADR-0017
## already depends on.
##
## Reassigns _pending_deaths to a fresh Array rather than calling .clear()
## on it — GDScript Arrays are reference types, so monsters_died_batch's
## emit(_pending_deaths) hands subscribers a live reference to this same
## array; clearing it in place would retroactively empty whatever any
## subscriber (or a deferred/queued consumer) holds onto, even though the
## signal already "fired" with real data. Reassignment leaves the emitted
## array's contents intact and untouched by future frames.
func _pass4_death_and_absorbed_flush() -> void:
	if _pending_deaths.size() > DEATH_BATCH_THRESHOLD:
		GEventBus.monsters_died_batch.emit(_pending_deaths)
	else:
		for death_event: MonsterDiedEvent in _pending_deaths:
			GEventBus.monster_died.emit(death_event)
	_pending_deaths = []

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

	# Presentation layer (MonsterInstance, mirrors TowerInstance's pattern):
	# a plain Node2D child at local (0,0) that rides entity's global_position
	# for free. Failure here is non-fatal to spawning — an entity with no
	# visible sprite is still a fully correct simulation entity.
	var instance := MONSTER_INSTANCE_SCENE.instantiate() as MonsterInstance
	entity.add_child(instance)
	instance.configure(res.monster_id, res.tier, res.display_name)
	entity.monster_instance = instance

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
		# ADR-0036: reset the Tarot speed-scalar aggregate on every mission's
		# first wave -- required for retry (MissionSelect.retry_current_mission()
		# reuses this same MonsterManager instance, re-emitting mission_launched
		# without destroying/recreating the scene), otherwise a retried mission
		# would compound this attempt's product against the failed attempt's
		# stale value instead of restarting from F4's "no card -> 1.0" baseline.
		_tarot_speed_scalar_raw = 1.0
		_tarot_speed_scalar = 1.0
	active_monsters.clear()
	spawning_entities.clear()
	_entity_lookup.clear()
	_pending_absorbed.clear()
	_pending_damage.clear()
	_pending_deaths.clear()


## Story 002 (epic-04-wave-manager): wave_completed gained a third
## was_boss_breached: bool field. Godot requires connected handlers to accept
## every argument a signal emits (arity must match exactly, extra args are
## NOT silently dropped) — this handler ignores the new field but must
## declare it to avoid a runtime "Method expected 2 argument(s)" error.
func _on_wave_completed(_wave_number: int, _enemies_remaining: int, _was_boss_breached: bool) -> void:
	_is_wave_active = false
	_pending_absorbed.clear()
	_pending_damage.clear()
	_pending_deaths.clear()
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


## ADR-0036: F2/F4 -- Formula F2's multiplicative running product across all
## equipped tarot_speed_scalar_mult cards, clamped [0.50, 2.00] per F4. Real
## bug fixed here (2026-08-12): this handler previously checked
## modifier_type == "monster_speed_scalar", a string that matches nothing
## Tarot ever emits (the real registered value is "tarot_speed_scalar_mult",
## tarot.md Rule 7's table) -- and even if it had matched, did a last-write-
## wins overwrite instead of F2's multiplicative stacking across cards.
func _on_mission_modifier_applied(modifier_type: String, modifier_value: float, _source: String) -> void:
	if modifier_type == "tarot_speed_scalar_mult":
		_tarot_speed_scalar_raw *= modifier_value
		_tarot_speed_scalar = clamp(_tarot_speed_scalar_raw, 0.50, 2.00)


## Dead code at MVP (Grid locks tower writes during WAVE_ACTIVE). Kept for post-MVP.
func _on_path_invalidated(_affected_cells: Array) -> void:
	pass


func _on_monster_damage_taken(payload: MonsterDamageTaken) -> void:
	_pending_damage.append(payload)
