## Unit tests for Story 002 (TR-craft-002, ADR-0023): the 3-trigger recipe
## discovery state machine — boot/restore-time sweep (AC-1), tech-gate
## blocking until tech_unlocked fires (AC-2), and the item_added trigger
## (AC-11).
##
## Exercises the real, authored res://assets/data/recipes/ and
## res://assets/data/items/ content via the GGameDataRegistry Autoload — no
## fixture injection, same rationale as every other GameDataRegistry-backed
## test. Crafting is instantiated directly (Crafting.new(), no add_child())
## so _ready() never fires — GSavePersistence.register() is never called,
## avoiding pollution of the real Autoload's _registered_systems list.
## GInventory and GDefenseBuilding ARE the real global Autoloads (Crafting
## calls them directly per ADR-0020 Criterion A/B) — reset in
## before_test()/after_test() to avoid leaking state into other test files.
extends GdUnitTestSuite

const RECIPE_IRON_FOUNDATION: StringName = &"recipe_iron_foundation"      # ungated, needs 5 Material
const RECIPE_HEALING_SALVE: StringName = &"recipe_healing_salve"          # ungated, needs 3 Material
const RECIPE_ADVANCED_COMPONENT: StringName = &"recipe_advanced_component"  # gated on tech_production_2, needs 2 Material
const TECH_PRODUCTION_2: StringName = &"tech_production_2"

var _crafting: Crafting
var _spy: EventBusSpy


func before_test() -> void:
	_crafting = Crafting.new()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.recipe_discovered)
	GInventory.reset_to_defaults()


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _crafting != null and is_instance_valid(_crafting):
		_crafting.free()
	_crafting = null
	GInventory.reset_to_defaults()


func _seed_material(quantity: int) -> void:
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"common_scrap")
	GInventory.add_stackable(def, quantity)


# ---------------------------------------------------------------------------
# AC-1: boot/restore-time sweep — a recipe whose gates are already both-true
# at session start fires recipe_discovered exactly once.
# ---------------------------------------------------------------------------

func test_boot_sweep_discovers_ungated_recipe_with_sufficient_materials() -> void:
	# Seed corrected 4->3 2026-08-26 (live gdUnit4 run + Godot MCP diagnostic):
	# recipe_hunters_draught.tres (ungated, {&"Material": 4}) was added at
	# some point after this test's original 4-material seed was chosen,
	# meaning 4 now ALSO newly satisfies it, breaking this test's "exactly
	# one recipe discovered" assumption — live-verified via run_script
	# against the real registry: seeding 3 discovers only healing_salve;
	# seeding 4 discovers healing_salve AND hunters_draught. 3 still clears
	# healing_salve's own threshold (3), so this test's actual intent is
	# unchanged.
	_seed_material(3)  # satisfies healing_salve (3) only, not hunters_draught (4) or iron_foundation (5)
	var ok: bool = _crafting.restore_save_data({})

	assert_bool(ok).is_true()
	assert_bool(_crafting.is_discovered(RECIPE_HEALING_SALVE)).is_true()
	assert_bool(_crafting.is_discovered(RECIPE_IRON_FOUNDATION)).is_false()
	assert_int(_spy.count("recipe_discovered")).is_equal(1)


func test_boot_sweep_does_not_rediscover_already_discovered_recipe() -> void:
	var already_discovered: Dictionary = {"discovery_ledger": {"recipe_healing_salve": true}}
	# Seeded quantity deliberately capped at 5 (not 10): common_scrap is both
	# item_type=Material AND rarity=Common (TD-craft-001 RESOLVED, S6-06b) —
	# recipe_healing_salve_bulk is ungated and rarity-keyed ({&"Common": 6}),
	# so 10 would ALSO newly satisfy it. 5 satisfies iron_foundation's
	# {&"Material": 5} but stays below healing_salve_bulk's 6-Common threshold.
	#
	# Corrected 2026-08-26 (live gdUnit4 run + Godot MCP diagnostic):
	# recipe_hunters_draught.tres (ungated, {&"Material": 4}) also sits
	# between healing_salve's 3 and iron_foundation's 5 — 5 was never a
	# clean "iron_foundation only" seed once that recipe existed. Live-
	# verified via run_script against the real registry: this exact scenario
	# (already-discovered healing_salve, 5 Material seeded) fires exactly 2
	# NEW recipe_discovered events, hunters_draught then iron_foundation (in
	# that order) — not 1. This test's real intent (healing_salve must not
	# re-fire; newly-qualifying recipes must) is preserved, just with the
	# now-accurate count and both real recipe ids asserted.
	_seed_material(5)
	_crafting.restore_save_data(already_discovered)

	assert_int(_spy.count("recipe_discovered")).is_equal(2)
	var emissions: Array = _spy.emissions["recipe_discovered"] as Array
	var discovered_ids: Array = []
	for emission: Array in emissions:
		discovered_ids.append(emission[0] as String)
	assert_bool(discovered_ids.has(String(&"recipe_hunters_draught"))).is_true()
	assert_bool(discovered_ids.has(String(RECIPE_IRON_FOUNDATION))).is_true()
	assert_bool(discovered_ids.has(String(RECIPE_HEALING_SALVE))).is_false()


func test_boot_sweep_does_not_discover_recipe_with_insufficient_materials() -> void:
	var ok: bool = _crafting.restore_save_data({})
	assert_bool(ok).is_true()
	assert_bool(_crafting.is_discovered(RECIPE_HEALING_SALVE)).is_false()
	assert_bool(_crafting.is_discovered(RECIPE_IRON_FOUNDATION)).is_false()
	assert_int(_spy.count("recipe_discovered")).is_equal(0)


func test_restore_save_data_rejects_malformed_payload() -> void:
	var ok: bool = _crafting.restore_save_data({"discovery_ledger": "not_a_dictionary"})
	assert_bool(ok).is_false()


# ---------------------------------------------------------------------------
# AC-2: a tech-gated recipe with sufficient materials does NOT discover via
# item_added alone — only once the matching tech_unlocked arrives.
# ---------------------------------------------------------------------------

func test_item_added_does_not_discover_tech_gated_recipe_before_tech_unlocked() -> void:
	# Calling _on_item_added() directly exercises the trigger's logic without
	# needing a live EventBus connection (no _ready()/add_child() involved).
	_seed_material(2)
	_crafting._on_item_added("common_scrap", "Material", 2)

	assert_bool(_crafting.is_discovered(RECIPE_ADVANCED_COMPONENT)).is_false()
	assert_int(_spy.count("recipe_discovered")).is_equal(0)


func test_tech_unlocked_discovers_recipe_once_materials_already_sufficient() -> void:
	_seed_material(2)
	_crafting._on_tech_unlocked(String(TECH_PRODUCTION_2), "production_tech")

	assert_bool(_crafting.is_discovered(RECIPE_ADVANCED_COMPONENT)).is_true()
	assert_int(_spy.count("recipe_discovered")).is_equal(1)


# ---------------------------------------------------------------------------
# AC-11: a tech-gate-satisfied, not-yet-discovered recipe discovers the
# moment item_added pushes materials past the threshold.
# ---------------------------------------------------------------------------

func test_item_added_discovers_tech_gate_satisfied_recipe_once_materials_sufficient() -> void:
	# _on_item_added() reads GDefenseBuilding directly (Criterion A) — this
	# test seeds the REAL Autoload's ledger directly, then cleans it up
	# immediately after, matching the project's established
	# reset-before/reset-after convention for real-Autoload-touching tests.
	GDefenseBuilding._tech_ledger[TECH_PRODUCTION_2] = true

	_seed_material(2)
	_crafting._on_item_added("common_scrap", "Material", 2)

	assert_bool(_crafting.is_discovered(RECIPE_ADVANCED_COMPONENT)).is_true()
	assert_int(_spy.count("recipe_discovered")).is_equal(1)

	GDefenseBuilding._tech_ledger.erase(TECH_PRODUCTION_2)


func test_item_added_fires_recipe_discovered_only_once_across_two_crossings() -> void:
	GDefenseBuilding._tech_ledger[TECH_PRODUCTION_2] = true
	_seed_material(2)
	_crafting._on_item_added("common_scrap", "Material", 2)
	_crafting._on_item_added("common_scrap", "Material", 1)  # second item_added, already discovered

	assert_int(_spy.count("recipe_discovered")).is_equal(1)
	GDefenseBuilding._tech_ledger.erase(TECH_PRODUCTION_2)
