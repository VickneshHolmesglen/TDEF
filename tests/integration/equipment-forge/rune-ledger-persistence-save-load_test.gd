## Integration tests for Story 016 (TR-equipforge-003, ADR-0025): Rune Ledger
## Persistence Across Save/Load (AC-26/AC-27).
##
## Closes the GDD's own previously-flagged-unverifiable gap: Constellation
## had no assigned restore_order when equipment-forge.md was written.
## ADR-0022 has since assigned Constellation restore_order=24; this story
## confirms 24 < 32 (Equipment Forge's own RESTORE_ORDER) explicitly, and
## exercises both Constellation- and Tarot-sourced rune round-tripping.
##
## EquipmentForge does NOT re-subscribe-and-replay past discovery events at
## restore time (Story 016's own Implementation Notes) — it restores its own
## persisted available_runes Dictionary directly, so these tests verify the
## save/load round-trip of that payload, plus the structural ordering
## guarantee (restore_order comparisons), matching this project's established
## persistence-test convention (no add_child(), no live cross-Autoload
## restore orchestration needed to prove correctness).
extends GdUnitTestSuite

var _forge: EquipmentForge


func before_test() -> void:
	_forge = EquipmentForge.new()
	GInventory.reset_to_defaults()


func after_test() -> void:
	if _forge != null and is_instance_valid(_forge):
		_forge.free()
	_forge = null
	GInventory.reset_to_defaults()


# ---------------------------------------------------------------------------
# Structural ordering guarantee (ADR-0025 Decision Summary)
# ---------------------------------------------------------------------------

func test_restore_order_32_is_after_tarot_22_and_constellation_24() -> void:
	assert_int(EquipmentForge.RESTORE_ORDER).is_equal(32)
	assert_int(Tarot.RESTORE_ORDER).is_less(EquipmentForge.RESTORE_ORDER)
	assert_int(Constellation.RESTORE_ORDER).is_less(EquipmentForge.RESTORE_ORDER)


# ---------------------------------------------------------------------------
# AC-26 (previously flagged unverifiable — now resolved by ADR-0022's
# Constellation restore_order=24): a Constellation-sourced rune already
# AVAILABLE before save is still correctly present and selectable post-restore.
# ---------------------------------------------------------------------------

func test_constellation_sourced_rune_survives_save_load_round_trip() -> void:
	_forge._on_constellation_rune_discovered("rune_triad_line", "pattern_triad_line")

	var saved: Dictionary = _forge.get_save_data()
	var restored := EquipmentForge.new()
	var ok: bool = restored.restore_save_data(saved)

	assert_bool(ok).is_true()
	var entry: Dictionary = restored.get_available_rune(&"rune_triad_line")
	assert_bool(entry.is_empty()).is_false()
	assert_str(entry["rune_source"] as String).is_equal("constellation")
	assert_bool(entry["is_known"] as bool).is_true()  # selectable post-restore

	# Selectable = actually imbuable, not just present in the ledger.
	var instance_id: int = _craft_iron_sword_via(restored)
	assert_bool(restored.resolve_imbue(instance_id, &"rune_triad_line")).is_true()
	restored.free()


# ---------------------------------------------------------------------------
# AC-27 (contrast case, always verifiable — Tarot restore_order=22 already
# existed before this story).
# ---------------------------------------------------------------------------

func test_tarot_sourced_rune_survives_save_load_round_trip() -> void:
	_forge._on_tarot_rune_discovered("rune_iron_resolve", "iron_resolve")

	var saved: Dictionary = _forge.get_save_data()
	var restored := EquipmentForge.new()
	var ok: bool = restored.restore_save_data(saved)

	assert_bool(ok).is_true()
	var entry: Dictionary = restored.get_available_rune(&"rune_iron_resolve")
	assert_bool(entry.is_empty()).is_false()
	assert_str(entry["rune_source"] as String).is_equal("tarot")
	assert_bool(entry["is_known"] as bool).is_true()
	restored.free()


func test_both_sources_survive_the_same_round_trip_together() -> void:
	_forge._on_constellation_rune_discovered("rune_triad_line", "pattern_triad_line")
	_forge._on_tarot_rune_discovered("rune_iron_resolve", "iron_resolve")

	var saved: Dictionary = _forge.get_save_data()
	var restored := EquipmentForge.new()
	restored.restore_save_data(saved)

	assert_bool(restored.get_available_rune(&"rune_triad_line").is_empty()).is_false()
	assert_bool(restored.get_available_rune(&"rune_iron_resolve").is_empty()).is_false()
	restored.free()


func _craft_iron_sword_via(forge: EquipmentForge) -> int:
	forge._equipment_discovery_ledger[&"recipe_iron_sword"] = true
	GInventory.add_stackable(GGameDataRegistry.get_item_definition(&"common_scrap"), 4)
	forge.resolve_craft(&"recipe_iron_sword")
	return GInventory.get_slot_contents(0)["instance_id"] as int
