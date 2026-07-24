extends Node2D

## MissionScene — the generic MISSION-context scene, hosting both Mission
## Select's own browsing/configuring screen AND the live gameplay assembly,
## switching between them based on GMissionSelect.state.
##
## Closes a real, previously-undiscovered gap: `res://src/scenes/
## MissionScene.tscn` (SceneManager's own DEFAULT_MISSION_SCENE_PATH) never
## existed — the only real, playable mission scene was `the_gap.tscn`, a
## directly-booted, single-hardcoded-mission demo that self-emits
## `mission_launched` on a debug timer and never went through
## `SceneManager`/`MissionSelect` at all. This scene is the first one that
## actually connects Sanctuary UI's Launch/Depart -> Mission Select's
## browsing/configuring flow -> a real, played mission, end to end.
##
## Architecture: mirrors sanctuary_ui.gd's own "shell + mutually-exclusive
## content" pattern (OVERVIEW vs ROOM_*) and tarot_deck_ui.gd's (TAROT_DECK
## vs HERO_SKILL_BUILD) — here, MissionSelectScreen (BROWSING/CONFIGURING)
## vs. the live gameplay assembly (LAUNCHED/DORMANT_RETRY_ARMED). Unlike
## those two shells, this one has only 2 states and no persistent chrome of
## its own (Mission HUD, mounted as part of the gameplay assembly, owns its
## own chrome once gameplay is visible).
##
## Gameplay assembly (GridVisual/MonsterManager/TowerSystem/DamageStatus/
## Hero/Camera2D/Mission HUD/PauseMenu) is instanced fresh at _ready() but
## kept invisible/non-processing until `mission_launched` fires — this
## mirrors `the_gap.tscn`'s own exact node structure and known, documented
## stopgaps (Hero._base_stats direct-poke, since no HeroResource pipeline
## exists yet — see that scene's own class doc comment for the full
## rationale, unchanged and not re-litigated here). Grid itself is NOT
## initialized here — `MissionSelect.confirm_launch()` now does that
## directly (a real bug fixed 2026-07-25 alongside this scene), matching
## Grid Rule 9's own direct-call-exception precedent.
##
## No `class_name` declared — matches `sanctuary_scene.gd`'s/`the_gap.gd`'s
## own TD-workflow-001 precedent. Only ever loaded via
## `ResourceLoader.load(path) as PackedScene`.

## mission-select.md Rule 2: cell_size is a fixed project-wide constant for
## every mission, always — safe to hardcode here rather than reading it back
## off Grid (which has no public getter for it).
const CELL_SIZE: float = 64.0

@onready var _mission_select_screen: Control = $MissionSelectScreen
@onready var _gameplay_root: Node2D = $GameplayRoot
@onready var _grid_visual: Node2D = $GameplayRoot/GridVisual
@onready var _hero: Hero = $GameplayRoot/Hero
@onready var _camera: Camera2D = $GameplayRoot/Camera2D
@onready var _monsters_container: Node2D = $GameplayRoot/MonstersContainer


func _ready() -> void:
	_gameplay_root.visible = false
	_gameplay_root.set_process(false)
	_gameplay_root.set_physics_process(false)

	GEventBus.mission_launched.connect(_on_mission_launched)
	GEventBus.monster_spawned.connect(_on_monster_spawned)


func _exit_tree() -> void:
	GEventBus.mission_launched.disconnect(_on_mission_launched)
	GEventBus.monster_spawned.disconnect(_on_monster_spawned)


## Swaps from the Mission Select screen to the live gameplay assembly.
## Grid is already initialized by MissionSelect.confirm_launch()/
## retry_current_mission() by the time this fires — this handler only
## positions the camera/hero against Grid's now-live state and activates
## the gameplay subtree, mirroring the_gap.gd's own _ready() assembly.
func _on_mission_launched(_mission_id: String, _modifiers: PackedStringArray, _difficulty_tier: int) -> void:
	if _mission_select_screen.has_method(&"disconnect_own_subscriptions"):
		_mission_select_screen.disconnect_own_subscriptions()
	_mission_select_screen.visible = false
	_mission_select_screen.set_process_unhandled_input(false)

	_gameplay_root.visible = true
	_gameplay_root.set_process(true)
	_gameplay_root.set_physics_process(true)

	if _grid_visual.has_method(&"configure"):
		var cells: Dictionary = {}
		for row: int in range(GGrid.get_grid_rows()):
			for col: int in range(GGrid.get_grid_cols()):
				var cell := Vector2i(col, row)
				cells[cell] = GGrid.get_cell_type(cell)
		_grid_visual.call(&"configure", GGrid.get_grid_cols(), GGrid.get_grid_rows(), CELL_SIZE, cells)
	else:
		push_error("[MissionScene] GridVisual node has no configure() method — grid will not render.")

	_camera.position = Vector2(GGrid.get_grid_cols() * CELL_SIZE / 2.0, GGrid.get_grid_rows() * CELL_SIZE / 2.0)
	_camera.zoom = Vector2(0.85, 0.85)

	var spawn_cells: Array[Vector2i] = GGrid.get_spawn_cells()
	_hero.global_position = GGrid.cell_to_world(spawn_cells[0]) if not spawn_cells.is_empty() else Vector2.ZERO
	_set_hero_placeholder_stats()


## Stopgap, unchanged from the_gap.gd's own identical, already-flagged gap:
## no HeroResource pipeline exists yet to author these values externally.
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


## Mirrors the_gap.gd's own identical visual-grouping handler.
func _on_monster_spawned(payload: MonsterSpawnedEvent) -> void:
	var monster_manager: MonsterManager = $GameplayRoot/MonsterManager
	var entity: MonsterEntity = monster_manager._entity_lookup.get(payload.entity_id) as MonsterEntity
	if entity == null:
		return
	entity.reparent(_monsters_container)
	var size: float = 40.0 if payload.monster_id == &"goblin_warlord_boss" else 20.0
	var vis := ColorRect.new()
	vis.size = Vector2(size, size)
	vis.position = Vector2(-size / 2.0, -size / 2.0)
	vis.color = Color(0.9, 0.6, 0.1)
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entity.add_child(vis)


func _unhandled_input(event: InputEvent) -> void:
	if not _gameplay_root.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell: Vector2i = GGrid.world_to_cell(get_global_mouse_position())
		$GameplayRoot/TowerSystem.place_tower(&"archer", cell)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		GEventBus.player_ready.emit()
