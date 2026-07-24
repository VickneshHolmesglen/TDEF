class_name UltimateComboTable
extends Resource

## Maps a 4-active-skill combo to its resulting Ultimate. TD-hero-002.
## Schema: design/gdd/hero.md Rule 9/10 (Story 007, ADR-0010).
##
## Single-resource table, mirroring TowerPerkRegistry's pattern (one .tres file
## for the whole table, not one file per entry — there is no natural per-entry
## identity the way MonsterResource/SkillResource have monster_id/skill_id).
##
## ADR-0030 correction (Epic 08, Story 003, 2026-07-19): `combos` (below) was
## TD-hero-002's original combo-key-lookup derivation mechanism, read
## directly by Hero itself. ADR-0030 supersedes this — Hero Skill Build
## (Autoload #13) now owns Ultimate derivation entirely via a pure
## category-profile -> shape -> Ultimate-ID pipeline, never reading this
## table's `combos` field. `combos` is retained for schema-completeness/any
## future tooling but is no longer read by any production code path.
## `ultimate_cooldowns` (below) is unaffected — Ultimate cooldown remains
## content data keyed by ultimate_id, unrelated to how the ID is derived.
##
## combos[key] = ultimate_id: StringName
##   key = comma-joined, alphabetically-sorted 4 skill-id Strings — historical
##   format from the now-superseded derivation mechanism (see above).
##
## ultimate_cooldowns[ultimate_id: String] = cooldown: float — GDD Rule 10:
## "The Ultimate has its own cooldown defined by its data entry." Keyed
## separately from combos (not nested inside it) since multiple combo keys
## could in principle resolve to the same ultimate_id, and cooldown is a
## property of the Ultimate itself, not of any one combo. TD-hero-003.
## NOTE (Rule 12 scope): CDR does NOT apply to Ultimate cooldown — Rule 12's
## `effective_cooldown = base x (1 - CDR)` formula is explicitly scoped to
## "active skill cooldowns" only. Hero._on_hero_ultimate_activated() uses this
## raw value directly, unlike activate_skill()'s CDR-adjusted cooldown.
##
## Untyped Dictionary exports (not Dictionary[String, StringName]) — matches
## TowerPerkRegistry's own convention, avoiding the empty-typed-dictionary-literal
## engine quirk documented in hero.gd's own field doc comments.
##
## Usage:
##   var table: UltimateComboTable = GGameDataRegistry.get_ultimate_combo_table()
##   var ultimate_id: StringName = table.get_ultimate_for_combo(key)
##   var cooldown: float = table.get_cooldown_for_ultimate(ultimate_id)

@export var combos: Dictionary = {}
@export var ultimate_cooldowns: Dictionary = {}


## Returns the Ultimate StringName for the given combo key, or &"" if no combo
## entry matches (i.e. the 4 equipped skills don't form a recognized Ultimate).
func get_ultimate_for_combo(key: String) -> StringName:
	return combos.get(key, &"")


## Returns the cooldown (seconds) for the given ultimate_id, or 0.0 if no entry
## exists. A 0.0 result means "no cooldown data" — callers should treat this as
## a content-authoring gap, not a legitimate zero-cooldown Ultimate.
func get_cooldown_for_ultimate(ultimate_id: StringName) -> float:
	return ultimate_cooldowns.get(String(ultimate_id), 0.0)


## Load-time validation. Called by GameDataRegistry at boot (ADR-0009).
## Returns [] when valid; one string per invalid/malformed entry otherwise.
func validate() -> Array[String]:
	var errors: Array[String] = []
	for key: Variant in combos.keys():
		if typeof(key) != TYPE_STRING:
			errors.append("combo key is not a String (got %s)" % type_string(typeof(key)))
			continue
		if String(key) == "":
			errors.append("combo key must not be empty")
		var value: Variant = combos[key]
		if typeof(value) != TYPE_STRING_NAME and typeof(value) != TYPE_STRING:
			errors.append("%s: ultimate_id must be a StringName/String (got %s)" % [key, type_string(typeof(value))])
		elif String(value) == "":
			errors.append("%s: ultimate_id must not be empty" % key)
	for ult_key: Variant in ultimate_cooldowns.keys():
		if typeof(ult_key) != TYPE_STRING:
			errors.append("ultimate_cooldowns key is not a String (got %s)" % type_string(typeof(ult_key)))
			continue
		var cd: Variant = ultimate_cooldowns[ult_key]
		if typeof(cd) != TYPE_FLOAT and typeof(cd) != TYPE_INT:
			errors.append("%s: cooldown must be a number (got %s)" % [ult_key, type_string(typeof(cd))])
		elif float(cd) <= 0.0:
			errors.append("%s: cooldown must be > 0.0" % ult_key)
	return errors
