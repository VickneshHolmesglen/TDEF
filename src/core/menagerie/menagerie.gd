class_name Menagerie
extends Node

## Menagerie's creature roster and Lure acquisition action (Story 007,
## TR-menag-001, ADR-0026).
##
## Autoload #11 (ADR-0026 Decision) — required so request_sacrifice()
## (Story 016) is callable as a bare global from Equipment Forge (Criterion
## B, ADR-0020). Registered in project.godot as GMenagerie.
##
## _creatures: all creature instances ever created (RESERVE/HABITAT/
## BREEDING_PEN/SACRIFICED — terminal, never removed from the array).
## _breeding_pens: fixed 2 (Story 015 scope). _habitat_capacity: base 4,
## +2 per Habitat Expansion tier (Story 009 scope — this story only
## declares the field). _next_creature_id: monotonic counter, same pattern
## as Inventory's _next_instance_id (ADR-0016).
##
## Lure (Rule 1/3, Formula 4): a deterministic, player-initiated action — no
## RNG anywhere in species, cost, or starting state. Formula 4:
## lure_cost(tier) = base_lure_cost(3) × tier. Consumes the SPECIFIC
## `menagerie_lure` item (Inventory.has_item_quantity()/consume_stackable() —
## NOT has_items(), which sums by item_type and would incorrectly aggregate
## menagerie_lure with other item_type="Material" items).

const BASE_LURE_COST: int = 3
const HABITAT_BASE_CAPACITY: int = 4
const HABITAT_CAPACITY_PER_TIER: int = 2
const HABITAT_MAX_TIERS: int = 4  ## 2026-08-03: real Habitat Expansion Tier 4 added (defense-building.md Core Rule 5)
const HABITAT_MAX_CAPACITY: int = HABITAT_BASE_CAPACITY + HABITAT_CAPACITY_PER_TIER * HABITAT_MAX_TIERS  # 12
const RESTORE_ORDER: int = 20  ## save-persistence.md's authoritative table — after Inventory (10)

var _creatures: Array[CreatureInstance] = []
var _breeding_pens: Array[BreedingPen] = [BreedingPen.new(), BreedingPen.new()]
var _habitat_capacity: int = HABITAT_BASE_CAPACITY
var _next_creature_id: int = 0


func _ready() -> void:
	GEventBus.sanctuary_structure_built.connect(_on_sanctuary_structure_built)
	GEventBus.mission_launched.connect(_on_mission_launched)
	GSavePersistence.register(self, RESTORE_ORDER)


func _exit_tree() -> void:
	GEventBus.sanctuary_structure_built.disconnect(_on_sanctuary_structure_built)
	GEventBus.mission_launched.disconnect(_on_mission_launched)
	GSavePersistence.unregister(self)


## Story 013 (AC-19/AC-42): the sole tick source — never _process()/
## _physics_process(). Two separate, non-interleaved passes (ADR-0026's
## explicit sequencing requirement, mirroring the mutate-during-iterate fix
## ADR-0022/Constellation already established): decay first (snapshot-
## filtered to HABITAT only), breeding second. Offspring creation (inside
## the breeding pass) happens only after the decay pass has fully completed
## iterating its own snapshot, so a same-tick offspring is never visited by
## this tick's decay pass.
func _on_mission_launched(_mission_id: String, _modifiers: PackedStringArray, _difficulty_tier: int) -> void:
	_tick_decay()
	_tick_breeding_pens()


## Decay pass (AC-19): only HABITAT creatures decay and have
## missions_since_tended incremented — RESERVE/BREEDING_PEN creatures are
## untouched. Each decayed creature fires its own creature_happiness_changed
## independently (AC-42 — up to 10 HABITAT creatures at Rule 4's max, still
## under EventBus's 20/frame batch threshold, no batching needed).
##
## Bug found and fixed during the epic-wide code review (2026-07-18):
## compute_quality_bonus() was originally called INSIDE this loop, after
## each individual creature's own decay — meaning every emission except the
## last carried a transiently-wrong bonus computed from a partially-decayed
## HABITAT set (some creatures already decremented, some not yet). Not
## caught by this story's own tests, which only assert emission COUNT, not
## per-emission values. Fixed: decay every creature first, THEN compute the
## aggregate once, and use that single final value for every emission.
func _tick_decay() -> void:
	var habitat_creatures: Array[CreatureInstance] = _creatures.filter(
		func(c: CreatureInstance) -> bool: return c.state == CreatureInstance.CreatureState.HABITAT
	)
	for creature: CreatureInstance in habitat_creatures:
		_apply_decay(creature)
		creature.missions_since_tended += 1
	var bonus: float = compute_quality_bonus()
	for creature: CreatureInstance in habitat_creatures:
		GEventBus.creature_happiness_changed.emit(creature.creature_id, creature.happiness, bonus)


## Story 009 (AC-6/AC-7): EventBus-subscription-driven only — Menagerie
## never calls Defense Building directly for capacity. +2 per Habitat
## Expansion tier event, capped at HABITAT_MAX_CAPACITY (a 4th event, if it
## ever arrived, is a no-op past the cap). Counts events, does not assume
## tier ordering — Defense Building's own sequential-tier enforcement
## (Story 019) is the only ordering guarantee this relies on.
func _on_sanctuary_structure_built(_structure_id: String, structure_type: String) -> void:
	if structure_type != "habitat_expansion":
		return
	_habitat_capacity = mini(_habitat_capacity + HABITAT_CAPACITY_PER_TIER, HABITAT_MAX_CAPACITY)


## Current HABITAT slot count (base + built expansions). Read-only; lets the
## Menagerie screen draw empty-slot placeholders up to the real capacity.
##     var free_slots: int = GMenagerie.get_habitat_capacity() - roster_size
func get_habitat_capacity() -> int:
	return _habitat_capacity


## Formula 4: lure_cost(tier) = base_lure_cost × tier (AC-37/AC-38).
static func lure_cost(species_tier: int) -> int:
	return BASE_LURE_COST * species_tier


## AC-1: no discovery/unlock gate beyond has_item_quantity(lure_cost) — any
## of the 5 species is always a valid Lure target.
##
## AC-2/AC-3: deterministic — materials_spent fires for the exact cost, one
## new CreatureInstance created at starting_happiness=70, or the action is
## rejected in full (zero state change) if materials are insufficient.
## Returns the new creature_id on success, or -1 on rejection.
func lure_creature(species_id: StringName) -> int:
	var species: SpeciesResource = GGameDataRegistry.get_species(species_id)
	if species == null:
		return -1

	var cost: int = lure_cost(species.species_tier)
	if not GInventory.has_item_quantity(&"menagerie_lure", cost):
		return -1

	var lure_definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"menagerie_lure")
	if lure_definition == null:
		return -1
	# materials_spent IS the consume step: Inventory._on_materials_spent()
	# deducts the stack (menagerie.md Rule 2, materials_wiring_test). A direct
	# consume_stackable() here as well charged every Lure twice -- found live
	# in the 2026-10-04 smoke check (11 lures - 2 Tier-1 lures left 2, not 5).
	GEventBus.materials_spent.emit("menagerie_lure", cost, "lure")

	var creature := CreatureInstance.new()
	creature.creature_id = _next_creature_id
	_next_creature_id += 1
	creature.species = species_id
	creature.state = CreatureInstance.CreatureState.RESERVE  # placement below may promote to HABITAT
	creature.happiness = STARTING_HAPPINESS  # AC-16: exactly 70, no rounding drift
	creature.missions_since_tended = 0
	_creatures.append(creature)

	GEventBus.creature_acquired.emit(creature.creature_id, String(species_id))

	# Story 008 (AC-4/AC-5): place directly into HABITAT if an open slot
	# exists (triggers the aggregate recompute-and-push, Story 011);
	# otherwise the creature stays RESERVE with no recompute at all —
	# acquisition itself never fails or queues on HABITAT capacity.
	if _habitat_count() < _habitat_capacity:
		move_to_habitat(creature.creature_id)

	return creature.creature_id


## Read-only lookup by creature_id, or null if not found. Used by tests and
## later stories (Out of Scope here — Story 008 decides HABITAT vs RESERVE
## placement).
func get_creature(creature_id: int) -> CreatureInstance:
	for creature: CreatureInstance in _creatures:
		if creature.creature_id == creature_id:
			return creature
	return null


## Read-only roster query for the Menagerie screen (menagerie.md's UI
## Requirements — the roster strip lists every owned creature regardless of
## state). Returns a shallow copy of the internal array so callers can't
## mutate Menagerie's own list; individual CreatureInstance objects are still
## live references (read-only display use, per the screen's own scope).
func get_all_creatures() -> Array[CreatureInstance]:
	return _creatures.duplicate()


## Real gap found and fixed 2026-08-11 (player-requested Building Upgrade
## System, `design/gdd/building-upgrade.md`'s `"creature"` requirement
## type): get_all_creatures() returns every owned instance, forcing every
## caller that only wants "do I own at least one of species X" to
## re-implement the same linear scan. Any CreatureState counts (including
## SACRIFICED — deliberately not filtered: this doc's own Rule 5 treats
## `requirements` as "does this exist in my save history," not "is it
## currently alive," matching Defense Building's own is_structure_built()
## precedent of never un-checking a permanent milestone).
func has_creature_species(species_id: StringName) -> bool:
	for creature: CreatureInstance in _creatures:
		if creature.species == species_id:
			return true
	return false


# ---------------------------------------------------------------------------
# Story 010 (TR-menag-002, aggregate formula half): Formula 3 —
# menagerie_quality_bonus. HABITAT-only, never divides by zero.
# ---------------------------------------------------------------------------

const STARTING_HAPPINESS: float = 70.0
const HAPPINESS_FLOOR: float = 20.0
const DECAY_PER_MISSION: float = 8.0

const QUALITY_BONUS_FLOOR: float = 1.0
const QUALITY_BONUS_CEILING: float = 1.5
const QUALITY_BONUS_HAPPINESS_WEIGHT: float = 0.5


## Formula 3: 1.0 if N_habitat=0; clamp(1.0 + 0.5*(H_avg/100), 1.0, 1.5)
## otherwise. Filters _creatures to state==HABITAT only — RESERVE and
## BREEDING_PEN never contribute (AC-8/AC-9).
func compute_quality_bonus() -> float:
	var habitat_creatures: Array[CreatureInstance] = _creatures.filter(
		func(c: CreatureInstance) -> bool: return c.state == CreatureInstance.CreatureState.HABITAT
	)
	if habitat_creatures.is_empty():
		return QUALITY_BONUS_FLOOR
	var total_happiness: float = 0.0
	for creature: CreatureInstance in habitat_creatures:
		total_happiness += creature.happiness
	var average_happiness: float = total_happiness / habitat_creatures.size()
	var bonus: float = QUALITY_BONUS_FLOOR + QUALITY_BONUS_HAPPINESS_WEIGHT * (average_happiness / 100.0)
	return clampf(bonus, QUALITY_BONUS_FLOOR, QUALITY_BONUS_CEILING)


# ---------------------------------------------------------------------------
# Story 011 (TR-menag-002, highest-risk rule): single call-site aggregate
# recompute-and-push, plus the HABITAT/BREEDING_PEN move actions that
# trigger it.
# ---------------------------------------------------------------------------

## Longest-tended remaining HABITAT creature (Rule 6) — arbitrary tie-break
## is acceptable, only the pushed aggregate VALUE matters to consumers, not
## the representative's identity. Returns -1 if HABITAT is empty.
func _pick_representative() -> int:
	var candidates: Array[CreatureInstance] = _creatures.filter(
		func(c: CreatureInstance) -> bool: return c.state == CreatureInstance.CreatureState.HABITAT
	)
	if candidates.is_empty():
		return -1
	candidates.sort_custom(func(a: CreatureInstance, b: CreatureInstance) -> bool: return a.missions_since_tended > b.missions_since_tended)
	return candidates[0].creature_id


## Single call site (ADR-0026 Decision) — called synchronously by every
## HABITAT-composition-changing action. Never called directly by external
## code; call sites call _pick_representative() first and skip this
## entirely if it returns -1 (Rule 6's explicit skip clause, AC-14).
func _recompute_and_push_aggregate(representative_creature_id: int) -> void:
	var bonus: float = compute_quality_bonus()
	var representative: CreatureInstance = get_creature(representative_creature_id)
	var happiness: float = representative.happiness if representative != null else 0.0
	GEventBus.creature_happiness_changed.emit(representative_creature_id, happiness, bonus)


## AC-10: RESERVE -> HABITAT (also used by Story 008's placement-on-
## acquisition HABITAT path). Returns false if the creature doesn't exist,
## isn't RESERVE, or HABITAT is already at capacity.
func move_to_habitat(creature_id: int) -> bool:
	var creature: CreatureInstance = get_creature(creature_id)
	if creature == null or creature.state != CreatureInstance.CreatureState.RESERVE:
		return false
	if _habitat_count() >= _habitat_capacity:
		return false
	creature.state = CreatureInstance.CreatureState.HABITAT
	_recompute_and_push_aggregate(creature_id)
	return true


## AC-11: HABITAT -> BREEDING_PEN (actual pen occupancy is Story 015's
## scope — this method only handles the state transition + aggregate push
## + notification, matching this story's own Out of Scope boundary).
func move_to_breeding_pen(creature_id: int) -> bool:
	var creature: CreatureInstance = get_creature(creature_id)
	if creature == null:
		return false
	if creature.state != CreatureInstance.CreatureState.HABITAT and creature.state != CreatureInstance.CreatureState.RESERVE:
		return false
	var was_habitat: bool = creature.state == CreatureInstance.CreatureState.HABITAT
	creature.state = CreatureInstance.CreatureState.BREEDING_PEN
	GEventBus.creature_moved_to_breeding_pen.emit(creature_id)
	if was_habitat:
		var representative_id: int = _pick_representative()
		if representative_id != -1:
			_recompute_and_push_aggregate(representative_id)
	return true


## Formula 5 (Story 015): breeding_missions_remaining(tier) =
## base_breeding_duration(2) + tier_breeding_penalty(1) × (tier-1).
const BASE_BREEDING_DURATION: int = 2
const TIER_BREEDING_PENALTY: int = 1


static func breeding_duration(species_tier: int) -> int:
	return BASE_BREEDING_DURATION + TIER_BREEDING_PENALTY * (species_tier - 1)


## AC-23/AC-24/AC-28: pairs two same-species creatures into the first open
## pen (0 occupants) and starts Formula 5's countdown. Rejected outright
## (zero state change, no event for either) if: either creature is missing,
## species differ, either isn't RESERVE/HABITAT-eligible for the pen move,
## or both pens are already fully occupied (fixed capacity, not
## expandable). Reuses move_to_breeding_pen() per creature for the state
## transition + conditional aggregate push.
func pair_for_breeding(creature_id_a: int, creature_id_b: int) -> bool:
	if creature_id_a == creature_id_b:
		return false  # TD-menag review fix (2026-07-18): a creature cannot pair with itself
	var creature_a: CreatureInstance = get_creature(creature_id_a)
	var creature_b: CreatureInstance = get_creature(creature_id_b)
	if creature_a == null or creature_b == null:
		return false
	if creature_a.species != creature_b.species:
		return false
	if creature_a.state == CreatureInstance.CreatureState.SACRIFICED or creature_a.state == CreatureInstance.CreatureState.BREEDING_PEN:
		return false
	if creature_b.state == CreatureInstance.CreatureState.SACRIFICED or creature_b.state == CreatureInstance.CreatureState.BREEDING_PEN:
		return false

	var open_pen: BreedingPen = null
	for pen: BreedingPen in _breeding_pens:
		if pen.occupant_ids.is_empty():
			open_pen = pen
			break
	if open_pen == null:
		return false  # AC-28: both pens already fully occupied

	move_to_breeding_pen(creature_id_a)
	move_to_breeding_pen(creature_id_b)
	open_pen.occupant_ids = [creature_id_a, creature_id_b]

	var species: SpeciesResource = GGameDataRegistry.get_species(creature_a.species)
	var tier: int = species.species_tier if species != null else 1
	open_pen.breeding_missions_remaining = breeding_duration(tier)
	return true


## Story 013's breeding pass (called once per mission_launched, AFTER the
## decay pass completes — never interleaved, per ADR-0026's explicit
## sequencing requirement). Decrements every active pen's counter; any pen
## reaching 0 produces exactly one offspring (species of the parents,
## directly into RESERVE, never HABITAT — AC-45), fires creature_bred once,
## and immediately restarts the countdown at the same tier's full duration
## (GDD Rule 11: "may be bred again" — parents remain paired, unconsumed,
## the same occupancy-triggers-countdown rule that started it applies again).
func _tick_breeding_pens() -> void:
	for pen: BreedingPen in _breeding_pens:
		if pen.occupant_ids.size() != 2 or pen.breeding_missions_remaining <= 0:
			continue
		pen.breeding_missions_remaining -= 1
		if pen.breeding_missions_remaining == 0:
			var parent: CreatureInstance = get_creature(pen.occupant_ids[0])
			var offspring := CreatureInstance.new()
			offspring.creature_id = _next_creature_id
			_next_creature_id += 1
			offspring.species = parent.species if parent != null else &""
			offspring.state = CreatureInstance.CreatureState.RESERVE
			offspring.happiness = STARTING_HAPPINESS
			_creatures.append(offspring)
			GEventBus.creature_bred.emit(offspring.creature_id, String(offspring.species))

			var species: SpeciesResource = GGameDataRegistry.get_species(offspring.species)
			var tier: int = species.species_tier if species != null else 1
			pen.breeding_missions_remaining = breeding_duration(tier)


## AC-12: BREEDING_PEN -> RESERVE (NOT HABITAT) — no aggregate recompute,
## no creature_happiness_changed, only the return notification.
func return_from_breeding_pen_to_reserve(creature_id: int) -> bool:
	var creature: CreatureInstance = get_creature(creature_id)
	if creature == null or creature.state != CreatureInstance.CreatureState.BREEDING_PEN:
		return false
	creature.state = CreatureInstance.CreatureState.RESERVE
	GEventBus.creature_returned_from_breeding_pen.emit(creature_id)
	# Story 015 Edge Cases: pen removal before breeding completes discards
	# the in-progress timer entirely — not paused/resumable. Clear this
	# creature from whichever pen holds it; the pen's countdown is dropped
	# for the whole pair (re-pairing later restarts the full duration).
	for pen: BreedingPen in _breeding_pens:
		if pen.occupant_ids.has(creature_id):
			pen.occupant_ids = []
			pen.breeding_missions_remaining = -1
			break
	return true


## Formula 1 (Story 012): floor-not-death — a HABITAT creature always
## survives, never removed, never state-transitioned purely by reaching the
## floor (AC-18/AC-40). Applied only to HABITAT creatures, only by the
## mission_launched decay pass (Story 013) — never called for RESERVE/
## BREEDING_PEN creatures, whose happiness stays frozen at whatever value
## it held when they left HABITAT.
func _apply_decay(creature: CreatureInstance) -> void:
	creature.happiness = maxf(HAPPINESS_FLOOR, creature.happiness - DECAY_PER_MISSION)


## Formula 2 (Story 014): the inverse of decay — single Sanctuary-only
## action per creature, no cooldown, no limit on repeat use. Boosts
## happiness (clamped at 100, no stored overheal) and resets
## missions_since_tended to 0 (still resets even if already at 100 — the
## counter reset is unconditional, not gated on a happiness change actually
## occurring). Only valid on HABITAT creatures (per the GDD's own UI
## scoping) — rejected outright for any other state, zero mutation.
const TEND_BOOST: float = 20.0
const HAPPINESS_CEILING: float = 100.0


func tend_creature(creature_id: int) -> bool:
	var creature: CreatureInstance = get_creature(creature_id)
	if creature == null or creature.state != CreatureInstance.CreatureState.HABITAT:
		return false
	creature.happiness = minf(HAPPINESS_CEILING, creature.happiness + TEND_BOOST)
	creature.missions_since_tended = 0
	return true


func _habitat_count() -> int:
	var count: int = 0
	for creature: CreatureInstance in _creatures:
		if creature.state == CreatureInstance.CreatureState.HABITAT:
			count += 1
	return count


## Story 016 owns the FULL sacrifice validation flow — this is the minimal
## version needed to exercise Story 011's aggregate-push behavior (AC-13/
## AC-14): rejects a BREEDING_PEN-state creature, transitions to terminal
## SACRIFICED, recomputes the aggregate if the creature was HABITAT-sourced
## (skipping entirely per Rule 6's skip clause if HABITAT is now empty),
## emits creature_sacrificed synchronously. Story 016 may add further
## validation on top without changing this shape.
func request_sacrifice(creature_id: int, target_item_id: int) -> bool:
	var creature: CreatureInstance = get_creature(creature_id)
	if creature == null:
		return false
	# AC-44: SACRIFICED is a verified terminal state — reject a second
	# sacrifice attempt against an already-sacrificed instance (this check
	# is additional to ADR-0026's own literal pseudocode, which only
	# rejected BREEDING_PEN — a real gap caught while writing Story 016's
	# terminal-state test).
	if creature.state == CreatureInstance.CreatureState.BREEDING_PEN or creature.state == CreatureInstance.CreatureState.SACRIFICED:
		return false
	var was_habitat: bool = creature.state == CreatureInstance.CreatureState.HABITAT
	creature.state = CreatureInstance.CreatureState.SACRIFICED
	if was_habitat:
		var representative_id: int = _pick_representative()
		if representative_id != -1:
			_recompute_and_push_aggregate(representative_id)
	GEventBus.creature_sacrificed.emit(creature_id, target_item_id)
	return true


# ---------------------------------------------------------------------------
# SaveRestorer interface (ADR-0003, ADR-0026) — Story 017, TR-menag-003
# ---------------------------------------------------------------------------

func get_save_key() -> String:
	return "menagerie"


## ADR-0003 primitive-only rule: CreatureState (enum -> int, already
## primitive), StringName species converted to String explicitly, matching
## inventory.gd's/defense_building.gd's established convention.
func get_save_data() -> Dictionary:
	var creatures_data: Array = []
	for creature: CreatureInstance in _creatures:
		creatures_data.append({
			"creature_id": creature.creature_id,
			"species": String(creature.species),
			"state": creature.state,
			"happiness": creature.happiness,
			"missions_since_tended": creature.missions_since_tended,
		})
	var pens_data: Array = []
	for pen: BreedingPen in _breeding_pens:
		pens_data.append({
			"occupant_ids": pen.occupant_ids.duplicate(),
			"breeding_missions_remaining": pen.breeding_missions_remaining,
		})
	return {
		"creatures": creatures_data,
		"breeding_pens": pens_data,
		"habitat_capacity": _habitat_capacity,
		"next_creature_id": _next_creature_id,
	}


## Returns false (not void!) on any malformed/missing data so
## SavePersistence's _restore_all_systems() falls back to reset_to_defaults().
## Validates presence and type of every field before mutating any state, so
## a rejected payload has no partial-restore side effects.
func restore_save_data(data: Dictionary) -> bool:
	if not (data.has("creatures") and data.has("breeding_pens") and data.has("habitat_capacity") and data.has("next_creature_id")):
		return false

	var creatures_raw: Variant = data["creatures"]
	var pens_raw: Variant = data["breeding_pens"]
	var capacity_raw: Variant = data["habitat_capacity"]
	var next_id_raw: Variant = data["next_creature_id"]
	if not (creatures_raw is Array and pens_raw is Array and capacity_raw is int and next_id_raw is int):
		return false

	var restored_creatures: Array[CreatureInstance] = []
	for entry_raw: Variant in (creatures_raw as Array):
		if not (entry_raw is Dictionary):
			return false
		var entry: Dictionary = entry_raw as Dictionary
		if not (entry.has("creature_id") and entry.has("species") and entry.has("state")
				and entry.has("happiness") and entry.has("missions_since_tended")):
			return false
		var creature_id_raw: Variant = entry["creature_id"]
		var species_raw: Variant = entry["species"]
		var state_raw: Variant = entry["state"]
		var happiness_raw: Variant = entry["happiness"]
		var tended_raw: Variant = entry["missions_since_tended"]
		if not (creature_id_raw is int and species_raw is String and state_raw is int
				and (happiness_raw is float or happiness_raw is int) and tended_raw is int):
			return false
		var creature := CreatureInstance.new()
		creature.creature_id = creature_id_raw as int
		creature.species = StringName(species_raw as String)
		creature.state = state_raw as CreatureInstance.CreatureState
		# Defense-in-depth against a corrupted/hand-edited save (flagged during
		# the epic-wide code review): clamp to the same [floor, ceiling] range
		# normal gameplay (_apply_decay()/tend_creature()) already enforces,
		# rather than trusting an out-of-range value to persist until the
		# next decay/tend touches it.
		creature.happiness = clampf(float(happiness_raw), HAPPINESS_FLOOR, HAPPINESS_CEILING)
		creature.missions_since_tended = tended_raw as int
		restored_creatures.append(creature)

	var pens_array: Array = pens_raw as Array
	if pens_array.size() != 2:
		return false
	var restored_pens: Array[BreedingPen] = []
	for pen_entry_raw: Variant in pens_array:
		if not (pen_entry_raw is Dictionary):
			return false
		var pen_entry: Dictionary = pen_entry_raw as Dictionary
		if not (pen_entry.has("occupant_ids") and pen_entry.has("breeding_missions_remaining")):
			return false
		var occupant_ids_raw: Variant = pen_entry["occupant_ids"]
		var remaining_raw: Variant = pen_entry["breeding_missions_remaining"]
		if not (occupant_ids_raw is Array and remaining_raw is int):
			return false
		var pen := BreedingPen.new()
		var occupant_ids: Array[int] = []
		for id_raw: Variant in (occupant_ids_raw as Array):
			if not (id_raw is int):
				return false
			occupant_ids.append(id_raw as int)
		pen.occupant_ids = occupant_ids
		pen.breeding_missions_remaining = remaining_raw as int
		restored_pens.append(pen)

	_creatures = restored_creatures
	_breeding_pens = restored_pens
	_habitat_capacity = capacity_raw as int
	_next_creature_id = next_id_raw as int
	return true


## Clears all Menagerie state to new-game defaults. Menagerie is an
## Autoload — nothing resets implicitly via scene teardown, so this is the
## only new-game reset path (ADR-0026 Risks).
func reset_to_defaults() -> void:
	_creatures = []
	_breeding_pens = [BreedingPen.new(), BreedingPen.new()]
	_habitat_capacity = HABITAT_BASE_CAPACITY
	_next_creature_id = 0
