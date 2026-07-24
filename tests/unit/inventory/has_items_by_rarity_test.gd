## Unit tests for Inventory.has_items_by_rarity()/consume_by_rarity()
## (TD-craft-001/TD-defbuild-002 resolution, Sprint 6 S6-06b, ADR-0021
## amendment). Mirrors has_items_test.gd's structure exactly, but sums by
## ItemDefinitionResource.rarity instead of item_type — a genuinely
## separate aggregation axis (Formula 1/3's recipe/tech/structure cost
## tables are authored "N of rarity tier X", not "N of a specific
## item_type").
##
## Exercises the real GGameDataRegistry Autoload content
## (res://assets/data/items/common_scrap.tres [rarity=Common],
## iron_ore.tres [rarity=Uncommon], menagerie_lure.tres [rarity="", never
## rarity-gated]) — the actual authored definitions, not synthetic fixtures.
extends GdUnitTestSuite

const COMMON_SCRAP: StringName = &"common_scrap"
const IRON_ORE: StringName = &"iron_ore"
const MENAGERIE_LURE: StringName = &"menagerie_lure"

var _inventory: Inventory


func before_test() -> void:
	_inventory = Inventory.new()
	_inventory.reset_to_defaults()


func after_test() -> void:
	if _inventory != null and is_instance_valid(_inventory):
		_inventory.free()
	_inventory = null


func _make_stackable_definition(item_id: StringName) -> ItemDefinitionResource:
	var def := ItemDefinitionResource.new()
	def.item_id = item_id
	def.item_type = &"Material"
	def.display_name = String(item_id)
	def.is_unique_instance = false
	return def


func test_has_items_by_rarity_empty_cost_returns_true_trivially() -> void:
	assert_bool(_inventory.has_items_by_rarity({})).is_true()


func test_has_items_by_rarity_sufficient_single_rarity_returns_true() -> void:
	_inventory.add_stackable(_make_stackable_definition(COMMON_SCRAP), 8)
	assert_bool(_inventory.has_items_by_rarity({&"Common": 8})).is_true()


func test_has_items_by_rarity_insufficient_single_rarity_returns_false() -> void:
	_inventory.add_stackable(_make_stackable_definition(COMMON_SCRAP), 4)
	assert_bool(_inventory.has_items_by_rarity({&"Common": 8})).is_false()


## Different rarities must not cross-count — this is the core distinction
## from has_items(): common_scrap (Common) and iron_ore (Uncommon) share
## item_type=Material but must NOT both satisfy a Common-only requirement.
func test_has_items_by_rarity_different_rarities_do_not_cross_count() -> void:
	_inventory.add_stackable(_make_stackable_definition(COMMON_SCRAP), 4)
	_inventory.add_stackable(_make_stackable_definition(IRON_ORE), 20)
	assert_bool(_inventory.has_items_by_rarity({&"Common": 8})).is_false()
	assert_bool(_inventory.has_items_by_rarity({&"Uncommon": 8})).is_true()


## An item whose rarity is "" (not rarity-gated, e.g. menagerie_lure) must
## never count toward any rarity requirement.
func test_has_items_by_rarity_ungated_item_never_counts() -> void:
	_inventory.add_stackable(_make_stackable_definition(MENAGERIE_LURE), 99)
	assert_bool(_inventory.has_items_by_rarity({&"Common": 1})).is_false()


func test_consume_by_rarity_deducts_correct_quantity() -> void:
	_inventory.add_stackable(_make_stackable_definition(COMMON_SCRAP), 20)
	var consumed: int = _inventory.consume_by_rarity("Common", 8, false)
	assert_int(consumed).is_equal(8)
	assert_bool(_inventory.has_items_by_rarity({&"Common": 13})).is_false()
	assert_bool(_inventory.has_items_by_rarity({&"Common": 12})).is_true()


func test_consume_by_rarity_never_touches_a_different_rarity() -> void:
	_inventory.add_stackable(_make_stackable_definition(COMMON_SCRAP), 10)
	_inventory.add_stackable(_make_stackable_definition(IRON_ORE), 10)
	_inventory.consume_by_rarity("Common", 10, false)
	assert_bool(_inventory.has_items_by_rarity({&"Uncommon": 10})).is_true()
