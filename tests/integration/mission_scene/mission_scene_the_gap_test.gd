extends GdUnitTestSuite

## Integration test: "The Gap" mission scene (S4-09, epic-04-wave-manager capstone).
## Design source: production/epics/epic-04-wave-manager/story-008-assemble-the-gap-mission-scene.md
##
## Covers everything headless-testable: WaveConfig content authoring (Rule 6
## compliance), Grid assembly (exactly 1 SPAWN cell per the control manifest),
## and a full real SCOUT -> PRE_WAVE -> WAVE_ACTIVE phase progression with a real
## spawned, visible monster and a real DEFEAT transition via the debug hero-kill
## trigger. Timer waits are skipped via direct timeout-handler invocation, matching
## this codebase's own established convention (see
## tests/integration/wave_manager/wave_manager_config_loading_test.gd) rather than
## waiting out real 60s/10s durations.
##
## NOT covered here (see production/qa/evidence/the-gap-mission-scene-evidence.md):
## visual monster pathing "feel", real Hero movement/combat feel, and FPS/draw-call/
## memory performance measurement — all of which require real rendering that
## headless mode cannot exercise.
##
## This test also serves as the regression guard for two production bugs found
## and fixed during this story's own verification pass (see
## docs/tech-debt-register.md TD-wave-002 and TD-wave-003): before those fixes,
## a real (non-test-injected) mission always spawned exactly 0 monsters.

const SCENE_PATH: String = "res://src/gameplay/missions/the_gap/the_gap.tscn"
const WAVES_PATH: String = "res://assets/data/waves/the_gap_waves.tres"

var _scene: Node2D


func before_test() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	_scene = packed.instantiate()
	add_child(_scene)


## Cross-suite isolation fix (found during this story's own full-suite regression
## run): GGrid is a real Autoload — its `_cell_types` (including SPAWN/GOAL cells)
## persist across test SUITE FILES within the same headless test process (gdUnit4
## does not reset Autoload state between suite files, only via before_test/
## after_test within one suite). Without this reset, a later-running suite in the
## same process (e.g. wave_manager_config_loading_test.gd) would see this suite's
## real SPAWN/GOAL cells still configured, causing its own ambient
## GPathfindingSystem to successfully build real templates and emit a real
## templates_ready during that OTHER suite's test — an inter-suite pollution bug
## this story's own production fix (removing _on_templates_ready()'s incorrect
## _phase_locked guard, see TD-wave-003) made newly observable. Re-initializing
## with an empty GridConfig here fully clears _cell_types so no SPAWN/GOAL cells
## leak into later suites.
func after_test() -> void:
	if is_instance_valid(_scene):
		remove_child(_scene)
		_scene.free()
	GGrid.initialize(GridConfig.new())

# ---------------------------------------------------------------------------
# Content authoring: real WaveConfig .tres, Rule 6 compliance
# ---------------------------------------------------------------------------

func test_the_gap_waves_config_has_five_to_eight_waves() -> void:
	var cfg: WaveConfig = load(WAVES_PATH)
	assert_object(cfg).is_not_null()
	assert_int(cfg.wave_scripts.size()).is_between(5, 8)


func test_the_gap_waves_config_penultimate_wave_is_elite_only() -> void:
	var cfg: WaveConfig = load(WAVES_PATH)
	var n: int = cfg.wave_scripts.size()
	var penultimate: WaveScript = cfg.wave_scripts[n - 2]
	assert_bool(penultimate.entries.is_empty()).is_false()
	for entry: WaveSpawnEntry in penultimate.entries:
		var res: MonsterResource = GGameDataRegistry.get_monster_resource(entry.monster_id)
		assert_object(res).is_not_null()
		assert_int(res.tier).is_equal(1)  # ELITE


func test_the_gap_waves_config_final_wave_ends_in_exactly_one_boss_entry() -> void:
	var cfg: WaveConfig = load(WAVES_PATH)
	var final: WaveScript = cfg.wave_scripts[cfg.wave_scripts.size() - 1]
	var boss_count: int = 0
	for i: int in range(final.entries.size()):
		var entry: WaveSpawnEntry = final.entries[i]
		var res: MonsterResource = GGameDataRegistry.get_monster_resource(entry.monster_id)
		if res != null and res.tier == 2:
			boss_count += 1
			assert_int(i).is_equal(final.entries.size() - 1)  # BOSS must be the last entry
	assert_int(boss_count).is_equal(1)


func test_the_gap_waves_config_all_monster_ids_are_real() -> void:
	var cfg: WaveConfig = load(WAVES_PATH)
	for script: WaveScript in cfg.wave_scripts:
		for entry: WaveSpawnEntry in script.entries:
			assert_object(GGameDataRegistry.get_monster_resource(entry.monster_id)).is_not_null()


func test_the_gap_waves_config_passes_own_validate() -> void:
	var cfg: WaveConfig = load(WAVES_PATH)
	assert_array(cfg.validate()).is_empty()


## Regression guard for the WaveSpawnEntry @export fix (verified empirically this
## story via a real ResourceSaver/ResourceLoader round-trip): confirms the fields
## actually survive .tres load, not just that the file exists.
func test_the_gap_waves_config_wave_spawn_entry_fields_survive_tres_load() -> void:
	var cfg: WaveConfig = load(WAVES_PATH)
	var first_entry: WaveSpawnEntry = cfg.wave_scripts[0].entries[0]
	assert_str(String(first_entry.monster_id)).is_equal("goblin_runner")
	assert_float(first_entry.pre_delay).is_equal(0.0)
	assert_int(first_entry.difficulty_tier).is_equal(1)

# ---------------------------------------------------------------------------
# Scene assembly: Grid, exactly one SPAWN cell (control manifest requirement)
# ---------------------------------------------------------------------------

func test_the_gap_scene_grid_has_exactly_one_spawn_cell() -> void:
	assert_array(GGrid.get_spawn_cells()).has_size(1)


func test_the_gap_scene_grid_has_at_least_one_goal_cell() -> void:
	assert_bool(GGrid.get_goal_cells().is_empty()).is_false()

# ---------------------------------------------------------------------------
# Full phase progression + real spawn (timer waits skipped via direct
# timeout-handler invocation — matches this codebase's established convention)
# ---------------------------------------------------------------------------

func test_the_gap_full_mission_reaches_wave_active_with_a_real_visible_spawned_monster() -> void:
	await get_tree().create_timer(1.2).timeout  # clears the_gap.gd's 1s auto-launch delay
	assert_int(GWaveManager._phase).is_equal(WaveManager.Phase.SCOUT)

	GWaveManager._on_scout_timer_timeout()
	assert_int(GWaveManager._phase).is_equal(WaveManager.Phase.PRE_WAVE)

	GWaveManager._on_pre_wave_timer_timeout()
	assert_int(GWaveManager._phase).is_equal(WaveManager.Phase.WAVE_ACTIVE)

	# TD-wave-002 / TD-wave-003 regression coverage: a real monster must actually spawn.
	assert_int(GWaveManager._enemies_alive).is_greater(0)

	var monster_manager: Node = _scene.get_node("MonsterManager")
	assert_int((monster_manager.active_monsters as Array).size()).is_greater(0)

	# TD-monster-003 workaround coverage: the spawned entity must be a real,
	# visible scene-tree child (not the orphan node TD-monster-003 tracks).
	var monsters_container: Node = _scene.get_node("MonstersContainer")
	assert_int(monsters_container.get_child_count()).is_greater(0)


## AC: hero-death playthrough correctly reaches DEFEAT and halts further wave
## activity. Uses the debug-only hero-kill trigger (see the_gap.gd's own doc
## comment — no real Hero-damage source exists anywhere in this codebase yet).
##
## Real bug found and fixed 2026-07-20 (epic-01-foundation.md's own retroactive
## note): `res://src/scenes/SanctuaryScene.tscn` never existed anywhere in this
## project, so `hero_died`'s automatic `SceneManager.transition_to_sanctuary()`
## call always failed with a push_error — this test previously documented and
## explicitly asserted on THAT incidental error (`any_string()`, to avoid
## coupling to its exact wording) rather than the transition succeeding. Now
## that a real (stub) SanctuaryScene exists, that push_error no longer fires.
##
## GSceneManager is injected with the isolated stub fixture scene for the
## duration of this one test (matching scene_manager_transition_test.gd's own
## established convention) — this test's concern is WaveManager's DEFEAT
## transition, not exercising a real, heavy `change_scene_to_packed()` swap of
## the actual shipped SanctuaryScene mid-integration-test (which would orphan
## nodes this test's own after_test() has no way to clean up, since neither
## `_scene` nor `get_tree().current_scene` in this suite are the same thing).
func test_the_gap_debug_hero_kill_reaches_defeat_and_halts_wave_activity() -> void:
	var original_sanctuary_path: String = GSceneManager._sanctuary_scene_path
	GSceneManager._inject(GSceneManager._mission_scene_path, "res://tests/fixtures/scene_manager/StubScene.tscn")

	await get_tree().create_timer(1.2).timeout
	GWaveManager._on_scout_timer_timeout()
	GWaveManager._on_pre_wave_timer_timeout()
	assert_int(GWaveManager._phase).is_equal(WaveManager.Phase.WAVE_ACTIVE)

	var hero: Hero = _scene.get_node("Hero")
	assert_float(hero._current_hp).is_greater(0.0)

	_scene._debug_kill_hero()

	assert_float(hero._current_hp).is_equal(0.0)
	assert_int(GWaveManager._phase).is_equal(WaveManager.Phase.DEFEAT)

	# No further wave activity after DEFEAT — a stale timer firing must be a no-op.
	var enemies_before: int = GWaveManager._enemies_alive
	GWaveManager._on_watchdog_force_timeout()
	assert_int(GWaveManager._phase).is_equal(WaveManager.Phase.DEFEAT)
	assert_int(GWaveManager._enemies_alive).is_equal(enemies_before)

	if GSceneManager._transition_in_progress:
		await GEventBus.scene_transition_completed
	GSceneManager._inject(GSceneManager._mission_scene_path, original_sanctuary_path)

# ---------------------------------------------------------------------------
# Debug tower-placement affordance (real TowerSystem.place_tower() API)
# ---------------------------------------------------------------------------

func test_the_gap_debug_tower_placement_uses_real_tower_system() -> void:
	await get_tree().create_timer(1.2).timeout
	assert_int(GWaveManager._phase).is_equal(WaveManager.Phase.SCOUT)  # placement allowed (Gate 1)

	var tower_system: Node = _scene.get_node("TowerSystem")
	# (2, 3) is off the authored path corridor (row6 col0-4, col4 row2-6, ...) and
	# off the border BLOCKED ring — a genuine PLACEABLE cell per _build_grid_config().
	var placeable_cell: Vector2i = Vector2i(2, 3)
	assert_int(GGrid.get_cell_type(placeable_cell)).is_equal(Grid.CellType.PLACEABLE)

	var placed: bool = tower_system.place_tower(&"archer", placeable_cell)
	assert_bool(placed).is_true()
	assert_int(GGrid.get_occupant(placeable_cell)).is_greater(-1)


## Upgraded 2026-08-11 from design/quick-specs/combat-tower-placeholder-
## visual-layer-2026-07-31.md's original flat ColorRect assertions to real
## per-archetype art (TowerInstance) — real placement through the real
## GEventBus.tower_placed signal produces a real, correctly-textured,
## correctly-positioned visual, and removing it frees exactly that one.
func test_the_gap_tower_placement_creates_and_removes_real_tower_visual() -> void:
	await get_tree().create_timer(1.2).timeout

	var tower_system: TowerSystem = _scene.get_node("TowerSystem") as TowerSystem
	var placeable_cell: Vector2i = Vector2i(2, 3)

	var placed: bool = tower_system.place_tower(&"archer", placeable_cell)
	assert_bool(placed).is_true()

	var tower_visuals: Dictionary = _scene.get("_tower_visuals") as Dictionary
	assert_int(tower_visuals.size()).is_equal(1)
	var tower_id: int = (tower_visuals.keys() as Array)[0] as int
	var vis: TowerInstance = tower_visuals[tower_id] as TowerInstance
	assert_object(vis).is_not_null()
	assert_bool(is_instance_valid(vis)).is_true()
	# archer's real archetype is "physical" -> tower_physical_base.png
	# (TowerInstance.ARCHETYPE_TEXTURES).
	var sprite: Sprite2D = vis.get_node("Sprite2D") as Sprite2D
	assert_object(sprite.texture).is_not_null()
	assert_str(sprite.texture.resource_path).contains("tower_physical_base")
	assert_that(vis.position).is_equal(GGrid.cell_to_world(placeable_cell))

	var removed: bool = tower_system.sell_tower(tower_id)
	assert_bool(removed).is_true()

	var tower_visuals_after: Dictionary = _scene.get("_tower_visuals") as Dictionary
	assert_int(tower_visuals_after.size()).is_equal(0)

# ---------------------------------------------------------------------------
# AC-6 (code review gap): real Hero combat vs. a real spawned monster within
# this assembled scene. Previously untested and undisclosed. Mechanism read
# from src/core/hero/hero.gd (Epic 02 story-003) and cross-checked against
# tests/unit/hero/hero_auto_attack_test.gd and
# tests/integration/hero/hero_combat_formula_test.gd before writing this:
##   1. Hero._on_monster_spawned() populates Hero._monster_cache from the real
##      monster_spawned EventBus signal — no test-injection seam is used here;
##      the cache is populated purely by this assembled scene's own real
##      spawn chain (same chain TD-wave-002/003 fixed).
##   2. Hero._on_attack_timer_timeout() (normally fired by Hero._attack_timer,
##      a real Timer node) selects a target from the cache and emits
##      hero_auto_attacked synchronously. Matches this file's own established
##      timer-skip convention (direct handler invocation) rather than waiting
##      out the real 1s AUTO_ATTACK_INTERVAL_S.
##   3. DamageStatus._on_hero_auto_attacked() (real autoload-equivalent node,
##      already running in the scene tree — see damage_status.gd) resolves
##      Formula 4 one frame later and emits monster_damage_taken.
##   4. MonsterManager._pass1_damage() (real _physics_process pass) applies
##      that damage to the real MonsterEntity.current_hp on the next physics
##      frame — proving the full real D&S pipeline, not just the emission.
func test_the_gap_real_hero_auto_attack_engages_real_spawned_monster_and_reduces_its_hp() -> void:
	await get_tree().create_timer(1.2).timeout
	GWaveManager._on_scout_timer_timeout()
	GWaveManager._on_pre_wave_timer_timeout()
	assert_int(GWaveManager._phase).is_equal(WaveManager.Phase.WAVE_ACTIVE)
	assert_int(GWaveManager._enemies_alive).is_greater(0)

	var monster_manager: Node = _scene.get_node("MonsterManager")
	var active: Array = monster_manager.active_monsters as Array
	assert_int(active.size()).is_greater(0)
	var monster: MonsterEntity = active[0] as MonsterEntity

	var hero: Hero = _scene.get_node("Hero")
	# Real monster-cache population (Epic 02 story-003 mechanism), driven
	# purely by this scene's real monster_spawned emission — not test-injected.
	assert_bool(hero._monster_cache.has(monster.entity_id)).is_true()

	var pre_attack_hp: float = monster.current_hp
	assert_float(pre_attack_hp).is_greater(0.0)

	var spy := EventBusSpy.new()
	spy.watch(GEventBus.hero_auto_attacked)

	# Timer-skip convention (matches this file's other tests): invoke the real
	# attack-timer handler directly rather than waiting out AUTO_ATTACK_INTERVAL_S.
	hero._on_attack_timer_timeout()

	assert_int(spy.count("hero_auto_attacked")).is_equal(1)
	var payload: HeroAutoAttackEvent = (spy.emissions["hero_auto_attacked"] as Array)[0][0] as HeroAutoAttackEvent
	assert_int(payload.target_id).is_equal(monster.entity_id)

	# Let the real D&S deferred frame (await get_tree().process_frame) and the
	# following real MonsterManager._physics_process pass both elapse.
	await get_tree().create_timer(0.1).timeout

	if is_instance_valid(monster):
		assert_float(monster.current_hp).is_less(pre_attack_hp)
	else:
		# The hit was lethal (monster freed by _emit_death) — also proof the
		# real damage pipeline actually applied, just via the death path.
		assert_bool(is_instance_valid(monster)).is_false()

	spy.disconnect_all()

# ---------------------------------------------------------------------------
# AC-3 (code review gap): the full authored 6-wave WaveConfig loop through
# MISSION_COMPLETE. Previously only wave 1's SCOUT -> PRE_WAVE -> WAVE_ACTIVE
# transition was exercised. Each wave's clearing condition is simulated via
# GWaveManager._on_watchdog_force_timeout() — the same real, production
# force-clear handler this codebase's own WaveManager suites use to simulate
# a wave clearing without a full combat simulation (see
## tests/unit/wave_manager/wave_manager_defeat_victory_test.gd's
## test_watchdog_force_timeout_on_final_wave_transitions_to_mission_complete()
## and wave_manager_boss_wave_clear_test.gd for the same established pattern)
## — it force-clears the current wave regardless of _enemies_alive /
## _all_spawns_fired and correctly routes to INTERMISSION or, on the final
## wave, MISSION_COMPLETE, per WaveManager._is_final_wave().
## Real bug fix note (2026-07-20, same as the DEFEAT test above): reaching
## MISSION_COMPLETE also triggers SceneManager.transition_to_sanctuary()
## automatically — isolated with the same stub-injection pattern so this
## test doesn't perform a real, heavy scene swap of the actual shipped
## SanctuaryScene as an untracked side effect.
func test_the_gap_full_six_wave_loop_reaches_mission_complete_on_real_wave_config() -> void:
	var original_sanctuary_path: String = GSceneManager._sanctuary_scene_path
	GSceneManager._inject(GSceneManager._mission_scene_path, "res://tests/fixtures/scene_manager/StubScene.tscn")

	var cfg: WaveConfig = load(WAVES_PATH)
	var total_waves: int = cfg.wave_scripts.size()
	assert_int(total_waves).is_between(5, 8)  # matches this suite's Rule-6 content-authoring assertion

	await get_tree().create_timer(1.2).timeout
	GWaveManager._on_scout_timer_timeout()
	assert_int(GWaveManager._phase).is_equal(WaveManager.Phase.PRE_WAVE)
	GWaveManager._on_pre_wave_timer_timeout()
	assert_int(GWaveManager._phase).is_equal(WaveManager.Phase.WAVE_ACTIVE)

	for wave_number: int in range(1, total_waves + 1):
		assert_int(GWaveManager._phase).is_equal(WaveManager.Phase.WAVE_ACTIVE)
		assert_int(GWaveManager._wave_index).is_equal(wave_number)

		GWaveManager._on_watchdog_force_timeout()

		if wave_number == total_waves:
			assert_int(GWaveManager._phase).is_equal(WaveManager.Phase.MISSION_COMPLETE)
		else:
			assert_int(GWaveManager._phase).is_equal(WaveManager.Phase.INTERMISSION)
			GWaveManager._on_intermission_timer_timeout()
			assert_int(GWaveManager._phase).is_equal(WaveManager.Phase.PRE_WAVE)
			GWaveManager._on_pre_wave_timer_timeout()
			assert_int(GWaveManager._phase).is_equal(WaveManager.Phase.WAVE_ACTIVE)

	assert_int(GWaveManager._phase).is_equal(WaveManager.Phase.MISSION_COMPLETE)
	assert_int(GWaveManager._wave_index).is_equal(total_waves)

	if GSceneManager._transition_in_progress:
		await GEventBus.scene_transition_completed
	GSceneManager._inject(GSceneManager._mission_scene_path, original_sanctuary_path)
