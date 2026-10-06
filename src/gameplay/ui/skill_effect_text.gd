class_name SkillEffectText
extends RefCounted

## Player-facing text for a hero skill (skill effect UI, 2026-10-07): its
## secondary effect as one sentence, and a one-line stats summary. Shared by
## the Skill Build screen's detail panel and the Skill Tree's choice buttons
## so both always describe a skill the same way. Static; uses
## TranslationServer (strings.csv SKILL_EFFECT_* / SKILL_DETAIL_* keys).
##
## Example: `SkillEffectText.describe_effect(skill.effect_data)`
##   -> "Slows the target by 30% for 2s."


## One sentence for `data.secondary_effect`, or "" when the skill has none.
static func describe_effect(data: HeroSkillEffectResource) -> String:
	if data == null:
		return ""
	var v: float = data.secondary_value
	var d: float = data.secondary_duration
	match data.secondary_effect:
		"dot_burn":
			return _t("SKILL_EFFECT_DOT_BURN") % [_pct(v), _secs(d)]
		"dot_poison":
			return _t("SKILL_EFFECT_DOT_POISON") % [_pct(v), _secs(d)]
		"dot_bleed":
			return _t("SKILL_EFFECT_DOT_BLEED") % [data.bleed_stacks, _pct(data.bleed_value),
				_secs(data.bleed_duration), MonsterManager.BLEED_MAX_STACKS]
		"dot_haemorrhage":
			return _t("SKILL_EFFECT_DOT_HAEMORRHAGE") % [data.bleed_stacks, _pct(data.bleed_value),
				_secs(data.bleed_duration), MonsterManager.BLEED_MAX_STACKS, _num(MonsterManager.HAEMORRHAGE_RUPTURE_MULTIPLIER)]
		"slow":
			return _t("SKILL_EFFECT_SLOW") % [_pct(v), _secs(d)]
		"stun":
			return _t("SKILL_EFFECT_STUN") % _secs(d)
		"armor_shred":
			return _t("SKILL_EFFECT_ARMOR_SHRED") % [_pct(v), _secs(d)]
		"knockback":
			return _t("SKILL_EFFECT_KNOCKBACK") % _num(v)
		"chain":
			return _t("SKILL_EFFECT_CHAIN") % [data.secondary_count, _num(Hero.CHAIN_RADIUS_CELLS), _pct(v)]
		"lifesteal_bonus":
			return _t("SKILL_EFFECT_LIFESTEAL_BONUS") % [_pct(v), _secs(d)]
	return ""


## "Ice · Cooldown 4s · Power x1.2" (damage type, cooldown, power coefficient).
static func describe_stats(skill: SkillDefinitionResource) -> String:
	if skill == null or skill.effect_data == null:
		return ""
	var type_key: String = "SKILL_DAMAGE_TYPE_%s" % (skill.effect_data.damage_type.to_upper() if not skill.effect_data.damage_type.is_empty() else "SUPPORT")
	return _t("SKILL_DETAIL_STATS") % [_t(type_key), _secs(skill.base_cooldown), _num(skill.effect_data.skill_power_coefficient)]


## The full multi-line detail for a skill: name, stats line, and effect line
## (the effect line is omitted for skills without a secondary effect).
static func describe_skill(skill: SkillDefinitionResource) -> String:
	if skill == null:
		return ""
	var lines: Array[String] = [skill.display_name if not skill.display_name.is_empty() else String(skill.skill_id),
		describe_stats(skill)]
	var effect: String = describe_effect(skill.effect_data)
	if not effect.is_empty():
		lines.append(_t("SKILL_EFFECT_LINE") % effect)
	return "\n".join(lines)


static func _t(key: String) -> String:
	return TranslationServer.translate(key)


## 0.3 -> "30", 0.015 -> "1.5"
static func _pct(fraction: float) -> String:
	return _num(snappedf(fraction * 100.0, 0.1))


## 2.0 -> "2s", 0.75 -> "0.75s"
static func _secs(seconds: float) -> String:
	return "%ss" % _num(seconds)


## Drops a trailing ".0": 2.0 -> "2", 1.5 -> "1.5".
static func _num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return String.num(value, 2).rstrip("0").rstrip(".")
