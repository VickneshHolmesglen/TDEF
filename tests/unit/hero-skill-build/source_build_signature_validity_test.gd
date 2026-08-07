## Regression guard for the source_build_signature/real-tower-component
## mismatch found and fixed 2026-08-07 (commit fa79af9): a prior audit only
## confirmed each of the 8 skill definitions' source_build_signature field
## was non-empty, never that its value corresponded to a real, buildable
## tower's actual component_id 4-tuple. 7 of 8 referenced component IDs that
## existed nowhere in the game (found_fire_t1, weap_bulwark_t1,
## focus_volley_t1, etc.) -- permanently unlearnable via Tower Mastery's
## proximity-accrual mechanism, since no real tower could ever produce a
## matching signature.
##
## Exercises the real GGameDataRegistry Autoload (both skill definitions and
## tower blueprints are static, boot-loaded content -- no injection needed,
## matching hero_skill_build_screen_test.gd's own "real Autoload" precedent).
extends GdUnitTestSuite

## All 8 real Alpha-scope skill_ids (hero-skill-build.md Rule 3).
const ALL_SKILL_IDS: Array[StringName] = [
	&"phys_cleave", &"phys_bulwark",
	&"elem_frostbolt", &"elem_firestorm",
	&"rng_piercing_shot", &"rng_volley",
	&"sup_rally", &"sup_barrier",
]


## Builds the real signature ("found|weap|focus|power" component_id tuple)
## for every currently-authored tower blueprint.
func _real_tower_signatures() -> Dictionary:
	var signatures: Dictionary = {}
	var blueprints: Dictionary[StringName, TowerBlueprintData] = GGameDataRegistry.get_all_tower_blueprints()
	for tower_id: StringName in blueprints:
		var bp: TowerBlueprintData = blueprints[tower_id]
		var sig: String = "%s|%s|%s|%s" % [
			bp.foundation.component_id, bp.weapon.component_id,
			bp.focus.component_id, bp.power.component_id,
		]
		signatures[sig] = tower_id
	return signatures


## tower-mastery.md Rule 7: "A single signature may map to at most one skill
## at MVP." Every non-empty source_build_signature across all 8 skills must
## therefore be unique.
func test_no_two_skills_share_the_same_non_empty_signature() -> void:
	var seen: Dictionary = {}
	for skill_id: StringName in ALL_SKILL_IDS:
		var definition: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(skill_id)
		assert_object(definition).is_not_null()
		var sig: String = String(definition.source_build_signature)
		if sig == "":
			continue
		assert_bool(seen.has(sig)) \
			.override_failure_message("Duplicate source_build_signature '%s' shared by '%s' and '%s'" % [sig, seen.get(sig, ""), skill_id]) \
			.is_false()
		seen[sig] = skill_id


## Every non-empty source_build_signature must correspond to a real tower's
## actual authored component_id 4-tuple -- hero-skill-build.md's own
## explicit allowance is an EMPTY string for "unreachable via mastery"
## (AC-2), never a signature that merely looks plausible but matches no real
## tower.
func test_every_non_empty_signature_matches_a_real_tower() -> void:
	var real_signatures: Dictionary = _real_tower_signatures()
	for skill_id: StringName in ALL_SKILL_IDS:
		var definition: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(skill_id)
		var sig: String = String(definition.source_build_signature)
		if sig == "":
			continue
		assert_bool(real_signatures.has(sig)) \
			.override_failure_message("skill '%s' has source_build_signature '%s', which matches no real tower's component_id tuple" % [skill_id, sig]) \
			.is_true()


## At least one skill must be genuinely reachable via mastery -- guards
## against a future regression that empties every signature at once (e.g. an
## overzealous "just clear it" fix), which would silently make Tower Mastery
## unable to teach any skill at all.
func test_at_least_one_skill_has_a_real_reachable_signature() -> void:
	var reachable_count: int = 0
	for skill_id: StringName in ALL_SKILL_IDS:
		var definition: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(skill_id)
		if String(definition.source_build_signature) != "":
			reachable_count += 1
	assert_int(reachable_count).is_greater(0)
