extends GdUnitTestSuite

## Unit tests for Hero auto-attack (S4-05, story-003, ADR-0010).
## Covers Rule 3 (fixed cadence, CDR-independent), Rule 4 (target priority),
## Rule 5 (always hits — implicit, no miss-chance code path exists), Rule 6
## (HeroAutoAttackEvent payload correctness), and Rule 7 (in-progress swing
## completes even if the hero later moves out of range).
##
## Data-path corrections vs. the story's own Implementation Notes sketch (see
## dispatch brief): no monster_hp_changed signal, no archetype_tags array —
## the real monster cache shape is {cell, hp, monster_id, tier, path_step},
## populated from monster_spawned/monster_cell_entered/monster_died, mirroring
## TowerSystem's shipped monster-cache pattern (ADR-0007).
##
## Gap 5 (crit-chance cap): get_effective_stat(&"crit_chance") is now resolved
## via a diminishing-returns curve (Hero Combat & Stats Redesign, 2026-09-18),
## asymptotically approaching Hero.CRIT_CHANCE_CAP = 0.85 but never reaching
## it, so crit_chance = 1.0 does NOT deterministically guarantee is_crit =
## true. Rule 6 payload-shape coverage uses crit_chance = 0.0 for a
## deterministic no-crit case (randf() < 0.0 is always false) and a separate
## statistical smoke test at raw=1.0 (curved to ~0.567) to prove the crit path
## is reachable (p(0 crits in 50 trials) = (1-0.567)^50, effectively 0, a
## negligible flake risk in practice).

const CELL_SIZE: float = 64.0  # matches GGrid._cell_size default

var _hero: Hero
var _spy: EventBusSpy


func before_test() -> void:
	_hero = Hero.new()
	add_child(_hero)  # triggers _ready(): collision shape, attack timer, cache subscriptions
	_hero.set_process(false)  # no keyboard input relevant to these tests
	_hero.global_position = GGrid.cell_to_world(Vector2i(0, 0))


func after_test() -> void:
	if _spy != null:
		_spy.disconnect_all()
		_spy = null
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null


func _watch_auto_attacked() -> EventBusSpy:
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_auto_attacked)
	return _spy


# ---------------------------------------------------------------------------
# Rule 3: fixed cadence, CDR-independent
# ---------------------------------------------------------------------------

func test_attack_timer_wait_time_matches_fixed_interval_constant() -> void:
	# Given: Hero with cdr at its cap (0.75, per story-001 Tuning Knobs)
	_hero._base_stats[&"cdr"] = 0.75

	# Then: the attack Timer's wait_time is the fixed constant, never derived from cdr
	assert_float(_hero._attack_timer.wait_time).is_equal_approx(
		Hero.AUTO_ATTACK_INTERVAL_S, 0.0001)


func test_attack_timer_fires_real_timeout_end_to_end_without_manual_invocation() -> void:
	# Regression (found during code review): every other test in this file calls
	# _on_attack_timer_timeout() manually, which never exercises the real Timer
	# node's wiring (autostart, one_shot, .timeout.connect()). A regression that
	# broke autostart, flipped one_shot, or dropped the connect() call would pass
	# every other test in this file silently. Shrink wait_time and restart so the
	# test doesn't wait a full AUTO_ATTACK_INTERVAL_S (1.0s) for real elapsed time.
	_hero._base_stats[&"attack_range"] = 1000.0
	_hero._monster_cache[1] = {"cell": Vector2i(0, 0), "hp": 100.0, "tier": 0, "path_step": 0}
	_watch_auto_attacked()

	_hero._attack_timer.stop()
	_hero._attack_timer.wait_time = 0.05
	_hero._attack_timer.start()

	await get_tree().create_timer(0.2).timeout

	assert_int(_spy.count("hero_auto_attacked")).is_greater_equal(1)


func test_attack_timeout_fires_every_manual_trigger_regardless_of_cdr_value() -> void:
	# Given: Hero with cdr = 1.0 (raw input; clamped to 0.75 internally) and one
	# monster in range
	_hero._base_stats[&"cdr"] = 1.0
	_hero._base_stats[&"attack_range"] = 1000.0
	_hero._monster_cache[1] = {"cell": Vector2i(0, 0), "hp": 100.0, "tier": 0, "path_step": 0}
	_watch_auto_attacked()

	# When: the timeout callback fires twice (simulating two elapsed intervals)
	_hero._on_attack_timer_timeout()
	_hero._on_attack_timer_timeout()

	# Then: two attacks fire — cdr has no bearing on auto-attack rate
	assert_int(_spy.count("hero_auto_attacked")).is_equal(2)


# ---------------------------------------------------------------------------
# Rule 4: target priority
# ---------------------------------------------------------------------------

func test_select_target_prioritizes_highest_path_step_in_range() -> void:
	_hero._base_stats[&"attack_range"] = 100.0
	_hero._monster_cache[1] = {"cell": Vector2i(1, 0), "hp": 100.0, "tier": 0, "path_step": 2}
	_hero._monster_cache[2] = {"cell": Vector2i(1, 1), "hp": 100.0, "tier": 0, "path_step": 8}

	assert_int(_hero._select_target()).is_equal(2)


func test_select_target_tie_breaks_by_lower_hp() -> void:
	_hero._base_stats[&"attack_range"] = 100.0
	_hero._monster_cache[1] = {"cell": Vector2i(1, 0), "hp": 200.0, "tier": 0, "path_step": 5}
	_hero._monster_cache[2] = {"cell": Vector2i(1, 1), "hp": 50.0, "tier": 0, "path_step": 5}

	assert_int(_hero._select_target()).is_equal(2)


func test_select_target_tie_breaks_by_cache_insertion_order_when_step_and_hp_equal() -> void:
	_hero._base_stats[&"attack_range"] = 100.0
	_hero._monster_cache[1] = {"cell": Vector2i(1, 0), "hp": 100.0, "tier": 0, "path_step": 5}
	_hero._monster_cache[2] = {"cell": Vector2i(1, 1), "hp": 100.0, "tier": 0, "path_step": 5}

	# Edge case: identical step and hp -> first inserted (entity_id 1) wins
	assert_int(_hero._select_target()).is_equal(1)


func test_select_target_excludes_monster_outside_attack_range() -> void:
	_hero._base_stats[&"attack_range"] = 100.0
	# Far monster: cell (5,0) -> world (352,32); distance from hero at (32,32) = 320 > 100
	_hero._monster_cache[1] = {"cell": Vector2i(5, 0), "hp": 100.0, "tier": 0, "path_step": 99}
	# Near monster: cell (1,0) -> world (96,32); distance = 64 <= 100
	_hero._monster_cache[2] = {"cell": Vector2i(1, 0), "hp": 100.0, "tier": 0, "path_step": 1}

	assert_int(_hero._select_target()).is_equal(2)


func test_select_target_returns_negative_one_when_cache_empty() -> void:
	_hero._base_stats[&"attack_range"] = 1000.0

	assert_int(_hero._select_target()).is_equal(-1)


# ---------------------------------------------------------------------------
# Rule 6: HeroAutoAttackEvent payload correctness
# ---------------------------------------------------------------------------

func test_attack_timeout_emits_payload_with_expected_fields_on_deterministic_no_crit() -> void:
	# Given: Hero with damage=90, crit_chance=0.0 (deterministic no-crit),
	# crit_multiplier bonus=0.25, lifesteal=0.1, targeting an ELITE monster (tier=1)
	_hero._base_stats[&"physical_attack"] = 90.0
	_hero._base_stats[&"crit_chance"] = 0.0
	_hero._base_stats[&"crit_multiplier"] = 0.25
	_hero._base_stats[&"lifesteal"] = 0.1
	_hero._base_stats[&"attack_range"] = 1000.0
	_hero._monster_cache[42] = {"cell": Vector2i(0, 0), "hp": 100.0, "tier": 1, "path_step": 0}
	_watch_auto_attacked()

	_hero._on_attack_timer_timeout()

	assert_int(_spy.count("hero_auto_attacked")).is_equal(1)
	var payload: HeroAutoAttackEvent = (_spy.emissions["hero_auto_attacked"] as Array)[0][0] as HeroAutoAttackEvent
	assert_float(payload.base_damage).is_equal_approx(90.0, 0.001)
	assert_bool(payload.is_crit).is_false()
	assert_int(payload.target_id).is_equal(42)
	# 1.5 base + diminishing_curve(0.25, 2.0, 1.0) = 1.5 + (0.25*2.0)/(0.25+1.0) = 1.5 + 0.4 = 1.9
	assert_float(payload.crit_multiplier_effective).is_equal_approx(1.9, 0.001)
	assert_float(payload.hero_lifesteal_fraction).is_equal_approx(0.1, 0.001)
	assert_int(payload.hero_bonus_tier).is_equal(1)  # ELITE


func test_attack_timeout_boss_tier_sets_hero_bonus_tier_2() -> void:
	_hero._base_stats[&"attack_range"] = 1000.0
	_hero._monster_cache[7] = {"cell": Vector2i(0, 0), "hp": 500.0, "tier": 2, "path_step": 0}
	_watch_auto_attacked()

	_hero._on_attack_timer_timeout()

	var payload: HeroAutoAttackEvent = (_spy.emissions["hero_auto_attacked"] as Array)[0][0] as HeroAutoAttackEvent
	assert_int(payload.hero_bonus_tier).is_equal(2)  # BOSS


func test_attack_timeout_no_target_in_range_emits_no_event() -> void:
	# Edge case: no monster in cache at all
	_hero._base_stats[&"attack_range"] = 1000.0
	_watch_auto_attacked()

	_hero._on_attack_timer_timeout()

	assert_int(_spy.count("hero_auto_attacked")).is_equal(0)


func test_attack_timeout_crit_roll_can_occur_when_crit_chance_is_capped_high() -> void:
	# Statistical smoke test: crit_chance = 1.0 curves to ~0.5667 (diminishing
	# curve, Hero Combat & Stats Redesign, 2026-09-18) — not a deterministic
	# guarantee. Fire the timeout 50 times and assert at least one crit
	# occurred. p(zero crits) = (1-0.5667)^50, effectively 0.
	_hero._base_stats[&"crit_chance"] = 1.0
	_hero._base_stats[&"attack_range"] = 1000.0
	_hero._monster_cache[1] = {"cell": Vector2i(0, 0), "hp": 100.0, "tier": 0, "path_step": 0}
	_watch_auto_attacked()

	for _i: int in range(50):
		_hero._on_attack_timer_timeout()

	var emissions: Array = _spy.emissions["hero_auto_attacked"] as Array
	var any_crit: bool = false
	for emission: Array in emissions:
		var payload: HeroAutoAttackEvent = emission[0] as HeroAutoAttackEvent
		if payload.is_crit:
			any_crit = true
			break
	assert_bool(any_crit).is_true()


# ---------------------------------------------------------------------------
# TD-hero-001 (fixed): GDD Formula 2 tower_affinity bonus folded into base_damage
# ---------------------------------------------------------------------------

func test_attack_timeout_folds_tower_affinity_bonus_into_base_damage() -> void:
	# Given: damage=100, tower_affinity base=1.0, and 4 qualifying towers (no
	# primary class set -> unfiltered count). bonus_multiplier = sqrt(4/16) = 0.5,
	# so effective tower_affinity = 1.0 * 0.5 = 0.5. Expected base_damage =
	# 100 * (1 + 0.5) = 150.
	_hero._base_stats[&"physical_attack"] = 100.0
	_hero._base_stats[&"tower_affinity"] = 1.0
	_hero._base_stats[&"attack_range"] = 1000.0
	for i: int in range(4):
		GEventBus.tower_placed.emit(TowerPlacedEvent.make(600 + i, Vector2i(i, 0), "BASIC", Vector2i.ONE, true, ""))
		_hero._monster_cache[1] = {"cell": Vector2i(0, 0), "hp": 100.0, "tier": 0, "path_step": 0}
	_watch_auto_attacked()

	_hero._on_attack_timer_timeout()

	var payload: HeroAutoAttackEvent = (_spy.emissions["hero_auto_attacked"] as Array)[0][0] as HeroAutoAttackEvent
	assert_float(payload.base_damage).is_equal_approx(150.0, 0.001)


func test_attack_timeout_zero_tower_affinity_leaves_base_damage_unchanged() -> void:
	# Given: no towers placed -> tower_affinity resolves to 0 -> (1 + 0) = 1x, no change.
	_hero._base_stats[&"physical_attack"] = 100.0
	_hero._base_stats[&"tower_affinity"] = 1.0
	_hero._base_stats[&"attack_range"] = 1000.0
	_hero._monster_cache[1] = {"cell": Vector2i(0, 0), "hp": 100.0, "tier": 0, "path_step": 0}
	_watch_auto_attacked()

	_hero._on_attack_timer_timeout()

	var payload: HeroAutoAttackEvent = (_spy.emissions["hero_auto_attacked"] as Array)[0][0] as HeroAutoAttackEvent
	assert_float(payload.base_damage).is_equal_approx(100.0, 0.001)


# ---------------------------------------------------------------------------
# Rule 7: in-progress swing completes even if hero moves out of range
# ---------------------------------------------------------------------------

func test_swing_already_emitted_target_unaffected_by_hero_moving_out_of_range_afterward() -> void:
	# Given: hero in range of a monster; timeout fires (atomic, synchronous emit)
	_hero._base_stats[&"attack_range"] = 100.0
	_hero._monster_cache[9] = {"cell": Vector2i(1, 0), "hp": 100.0, "tier": 0, "path_step": 0}
	_watch_auto_attacked()

	_hero._on_attack_timer_timeout()

	# When: the hero then moves far out of range (simulating movement mid-"animation")
	_hero.global_position = GGrid.cell_to_world(Vector2i(500, 500))

	# Then: the already-fired swing's payload is untouched — still targets entity 9.
	# (No re-validation code path exists: range is checked only inside
	# _select_target(), at target-acquisition time, never re-checked after.)
	assert_int(_spy.count("hero_auto_attacked")).is_equal(1)
	var payload: HeroAutoAttackEvent = (_spy.emissions["hero_auto_attacked"] as Array)[0][0] as HeroAutoAttackEvent
	assert_int(payload.target_id).is_equal(9)
