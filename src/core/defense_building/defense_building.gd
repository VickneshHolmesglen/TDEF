class_name DefenseBuilding
extends Node

## Defense Building's tech-tree and Sanctuary-structure ledger container.
##
## Story 018 (TR-defbuild-001): declares the two independent, permanent
## ledgers defined by ADR-0024. Story 019 (TR-defbuild-001, chain-enforcement
## half) adds is_tech_unlocked() and can_unlock_tech() — read-only queries
## only. Story 020 (TR-defbuild-002) adds the structure-side equivalent,
## can_build_structure() — also a read-only eligibility check only. Story 022
## (TR-defbuild-001, currency half) adds resolve_tech_unlock()/
## resolve_structure_build() — the dual-gate check (eligibility + materials
## sufficiency) plus the gold-debit emission only. Story 023 (TR-defbuild-001,
## resolution-ordering half) completes both resolve methods with
## tech_unlocked/sanctuary_structure_built event emission, bringing 5 of
## ADR-0024 Rule 9's 6 sub-steps to a single synchronous call. Material
## CONSUMPTION (step d) remains STILL deferred — a genuine, GDD-flagged
## open design question (material-rarity vs. item_type vocabulary mismatch),
## not a coding gap either story could resolve unilaterally — see
## resolve_tech_unlock()'s doc comment for the full rationale; tracked as
## TD-defbuild-002. Story 024 (TR-defbuild-003) adds the Sanctuary-only
## phase lock (is_locked(), gating both resolve methods) and full
## SaveRestorer persistence at restore_order=21. Story 026 (TR-defbuild-001,
## edge-case half) adds the shared `_action_resolving` guard — one flag
## covering BOTH resolve methods, not per-ledger, closing the cross-ledger
## double-spend race (a tech unlock and a structure build "arriving in the
## same frame" must never both proceed against the same gold balance).
##
## Registered as Autoload #10 in project.godot (ADR-0024), after Inventory
## (Autoload #9, ADR-0016) — DefenseBuilding's resolve methods (Story 022)
## call Inventory.has_items() directly and must load after it.
##
## _tech_ledger: tech_id -> true means UNLOCKED (ADR-0024 Decision).
## _structure_ledger: structure_id -> true means BUILT (ADR-0024 Decision).
## The two ledgers are structurally independent — no shared "progression
## point" currency, cross-linked only via StructureResource.tech_gate at the
## (not-yet-implemented) resolution layer (GDD Core Rule 1, AC-1).
##
## Only the terminal UNLOCKED/BUILT state is ever persisted — LOCKED_PREREQ/
## AVAILABLE are always derived at query time from the prerequisite chain,
## never a third stored state (ADR-0024; derivation logic is out of scope
## for this story).
##
## Sanctuary-only scope (Story 024, GDD Rule 11): DefenseBuilding tracks
## `_is_sanctuary` via GEventBus.scene_transition_completed (SceneManager's
## own SANCTUARY/MISSION transition signal — NOT mission_phase_changed,
## which only fires for in-mission phases like WAVE_ACTIVE/SCOUT and never
## emits a "SANCTUARY" value at all). Defaults to `false` (LOCKED) at
## construction — this project's main_scene currently boots directly into a
## mission scene (the_gap.tscn, TD-project-001), so no explicit SANCTUARY
## transition is guaranteed to have fired yet; failing closed (locked) until
## one is observed is the safe default, not an arbitrary choice. DEFEAT never
## reverts, decrements, or resets either ledger — locking only blocks NEW
## writes going forward, it never touches already-written entries (the
## Player Fantasy's "only ever grows" contract, AC-29).

const RESTORE_ORDER: int = 21  ## matches save-persistence.md's Formula 4 table (ADR-0024)

var _tech_ledger: Dictionary[StringName, bool] = {}
var _structure_ledger: Dictionary[StringName, bool] = {}
var _is_sanctuary: bool = false
var _action_resolving: bool = false  ## shared across BOTH resolve methods (Story 026, ADR-0024)


func _ready() -> void:
	GEventBus.scene_transition_completed.connect(_on_scene_transition_completed)
	GSavePersistence.register(self, RESTORE_ORDER)


func _exit_tree() -> void:
	GEventBus.scene_transition_completed.disconnect(_on_scene_transition_completed)
	GSavePersistence.unregister(self)


func _on_scene_transition_completed(target_context: String, _mission_id: String) -> void:
	_is_sanctuary = (target_context == "SANCTUARY")


## True when the current scene context is anything other than SANCTUARY
## (AC-28) — mission phases (SCOUT/WAVE_ACTIVE/INTERMISSION/DEFEAT/OUTCOME
## alike) are all LOCKED. Both resolve_tech_unlock() and
## resolve_structure_build() check this first and reject with zero side
## effects while locked; already-written ledger entries are never affected
## by lock state (locking only blocks new writes, per AC-29's "only ever
## grows" contract).
func is_locked() -> bool:
	return not _is_sanctuary


## Returns true if tech_id is UNLOCKED. O(1) ledger lookup; a false result
## covers both "never seen" and "explicitly LOCKED_PREREQ/AVAILABLE" — this
## method never derives the prerequisite chain itself (ADR-0024).
func is_tech_unlocked(tech_id: StringName) -> bool:
	return _tech_ledger.get(tech_id, false)


## Read-only eligibility check for whether tech_id's prerequisite chain is
## satisfied and it is not already unlocked (AC-4, AC-5, AC-6, AC-26). Does
## NOT check gold/material affordability — that gate is owned entirely by
## the unlock-resolution sequence (Story 022/023, ADR-0024 Decision); a true
## result here only means "eligible to proceed to the cost check," it is not
## itself an unlock. Returns false (not a crash) for an unknown tech_id.
func can_unlock_tech(tech_id: StringName) -> bool:
	if is_tech_unlocked(tech_id):
		return false
	var tech_node: TechNodeResource = GGameDataRegistry.get_tech_node(tech_id)
	if tech_node == null:
		return false
	if tech_node.prerequisite_tech_id == &"":
		return true
	return is_tech_unlocked(tech_node.prerequisite_tech_id)


## Returns true if structure_id is BUILT. O(1) ledger lookup, mirrors
## is_tech_unlocked() exactly. Added 2026-07-25 for the Defense Building
## screen's own built/unbuilt status display — no query for this existed
## before (only the combined ineligibility check in can_build_structure(),
## which doesn't distinguish "already built" from "not yet eligible").
func is_structure_built(structure_id: StringName) -> bool:
	return _structure_ledger.get(structure_id, false)


## Read-only eligibility check for whether structure_id may be built:
## its tier-sequence prerequisite (StructureResource.prerequisite_structure_id)
## AND its tech-gate (StructureResource.tech_gate) must both be satisfied, and
## it must not already be BUILT (AC-10 through AC-14, AC-27, ADR-0024). Both
## checks are evaluated — an ungated prerequisite does not bypass an unmet
## tech-gate, and vice versa (AC-11/AC-12). Does NOT check gold/material
## affordability — that gate, along with the actual build and
## sanctuary_structure_built emission, is owned entirely by the
## build-resolution sequence (Story 022/023, ADR-0024 Decision); a true
## result here only means "eligible to proceed to the cost check," it is not
## itself a build. Returns false (not a crash) for an unknown structure_id.
func can_build_structure(structure_id: StringName) -> bool:
	if _structure_ledger.get(structure_id, false):
		return false
	var structure: StructureResource = GGameDataRegistry.get_structure(structure_id)
	if structure == null:
		return false
	if structure.prerequisite_structure_id != &"" and not _structure_ledger.get(structure.prerequisite_structure_id, false):
		return false
	if structure.tech_gate != &"" and not is_tech_unlocked(structure.tech_gate):
		return false
	return true


## Resolves a tech node unlock (Story 022/023, TR-defbuild-001 currency +
## resolution-ordering halves; ADR-0024 Rule 9). Dual-gated: both the
## prerequisite-chain eligibility (can_unlock_tech(), AC-4/AC-5/AC-6/AC-26)
## AND materials sufficiency (Inventory.has_items(material_costs), AC-18)
## must pass, or the action is rejected in full — zero ledger mutation, zero
## gold-debit emission, zero tech_unlocked emission; gold alone is never
## sufficient on its own (AC-18's literal wording).
##
## Executes 5 of ADR-0024 Rule 9's 6 sub-steps synchronously, in fixed order,
## within this single call (AC-24) — no `await`, no `call_deferred`, so the
## caller observes the terminal state immediately upon return (AC-25), not on
## a later frame:
##   (a) eligibility re-validate (can_unlock_tech())
##   (b) materials re-validate (Inventory.has_items())
##   (c) gold debit (resources_changed, Story 022)
##   (e) ledger write (_tech_ledger[tech_id] = true)
##   (f) domain event emission (tech_unlocked, Story 023)
##
## Gold sufficiency is deliberately NOT independently re-validated (AC-19/
## AC-22, out of scope project-wide): gold-balance ownership is a
## pre-existing, unresolved gap shared with Tower System (ADR-0024 Decision,
## Core Rule 7) — this method follows the same self-debit convention every
## other gold-spending system in this project already uses, rather than
## inventing a Defense-Building-local resolution.
##
## TD-defbuild-002 RESOLVED (Sprint 6, S6-06b): the rarity-keyed check below
## now uses Inventory.has_items_by_rarity() — a genuine aggregation axis
## (ItemDefinitionResource.rarity) separate from has_items()'s item_type sum
## — so this check is real, not merely content-correct-but-unpayable.
##
## Step (d), material CONSUMPTION, is STILL deliberately NOT performed —
## this is a separate, still-open scope decision (whether/how Defense
## Building should synchronously consume materials on tech-unlock/structure-
## build, and whether that belongs here or in a dedicated resolution step),
## not a vocabulary gap — the vocabulary gap the rarity fix above resolves.
## AC-24's "six sub-steps" wording is therefore satisfied for 5 of 6 steps
## here; step (d) remains open, same treatment as AC-19's gold-balance gap.
##
## Guarded by the shared `_action_resolving` flag (Story 026, AC-37/AC-38):
## set immediately before step (a) once the lock/reentrancy checks pass,
## cleared on every exit path (both rejection and success) — a single failed
## resolve must never permanently disable future actions (AC-37's stale-UI
## rejection must still allow the next legitimate attempt to succeed).
##
## Returns true on a successful resolve (gold debit + tech_unlocked emitted,
## ledger written). Returns false on any rejection, with zero side effects.
func resolve_tech_unlock(tech_id: StringName) -> bool:
	if is_locked():
		return false
	if _action_resolving:
		return false
	_action_resolving = true
	if not can_unlock_tech(tech_id):
		_action_resolving = false
		return false
	var tech_node: TechNodeResource = GGameDataRegistry.get_tech_node(tech_id)
	if tech_node == null:
		_action_resolving = false
		return false
	if not GInventory.has_items_by_rarity(tech_node.material_costs):
		_action_resolving = false
		return false
	GEventBus.resources_changed.emit(-tech_node.gold_cost, &"tech_unlock")
	_tech_ledger[tech_id] = true
	GEventBus.tech_unlocked.emit(String(tech_id), tech_node.tech_category)
	_action_resolving = false
	return true


## Resolves a Sanctuary structure build (Story 022/023, TR-defbuild-001
## currency + resolution-ordering halves; ADR-0024 Rule 9). Mirrors
## resolve_tech_unlock()'s shape exactly — same dual-gate contract, same
## 5-of-6-steps synchronous execution, same gold-balance-ownership and
## material-consumption deferrals (see resolve_tech_unlock()'s doc comment
## for both rationales in full — not re-stated here to avoid drift between
## two copies of the same reasoning).
##
## Shares the SAME `_action_resolving` flag as resolve_tech_unlock() — not a
## separate per-ledger guard (ADR-0024 Decision, Story 026 AC-38) — so a
## tech-unlock confirm and a structure-build confirm arriving "simultaneously"
## can never both read the pre-debit gold balance and double-spend it.
##
## Returns true on a successful resolve (gold debit + sanctuary_structure_built
## emitted via `resources_changed(-gold_cost, &"structure_built")` /
## `sanctuary_structure_built(structure_id, structure_type)`, ledger written).
## Returns false on any rejection, with zero side effects.
func resolve_structure_build(structure_id: StringName) -> bool:
	if is_locked():
		return false
	if _action_resolving:
		return false
	_action_resolving = true
	if not can_build_structure(structure_id):
		_action_resolving = false
		return false
	var structure: StructureResource = GGameDataRegistry.get_structure(structure_id)
	if structure == null:
		_action_resolving = false
		return false
	if not GInventory.has_items_by_rarity(structure.material_costs):
		_action_resolving = false
		return false
	GEventBus.resources_changed.emit(-structure.gold_cost, &"structure_built")
	_structure_ledger[structure_id] = true
	GEventBus.sanctuary_structure_built.emit(String(structure_id), structure.structure_type)
	_action_resolving = false
	return true


# ---------------------------------------------------------------------------
# SaveRestorer interface (ADR-0003, ADR-0024) — Story 024, TR-defbuild-003
# ---------------------------------------------------------------------------

## ADR-0003 SaveRestorer interface. Called by GSavePersistence._collect_save_data()
## to key this system's entry in the master save Dictionary.
func get_save_key() -> String:
	return "defense_building"


## ADR-0003 primitive-only rule: StringName keys/values are not primitives for
## store_var() purposes — converted to String explicitly here, matching
## inventory.gd's established convention (not the simplified, non-converting
## sketch in ADR-0024's own Key Interfaces block, which predates that
## precedent being established in shipped code).
func get_save_data() -> Dictionary:
	var tech_data: Dictionary = {}
	for tech_id: StringName in _tech_ledger:
		tech_data[String(tech_id)] = _tech_ledger[tech_id]
	var structure_data: Dictionary = {}
	for structure_id: StringName in _structure_ledger:
		structure_data[String(structure_id)] = _structure_ledger[structure_id]
	return {
		"tech_ledger": tech_data,
		"structure_ledger": structure_data,
	}


## Returns false (not void!) on any malformed/missing data so
## SavePersistence's _restore_all_systems() falls back to reset_to_defaults()
## for this system (matching inventory.gd's/hero.gd's restore_save_data()
## idiom). Validates presence and type of both ledgers, and every entry
## within them, before mutating any field — a rejected payload has no
## partial-restore side effects.
func restore_save_data(data: Dictionary) -> bool:
	if not (data.has("tech_ledger") and data.has("structure_ledger")):
		return false

	var tech_raw: Variant = data["tech_ledger"]
	var structure_raw: Variant = data["structure_ledger"]
	if not (tech_raw is Dictionary and structure_raw is Dictionary):
		return false

	var restored_tech: Dictionary[StringName, bool] = {}
	for key: Variant in (tech_raw as Dictionary):
		if not (key is String):
			return false
		var value: Variant = (tech_raw as Dictionary)[key]
		if not (value is bool):
			return false
		restored_tech[StringName(key as String)] = value as bool

	var restored_structure: Dictionary[StringName, bool] = {}
	for key: Variant in (structure_raw as Dictionary):
		if not (key is String):
			return false
		var value: Variant = (structure_raw as Dictionary)[key]
		if not (value is bool):
			return false
		restored_structure[StringName(key as String)] = value as bool

	_tech_ledger = restored_tech
	_structure_ledger = restored_structure
	return true


## Clears both ledgers to their starting (empty) state. Called by
## SavePersistence when no save data exists for this key, or when
## restore_save_data() rejects malformed data. Idempotent.
func reset_to_defaults() -> void:
	_tech_ledger = {}
	_structure_ledger = {}
