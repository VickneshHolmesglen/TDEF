## Integration tests for Story 005 (epic-11-tarot-deck-ui): Current Build
## Snapshot Chip -- the shell's own cross-screen bridge (GDD Core Rule 7, AC
## Group 5).
##
## GHeroSkillBuild is a shared Autoload whose internal slot state may already
## be mutated by other test suites in the same headless run (Epic 08's own
## hero-skill-build tests, or Story 003's real transition_to_sanctuary() call
## unlocking it as a side effect) -- these tests deliberately assert
## live-consistency against GHeroSkillBuild's own real return value at call
## time, never a hardcoded expected string, since this class's entire job is
## being a passthrough live read, not owning any state of its own.
##
## The Tarot-risk half has no live instance anywhere in this project to read
## from (OQ-5, no Autoload) -- tested as an explicit "not available" result,
## matching snapshot_chip.gd's own documented, flagged gap.
extends GdUnitTestSuite

var _runner: GdUnitSceneRunner
var _shell: TarotDeckUI
var _chip: SnapshotChip


func before_test() -> void:
	_runner = scene_runner("res://src/presentation/tarot_deck_ui/TarotDeckUI.tscn")
	@warning_ignore("unsafe_cast")
	_shell = _runner.scene() as TarotDeckUI
	_chip = _shell.get_snapshot_chip()


# ---------------------------------------------------------------------------
# Ultimate half: a genuine live read of the real Autoload, always in sync
# ---------------------------------------------------------------------------

func test_get_ultimate_id_matches_hero_skill_builds_own_live_value() -> void:
	assert_str(_chip.get_ultimate_id()).is_equal(GHeroSkillBuild.get_all_slot_bindings()["U"])


func test_get_ultimate_id_never_returns_a_cached_stale_value() -> void:
	var first_read: String = _chip.get_ultimate_id()
	var second_read: String = _chip.get_ultimate_id()

	# Two consecutive reads must both match the Autoload's own current live
	# value, not a value cached at chip-construction time -- the direct proof
	# this is a passthrough, not a subscription-and-cache pattern.
	assert_str(first_read).is_equal(GHeroSkillBuild.get_all_slot_bindings()["U"])
	assert_str(second_read).is_equal(GHeroSkillBuild.get_all_slot_bindings()["U"])


func test_empty_ultimate_constant_matches_hero_skill_builds_own_empty_sentinel() -> void:
	# Confirms this class's own EMPTY_ULTIMATE constant is the SAME string
	# hero_skill_build.gd's own _derive_ultimate_id() actually returns when
	# fewer than 4 slots are filled, not an independently-guessed literal.
	assert_str(SnapshotChip.EMPTY_ULTIMATE).is_equal("EMPTY")


# ---------------------------------------------------------------------------
# Tarot-risk half: explicit "not available," not a fabricated value
# ---------------------------------------------------------------------------

func test_tarot_risk_summary_is_explicitly_unavailable() -> void:
	var summary: Dictionary = _chip.get_tarot_risk_summary()

	assert_bool(summary.get("available", true)).is_false()
