extends GdUnitTestSuite

## Unit tests for SkillEffectText (skill effect UI, 2026-10-07): one sentence
## per secondary effect, read from the real skill data.


func _effect(skill_id: StringName) -> String:
	return SkillEffectText.describe_effect(GGameDataRegistry.get_skill_definition(skill_id).effect_data)


func test_every_secondary_effect_in_use_has_a_translated_sentence() -> void:
	for skill: SkillDefinitionResource in GGameDataRegistry.get_all_skill_definitions().values():
		var text: String = SkillEffectText.describe_effect(skill.effect_data)
		if skill.effect_data.secondary_effect == "none":
			assert_str(text).override_failure_message(String(skill.skill_id)).is_empty()
		else:
			assert_str(text).override_failure_message("%s has no text" % skill.skill_id).is_not_empty()
			assert_str(text).override_failure_message("%s shows a raw key" % skill.skill_id).not_contains("SKILL_EFFECT_")


func test_sentences_carry_the_skill_numbers() -> void:
	assert_str(_effect(&"elem_frostbolt")).is_equal("Slows the target by 30% for 2s.")
	assert_str(_effect(&"phys_shatter_slam")).is_equal("Stuns the target for 1.25s (half as long on bosses).")
	assert_str(_effect(&"elem_arc_lightning")).is_equal("Chains to 3 more enemies within 3 cells at 70% power.")
	assert_str(_effect(&"phys_last_stand")).is_equal("On cast: +10% lifesteal for 6s.")
	assert_str(_effect(&"phys_cleave")).is_equal("Adds 1 bleed stack(s) - 4% of the target's HP per stack over 8s (up to 5 stacks).")
	assert_str(_effect(&"phys_whirling_assault")).contains("ruptures for 1.5x")


func test_a_skill_without_an_effect_omits_the_effect_line() -> void:
	var text: String = SkillEffectText.describe_skill(GGameDataRegistry.get_skill_definition(&"rng_volley"))
	assert_str(text).contains("Physical")
	assert_str(text).not_contains("Effect:")


func test_support_skills_are_labelled_support() -> void:
	assert_str(SkillEffectText.describe_stats(GGameDataRegistry.get_skill_definition(&"phys_bulwark"))).starts_with("Support")
