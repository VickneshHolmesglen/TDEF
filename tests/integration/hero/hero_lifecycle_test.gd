extends GdUnitTestSuite

## Integration tests for Hero Lifecycle, Death & Save (story-008).
##
## Governing ADRs: ADR-0010 (Hero), ADR-0002 (Scene/Autoload Structure, Rule 2 —
## synchronous emission from non-physics callers), ADR-0003 (Save File Format).
## Story: production/epics/epic-02-core-combat/story-008-hero-lifecycle.md
##
## Covers:
##   - AC-13: hero_died + mission_phase_changed(..., "DEFEAT", ...) fire
##     synchronously (same frame, no await) from _on_hero_damage_taken, plus the
##     exact HP-threshold edge cases (amount == current HP -> death at exactly
##     0; amount == current HP - 1 -> HP = 1.0, no death).
##   - Rule 19: HeroPhase state machine transitions, driven exclusively by the
##     real mission_phase_changed signal (Hero never reads WaveManager
##     directly) — SANCTUARY -> SCOUT -> WAVE_ACTIVE -> INTERMISSION ->
##     DEFEAT/MISSION_COMPLETE.
##   - Rule 20: hero_damage_taken is a no-op (no HP change, no
##     hero_health_changed, no death check) outside COMBAT/INTERMISSION.
##   - Save/Restore: get_save_data() / reset_to_defaults() / restore_save_data()
##     full round-trip, plus malformed-input rejection (returns false).
##
## Fixture pattern matches tests/integration/hero/hero_class_proximity_test.gd:
## real Hero (CharacterBody2D) added to the tree via add_child() (triggers
## _ready(): collision shape, timers, EventBus subscriptions, GSavePersistence
## registration, and the reset_to_defaults() call that seeds starting HP),
## _process() disabled to avoid the real Input singleton overwriting the test
## seam, and add_child()/remove_child()+.free() teardown in after_test()
## (triggers _exit_tree(): EventBus disconnects + GSavePersistence.unregister()).
##
## AC-13's same-frame requirement is verified by asserting on EventBusSpy
## immediately after the triggering emit() call, with no
## `await get_tree().process_frame` in between — proving no deferral occurred.

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
	add_child(_hero)  # triggers _ready(): collision shape, timers, EventBus
	# subscriptions, GSavePersistence.register(), and reset_to_defaults()
	_hero._base_stats[&"move_speed"] = 0.0
	_hero.set_process(false)  # avoid the real Input singleton overwriting _input_direction
	return _hero


# ---------------------------------------------------------------------------
# AC-13: death triggers hero_died + mission_phase_changed(DEFEAT) same frame
# ---------------------------------------------------------------------------

func test_ac13_damage_equal_to_current_hp_triggers_death_at_exactly_zero() -> void:
	# Given: Hero in COMBAT with HP == amount, so the hit lands exactly on 0.
	var hero := _make_hero()
	hero._phase = Hero.HeroPhase.COMBAT
	hero._current_hp = 10.0
	hero._max_hp = 10.0

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_died)
	_spy.watch(GEventBus.mission_phase_changed)
	_spy.watch(GEventBus.hero_health_changed)

	# When: hero_damage_taken fires with amount == current HP.
	GEventBus.hero_damage_taken.emit(10, 0)

	# Then: HP is exactly 0, death fires, and DEFEAT fires — all synchronously,
	# with no await in between (proves same-frame, no 1-frame delay).
	assert_float(hero._current_hp).is_equal_approx(0.0, 0.0001)
	assert_bool(hero._phase == Hero.HeroPhase.DEAD).is_true()
	assert_int(_spy.count("hero_died")).is_equal(1)
	assert_int(_spy.count("mission_phase_changed")).is_equal(1)
	var args: Array = (_spy.emissions["mission_phase_changed"] as Array)[0] as Array
	assert_str(args[1] as String).is_equal("DEFEAT")


func test_ac13_damage_one_less_than_current_hp_leaves_hp_one_no_death() -> void:
	# Given: Hero in COMBAT with HP = 10, amount = 9 (one less than lethal).
	var hero := _make_hero()
	hero._phase = Hero.HeroPhase.COMBAT
	hero._current_hp = 10.0
	hero._max_hp = 10.0

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_died)
	_spy.watch(GEventBus.mission_phase_changed)
	_spy.watch(GEventBus.hero_health_changed)

	# When
	GEventBus.hero_damage_taken.emit(9, 0)

	# Then: HP = 1.0, hero_health_changed fires once, no death, no DEFEAT.
	assert_float(hero._current_hp).is_equal_approx(1.0, 0.0001)
	assert_bool(hero._phase == Hero.HeroPhase.COMBAT).is_true()
	assert_int(_spy.count("hero_health_changed")).is_equal(1)
	assert_int(_spy.count("hero_died")).is_equal(0)
	assert_int(_spy.count("mission_phase_changed")).is_equal(0)


func test_ac13_overkill_damage_still_triggers_death() -> void:
	# Edge case: damage exceeding current HP still triggers death and clamps
	# HP at 0 (never negative).
	var hero := _make_hero()
	hero._phase = Hero.HeroPhase.INTERMISSION
	hero._current_hp = 10.0
	hero._max_hp = 10.0

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_died)

	GEventBus.hero_damage_taken.emit(999, 0)

	assert_float(hero._current_hp).is_equal_approx(0.0, 0.0001)
	assert_int(_spy.count("hero_died")).is_equal(1)
	assert_bool(hero._phase == Hero.HeroPhase.DEAD).is_true()


# ---------------------------------------------------------------------------
# Rule 20: damage is a no-op outside COMBAT/INTERMISSION
# ---------------------------------------------------------------------------

func test_rule20_damage_is_noop_in_idle_sanctuary() -> void:
	var hero := _make_hero()
	hero._phase = Hero.HeroPhase.IDLE_SANCTUARY
	hero._current_hp = 10.0
	hero._max_hp = 10.0

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_health_changed)
	_spy.watch(GEventBus.hero_died)

	GEventBus.hero_damage_taken.emit(5, 0)

	assert_float(hero._current_hp).is_equal_approx(10.0, 0.0001)
	assert_int(_spy.count("hero_health_changed")).is_equal(0)
	assert_int(_spy.count("hero_died")).is_equal(0)


func test_rule20_damage_is_noop_in_scout() -> void:
	var hero := _make_hero()
	hero._phase = Hero.HeroPhase.SCOUT
	hero._current_hp = 10.0
	hero._max_hp = 10.0

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_health_changed)
	_spy.watch(GEventBus.hero_died)

	GEventBus.hero_damage_taken.emit(5, 0)

	assert_float(hero._current_hp).is_equal_approx(10.0, 0.0001)
	assert_int(_spy.count("hero_health_changed")).is_equal(0)
	assert_int(_spy.count("hero_died")).is_equal(0)


func test_rule20_damage_is_noop_when_already_dead() -> void:
	# Guards against a lethal hit re-triggering hero_died once DEAD.
	var hero := _make_hero()
	hero._phase = Hero.HeroPhase.DEAD
	hero._current_hp = 0.0
	hero._max_hp = 10.0

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_died)
	_spy.watch(GEventBus.hero_health_changed)

	GEventBus.hero_damage_taken.emit(5, 0)

	assert_int(_spy.count("hero_died")).is_equal(0)
	assert_int(_spy.count("hero_health_changed")).is_equal(0)


func test_rule20_damage_applies_in_combat() -> void:
	var hero := _make_hero()
	hero._phase = Hero.HeroPhase.COMBAT
	hero._current_hp = 10.0
	hero._max_hp = 10.0

	GEventBus.hero_damage_taken.emit(3, 0)

	assert_float(hero._current_hp).is_equal_approx(7.0, 0.0001)


func test_rule20_damage_applies_in_intermission() -> void:
	var hero := _make_hero()
	hero._phase = Hero.HeroPhase.INTERMISSION
	hero._current_hp = 10.0
	hero._max_hp = 10.0

	GEventBus.hero_damage_taken.emit(3, 0)

	assert_float(hero._current_hp).is_equal_approx(7.0, 0.0001)


# ---------------------------------------------------------------------------
# Rule 19: HeroPhase state machine transitions
# ---------------------------------------------------------------------------

func test_rule19_starts_in_idle_sanctuary() -> void:
	var hero := _make_hero()
	assert_bool(hero._phase == Hero.HeroPhase.IDLE_SANCTUARY).is_true()


func test_rule19_scout_transitions_to_scout_phase() -> void:
	var hero := _make_hero()
	GEventBus.mission_phase_changed.emit("SANCTUARY", "SCOUT", 0.0)
	assert_bool(hero._phase == Hero.HeroPhase.SCOUT).is_true()


func test_rule19_wave_active_transitions_to_combat_phase() -> void:
	var hero := _make_hero()
	GEventBus.mission_phase_changed.emit("SCOUT", "WAVE_ACTIVE", 1.0)
	assert_bool(hero._phase == Hero.HeroPhase.COMBAT).is_true()


func test_rule19_intermission_transitions_to_intermission_phase() -> void:
	var hero := _make_hero()
	GEventBus.mission_phase_changed.emit("WAVE_ACTIVE", "INTERMISSION", 2.0)
	assert_bool(hero._phase == Hero.HeroPhase.INTERMISSION).is_true()


func test_rule19_defeat_transitions_to_dead_phase() -> void:
	var hero := _make_hero()
	GEventBus.mission_phase_changed.emit("INTERMISSION", "DEFEAT", 3.0)
	assert_bool(hero._phase == Hero.HeroPhase.DEAD).is_true()


func test_rule19_mission_complete_transitions_to_dead_phase() -> void:
	# Real win-condition phase string (verified against
	# src/gameplay/wave_manager.gd's Phase enum) is "MISSION_COMPLETE", not
	# "VICTORY" — no "VICTORY" phase string exists anywhere in this codebase.
	var hero := _make_hero()
	GEventBus.mission_phase_changed.emit("INTERMISSION", "MISSION_COMPLETE", 3.0)
	assert_bool(hero._phase == Hero.HeroPhase.DEAD).is_true()


func test_rule19_full_sequence_idle_scout_combat_intermission_dead() -> void:
	var hero := _make_hero()
	assert_bool(hero._phase == Hero.HeroPhase.IDLE_SANCTUARY).is_true()

	GEventBus.mission_phase_changed.emit("SANCTUARY", "SCOUT", 0.0)
	assert_bool(hero._phase == Hero.HeroPhase.SCOUT).is_true()

	GEventBus.mission_phase_changed.emit("SCOUT", "WAVE_ACTIVE", 60.0)
	assert_bool(hero._phase == Hero.HeroPhase.COMBAT).is_true()

	GEventBus.mission_phase_changed.emit("WAVE_ACTIVE", "INTERMISSION", 120.0)
	assert_bool(hero._phase == Hero.HeroPhase.INTERMISSION).is_true()

	GEventBus.mission_phase_changed.emit("INTERMISSION", "DEFEAT", 150.0)
	assert_bool(hero._phase == Hero.HeroPhase.DEAD).is_true()


func test_rule19_sanctuary_phase_sets_idle_sanctuary() -> void:
	var hero := _make_hero()
	hero._phase = Hero.HeroPhase.DEAD
	GEventBus.mission_phase_changed.emit("DEFEAT", "SANCTUARY", 0.0)
	assert_bool(hero._phase == Hero.HeroPhase.IDLE_SANCTUARY).is_true()


# ---------------------------------------------------------------------------
# Save/Restore
# ---------------------------------------------------------------------------

func test_get_save_key_returns_hero() -> void:
	var hero := _make_hero()
	assert_str(hero.get_save_key()).is_equal("hero")


func test_save_restore_round_trip_all_fields_match_original() -> void:
	# Given: hero populated with real values across all persisted fields.
	var hero := _make_hero()
	hero._current_hp = 75.0
	hero._max_hp = 100.0
	hero._proximity_time[&"FROST"] = 22.5
	hero._primary_class = &""
	hero._class_locked = false
	hero._skill_slots = [&"FIREBALL", &"", &"", &""]

	# When: save, then wipe via reset_to_defaults(), then restore.
	var saved: Dictionary = hero.get_save_data()
	hero.reset_to_defaults()

	# Sanity: reset_to_defaults() actually cleared state before we restore over it.
	assert_bool(hero._proximity_time.is_empty()).is_true()
	assert_bool(hero._skill_slots[0] == &"").is_true()

	var ok: bool = hero.restore_save_data(saved)

	# Then: all fields match the original values.
	assert_bool(ok).is_true()
	assert_float(hero._current_hp).is_equal_approx(75.0, 0.0001)
	assert_float(hero._proximity_time.get(&"FROST", 0.0)).is_equal_approx(22.5, 0.0001)
	assert_bool(hero._primary_class == &"").is_true()
	assert_bool(hero._class_locked).is_false()
	assert_bool(hero._skill_slots[0] == &"FIREBALL").is_true()
	assert_bool(hero._skill_slots[1] == &"").is_true()
	assert_bool(hero._skill_slots[2] == &"").is_true()
	assert_bool(hero._skill_slots[3] == &"").is_true()


func test_save_restore_round_trip_class_locked_true_and_empty_proximity() -> void:
	# Edge cases: empty _proximity_time restores as empty Dictionary;
	# _class_locked = true restores correctly.
	var hero := _make_hero()
	hero._current_hp = 40.0
	hero._max_hp = 40.0
	hero._proximity_time.clear()
	hero._primary_class = &"FIRE"
	hero._class_locked = true
	hero._skill_slots = [&"", &"", &"", &""]

	var saved: Dictionary = hero.get_save_data()
	hero.reset_to_defaults()
	var ok: bool = hero.restore_save_data(saved)

	assert_bool(ok).is_true()
	assert_bool(hero._proximity_time.is_empty()).is_true()
	assert_bool(hero._primary_class == &"FIRE").is_true()
	assert_bool(hero._class_locked).is_true()


func test_reset_to_defaults_clears_all_fields() -> void:
	var hero := _make_hero()
	hero._current_hp = 5.0
	hero._proximity_time[&"FROST"] = 10.0
	hero._primary_class = &"FROST"
	hero._class_locked = true
	hero._skill_slots = [&"FIREBALL", &"", &"", &""]
	hero._phase = Hero.HeroPhase.COMBAT

	hero.reset_to_defaults()

	assert_bool(hero._proximity_time.is_empty()).is_true()
	assert_bool(hero._primary_class == &"").is_true()
	assert_bool(hero._class_locked).is_false()
	assert_bool(hero._skill_slots[0] == &"").is_true()
	assert_bool(hero._phase == Hero.HeroPhase.IDLE_SANCTUARY).is_true()


func test_restore_save_data_returns_false_on_missing_key() -> void:
	# Malformed: missing "skill_slots" entirely.
	var hero := _make_hero()
	var malformed: Dictionary = {
		"hp": 50.0,
		"proximity_time": {},
		"primary_class": "",
		"class_locked": false,
	}
	var ok: bool = hero.restore_save_data(malformed)
	assert_bool(ok).is_false()


func test_restore_save_data_returns_false_on_wrong_skill_slots_size() -> void:
	var hero := _make_hero()
	var malformed: Dictionary = {
		"hp": 50.0,
		"proximity_time": {},
		"primary_class": "",
		"class_locked": false,
		"skill_slots": ["FIREBALL", ""],  # size 2, not 4
	}
	var ok: bool = hero.restore_save_data(malformed)
	assert_bool(ok).is_false()


func test_restore_save_data_returns_false_on_wrong_type_for_hp() -> void:
	var hero := _make_hero()
	var malformed: Dictionary = {
		"hp": "not_a_number",
		"proximity_time": {},
		"primary_class": "",
		"class_locked": false,
		"skill_slots": ["", "", "", ""],
	}
	var ok: bool = hero.restore_save_data(malformed)
	assert_bool(ok).is_false()


## Regression test (code review fix): restore_save_data() previously only did
## a has() presence check on "primary_class" before casting it to String —
## missing type validation risked a runtime cast error on malformed data
## (e.g. a corrupted or hand-edited save storing primary_class as an int),
## violating the function's own contract of "never throw, return false".
func test_restore_save_data_returns_false_on_wrong_type_for_primary_class() -> void:
	var hero := _make_hero()
	var malformed: Dictionary = {
		"hp": 50.0,
		"proximity_time": {},
		"primary_class": 123,  # should be String, not int
		"class_locked": false,
		"skill_slots": ["", "", "", ""],
	}
	var ok: bool = hero.restore_save_data(malformed)
	assert_bool(ok).is_false()


func test_restore_failure_via_save_persistence_falls_back_to_reset_to_defaults() -> void:
	# Exercises SavePersistence's own restore-failure contract
	# (_restore_all_systems() calls reset_to_defaults() when restore_save_data()
	# returns false) using a fresh, unregistered SavePersistence instance (no
	# GSavePersistence Autoload / file I/O involved), matching this codebase's
	# established stub pattern (tests/unit/save_persistence/save_persistence_restore_test.gd).
	var hero := _make_hero()
	hero._current_hp = 30.0
	hero._proximity_time[&"FROST"] = 5.0
	hero._primary_class = &"FROST"
	hero._class_locked = true
	hero._skill_slots = [&"FIREBALL", &"", &"", &""]

	var sp := SavePersistence.new()
	sp._registered_systems.append({"ref": hero, "key": "hero", "restore_order": Hero.RESTORE_ORDER})

	# Malformed payload for "hero" — missing "skill_slots" — must be rejected.
	var malformed_data: Dictionary = {
		"hero": {"hp": 999.0, "proximity_time": {}, "primary_class": "", "class_locked": false},
	}
	sp._restore_all_systems(malformed_data, 0)

	# reset_to_defaults() must have run — fields cleared, not left at the
	# malformed payload's (rejected) values, and not left at their pre-restore
	# populated values either.
	assert_bool(hero._proximity_time.is_empty()).is_true()
	assert_bool(hero._primary_class == &"").is_true()
	assert_bool(hero._class_locked).is_false()
	assert_bool(hero._skill_slots[0] == &"").is_true()

	sp.free()
