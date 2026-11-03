## Ascension rewards wired through the real systems
## (design/quick-specs/ascension-rewards-2026-11-03.md): shard awards on a
## recorded clear, the Forge's extra rune slot, Ascension Tarot unlocks, the
## outcome screen's lines and the medallion rim. GInventory and
## GMissionSelect are the real Autoloads, reset around every test.
extends GdUnitTestSuite

var _forge: EquipmentForge
var _mission_select: MissionSelect
var _spy: EventBusSpy


func before_test() -> void:
	GInventory.reset_to_defaults()
	GMissionSelect.reset_to_defaults()
	_forge = EquipmentForge.new()
	_mission_select = MissionSelect.new()
	_mission_select._restore_completed = true
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.materials_earned)
	_spy.watch(GEventBus.ascension_shards_awarded)
	_spy.watch(GEventBus.item_rune_slot_added)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	for node: Object in [_forge, _mission_select]:
		if node != null and is_instance_valid(node):
			node.free()
	_forge = null
	_mission_select = null
	GInventory.reset_to_defaults()
	GMissionSelect.reset_to_defaults()


func _shards() -> int:
	return GInventory.count_by_material_id(AscensionRewards.SHARD_ITEM_ID)


func _give_shards(amount: int) -> void:
	GInventory.add_stackable(GGameDataRegistry.get_item_definition(AscensionRewards.SHARD_ITEM_ID), amount)


## A recorded win at `tier` on The Gap, as MISSION_COMPLETE records it.
func _win(tier: int) -> void:
	_mission_select._runtime_mission_id = "the_gap"
	_mission_select._runtime_difficulty_tier = tier
	_mission_select._runtime_launch_timestamp = Time.get_unix_time_from_system() - 100.0
	_mission_select._record_runtime_completion()


## Crafts iron_sword (weapon, base 2 rune slots) and returns its instance_id.
func _craft_iron_sword() -> int:
	_forge._equipment_discovery_ledger[&"recipe_iron_sword"] = true
	GInventory.add_stackable(GGameDataRegistry.get_item_definition(&"common_scrap"), GGameDataRegistry.get_equipment_recipe(&"recipe_iron_sword").inputs[&"Material"] as int)
	_forge.resolve_craft(&"recipe_iron_sword")
	return GInventory.get_slot_contents(0)["instance_id"] as int


# --- Shards on a recorded clear ----------------------------------------------

func test_ascension_first_clear_pays_bounty_then_repeat_pays_run_reward() -> void:
	_win(5)  # Ascension 2, first time
	assert_int(_shards()).is_equal(24)
	var args: Array = (_spy.emissions["ascension_shards_awarded"] as Array)[0] as Array
	assert_int(args[0] as int).is_equal(24)
	assert_bool(args[1] as bool).is_true()

	_win(5)  # same rank again
	assert_int(_shards()).is_equal(28)
	args = (_spy.emissions["ascension_shards_awarded"] as Array)[1] as Array
	assert_bool(args[1] as bool).is_false()


## Found live 2026-11-03: a real save with a full bag silently lost the
## first-clear bounty. Shards that don't fit are held, saved and delivered later.
func test_ascension_full_bag_holds_shards_then_delivers_them() -> void:
	var hide: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"goblin_hide")
	GInventory.add_stackable(hide, GInventory.stackable_room(hide))
	assert_int(GInventory.stackable_room(GGameDataRegistry.get_item_definition(AscensionRewards.SHARD_ITEM_ID))).is_equal(0)
	_spy.watch(GEventBus.item_pickup_rejected)

	_win(5)  # Ascension 2 first clear: 24

	assert_int(_shards()).is_equal(0)
	assert_int(_mission_select.get_held_shards()).is_equal(24)
	assert_bool(_spy.was_emitted("item_pickup_rejected")).is_false()  # no "bag full" toast/sound
	assert_int(_mission_select.get_save_data()["held_shards"] as int).is_equal(24)

	GInventory.consume_stackable(hide, 99)
	_mission_select.deliver_held_shards()

	assert_int(_shards()).is_equal(24)
	assert_int(_mission_select.get_held_shards()).is_equal(0)


func test_ascension_held_shards_survive_save_round_trip() -> void:
	_mission_select._held_shards = 17
	var restored := MissionSelect.new()
	assert_bool(restored.restore_save_data(_mission_select.get_save_data())).is_true()
	assert_int(restored.get_held_shards()).is_equal(17)
	# Older saves have no field: nothing held.
	assert_bool(restored.restore_save_data({"completion_ledger": {}})).is_true()
	assert_int(restored.get_held_shards()).is_equal(0)
	restored.free()


func test_ascension_brutal_win_pays_no_shards() -> void:
	_win(3)
	assert_int(_shards()).is_equal(0)
	assert_bool(_spy.was_emitted("ascension_shards_awarded")).is_false()


func test_ascension_highest_rank_reads_across_maps() -> void:
	assert_int(_mission_select.get_highest_ascension_rank()).is_equal(0)
	_mission_select.record_completion("the_gap", 3, 100.0)
	_mission_select.record_completion("the_foothills", 7, 100.0)
	assert_int(_mission_select.get_highest_ascension_rank()).is_equal(4)


# --- Extra rune slot -----------------------------------------------------------

func test_ascension_add_rune_slot_spends_shards_and_adds_a_slot() -> void:
	var sword: int = _craft_iron_sword()
	_give_shards(40)

	assert_bool(_forge.resolve_add_rune_slot(sword)).is_true()

	assert_int(GInventory.get_slot_contents_by_instance_id(sword)["rune_slot_count"] as int).is_equal(3)
	assert_int(_shards()).is_equal(0)
	assert_int(_forge.extra_rune_slots(sword)).is_equal(1)
	assert_int(_forge.add_rune_slot_cost(sword)).is_equal(120)
	assert_int(_spy.count("item_rune_slot_added")).is_equal(1)


func test_ascension_add_rune_slot_short_of_shards_spends_nothing() -> void:
	var sword: int = _craft_iron_sword()
	_give_shards(39)

	assert_bool(_forge.resolve_add_rune_slot(sword)).is_false()

	assert_int(GInventory.get_slot_contents_by_instance_id(sword)["rune_slot_count"] as int).is_equal(2)
	assert_int(_shards()).is_equal(39)


func test_ascension_add_rune_slot_stops_at_the_cap() -> void:
	var sword: int = _craft_iron_sword()
	_give_shards(40 + 120 + 500)
	assert_bool(_forge.resolve_add_rune_slot(sword)).is_true()
	assert_bool(_forge.resolve_add_rune_slot(sword)).is_true()

	assert_int(_forge.add_rune_slot_cost(sword)).is_equal(-1)
	assert_bool(_forge.resolve_add_rune_slot(sword)).is_false()
	assert_int(GInventory.get_slot_contents_by_instance_id(sword)["rune_slot_count"] as int).is_equal(4)
	assert_int(_shards()).is_equal(500)


func test_ascension_add_rune_slot_rejects_unknown_item() -> void:
	_give_shards(40)
	assert_bool(_forge.resolve_add_rune_slot(987654)).is_false()
	assert_int(_shards()).is_equal(40)


# --- Tarot -----------------------------------------------------------------------

func test_ascension_tarot_card_unlocks_at_its_rank() -> void:
	GMissionSelect.record_completion("the_gap", 5, 100.0)  # Ascension 2
	assert_bool(GTarot.is_card_unlocked(&"dawnbreaker")).is_false()

	GMissionSelect.record_completion("the_gap", 6, 100.0)  # Ascension 3
	assert_bool(GTarot.is_card_unlocked(&"dawnbreaker")).is_true()
	assert_bool(GTarot.is_card_unlocked(&"final_judgement")).is_false()


func test_ascension_tarot_locked_tag_names_the_rank() -> void:
	var tarot_screen: GDScript = load("res://src/gameplay/ui/tarot_screen/tarot_screen.gd")  # no class_name by design
	assert_str(tarot_screen.call("locked_tag", &"final_judgement")).is_equal(tr("TAROT_TAG_LOCKED_ASCENSION") % 6)
	assert_str(tarot_screen.call("locked_tag", &"grinding_gauntlet")).is_empty()  # caller shows the plain "(Locked)"


func test_ascension_outcome_lists_newly_unlocked_tarot_cards() -> void:
	GMissionSelect.record_completion("the_gap", 9, 100.0)  # Ascension 6

	var lines: PackedStringArray = MissionOutcomeScreen.tarot_unlock_lines_since(2)

	assert_int(lines.size()).is_equal(2)
	assert_str(lines[0]).is_equal(tr("OUTCOME_UNLOCKED_TAROT") % "Dawnbreaker")
	assert_str(lines[1]).is_equal(tr("OUTCOME_UNLOCKED_TAROT") % "Final Judgement")
	assert_int(MissionOutcomeScreen.tarot_unlock_lines_since(6).size()).is_equal(0)


# --- Medallion rim ----------------------------------------------------------------

func test_ascension_rim_level_zero_keeps_the_original_icon() -> void:
	var icon: Texture2D = GGameDataRegistry.get_mission_entry("the_gap").icon
	assert_object(MedallionRim.apply(icon, 0)).is_same(icon)


func test_ascension_rim_is_drawn_on_the_medallion_edge() -> void:
	var icon: Texture2D = GGameDataRegistry.get_mission_entry("the_gap").icon
	var rimmed: Texture2D = MedallionRim.apply(icon, 3)

	assert_object(rimmed).is_not_same(icon)
	assert_vector(Vector2(rimmed.get_size())).is_equal(Vector2(icon.get_size()))
	var before: Image = MedallionRim._rgba(icon.get_image())
	var after: Image = rimmed.get_image()
	var used: Rect2i = before.get_used_rect()
	# Left edge of the medallion, half way down: inside the rim band.
	var probe := Vector2i(used.position.x + int(used.size.x * 0.03), used.position.y + used.size.y / 2)
	assert_bool(after.get_pixelv(probe).is_equal_approx(before.get_pixelv(probe))).is_false()
	# Same rank twice -> the cached texture.
	assert_object(MedallionRim.apply(icon, 3)).is_same(rimmed)
