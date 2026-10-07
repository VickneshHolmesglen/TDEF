## Hero equipment appearance (docs/superpowers/specs/2026-10-07-hero-
## equipment-appearance-design.md): equipped gear is layered on the hero in
## both hosts (mission Sprite2D, paperdoll TextureRect), removed on unequip,
## fitted overlays replace the icon fallback, and the sprite host mirrors.
extends GdUnitTestSuite

const HELM := &"brutes_war_helm"
const BOOTS := &"reinforced_boots"
const AMULET := &"bogpearl_amulet"
const SWORD := &"iron_sword"  ## no worn_texture yet: exercises the icon fallback


func before_test() -> void:
	GInventory.reset_to_defaults()


func after_test() -> void:
	GInventory.reset_to_defaults()


func _definition(id: StringName) -> ItemDefinitionResource:
	return GGameDataRegistry.get_item_definition(id)


func _sprite_host() -> Array:
	var host: Sprite2D = auto_free(Sprite2D.new())
	host.texture = PlaceholderTexture2D.new()
	var appearance := HeroAppearance.new()
	host.add_child(appearance)
	add_child(host)
	return [host, appearance]


func test_hero_appearance_equip_adds_layer_and_unequip_removes_it() -> void:
	var appearance: HeroAppearance = _sprite_host()[1]
	assert_object(appearance.get_layer("main_hand")).is_null()
	assert_bool(GInventory.equip_item("main_hand", _definition(SWORD))).is_true()
	var layer: Sprite2D = appearance.get_layer("main_hand")
	assert_object(layer).is_not_null()
	assert_object(layer.texture).is_same(_definition(SWORD).icon)
	assert_bool(appearance.is_fitted("main_hand")).is_false()
	assert_bool(GInventory.unequip_item("main_hand")).is_true()
	assert_object(appearance.get_layer("main_hand")).is_null()


func test_hero_appearance_icon_fallback_sits_on_the_slot_anchor() -> void:
	var appearance: HeroAppearance = _sprite_host()[1]
	GInventory.equip_item("main_hand", _definition(SWORD))
	var base_size := Vector2(appearance.config.base_texture.get_size())
	var expected: Vector2 = (appearance.config.icon_anchors["main_hand"] - Vector2(0.5, 0.5)) * base_size
	assert_vector(appearance.get_layer("main_hand").position).is_equal_approx(expected, Vector2(0.01, 0.01))
	var icon_height: float = appearance.get_layer("main_hand").scale.y * _definition(SWORD).icon.get_height()
	assert_float(icon_height).is_equal_approx(appearance.config.icon_heights["main_hand"] * base_size.y, 0.5)


func test_hero_appearance_fitted_overlay_replaces_the_icon() -> void:
	var definition := _definition(HELM)
	var original: Texture2D = definition.worn_texture
	var worn := ImageTexture.create_from_image(Image.create(512, 768, false, Image.FORMAT_RGBA8))
	definition.worn_texture = worn
	var appearance: HeroAppearance = _sprite_host()[1]
	GInventory.equip_item("helmet", definition)
	definition.worn_texture = original  # shared cached resource: restore before asserting
	var layer: Sprite2D = appearance.get_layer("helmet")
	assert_bool(appearance.is_fitted("helmet")).is_true()
	assert_object(layer.texture).is_same(worn)
	assert_vector(layer.position).is_equal(Vector2.ZERO)
	# Half-size overlay scaled up to the base canvas.
	var base_size := Vector2(appearance.config.base_texture.get_size())
	assert_vector(layer.scale).is_equal_approx(base_size / Vector2(512, 768), Vector2(0.001, 0.001))


func test_hero_appearance_neck_and_rings_never_show() -> void:
	var appearance: HeroAppearance = _sprite_host()[1]
	assert_bool(GInventory.equip_item("neck", _definition(AMULET))).is_true()
	assert_object(appearance.get_layer("neck")).is_null()
	assert_int(appearance.get_child_count()).is_equal(0)


func test_hero_appearance_layers_follow_the_configured_order() -> void:
	var appearance: HeroAppearance = _sprite_host()[1]
	GInventory.equip_item("helmet", _definition(HELM))
	GInventory.equip_item("boots", _definition(BOOTS))
	# Boots are behind the helmet (drawn first).
	assert_int(appearance.get_layer("boots").get_index()).is_less(appearance.get_layer("helmet").get_index())


func test_hero_appearance_already_equipped_gear_shows_on_creation() -> void:
	GInventory.equip_item("helmet", _definition(HELM))
	var appearance: HeroAppearance = _sprite_host()[1]
	assert_object(appearance.get_layer("helmet")).is_not_null()


func test_hero_appearance_sprite_host_gets_base_body_and_mirrors_with_it() -> void:
	var pair := _sprite_host()
	var host: Sprite2D = pair[0]
	var appearance: HeroAppearance = pair[1]
	assert_object(host.texture).is_same(appearance.config.base_texture)
	host.flip_h = true
	host.offset = Vector2(0, -12)
	appearance._process(0.016)
	assert_vector(appearance.scale).is_equal(Vector2(-1, 1))
	assert_vector(appearance.position).is_equal(Vector2(0, -12))
	host.flip_h = false
	appearance._process(0.016)
	assert_vector(appearance.scale).is_equal(Vector2.ONE)


func test_hero_appearance_gear_uses_the_host_material_for_hit_flash() -> void:
	var appearance: HeroAppearance = _sprite_host()[1]
	GInventory.equip_item("helmet", _definition(HELM))
	assert_bool(appearance.get_layer("helmet").use_parent_material).is_true()


func test_hero_appearance_rect_host_fits_keep_aspect_centred() -> void:
	var rect: TextureRect = auto_free(TextureRect.new())
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # as the paperdoll's portrait
	rect.size = Vector2(160, 320)
	var appearance := HeroAppearance.new()
	rect.add_child(appearance)
	add_child(rect)
	var base_size := Vector2(appearance.config.base_texture.get_size())
	var fit: float = minf(160.0 / base_size.x, 320.0 / base_size.y)
	assert_vector(appearance.position).is_equal(Vector2(80, 160))
	assert_vector(appearance.scale).is_equal_approx(Vector2(fit, fit), Vector2(0.0001, 0.0001))
	assert_object(rect.texture).is_same(appearance.config.base_texture)


func test_hero_scene_and_paperdoll_both_host_hero_appearance() -> void:
	var hero: Node = auto_free(load("res://src/core/hero/Hero.tscn").instantiate())
	assert_object(hero.get_node_or_null("Sprite2D/HeroAppearance")).is_not_null()
	var runner := scene_runner("res://src/gameplay/ui/inventory_screen/InventoryScreen.tscn")
	assert_object(runner.scene().find_child("HeroAppearance", true, false)).is_not_null()


func test_hero_appearance_config_validates() -> void:
	var config: HeroAppearanceResource = load(HeroAppearance.CONFIG_PATH)
	assert_array(config.validate()).is_empty()


func test_hero_appearance_shipped_helmets_use_fitted_overlays() -> void:
	# 2026-10-07: the 5 helmets have real worn art on the base-body canvas.
	var appearance: HeroAppearance = _sprite_host()[1]
	for id: StringName in [&"brutes_war_helm", &"goblin_fang_circlet", &"iron_helm", &"reinforced_helm", &"sentinel_visor"]:
		var definition := _definition(id)
		assert_object(definition.worn_texture).override_failure_message("%s has no worn_texture" % id).is_not_null()
		assert_vector(Vector2(definition.worn_texture.get_size())).is_equal(Vector2(appearance.config.base_texture.get_size()))
		GInventory.equip_item("helmet", definition)
		assert_bool(appearance.is_fitted("helmet")).is_true()
		GInventory.unequip_item("helmet")
