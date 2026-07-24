## Integration tests for Story 005 (TR-heroskill-002, ADR-0030): persistence
## boundary and cross-mission state (AC-15/16/17/26).
##
## HeroSkillBuild is instantiated directly (HeroSkillBuild.new(), no
## add_child()) so _ready() never fires — GSavePersistence.register() is
## never called, avoiding pollution of the real Autoload's registered-systems
## list. get_save_data()/restore_save_data() are called directly, matching
## this project's established persistence-test convention (Tarot, Mission
## Select). _on_scene_transition_completed()/_on_skill_unlocked() are called
## directly to simulate the real subscriptions since _ready() never runs.
extends GdUnitTestSuite

var _hero_skill_build: HeroSkillBuild


func before_test() -> void:
	_hero_skill_build = HeroSkillBuild.new()


func after_test() -> void:
	if _hero_skill_build != null and is_instance_valid(_hero_skill_build):
		_hero_skill_build.free()
	_hero_skill_build = null


func test_restore_order_is_31() -> void:
	assert_int(HeroSkillBuild.RESTORE_ORDER).is_equal(31)


# ---------------------------------------------------------------------------
# AC-15: slot assignments persist across every mission-exit path
# ---------------------------------------------------------------------------

func test_slot_assignments_survive_a_save_load_round_trip() -> void:
	_hero_skill_build._is_sanctuary = true
	_hero_skill_build._on_skill_unlocked("phys_cleave", 1)
	_hero_skill_build.set_active_slot(0, "phys_cleave")
	_hero_skill_build.set_passive_slot("phys_cleave", 0, "some_item")

	var saved: Dictionary = _hero_skill_build.get_save_data()
	assert_bool(saved.has("equippable_skills")).is_true()
	assert_bool(saved.has("active_slots")).is_true()
	assert_bool(saved.has("passive_slots")).is_true()

	var restored: HeroSkillBuild = HeroSkillBuild.new()
	var ok: bool = restored.restore_save_data(saved)
	assert_bool(ok).is_true()

	assert_array(restored.get_active_slots()).contains_exactly(["phys_cleave", "", "", ""])
	assert_array(restored.get_passive_loadout("phys_cleave")).contains_exactly(["some_item"])
	restored.free()


func test_mission_phase_transitions_never_reset_slot_assignments() -> void:
	# Nothing in HeroSkillBuild's own code resets slots on MISSION_COMPLETE/
	# DEFEAT — only reset_to_defaults() does, and only SavePersistence calls
	# that (new-save condition). Prove slots survive an arbitrary sequence of
	# scene transitions (simulating a full mission cycle) untouched.
	_hero_skill_build._is_sanctuary = true
	_hero_skill_build.set_active_slot(0, "phys_cleave")

	_hero_skill_build._on_scene_transition_completed("MISSION", "the_gap")  # -> LOCKED
	_hero_skill_build._on_scene_transition_completed("SANCTUARY", "")       # mission ends, back to SANCTUARY

	assert_array(_hero_skill_build.get_active_slots()).contains_exactly(["phys_cleave", "", "", ""])


# ---------------------------------------------------------------------------
# AC-16: only a brand-new save resets everything together
# ---------------------------------------------------------------------------

func test_reset_to_defaults_clears_all_three_structures_together() -> void:
	_hero_skill_build._is_sanctuary = true
	_hero_skill_build._on_skill_unlocked("phys_cleave", 1)
	_hero_skill_build.set_active_slot(0, "phys_cleave")
	_hero_skill_build.set_passive_slot("phys_cleave", 0, "some_item")

	_hero_skill_build.reset_to_defaults()

	assert_array(_hero_skill_build.get_active_slots()).contains_exactly(["", "", "", ""])
	assert_array(_hero_skill_build.get_passive_loadout("phys_cleave")).is_empty()
	assert_str(_hero_skill_build._derive_ultimate_id()).is_equal("EMPTY")


func test_restore_save_data_rejects_malformed_payload() -> void:
	assert_bool(_hero_skill_build.restore_save_data({})).is_false()
	assert_bool(_hero_skill_build.restore_save_data({"equippable_skills": {}, "active_slots": ["", "", ""], "passive_slots": {}})).is_false()  # wrong size


# ---------------------------------------------------------------------------
# AC-17: skill_unlocked live during LOCKED, no write, no recompute
# ---------------------------------------------------------------------------

func test_skill_unlocked_during_locked_adds_to_library_without_recompute() -> void:
	_hero_skill_build._is_sanctuary = false  # LOCKED
	var spy: EventBusSpy = EventBusSpy.new()
	spy.watch(GEventBus.ultimate_skill_changed)
	spy.watch(GEventBus.active_skill_equipped)

	_hero_skill_build._on_skill_unlocked("phys_cleave", 1)

	assert_bool(spy.was_emitted("ultimate_skill_changed")).is_false()
	assert_bool(spy.was_emitted("active_skill_equipped")).is_false()
	spy.disconnect_all()


func test_skill_unlocked_during_locked_is_immediately_assignable_once_configurable() -> void:
	_hero_skill_build._is_sanctuary = false
	_hero_skill_build._on_skill_unlocked("phys_cleave", 1)

	_hero_skill_build._is_sanctuary = true  # -> CONFIGURABLE
	var result: bool = _hero_skill_build.set_active_slot(0, "phys_cleave")

	assert_bool(result).is_true()


# ---------------------------------------------------------------------------
# AC-26: full state machine transition sequence
# ---------------------------------------------------------------------------

func test_full_state_sequence_writes_only_accepted_while_configurable() -> void:
	# DORMANT-equivalent (before any scene_transition_completed) — write rejected.
	assert_bool(_hero_skill_build.set_active_slot(0, "phys_cleave")).is_false()

	# -> CONFIGURABLE (SANCTUARY)
	_hero_skill_build._on_scene_transition_completed("SANCTUARY", "")
	assert_bool(_hero_skill_build.set_active_slot(0, "phys_cleave")).is_true()

	# -> LOCKED (mission)
	_hero_skill_build._on_scene_transition_completed("MISSION", "the_gap")
	assert_bool(_hero_skill_build.set_active_slot(1, "rng_volley")).is_false()
	# Ultimate remains live-readable throughout LOCKED.
	assert_str(_hero_skill_build.get_all_slot_bindings()["U"]).is_equal("EMPTY")

	# -> CONFIGURABLE again (mission ends, back to SANCTUARY)
	_hero_skill_build._on_scene_transition_completed("SANCTUARY", "")
	assert_bool(_hero_skill_build.set_active_slot(1, "rng_volley")).is_true()
