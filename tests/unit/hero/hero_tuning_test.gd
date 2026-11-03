## HeroTuning (2026-11-04): the hero's caps, curve constants, hitbox and attack
## interval come from res://assets/data/hero/hero_tuning.tres, not constants.
extends GdUnitTestSuite


func test_hero_tuning_data_file_loads_with_shipped_values() -> void:
	var t := HeroTuning.load_default()
	assert_object(t).is_not_null()
	assert_float(t.crit_chance_cap).is_equal(0.85)
	assert_float(t.cdr_cap).is_equal(0.75)
	assert_float(t.collision_radius).is_equal(16.0)
	assert_float(t.auto_attack_interval_s).is_equal(1.0)


func test_hero_tuning_assigned_resource_overrides_caps() -> void:
	# Arrange: a hero with its own, tighter CDR and lifesteal caps.
	var hero := Hero.new()
	var custom := HeroTuning.new()
	custom.cdr_cap = 0.5
	custom.lifesteal_cap = 0.1
	hero.tuning = custom
	# Act / Assert
	assert_float(hero._apply_stat_cap(&"cdr", 0.9)).is_equal(0.5)
	assert_float(hero._apply_stat_cap(&"lifesteal", 0.3)).is_equal(0.1)
	hero.free()


func test_hero_tuning_defaults_to_shared_file() -> void:
	var hero := Hero.new()
	assert_float(hero._apply_stat_cap(&"cdr", 0.9)).is_equal(0.75)
	assert_object(hero.tuning).is_same(HeroTuning.load_default())
	hero.free()
