extends GdUnitTestSuite

## Unit tests for Damage & Status Rule V, the Hero incoming-damage pipeline
## (hero-damage spec section 4.4 / 5, AC-6, AC-9).

class _StubHeroStats extends RefCounted:
	var stats: Dictionary = {}

	func get_effective_stat(stat: StringName) -> float:
		return float(stats.get(stat, 0.0))


var _ds: DamageStatus
var _spy: EventBusSpy


func before_test() -> void:
	_ds = DamageStatus.new()
	add_child(_ds)  # Required: the handler awaits get_tree().process_frame
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_damage_taken)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if is_instance_valid(_ds):
		_ds.queue_free()
		await get_tree().process_frame
	_ds = null


func _ev(amount: float, damage_type: String = "physical", source_type: int = 0) -> HeroIncomingDamageEvent:
	var ev := HeroIncomingDamageEvent.new()
	ev.amount = amount
	ev.damage_type = damage_type
	ev.source_type = source_type
	return ev


# --- pure mitigation -------------------------------------------------------

func test_physical_with_no_armor_is_unmitigated() -> void:
	assert_int(DamageStatus.mitigate_hero_incoming(45.0, "physical", 0.0, 0.0)).is_equal(45)


func test_physical_armor_floors_the_result() -> void:
	# floor(45 x 100 / 152) = 29 ; floor(70 x 100 / 152) = 46
	assert_int(DamageStatus.mitigate_hero_incoming(45.0, "physical", 52.0, 0.0)).is_equal(29)
	assert_int(DamageStatus.mitigate_hero_incoming(70.0, "physical", 52.0, 0.0)).is_equal(46)


func test_armor_cannot_reduce_a_hit_below_one() -> void:
	assert_int(DamageStatus.mitigate_hero_incoming(1.0, "physical", 1000.0, 0.0)).is_equal(1)


func test_negative_armor_is_treated_as_zero() -> void:
	assert_int(DamageStatus.mitigate_hero_incoming(45.0, "physical", -50.0, 0.0)).is_equal(45)


func test_fire_and_frost_use_the_resist_fraction() -> void:
	assert_int(DamageStatus.mitigate_hero_incoming(100.0, "fire", 999.0, 0.5)).is_equal(50)
	assert_int(DamageStatus.mitigate_hero_incoming(100.0, "frost", 999.0, 0.2)).is_equal(80)


func test_resist_is_capped_at_seventy_five_percent() -> void:
	assert_int(DamageStatus.mitigate_hero_incoming(100.0, "fire", 0.0, 0.9)).is_equal(25)


func test_unknown_damage_type_is_unmitigated() -> void:
	assert_int(DamageStatus.mitigate_hero_incoming(30.0, "poison", 500.0, 0.75)).is_equal(30)


# --- handler ---------------------------------------------------------------

func test_incoming_damage_is_mitigated_and_emitted_one_frame_later() -> void:
	var stub := _StubHeroStats.new()
	stub.stats[&"armor"] = 52.0
	_ds.set_hero_stats(stub)
	_ds._on_hero_incoming_damage(_ev(45.0, "physical", 0))
	assert_int(_spy.count("hero_damage_taken")).is_equal(0)  # deferred one frame
	await get_tree().process_frame
	assert_int(_spy.count("hero_damage_taken")).is_equal(1)
	var args: Array = (_spy.emissions["hero_damage_taken"] as Array)[0] as Array
	assert_int(args[0]).is_equal(29)
	assert_int(args[1]).is_equal(0)


func test_source_type_is_forwarded() -> void:
	_ds._on_hero_incoming_damage(_ev(10.0, "physical", 1))
	await get_tree().process_frame
	var args: Array = (_spy.emissions["hero_damage_taken"] as Array)[0] as Array
	assert_int(args[1]).is_equal(1)


func test_without_a_stat_provider_armor_and_resists_are_zero() -> void:
	_ds._on_hero_incoming_damage(_ev(45.0, "physical"))
	_ds._on_hero_incoming_damage(_ev(40.0, "fire"))
	await get_tree().process_frame
	var emissions: Array = _spy.emissions["hero_damage_taken"] as Array
	assert_int(emissions.size()).is_equal(2)
	assert_int((emissions[0] as Array)[0]).is_equal(45)
	assert_int((emissions[1] as Array)[0]).is_equal(40)


func test_fire_damage_reads_the_fire_resist_stat() -> void:
	var stub := _StubHeroStats.new()
	stub.stats[&"elemental_resist_fire"] = 0.5
	stub.stats[&"elemental_resist_frost"] = 0.0
	_ds.set_hero_stats(stub)
	_ds._on_hero_incoming_damage(_ev(100.0, "fire"))
	_ds._on_hero_incoming_damage(_ev(100.0, "frost"))
	await get_tree().process_frame
	var emissions: Array = _spy.emissions["hero_damage_taken"] as Array
	assert_int((emissions[0] as Array)[0]).is_equal(50)
	assert_int((emissions[1] as Array)[0]).is_equal(100)


func test_stats_are_read_at_hit_time_not_emit_time() -> void:
	var stub := _StubHeroStats.new()
	stub.stats[&"armor"] = 100.0
	_ds.set_hero_stats(stub)
	_ds._on_hero_incoming_damage(_ev(100.0))
	stub.stats[&"armor"] = 0.0  # changes during the deferral frame
	await get_tree().process_frame
	var args: Array = (_spy.emissions["hero_damage_taken"] as Array)[0] as Array
	assert_int(args[0]).is_equal(50)  # floor(100 x 100 / 200) with the armor at hit time


func test_real_bus_delivers_hero_incoming_damage_to_the_pipeline() -> void:
	GEventBus.hero_incoming_damage.emit(_ev(30.0))
	await get_tree().process_frame
	assert_int(_spy.count("hero_damage_taken")).is_equal(1)


func test_subscription_is_disconnected_on_exit() -> void:
	var baseline: int = GEventBus.hero_incoming_damage.get_connections().size()
	remove_child(_ds)
	_ds.free()
	_ds = null
	assert_int(GEventBus.hero_incoming_damage.get_connections().size()).is_equal(baseline - 1)
