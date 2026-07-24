class_name TarotModifierEntry
extends Resource

## Story 001 (TR-tarot-001, ADR-0027): nested Resource, not a top-level
## GameDataRegistry entry — lives only inside a TarotCardResource's own
## `modifiers` array. `modifier_type` must be one of Group 3 Rule 7's 4
## registered types; `base_modifier_value` is fixed content, authored once,
## never changed at runtime except by mastery scaling (Formula F1, Story 003).

## Group 3 Rule 7's 4 registered modifier_type values, one mechanism each.
const REGISTERED_MODIFIER_TYPES: Array[StringName] = [
	&"tarot_speed_scalar_mult",
	&"tarot_reward_scalar_mult",
	&"tarot_difficulty_growth_rate",
	&"tarot_wave_config_override",
]

## Story 002 (EC-3/AC-16): REPLACE-mechanism types — only one equipped card
## may target a given one of these at a time (enforced at equip-time by
## Tarot.equip_card()). The other 2 registered types are MULTIPLICATIVE and
## stack freely (Formula F2's own stacking rule).
const REPLACE_MODIFIER_TYPES: Array[StringName] = [
	&"tarot_difficulty_growth_rate",
	&"tarot_wave_config_override",
]

@export var modifier_type: StringName = &""
@export var base_modifier_value: float = 1.0
