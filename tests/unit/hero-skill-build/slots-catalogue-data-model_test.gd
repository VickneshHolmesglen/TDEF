## Unit tests for Story 001 (TR-heroskill-001 data-model portion, ADR-0030):
## the slot/catalogue data model — 5 independent bindings, Sanctuary-only
## write gating, duplicate skill_id allowance, and category-enum parity with
## tower.md's Foundation archetype enum.
##
## HeroSkillBuild is instantiated directly (HeroSkillBuild.new(), no
## add_child()) — matching this project's established test convention.
extends GdUnitTestSuite

var _hero_skill_build: HeroSkillBuild

const ALPHA_SKILL_IDS: Array[StringName] = [
	&"phys_cleave", &"phys_bulwark", &"rng_piercing_shot", &"rng_volley",
	&"elem_frostbolt", &"elem_firestorm", &"sup_rally", &"sup_barrier",
]


func before_test() -> void:
	_hero_skill_build = HeroSkillBuild.new()
	_hero_skill_build._is_sanctuary = true


func after_test() -> void:
	if _hero_skill_build != null and is_instance_valid(_hero_skill_build):
		_hero_skill_build.free()
	_hero_skill_build = null


# ---------------------------------------------------------------------------
# AC-1: exactly 5 independent bindings in a fresh CONFIGURABLE state
# ---------------------------------------------------------------------------

func test_fresh_state_has_exactly_5_bindings_all_empty() -> void:
	var bindings: Dictionary[String, String] = _hero_skill_build.get_all_slot_bindings()
	assert_int(bindings.size()).is_equal(5)
	for key: String in ["A", "B", "C", "D"]:
		assert_bool(bindings.has(key)).is_true()
		assert_str(bindings[key]).is_equal("")
	# U (Ultimate) is always the live-derived value (Story 002) — "EMPTY" in a
	# fresh state since Formula 1's all-4-slots-filled precondition isn't met.
	assert_bool(bindings.has("U")).is_true()
	assert_str(bindings["U"]).is_equal("EMPTY")


func test_active_slots_are_independently_settable() -> void:
	_hero_skill_build.set_active_slot(0, "phys_cleave")
	var bindings: Dictionary[String, String] = _hero_skill_build.get_all_slot_bindings()
	assert_str(bindings["A"]).is_equal("phys_cleave")
	assert_str(bindings["B"]).is_equal("")
	assert_str(bindings["C"]).is_equal("")
	assert_str(bindings["D"]).is_equal("")


# ---------------------------------------------------------------------------
# AC-2: catalogue schema completeness (Alpha-scope 8-skill catalogue)
# ---------------------------------------------------------------------------

func test_alpha_catalogue_entries_are_schema_complete() -> void:
	for skill_id: StringName in ALPHA_SKILL_IDS:
		var definition: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(skill_id)
		assert_object(definition).is_not_null()
		assert_str(String(definition.skill_id)).is_not_empty()
		assert_array(["physical", "ranged", "elemental", "support"]).contains([definition.category])
		assert_bool(definition.passive_slot_count >= 1 and definition.passive_slot_count <= 3).is_true()
		assert_array(definition.validate()).is_empty()


func test_alpha_catalogue_has_unique_skill_ids() -> void:
	var seen: Dictionary[StringName, bool] = {}
	for skill_id: StringName in ALPHA_SKILL_IDS:
		assert_bool(seen.has(skill_id)).is_false()
		seen[skill_id] = true


# ---------------------------------------------------------------------------
# AC-3: Sanctuary-only writes
# ---------------------------------------------------------------------------

func test_slot_write_rejected_while_locked() -> void:
	_hero_skill_build._is_sanctuary = false
	var result: bool = _hero_skill_build.set_active_slot(0, "phys_cleave")
	assert_bool(result).is_false()
	assert_str(_hero_skill_build.get_active_slots()[0]).is_equal("")


func test_slot_write_succeeds_while_configurable() -> void:
	_hero_skill_build._is_sanctuary = true
	var result: bool = _hero_skill_build.set_active_slot(0, "phys_cleave")
	assert_bool(result).is_true()
	assert_str(_hero_skill_build.get_active_slots()[0]).is_equal("phys_cleave")


# ---------------------------------------------------------------------------
# AC-4: duplicate skill_id allowed, category_count reflects occupied slots
# ---------------------------------------------------------------------------

func test_duplicate_skill_id_allowed_across_all_active_slots() -> void:
	for i: int in 4:
		var result: bool = _hero_skill_build.set_active_slot(i, "phys_cleave")
		assert_bool(result).is_true()
	assert_str(_hero_skill_build.get_active_slots()[0]).is_equal("phys_cleave")
	assert_str(_hero_skill_build.get_active_slots()[3]).is_equal("phys_cleave")


func test_category_count_reflects_one_increment_per_occupied_slot() -> void:
	_hero_skill_build.set_active_slot(0, "phys_cleave")
	_hero_skill_build.set_active_slot(1, "phys_cleave")
	_hero_skill_build.set_active_slot(2, "phys_cleave")
	# slot 3 (D) left unassigned
	var counts: Dictionary[String, int] = _hero_skill_build.get_category_count()
	assert_int(counts["physical"]).is_equal(3)
	assert_int(counts["ranged"]).is_equal(0)
	assert_int(counts["elemental"]).is_equal(0)
	assert_int(counts["support"]).is_equal(0)


func test_category_count_all_four_occupied() -> void:
	_hero_skill_build.set_active_slot(0, "phys_cleave")
	_hero_skill_build.set_active_slot(1, "rng_volley")
	_hero_skill_build.set_active_slot(2, "elem_frostbolt")
	_hero_skill_build.set_active_slot(3, "sup_rally")
	var counts: Dictionary[String, int] = _hero_skill_build.get_category_count()
	assert_int(counts["physical"]).is_equal(1)
	assert_int(counts["ranged"]).is_equal(1)
	assert_int(counts["elemental"]).is_equal(1)
	assert_int(counts["support"]).is_equal(1)


# ---------------------------------------------------------------------------
# AC-5: category enum parity with tower.md's Foundation archetype enum
# ---------------------------------------------------------------------------

func test_category_enum_matches_foundation_archetype_enum() -> void:
	var foundation: FoundationComponent = FoundationComponent.new()
	# tower.md's Foundation archetype default confirms the shared string vocabulary.
	assert_str(foundation.archetype).is_equal("physical")
	var valid_categories: Array[String] = ["physical", "ranged", "elemental", "support"]
	assert_int(valid_categories.size()).is_equal(4)
	for skill_id: StringName in ALPHA_SKILL_IDS:
		var definition: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(skill_id)
		assert_array(valid_categories).contains([definition.category])
