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

const TowerInstanceScene: PackedScene = preload("res://src/core/tower/TowerInstance.tscn")
const ProjectileVisualScene: PackedScene = preload("res://src/scenes/ProjectileVisual.tscn")
const AoeRingVisualScene: PackedScene = preload("res://src/scenes/AoeRingVisual.tscn")
const PlacementRejectFlashScene: PackedScene = preload("res://src/scenes/PlacementRejectFlash.tscn")
const TowerDestroyVFXScene: PackedScene = preload("res://src/scenes/TowerDestroyVFX.tscn")
const MonsterDeathVFXScene: PackedScene = preload("res://src/scenes/MonsterDeathVFX.tscn")

## design/monster.md "Death VFX" BOSS row: "screen micro-shake (0.1-0.15s,
## low amplitude)." Camera2D.offset (not .position) is used specifically
## because it's independent of whatever is actually driving camera position
## — the shake can never fight with or permanently displace the camera's
## real tracked position, it always resets to Vector2.ZERO when done.
const BOSS_DEATH_SHAKE_DURATION: float = 0.12
const BOSS_DEATH_SHAKE_MAGNITUDE: float = 6.0  ## world units
const BOSS_DEATH_SHAKE_STEPS: int = 4

## design/gdd/tower.md "Archetype projectile color language": Support =
## "Warm gold / pale light." Support towers never fire a projectile (Rule
## 5a), so this never lived in ProjectileVisual's own ARCHETYPE_COLORS —
## it's used only for the aura pulse ring.
const SUPPORT_AURA_COLOR: Color = Color(0.95, 0.75, 0.3)

## design/gdd/tower.md "Placement Confirmed" Visual/Audio Requirements: the
## ghost "solidifies to full opacity" — no archetype/element color is
## specified for the ripple itself (unlike the projectile/detonation VFX,
## which are explicitly elemental), so a neutral pale color is used
## uniformly across every archetype.
const PLACEMENT_CONFIRM_COLOR: Color = Color(0.95, 0.95, 0.9)
const PLACEMENT_CONFIRM_DURATION: float = 0.3  ## seconds, per the GDD's own "~0.3s" spec

@onready var _mission_select_screen: Control = $MissionSelectLayer/MissionSelectScreen
@onready var _gameplay_root: Node2D = $GameplayRoot
@onready var _grid_visual: Node2D = $GameplayRoot/GridVisual
@onready var _hero: Hero = $GameplayRoot/Hero
@onready var _camera: Camera2D = $GameplayRoot/Camera2D
@onready var _camera_3d: Camera3D = $GameplayRoot/Camera3D
@onready var _monsters_container: Node2D = $GameplayRoot/MonstersContainer
## Real gap found during /code-review (2026-08-13, closing Epic 10's own
## deferred gate): these two were re-resolved via $GameplayRoot/... on
## every call instead of cached here like every other node reference in
## this file -- a real regression against this file's own established
## convention and the_gap.gd's own precedent (both specialist passes
## independently flagged this).
@onready var _tower_system: TowerSystem = $GameplayRoot/TowerSystem
@onready var _monster_manager: MonsterManager = $GameplayRoot/MonsterManager

## Tower Build Panel's own pending selection (Mission HUD's Planning Cluster,
## added 2026-08-10) — empty string means nothing selected, matching
## set_boss_telegraph_cell's identical sentinel convention for "nothing to
## show." A left-click on the grid with no selection is a no-op; this
## replaces the previous hardcoded `place_tower(&"archer", cell)` debug
## behavior every click used to trigger regardless of intent.
var _selected_blueprint_id: StringName = &""

## Real gap found and fixed 2026-08-11: unlike the_gap.gd (which has had a
## tower-placed visual since design/quick-specs/combat-tower-placeholder-
## visual-layer-2026-07-31.md), this scene never subscribed to tower_placed/
## tower_removed/tower_destroyed at all — a tower placed via the real
## Mission-Select-routed flow was completely invisible, not even a
## placeholder rect. Wired directly to real per-archetype art
## (tower_instance.gd) rather than reintroducing the ColorRect step the_gap.gd
## has already moved past.
var _tower_visuals: Dictionary = {}  # tower_id(int) -> TowerInstance


func _ready() -> void:
	# Epic 15 Story 003 (ADR-0037): Godot auto-promotes a lone Camera3D to
	# current=true on _enter_tree(), overriding the .tscn's stored
	# current=false — confirmed live via Godot MCP. Re-asserting here is what
	# actually keeps Camera2D the active view during this phased migration;
	# see the_gap.gd's _ready() for the identical fix and full rationale.
	# Cached as _camera_3d (not a bare $-lookup) matching this file's own
	# established node-reference convention — see the code-review note on
	# the @onready block above (a real regression this file was fixed for
	# once already, during Epic 10).
	_camera_3d.current = false
	_gameplay_root.visible = false
	_gameplay_root.set_process(false)
	_gameplay_root.set_physics_process(false)

	GEventBus.grid_initialized.connect(_on_grid_initialized)
	GEventBus.mission_launched.connect(_on_mission_launched)
	GEventBus.monster_spawned.connect(_on_monster_spawned)
	GEventBus.tower_blueprint_selected.connect(_on_tower_blueprint_selected)
	GEventBus.tower_placed.connect(_on_tower_placed)
	GEventBus.tower_removed.connect(_on_tower_removed)
	GEventBus.tower_destroyed.connect(_on_tower_destroyed)
	GEventBus.tower_attacked.connect(_on_tower_attacked)
	GEventBus.tower_damaged.connect(_on_tower_damaged)
	GEventBus.tower_aura_pulse.connect(_on_tower_aura_pulse)
	GEventBus.pre_placement_perk_activated.connect(_on_pre_placement_perk_activated)
	GEventBus.monster_died.connect(_on_monster_died)
	GEventBus.monsters_died_batch.connect(_on_monsters_died_batch)


func _exit_tree() -> void:
	GEventBus.grid_initialized.disconnect(_on_grid_initialized)
	GEventBus.mission_launched.disconnect(_on_mission_launched)
	GEventBus.monster_spawned.disconnect(_on_monster_spawned)
	GEventBus.tower_blueprint_selected.disconnect(_on_tower_blueprint_selected)
	GEventBus.tower_placed.disconnect(_on_tower_placed)
	GEventBus.tower_removed.disconnect(_on_tower_removed)
	GEventBus.tower_destroyed.disconnect(_on_tower_destroyed)
	GEventBus.tower_attacked.disconnect(_on_tower_attacked)
	GEventBus.tower_damaged.disconnect(_on_tower_damaged)
	GEventBus.tower_aura_pulse.disconnect(_on_tower_aura_pulse)
	GEventBus.pre_placement_perk_activated.disconnect(_on_pre_placement_perk_activated)
	GEventBus.monster_died.disconnect(_on_monster_died)
	GEventBus.monsters_died_batch.disconnect(_on_monsters_died_batch)


## Real bug fix, 2026-08-09 — see grid_initialized's own doc comment
## (event_bus.gd) for the full ordering race this closes: camera position/
## zoom and GridVisual.configure() used to run inside _on_mission_launched
## below, but mission_launched's subscriber order always ran WaveManager's
## synchronous templates_ready -> route-render cascade BEFORE this scene's
## own handler, so every Planning Cluster screen-space overlay (route line,
## blocked-cell markers, boss-lane telegraph) computed its position against
## a camera still at its Node defaults. grid_initialized fires before
## mission_launched at every call site, closing the gap structurally.
func _on_grid_initialized(cols: int, rows: int, cell_size: float) -> void:
	if _grid_visual.has_method(&"configure"):
		var cells: Dictionary = {}
		for row: int in range(rows):
			for col: int in range(cols):
				var cell := Vector2i(col, row)
				cells[cell] = GGrid.get_cell_type(cell)
		# Per-mission terrain/prop flavour (2026-08-15): _current_mission_id
		# is already set by the time GGrid.initialize() (and therefore this
		# handler) runs -- confirm_launch()/retry_current_mission() both set
		# it before calling GGrid.initialize(), which is what synchronously
		# fires grid_initialized. Direct Autoload call, matches this file's
		# own established ADR-0020 Criterion A/B precedent elsewhere.
		_grid_visual.call(&"configure", cols, rows, cell_size, cells, GMissionSelect.get_current_mission_id())
	else:
		push_error("[MissionScene] GridVisual node has no configure() method — grid will not render.")

	_camera.position = Vector2(cols * cell_size / 2.0, rows * cell_size / 2.0)
	_camera.zoom = Vector2(0.85, 0.85)


## Swaps from the Mission Select screen to the live gameplay assembly.
## Grid/camera/GridVisual are already set up by _on_grid_initialized() above
## by the time this fires — this handler only reveals the gameplay subtree
## and positions the Hero, mirroring the_gap.gd's own _ready() assembly.
func _on_mission_launched(_mission_id: String, _modifiers: PackedStringArray, _difficulty_tier: int) -> void:
	if _mission_select_screen.has_method(&"disconnect_own_subscriptions"):
		_mission_select_screen.disconnect_own_subscriptions()
	_mission_select_screen.visible = false
	_mission_select_screen.set_process_unhandled_input(false)

	_gameplay_root.visible = true
	_gameplay_root.set_process(true)
	_gameplay_root.set_physics_process(true)

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


## Mirrors the_gap.gd's own identical visual-grouping handler. Player-
## reported 2026-08-16: the flat-colored placeholder ColorRect this handler
## used to attach here was drawn on top of the real, already-wired
## MonsterInstance sprite (MonsterManager._spawn_entity() instances it and
## calls configure() for every spawn, monster_manager.gd:485-487) — the
## player was seeing that opaque square, not a real hitbox (this project has
## no collision-shape debug rendering anywhere). Removed; MonsterManager's
## own presentation layer is the sole visual now.
func _on_monster_spawned(payload: MonsterSpawnedEvent) -> void:
	var entity: MonsterEntity = _monster_manager._entity_lookup.get(payload.entity_id) as MonsterEntity
	if entity == null:
		return
	entity.reparent(_monsters_container)


## GGrid.cell_to_world() returns a cell's CENTER — TowerInstance is a Node2D
## whose Sprite2D is centered on it by construction, so this is the correct
## placement. Footprint >1 (no current blueprint uses one) centers on the
## whole footprint, not just its top-left cell — mirrors the_gap.gd's
## identical handler.
func _on_tower_placed(payload: TowerPlacedEvent) -> void:
	var vis: TowerInstance = TowerInstanceScene.instantiate()
	_gameplay_root.add_child(vis)
	vis.position = GGrid.cell_to_world(payload.grid_position) + Vector2(payload.footprint - Vector2i.ONE) * CELL_SIZE * 0.5
	# state.weapon is already populated in _tower_system.placed_towers by the
	# time tower_placed fires (TowerSystem sets it before emitting) -- same
	# access pattern already used by _on_tower_attacked. Looked up BEFORE
	# configure() (2026-08-17 fix) so the real element can be passed in --
	# see TowerInstance.ELEMENT_TEXTURES's own doc comment for the bug this
	# closes (every elemental tower silently rendered as ice art).
	var state: TowerMissionState = _tower_system.placed_towers.get(payload.tower_id) as TowerMissionState
	var element: String = state.weapon.element if state != null else ""
	vis.configure(payload.archetype, element)
	if state != null:
		vis.element = state.weapon.element
		vis.set_idle_ambient(state.weapon.element)
	_tower_visuals[payload.tower_id] = vis
	_spawn_placement_confirm_ripple(vis.position, payload.footprint)


## design/gdd/tower.md "Placement Confirmed" Visual/Audio Requirements: "Ghost
## solidifies to full opacity with a brief outward scale ripple on footprint
## cells (~0.3s). Tower immediately enters IDLE appearance." The IDLE
## appearance half is already satisfied by `vis` itself appearing
## immediately above — this only adds the ripple. Reuses AoeRingVisual (the
## same "expanding ring" shape as the AoE detonation/aura pulse VFX) at a
## shorter, configurable duration rather than building a distinct node.
func _spawn_placement_confirm_ripple(world_position: Vector2, footprint: Vector2i) -> void:
	var ripple: Node2D = AoeRingVisualScene.instantiate()
	_gameplay_root.add_child(ripple)
	ripple.global_position = world_position
	var radius: float = maxf(footprint.x, footprint.y) * CELL_SIZE * 0.6
	ripple.configure(radius, PLACEMENT_CONFIRM_COLOR, "", PLACEMENT_CONFIRM_DURATION)


## design/gdd/tower.md "Tower Voluntarily Removed": calm dissolve, no debris,
## no flash — TowerInstance animates and frees itself; see
## play_remove_animation()'s own doc comment.
func _on_tower_removed(tower_id: int, _grid_position: Vector2i, _archetype: String, _constellation_eligibility_tag: String) -> void:
	var vis: TowerInstance = _tower_visuals.get(tower_id) as TowerInstance
	if vis == null:
		return
	_tower_visuals.erase(tower_id)
	vis.play_remove_animation()


## design/gdd/tower.md "Tower DESTROYED (Terminal)": the sudden/violent
## counterpart to voluntary removal — red flash then an archetype-appropriate
## particle burst (TowerDestroyVFX). The TowerInstance itself is freed
## immediately (no lingering wreckage on the grid — GDD step 3, "no visual
## remnant on cells") and the VFX node spawns in its place. footprint size is
## approximated at one cell (CELL_SIZE) — no current blueprint uses a
## footprint larger than 1x1 (see tower_placed's own precedent for this
## simplification), and the destroyed-event payload carries occupied cells,
## not a footprint size, so there is nothing more precise to read here anyway.
func _on_tower_destroyed(tower_id: int, _grid_position: Vector2i, archetype: String,
		_footprint: Array, _constellation_eligibility_tag: String) -> void:
	var vis: TowerInstance = _tower_visuals.get(tower_id) as TowerInstance
	if vis == null:
		return
	_tower_visuals.erase(tower_id)
	var vfx: Node2D = TowerDestroyVFXScene.instantiate()
	_gameplay_root.add_child(vfx)
	vfx.global_position = vis.global_position
	vfx.configure(archetype, vis.element, Vector2(CELL_SIZE, CELL_SIZE))
	vis.queue_free()


## Visual-only first pass (design/gdd/tower.md "Projectile Types"): spawns a
## purely cosmetic flight-path visual, colored/shaped by the firing tower's
## archetype and WeaponComponent.projectile_type. Does not gate or delay
## damage — damage_status.gd's existing one-frame resolution is unchanged.
## Support archetype towers never fire a projectile (Rule 5a — they emit
## tower_aura_pulse instead), so are skipped here. BALLISTIC weapons with a
## nonzero aoe_radius_cells also get a ground-plane detonation ring on
## arrival ("AoE Detonation" section) — ProjectileVisual spawns that itself
## once the flight completes.
## armor_penetration/is_crit (Tower Stats System Phase 1, 2026-08-16):
## not yet consumed here — accepted only because GDScript requires exact
## signal arity match. A crit-hit visual hook is a plausible future use of
## is_crit but is not required for Phase 1 correctness.
func _on_tower_attacked(tower_id: int, target_monster_id: int, _damage_amount: float,
		_is_siege: bool, is_armored: bool, _effect_type: String, _effect_value: float,
		_effect_duration: float, _armor_penetration: float, _is_crit: bool) -> void:
	var tower_vis: TowerInstance = _tower_visuals.get(tower_id) as TowerInstance
	if tower_vis == null:
		return
	var state: TowerMissionState = _tower_system.placed_towers.get(tower_id) as TowerMissionState
	if state == null or state.foundation.archetype == "support":
		return
	var target: MonsterEntity = _monster_manager._entity_lookup.get(target_monster_id) as MonsterEntity
	if target == null:
		return
	var projectile: ProjectileVisual = ProjectileVisualScene.instantiate()
	_gameplay_root.add_child(projectile)
	var aoe_radius_world: float = state.weapon.aoe_radius_cells * CELL_SIZE
	projectile.configure(state.foundation.archetype, state.weapon.projectile_type,
			tower_vis.global_position, target, aoe_radius_world, state.weapon.element, is_armored)

	# design/gdd/tower.md "Tower TARGETING/ATTACKING States" — both fire from
	# this same event; see TowerInstance's own TARGETING consts for why they
	# can't be triggered any earlier in this codebase's actual state machine.
	var tower_color: Color = _resolve_tower_color(state.foundation.archetype, state.weapon.element)
	tower_vis.play_targeting_orientation(target.global_position, tower_color, 1.0 / state.weapon.attack_speed)
	tower_vis.play_attack_punch(tower_color)


## Art & Animation Pipeline Upgrade, vertical slice (2026-08-17) — real gap
## found during the audit: this scene never subscribed to tower_damaged at
## all (only mission_hud.gd's HP-bar text reacted to it), so a tower being
## hit by a monster had zero sprite-level feedback. See TowerInstance.
## play_hit_flash()'s own doc comment for why this is a separate shader-
## driven channel from play_attack_punch()'s modulate/scale flash.
func _on_tower_damaged(tower_id: int, _damage_dealt: float, _current_hp: float, _max_hp: float) -> void:
	var tower_vis: TowerInstance = _tower_visuals.get(tower_id) as TowerInstance
	if tower_vis == null:
		return
	tower_vis.play_hit_flash()


## Shared color resolution for tower-owned VFX (TARGETING glow, ATTACKING
## punch) — matches ProjectileVisual's own ARCHETYPE_COLORS/ELEMENT_COLORS
## exactly (referenced directly, not duplicated) so a tower's own visual
## reaction to firing always matches the color of what it just fired.
func _resolve_tower_color(archetype: String, element: String) -> Color:
	if archetype == "elemental" and ProjectileVisual.ELEMENT_COLORS.has(element):
		return ProjectileVisual.ELEMENT_COLORS[element]
	return ProjectileVisual.ARCHETYPE_COLORS.get(archetype, Color.WHITE)


## design/gdd/tower.md "Support aura visibility requirements": "Per-pulse VFX
## (required): On each tower_aura_pulse emission, the Mission HUD must
## trigger a brief visual pulse effect (expanding ring, burst, or glow) at
## the Support tower's grid position. This VFX is the player's only
## confirmation that the aura is firing during WAVE_ACTIVE. Without it, the
## player cannot know whether the Support tower is contributing." Was
## entirely unimplemented before this pass — reuses AoeRingVisual (an
## expanding-then-fading ring is one of the GDD's own 3 sanctioned options)
## rather than building a distinct effect from scratch.
func _on_tower_aura_pulse(payload: TowerAuraPulseEvent) -> void:
	var tower_vis: TowerInstance = _tower_visuals.get(payload.tower_id) as TowerInstance
	if tower_vis == null:
		return
	var ring: Node2D = AoeRingVisualScene.instantiate()
	_gameplay_root.add_child(ring)
	ring.global_position = tower_vis.global_position
	ring.configure(payload.aura_radius_cells * CELL_SIZE, SUPPORT_AURA_COLOR)


## design/gdd/tower.md "Pre-Placement Perk Indicator" — see
## TowerInstance.set_perk_badge()'s own doc comment for why no "forfeit"
## path is needed here: a voluntarily-removed tower's TowerInstance is freed
## entirely, and TowerSystem's own fix (2026-08-13, found while implementing
## this) already guarantees this event never fires for an Intermission
## placement or a tower with no perk configured.
func _on_pre_placement_perk_activated(tower_id: int, _perk_type: String) -> void:
	var tower_vis: TowerInstance = _tower_visuals.get(tower_id) as TowerInstance
	if tower_vis == null:
		return
	tower_vis.set_perk_badge(true)


## design/gdd/monster.md "Death VFX — death_vfx_scene Specification":
## "Death VFX is NOT instantiated on breach." monster_died/monsters_died_batch
## only fire for real kills — a breach frees the entity via a completely
## separate path (monster_breached, MonsterManager's Pass 3) that this scene
## never subscribes to, so that exclusion is already structurally satisfied
## without any extra check here.
func _on_monster_died(payload: MonsterDiedEvent) -> void:
	_spawn_monster_death_vfx(payload)


## ADR-0033: batches into one event when > DEATH_BATCH_THRESHOLD deaths
## land in a single frame. Same per-death VFX either way — this handler
## just unpacks the array.
func _on_monsters_died_batch(payloads: Array[MonsterDiedEvent]) -> void:
	for payload: MonsterDiedEvent in payloads:
		_spawn_monster_death_vfx(payload)


func _spawn_monster_death_vfx(payload: MonsterDiedEvent) -> void:
	var vfx: Node2D = MonsterDeathVFXScene.instantiate()
	_gameplay_root.add_child(vfx)
	vfx.global_position = payload.world_position
	vfx.configure(payload.monster_id, payload.tier)
	if payload.tier == 2:
		_shake_camera_for_boss_death()


func _shake_camera_for_boss_death() -> void:
	var shake_tween := create_tween()
	var step_duration: float = BOSS_DEATH_SHAKE_DURATION / float(BOSS_DEATH_SHAKE_STEPS)
	for i in range(BOSS_DEATH_SHAKE_STEPS):
		var jitter := Vector2(randf_range(-BOSS_DEATH_SHAKE_MAGNITUDE, BOSS_DEATH_SHAKE_MAGNITUDE),
				randf_range(-BOSS_DEATH_SHAKE_MAGNITUDE, BOSS_DEATH_SHAKE_MAGNITUDE))
		shake_tween.tween_property(_camera, "offset", jitter, step_duration)
	shake_tween.tween_property(_camera, "offset", Vector2.ZERO, step_duration)


func _on_tower_blueprint_selected(blueprint_id: StringName) -> void:
	_selected_blueprint_id = blueprint_id
	# UX spec (design/ux/mission-hud.md line 267): "placement cursor
	# activates" the instant an entry is selected — not deferred until the
	# next mouse-motion event.
	_update_placement_preview()


func _unhandled_input(event: InputEvent) -> void:
	if not _gameplay_root.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _selected_blueprint_id == &"":
			return
		var cell: Vector2i = GGrid.world_to_cell(get_global_mouse_position())
		_attempt_placement_at(cell)
	elif event is InputEventMouseMotion:
		_update_placement_preview()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		GEventBus.player_ready.emit()


## Attempts to place the currently-selected blueprint at `cell`. Split out
## from _unhandled_input so tests can exercise the placement-then-cleanup
## logic without simulating mouse position (see mission_scene_test.gd's
## test_successful_placement_clears_selection_and_returns_to_free_cursor).
func _attempt_placement_at(cell: Vector2i) -> bool:
	var blueprint_id: StringName = _selected_blueprint_id
	var placed: bool = _tower_system.place_tower(blueprint_id, cell)
	if placed:
		# design/ux/interaction-patterns.md line 61: "Confirm action ...
		# returns cursor to free-cursor mode." Without this, the stale
		# selection kept showing the invalid-placement (red) cursor over
		# the tower just placed the next time the mouse crossed its cell.
		_selected_blueprint_id = &""
		_update_placement_preview()
	else:
		_spawn_placement_reject_flash(cell, blueprint_id)
	return placed


## design/gdd/tower.md "Placement Rejected" Visual/Audio Requirements:
## "Footprint cells flash red (2–3 rapid pulses, ~0.4s), then return to
## normal grid state." Fires for every rejection gate (phase/resource/
## footprint/path) uniformly — place_tower() collapses all 4 into a single
## bool, so this can't (and per the GDD doesn't need to) distinguish why.
func _spawn_placement_reject_flash(cell: Vector2i, blueprint_id: StringName) -> void:
	var blueprints: Dictionary = GGameDataRegistry.get_all_tower_blueprints()
	var data: TowerBlueprintData = blueprints.get(blueprint_id) as TowerBlueprintData
	if data == null:
		return
	var footprint: Vector2i = data.foundation.footprint
	var flash: Node2D = PlacementRejectFlashScene.instantiate()
	_gameplay_root.add_child(flash)
	flash.global_position = GGrid.cell_to_world(cell) + Vector2(footprint - Vector2i.ONE) * CELL_SIZE * 0.5
	flash.configure(Vector2(footprint) * CELL_SIZE)


## Grid Placement Cursor (design/ux/interaction-patterns.md) — this scene
## owns the real TowerSystem reference, so it computes the hover preview and
## forwards the result via EventBus rather than Mission HUD holding a direct
## TowerSystem reference of its own (see tower_placement_preview_updated's
## own doc comment in event_bus.gd for the full rationale).
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
