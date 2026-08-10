extends Node2D

## "The Gap" mission scene controller — S4-09 (epic-04-wave-manager) capstone.
##
## Story: production/epics/epic-04-wave-manager/story-008-assemble-the-gap-mission-scene.md
## This story is scene-assembly + integration verification, not new gameplay logic.
## Every subsystem wired here (Grid, WaveManager, MonsterManager, TowerSystem, Hero) was
## implemented and unit/integration-tested in isolation by Stories 001-007 (epic-04) and
## Epic 02 (Hero). This script's job is ONLY to assemble them into one real, playable scene.
##
## Known deviations / documented workarounds (all flagged in the S4-09 report; none of
## them modify Stories 001-007's or Epic 02's actual production source):
##   1. GridConfig is built programmatically here (not a .tres) — no Mission Select System
##      exists yet to author one externally (confirmed Not Started in systems-index.md).
##   2. [S5-01, 2026-07-07] TD-data-001 CLOSED — GameDataRegistry now scans
##      res://assets/data/towers/blueprints/ for TowerData at boot (mirroring its
##      existing MonsterResource loader), and MonsterManager/TowerSystem each
##      self-populate their own lookup table from GGameDataRegistry at _ready()
##      if empty. This scene no longer needs the _wire_monster_data()/_wire_tower_data()
##      workaround it previously used — removed. [Closed further 2026-08-11]
##      the 500-gold debug seed this point used to note is gone too — Resource
##      Economy now has a real `ResourceEconomy` node in this scene (it was
##      never instanced anywhere before, real or test-adjacent scenes alike,
##      so the Scout Phase starting grant and monster-kill drops never
##      actually fired in real gameplay regardless of the debug seed).
##   3. Hero._base_stats has no public setter (no HeroResource pipeline exists yet — a
##      known, previously-flagged gap in Story 008/epic-02's own Completion Notes). Set
##      directly here as a documented stopgap so the Hero isn't shipped at 0 HP.
##   4. [S4-18, 2026-07-06] TD-monster-003 CLOSED — MonsterManager now calls add_child()
##      on every spawned entity itself (src/core/monster/monster_manager.gd::_spawn_entity()),
##      so entities are real scene-tree nodes from creation, not orphans. This scene's
##      _on_monster_spawned() handler now just reparent()s the entity into MonstersContainer
##      for visual grouping (add_child() would error, since the entity already has a parent
##      by the time this synchronous EventBus handler runs) and attaches the placeholder
##      visual — same as before, minus the orphan-node gap.
##   5. Debug-only "kill hero" trigger (K key): EventBus.hero_incoming_damage's own doc
##      comment confirms no production attack source exists yet anywhere in this codebase
##      — the DEFEAT playthrough AC can only be exercised via a direct debug emission.
##      NOT a real combat path. Gated behind `debug_controls_enabled` (S4-11 playtest
##      prep, default false) so real human playtesters never see or trigger it.
##   6. Debug HUD timer reads GWaveManager's private Timer nodes directly — Mission HUD's
##      own `phase_timer_tick` EventBus signal is declared but never emitted by any
##      production code (grep-verified); this is a scaffolding-only substitute, consistent
##      with Mission HUD's Skeleton status (this story does not implement real Mission HUD).
##
## Bug found and fixed during code-review follow-up (this story's own AC-6 real-combat
## test, added in response to a review finding that AC-6 had zero test coverage):
## `DamageStatusSystem` (`src/core/damage_status/damage_status.gd`) is documented in
## `docs/architecture/adr-0002-scene-autoload-structure.md` as "Scene-instanced,
## Mission-only" — every mission scene is required to instance it — but `the_gap.tscn`
## never did. Net effect: `Hero.hero_auto_attacked` had no subscriber anywhere in the
## real assembled scene, so real Hero auto-attacks never actually damaged a spawned
## monster's HP in real gameplay (the emission fired correctly; nothing consumed it).
## The new AC-6 test caught this directly (asserted HP decreased after a real attack;
## it did not, since no DamageStatus node existed to run the D&S pipeline). Fixed by
## adding a `DamageStatus` node to `the_gap.tscn`, mirroring the existing
## MonsterManager/TowerSystem node pattern (plain `Node`, self-wires entirely via its
## own `_ready()`/`_exit_tree()` EventBus subscriptions — no scene-local wiring needed).
## Tracked for traceability: docs/tech-debt-register.md TD-damage-001.

const MISSION_ID: String = "the_gap"
const GRID_COLS: int = 16
const GRID_ROWS: int = 12
const CELL_SIZE: float = 64.0
const SPAWN_CELL: Vector2i = Vector2i(0, 6)
const GOAL_CELL: Vector2i = Vector2i(15, 6)

## S4-11 playtest prep: the K-key "debug-kill hero" trigger (deviation #5 below)
## is a QA-only stopgap, not a real combat path — exposing it to a human
## playtester with no developer context risks a confusing false "bug report"
## (instant death, no visible cause). Defaults to false for real play sessions;
## flip to true in the Inspector when a developer needs to exercise DEFEAT
## manually for QA. Left-click (tower placement) and SPACE (ready-up) are real
## interactions and are never gated by this flag.
@export var debug_controls_enabled: bool = false

## Typed as Node2D (the real base type), NOT GridVisual — grid_visual.gd
## deliberately declares no class_name (see its own class doc comment: a
## fresh class_name failed to resolve in a purely headless run during this
## story's own verification pass, a real witnessed Godot 4.6.2 class-cache
## fragility for a newly added script). Node2D is always resolvable without a
## class-cache rescan. Since Node2D has no configure() method, the call in
## _ready() is dispatched dynamically via .call() — guarded by has_method()
## so a typo'd/renamed method name fails loudly with a clear, actionable
## push_error instead of silently no-op'ing or only surfacing the engine's
## generic "Nonexistent function" console error.
@onready var _grid_visual: Node2D = $GridVisual
@onready var _monster_manager: MonsterManager = $MonsterManager
@onready var _tower_system: TowerSystem = $TowerSystem
@onready var _hero: Hero = $Hero
@onready var _camera: Camera2D = $Camera2D
@onready var _hud_phase_label: Label = $HUD/Panel/VBox/PhaseLabel
@onready var _hud_wave_label: Label = $HUD/Panel/VBox/WaveLabel
@onready var _hud_timer_label: Label = $HUD/Panel/VBox/TimerLabel
@onready var _hud_help_label: Label = $HUD/Panel/VBox/HelpLabel

var _monsters_container: Node2D

const TowerInstanceScene: PackedScene = preload("res://src/core/tower/TowerInstance.tscn")

## Upgraded 2026-08-11 from design/quick-specs/combat-tower-placeholder-
## visual-layer-2026-07-31.md's original flat ColorRect to real per-
## archetype art (tower_instance.gd) -- that spec's own "Out of Scope"
## section named this exact swap as future work ("this is the placeholder
## layer the real art... will replace later"), and the real art
## (assets/art/towers/) already existed, along with tower_instance.gd's own
## configure(archetype) method -- both were simply never wired to a live
## placement call site until now. TowerSystem itself stays pure data/logic
## (no scene involvement); this scene owns the visual exactly like it
## already owns monster visuals via _on_monster_spawned().
var _tower_visuals: Dictionary = {}  # tower_id(int) -> TowerInstance

## Tower Build Panel's own pending selection (Mission HUD's Planning Cluster,
## added 2026-08-10) — see mission_scene.gd's identical field for the full
## rationale. Empty = nothing selected; a click is then a no-op instead of
## the previous hardcoded `place_tower(&"archer", cell)` debug behavior.
var _selected_blueprint_id: StringName = &""


func _ready() -> void:
	_monsters_container = Node2D.new()
	_monsters_container.name = "MonstersContainer"
	add_child(_monsters_container)

	var config: GridConfig = _build_grid_config()
	GGrid.initialize(config)
	# Dynamic dispatch (see _grid_visual's own doc comment for why it is typed
	# Node2D rather than a GridVisual class_name). has_method() guard closes
	# the "unchecked dynamic dispatch" gap flagged in code review: a
	# typo'd/renamed configure() method now fails loudly and immediately via
	# push_error, rather than the call silently doing nothing (Callable.call()
	# on an absent method logs an engine-level error but does not halt or
	# otherwise surface as a clear diagnostic).
	if _grid_visual.has_method(&"configure"):
		_grid_visual.call(&"configure", config.cols, config.rows, config.cell_size, config.cells)
	else:
		push_error("[the_gap] GridVisual node ($GridVisual) has no configure() method — grid will not render. Check grid_visual.gd for a renamed/removed method.")

	_camera.position = Vector2(config.cols * config.cell_size / 2.0, config.rows * config.cell_size / 2.0)
	_camera.zoom = Vector2(0.85, 0.85)

	# Monster/tower blueprint data is now self-populated by MonsterManager/TowerSystem
	# from GGameDataRegistry at their own _ready() (S5-01, closing TD-data-001) — no
	# scene-local wiring needed here anymore. Gold is now owned by GMissionEconomy
	# (Epic 03 Story 013) — TowerSystem no longer has its own _player_gold field to
	# poke. The debug seed now flows through the real system via resources_changed
	# (see below, AFTER _launch_mission() — mission_launched resets the balance to 0,
	# so seeding here would be wiped before the player ever sees it).

	_hero.global_position = GGrid.cell_to_world(Vector2i(2, 6))
	_set_hero_placeholder_stats()

	GEventBus.monster_spawned.connect(_on_monster_spawned)
	GEventBus.mission_phase_changed.connect(_on_mission_phase_changed)
	GEventBus.wave_started.connect(_on_wave_started)
	GEventBus.wave_completed.connect(_on_wave_completed)
	GEventBus.tower_placed.connect(_on_tower_placed)
	GEventBus.tower_removed.connect(_on_tower_removed)
	GEventBus.tower_destroyed.connect(_on_tower_destroyed)
	GEventBus.tower_blueprint_selected.connect(_on_tower_blueprint_selected)

	_hud_phase_label.text = "Phase: (not launched)"
	_hud_wave_label.text = "Wave: -"
	_hud_timer_label.text = "Timer: --"
	_hud_help_label.text = "SPACE = ready-up | Left-click = place tower"
	if debug_controls_enabled:
		_hud_help_label.text += " | K = debug-kill hero (QA only)"

	set_process(true)

	# No Mission Select System exists yet (confirmed Not Started, systems-index.md) —
	# per this story's Out of Scope section, use a debug auto-launch instead of a
	# mission-select UI.
	await get_tree().create_timer(1.0).timeout
	_launch_mission()
	# TD-data-001's debug-seeded 500-gold stopgap removed 2026-08-11: closed by
	# adding a real ResourceEconomy node to this scene (it was never instanced
	# anywhere before, so the real Scout Phase starting grant — and monster-kill
	# drops — never actually fired in real gameplay; this debug line was masking
	# that gap, not working around a real absence of the mechanism).


func _exit_tree() -> void:
	GEventBus.monster_spawned.disconnect(_on_monster_spawned)
	GEventBus.mission_phase_changed.disconnect(_on_mission_phase_changed)
	GEventBus.wave_started.disconnect(_on_wave_started)
	GEventBus.wave_completed.disconnect(_on_wave_completed)
	GEventBus.tower_placed.disconnect(_on_tower_placed)
	GEventBus.tower_removed.disconnect(_on_tower_removed)
	GEventBus.tower_destroyed.disconnect(_on_tower_destroyed)
	GEventBus.tower_blueprint_selected.disconnect(_on_tower_blueprint_selected)


# ---------------------------------------------------------------------------
# Grid layout — deviation #1 (see class doc comment)
# ---------------------------------------------------------------------------

func _build_grid_config() -> GridConfig:
	var config := GridConfig.new()
	config.cols = GRID_COLS
	config.rows = GRID_ROWS
	config.cell_size = CELL_SIZE

	var path_cells: Array[Vector2i] = []
	path_cells.append_array(_line_cells(Vector2i(0, 6), Vector2i(4, 6)))
	path_cells.append_array(_line_cells(Vector2i(4, 6), Vector2i(4, 2)))
	path_cells.append_array(_line_cells(Vector2i(4, 2), Vector2i(10, 2)))
	path_cells.append_array(_line_cells(Vector2i(10, 2), Vector2i(10, 9)))
	path_cells.append_array(_line_cells(Vector2i(10, 9), Vector2i(14, 9)))
	path_cells.append_array(_line_cells(Vector2i(14, 9), Vector2i(14, 6)))
	path_cells.append_array(_line_cells(Vector2i(14, 6), Vector2i(15, 6)))

	var path_set: Dictionary = {}
	for cell: Vector2i in path_cells:
		path_set[cell] = true

	for row: int in range(GRID_ROWS):
		for col: int in range(GRID_COLS):
			var cell := Vector2i(col, row)
			if cell == SPAWN_CELL:
				config.cells[cell] = Grid.CellType.SPAWN
			elif cell == GOAL_CELL:
				config.cells[cell] = Grid.CellType.GOAL
			elif path_set.has(cell):
				config.cells[cell] = Grid.CellType.PATH
			elif row == 0 or row == GRID_ROWS - 1 or col == 0 or col == GRID_COLS - 1:
				config.cells[cell] = Grid.CellType.BLOCKED
			else:
				config.cells[cell] = Grid.CellType.PLACEABLE

	return config


## Inclusive orthogonal line between two cells sharing a row or column.
func _line_cells(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if from.x == to.x:
		var step: int = 1 if to.y >= from.y else -1
		var y: int = from.y
		while true:
			result.append(Vector2i(from.x, y))
			if y == to.y:
				break
			y += step
	else:
		var step_x: int = 1 if to.x >= from.x else -1
		var x: int = from.x
		while true:
			result.append(Vector2i(x, from.y))
			if x == to.x:
				break
			x += step_x
	return result


# ---------------------------------------------------------------------------
# Deviation #3 — Hero base stats stopgap
# ---------------------------------------------------------------------------

func _set_hero_placeholder_stats() -> void:
	_hero._base_stats = {
		&"max_hp": 500.0,
		&"damage": 25.0,
		&"move_speed": 220.0,
		&"cdr": 0.0,
		&"crit_chance": 0.1,
		&"armor": 0.0,
		&"skill_power": 10.0,
		&"attack_range": 220.0,
		&"elemental_resist_fire": 0.0,
		&"elemental_resist_frost": 0.0,
		&"lifesteal": 0.0,
		&"tower_affinity": 1.0,
		&"crit_multiplier": 0.0,
	}
	_hero.reset_to_defaults()


func _launch_mission() -> void:
	GEventBus.mission_launched.emit(MISSION_ID, PackedStringArray([]), 1)


# ---------------------------------------------------------------------------
# Debug input (deviation #5 — hero-kill is QA-only, not real combat)
# ---------------------------------------------------------------------------

func _on_tower_blueprint_selected(blueprint_id: StringName) -> void:
	_selected_blueprint_id = blueprint_id
	_update_placement_preview()


## Grid Placement Cursor (design/ux/interaction-patterns.md) — see
## mission_scene.gd's identical method for the full decoupling rationale.
func _update_placement_preview() -> void:
	if _selected_blueprint_id == &"":
		GEventBus.tower_placement_preview_updated.emit(Vector2i(-1, -1), Vector2i.ZERO, false)
		return
	var blueprints: Dictionary = GGameDataRegistry.get_all_tower_blueprints()
	var data: TowerBlueprintData = blueprints.get(_selected_blueprint_id) as TowerBlueprintData
	if data == null:
		return
	var cell: Vector2i = GGrid.world_to_cell(get_global_mouse_position())
	var preview: PlacementPreview = _tower_system.get_placement_preview(_selected_blueprint_id, cell)
	GEventBus.tower_placement_preview_updated.emit(cell, data.foundation.footprint, preview.valid)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _selected_blueprint_id == &"":
			return
		var cell: Vector2i = GGrid.world_to_cell(get_global_mouse_position())
		var placed: bool = _tower_system.place_tower(_selected_blueprint_id, cell)
		print("[the_gap][debug] tower placement attempt at %s -> %s" % [cell, placed])
	elif event is InputEventMouseMotion:
		_update_placement_preview()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			GEventBus.player_ready.emit()
		elif event.keycode == KEY_K and debug_controls_enabled:
			_debug_kill_hero()


## QA-ONLY STOPGAP — NOT a real combat path. See class doc comment deviation #5.
func _debug_kill_hero() -> void:
	GEventBus.hero_damage_taken.emit(999999, 0)


# ---------------------------------------------------------------------------
# Deviation #4 — monster visibility grouping (TD-monster-003 closed: MonsterManager
# now parents every spawned entity into the scene tree itself, right at creation
# time — see monster_manager.gd::_spawn_entity(). This handler no longer needs to
# be the entity's FIRST parent; it just moves the entity from MonsterManager into
# this scene's dedicated MonstersContainer for visual grouping, using reparent()
# (not add_child(), which would error — the entity already has a parent by the
# time this synchronous EventBus handler runs).
# ---------------------------------------------------------------------------

func _on_monster_spawned(payload: MonsterSpawnedEvent) -> void:
	var entity: MonsterEntity = _monster_manager._entity_lookup.get(payload.entity_id) as MonsterEntity
	if entity == null:
		return
	entity.reparent(_monsters_container)
	var size: float = 40.0 if payload.monster_id == &"goblin_warlord_boss" else 20.0
	var vis := ColorRect.new()
	vis.size = Vector2(size, size)
	vis.position = Vector2(-size / 2.0, -size / 2.0)
	vis.color = _color_for_monster(payload.monster_id)
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entity.add_child(vis)


func _color_for_monster(monster_id: StringName) -> Color:
	match monster_id:
		&"forest_troll_elite":
			return Color(0.6, 0.2, 0.8)
		&"goblin_warlord_boss":
			return Color(0.9, 0.1, 0.1)
		_:
			return Color(0.9, 0.6, 0.1)


# ---------------------------------------------------------------------------
# design/quick-specs/combat-tower-placeholder-visual-layer-2026-07-31.md —
# TowerSystem stays pure data/logic (no scene involvement, per its own
# established boundary); this scene owns the placeholder visual entirely,
# mirroring the monster-visual pattern above. Static IDLE-only rect — no
# TARGETING/ATTACKING/DESTROYED state art, no projectile VFX (all real
# content-authoring work tower.md's own Visual/Audio Requirements section
# defers to later).
# ---------------------------------------------------------------------------

## GGrid.cell_to_world() returns a cell's CENTER (not top-left, unlike the
## old ColorRect's .position convention) — TowerInstance is a Node2D whose
## Sprite2D is centered on it by construction, so this is now the correct
## placement, not an approximation. Footprint >1 (no current blueprint uses
## one, but TowerBlueprintData supports it) centers on the whole footprint,
## not just its top-left cell.
func _on_tower_placed(payload: TowerPlacedEvent) -> void:
	var vis: TowerInstance = TowerInstanceScene.instantiate()
	add_child(vis)
	vis.position = GGrid.cell_to_world(payload.grid_position) + Vector2(payload.footprint - Vector2i.ONE) * CELL_SIZE * 0.5
	vis.configure(payload.archetype)
	_tower_visuals[payload.tower_id] = vis


func _on_tower_removed(tower_id: int, _grid_position: Vector2i, _archetype: String, _constellation_eligibility_tag: String) -> void:
	_free_tower_visual(tower_id)


func _on_tower_destroyed(tower_id: int, _grid_position: Vector2i, _archetype: String, _footprint: Array, _constellation_eligibility_tag: String) -> void:
	_free_tower_visual(tower_id)


func _free_tower_visual(tower_id: int) -> void:
	var vis: TowerInstance = _tower_visuals.get(tower_id) as TowerInstance
	if vis == null:
		return
	if is_instance_valid(vis):
		vis.queue_free()
	_tower_visuals.erase(tower_id)


# ---------------------------------------------------------------------------
# Debug HUD (deviation #6 — Mission HUD remains Skeleton; this is scaffolding)
# ---------------------------------------------------------------------------

func _on_mission_phase_changed(_previous_phase: String, new_phase: String, _timestamp: float) -> void:
	_hud_phase_label.text = "Phase: %s" % new_phase


func _on_wave_started(wave_number: int, total_waves: int, _wave_difficulty: float) -> void:
	_hud_wave_label.text = "Wave: %d / %d" % [wave_number, total_waves]


func _on_wave_completed(wave_number: int, enemies_remaining: int, _was_boss_breached: bool) -> void:
	_hud_wave_label.text = "Wave %d cleared (%d remaining)" % [wave_number, enemies_remaining]


func _process(_delta: float) -> void:
	var remaining: float = -1.0
	match GWaveManager._phase:
		WaveManager.Phase.SCOUT:
			remaining = GWaveManager._scout_timer.time_left
		WaveManager.Phase.PRE_WAVE:
			remaining = GWaveManager._pre_wave_timer.time_left
		WaveManager.Phase.INTERMISSION:
			remaining = GWaveManager._intermission_timer.time_left
	if remaining >= 0.0:
		_hud_timer_label.text = "Timer: %.1fs" % remaining
	else:
		_hud_timer_label.text = "Timer: --"
