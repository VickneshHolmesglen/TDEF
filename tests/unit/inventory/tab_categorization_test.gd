## Unit tests for Inventory's tab categorization (Story 002, ADR-0016).
## Covers AC-7 (item_type -> fixed tab mapping) and its backing constant, TAB_ORDER
## (queried by AC-5's fixed-order requirement — the UI itself, Story 007, is out of
## scope here per this story's own boundaries).
##
## Inventory.get_tab_for_item_type() is a static, pure function — no Inventory
## instance is needed (no Inventory.new()/reset_to_defaults(), unlike
## slot_stack_model_test.gd, since this logic touches no instance state at all).
## No random seeds, no time dependence, no external I/O.
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# AC-5 backing: fixed tab order constant
# ---------------------------------------------------------------------------

func test_tab_order_has_exactly_four_entries_in_gdd_specified_order() -> void:
	assert_that(Inventory.TAB_ORDER).is_equal([
		&"Equipment", &"TowerComponent", &"Material", &"CraftedGood",
	])


# ---------------------------------------------------------------------------
# AC-7: item_type resolves to exactly one of the 4 fixed tabs
# ---------------------------------------------------------------------------

func test_get_tab_for_item_type_resolves_equipment() -> void:
	assert_that(Inventory.get_tab_for_item_type(&"Equipment")).is_equal(&"Equipment")


func test_get_tab_for_item_type_resolves_tower_component() -> void:
	assert_that(Inventory.get_tab_for_item_type(&"TowerComponent")).is_equal(&"TowerComponent")


func test_get_tab_for_item_type_resolves_material() -> void:
	assert_that(Inventory.get_tab_for_item_type(&"Material")).is_equal(&"Material")


func test_get_tab_for_item_type_resolves_crafted_good() -> void:
	assert_that(Inventory.get_tab_for_item_type(&"CraftedGood")).is_equal(&"CraftedGood")


## AC-7 edge case (QA Test Cases): an item_type outside the 4 known categories must
## not silently resolve to a tab. The primary guarantee for this is
## ItemDefinitionResource.validate() rejecting malformed item_type at load time
## (Story 001) — this assertion only confirms get_tab_for_item_type()'s own
## defense-in-depth backstop behaves consistently with that contract, it does not
## re-test validate() itself.
func test_get_tab_for_item_type_rejects_unknown_item_type() -> void:
	assert_that(Inventory.get_tab_for_item_type(&"NotARealCategory")).is_equal(&"")


## TD-inv-002: the "fail loudly" half of AC-7's edge case (push_error firing on
## rejection) was previously unasserted — only the &"" return value was
## checked. Uses gdUnit4's established assert_error(func...).is_push_error(...)
## combinator (precedent: game_data_registry_test.gd).
func test_get_tab_for_item_type_rejects_unknown_item_type_push_error_message() -> void:
	await assert_error(func() -> void: Inventory.get_tab_for_item_type(&"NotARealCategory")) \
		.is_push_error("[Inventory] get_tab_for_item_type: unknown item_type 'NotARealCategory' — not one of the 4 fixed tabs.")


## TD-inv-002: an empty StringName (&"", an uninitialized/default item_type)
## is a distinct case from "a wrong but non-empty string" and was not
## previously tested on its own.
func test_get_tab_for_item_type_rejects_empty_string_name() -> void:
	assert_that(Inventory.get_tab_for_item_type(&"")).is_equal(&"")
