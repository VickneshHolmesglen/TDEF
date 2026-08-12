extends GdUnitTestSuite

## ADR-0036 (tarot.md Rule 7/Formula F2/F4): Monster System's consumption of
## mission_modifier_applied for tarot_speed_scalar_mult. Real bug fixed by
## this ADR: the handler previously checked modifier_type == "monster_speed_scalar"
## (matches nothing Tarot ever emits) and did a last-write-wins overwrite
## instead of F2's multiplicative aggregate-then-clamp.

var _mm: MonsterManager


func before_test() -> void:
	_mm = MonsterManager.new()
	add_child(_mm)  # triggers _ready() -- subscribes to mission_modifier_applied/wave_started


func after_test() -> void:
	remove_child(_mm)
	_mm.free()


func test_unrecognized_modifier_type_string_from_the_old_bug_never_matches() -> void:
	GEventBus.mission_modifier_applied.emit("monster_speed_scalar", 1.75, "some_card")

	assert_float(_mm._tarot_speed_scalar).is_equal_approx(1.0, 0.001)


func test_tarot_speed_scalar_mult_single_card_composes_via_f2() -> void:
	GEventBus.mission_modifier_applied.emit("tarot_speed_scalar_mult", 1.69, "swift_current")

	assert_float(_mm._tarot_speed_scalar).is_equal_approx(1.69, 0.001)


func test_tarot_speed_scalar_mult_stacks_multiplicatively_across_two_cards() -> void:
	GEventBus.mission_modifier_applied.emit("tarot_speed_scalar_mult", 1.69, "card_a")
	GEventBus.mission_modifier_applied.emit("tarot_speed_scalar_mult", 1.20, "card_b")

	# tarot.md's own F2 worked example: 1.69 * 1.20 = 2.028, clamped to 2.00
	assert_float(_mm._tarot_speed_scalar).is_equal_approx(2.00, 0.001)


func test_tarot_speed_scalar_mult_clamps_at_lower_boundary() -> void:
	GEventBus.mission_modifier_applied.emit("tarot_speed_scalar_mult", 0.10, "card_a")

	assert_float(_mm._tarot_speed_scalar).is_equal_approx(0.50, 0.001)


## Real gap found live during ADR-0036 implementation: MonsterManager is a
## static MissionScene child, never destroyed/recreated between attempts —
## MissionSelect.retry_current_mission() re-emits mission_launched on this
## SAME instance. Without an explicit reset, a retried mission would compound
## this attempt's product against the first attempt's stale value instead of
## restarting from F4's "no card -> 1.0" baseline.
func test_tarot_speed_scalar_resets_on_wave_1_for_a_retried_mission() -> void:
	GEventBus.mission_modifier_applied.emit("tarot_speed_scalar_mult", 1.69, "swift_current")
	assert_float(_mm._tarot_speed_scalar).is_equal_approx(1.69, 0.001)

	# Simulate a mission retry's wave 1 entry -- same instance, no scene reload.
	_mm._on_wave_started(1, 6, 1.0)

	assert_float(_mm._tarot_speed_scalar_raw).is_equal_approx(1.0, 0.001)
	assert_float(_mm._tarot_speed_scalar).is_equal_approx(1.0, 0.001)


func test_tarot_speed_scalar_does_not_reset_on_wave_2() -> void:
	GEventBus.mission_modifier_applied.emit("tarot_speed_scalar_mult", 1.69, "swift_current")

	_mm._on_wave_started(2, 6, 1.0)

	assert_float(_mm._tarot_speed_scalar).is_equal_approx(1.69, 0.001)
