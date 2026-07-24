## Integration tests for Story 003 (TR-heroskill-001, ADR-0030): the recompute
## trigger and ownership boundary between Hero Skill Build (sole deriver) and
## Hero System (pure applier, AC-11/AC-12).
##
## HeroSkillBuild and Hero are both instantiated directly (no add_child() for
## HeroSkillBuild; Hero uses add_child() per its own established test
## convention, tests/unit/hero/hero_skill_system_test.gd) — a real EventBus
## round-trip is exercised (Integration story).
extends GdUnitTestSuite

var _hero_skill_build: HeroSkillBuild
var _hero: Hero
var _spy: EventBusSpy


func before_test() -> void:
	_hero_skill_build = HeroSkillBuild.new()
	_hero_skill_build._is_sanctuary = true
	_hero = Hero.new()
	add_child(_hero)
	_hero.set_process(false)
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.ultimate_skill_changed)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null
	if _hero_skill_build != null and is_instance_valid(_hero_skill_build):
		_hero_skill_build.free()
	_hero_skill_build = null


# ---------------------------------------------------------------------------
# AC-11: same-frame recompute + re-emission on every slot change, cooldown discarded
# ---------------------------------------------------------------------------

func test_slot_reassignment_recomputes_and_reemits_same_frame() -> void:
	_hero_skill_build.set_active_slot(0, "phys_cleave")
	_hero_skill_build.set_active_slot(1, "rng_volley")
	_hero_skill_build.set_active_slot(2, "elem_frostbolt")
	_hero_skill_build.set_active_slot(3, "sup_rally")
	# All 4 different categories -> "convergence"
	assert_str(_hero._ultimate_id).is_equal(&"convergence")

	_spy.clear()
	_hero_skill_build.set_active_slot(0, "phys_bulwark")  # still physical -> same shape

	assert_int(_spy.count("ultimate_skill_changed")).is_equal(1)
	assert_str(_hero._ultimate_id).is_equal(&"convergence")


func test_reemission_fires_even_when_resolved_value_is_unchanged() -> void:
	_hero_skill_build.set_active_slot(0, "phys_cleave")
	_hero_skill_build.set_active_slot(1, "rng_volley")
	_hero_skill_build.set_active_slot(2, "elem_frostbolt")
	_hero_skill_build.set_active_slot(3, "sup_rally")
	_spy.clear()

	# Swap slot 0's skill for another physical skill — category profile and
	# therefore the resolved Ultimate ("convergence") is unchanged.
	_hero_skill_build.set_active_slot(0, "phys_bulwark")

	assert_int(_spy.count("ultimate_skill_changed")).is_equal(1)
	var emission: Array = (_spy.emissions["ultimate_skill_changed"] as Array)[0]
	assert_str(emission[0] as String).is_equal("convergence")


func test_slot_change_discards_previous_ultimate_cooldown() -> void:
	# Alpha catalogue Ultimate IDs (e.g. physical_ascendant) have no cooldown
	# data authored in ultimate_combo_table.tres (only the real production
	# "elemental_cataclysm" does) — set the Ultimate directly to that real,
	# cooldown-having ID first so hero_ultimate_activated actually starts a
	# timer, then prove HeroSkillBuild's own slot-change re-emission discards
	# it, matching production behavior exactly.
	GEventBus.ultimate_skill_changed.emit("elemental_cataclysm")
	GEventBus.hero_ultimate_activated.emit()
	assert_bool(_hero._ultimate_cooldown_timer.is_stopped()).is_false()

	_hero_skill_build.set_active_slot(0, "phys_cleave")
	_hero_skill_build.set_active_slot(1, "phys_cleave")
	_hero_skill_build.set_active_slot(2, "phys_cleave")
	_hero_skill_build.set_active_slot(3, "phys_bulwark")  # any slot write triggers re-emission

	assert_bool(_hero._ultimate_cooldown_timer.is_stopped()).is_true()


func test_clearing_a_slot_recomputes_to_empty() -> void:
	_hero_skill_build.set_active_slot(0, "phys_cleave")
	_hero_skill_build.set_active_slot(1, "rng_volley")
	_hero_skill_build.set_active_slot(2, "elem_frostbolt")
	_hero_skill_build.set_active_slot(3, "sup_rally")
	assert_str(_hero._ultimate_id).is_not_equal(&"")

	_hero_skill_build.set_active_slot(3, "")

	assert_str(_hero._ultimate_id).is_equal(&"EMPTY")


# ---------------------------------------------------------------------------
# AC-12: Hero applies verbatim, never independently re-derives
# ---------------------------------------------------------------------------

func test_hero_applies_ultimate_id_verbatim() -> void:
	_hero_skill_build.set_active_slot(0, "phys_cleave")
	_hero_skill_build.set_active_slot(1, "phys_cleave")
	_hero_skill_build.set_active_slot(2, "phys_cleave")
	_hero_skill_build.set_active_slot(3, "phys_cleave")

	assert_str(_hero._ultimate_id).is_equal(&"physical_ascendant")


func test_hero_has_no_independent_derivation_path() -> void:
	# Directly emitting an arbitrary, non-derivable ultimate_id proves Hero
	# performs no validation or re-derivation of its own — it applies
	# whatever it receives verbatim, confirming the ownership boundary
	# (Forbidden rule: Hero must never independently compute a category
	# profile or shape from raw skill IDs).
	GEventBus.ultimate_skill_changed.emit("totally_synthetic_id_not_in_any_table")
	assert_str(_hero._ultimate_id).is_equal(&"totally_synthetic_id_not_in_any_table")
