## Integration tests for TarotScreen (src/gameplay/ui/tarot_screen), Tarot
## Deck UI Story 001's Room Hosting scope. Exercises the screen against
## tarot.md's UI Requirements: deck tray + card pool, single-action
## equip/unequip (see the screen's own doc comment for the honestly-scoped
## deviation from the GDD's literal pick-up-then-place wording).
##
## Tarot is deliberately scene-instanced (ADR-0027), not an Autoload -- this
## screen discovers its one real instance via the "tarot" group at _ready(),
## which is empty in an isolated scene_runner() tree. Matches
## equipment_forge_screen_test.gd's own established pattern: `Tarot.new()`
## (no add_child(), so _ready()/EventBus subscriptions never fire), injected
## onto the screen post-_ready() via `.set()`, followed by an explicit
## rebuild call.
extends GdUnitTestSuite

const CARD_IRON_RESOLVE: StringName = &"iron_resolve"
const CARD_LUCKY_CHARM: StringName = &"lucky_charm"

var _tarot: Tarot
var _runner: GdUnitSceneRunner
var _screen: Control


var _conflict_indicator: ConflictIndicator


func before_test() -> void:
	_tarot = Tarot.new()
	_conflict_indicator = ConflictIndicator.new()
	add_child(_conflict_indicator)
	_runner = scene_runner("res://src/gameplay/ui/tarot_screen/TarotScreen.tscn")
	_screen = _runner.scene() as Control
	_screen.set("tarot", _tarot)
	_screen.set("conflict_indicator", _conflict_indicator)
	_rebuild_all()


func after_test() -> void:
	if _tarot != null and is_instance_valid(_tarot):
		_tarot.free()
	_tarot = null
	if _conflict_indicator != null and is_instance_valid(_conflict_indicator):
		_conflict_indicator.disconnect_own_subscriptions()
		_conflict_indicator.queue_free()
	_conflict_indicator = null


func _rebuild_all() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_rebuild_deck_tray")
	@warning_ignore("unsafe_method_access")
	_screen.call("_rebuild_card_pool")


func _unlock(card_id: StringName) -> void:
	@warning_ignore("unsafe_property_access")
	(_tarot.get("_card_unlocked") as Dictionary)[card_id] = true


# ---------------------------------------------------------------------------
# Card pool
# ---------------------------------------------------------------------------

func test_locked_card_shows_locked_state() -> void:
	_rebuild_all()
	var button: Button = _screen.call("get_pool_button", CARD_IRON_RESOLVE)
	assert_object(button).is_not_null()
	assert_str(button.text).contains("LOCKED")


func test_unlocked_unequipped_card_shows_available_state() -> void:
	_unlock(CARD_IRON_RESOLVE)
	_rebuild_all()
	var button: Button = _screen.call("get_pool_button", CARD_IRON_RESOLVE)
	assert_str(button.text).contains("AVAILABLE")


func test_pressing_an_unlocked_card_equips_it() -> void:
	_unlock(CARD_IRON_RESOLVE)
	_rebuild_all()

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_pool_card_pressed", CARD_IRON_RESOLVE)

	assert_array(_tarot.get_current_deck()).contains(CARD_IRON_RESOLVE)


func test_pressing_a_locked_card_does_not_equip_it_and_flags_rejection() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_pool_card_pressed", CARD_IRON_RESOLVE)

	assert_array(_tarot.get_current_deck()).is_empty()
	assert_that(_screen.call("get_last_rejected_card_id")).is_equal(CARD_IRON_RESOLVE)


func test_pressing_an_equipped_card_in_the_pool_unequips_it() -> void:
	_unlock(CARD_IRON_RESOLVE)
	_tarot.equip_card(CARD_IRON_RESOLVE)
	_rebuild_all()

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_pool_card_pressed", CARD_IRON_RESOLVE)

	assert_array(_tarot.get_current_deck()).is_empty()


# ---------------------------------------------------------------------------
# Deck tray
# ---------------------------------------------------------------------------

func test_equipped_card_appears_in_the_deck_tray() -> void:
	_unlock(CARD_IRON_RESOLVE)
	_tarot.equip_card(CARD_IRON_RESOLVE)
	_rebuild_all()

	assert_object(_screen.call("get_deck_button", CARD_IRON_RESOLVE)).is_not_null()


func test_pressing_a_deck_tray_card_unequips_it() -> void:
	_unlock(CARD_IRON_RESOLVE)
	_tarot.equip_card(CARD_IRON_RESOLVE)
	_rebuild_all()

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_deck_card_pressed", CARD_IRON_RESOLVE)

	assert_array(_tarot.get_current_deck()).is_empty()


func test_deck_changed_event_triggers_a_live_rebuild() -> void:
	_unlock(CARD_LUCKY_CHARM)
	_tarot.equip_card(CARD_LUCKY_CHARM)  # fires tarot_deck_changed -- screen listens for this

	assert_object(_screen.call("get_deck_button", CARD_LUCKY_CHARM)).is_not_null()


# ---------------------------------------------------------------------------
# Conflict Indicator (epic-11 Story 004, GDD Core Rule 6)
# ---------------------------------------------------------------------------

func test_no_conflict_tag_when_no_run_modifier_is_active() -> void:
	_unlock(CARD_IRON_RESOLVE)  # tarot_difficulty_growth_rate
	_tarot.equip_card(CARD_IRON_RESOLVE)
	_rebuild_all()

	var button: Button = _screen.call("get_deck_button", CARD_IRON_RESOLVE)
	assert_str(button.text).not_contains("CONFLICT")
	assert_bool(_screen.call("has_conflict", CARD_IRON_RESOLVE)).is_false()


func test_conflict_tag_appears_when_a_mapped_run_modifier_is_active() -> void:
	_unlock(CARD_IRON_RESOLVE)  # tarot_difficulty_growth_rate -> conflicts with difficulty_growth_boost
	_tarot.equip_card(CARD_IRON_RESOLVE)
	_rebuild_all()

	GEventBus.run_modifier_selected.emit("difficulty_growth_boost", 0.03)

	var button: Button = _screen.call("get_deck_button", CARD_IRON_RESOLVE)
	assert_str(button.text).contains("CONFLICT")
	assert_bool(_screen.call("has_conflict", CARD_IRON_RESOLVE)).is_true()


func test_conflict_tag_clears_when_mission_selected_resets_modifiers() -> void:
	_unlock(CARD_IRON_RESOLVE)
	_tarot.equip_card(CARD_IRON_RESOLVE)
	_rebuild_all()
	GEventBus.run_modifier_selected.emit("difficulty_growth_boost", 0.03)
	assert_bool(_screen.call("has_conflict", CARD_IRON_RESOLVE)).is_true()

	GEventBus.mission_selected.emit("some_other_mission")

	var button: Button = _screen.call("get_deck_button", CARD_IRON_RESOLVE)
	assert_str(button.text).not_contains("CONFLICT")


func test_conflict_tag_never_blocks_unequipping_the_card() -> void:
	_unlock(CARD_IRON_RESOLVE)
	_tarot.equip_card(CARD_IRON_RESOLVE)
	_rebuild_all()
	GEventBus.run_modifier_selected.emit("difficulty_growth_boost", 0.03)
	assert_bool(_screen.call("has_conflict", CARD_IRON_RESOLVE)).is_true()

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_deck_card_pressed", CARD_IRON_RESOLVE)

	assert_array(_tarot.get_current_deck()).is_empty()


func test_unmapped_modifier_type_never_shows_a_conflict_tag() -> void:
	_unlock(CARD_LUCKY_CHARM)  # tarot_reward_scalar_mult -- no MAPPING entry, no analog
	_tarot.equip_card(CARD_LUCKY_CHARM)
	_rebuild_all()

	GEventBus.run_modifier_selected.emit("difficulty_growth_boost", 0.03)
	GEventBus.run_modifier_selected.emit("extend_waves", 1.0)

	var button: Button = _screen.call("get_deck_button", CARD_LUCKY_CHARM)
	assert_str(button.text).not_contains("CONFLICT")


# ---------------------------------------------------------------------------
# Room-hosting contract (ADR-0032)
# ---------------------------------------------------------------------------

func test_disconnect_own_subscriptions_is_safe_to_call() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("disconnect_own_subscriptions")
	assert_bool(true).is_true()
