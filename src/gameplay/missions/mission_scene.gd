extends Node2D

## Generic, data-driven mission scene controller.
##
## Reads its GridConfig and difficulty tier from the mission's MissionEntry
## resource (GGameDataRegistry.get_mission_entry(mission_id)) instead of
## hardcoding a per-mission grid layout in GDScript — the approach the_gap.gd
## used before Mission Select System's MissionEntry data model existed
## (see the_gap.gd's own class doc comment, deviation #1). Now that
## MissionEntry .tres content is authored (assets/data/missions/entries/),
## new missions instance this one controller with mission_id set, rather
## than duplicating the_gap.gd's ~400-line hardcoded scene-assembly script
## per mission.
##
## the_gap.tscn itself is left untouched — it remains the original
## hand-verified vertical-slice capstone (S4-09) and is not migrated here
## retroactively; this generic controller is for missions added after
## MissionEntry existed (The Foothills, The Hollow).
##
## Subsystem wiring (Grid, WaveManager, MonsterManager, TowerSystem,
## DamageStatus, Hero, debug HUD, debug tower placement/hero-kill) mirrors
## the_gap.gd exactly — those subsystems are mission-agnostic by design.

## Set per-instance in the wrapper scene (e.g. the_foothills.tscn), matching
## the MissionEntry.mission_id this scene should load and launch.
@export var mission_id: String = ""

## Same QA-only stopgap as the_gap.gd (deviation #5 there) — gates the K-key
## debug-kill-hero trigger. Left-click (tower placement) and SPACE
## (ready-up) are real interactions and are never gated by this flag.
@export var debug_controls_enabled: bool = false

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
var _cell_size: float = 64.0
var _recommended_difficulty_tier: int = 1

## design/quick-specs/combat-tower-placeholder-visual-layer-2026-07-31.md —
## tower_id(int) -> ColorRect placeholder, same pattern as the_gap.gd.
var _tower_visuals: Dictionary = {}


func _ready() -> void:
	var entry: MissionEntry = GGameDataRegistry.get_mission_entry(mission_id)
	if entry == null:
		push_error("[mission_scene] No MissionEntry found for mission_id='%s' — check assets/data/missions/entries/ and this scene's exported mission_id." % mission_id)
		return

	_recommended_difficulty_tier = entry.recommended_difficulty_tier

	_monsters_container = Node2D.new()
	_monsters_container.name = "MonstersContainer"
	add_child(_monsters_container)

	var config: GridConfig = entry.grid_config
	_cell_size = config.cell_size
	GGrid.initialize(config)
	# Dynamic dispatch (see the_gap.gd's grid_visual.gd doc comment for why
	# GridVisual is typed Node2D, not a GridVisual class_name).
	if _grid_visual.has_method(&"configure"):
		_grid_visual.call(&"configure", config.cols, config.rows, config.cell_size, config.cells)
	else:
		push_error("[mission_scene] GridVisual node ($GridVisual) has no configure() method — grid will not render.")

	_camera.position = Vector2(config.cols * config.cell_size / 2.0, config.rows * config.cell_size / 2.0)
	_camera.zoom = Vector2(0.85, 0.85)

	# Monster/tower blueprint data self-populates from GGameDataRegistry
	# (see the_gap.gd's own deviation #2 note) — no scene-local wiring needed.

	_hero.global_position = GGrid.cell_to_world(_hero_spawn_cell(config.cols, config.rows))
	_set_hero_placeholder_stats()

	GEventBus.monster_spawned.connect(_on_monster_spawned)
	GEventBus.mission_phase_changed.connect(_on_mission_phase_changed)
	GEventBus.wave_started.connect(_on_wave_started)
	GEventBus.wave_completed.connect(_on_wave_completed)
	GEventBus.tower_placed.connect(_on_tower_placed)
	GEventBus.tower_removed.connect(_on_tower_removed)
	GEventBus.tower_destroyed.connect(_on_tower_destroyed)

	_hud_phase_label.text = "Phase: (not launched)"
	_hud_wave_label.text = "Wave: -"
	_hud_timer_label.text = "Timer: --"
	_hud_help_label.text = "SPACE = ready-up | Left-click = place tower"
	if debug_controls_enabled:
		_hud_help_label.text += " | K = debug-kill hero (QA only)"

	set_process(true)

	# No Mission Select UI flow wired into this debug scene yet (same
	# stopgap as the_gap.gd) — auto-launch after a short delay instead.
	await get_tree().create_timer(1.0).timeout
	_launch_mission()
	GEventBus.resources_changed.emit(500, &"debug_seed")  # fires after mission_launched so it isn't wiped by GMissionEconomy's reset


func _exit_tree() -> void:
	GEventBus.monster_spawned.disconnect(_on_monster_spawned)
	GEventBus.mission_phase_changed.disconnect(_on_mission_phase_changed)
	GEventBus.wave_started.disconnect(_on_wave_started)
	GEventBus.wave_completed.disconnect(_on_wave_completed)
	GEventBus.tower_placed.disconnect(_on_tower_placed)
	GEventBus.tower_removed.disconnect(_on_tower_removed)
	GEventBus.tower_destroyed.disconnect(_on_tower_destroyed)


# ---------------------------------------------------------------------------
# Hero spawn placement — generalizes the_gap.gd's "2 cells inward from the
# SPAWN cell" placement to any border-edge SPAWN cell, not just a left-edge
# one. Every authored mission (the_gap, the_foothills, the_hollow) places
# SPAWN on a grid border edge; this offsets 2 cells toward the grid interior
# along whichever axis the SPAWN cell sits on the border of.
# ---------------------------------------------------------------------------

func _hero_spawn_cell(cols: int, rows: int) -> Vector2i:
	var spawn_cells: Array[Vector2i] = GGrid.get_spawn_cells()
	if spawn_cells.is_empty():
		push_error("[mission_scene] MissionEntry '%s' has no SPAWN cell — hero will spawn at (0,0)." % mission_id)
		return Vector2i.ZERO
	var spawn: Vector2i = spawn_cells[0]
	if spawn.x == 0:
		return spawn + Vector2i(2, 0)
	if spawn.x == cols - 1:
		return spawn + Vector2i(-2, 0)
	if spawn.y == 0:
		return spawn + Vector2i(0, 2)
	if spawn.y == rows - 1:
		return spawn + Vector2i(0, -2)
	return spawn


# ---------------------------------------------------------------------------
# Deviation #3 (the_gap.gd) — same Hero base-stats stopgap, no HeroResource
# pipeline exists yet.
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
	GEventBus.mission_launched.emit(mission_id, PackedStringArray([]), _recommended_difficulty_tier)


# ---------------------------------------------------------------------------
# Debug input (same QA-only pattern as the_gap.gd)
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell: Vector2i = GGrid.world_to_cell(get_global_mouse_position())
		var placed: bool = _tower_system.place_tower(&"archer", cell)
		print("[mission_scene][%s][debug] tower placement attempt at %s -> %s" % [mission_id, cell, placed])
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			GEventBus.player_ready.emit()
		elif event.keycode == KEY_K and debug_controls_enabled:
			_debug_kill_hero()


## QA-ONLY STOPGAP — NOT a real combat path. See the_gap.gd's deviation #5.
func _debug_kill_hero() -> void:
	GEventBus.hero_damage_taken.emit(999999, 0)


# ---------------------------------------------------------------------------
# Monster/tower placeholder visuals — identical to the_gap.gd (deviation #4).
# ---------------------------------------------------------------------------

func _on_monster_spawned(payload: MonsterSpawnedEvent) -> void:
	var entity: MonsterEntity = _monster_manager._entity_lookup.get(payload.entity_id) as MonsterEntity
	if entity == null:
		return
	entity.reparent(_monsters_container)
	var size: float = 40.0 if payload.monster_id in [&"goblin_warlord_boss", &"rift_sentinel_boss"] else 20.0
	var vis := ColorRect.new()
	vis.size = Vector2(size, size)
	vis.position = Vector2(-size / 2.0, -size / 2.0)
	vis.color = _color_for_monster(payload.monster_id)
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entity.add_child(vis)


func _color_for_monster(monster_id: StringName) -> Color:
	match monster_id:
		&"forest_troll_elite", &"bog_lurker_elite":
			return Color(0.6, 0.2, 0.8)
		&"goblin_warlord_boss", &"rift_sentinel_boss":
			return Color(0.9, 0.1, 0.1)
		_:
			return Color(0.9, 0.6, 0.1)


func _on_tower_placed(payload: TowerPlacedEvent) -> void:
	var vis := ColorRect.new()
	vis.size = Vector2(payload.footprint) * _cell_size
	vis.position = GGrid.cell_to_world(payload.grid_position)
	vis.color = _color_for_tower_archetype(payload.archetype)
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vis)
	_tower_visuals[payload.tower_id] = vis


func _on_tower_removed(tower_id: int, _grid_position: Vector2i, _archetype: String, _constellation_eligibility_tag: String) -> void:
	_free_tower_visual(tower_id)


func _on_tower_destroyed(tower_id: int, _grid_position: Vector2i, _archetype: String, _footprint: Array, _constellation_eligibility_tag: String) -> void:
	_free_tower_visual(tower_id)


func _free_tower_visual(tower_id: int) -> void:
	var vis: ColorRect = _tower_visuals.get(tower_id) as ColorRect
	if vis == null:
		return
	if is_instance_valid(vis):
		vis.queue_free()
	_tower_visuals.erase(tower_id)


## Same Archetype Color Language table as the_gap.gd (tower.md Visual/Audio
## Requirements section).
func _color_for_tower_archetype(archetype: String) -> Color:
	match archetype:
		"physical":
			return Color(0.6, 0.6, 0.65)
		"ranged":
			return Color(0.55, 0.4, 0.25)
		"elemental":
			return Color(0.6, 0.85, 0.95)
		"support":
			return Color(0.9, 0.75, 0.3)
		_:
			return Color.MAGENTA


# ---------------------------------------------------------------------------
# Debug HUD — identical to the_gap.gd (deviation #6).
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
