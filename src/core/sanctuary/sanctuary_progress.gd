class_name SanctuaryProgress
extends RefCounted

## Per-tab progress scores for the Sanctuary town buildings (sanctuary town
## buildings spec, 2026-10-07, §2-3). Pure and static: reads the real systems
## (autoloads, plus the scene-instanced Crafting/EquipmentForge found by group)
## and returns 0-1 scores; a missing system contributes 0, never an error.
##
## Example:
##   var scores := SanctuaryProgress.scores(get_tree())   # {&"armoury": 0.35, ...}
##   var tier := SanctuaryProgress.tier_for(scores[&"armoury"])  # 2

const TIER_COUNT: int = 5
## Menagerie: creatures kept count fully at this many (spec §2).
const MENAGERIE_CREATURE_TARGET: int = 12
## Blacksmith: runes known count fully at this many (runes are discovered, not catalogued).
const BLACKSMITH_RUNE_TARGET: int = 8

const BUILDING_IDS: Array[StringName] = [
	&"armoury", &"menagerie", &"keep", &"blacksmith", &"training_hall", &"seers_tower",
]


## 1 + floor(score x 5), clamped to 1..5 (tier 2 at 20%, ..., tier 5 at 80%).
static func tier_for(score: float) -> int:
	return clampi(1 + int(floor(clampf(score, 0.0, 1.0) * TIER_COUNT)), 1, TIER_COUNT)


## Every building's score, plus &"castle" (the mean of the six).
static func scores(tree: SceneTree) -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = {
		&"armoury": armoury(tree),
		&"menagerie": menagerie(),
		&"keep": keep(),
		&"blacksmith": blacksmith(tree),
		&"training_hall": training_hall(),
		&"seers_tower": seers_tower(),
	}
	var total: float = 0.0
	for id: StringName in BUILDING_IDS:
		total += out[id]
	out[&"castle"] = total / float(BUILDING_IDS.size())
	return out


static func armoury(tree: SceneTree) -> float:
	var tier_part: float = _ratio(GInventory.get_current_slot_tier(), SlotExpansionCostTable.MAX_TIER)
	var discovered: int = 0
	var crafting: Node = tree.get_first_node_in_group(Crafting.GROUP_NAME) if tree != null else null
	if crafting != null:
		for recipe_id: StringName in GGameDataRegistry.get_all_recipes():
			if crafting.is_discovered(recipe_id):
				discovered += 1
	return 0.5 * tier_part + 0.5 * _ratio(discovered, GGameDataRegistry.get_all_recipes().size())


static func menagerie() -> float:
	var creatures: Array = GMenagerie.get_all_creatures()
	var species: Dictionary = {}
	for creature: Variant in creatures:
		species[(creature as CreatureInstance).species] = true
	return 0.5 * minf(1.0, _ratio(creatures.size(), MENAGERIE_CREATURE_TARGET)) \
		+ 0.5 * _ratio(species.size(), GGameDataRegistry.get_all_species().size())


static func keep() -> float:
	var done: int = 0
	for tech_id: StringName in GGameDataRegistry.get_all_tech_nodes():
		if GDefenseBuilding.is_tech_unlocked(tech_id):
			done += 1
	for structure_id: StringName in GGameDataRegistry.get_all_structures():
		if GDefenseBuilding.is_structure_built(structure_id):
			done += 1
	return _ratio(done, GGameDataRegistry.get_all_tech_nodes().size() + GGameDataRegistry.get_all_structures().size())


static func blacksmith(tree: SceneTree) -> float:
	var forge: Node = tree.get_first_node_in_group(EquipmentForge.GROUP_NAME) if tree != null else null
	if forge == null:
		return 0.0
	var discovered: int = 0
	for recipe_id: StringName in GGameDataRegistry.get_all_equipment_recipes():
		if forge.is_discovered(recipe_id):
			discovered += 1
	var runes: int = (forge.get_all_available_runes() as Dictionary).size()
	return 0.5 * _ratio(discovered, GGameDataRegistry.get_all_equipment_recipes().size()) \
		+ 0.5 * minf(1.0, _ratio(runes, BLACKSMITH_RUNE_TARGET))


static func training_hall() -> float:
	var unlocked: int = 0
	for archetype: String in HeroSkillTree.ARCHETYPES:
		for node_index: int in HeroSkillTree.NODES_PER_CHAIN:
			if bool(GHeroSkillTree.get_node_state(archetype, node_index).get("unlocked", false)):
				unlocked += 1
	var all_nodes: int = HeroSkillTree.ARCHETYPES.size() * HeroSkillTree.NODES_PER_CHAIN
	var learned: int = GHeroSkillBuild.get_assignable_skills().size()
	return 0.6 * _ratio(unlocked, all_nodes) + 0.4 * _ratio(learned, GGameDataRegistry.get_all_skill_definitions().size())


static func seers_tower() -> float:
	var cards: Dictionary = GGameDataRegistry.get_all_tarot_cards()
	var unlocked: int = 0
	var mastery_total: int = 0
	for card_id: StringName in cards:
		if GTarot.is_card_unlocked(card_id):
			unlocked += 1
			mastery_total += GTarot.get_mastery_tier(card_id)
	var max_mastery: int = Tarot.MASTERY_TIER_THRESHOLDS.size() - 1
	var mean_mastery: float = _ratio(mastery_total, unlocked * max_mastery)
	return 0.6 * _ratio(unlocked, cards.size()) + 0.4 * mean_mastery


static func _ratio(part: float, whole: float) -> float:
	return clampf(part / whole, 0.0, 1.0) if whole > 0.0 else 0.0
