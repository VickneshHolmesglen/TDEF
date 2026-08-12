## Regression test for BUG-0001 (production/qa/bugs/BUG-0001.md), fixed by
## ADR-0035 (Tarot Autoload Conversion, 2026-08-12).
##
## BUG-0001's reproduction case: Tarot's save-persistence registration was
## silently dropped from any save taken while TarotDeckUI.tscn was not
## mounted, because Tarot only registered with GSavePersistence in its own
## _ready()/_exit_tree(), and was only ever instanced as a child of that one
## screen. This test inverts that reproduction case into a passing one: it
## asserts Tarot's "tarot" save key is present in GSavePersistence's
## collected save data with NO TarotDeckUI.tscn (or any other Tarot-hosting
## scene) instantiated anywhere in this test's own tree -- exactly the
## "player is anywhere else in the game" condition BUG-0001 named.
##
## GSavePersistence._collect_save_data() is called directly (private-by-
## convention test seam, matching this project's established direct-access
## pattern for other systems' internal state) rather than a real
## save_slot()/load_slot() disk round-trip, to avoid touching real save
## files shared across the test suite -- this project's own Story 007 Tarot
## persistence tests (state-tables-persistence_test.gd) establish the same
## "call get_save_data()/restore_save_data() directly, not through disk I/O"
## convention for this exact class of test.
extends GdUnitTestSuite


func test_tarot_save_key_is_collected_with_no_tarot_hosting_scene_mounted() -> void:
	# No TarotDeckUI.tscn, no local Tarot.new() add_child()'d anywhere in
	# this test -- GTarot is a real Autoload (ADR-0035), always registered
	# with GSavePersistence regardless of which scene is currently active.
	@warning_ignore("unsafe_method_access")
	var collected: Dictionary = GSavePersistence._collect_save_data()

	assert_bool(collected.has("tarot")).is_true()


func test_tarot_save_key_reflects_gtarots_own_real_state() -> void:
	GTarot.reset_to_defaults()
	GTarot._card_unlocked[&"iron_resolve"] = true

	@warning_ignore("unsafe_method_access")
	var collected: Dictionary = GSavePersistence._collect_save_data()
	var tarot_data: Dictionary = collected.get("tarot", {}) as Dictionary

	assert_bool((tarot_data.get("card_unlocked", {}) as Dictionary).get("iron_resolve", false) as bool).is_true()

	GTarot.reset_to_defaults()
