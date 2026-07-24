class_name GameDataRegistry
extends Node

## GameDataRegistry — Autoload #5 (ADR-0009).
##
## Pure data cache for MonsterResource, TowerPerkRegistry, TowerBlueprintData
## blueprints, MissionResource, SkillResource, and UltimateComboTable. No
## per-frame processing — this is a load-once-at-boot registry, not a live system.
##
## _ready() scans res://assets/data/monsters/ for every .tres file, loads
## each as MonsterResource keyed by monster_id, validates it and
## push_error()s per invalid field (does not abort boot). Also preloads and
## validates res://assets/data/towers/perk_registry.tres as TowerPerkRegistry,
## scans res://assets/data/towers/blueprints/ for every .tres file, loads
## each as TowerBlueprintData keyed by tower_id, scans res://assets/data/missions/
## for every .tres file, loads each as MissionResource keyed by mission_id
## (S5-02), scans res://assets/data/missions/entries/ for every .tres file,
## loads each as MissionEntry keyed by mission_id (Story 008 — a separate
## directory from MissionResource's to avoid a directory-scan collision
## between the two mission_id-keyed Resource subclasses), scans
## res://assets/data/skills/ for every .tres file, loads each
## as SkillResource keyed by skill_id (TD-hero-002), preloads/validates
## res://assets/data/skills/ultimate_combo_table.tres as UltimateComboTable
## (TD-hero-002), scans res://assets/data/drop_tables/ for every .tres
## file, loading each as DropTableResource keyed by drop_table_id (Epic 03
## Story 010, ADR-0017), scans res://assets/data/defense_building/tech_nodes/
## for every .tres file, loading each as TechNodeResource keyed by tech_id,
## scans res://assets/data/defense_building/structures/ for every .tres
## file, loading each as StructureResource keyed by structure_id (S018,
## ADR-0024), and scans res://assets/data/items/ for every .tres file,
## loading each as ItemDefinitionResource keyed by item_id (Story 022
## prerequisite fix — closes the gap ItemDefinitionResource's own header
## comment and ADR-0021 both flagged: "intended to live under
## assets/data/items/ and be loaded by GameDataRegistry at boot... that
## loader wiring is deliberately NOT added by Story 001") — all directory
## scans share the same does-not-abort validation policy.
##
## No other system may load MonsterResource, TowerPerkRegistry, TowerBlueprintData,
## MissionResource, MissionEntry, SkillResource, UltimateComboTable, DropTableResource,
## TechNodeResource, StructureResource, or ItemDefinitionResource by path
## directly — all lookups go through get_monster_resource() /
## get_perk_registry() / get_tower_blueprint() / get_mission_resource() /
## get_mission_entry() / get_skill_resource() / get_ultimate_combo_table() / get_drop_table() /
## get_tech_node() / get_structure() / get_item_definition() (S5-01 closing
## TD-data-001; S5-02 for MissionResource; Story 008 for MissionEntry;
## TD-hero-002 for SkillResource/UltimateComboTable; Story 010 for
## DropTableResource; S018 for TechNodeResource/StructureResource; Story 022
## for ItemDefinitionResource).
##
## Usage:
##   var res: MonsterResource = GGameDataRegistry.get_monster_resource(&"goblin_runner")
##   if res == null:
##       push_error("Unknown monster_id — aborting spawn.")
##   var perks: TowerPerkRegistry = GGameDataRegistry.get_perk_registry()
##   var blueprint: TowerBlueprintData = GGameDataRegistry.get_tower_blueprint(&"archer")
##   var mission: MissionResource = GGameDataRegistry.get_mission_resource(&"the_gap")
##   var entry: MissionEntry = GGameDataRegistry.get_mission_entry("the_gap")
##   var skill_def: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(&"phys_cleave")
##   var skill: SkillResource = GGameDataRegistry.get_skill_resource(&"fireball")
##   var combos: UltimateComboTable = GGameDataRegistry.get_ultimate_combo_table()
##   var drop_table: DropTableResource = GGameDataRegistry.get_drop_table(&"goblin_basic")
##   var tech_node: TechNodeResource = GGameDataRegistry.get_tech_node(&"tech_production_2")
##   var structure: StructureResource = GGameDataRegistry.get_structure(&"habitat_expansion_tier_1")
##   var item_def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"iron_ore")

const DEFAULT_MONSTERS_DIR: String = "res://assets/data/monsters/"
const DEFAULT_PERK_REGISTRY_PATH: String = "res://assets/data/towers/perk_registry.tres"
const DEFAULT_TOWER_BLUEPRINTS_DIR: String = "res://assets/data/towers/blueprints/"
const DEFAULT_MISSIONS_DIR: String = "res://assets/data/missions/"
## Separate from DEFAULT_MISSIONS_DIR to avoid a directory-scan collision:
## MissionResource (S5-02, objective text) and MissionEntry (ADR-0028,
## catalogue/grid data) are both keyed by mission_id but are distinct Resource
## subclasses — scanning them from the same directory would push_error() on
## every file for whichever loader runs against the other type's .tres files.
const DEFAULT_MISSION_ENTRIES_DIR: String = "res://assets/data/missions/entries/"
const DEFAULT_SKILLS_DIR: String = "res://assets/data/skills/"
const DEFAULT_ULTIMATE_COMBO_TABLE_PATH: String = "res://assets/data/skills/ultimate_combo_table.tres"
## Separate from DEFAULT_SKILLS_DIR to avoid a directory-scan collision:
## SkillResource (TD-hero-002, cooldown-only) and SkillDefinitionResource
## (ADR-0030, shared Tower Mastery/Hero Skill Build catalogue) are both keyed
## by skill_id but are distinct Resource subclasses.
const DEFAULT_SKILL_DEFINITIONS_DIR: String = "res://assets/data/skills/definitions/"
const DEFAULT_DROP_TABLES_DIR: String = "res://assets/data/drop_tables/"
const DEFAULT_TECH_NODES_DIR: String = "res://assets/data/defense_building/tech_nodes/"
const DEFAULT_STRUCTURES_DIR: String = "res://assets/data/defense_building/structures/"
const DEFAULT_ITEM_DEFINITIONS_DIR: String = "res://assets/data/items/"
const DEFAULT_RECIPES_DIR: String = "res://assets/data/recipes/"
const DEFAULT_SPECIES_DIR: String = "res://assets/data/species/"
const DEFAULT_TAROT_CARDS_DIR: String = "res://assets/data/tarot/"
const DEFAULT_EQUIPMENT_RECIPES_DIR: String = "res://assets/data/equipment_recipes/"
const DEFAULT_SACRIFICE_RECIPES_DIR: String = "res://assets/data/sacrifice_recipes/"

# Test injection seam — override via _inject() before add_child() triggers _ready().
var _monsters_dir: String = DEFAULT_MONSTERS_DIR
var _perk_registry_path: String = DEFAULT_PERK_REGISTRY_PATH
var _tower_blueprints_dir: String = DEFAULT_TOWER_BLUEPRINTS_DIR
var _missions_dir: String = DEFAULT_MISSIONS_DIR
var _mission_entries_dir: String = DEFAULT_MISSION_ENTRIES_DIR
var _skills_dir: String = DEFAULT_SKILLS_DIR
var _ultimate_combo_table_path: String = DEFAULT_ULTIMATE_COMBO_TABLE_PATH
var _skill_definitions_dir: String = DEFAULT_SKILL_DEFINITIONS_DIR
var _equipment_recipes_dir: String = DEFAULT_EQUIPMENT_RECIPES_DIR
var _sacrifice_recipes_dir: String = DEFAULT_SACRIFICE_RECIPES_DIR
var _drop_tables_dir: String = DEFAULT_DROP_TABLES_DIR
var _tech_nodes_dir: String = DEFAULT_TECH_NODES_DIR
var _structures_dir: String = DEFAULT_STRUCTURES_DIR
var _item_definitions_dir: String = DEFAULT_ITEM_DEFINITIONS_DIR
var _recipes_dir: String = DEFAULT_RECIPES_DIR
var _species_dir: String = DEFAULT_SPECIES_DIR
var _tarot_cards_dir: String = DEFAULT_TAROT_CARDS_DIR

var _monster_resources: Dictionary[StringName, MonsterResource] = {}
var _perk_registry: TowerPerkRegistry = null
var _tower_blueprints: Dictionary[StringName, TowerBlueprintData] = {}
var _mission_resources: Dictionary[StringName, MissionResource] = {}
var _mission_entries: Dictionary[String, MissionEntry] = {}
var _skill_resources: Dictionary[StringName, SkillResource] = {}
var _skill_definitions: Dictionary[StringName, SkillDefinitionResource] = {}
var _equipment_recipes: Dictionary[StringName, EquipmentRecipeResource] = {}
var _sacrifice_recipes: Dictionary[StringName, SacrificeRecipeResource] = {}
var _ultimate_combo_table: UltimateComboTable = null
var _drop_tables: Dictionary[StringName, DropTableResource] = {}
var _tech_nodes: Dictionary[StringName, TechNodeResource] = {}
var _structures: Dictionary[StringName, StructureResource] = {}
var _item_definitions: Dictionary[StringName, ItemDefinitionResource] = {}
var _recipes: Dictionary[StringName, RecipeResource] = {}
var _species: Dictionary[StringName, SpeciesResource] = {}
var _tarot_cards: Dictionary[StringName, TarotCardResource] = {}


func _ready() -> void:
	_load_monster_resources()
	_load_perk_registry()
	_load_tower_blueprints()
	_load_mission_resources()
	_load_mission_entries()
	_load_skill_resources()
	_load_skill_definitions()
	_load_ultimate_combo_table()
	_load_drop_tables()
	_load_tech_nodes()
	_load_structures()
	_load_item_definitions()
	_load_recipes()
	_load_species()
	_load_tarot_cards()
	_load_equipment_recipes()
	_load_sacrifice_recipes()


## Inject alternate scan paths before add_child() triggers _ready(). Tests only.
func _inject(monsters_dir: String, perk_registry_path: String, tower_blueprints_dir: String = DEFAULT_TOWER_BLUEPRINTS_DIR, missions_dir: String = DEFAULT_MISSIONS_DIR, skills_dir: String = DEFAULT_SKILLS_DIR, ultimate_combo_table_path: String = DEFAULT_ULTIMATE_COMBO_TABLE_PATH, drop_tables_dir: String = DEFAULT_DROP_TABLES_DIR, tech_nodes_dir: String = DEFAULT_TECH_NODES_DIR, structures_dir: String = DEFAULT_STRUCTURES_DIR, item_definitions_dir: String = DEFAULT_ITEM_DEFINITIONS_DIR, recipes_dir: String = DEFAULT_RECIPES_DIR, species_dir: String = DEFAULT_SPECIES_DIR, tarot_cards_dir: String = DEFAULT_TAROT_CARDS_DIR, mission_entries_dir: String = DEFAULT_MISSION_ENTRIES_DIR, skill_definitions_dir: String = DEFAULT_SKILL_DEFINITIONS_DIR, equipment_recipes_dir: String = DEFAULT_EQUIPMENT_RECIPES_DIR, sacrifice_recipes_dir: String = DEFAULT_SACRIFICE_RECIPES_DIR) -> void:
	_monsters_dir = monsters_dir
	_perk_registry_path = perk_registry_path
	_tower_blueprints_dir = tower_blueprints_dir
	_missions_dir = missions_dir
	_mission_entries_dir = mission_entries_dir
	_skills_dir = skills_dir
	_ultimate_combo_table_path = ultimate_combo_table_path
	_drop_tables_dir = drop_tables_dir
	_tech_nodes_dir = tech_nodes_dir
	_structures_dir = structures_dir
	_item_definitions_dir = item_definitions_dir
	_recipes_dir = recipes_dir
	_species_dir = species_dir
	_tarot_cards_dir = tarot_cards_dir
	_skill_definitions_dir = skill_definitions_dir
	_equipment_recipes_dir = equipment_recipes_dir
	_sacrifice_recipes_dir = sacrifice_recipes_dir


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns the MonsterResource for monster_id, or null if not found/loaded.
## O(1) Dictionary lookup. A non-null result is not a validity guarantee —
## validate() may have logged errors for it at boot without removing it from
## the cache (ADR-0009 Risks: "Invalid MonsterResource at spawn time").
func get_monster_resource(monster_id: StringName) -> MonsterResource:
	return _monster_resources.get(monster_id, null)


## Returns the TowerPerkRegistry. Always non-null after _ready() completes
## UNLESS perk_registry.tres failed to load (missing/corrupt file) — in that
## documented failure case this returns null; the load failure was already
## push_error()'d.
func get_perk_registry() -> TowerPerkRegistry:
	return _perk_registry


## Returns a shallow copy of the monster_id -> MonsterResource cache. A copy,
## not the registry's live Dictionary — callers (e.g. MonsterManager) may
## safely treat the returned table as their own local storage, including
## test code that writes additional entries into it after self-populating.
## The MonsterResource values themselves are still shared references (by
## design — they're immutable data), only the Dictionary container is isolated.
func get_all_monster_resources() -> Dictionary[StringName, MonsterResource]:
	return _monster_resources.duplicate()


## Returns the TowerBlueprintData blueprint for tower_id, or null if not found/loaded.
## O(1) Dictionary lookup. A non-null result is not a validity guarantee —
## validate() may have logged errors for it at boot without removing it from
## the cache (same policy as get_monster_resource()).
func get_tower_blueprint(tower_id: StringName) -> TowerBlueprintData:
	return _tower_blueprints.get(tower_id, null)


## Returns the TarotCardResource for card_id, or null if not found/loaded.
## O(1) Dictionary lookup. A non-null result is not a validity guarantee —
## validate() may have logged errors for it at boot without removing it from
## the cache (same policy as get_monster_resource()).
func get_tarot_card(card_id: StringName) -> TarotCardResource:
	return _tarot_cards.get(card_id, null)


## Returns a shallow copy of the card_id -> TarotCardResource cache. A copy,
## not the registry's live Dictionary — same isolation rationale as
## get_all_tower_blueprints().
func get_all_tarot_cards() -> Dictionary[StringName, TarotCardResource]:
	return _tarot_cards.duplicate()


## Returns a shallow copy of the tower_id -> TowerBlueprintData blueprint cache. A copy,
## not the registry's live Dictionary — callers (e.g. TowerSystem) may safely
## treat the returned table as their own local storage, including test code
## that writes additional entries into it after self-populating. The TowerBlueprintData
## values themselves are still shared references (by design — they're
## immutable data), only the Dictionary container is isolated.
func get_all_tower_blueprints() -> Dictionary[StringName, TowerBlueprintData]:
	return _tower_blueprints.duplicate()


## Returns the MissionResource for mission_id, or null if not found/loaded.
## O(1) Dictionary lookup. A non-null result is not a validity guarantee —
## validate() may have logged errors for it at boot without removing it from
## the cache (same policy as get_monster_resource()).
func get_mission_resource(mission_id: StringName) -> MissionResource:
	return _mission_resources.get(mission_id, null)


## Returns the MissionEntry catalogue data for mission_id, or null if not
## found/loaded. O(1) Dictionary lookup. A non-null result is not a validity
## guarantee — validate() may have logged errors for it at boot without
## removing it from the cache (same policy as get_monster_resource()).
func get_mission_entry(mission_id: String) -> MissionEntry:
	return _mission_entries.get(mission_id, null)


## Returns the SkillResource for skill_id, or null if not found/loaded.
## O(1) Dictionary lookup. A non-null result is not a validity guarantee —
## validate() may have logged errors for it at boot without removing it from
## the cache (same policy as get_monster_resource()).
func get_skill_resource(skill_id: StringName) -> SkillResource:
	return _skill_resources.get(skill_id, null)


## Returns the SkillDefinitionResource for skill_id, or null if not
## found/loaded. Shared catalogue entry (ADR-0030) — Tower Mastery and Hero
## Skill Build both read the same instance, never a second competing copy.
func get_skill_definition(skill_id: StringName) -> SkillDefinitionResource:
	return _skill_definitions.get(skill_id, null)


## Returns a shallow copy of the skill_id -> SkillResource cache. A copy, not
## the registry's live Dictionary — same isolation rationale as
## get_all_monster_resources()/get_all_tower_blueprints() (S5-01: prevents
## shared-mutable-state bugs for callers that self-populate a local table).
func get_all_skill_resources() -> Dictionary[StringName, SkillResource]:
	return _skill_resources.duplicate()


## Returns the UltimateComboTable. Always non-null after _ready() completes
## UNLESS ultimate_combo_table.tres failed to load (missing/corrupt file) — in
## that documented failure case this returns null; the load failure was
## already push_error()'d (same policy as get_perk_registry()).
func get_ultimate_combo_table() -> UltimateComboTable:
	return _ultimate_combo_table


## Returns the DropTableResource for drop_table_id, or null if not found/loaded.
## O(1) Dictionary lookup. A non-null result is not a validity guarantee —
## validate() may have logged errors for it at boot without removing it from
## the cache (same policy as get_monster_resource()). A null result at runtime
## is NOT necessarily a content bug on its own — ResourceEconomy (ADR-0017,
## Epic 03 Story 010) treats an unregistered drop_table_id as a runtime
## warn-once-then-no-drop case, not a hard failure.
func get_drop_table(drop_table_id: StringName) -> DropTableResource:
	return _drop_tables.get(drop_table_id, null)


## Returns the TechNodeResource for tech_id, or null if not found/loaded.
## O(1) Dictionary lookup. A non-null result is not a validity guarantee —
## validate() may have logged errors for it at boot without removing it from
## the cache (same policy as get_monster_resource()).
func get_tech_node(tech_id: StringName) -> TechNodeResource:
	return _tech_nodes.get(tech_id, null)


## Returns a shallow copy of the tech_id -> TechNodeResource cache. A copy,
## not the registry's live Dictionary — same isolation rationale as
## get_all_monster_resources() (S018: prevents shared-mutable-state bugs for
## callers that self-populate a local table).
func get_all_tech_nodes() -> Dictionary[StringName, TechNodeResource]:
	return _tech_nodes.duplicate()


## Returns the StructureResource for structure_id, or null if not found/loaded.
## O(1) Dictionary lookup. A non-null result is not a validity guarantee —
## validate() may have logged errors for it at boot without removing it from
## the cache (same policy as get_monster_resource()).
func get_structure(structure_id: StringName) -> StructureResource:
	return _structures.get(structure_id, null)


## Returns a shallow copy of the structure_id -> StructureResource cache. A
## copy, not the registry's live Dictionary — same isolation rationale as
## get_all_monster_resources() (S018).
func get_all_structures() -> Dictionary[StringName, StructureResource]:
	return _structures.duplicate()


## Returns the ItemDefinitionResource for item_id, or null if not found/loaded.
## O(1) Dictionary lookup. A non-null result is not a validity guarantee —
## validate() may have logged errors for it at boot without removing it from
## the cache (same policy as get_monster_resource()). Story 022 prerequisite
## fix: closes the gap ItemDefinitionResource's own header comment and
## ADR-0021 both flagged — this loader/accessor pair "deliberately NOT added
## by Story 001" now exists so Inventory.has_items() can resolve a slot's
## item_id to its item_type without loading ItemDefinitionResource by path
## itself (Inventory's own "never loads by path" invariant, ADR-0016).
func get_item_definition(item_id: StringName) -> ItemDefinitionResource:
	return _item_definitions.get(item_id, null)


## Returns a shallow copy of the item_id -> ItemDefinitionResource cache. A
## copy, not the registry's live Dictionary — same isolation rationale as
## get_all_monster_resources() (S5-01).
func get_all_item_definitions() -> Dictionary[StringName, ItemDefinitionResource]:
	return _item_definitions.duplicate()


## Returns the RecipeResource for recipe_id, or null if not found/loaded.
## O(1) Dictionary lookup. A non-null result is not a validity guarantee —
## validate() may have logged errors for it at boot without removing it from
## the cache (same policy as get_monster_resource()). Story 001, ADR-0023.
func get_recipe(recipe_id: StringName) -> RecipeResource:
	return _recipes.get(recipe_id, null)


## Returns a shallow copy of the recipe_id -> RecipeResource cache. A copy,
## not the registry's live Dictionary — same isolation rationale as
## get_all_monster_resources() (Story 001).
func get_all_recipes() -> Dictionary[StringName, RecipeResource]:
	return _recipes.duplicate()


## Returns the EquipmentRecipeResource for recipe_id, or null if not
## found/loaded. O(1) Dictionary lookup. A non-null result is not a validity
## guarantee — validate() may have logged errors for it at boot without
## removing it from the cache (same policy as get_monster_resource()).
## Story 009, ADR-0025.
func get_equipment_recipe(recipe_id: StringName) -> EquipmentRecipeResource:
	return _equipment_recipes.get(recipe_id, null)


## Returns a shallow copy of the recipe_id -> EquipmentRecipeResource cache.
## A copy, not the registry's live Dictionary — same isolation rationale as
## get_all_recipes().
func get_all_equipment_recipes() -> Dictionary[StringName, EquipmentRecipeResource]:
	return _equipment_recipes.duplicate()


## Returns the SacrificeRecipeResource for sacrifice_recipe_id, or null if not
## found/loaded. O(1) Dictionary lookup. A non-null result is not a validity
## guarantee — validate() may have logged errors for it at boot without
## removing it from the cache (same policy as get_monster_resource()).
## Story 014, ADR-0025.
func get_sacrifice_recipe(sacrifice_recipe_id: StringName) -> SacrificeRecipeResource:
	return _sacrifice_recipes.get(sacrifice_recipe_id, null)


## Returns a shallow copy of the sacrifice_recipe_id -> SacrificeRecipeResource
## cache. A copy, not the registry's live Dictionary — same isolation
## rationale as get_all_equipment_recipes().
func get_all_sacrifice_recipes() -> Dictionary[StringName, SacrificeRecipeResource]:
	return _sacrifice_recipes.duplicate()


## Returns the SpeciesResource for species_id, or null if not found/loaded.
## Story 007, ADR-0026.
func get_species(species_id: StringName) -> SpeciesResource:
	return _species.get(species_id, null)


## Returns a shallow copy of the species_id -> SpeciesResource cache.
func get_all_species() -> Dictionary[StringName, SpeciesResource]:
	return _species.duplicate()


# ---------------------------------------------------------------------------
# Loaders
# ---------------------------------------------------------------------------

func _load_monster_resources() -> void:
	if not DirAccess.dir_exists_absolute(_monsters_dir):
		push_error("[GameDataRegistry] Monsters directory does not exist: %s" % _monsters_dir)
		return
	for file_name: String in DirAccess.get_files_at(_monsters_dir):
		if not file_name.ends_with(".tres"):
			continue
		var resource: MonsterResource = ResourceLoader.load(_monsters_dir + file_name) as MonsterResource
		if resource == null:
			push_error("[GameDataRegistry] %s: failed to load as MonsterResource." % file_name)
			continue
		var errors: Array[String] = resource.validate()
		for err: String in errors:
			push_error("[GameDataRegistry] %s: %s" % [file_name, err])
		if _monster_resources.has(resource.monster_id):
			push_error("[GameDataRegistry] %s: duplicate monster_id '%s' — overwriting previous entry." % [file_name, resource.monster_id])
		_monster_resources[resource.monster_id] = resource


func _load_perk_registry() -> void:
	_perk_registry = ResourceLoader.load(_perk_registry_path) as TowerPerkRegistry
	if _perk_registry == null:
		push_error("[GameDataRegistry] %s: failed to load as TowerPerkRegistry." % _perk_registry_path)
		return
	var errors: Array[String] = _perk_registry.validate()
	for err: String in errors:
		push_error("[GameDataRegistry] perk_registry.tres: %s" % err)


func _load_tower_blueprints() -> void:
	if not DirAccess.dir_exists_absolute(_tower_blueprints_dir):
		push_error("[GameDataRegistry] Tower blueprints directory does not exist: %s" % _tower_blueprints_dir)
		return
	for file_name: String in DirAccess.get_files_at(_tower_blueprints_dir):
		if not file_name.ends_with(".tres"):
			continue
		var blueprint: TowerBlueprintData = ResourceLoader.load(_tower_blueprints_dir + file_name) as TowerBlueprintData
		if blueprint == null:
			push_error("[GameDataRegistry] %s: failed to load as TowerBlueprintData." % file_name)
			continue
		# TowerBlueprintData.validate() logs its own push_error() per invalid field internally
		# (unlike MonsterResource.validate(), which returns an Array[String] for the
		# caller to log) — the bool return here is only used to decide whether to
		# note the failure at the registry level; the resource is still cached either
		# way, matching _load_monster_resources()'s does-not-abort policy.
		if not blueprint.validate():
			push_error("[GameDataRegistry] %s: TowerBlueprintData failed validation (see errors above)." % file_name)
		if _tower_blueprints.has(blueprint.tower_id):
			push_error("[GameDataRegistry] %s: duplicate tower_id '%s' — overwriting previous entry." % [file_name, blueprint.tower_id])
		_tower_blueprints[blueprint.tower_id] = blueprint


func _load_tarot_cards() -> void:
	if not DirAccess.dir_exists_absolute(_tarot_cards_dir):
		push_error("[GameDataRegistry] Tarot cards directory does not exist: %s" % _tarot_cards_dir)
		return
	for file_name: String in DirAccess.get_files_at(_tarot_cards_dir):
		if not file_name.ends_with(".tres"):
			continue
		var card: TarotCardResource = ResourceLoader.load(_tarot_cards_dir + file_name) as TarotCardResource
		if card == null:
			push_error("[GameDataRegistry] %s: failed to load as TarotCardResource." % file_name)
			continue
		if not card.validate():
			push_error("[GameDataRegistry] %s: TarotCardResource failed validation (see errors above)." % file_name)
		if _tarot_cards.has(card.card_id):
			push_error("[GameDataRegistry] %s: duplicate card_id '%s' — overwriting previous entry." % [file_name, card.card_id])
		_tarot_cards[card.card_id] = card


func _load_mission_resources() -> void:
	if not DirAccess.dir_exists_absolute(_missions_dir):
		push_error("[GameDataRegistry] Missions directory does not exist: %s" % _missions_dir)
		return
	for file_name: String in DirAccess.get_files_at(_missions_dir):
		if not file_name.ends_with(".tres"):
			continue
		var mission: MissionResource = ResourceLoader.load(_missions_dir + file_name) as MissionResource
		if mission == null:
			push_error("[GameDataRegistry] %s: failed to load as MissionResource." % file_name)
			continue
		var errors: Array[String] = mission.validate()
		for err: String in errors:
			push_error("[GameDataRegistry] %s: %s" % [file_name, err])
		if _mission_resources.has(mission.mission_id):
			push_error("[GameDataRegistry] %s: duplicate mission_id '%s' — overwriting previous entry." % [file_name, mission.mission_id])
		_mission_resources[mission.mission_id] = mission


func _load_mission_entries() -> void:
	if not DirAccess.dir_exists_absolute(_mission_entries_dir):
		push_error("[GameDataRegistry] Mission entries directory does not exist: %s" % _mission_entries_dir)
		return
	for file_name: String in DirAccess.get_files_at(_mission_entries_dir):
		if not file_name.ends_with(".tres"):
			continue
		var entry: MissionEntry = ResourceLoader.load(_mission_entries_dir + file_name) as MissionEntry
		if entry == null:
			push_error("[GameDataRegistry] %s: failed to load as MissionEntry." % file_name)
			continue
		var errors: Array[String] = entry.validate()
		for err: String in errors:
			push_error("[GameDataRegistry] %s: %s" % [file_name, err])
		if _mission_entries.has(entry.mission_id):
			push_error("[GameDataRegistry] %s: duplicate mission_id '%s' — overwriting previous entry." % [file_name, entry.mission_id])
		_mission_entries[entry.mission_id] = entry


func _load_skill_resources() -> void:
	if not DirAccess.dir_exists_absolute(_skills_dir):
		push_error("[GameDataRegistry] Skills directory does not exist: %s" % _skills_dir)
		return
	for file_name: String in DirAccess.get_files_at(_skills_dir):
		if not file_name.ends_with(".tres"):
			continue
		# ultimate_combo_table.tres lives in this same directory (single-resource
		# table, not a per-skill file) — skip it here; _load_ultimate_combo_table()
		# handles it via its own dedicated path.
		if _skills_dir + file_name == _ultimate_combo_table_path:
			continue
		var skill: SkillResource = ResourceLoader.load(_skills_dir + file_name) as SkillResource
		if skill == null:
			push_error("[GameDataRegistry] %s: failed to load as SkillResource." % file_name)
			continue
		var errors: Array[String] = skill.validate()
		for err: String in errors:
			push_error("[GameDataRegistry] %s: %s" % [file_name, err])
		if _skill_resources.has(skill.skill_id):
			push_error("[GameDataRegistry] %s: duplicate skill_id '%s' — overwriting previous entry." % [file_name, skill.skill_id])
		_skill_resources[skill.skill_id] = skill


func _load_skill_definitions() -> void:
	if not DirAccess.dir_exists_absolute(_skill_definitions_dir):
		push_error("[GameDataRegistry] Skill definitions directory does not exist: %s" % _skill_definitions_dir)
		return
	for file_name: String in DirAccess.get_files_at(_skill_definitions_dir):
		if not file_name.ends_with(".tres"):
			continue
		var definition: SkillDefinitionResource = ResourceLoader.load(_skill_definitions_dir + file_name) as SkillDefinitionResource
		if definition == null:
			push_error("[GameDataRegistry] %s: failed to load as SkillDefinitionResource." % file_name)
			continue
		var errors: Array[String] = definition.validate()
		for err: String in errors:
			push_error("[GameDataRegistry] %s: %s" % [file_name, err])
		if _skill_definitions.has(definition.skill_id):
			push_error("[GameDataRegistry] %s: duplicate skill_id '%s' — overwriting previous entry." % [file_name, definition.skill_id])
		_skill_definitions[definition.skill_id] = definition


func _load_ultimate_combo_table() -> void:
	_ultimate_combo_table = ResourceLoader.load(_ultimate_combo_table_path) as UltimateComboTable
	if _ultimate_combo_table == null:
		push_error("[GameDataRegistry] %s: failed to load as UltimateComboTable." % _ultimate_combo_table_path)
		return
	var errors: Array[String] = _ultimate_combo_table.validate()
	for err: String in errors:
		push_error("[GameDataRegistry] ultimate_combo_table.tres: %s" % err)


func _load_drop_tables() -> void:
	if not DirAccess.dir_exists_absolute(_drop_tables_dir):
		push_error("[GameDataRegistry] Drop tables directory does not exist: %s" % _drop_tables_dir)
		return
	for file_name: String in DirAccess.get_files_at(_drop_tables_dir):
		if not file_name.ends_with(".tres"):
			continue
		var drop_table: DropTableResource = ResourceLoader.load(_drop_tables_dir + file_name) as DropTableResource
		if drop_table == null:
			push_error("[GameDataRegistry] %s: failed to load as DropTableResource." % file_name)
			continue
		var errors: Array[String] = drop_table.validate()
		for err: String in errors:
			push_error("[GameDataRegistry] %s: %s" % [file_name, err])
		if _drop_tables.has(drop_table.drop_table_id):
			push_error("[GameDataRegistry] %s: duplicate drop_table_id '%s' — overwriting previous entry." % [file_name, drop_table.drop_table_id])
		_drop_tables[drop_table.drop_table_id] = drop_table


func _load_tech_nodes() -> void:
	if not DirAccess.dir_exists_absolute(_tech_nodes_dir):
		push_error("[GameDataRegistry] Tech nodes directory does not exist: %s" % _tech_nodes_dir)
		return
	for file_name: String in DirAccess.get_files_at(_tech_nodes_dir):
		if not file_name.ends_with(".tres"):
			continue
		var tech_node: TechNodeResource = ResourceLoader.load(_tech_nodes_dir + file_name) as TechNodeResource
		if tech_node == null:
			push_error("[GameDataRegistry] %s: failed to load as TechNodeResource." % file_name)
			continue
		var errors: Array[String] = tech_node.validate()
		for err: String in errors:
			push_error("[GameDataRegistry] %s: %s" % [file_name, err])
		if _tech_nodes.has(tech_node.tech_id):
			push_error("[GameDataRegistry] %s: duplicate tech_id '%s' — overwriting previous entry." % [file_name, tech_node.tech_id])
		_tech_nodes[tech_node.tech_id] = tech_node


func _load_structures() -> void:
	if not DirAccess.dir_exists_absolute(_structures_dir):
		push_error("[GameDataRegistry] Structures directory does not exist: %s" % _structures_dir)
		return
	for file_name: String in DirAccess.get_files_at(_structures_dir):
		if not file_name.ends_with(".tres"):
			continue
		var structure: StructureResource = ResourceLoader.load(_structures_dir + file_name) as StructureResource
		if structure == null:
			push_error("[GameDataRegistry] %s: failed to load as StructureResource." % file_name)
			continue
		var errors: Array[String] = structure.validate()
		for err: String in errors:
			push_error("[GameDataRegistry] %s: %s" % [file_name, err])
		if _structures.has(structure.structure_id):
			push_error("[GameDataRegistry] %s: duplicate structure_id '%s' — overwriting previous entry." % [file_name, structure.structure_id])
		_structures[structure.structure_id] = structure


func _load_item_definitions() -> void:
	if not DirAccess.dir_exists_absolute(_item_definitions_dir):
		push_error("[GameDataRegistry] Item definitions directory does not exist: %s" % _item_definitions_dir)
		return
	for file_name: String in DirAccess.get_files_at(_item_definitions_dir):
		if not file_name.ends_with(".tres"):
			continue
		var item_definition: ItemDefinitionResource = ResourceLoader.load(_item_definitions_dir + file_name) as ItemDefinitionResource
		if item_definition == null:
			push_error("[GameDataRegistry] %s: failed to load as ItemDefinitionResource." % file_name)
			continue
		var errors: Array[String] = item_definition.validate()
		for err: String in errors:
			push_error("[GameDataRegistry] %s: %s" % [file_name, err])
		if _item_definitions.has(item_definition.item_id):
			push_error("[GameDataRegistry] %s: duplicate item_id '%s' — overwriting previous entry." % [file_name, item_definition.item_id])
		_item_definitions[item_definition.item_id] = item_definition


func _load_recipes() -> void:
	if not DirAccess.dir_exists_absolute(_recipes_dir):
		push_error("[GameDataRegistry] Recipes directory does not exist: %s" % _recipes_dir)
		return
	for file_name: String in DirAccess.get_files_at(_recipes_dir):
		if not file_name.ends_with(".tres"):
			continue
		var recipe: RecipeResource = ResourceLoader.load(_recipes_dir + file_name) as RecipeResource
		if recipe == null:
			push_error("[GameDataRegistry] %s: failed to load as RecipeResource." % file_name)
			continue
		var errors: Array[String] = recipe.validate()
		for err: String in errors:
			push_error("[GameDataRegistry] %s: %s" % [file_name, err])
		if _recipes.has(recipe.recipe_id):
			push_error("[GameDataRegistry] %s: duplicate recipe_id '%s' — overwriting previous entry." % [file_name, recipe.recipe_id])
		_recipes[recipe.recipe_id] = recipe


func _load_species() -> void:
	if not DirAccess.dir_exists_absolute(_species_dir):
		push_error("[GameDataRegistry] Species directory does not exist: %s" % _species_dir)
		return
	for file_name: String in DirAccess.get_files_at(_species_dir):
		if not file_name.ends_with(".tres"):
			continue
		var species: SpeciesResource = ResourceLoader.load(_species_dir + file_name) as SpeciesResource
		if species == null:
			push_error("[GameDataRegistry] %s: failed to load as SpeciesResource." % file_name)
			continue
		var errors: Array[String] = species.validate()
		for err: String in errors:
			push_error("[GameDataRegistry] %s: %s" % [file_name, err])
		if _species.has(species.species_id):
			push_error("[GameDataRegistry] %s: duplicate species_id '%s' — overwriting previous entry." % [file_name, species.species_id])
		_species[species.species_id] = species


func _load_equipment_recipes() -> void:
	if not DirAccess.dir_exists_absolute(_equipment_recipes_dir):
		push_error("[GameDataRegistry] Equipment recipes directory does not exist: %s" % _equipment_recipes_dir)
		return
	for file_name: String in DirAccess.get_files_at(_equipment_recipes_dir):
		if not file_name.ends_with(".tres"):
			continue
		var recipe: EquipmentRecipeResource = ResourceLoader.load(_equipment_recipes_dir + file_name) as EquipmentRecipeResource
		if recipe == null:
			push_error("[GameDataRegistry] %s: failed to load as EquipmentRecipeResource." % file_name)
			continue
		var errors: Array[String] = recipe.validate()
		for err: String in errors:
			push_error("[GameDataRegistry] %s: %s" % [file_name, err])
		if _equipment_recipes.has(recipe.recipe_id):
			push_error("[GameDataRegistry] %s: duplicate recipe_id '%s' — overwriting previous entry." % [file_name, recipe.recipe_id])
		_equipment_recipes[recipe.recipe_id] = recipe


func _load_sacrifice_recipes() -> void:
	if not DirAccess.dir_exists_absolute(_sacrifice_recipes_dir):
		push_error("[GameDataRegistry] Sacrifice recipes directory does not exist: %s" % _sacrifice_recipes_dir)
		return
	for file_name: String in DirAccess.get_files_at(_sacrifice_recipes_dir):
		if not file_name.ends_with(".tres"):
			continue
		var recipe: SacrificeRecipeResource = ResourceLoader.load(_sacrifice_recipes_dir + file_name) as SacrificeRecipeResource
		if recipe == null:
			push_error("[GameDataRegistry] %s: failed to load as SacrificeRecipeResource." % file_name)
			continue
		var errors: Array[String] = recipe.validate()
		for err: String in errors:
			push_error("[GameDataRegistry] %s: %s" % [file_name, err])
		if _sacrifice_recipes.has(recipe.sacrifice_recipe_id):
			push_error("[GameDataRegistry] %s: duplicate sacrifice_recipe_id '%s' — overwriting previous entry." % [file_name, recipe.sacrifice_recipe_id])
		_sacrifice_recipes[recipe.sacrifice_recipe_id] = recipe
