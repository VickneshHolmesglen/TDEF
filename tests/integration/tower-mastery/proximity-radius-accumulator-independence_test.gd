## Integration tests for Story 007 (TR-towermast-001, ADR-0029): shared
## proximity radius constant + fully independent Hero/Tower-Mastery
## accumulators.
##
## Scope note: this story is deliberately narrow (radius/independence
## contract only) — build_signature derivation (Story 008) and the
## cell-boundary-triggered recompute wiring to tower lifecycle events
## (Story 009) are both Blocked on a genuine Tower System data-model gap
## (see story-008's own Blocked-reason note). _active_signature_by_tower
## is therefore set directly here rather than derived from a real
## tower_placed payload — matching this project's established convention
## of test-injecting an internal seam for a not-yet-wired-up piece.
##
## TowerMastery/Hero are instantiated with add_child() so their real
## EventBus subscriptions are live (both react to hero_position_changed
## and mission_phase_changed) — matching hero_class_proximity_test.gd's own
## integration-test convention (real Hero, real signal wiring) rather than
## Crafting's direct-method-call convention, since this story specifically
## needs to prove BOTH systems react to the SAME live signal independently.
extends GdUnitTestSuite

var _hero: Hero
var _tower_mastery: TowerMastery
var _grid: GridSpyDouble


func before_test() -> void:
	_hero = Hero.new()
	add_child(_hero)
	_hero._base_stats[&"tower_affinity"] = 1.0

	_tower_mastery = TowerMastery.new()
	_grid = GridSpyDouble.new()
	add_child(_tower_mastery)
	_tower_mastery._grid = _grid


func after_test() -> void:
	if _tower_mastery != null and is_instance_valid(_tower_mastery):
		if _tower_mastery.is_inside_tree():
			_tower_mastery.get_parent().remove_child(_tower_mastery)
		_tower_mastery.free()
	_tower_mastery = null
	_grid = null
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null


# ---------------------------------------------------------------------------
# AC-01: single-source shared radius constant
# ---------------------------------------------------------------------------

func test_shared_radius_constant_is_the_same_source_as_hero() -> void:
	assert_int(TowerMastery.TOWER_MASTERY_PROXIMITY_RADIUS).is_equal(3)
	assert_int(TowerMastery.TOWER_MASTERY_PROXIMITY_RADIUS).is_equal(Hero.CLASS_PROXIMITY_RADIUS)


# ---------------------------------------------------------------------------
# AC-02: Chebyshev metric confirmed via a divergent boundary case
# ---------------------------------------------------------------------------

func test_chebyshev_metric_includes_a_cell_euclidean_would_exclude() -> void:
	# Hero at (5,5); tower at (8,8): Chebyshev = max(3,3) = 3 (in range),
	# Euclidean = sqrt(18) ≈ 4.24 (would be OUT of a Euclidean-radius-3 check).
	_grid.place(1, Vector2i(8, 8))
	_tower_mastery._active_signature_by_tower[1] = "sig_a"

	_tower_mastery._recompute_signatures_in_range(Vector2i(5, 5))

	assert_bool(_tower_mastery._signatures_in_range.get("sig_a", false)).is_true()


# ---------------------------------------------------------------------------
# AC-03: only get_occupied_cells_in_radius() + get_occupant() invoked
# ---------------------------------------------------------------------------

func test_recompute_never_calls_get_all_occupied_cells() -> void:
	_grid.place(1, Vector2i(5, 5))
	_tower_mastery._active_signature_by_tower[1] = "sig_a"

	_tower_mastery._recompute_signatures_in_range(Vector2i(5, 5))

	assert_int(_grid.get_all_occupied_cells_call_count).is_equal(0)


# ---------------------------------------------------------------------------
# AC-04/AC-05: independent dictionary entries, mutation-isolated
# ---------------------------------------------------------------------------

## Common arrange step for AC-04/05/06: a WAVE_ACTIVE hero standing within
## radius of one tower, both accumulators live. Hero's own _tower_cache is
## populated purely from the tower_placed payload (not from Grid), but
## Hero's _update_class_proximity() resolves the HERO's own cell via the
## real GGrid Autoload — hero.global_position must be set accordingly.
## TowerMastery's _recompute_signatures_in_range() resolves via the
## injected GridSpyDouble, which must independently know the tower occupies
## the same cell (a raw GEventBus.tower_placed.emit(TowerPlacedEvent.make()) does not write to any
## Grid — real TowerSystem.place_tower() would, but isn't used here).
func _arrange_shared_proximity_setup() -> void:
	_hero._on_mission_phase_changed("SCOUT", "WAVE_ACTIVE", 0.0)
	_hero.global_position = GGrid.cell_to_world(Vector2i(5, 6))
	GEventBus.tower_placed.emit(TowerPlacedEvent.make(1, Vector2i(6, 6), "BASIC", Vector2i.ONE, true, ""))

	_grid.place(1, Vector2i(6, 6))
	_tower_mastery._active_signature_by_tower[1] = "sig_a"
	_tower_mastery._on_mission_phase_changed("SCOUT", "WAVE_ACTIVE", 0.0)
	GEventBus.hero_position_changed.emit(Vector2i(5, 6))


func test_independent_accumulators_both_reach_15_seconds() -> void:
	_arrange_shared_proximity_setup()

	_hero._physics_process(15.0)
	_tower_mastery.tick(15.0)

	assert_float(_hero._proximity_time.get(&"BASIC", 0.0)).is_equal_approx(15.0, 0.0001)
	assert_float(_tower_mastery.mastery_time.get("sig_a", 0.0)).is_equal_approx(15.0, 0.0001)


func test_mutating_tower_mastery_accumulator_leaves_hero_unaffected() -> void:
	_arrange_shared_proximity_setup()
	_hero._physics_process(10.0)
	_tower_mastery.tick(10.0)

	_tower_mastery.mastery_time["sig_a"] = 999.0

	assert_float(_hero._proximity_time.get(&"BASIC", 0.0)).is_equal_approx(10.0, 0.0001)


func test_mutating_hero_accumulator_leaves_tower_mastery_unaffected() -> void:
	_arrange_shared_proximity_setup()
	_hero._physics_process(10.0)
	_tower_mastery.tick(10.0)

	_hero._proximity_time[&"BASIC"] = 999.0

	assert_float(_tower_mastery.mastery_time.get("sig_a", 0.0)).is_equal_approx(10.0, 0.0001)


# ---------------------------------------------------------------------------
# AC-06: independently-tracked thresholds — Hero's 30s crossing must not
# also fire Tower Mastery's 45s-threshold skill_unlocked.
# ---------------------------------------------------------------------------

func test_hero_threshold_crossing_does_not_also_cross_tower_mastery_threshold() -> void:
	_arrange_shared_proximity_setup()

	var spy := EventBusSpy.new()
	spy.watch(GEventBus.hero_class_unlocked)
	spy.watch(GEventBus.skill_unlocked)

	# 30s crosses Hero's threshold but stays well under Tower Mastery's 45s default.
	_hero._physics_process(30.0)
	_tower_mastery.tick(30.0)
	await get_tree().process_frame  # flush hero_class_unlocked's deferred emit (ADR-0001 Rule 2)

	assert_int(spy.count("hero_class_unlocked")).is_equal(1)
	assert_int(spy.count("skill_unlocked")).is_equal(0)

	spy.disconnect_all()
