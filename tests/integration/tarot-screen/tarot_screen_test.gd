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

## Rare rarity, unlock_tech_id = &"tech_production_2" (assets/data/tarot/card_bountiful_harvest.tres)
## -- the "starts locked" fixture for these 2 tests. iron_resolve (Common,
## unlock_tech_id = "") is unlocked from the start by content design as of
## the Defense Building tech-tree wiring (see TarotCardResource.unlock_tech_id),
## so it can no longer stand in for "a card the player has not unlocked yet."
const CARD_LOCKED_BY_DEFAULT: StringName = &"bountiful_harvest"

var _tarot: Tarot
var _runner: GdUnitSceneRunner
var _screen: Control


var _conflict_indicator: ConflictIndicator


func before_test() -> void:
	# GDefenseBuilding is a real, persistent Autoload -- is_card_unlocked()
	# now reads it live (TD-test-004 convention), so reset it here to
	# guarantee CARD_LOCKED_BY_DEFAULT's tech gate is actually unmet
	# regardless of what an earlier test in the same run left behind.
	GDefenseBuilding.reset_to_defaults()
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
	GDefenseBuilding.reset_to_defaults()


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
	var button: Button = _screen.call("get_pool_button", CARD_LOCKED_BY_DEFAULT)
	assert_object(button).is_not_null()
	assert_str(button.text).contains(tr("TAROT_TAG_LOCKED"))


func test_unlocked_unequipped_card_shows_available_state() -> void:
	_unlock(CARD_IRON_RESOLVE)
	_rebuild_all()
	var button: Button = _screen.call("get_pool_button", CARD_IRON_RESOLVE)
	assert_str(button.text).contains(tr("TAROT_TAG_AVAILABLE"))


func test_pressing_an_unlocked_card_equips_it() -> void:
	_unlock(CARD_IRON_RESOLVE)
	_rebuild_all()

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_pool_card_pressed", CARD_IRON_RESOLVE)

	assert_array(_tarot.get_current_deck()).contains(CARD_IRON_RESOLVE)


func test_pressing_a_locked_card_does_not_equip_it_and_flags_rejection() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_pool_card_pressed", CARD_LOCKED_BY_DEFAULT)

	assert_array(_tarot.get_current_deck()).is_empty()
	assert_that(_screen.call("get_last_rejected_card_id")).is_equal(CARD_LOCKED_BY_DEFAULT)


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
	assert_str(button.text).not_contains("Conflicts")
	assert_bool(_screen.call("has_conflict", CARD_IRON_RESOLVE)).is_false()


func test_conflict_tag_appears_when_a_mapped_run_modifier_is_active() -> void:
	_unlock(CARD_IRON_RESOLVE)  # tarot_difficulty_growth_rate -> conflicts with difficulty_growth_boost
	_tarot.equip_card(CARD_IRON_RESOLVE)
	_rebuild_all()

	GEventBus.run_modifier_selected.emit("difficulty_growth_boost", 0.03)

	var button: Button = _screen.call("get_deck_button", CARD_IRON_RESOLVE)
	assert_str(button.text).contains("Conflicts")
	assert_bool(_screen.call("has_conflict", CARD_IRON_RESOLVE)).is_true()


func test_conflict_tag_clears_when_mission_selected_resets_modifiers() -> void:
	_unlock(CARD_IRON_RESOLVE)
	_tarot.equip_card(CARD_IRON_RESOLVE)
	_rebuild_all()
	GEventBus.run_modifier_selected.emit("difficulty_growth_boost", 0.03)
	assert_bool(_screen.call("has_conflict", CARD_IRON_RESOLVE)).is_true()

	GEventBus.mission_selected.emit("some_other_mission")

	var button: Button = _screen.call("get_deck_button", CARD_IRON_RESOLVE)
	assert_str(button.text).not_contains("Conflicts")


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
	assert_str(button.text).not_contains("Conflicts")


# ---------------------------------------------------------------------------
# Card art (2026-08-04) -- closes this screen's own flagged "no card art"
# simplification for the 7 cards a best-fit mapping now exists for.
# ---------------------------------------------------------------------------

func test_pool_button_shows_an_icon_for_a_mapped_card() -> void:
	_unlock(CARD_IRON_RESOLVE)
	_rebuild_all()
	var button: Button = _screen.call("get_pool_button", CARD_IRON_RESOLVE)
	assert_object(button.icon).is_not_null()


func test_deck_tray_button_shows_an_icon_for_a_mapped_card() -> void:
	_unlock(CARD_LUCKY_CHARM)
	_rebuild_all()
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_pool_card_pressed", CARD_LUCKY_CHARM)
	var button: Button = _screen.call("get_deck_button", CARD_LUCKY_CHARM)
	assert_object(button.icon).is_not_null()


## Guards the original bug (native-res tarot art ballooning the button). The
## 2026-10-10 card layout dropped the fixed 32 px cap so the art fills its
## card; the guard is now that the art scales and never drives the card's
## minimum size anywhere near the art's native resolution.
func test_pool_card_art_scales_instead_of_ballooning_the_card() -> void:
	_unlock(CARD_IRON_RESOLVE)
	_rebuild_all()
	var button: Button = _screen.call("get_pool_button", CARD_IRON_RESOLVE)
	assert_bool(button.expand_icon).is_true()
	var min_size: Vector2 = button.get_combined_minimum_size()
	assert_float(min_size.x).is_less(300.0)
	assert_float(min_size.y).is_less(300.0)


## Every shipped card is art-mapped since 2026-10-04, so the fallback is
## exercised directly with an id absent from CARD_TEXTURES -- confirms it is
## a plain unmapped button, not an error or a placeholder icon.
func test_unmapped_card_has_no_icon() -> void:
	var button := Button.new()
	@warning_ignore("unsafe_method_access")
	_screen.call("_apply_card_icon", button, &"not_a_real_card")
	assert_object(button.icon).is_null()
	button.free()


func test_previously_unmapped_cards_now_show_art() -> void:
	for card_id: StringName in [&"reckless_onslaught", &"swift_current", &"grinding_gauntlet"]:
		_unlock(card_id)
	_rebuild_all()
	for card_id: StringName in [&"reckless_onslaught", &"swift_current", &"grinding_gauntlet"]:
		var pool_button: Button = _screen.call("get_pool_button", card_id)
		assert_object(pool_button.icon).override_failure_message("no art for %s" % card_id).is_not_null()


func test_grim_resolve_shows_an_icon_now_that_it_is_mapped() -> void:
	_unlock(&"grim_resolve")
	_rebuild_all()
	var button: Button = _screen.call("get_pool_button", &"grim_resolve")
	assert_object(button.icon).is_not_null()


# ---------------------------------------------------------------------------
# Room-hosting contract (ADR-0032)
# ---------------------------------------------------------------------------

func test_disconnect_own_subscriptions_is_safe_to_call() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("disconnect_own_subscriptions")
	assert_bool(true).is_true()
