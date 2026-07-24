extends GdUnitTestSuite

## Integration tests for Hero's Tower-Synced Class Proximity subsystem (story-006,
## ADR-0010 "Tower-Synced Class — Proximity Accumulation" / "Unlock Logic").
##
## Governing ADR: docs/architecture/adr-0010-hero-tower-synced-class.md
## Story: production/epics/epic-02-core-combat/story-006-hero-class-proximity.md
##
## Scope note: this suite tests story-006's SIMPLER 30s-primary-unlock-only model
## (locking immediately in _physics_process on threshold crossing), not ADR-0010's
## fuller model (90s deep-unlock, SCOUT-phase-entry primary/secondary computation)
## — that fuller model is explicitly out of scope for story-006 (deferred to a
## later story).
##
## Deterministic timing per the story's own suggested strategy: proximity_time is
## injected directly and _physics_process() is called with an explicit delta,
## rather than waiting real seconds or real physics frames.
##
## hero_class_unlocked is emitted via .emit.call_deferred() (ADR-0001 Rule 2 —
## physics caller) — observed via EventBusSpy + a single process_frame flush,
## matching this project's existing pattern for hero_position_changed
## (see tests/integration/hero/hero_movement_test.gd).

var _hero: Hero
var _spy: EventBusSpy


func after_test() -> void:
	if _spy != null:
		_spy.disconnect_all()
		_spy = null
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null


func _make_hero() -> Hero:
	_hero = Hero.new()
	add_child(_hero)  # triggers _ready(): collision shape, timers, EventBus subscriptions
	_hero._base_stats[&"move_speed"] = 0.0
	_hero.set_process(false)  # avoid the real Input singleton overwriting _input_direction
	return _hero


# ---------------------------------------------------------------------------
# AC-09: class unlock at the 30s cumulative-proximity threshold
# ---------------------------------------------------------------------------

func test_class_proximity_ac09_unlocks_primary_class_at_threshold_crossing() -> void:
	# Given: hero at cell (5,5), a FROST tower at Chebyshev distance 1, proximity
	# tracking active, and FROST already at 29.9s cumulative proximity.
	var hero := _make_hero()
	hero.global_position = GGrid.cell_to_world(Vector2i(5, 5))
	GEventBus.tower_placed.emit(TowerPlacedEvent.make(1001, Vector2i(6, 6), "FROST", Vector2i.ONE, true, ""))
	hero._proximity_active = true
	hero._proximity_time[&"FROST"] = 29.9

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_class_unlocked)

	# When: 0.2s of physics elapses, crossing the 30.0s threshold.
	hero._physics_process(0.2)
	await get_tree().process_frame  # flush the deferred emit (ADR-0001 Rule 2)

	# Then: _primary_class is set, the class is locked, and hero_class_unlocked
	# fires exactly once with (&"FROST", false).
	assert_bool(hero._primary_class == &"FROST").is_true()
	assert_bool(hero._class_locked).is_true()
	assert_int(_spy.count("hero_class_unlocked")).is_equal(1)
	var args: Array = (_spy.emissions["hero_class_unlocked"] as Array)[0] as Array
	assert_bool((args[0] as StringName) == &"FROST").is_true()
	assert_bool(args[1] as bool).is_false()


func test_class_proximity_tower_at_exact_radius_boundary_still_accumulates() -> void:
	# Edge case: Chebyshev distance exactly CLASS_PROXIMITY_RADIUS (3) counts.
	var hero := _make_hero()
	hero.global_position = GGrid.cell_to_world(Vector2i(5, 5))
	GEventBus.tower_placed.emit(TowerPlacedEvent.make(1002, Vector2i(8, 5), "FROST", Vector2i.ONE, true, ""))
	hero._proximity_active = true

	hero._physics_process(1.0)

	assert_float(hero._proximity_time.get(&"FROST", 0.0)).is_equal_approx(1.0, 0.0001)


func test_class_proximity_tower_beyond_radius_does_not_accumulate() -> void:
	# Edge case: Chebyshev distance CLASS_PROXIMITY_RADIUS + 1 (4) does not count.
	var hero := _make_hero()
	hero.global_position = GGrid.cell_to_world(Vector2i(5, 5))
	GEventBus.tower_placed.emit(TowerPlacedEvent.make(1003, Vector2i(9, 5), "FROST", Vector2i.ONE, true, ""))
	hero._proximity_active = true

	hero._physics_process(1.0)

	assert_float(hero._proximity_time.get(&"FROST", 0.0)).is_equal_approx(0.0, 0.0001)


# ---------------------------------------------------------------------------
# AC-10: SCOUT phase excluded from proximity tracking
# ---------------------------------------------------------------------------

func test_class_proximity_ac10_scout_phase_does_not_accumulate() -> void:
	# Given: hero in range of a FROST tower, but _proximity_active = false (SCOUT).
	var hero := _make_hero()
	hero.global_position = GGrid.cell_to_world(Vector2i(5, 5))
	GEventBus.tower_placed.emit(TowerPlacedEvent.make(1004, Vector2i(5, 6), "FROST", Vector2i.ONE, true, ""))
	hero._proximity_active = false

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_class_unlocked)

	# When: a full 30 seconds of physics elapses in one call.
	hero._physics_process(30.0)
	await get_tree().process_frame

	# Then: no accumulation occurred and no class was unlocked.
	assert_bool(hero._proximity_time.has(&"FROST")).is_false()
	assert_bool(hero._primary_class == &"").is_true()
	assert_int(_spy.count("hero_class_unlocked")).is_equal(0)


func test_mission_phase_changed_subscription_toggles_proximity_active() -> void:
	# Regression guard for the subscription itself (added this story) — proves
	# _on_mission_phase_changed is actually wired to GEventBus.mission_phase_changed
	# in _ready(), not just callable directly.
	var hero := _make_hero()
	assert_bool(hero._proximity_active).is_false()

	GEventBus.mission_phase_changed.emit("SCOUT", "WAVE_ACTIVE", 0.0)
	assert_bool(hero._proximity_active).is_true()

	# Bug fix regression: SCOUT entry with NO primary class designated must NOT
	# force-lock (see test below for the full permanent-lockout scenario this
	# guards against). _class_locked stays false here because _primary_class
	# is still &"".
	GEventBus.mission_phase_changed.emit("WAVE_ACTIVE", "SCOUT", 30.0)
	assert_bool(hero._proximity_active).is_false()
	assert_bool(hero._class_locked).is_false()


func test_class_proximity_scout_entry_with_designated_class_locks() -> void:
	# Companion case to the test above: SCOUT entry DOES force-lock when a
	# primary class has actually been designated (belt-and-suspenders per
	# AC-11), it's specifically the &"" (undesignated) case that must not lock.
	var hero := _make_hero()
	hero._primary_class = &"FROST"

	GEventBus.mission_phase_changed.emit("WAVE_ACTIVE", "SCOUT", 30.0)

	assert_bool(hero._class_locked).is_true()


func test_class_proximity_bugfix_scout_before_any_unlock_does_not_permanently_disable_unlocking() -> void:
	# Regression test for the code-review BLOCKING bug: SCOUT is the FIRST
	# phase of every mission (design/gdd/hero.md phase table). The original
	# implementation force-set _class_locked = true on ANY SCOUT entry, even
	# with no class designated — permanently disabling proximity accumulation
	# for the rest of the playthrough after the very first SCOUT transition.
	# This test proves accumulation still works AFTER an initial SCOUT phase
	# that occurred before anything was ever unlocked.
	var hero := _make_hero()

	# Simulate the very first SCOUT phase of the game — nothing unlocked yet.
	hero._on_mission_phase_changed("IDLE_SANCTUARY", "SCOUT", 0.0)
	assert_bool(hero._class_locked).is_false()

	# Mission begins: WAVE_ACTIVE starts, hero is near a FROST tower.
	hero._on_mission_phase_changed("SCOUT", "WAVE_ACTIVE", 0.0)
	hero.global_position = GGrid.cell_to_world(Vector2i(5, 5))
	GEventBus.tower_placed.emit(TowerPlacedEvent.make(2001, Vector2i(5, 6), "FROST", Vector2i.ONE, true, ""))
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_class_unlocked)

	hero._physics_process(30.0)
	await get_tree().process_frame

	# Then: proximity accumulation still ran and the class unlocked normally —
	# the earlier SCOUT phase did not permanently disable it.
	assert_bool(hero._primary_class == &"FROST").is_true()
	assert_bool(hero._class_locked).is_true()
	assert_int(_spy.count("hero_class_unlocked")).is_equal(1)


# ---------------------------------------------------------------------------
# AC-11: primary class lock cannot be displaced once designated
# ---------------------------------------------------------------------------

func test_class_proximity_ac11_locked_primary_class_cannot_be_displaced() -> void:
	# Given: a primary class already designated and locked from a previous run.
	var hero := _make_hero()
	hero._primary_class = &"FROST"
	hero._class_locked = true
	hero.global_position = GGrid.cell_to_world(Vector2i(5, 5))
	GEventBus.tower_placed.emit(TowerPlacedEvent.make(1005, Vector2i(5, 6), "FIRE", Vector2i.ONE, true, ""))
	hero._proximity_time[&"FIRE"] = 29.9

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_class_unlocked)

	# When: WAVE_ACTIVE begins again, and enough time passes that FIRE alone
	# would otherwise cross the 30s threshold.
	hero._on_mission_phase_changed("SCOUT", "WAVE_ACTIVE", 0.0)
	hero._physics_process(0.2)
	await get_tree().process_frame

	# Then: _primary_class remains FROST — FIRE cannot displace it, and no
	# further accumulation toward FIRE occurs (the locked guard short-circuits
	# _update_class_proximity() entirely).
	assert_bool(hero._primary_class == &"FROST").is_true()
	assert_float(hero._proximity_time.get(&"FIRE", 0.0)).is_equal_approx(29.9, 0.0001)
	assert_int(_spy.count("hero_class_unlocked")).is_equal(0)
