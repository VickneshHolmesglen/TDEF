## Integration tests for Story 004 (epic-11-tarot-deck-ui, ADR-0027/ADR-0028):
## Conflict Indicator -- Tarot / Mission Select modifier-mapping table (GDD
## Core Rule 6, AC Group 4).
##
## Exercises the mapping/query logic directly against the real EventBus
## signals (run_modifier_selected, mission_selected) -- no real Tarot
## deck-tray UI exists yet (OQ-5) to click a card in, so these tests confirm
## the engine a future screen story will query, matching conflict_indicator.gd's
## own class doc.
extends GdUnitTestSuite

var _runner: GdUnitSceneRunner
var _shell: TarotDeckUI
var _indicator: ConflictIndicator


func before_test() -> void:
	_runner = scene_runner("res://src/presentation/tarot_deck_ui/TarotDeckUI.tscn")
	@warning_ignore("unsafe_cast")
	_shell = _runner.scene() as TarotDeckUI
	_indicator = _shell.get_conflict_indicator()


# ---------------------------------------------------------------------------
# Mapped conflicts render -- both single- and multi-conflict cases
# ---------------------------------------------------------------------------

func test_difficulty_growth_rate_conflicts_with_difficulty_growth_boost() -> void:
	GEventBus.run_modifier_selected.emit("difficulty_growth_boost", 0.15)

	assert_bool(_indicator.has_conflict("tarot_difficulty_growth_rate")).is_true()
	assert_array(_indicator.get_conflicting_modifier_ids("tarot_difficulty_growth_rate")) \
		.is_equal(["difficulty_growth_boost"])


func test_wave_config_override_conflicts_with_extend_waves_only() -> void:
	GEventBus.run_modifier_selected.emit("extend_waves", 2.0)

	assert_array(_indicator.get_conflicting_modifier_ids("tarot_wave_config_override")) \
		.is_equal(["extend_waves"])


func test_wave_config_override_conflicts_with_both_simultaneously() -> void:
	GEventBus.run_modifier_selected.emit("extend_waves", 2.0)
	GEventBus.run_modifier_selected.emit("difficulty_growth_boost", 0.15)

	var conflicts: Array[String] = _indicator.get_conflicting_modifier_ids("tarot_wave_config_override")
	assert_int(conflicts.size()).is_equal(2)
	assert_array(conflicts).contains(["extend_waves", "difficulty_growth_boost"])


# ---------------------------------------------------------------------------
# No-analog modifier_types never trigger, regardless of active selections
# ---------------------------------------------------------------------------

func test_speed_scalar_mult_never_conflicts_with_anything() -> void:
	GEventBus.run_modifier_selected.emit("extend_waves", 2.0)
	GEventBus.run_modifier_selected.emit("difficulty_growth_boost", 0.15)

	assert_bool(_indicator.has_conflict("tarot_speed_scalar_mult")).is_false()


func test_reward_scalar_mult_never_conflicts_with_anything() -> void:
	GEventBus.run_modifier_selected.emit("extend_waves", 2.0)

	assert_bool(_indicator.has_conflict("tarot_reward_scalar_mult")).is_false()


# ---------------------------------------------------------------------------
# No selection set, no conflict
# ---------------------------------------------------------------------------

func test_no_active_selection_means_no_conflict_for_any_mapped_type() -> void:
	assert_bool(_indicator.has_conflict("tarot_difficulty_growth_rate")).is_false()
	assert_bool(_indicator.has_conflict("tarot_wave_config_override")).is_false()


# ---------------------------------------------------------------------------
# 0.0 modifier_value means "off" -- matches MissionSelect's own definition
# of active (mission-select.md's own "absence or a stored 0.0 means off")
# ---------------------------------------------------------------------------

func test_zero_modifier_value_is_treated_as_inactive() -> void:
	GEventBus.run_modifier_selected.emit("extend_waves", 2.0)
	assert_bool(_indicator.has_conflict("tarot_wave_config_override")).is_true()

	GEventBus.run_modifier_selected.emit("extend_waves", 0.0)  # toggled back off

	assert_bool(_indicator.has_conflict("tarot_wave_config_override")).is_false()


# ---------------------------------------------------------------------------
# Stale-value clearing -- mission_selected resets tracked state, matching
# MissionSelect's own select_mission() reset (mission-select.md Rule 6)
# ---------------------------------------------------------------------------

func test_mission_selected_clears_previously_active_modifiers() -> void:
	GEventBus.run_modifier_selected.emit("extend_waves", 2.0)
	assert_bool(_indicator.has_conflict("tarot_wave_config_override")).is_true()

	GEventBus.mission_selected.emit("second_mission")

	assert_bool(_indicator.has_conflict("tarot_wave_config_override")).is_false()
