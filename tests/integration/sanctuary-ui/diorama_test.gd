## Integration tests for the Diorama (epic-10-sanctuary-ui Story 013, GDD Core
## Rule 1 + Visual/Audio Requirements): fixed-position structure rendering,
## habitat occupancy readout, and the DEPARTING pull-back beat.
##
## Real gap closed 2026-07-25: the Diorama node was Story 001's placeholder,
## empty Control for this entire epic. ComfyUI-based art generation was
## attempted first (see diorama.gd's own doc comment for the CUDA/ZLUDA
## failure detail) and honestly fell back to plain ColorRect placeholders,
## matching this project's established "no art exists" convention.
##
## Updated 2026-07-31: "watchtower" now has real art (a user-provided,
## color-keyed reference image) and renders as a TextureRect instead.
##
## Updated 2026-08-01: "habitat_expansion" also has real art now -- 3
## tier-specific sprites (see diorama.gd's HABITAT_TEXTURES doc comment),
## with the diorama swapping the TextureRect's texture in place as the
## player upgrades. No structure_type uses a ColorRect placeholder anymore.
extends GdUnitTestSuite

const SanctuaryUiScene: PackedScene = preload("res://src/presentation/sanctuary_ui/SanctuaryUI.tscn")

var _shell: SanctuaryUI
var _menagerie: Menagerie


func before_test() -> void:
	_menagerie = Menagerie.new()
	_shell = SanctuaryUiScene.instantiate()
	add_child(_shell)
	_shell.get_diorama().set("menagerie", _menagerie)


func after_test() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.queue_free()
	_shell = null
	if _menagerie != null and is_instance_valid(_menagerie):
		_menagerie.free()
	_menagerie = null


# ---------------------------------------------------------------------------
# Fixed-position structure rendering (Core Rule 1)
# ---------------------------------------------------------------------------

func test_no_structures_rendered_at_fresh_mount() -> void:
	var diorama: Control = _shell.get_diorama()
	assert_array(diorama.call("get_rendered_structure_types")).is_empty()


func test_sanctuary_structure_built_renders_a_structure_at_its_fixed_position() -> void:
	GEventBus.sanctuary_structure_built.emit("watchtower_tier_1", "watchtower")

	var diorama: Control = _shell.get_diorama()
	var rendered: Array = diorama.call("get_rendered_structure_types")
	assert_array(rendered).contains(["watchtower"])


func test_a_later_tier_of_the_same_structure_type_does_not_duplicate_the_visual() -> void:
	GEventBus.sanctuary_structure_built.emit("habitat_expansion_tier_1", "habitat_expansion")
	GEventBus.sanctuary_structure_built.emit("habitat_expansion_tier_2", "habitat_expansion")

	var diorama: Control = _shell.get_diorama()
	var rendered: Array = diorama.call("get_rendered_structure_types")
	assert_int(rendered.size()).is_equal(1)


func test_unmapped_structure_type_renders_nothing_and_does_not_error() -> void:
	GEventBus.sanctuary_structure_built.emit("some_future_structure", "unknown_type")

	var diorama: Control = _shell.get_diorama()
	assert_array(diorama.call("get_rendered_structure_types")).is_empty()


## Real art landed 2026-07-31 (color-keyed from a user-provided reference
## image, see diorama.gd's WATCHTOWER_TEXTURE doc comment) -- watchtower is
## now a real TextureRect, not a ColorRect placeholder. habitat_expansion's
## own tier-swap art is covered separately below.
func test_watchtower_renders_as_a_textured_sprite_not_a_placeholder_rect() -> void:
	GEventBus.sanctuary_structure_built.emit("watchtower_tier_1", "watchtower")

	var diorama: Control = _shell.get_diorama()
	var rendered_nodes: Dictionary = diorama.get("_rendered_structure_types") as Dictionary
	var watchtower_visual: Control = rendered_nodes.get("watchtower") as Control

	assert_object(watchtower_visual).is_not_null()
	assert_bool(watchtower_visual is TextureRect).is_true()
	var tex_rect: TextureRect = watchtower_visual as TextureRect
	assert_object(tex_rect.texture).is_not_null()


## Regression test for a real bug found live via Godot MCP while verifying
## Tier 4 (2026-08-03): TextureRect's default expand_mode (EXPAND_KEEP_SIZE)
## silently clamped the manually-computed `.size = display_size` assignment
## back to the texture's own native pixel dimensions on the same frame --
## every structure had been rendering at full native art-generation
## resolution (900-1200px+ source art) instead of the intended
## HABITAT_DISPLAY_HEIGHT/WATCHTOWER_DISPLAY_HEIGHT=64 scaled size the whole
## time. Fixed with expand_mode=EXPAND_IGNORE_SIZE on both sprite builders.
func test_watchtower_and_habitat_sprites_scale_to_64_height_not_native_texture_size() -> void:
	GEventBus.sanctuary_structure_built.emit("watchtower_tier_1", "watchtower")
	GEventBus.sanctuary_structure_built.emit("habitat_expansion_tier_1", "habitat_expansion")

	var diorama: Control = _shell.get_diorama()
	var rendered_nodes: Dictionary = diorama.get("_rendered_structure_types") as Dictionary
	var watchtower_visual: TextureRect = rendered_nodes.get("watchtower") as TextureRect
	var habitat_visual: TextureRect = rendered_nodes.get("habitat_expansion") as TextureRect

	assert_float(watchtower_visual.size.y).is_equal(64.0)
	assert_bool(watchtower_visual.size.x < watchtower_visual.texture.get_width()).is_true()
	assert_float(habitat_visual.size.y).is_equal(64.0)
	assert_bool(habitat_visual.size.x < habitat_visual.texture.get_width()).is_true()


## habitat_expansion has 3 real tiers (unlike watchtower's 1) -- see
## design/quick-specs/habitat-expansion-tiered-art-2026-08-01.md. Building
## tier_1 creates one real TextureRect with tier_1's texture.
func test_habitat_expansion_tier_1_renders_as_a_textured_sprite() -> void:
	GEventBus.sanctuary_structure_built.emit("habitat_expansion_tier_1", "habitat_expansion")

	var diorama: Control = _shell.get_diorama()
	var rendered_nodes: Dictionary = diorama.get("_rendered_structure_types") as Dictionary
	var habitat_visual: Control = rendered_nodes.get("habitat_expansion") as Control

	assert_object(habitat_visual).is_not_null()
	assert_bool(habitat_visual is TextureRect).is_true()
	var tex_rect: TextureRect = habitat_visual as TextureRect
	assert_object(tex_rect.texture).is_not_null()
	assert_str(String(tex_rect.texture.resource_path)).contains("habitat_tier_1")


## Building a later tier swaps the SAME node's texture rather than creating
## a second one -- the real load-bearing behavior this quick spec added.
func test_habitat_expansion_tier_upgrade_swaps_texture_on_the_same_node() -> void:
	GEventBus.sanctuary_structure_built.emit("habitat_expansion_tier_1", "habitat_expansion")
	var diorama: Control = _shell.get_diorama()
	var rendered_nodes: Dictionary = diorama.get("_rendered_structure_types") as Dictionary
	var tier_1_visual: Control = rendered_nodes.get("habitat_expansion") as Control

	GEventBus.sanctuary_structure_built.emit("habitat_expansion_tier_2", "habitat_expansion")
	var tier_2_visual: Control = rendered_nodes.get("habitat_expansion") as Control

	assert_object(tier_2_visual).is_same(tier_1_visual)  # same node, not a new one
	var tex_rect: TextureRect = tier_2_visual as TextureRect
	assert_str(String(tex_rect.texture.resource_path)).contains("habitat_tier_2")
	assert_int(diorama.call("get_rendered_structure_types").size()).is_equal(1)


## 2026-08-03: habitat_expansion_tier_4 added (real content, closing the
## "4th building unused" gap) -- continues the same tier-swap-in-place path
## through to the new highest tier, same node throughout.
func test_habitat_expansion_tier_4_swaps_texture_on_the_same_node() -> void:
	GEventBus.sanctuary_structure_built.emit("habitat_expansion_tier_1", "habitat_expansion")
	var diorama: Control = _shell.get_diorama()
	var rendered_nodes: Dictionary = diorama.get("_rendered_structure_types") as Dictionary
	var tier_1_visual: Control = rendered_nodes.get("habitat_expansion") as Control

	GEventBus.sanctuary_structure_built.emit("habitat_expansion_tier_2", "habitat_expansion")
	GEventBus.sanctuary_structure_built.emit("habitat_expansion_tier_3", "habitat_expansion")
	GEventBus.sanctuary_structure_built.emit("habitat_expansion_tier_4", "habitat_expansion")
	var tier_4_visual: Control = rendered_nodes.get("habitat_expansion") as Control

	assert_object(tier_4_visual).is_same(tier_1_visual)  # still the same node
	var tex_rect: TextureRect = tier_4_visual as TextureRect
	assert_str(String(tex_rect.texture.resource_path)).contains("habitat_tier_4")
	assert_int(diorama.call("get_rendered_structure_types").size()).is_equal(1)


func test_diorama_still_renders_a_structure_while_a_room_is_active() -> void:
	# Core Rule 1: the diorama "keeps running... even while occluded by a room."
	_shell.set_active_state(&"ROOM_INVENTORY_CRAFTING")

	GEventBus.sanctuary_structure_built.emit("watchtower_tier_1", "watchtower")

	var diorama: Control = _shell.get_diorama()
	assert_array(diorama.call("get_rendered_structure_types")).contains(["watchtower"])


# ---------------------------------------------------------------------------
# Habitat occupancy readout (Core Rule 1: "habitat occupancy")
# ---------------------------------------------------------------------------

func test_habitat_label_appears_once_habitat_expansion_is_built() -> void:
	GEventBus.sanctuary_structure_built.emit("habitat_expansion_tier_1", "habitat_expansion")

	var diorama: Control = _shell.get_diorama()
	assert_str(diorama.call("get_habitat_label_text")).contains("0")


func test_habitat_label_reflects_a_real_creature_lured_directly_into_habitat() -> void:
	GEventBus.sanctuary_structure_built.emit("habitat_expansion_tier_1", "habitat_expansion")
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"menagerie_lure")
	GInventory.add_stackable(def, 9)

	_menagerie.lure_creature(&"glimmer_hare")  # habitat has an open slot (default capacity 4) -> lands in HABITAT

	var diorama: Control = _shell.get_diorama()
	assert_str(diorama.call("get_habitat_label_text")).is_equal("Habitat: 1")
	GInventory.reset_to_defaults()


# ---------------------------------------------------------------------------
# DEPARTING pull-back beat (Visual/Audio Requirements, Tuning Knobs 60/40 split)
# ---------------------------------------------------------------------------

func test_departing_triggers_the_diorama_pull_back_without_erroring() -> void:
	_shell.confirm_launch_depart()
	assert_that(_shell.get_active_state()).is_equal(&"DEPARTING")
	# The pull-back tween itself is cosmetic and covered by code review, not a
	# runtime assertion (matches the GDD's own explicit exclusion of
	# Visual/Audio Requirements from black-box assertions) -- this test only
	# confirms triggering it doesn't error and DEPARTING still activates.


# ---------------------------------------------------------------------------
# Cast-shadow layer (art bible Principle 1, GDD's "full stacked-sprite/
# cast-shadow treatment" requirement) -- added 2026-08-13.
# ---------------------------------------------------------------------------

func test_building_a_structure_adds_a_shadow_layer_beneath_it() -> void:
	GEventBus.sanctuary_structure_built.emit("watchtower_tier_1", "watchtower")

	var world: Node2D = _shell.get_diorama().call("get_world")
	var shadow: Node = world.get_node_or_null("Shadow_watchtower")
	var sprite: Node = world.get_node_or_null("Structure_watchtower")

	assert_object(shadow).is_not_null()
	assert_object(sprite).is_not_null()
	# 2D tree-order compositing: the shadow must be an earlier sibling than
	# the sprite so it draws underneath, not on top.
	assert_int(shadow.get_index()).is_less(sprite.get_index())


func test_shadow_layer_uses_a_unique_name_per_structure_type() -> void:
	GEventBus.sanctuary_structure_built.emit("watchtower_tier_1", "watchtower")
	GEventBus.sanctuary_structure_built.emit("habitat_expansion_tier_1", "habitat_expansion")

	var world: Node2D = _shell.get_diorama().call("get_world")
	# Real gap found live via Godot MCP (2026-08-13): Godot renames a second
	# same-named Control sibling to an anonymous "@Control@N" rather than the
	# expected "Shadow2" -- giving each shadow a structure-type-qualified
	# name avoids this entirely.
	assert_object(world.get_node_or_null("Shadow_watchtower")).is_not_null()
	assert_object(world.get_node_or_null("Shadow_habitat_expansion")).is_not_null()


func test_shadow_is_sized_proportional_to_its_structure_sprite() -> void:
	GEventBus.sanctuary_structure_built.emit("watchtower_tier_1", "watchtower")

	var world: Node2D = _shell.get_diorama().call("get_world")
	var shadow: Control = world.get_node("Shadow_watchtower") as Control
	var sprite: Control = world.get_node("Structure_watchtower") as Control

	# _build_shadow_for(): ellipse_size = sprite_display_size * (0.7, 0.18)
	assert_float(shadow.size.x).is_equal_approx(sprite.size.x * 0.7, 0.01)
	assert_float(shadow.size.y).is_equal_approx(sprite.size.y * 0.18, 0.01)
