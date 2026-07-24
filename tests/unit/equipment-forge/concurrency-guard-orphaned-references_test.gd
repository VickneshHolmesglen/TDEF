## Unit tests for Story 015 (TR-equipforge-001, ADR-0025): Concurrency Guard
## & Orphaned Rune References (AC-23-25).
##
## Exercises the real, authored res://assets/data/tarot/,
## res://assets/data/sacrifice_recipes/, and res://assets/data/equipment_recipes/
## content via GGameDataRegistry. EquipmentForge is instantiated directly
## (EquipmentForge.new(), no add_child()). GInventory/GMenagerie ARE the real
## global Autoloads, reset in before_test()/after_test() — matching this
## project's established equipment-forge test convention.
extends GdUnitTestSuite

var _forge: EquipmentForge
var _spy: EventBusSpy


func before_test() -> void:
	_forge = EquipmentForge.new()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_equipment_crafted)
	_spy.watch(GEventBus.item_rune_imbued)
	GInventory.reset_to_defaults()
	GMenagerie.reset_to_defaults()


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _forge != null and is_instance_valid(_forge):
		_forge.free()
	_forge = null
	GInventory.reset_to_defaults()
	GMenagerie.reset_to_defaults()


func _craft_iron_sword() -> int:
	_forge._equipment_discovery_ledger[&"recipe_iron_sword"] = true
	GInventory.add_stackable(GGameDataRegistry.get_item_definition(&"common_scrap"), 4)
	_forge.resolve_craft(&"recipe_iron_sword")
	return GInventory.get_slot_contents(0)["instance_id"] as int


# ---------------------------------------------------------------------------
# AC-23: shared _forge_resolving guard rejects a second same-frame
# confirmation, regardless of which two of the three operation types.
# ---------------------------------------------------------------------------

func test_resolve_craft_rejected_outright_while_forge_resolving_is_true() -> void:
	_forge._equipment_discovery_ledger[&"recipe_iron_sword"] = true
	GInventory.add_stackable(GGameDataRegistry.get_item_definition(&"common_scrap"), 4)
	_forge._forge_resolving = true  # simulate an in-flight resolution (same-type pair: craft+craft)

	var result: bool = _forge.resolve_craft(&"recipe_iron_sword")

	assert_bool(result).is_false()
	assert_bool(_spy.was_emitted("hero_equipment_crafted")).is_false()


func test_resolve_sacrifice_rejected_outright_while_forge_resolving_is_true() -> void:
	# cross-type pair: imbue (simulated as the in-flight op) + sacrifice
	_forge._forge_resolving = true

	var result: bool = _forge.resolve_sacrifice(&"sacrifice_aurora_stag", 0)

	assert_bool(result).is_false()


func test_resolve_imbue_rejected_outright_while_forge_resolving_is_true() -> void:
	var instance_id: int = _craft_iron_sword()
	_forge._on_constellation_rune_discovered("rune_triad_line", "pattern_triad_line")
	_forge._forge_resolving = true  # simulate an in-flight resolution (cross-type pair: craft+imbue)

	var result: bool = _forge.resolve_imbue(instance_id, &"rune_triad_line")

	assert_bool(result).is_false()
	assert_bool(_spy.was_emitted("item_rune_imbued")).is_false()


func test_guard_released_not_stuck_after_successful_craft() -> void:
	_forge._equipment_discovery_ledger[&"recipe_iron_sword"] = true
	GInventory.add_stackable(GGameDataRegistry.get_item_definition(&"common_scrap"), 4)

	_forge.resolve_craft(&"recipe_iron_sword")

	assert_bool(_forge._forge_resolving).is_false()


func test_guard_released_not_stuck_after_rejected_craft() -> void:
	# recipe never discovered — rejected at step (a)
	_forge.resolve_craft(&"recipe_iron_sword")

	assert_bool(_forge._forge_resolving).is_false()


# ---------------------------------------------------------------------------
# AC-24/AC-25: is_rune_id_known() — the single source-of-truth classification
# used to detect orphaned rune references.
# ---------------------------------------------------------------------------

func test_is_rune_id_known_true_for_real_constellation_rune() -> void:
	assert_bool(_forge.is_rune_id_known(&"rune_triad_line")).is_true()


func test_is_rune_id_known_true_for_real_tarot_rune() -> void:
	assert_bool(_forge.is_rune_id_known(&"rune_iron_resolve")).is_true()


func test_is_rune_id_known_true_for_real_menagerie_rune() -> void:
	assert_bool(_forge.is_rune_id_known(&"rune_menagerie_aurora_stag")).is_true()


func test_is_rune_id_known_false_for_removed_content_rune() -> void:
	assert_bool(_forge.is_rune_id_known(&"rune_never_existed_in_any_catalogue")).is_false()


func test_is_rune_id_known_false_for_empty_string() -> void:
	assert_bool(_forge.is_rune_id_known(&"")).is_false()


# ---------------------------------------------------------------------------
# AC-25: an orphaned still-AVAILABLE rune is retained (not discarded) on
# restore, but marked unselectable — resolve_imbue() rejects it.
# ---------------------------------------------------------------------------

func test_restore_marks_orphaned_available_rune_unknown_but_retains_entry() -> void:
	var save_data: Dictionary = {
		"equipment_discovery_ledger": {},
		"available_runes": {
			"rune_never_existed_in_any_catalogue": {
				"rune_source": "constellation",
				"stat_delta": {"additive_bonus_total": 0.05},
			},
			"rune_iron_resolve": {
				"rune_source": "tarot",
				"stat_delta": {"additive_bonus_total": 0.05},
			},
		},
	}

	var ok: bool = _forge.restore_save_data(save_data)

	assert_bool(ok).is_true()
	# Retained (not discarded) — still present in the ledger.
	assert_bool(_forge.get_available_rune(&"rune_never_existed_in_any_catalogue").is_empty()).is_false()
	assert_bool((_forge.get_available_rune(&"rune_never_existed_in_any_catalogue")["is_known"]) as bool).is_false()
	assert_bool((_forge.get_available_rune(&"rune_iron_resolve")["is_known"]) as bool).is_true()


func test_orphaned_available_rune_cannot_be_imbued() -> void:
	var instance_id: int = _craft_iron_sword()
	var save_data: Dictionary = {
		"equipment_discovery_ledger": {},
		"available_runes": {
			"rune_never_existed_in_any_catalogue": {
				"rune_source": "constellation",
				"stat_delta": {"additive_bonus_total": 0.05},
			},
		},
	}
	_forge.restore_save_data(save_data)

	var result: bool = _forge.resolve_imbue(instance_id, &"rune_never_existed_in_any_catalogue")

	assert_bool(result).is_false()
	assert_bool(_spy.was_emitted("item_rune_imbued")).is_false()
	# Still retained, unselectable — not silently deleted by the failed attempt.
	assert_bool(_forge.get_available_rune(&"rune_never_existed_in_any_catalogue").is_empty()).is_false()


func test_restore_does_not_block_load_when_orphaned_runes_present() -> void:
	var save_data: Dictionary = {
		"equipment_discovery_ledger": {},
		"available_runes": {
			"rune_never_existed_in_any_catalogue": {
				"rune_source": "menagerie",
				"stat_delta": {},
			},
		},
	}

	var ok: bool = _forge.restore_save_data(save_data)

	assert_bool(ok).is_true()  # AC-25: load not blocked
