class_name SanctuaryGold
extends Node

## Resource Economy's persistent half (design/quick-specs/sanctuary-gold-2026-11-05.md,
## resource-economy.md Rule 11): the Sanctuary gold balance.
##
## Gold is still only EARNED in missions (Rules 8/10/10b, GMissionEconomy).
## When a mission ends (MISSION_COMPLETE or DEFEAT) the gold the player still
## holds is banked here at the conversion rate: BASE_CONVERSION_RATE, raised
## by each owned Treasury tech (Defense Building, economy_tech column). It is
## spent in the Equipment Forge: crafting, imbuing a rune, adding a rune slot.
##
## Autoload GSanctuaryGold: the per-mission ResourceEconomy node is rebuilt
## with every mission scene, so the persistent balance lives here. Saved via
## GSavePersistence (key "sanctuary_gold"); a save without the key restores 0.
##
## Usage:
##   if GSanctuaryGold.can_afford(SanctuaryGold.craft_cost(recipe.quality_tier)):
##       GSanctuaryGold.spend(cost, &"forge_craft")

const RESTORE_ORDER: int = 38

## Share of the held mission gold banked at mission end with no Treasury tech.
const BASE_CONVERSION_RATE: float = 0.25
## Added per owned Treasury tech (3 techs -> 0.55).
const CONVERSION_RATE_PER_TECH: float = 0.10
const TREASURY_TECH_IDS: Array[StringName] = [&"tech_treasury_1", &"tech_treasury_2", &"tech_treasury_3"]

## Forge prices (tuned with tools/balance/progression_sim.py, 2026-11-05: see the
## sanctuary-gold spec). Crafting is CRAFT_COST_BASE x quality tier (80/160/240/320;
## tier 5 pays the tier-4 price): gold is planned around through the campaign
## without a wall. A doubling curve (T4 640) left tier-4 pieces waiting 20+ visits.
const CRAFT_COST_BASE: int = 80
const IMBUE_COST: int = 100
## Adding a rune slot: this x (slots already added + 1), on top of its shards.
## The endgame sink: ~10 worn items x 2 slots = ~7,500 gold, about what banks
## after the gear catalogue saturates.
const RUNE_SLOT_COST_STEP: int = 250

const SOURCE_MISSION_BANK: StringName = &"mission_bank"

var _balance: int = 0
## True between mission_launched and the mission's end bank, so a phase
## re-emit can never bank the same mission twice.
var _bank_pending: bool = false


func _ready() -> void:
	GSavePersistence.register(self, RESTORE_ORDER)
	GEventBus.mission_launched.connect(_on_mission_launched)
	GEventBus.mission_phase_changed.connect(_on_mission_phase_changed)


func _exit_tree() -> void:
	GSavePersistence.unregister(self)
	GEventBus.mission_launched.disconnect(_on_mission_launched)
	GEventBus.mission_phase_changed.disconnect(_on_mission_phase_changed)


func get_balance() -> int:
	return _balance


func can_afford(cost: int) -> bool:
	return cost <= _balance


## Spends `cost` (rejected in full, nothing spent, when short). Emits
## sanctuary_gold_changed(balance, -cost, source) on success.
func spend(cost: int, source: StringName) -> bool:
	if cost < 0 or cost > _balance:
		return false
	if cost == 0:
		return true
	_balance -= cost
	GEventBus.sanctuary_gold_changed.emit(_balance, -cost, source)
	return true


## Adds `amount` (ignored when <= 0).
func add(amount: int, source: StringName) -> void:
	if amount <= 0:
		return
	_balance += amount
	GEventBus.sanctuary_gold_changed.emit(_balance, amount, source)


## Current mission-to-Sanctuary conversion rate.
func conversion_rate() -> float:
	var owned: int = 0
	for tech_id: StringName in TREASURY_TECH_IDS:
		if GDefenseBuilding.is_tech_unlocked(tech_id):
			owned += 1
	return conversion_rate_for(owned)


static func conversion_rate_for(treasury_techs_owned: int) -> float:
	return BASE_CONVERSION_RATE + CONVERSION_RATE_PER_TECH * float(clampi(treasury_techs_owned, 0, TREASURY_TECH_IDS.size()))


## Sanctuary gold banked from `mission_gold` held at mission end.
static func banked_amount(mission_gold: int, rate: float) -> int:
	return int(floor(float(maxi(0, mission_gold)) * rate))


static func craft_cost(quality_tier: int) -> int:
	return CRAFT_COST_BASE * clampi(quality_tier, 1, 4)


static func rune_slot_cost(extra_slots_owned: int) -> int:
	return RUNE_SLOT_COST_STEP * (maxi(0, extra_slots_owned) + 1)


func _on_mission_launched(_mission_id: String, _modifiers: PackedStringArray, _difficulty_tier: int) -> void:
	_bank_pending = true


func _on_mission_phase_changed(_previous_phase: String, new_phase: String, _timestamp: float) -> void:
	if not _bank_pending or (new_phase != "MISSION_COMPLETE" and new_phase != "DEFEAT"):
		return
	_bank_pending = false
	# Hoarder temperament (menagerie-rehoming spec) raises the effective rate.
	var rate: float = conversion_rate() * (1.0 + GMenagerie.trait_bonus(Temperament.HOARDER))
	add(banked_amount(GMissionEconomy.get_gold_balance(), rate), SOURCE_MISSION_BANK)


func get_save_key() -> String:
	return "sanctuary_gold"


func get_save_data() -> Dictionary:
	return {"balance": _balance}


## False on malformed data so SavePersistence falls back to reset_to_defaults().
func restore_save_data(data: Dictionary) -> bool:
	var raw: Variant = data.get("balance", null)
	if not (raw is int) or (raw as int) < 0:
		return false
	_balance = raw as int
	return true


func reset_to_defaults() -> void:
	_balance = 0
