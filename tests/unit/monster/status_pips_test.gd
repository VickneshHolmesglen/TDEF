extends GdUnitTestSuite

## Status pips (design/quick-specs/status-pips-2026-11-03.md): MonsterManager
## turns a monster's statuses into a bitmask each frame; MonsterInstance shows
## one glyph per status and redraws only when the set changes.


func test_status_bits_cover_every_status_kind() -> void:
	var entity := MonsterEntity.new()
	assert_int(MonsterManager.status_bits_for(entity)).is_equal(0)

	for kind: String in ["burn", "poison", "bleed"]:
		var effect := ActiveStatusEffect.new()
		effect.effect_type = kind
		entity.active_status_effects.append(effect)
	entity.active_slow_effects.append(ActiveSlowEffect.new())
	entity.stun_remaining = 0.5
	entity.vulnerability_remaining = 2.0

	assert_int(MonsterManager.status_bits_for(entity)).is_equal(0b111111)
	entity.free()


func test_status_bits_map_to_ids_in_display_order() -> void:
	assert_array(MonsterInstance.statuses_from_bits(0b10001)).contains_exactly([&"burn", &"stun"])
	assert_array(MonsterInstance.statuses_from_bits(0)).is_empty()
	assert_int(MonsterInstance.STATUS_ORDER.size()).is_equal(MonsterInstance.STATUS_COLORS.size())


func test_set_statuses_stores_a_copy_and_ignores_repeats() -> void:
	var instance := MonsterInstance.new()
	var list: Array[StringName] = [&"slow"]
	instance.set_statuses(list)
	list.append(&"stun")  # caller's array changing later must not leak in
	assert_array(instance.get_statuses()).contains_exactly([&"slow"])
	instance.free()
