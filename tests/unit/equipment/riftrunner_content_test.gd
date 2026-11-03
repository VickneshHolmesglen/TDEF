extends GdUnitTestSuite

## Riftrunner set (2026-11-04, design/quick-specs/riftrunner-set-2026-11-04.md):
## every piece of the chain from new enemy to wearable set must survive
## GameDataRegistry validation. A rejected file only logs an error at boot, so
## this suite is what turns a bad value (drop rate, rune slots) into a failure.

const PIECES: Array[StringName] = [&"riftrunner_hood", &"riftrunner_coat", &"riftrunner_striders", &"drumskin_talisman"]


func test_riftrunner_monsters_point_at_their_own_drop_tables() -> void:
	assert_str(String(GGameDataRegistry.get_monster_resource(&"rift_hound").drop_table_id)).is_equal("hound_drops")
	assert_str(String(GGameDataRegistry.get_monster_resource(&"goblin_drummer").drop_table_id)).is_equal("drummer_drops")


func test_riftrunner_drop_tables_load_and_drop_the_new_materials() -> void:
	for pair: Array in [[&"hound_drops", &"rift_fang"], [&"drummer_drops", &"drum_hide"]]:
		var table: DropTableResource = GGameDataRegistry.get_drop_table(pair[0])
		assert_object(table).override_failure_message("%s rejected by the registry" % pair[0]).is_not_null()
		var materials: Array[StringName] = []
		for entry: DropEntry in table.entries:
			materials.append(entry.material_id)
		assert_array(materials).contains([pair[1]])
		assert_object(GGameDataRegistry.get_item_definition(pair[1])).is_not_null()


func test_riftrunner_every_piece_has_a_loaded_recipe_and_item() -> void:
	for piece: StringName in PIECES:
		var recipe: EquipmentRecipeResource = GGameDataRegistry.get_equipment_recipe(StringName("recipe_%s" % piece))
		assert_object(recipe).override_failure_message("recipe for %s rejected or missing" % piece).is_not_null()
		assert_str(String(recipe.output_item_id)).is_equal(String(piece))
		var item: ItemDefinitionResource = GGameDataRegistry.get_item_definition(piece)
		assert_object(item).is_not_null()
		assert_bool(ResourceLoader.exists(item.icon_path)).override_failure_message("%s icon" % piece).is_true()
		if item.worn_texture_path != "":
			assert_bool(ResourceLoader.exists(item.worn_texture_path)).override_failure_message("%s worn" % piece).is_true()
