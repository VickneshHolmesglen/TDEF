extends GdUnitTestSuite

## Unit tests for Hero's Tower Affinity subsystem (story-005, ADR-0010 Formula 2).
##
## Governing ADR: docs/architecture/adr-0010-hero-tower-synced-class.md
## Story: production/epics/epic-02-core-combat/story-005-hero-tower-affinity.md
##
## Formula under test (get_effective_stat(&"tower_affinity")):
##   base_result = Formula 1 result for tower_affinity
##   qualifying  = _tower_cache.size() when _primary_class == &""
##                 else count of entries whose archetype == _primary_class
##   multiplier  = clampf(sqrt(qualifying / TOWERS_AFFINITY_REFERENCE), 0.0, TOWER_AFFINITY_BONUS_CAP)
##   result      = base_result * multiplier
##
## Deviation from the story's stale text (resolved with the designer before this test
## was written — see ADR-0010, the authoritative source):
##   - EC-2 in the story claims "no primary class -> 0 qualifying towers". This is
##     WRONG per ADR-0010's _recompute_tower_affinity(): no primary class means ALL
##     cached towers qualify (unfiltered), not zero. Tests below assert the ADR's
##     actual (correct) behavior, and separately test the true zero case (no primary
##     class AND an empty cache).
##   - EC-1 in the story claims the multiplier is "clamped to 1.0". The real ADR-0010
##     constant is TOWER_AFFINITY_BONUS_CAP = 2.0. Tests below assert the real 2.0 cap.
##
## Cache lifecycle (tower_placed / tower_removed / tower_destroyed) is driven directly
## via GEventBus signal emission and observed indirectly through the resulting
## get_effective_stat(&"tower_affinity") value, matching this project's plain-unit-test
## idiom (no EventBusSpy needed since assertions are on Hero's return value, not on
## emitted events).

var _hero: Hero


func before_test() -> void:
	_hero = Hero.new()
	add_child(_hero)
	_hero._base_stats[&"tower_affinity"] = 1.0


func after_test() -> void:
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null


# ---------------------------------------------------------------------------
# AC-07: Affinity formula with N qualifying towers (no primary class set, so
# all placed towers are unfiltered-qualifying)
# ---------------------------------------------------------------------------

func test_tower_affinity_four_qualifying_towers_yields_half_multiplier() -> void:
	for i in range(4):
		GEventBus.tower_placed.emit(TowerPlacedEvent.make(100 + i, Vector2i(i, 0), "BASIC", Vector2i.ONE, true, ""))
	# sqrt(4/16) = 0.5 -> 1.0 * 0.5 = 0.5
	assert_float(_hero.get_effective_stat(&"tower_affinity")).is_equal_approx(0.5, 0.0001)


func test_tower_affinity_one_qualifying_tower_yields_quarter_multiplier() -> void:
	GEventBus.tower_placed.emit(TowerPlacedEvent.make(200, Vector2i(0, 0), "BASIC", Vector2i.ONE, true, ""))
	# sqrt(1/16) = 0.25 -> 1.0 * 0.25 = 0.25
	assert_float(_hero.get_effective_stat(&"tower_affinity")).is_equal_approx(0.25, 0.0001)


func test_tower_affinity_nine_qualifying_towers_yields_075_multiplier() -> void:
	for i in range(9):
		GEventBus.tower_placed.emit(TowerPlacedEvent.make(300 + i, Vector2i(i, 0), "BASIC", Vector2i.ONE, true, ""))
	# sqrt(9/16) = 0.75 -> 1.0 * 0.75 = 0.75
	assert_float(_hero.get_effective_stat(&"tower_affinity")).is_equal_approx(0.75, 0.0001)


func test_tower_affinity_sixteen_qualifying_towers_yields_full_multiplier() -> void:
	for i in range(16):
		GEventBus.tower_placed.emit(TowerPlacedEvent.make(400 + i, Vector2i(i, 0), "BASIC", Vector2i.ONE, true, ""))
	# sqrt(16/16) = 1.0 -> 1.0 * 1.0 = 1.0
	assert_float(_hero.get_effective_stat(&"tower_affinity")).is_equal_approx(1.0, 0.0001)


## Regression guard: every other test in this suite seeds base=1.0, where
## multiplier == result — indistinguishable from a hypothetical regression that
## returns the bare multiplier and drops "base_result * bonus_multiplier" entirely
## (hero.gd _apply_tower_affinity_bonus()). A non-1.0 base closes that gap: only the
## real multiplication formula produces 1.0 here — a dropped multiplication would
## incorrectly read 0.5 (the bare multiplier).
func test_tower_affinity_non_unity_base_stat_multiplies_correctly() -> void:
	_hero._base_stats[&"tower_affinity"] = 2.0
	for i in range(4):
		GEventBus.tower_placed.emit(TowerPlacedEvent.make(1000 + i, Vector2i(i, 0), "BASIC", Vector2i.ONE, true, ""))
	# base=2.0, sqrt(4/16)=0.5 -> 2.0 * 0.5 = 1.0
	assert_float(_hero.get_effective_stat(&"tower_affinity")).is_equal_approx(1.0, 0.0001)


# ---------------------------------------------------------------------------
# AC-08: Primary class archetype filter
# ---------------------------------------------------------------------------

func test_tower_affinity_primary_class_filters_non_matching_archetypes() -> void:
	_hero._primary_class = &"FROST"
	GEventBus.tower_placed.emit(TowerPlacedEvent.make(500, Vector2i(0, 0), "FROST", Vector2i.ONE, true, ""))
	GEventBus.tower_placed.emit(TowerPlacedEvent.make(501, Vector2i(1, 0), "FROST", Vector2i.ONE, true, ""))
	GEventBus.tower_placed.emit(TowerPlacedEvent.make(502, Vector2i(2, 0), "FIRE", Vector2i.ONE, true, ""))
	GEventBus.tower_placed.emit(TowerPlacedEvent.make(503, Vector2i(3, 0), "FIRE", Vector2i.ONE, true, ""))
	GEventBus.tower_placed.emit(TowerPlacedEvent.make(504, Vector2i(4, 0), "FIRE", Vector2i.ONE, true, ""))
	GEventBus.tower_placed.emit(TowerPlacedEvent.make(505, Vector2i(5, 0), "BASIC", Vector2i.ONE, true, ""))
	# Only the 2 FROST towers qualify: sqrt(2/16) ≈ 0.35355
	var expected: float = sqrt(2.0 / 16.0)
	assert_float(_hero.get_effective_stat(&"tower_affinity")).is_equal_approx(expected, 0.0001)


func test_tower_affinity_moderate_overcount_not_clamped_below_cap() -> void:
	_hero._primary_class = &"FROST"
	for i in range(20):
		GEventBus.tower_placed.emit(TowerPlacedEvent.make(600 + i, Vector2i(i, 0), "FROST", Vector2i.ONE, true, ""))
	# sqrt(20/16) ≈ 1.118, well under the 2.0 cap — must NOT be clamped.
	var expected: float = sqrt(20.0 / 16.0)
	assert_float(expected).is_less(2.0)
	assert_float(_hero.get_effective_stat(&"tower_affinity")).is_equal_approx(expected, 0.0001)


# ---------------------------------------------------------------------------
# EC-1 (corrected): cap behavior at the real ADR-0010 cap of 2.0
# ---------------------------------------------------------------------------

func test_tower_affinity_large_qualifying_count_clamps_to_bonus_cap() -> void:
	_hero._primary_class = &"FROST"
	for i in range(100):
		GEventBus.tower_placed.emit(TowerPlacedEvent.make(700 + i, Vector2i(i % 20, i / 20), "FROST", Vector2i.ONE, true, ""))
	# sqrt(100/16) ≈ 2.5 -> clamped to exactly TOWER_AFFINITY_BONUS_CAP (2.0)
	assert_float(_hero.get_effective_stat(&"tower_affinity")).is_equal_approx(2.0, 0.0001)


# ---------------------------------------------------------------------------
# EC-2 (corrected per ADR-0010): no primary class means ALL towers qualify
# (unfiltered), not zero. True zero only occurs with an empty cache.
# ---------------------------------------------------------------------------

func test_tower_affinity_no_primary_class_counts_all_towers_unfiltered() -> void:
	# _primary_class left at its default (&"") — all 4 mixed-archetype towers
	# should count, per ADR-0010's _recompute_tower_affinity().
	GEventBus.tower_placed.emit(TowerPlacedEvent.make(800, Vector2i(0, 0), "FROST", Vector2i.ONE, true, ""))
	GEventBus.tower_placed.emit(TowerPlacedEvent.make(801, Vector2i(1, 0), "FIRE", Vector2i.ONE, true, ""))
	GEventBus.tower_placed.emit(TowerPlacedEvent.make(802, Vector2i(2, 0), "BASIC", Vector2i.ONE, true, ""))
	GEventBus.tower_placed.emit(TowerPlacedEvent.make(803, Vector2i(3, 0), "BASIC", Vector2i.ONE, true, ""))
	# sqrt(4/16) = 0.5
	assert_float(_hero.get_effective_stat(&"tower_affinity")).is_equal_approx(0.5, 0.0001)


func test_tower_affinity_no_primary_class_and_empty_cache_yields_zero() -> void:
	# No towers placed at all, no primary class set -> true zero case.
	assert_float(_hero.get_effective_stat(&"tower_affinity")).is_equal_approx(0.0, 0.0001)


# ---------------------------------------------------------------------------
# Cache lifecycle: tower_placed adds, tower_removed / tower_destroyed erase.
# Verified indirectly through the resulting affinity formula output.
# ---------------------------------------------------------------------------

func test_tower_placed_event_adds_cache_entry_reflected_in_affinity() -> void:
	assert_float(_hero.get_effective_stat(&"tower_affinity")).is_equal_approx(0.0, 0.0001)

	GEventBus.tower_placed.emit(TowerPlacedEvent.make(900, Vector2i(0, 0), "BASIC", Vector2i.ONE, true, ""))
	# 1 qualifying tower (unfiltered, no primary class): sqrt(1/16) = 0.25
	assert_float(_hero.get_effective_stat(&"tower_affinity")).is_equal_approx(0.25, 0.0001)


func test_tower_removed_and_tower_destroyed_events_erase_cache_entries() -> void:
	GEventBus.tower_placed.emit(TowerPlacedEvent.make(910, Vector2i(0, 0), "BASIC", Vector2i.ONE, true, ""))
	GEventBus.tower_placed.emit(TowerPlacedEvent.make(911, Vector2i(1, 0), "BASIC", Vector2i.ONE, true, ""))
	GEventBus.tower_placed.emit(TowerPlacedEvent.make(912, Vector2i(2, 0), "BASIC", Vector2i.ONE, true, ""))
	GEventBus.tower_placed.emit(TowerPlacedEvent.make(913, Vector2i(3, 0), "BASIC", Vector2i.ONE, true, ""))
	# 4 qualifying (unfiltered): sqrt(4/16) = 0.5
	assert_float(_hero.get_effective_stat(&"tower_affinity")).is_equal_approx(0.5, 0.0001)

	# Voluntary removal of one tower.
	GEventBus.tower_removed.emit(910, Vector2i(0, 0), "BASIC", "")
	# Mid-wave destruction of another.
	GEventBus.tower_destroyed.emit(911, Vector2i(1, 0), "BASIC", [Vector2i(1, 0)], "")
	# 2 remaining: sqrt(2/16) ≈ 0.35355
	var expected: float = sqrt(2.0 / 16.0)
	assert_float(_hero.get_effective_stat(&"tower_affinity")).is_equal_approx(expected, 0.0001)
