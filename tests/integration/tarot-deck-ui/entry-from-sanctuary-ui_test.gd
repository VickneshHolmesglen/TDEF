## Integration tests for Story 002 (epic-11-tarot-deck-ui, ADR-0020): Entry --
## Sanctuary UI's Loadout Affordance (GDD Core Rule 3, AC Group 2).
##
## AC-1/AC-2 (defaults to HERO_SKILL_BUILD on every entry, not sticky) are
## already true by construction from Story 001's own _ready() -- this shell
## is scene-instanced and mounted fresh every visit (matching Sanctuary UI's
## own identical "no room-state persistence" precedent, Epic 10 Story 006),
## so there is no session-local state anywhere to BE sticky. These tests
## confirm that guarantee via real repeated instantiation, not new logic.
##
## AC-3 (entry blocked during an active mission, "inherited from the
## underlying phase gate, not a shell-specific check") is a REAL, FLAGGED
## GAP: no phase-gate check exists anywhere in either shell today -- Sanctuary
## UI's own Loadout tab (Epic 10 Story 002/010) does not currently check
## Tarot/Hero Skill Build LOCKED state before allowing selection. This is the
## GDD's own explicit expectation of an external system this project hasn't
## built yet, not an omission in this story specifically.
extends GdUnitTestSuite


func _fresh_instance() -> TarotDeckUI:
	var shell: TarotDeckUI = load("res://src/presentation/tarot_deck_ui/TarotDeckUI.tscn").instantiate()
	add_child(shell)
	auto_free(shell)
	return shell


# ---------------------------------------------------------------------------
# AC-1: every fresh mount defaults to HERO_SKILL_BUILD
# ---------------------------------------------------------------------------

func test_fresh_mount_defaults_to_hero_skill_build() -> void:
	var shell: TarotDeckUI = _fresh_instance()
	assert_that(shell.get_active_state()).is_equal(&"HERO_SKILL_BUILD")


# ---------------------------------------------------------------------------
# AC-2: re-entry after a prior instance had TAROT_DECK active still defaults
# to HERO_SKILL_BUILD -- confirming the default is genuinely fixed, not
# accidentally sticky session state
# ---------------------------------------------------------------------------

func test_reentry_after_prior_instance_had_tarot_deck_active_still_defaults_hero_skill_build() -> void:
	var first_shell: TarotDeckUI = _fresh_instance()
	first_shell.get_tab_strip_for_test().get_tab_button(1).pressed.emit()  # TAROT_DECK
	assert_that(first_shell.get_active_state()).is_equal(&"TAROT_DECK")

	# A "re-entry" in this architecture is a brand new instance (scene-
	# instanced, per ADR-0011's own scope note and matching Sanctuary UI's
	# identical Story 006 precedent) -- not a reset of the existing one.
	var second_shell: TarotDeckUI = _fresh_instance()

	assert_that(second_shell.get_active_state()).is_equal(&"HERO_SKILL_BUILD")


func test_default_holds_across_multiple_repeated_entry_exit_cycles() -> void:
	for _cycle: int in 3:
		var shell: TarotDeckUI = _fresh_instance()
		shell.get_tab_strip_for_test().get_tab_button(1).pressed.emit()
		assert_that(shell.get_active_state()).is_equal(&"TAROT_DECK")
		# Next loop iteration's fresh instance re-confirms the default holds,
		# no session-local memory accumulating across repeated cycles.

	var final_shell: TarotDeckUI = _fresh_instance()
	assert_that(final_shell.get_active_state()).is_equal(&"HERO_SKILL_BUILD")
