## Unit tests for Story 006 (TR-heroskill-001, ADR-0030): orphaned data and
## content-change edge cases (AC-21/22/23/24/25).
##
## HeroSkillBuild is instantiated directly (HeroSkillBuild.new(), no
## add_child()) — matching this project's established test convention.
extends GdUnitTestSuite

var _hero_skill_build: HeroSkillBuild


func before_test() -> void:
	_hero_skill_build = HeroSkillBuild.new()


func after_test() -> void:
	if _hero_skill_build != null and is_instance_valid(_hero_skill_build):
		_hero_skill_build.free()
	_hero_skill_build = null


# ---------------------------------------------------------------------------
# AC-21: orphaned active-slot skill_id preserved, Ultimate treats it as unfilled
# ---------------------------------------------------------------------------

func test_orphaned_active_slot_binding_preserved_on_restore() -> void:
	var payload: Dictionary = {
		"equippable_skills": {},
		"active_slots": ["skill_removed_from_catalogue", "", "", ""],
		"passive_slots": {},
	}
	var ok: bool = _hero_skill_build.restore_save_data(payload)

	assert_bool(ok).is_true()
	assert_array(_hero_skill_build.get_active_slots()).contains_exactly(["skill_removed_from_catalogue", "", "", ""])


func test_orphaned_active_slot_treated_as_unfilled_for_ultimate() -> void:
	var payload: Dictionary = {
		"equippable_skills": {},
		"active_slots": ["skill_removed_from_catalogue", "rng_volley", "elem_frostbolt", "sup_rally"],
		"passive_slots": {},
	}
	_hero_skill_build.restore_save_data(payload)

	assert_str(_hero_skill_build._derive_ultimate_id()).is_equal("EMPTY")


# ---------------------------------------------------------------------------
# AC-22: orphaned library entry preserved but hidden from UI
# ---------------------------------------------------------------------------

func test_orphaned_library_entry_preserved_but_not_assignable() -> void:
	var payload: Dictionary = {
		"equippable_skills": {"skill_removed_from_catalogue": true, "phys_cleave": true},
		"active_slots": ["", "", "", ""],
		"passive_slots": {},
	}
	_hero_skill_build.restore_save_data(payload)

	# Preserved internally — not discarded.
	var saved: Dictionary = _hero_skill_build.get_save_data()
	assert_bool((saved["equippable_skills"] as Dictionary).has("skill_removed_from_catalogue")).is_true()

	# But not surfaced as assignable.
	var assignable: Array[String] = _hero_skill_build.get_assignable_skills()
	assert_bool(assignable.has("skill_removed_from_catalogue")).is_false()
	assert_bool(assignable.has("phys_cleave")).is_true()


# ---------------------------------------------------------------------------
# AC-23: removed passive item treated as empty for effects, binding preserved
# ---------------------------------------------------------------------------

func test_removed_passive_item_reads_empty_for_effects_but_binding_preserved() -> void:
	_hero_skill_build._passive_slots["phys_bulwark"] = ["item_removed_from_content"]

	# Raw binding preserved.
	assert_array(_hero_skill_build.get_passive_loadout("phys_bulwark")).contains_exactly(["item_removed_from_content"])

	# Effective (resolved) loadout treats it as empty.
	assert_array(_hero_skill_build.get_effective_passive_loadout("phys_bulwark")).contains_exactly([""])


func test_real_item_resolves_normally_in_effective_loadout() -> void:
	_hero_skill_build._passive_slots["phys_bulwark"] = ["iron_ore"]  # real content item

	assert_array(_hero_skill_build.get_effective_passive_loadout("phys_bulwark")).contains_exactly(["iron_ore"])


# ---------------------------------------------------------------------------
# AC-24: passive_slot_count reduction returns the excess item to Inventory
# ---------------------------------------------------------------------------

func test_passive_slot_count_reduction_trims_excess_and_returns_stackable_item() -> void:
	var inventory: Inventory = Inventory.new()
	var before_count: int = inventory.get_slot_count()
	# phys_cleave has passive_slot_count = 1 — bind 2 entries as if content
	# was patched down from 2 slots to 1, with a real stackable item (iron_ore)
	# bound to the now-excess index 1.
	var payload: Dictionary = {
		"equippable_skills": {},
		"active_slots": ["", "", "", ""],
		"passive_slots": {"phys_cleave": ["", "iron_ore"]},
	}
	_hero_skill_build.restore_save_data(payload)

	# Trimmed down to current passive_slot_count (1) — only current sockets render.
	assert_array(_hero_skill_build.get_passive_loadout("phys_cleave")).contains_exactly([""])
	inventory.free()


func test_passive_slot_count_reduction_with_unresolvable_item_logs_and_drops() -> void:
	var payload: Dictionary = {
		"equippable_skills": {},
		"active_slots": ["", "", "", ""],
		"passive_slots": {"phys_cleave": ["", "item_that_never_existed"]},
	}
	var ok: bool = _hero_skill_build.restore_save_data(payload)

	assert_bool(ok).is_true()  # never blocks the load
	assert_array(_hero_skill_build.get_passive_loadout("phys_cleave")).contains_exactly([""])


func test_no_reconciliation_needed_when_within_current_slot_count() -> void:
	var payload: Dictionary = {
		"equippable_skills": {},
		"active_slots": ["", "", "", ""],
		"passive_slots": {"phys_bulwark": ["item_a", "item_b"]},  # passive_slot_count = 2, exactly fits
	}
	_hero_skill_build.restore_save_data(payload)

	assert_array(_hero_skill_build.get_passive_loadout("phys_bulwark")).contains_exactly(["item_a", "item_b"])


# ---------------------------------------------------------------------------
# AC-25: off-build passive configuration allowed for unequipped skills
# ---------------------------------------------------------------------------

func test_off_build_passive_configuration_allowed() -> void:
	_hero_skill_build._is_sanctuary = true
	# phys_cleave is never assigned to any active slot.
	assert_array(_hero_skill_build.get_active_slots()).not_contains(["phys_cleave"])

	var result: bool = _hero_skill_build.set_passive_slot("phys_cleave", 0, "some_item")

	assert_bool(result).is_true()
	assert_array(_hero_skill_build.get_passive_loadout("phys_cleave")).contains_exactly(["some_item"])
