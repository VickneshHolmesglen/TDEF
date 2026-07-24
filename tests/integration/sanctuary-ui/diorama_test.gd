## Integration tests for the Diorama (epic-10-sanctuary-ui Story 013, GDD Core
## Rule 1 + Visual/Audio Requirements): fixed-position structure rendering,
## habitat occupancy readout, and the DEPARTING pull-back beat.
##
## Real gap closed 2026-07-25: the Diorama node was Story 001's placeholder,
## empty Control for this entire epic. ComfyUI-based art generation was
## attempted first (see diorama.gd's own doc comment for the CUDA/ZLUDA
## failure detail) and honestly fell back to plain ColorRect placeholders,
## matching this project's established "no art exists" convention.
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
