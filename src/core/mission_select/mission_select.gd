class_name MissionSelect
extends Node

## Autoload #12 (ADR-0028) — reclassified from scene-instanced because
## MissionRuntimeState (Story 013) must survive the SANCTUARY->MISSION scene
## transition, and retry_current_mission() (Story 013) must be callable as a
## bare global from Mission HUD (ADR-0020 Criterion B).
##
## GDD source: design/gdd/mission-select.md
## Governing ADR: docs/architecture/adr-0028-mission-select-runtime-state.md
##
## Story 009 (TR-missel-003): difficulty-tier selection (Rule 3) and per-tier
## completion tracking (Rule 4, Formula 3). record_completion() is a pure
## Formula 3 update — the mission_phase_changed subscription that measures
## real elapsed completion_time_seconds from a cached launch timestamp is
## Story 013's scope (it depends on the MissionRuntimeState launch-time
## caching that story owns); this story's ACs (AC-6/7/8) take
## completion_time_seconds as an already-known input, matching the GDD's own
## Formula 3 worked example.
##
## Story 010 (TR-missel-001, Rule 9): run-modifier toggle emission.
## Mission Select is confirmed the SOLE emitter of run_modifier_selected
## (correcting wave-manager.md's Interactions table, which previously also
## listed Tarot — tarot.md Rule 8/AC-18 already established Tarot as
## subscribe-only from the receiving side; this is the sending-side half of
## that correction). set_run_modifier() emits immediately on every call, live
## on toggle, never batched to Launch confirm (Guardrail). No clamping
## against Wave Manager's own safe ranges (Rule 9 non-duplication) — the raw
## modifier_value is emitted bit-identical to the caller's input.
##
## Story 011 (TR-missel-001, Rules 6-7): the two-step select->configure->launch
## flow and mission_launched's payload assembly. select_mission() now emits
## mission_selected and transitions to CONFIGURING, resetting modifiers/tier
## to defaults every time it's called (from BROWSING or directly from
## CONFIGURING for a different tile — Rule 6 does not distinguish the two,
## so no separate re-selection code path is needed for AC-16). back_out()
## silently returns to BROWSING (AC-17 — nothing was locked in yet).
## confirm_launch() assembles modifiers from every non-0.0 run-modifier value
## (Rule 7 payload inclusion) and emits mission_launched.
##
## Story 012 (TR-missel-001, Rule 8): the Launch validation gate.
## can_launch() checks, in order: Save & Persistence's restore pass has
## completed (_restore_completed, set via the sanctuary_state_restored
## subscription — a defensive guard only, since restore_order=11 means this
## screen should structurally never be reachable pre-restore per
## save-persistence.md); a mission_id is actually selected (state !=
## BROWSING, i.e. CONFIGURING or later); difficulty_tier holds a valid value
## in {1,2,3} (structurally guaranteed by Rule 3's default-to-recommended
## behavior — this check exists to confirm the guarantee, not because it can
## fail in practice, AC-22). confirm_launch() now calls can_launch() first
## and no-ops (no state change, no emission) if it fails — an invalid launch
## attempt never reaches EventBus at all (AC-20).
##
## Story 013 (TR-missel-001/002, Rule 10): MissionRuntimeState and
## retry_current_mission(). This is the core reason Mission Select is
## Autoload #12 — the runtime state must survive the SANCTUARY->MISSION scene
## transition. Set once at confirm_launch() success: _runtime_mission_id,
## _runtime_grid_config (the EXACT MissionEntry.grid_config instance
## reference — never .duplicate()'d, satisfying the same-instance guarantee
## structurally via GDScript Resource reference semantics), _runtime_difficulty_tier,
## _runtime_modifiers, _runtime_launch_timestamp. Cleared on mission_phase_changed
## -> MISSION_COMPLETE (state returns to BROWSING); retained unchanged on ->
## DEFEAT (arms retry_current_mission()). retry_current_mission() re-emits
## mission_launched with the identical cached values, re-delivers the same
## _runtime_grid_config instance to Grid via direct call (ADR-0005 Criterion
## A), and refreshes _runtime_launch_timestamp (AC-26 — a retried run's
## completion-time clock restarts, never cumulative with the failed attempt).
## EC-6: if MissionRuntimeState is absent, logs an error and takes no action —
## never falls back to a fresh GridConfig fetch from the catalogue.
##
## Story 014 (TR-missel-003, EC-1/EC-5/AC-29/AC-30): edge cases and state
## transitions. EC-1 (no completion_records for a mission) already holds
## structurally via get_completion_record()'s Dictionary.get()-with-default —
## no code change needed, only confirmed by this story's own test. EC-5:
## SaveRestorer persistence for _completion_ledger (get_save_data()/
## restore_save_data()/reset_to_defaults(), restore_order=11 per
## save-persistence.md) is implemented here — no other Mission Select story
## in this epic owns persistence, so it lands in this one. Orphaned entries
## (mission_id no longer resolving via GameDataRegistry) are retained
## unconditionally on restore, with the exact specified warning logged once
## per orphan — never discarded, never surfaced by the catalogue UI (which
## must walk the MissionEntry roster, never the ledger, per the Control
## Manifest Forbidden rule). DORMANT_RETRY_ARMED added to the State enum —
## entered on DEFEAT, exited only via retry_current_mission() (-> LAUNCHED)
## or an out-of-this-GDD's-scope Mission-HUD-owned abandon action (-> BROWSING).

## Alpha-scope run modifier catalogue (Rule 5/9). No composition-altering
## modifier exists among these — that purpose is deferred to content-authoring,
## per the GDD's own flagged deferral (AC-13).
const RUN_MODIFIER_IDS: Array[StringName] = [&"extend_waves", &"difficulty_growth_boost"]

const RESTORE_ORDER: int = 11

## States and Transitions table (Rule 6). DORMANT_RETRY_ARMED entered on
## DEFEAT (Story 014) — exited via retry_current_mission() (-> LAUNCHED) or
## a Mission-HUD-owned abandon action (-> BROWSING, out of this GDD's scope).
enum State { BROWSING, CONFIGURING, LAUNCHED, DORMANT_RETRY_ARMED }

var state: State = State.BROWSING

## Set true once Save & Persistence signals its restore pass has completed.
## Test seam: unit tests instantiate MissionSelect.new() without add_child(),
## so _ready() never runs — tests set this directly (same convention as
## Defense Building's _is_sanctuary seam).
var _restore_completed: bool = false

## Difficulty tier for the currently selected mission. Defaults to 1 (Normal)
## until select_mission() sets it to that mission's recommended_difficulty_tier.
var difficulty_tier: int = 1
var _current_mission_id: String = ""

## Current run-modifier stepper positions, keyed by modifier_id. Absence
## (or a stored 0.0) means "off" — only non-0.0 entries are included in
## mission_launched's payload (Rule 7).
var _run_modifiers: Dictionary[StringName, float] = {}

## outer: mission_id -> inner (untyped: difficulty_tier -> MissionCompletionRecord).
## GDScript typed Dictionaries only type the outer container (ADR-0021 limitation,
## reconfirmed by ADR-0028).
var _completion_ledger: Dictionary[String, Dictionary] = {}

## MissionRuntimeState (Rule 10) — cached in memory only, NEVER persisted to
## save (excluded entirely from get_save_data()'s payload). Empty/null means
## "no armed retry state" (EC-6).
var _runtime_mission_id: String = ""
var _runtime_grid_config: GridConfig = null
var _runtime_difficulty_tier: int = 0
var _runtime_modifiers: PackedStringArray = PackedStringArray()
var _runtime_launch_timestamp: float = 0.0


func _ready() -> void:
	GEventBus.sanctuary_state_restored.connect(_on_sanctuary_state_restored)
	GEventBus.mission_phase_changed.connect(_on_mission_phase_changed)
	GSavePersistence.register(self, RESTORE_ORDER)


func _exit_tree() -> void:
	GEventBus.sanctuary_state_restored.disconnect(_on_sanctuary_state_restored)
	GEventBus.mission_phase_changed.disconnect(_on_mission_phase_changed)
	GSavePersistence.unregister(self)


func _on_sanctuary_state_restored(_save_slot: int) -> void:
	_restore_completed = true


## Clears MissionRuntimeState on MISSION_COMPLETE (state returns to BROWSING,
## retry no longer armed — AC-24); transitions to DORMANT_RETRY_ARMED on
## DEFEAT, retaining MissionRuntimeState unchanged (arms
## retry_current_mission()). Takes no action on any other phase (AC-30 —
## SCOUT/PRE_WAVE/WAVE_ACTIVE/INTERMISSION are not this system's concern,
## own state does not change).
func _on_mission_phase_changed(_previous_phase: String, new_phase: String, _timestamp: float) -> void:
	if new_phase == "MISSION_COMPLETE":
		_runtime_mission_id = ""
		_runtime_grid_config = null
		_runtime_difficulty_tier = 0
		_runtime_modifiers = PackedStringArray()
		_runtime_launch_timestamp = 0.0
		state = State.BROWSING
	elif new_phase == "DEFEAT":
		state = State.DORMANT_RETRY_ARMED


## Selects a mission for configuring (Rule 6). Emits mission_selected
## immediately, transitions to CONFIGURING, and resets difficulty_tier to
## that mission's recommended_difficulty_tier and every run-modifier to its
## 0.0 default — identical behavior whether called from BROWSING (AC-15) or
## directly from CONFIGURING for a different mission_id (AC-16), matching
## Rule 6's undifferentiated handling of the two entry paths. No gameplay
## state (Grid, Wave Manager phase) changes as a result — this only updates
## Mission Select's own local state and emits mission_selected.
func select_mission(mission_id: String) -> void:
	_current_mission_id = mission_id
	_run_modifiers.clear()
	var entry: MissionEntry = GGameDataRegistry.get_mission_entry(mission_id)
	difficulty_tier = entry.recommended_difficulty_tier if entry != null else 1
	state = State.CONFIGURING
	GEventBus.mission_selected.emit(mission_id)


## Backs out of CONFIGURING to BROWSING without pressing Launch (AC-17).
## Emits no EventBus event — nothing was locked in, so nothing is cancelled.
func back_out_to_browsing() -> void:
	state = State.BROWSING


## Sets the difficulty tier for the current CONFIGURING selection. Accepts
## any of {1,2,3} with no validation blocking (AC-4). Emits zero EventBus
## events — there is no difficulty_tier_selected event in the frozen contract
## (Rule 3); the only observable signal is mission_launched's own field,
## fired once at confirm time by confirm_launch() (AC-5).
func set_difficulty_tier(tier: int) -> void:
	difficulty_tier = tier


## Toggles a run modifier's stepper position and emits run_modifier_selected
## immediately (Guardrail — live on toggle, never batched to Launch confirm).
## modifier_value is emitted exactly as passed — no clamping against Wave
## Manager's own safe ranges (Rule 9 non-duplication, AC-14). Formula 1/2's
## requested_wave_count/requested_r derivations are conceptual only (Wave
## Manager's own consumption-side computation) — never transmitted as their
## own fields, only the raw modifier_value is sent (AC-11/AC-12). The value
## is also cached locally for confirm_launch()'s payload assembly (Rule 7).
func set_run_modifier(modifier_id: StringName, modifier_value: float) -> void:
	_run_modifiers[modifier_id] = modifier_value
	GEventBus.run_modifier_selected.emit(modifier_id, modifier_value)


## Launch validation gate (Rule 8). A defensive guard, not the primary
## prevention mechanism — the UI itself should gray out/hide Launch outside
## CONFIGURING; this exists in case that's somehow bypassed (AC-20). Also
## confirms the selected mission_id still resolves to a real MissionEntry —
## keeps confirm_launch() symmetric with retry_current_mission()'s EC-6
## guard, since a null grid_config would otherwise reach mission_launched.
func can_launch() -> bool:
	if not _restore_completed:
		return false
	if state == State.BROWSING:
		return false
	if difficulty_tier < 1 or difficulty_tier > 3:
		return false
	if GGameDataRegistry.get_mission_entry(_current_mission_id) == null:
		return false
	return true


## Confirms launch: runs the Launch validation gate (can_launch()) first — if
## it fails, this is a no-op, no state change, no emission (AC-20/AC-21).
## Otherwise assembles mission_launched's modifiers payload from every
## run-modifier currently at a non-0.0 value (Rule 7 — a still-0.0 modifier
## is omitted, not included with a zero value; AC-18/AC-19), emits
## mission_launched, and transitions to LAUNCHED.
func confirm_launch() -> void:
	if not can_launch():
		return
	var modifiers: PackedStringArray = PackedStringArray()
	for modifier_id: StringName in _run_modifiers:
		if _run_modifiers[modifier_id] != 0.0:
			modifiers.append(modifier_id)
	state = State.LAUNCHED
	# MissionRuntimeState (Rule 10) — cache the exact GridConfig instance
	# reference, never duplicated, so retry_current_mission() can later
	# re-deliver the identical object to Grid.
	var entry: MissionEntry = GGameDataRegistry.get_mission_entry(_current_mission_id)
	_runtime_mission_id = _current_mission_id
	_runtime_grid_config = entry.grid_config if entry != null else null
	_runtime_difficulty_tier = difficulty_tier
	_runtime_modifiers = modifiers
	_runtime_launch_timestamp = Time.get_unix_time_from_system()
	GEventBus.mission_launched.emit(_current_mission_id, modifiers, difficulty_tier)


## Re-emits mission_launched with the cached MissionRuntimeState values —
## called by Mission HUD as a direct Autoload call (ADR-0020 Criterion B),
## never via EventBus. Re-delivers the exact _runtime_grid_config instance
## to Grid (ADR-0005 Criterion A direct write call) — never a re-fetched
## equivalent (AC-23). Refreshes _runtime_launch_timestamp so the retried
## attempt's completion-time clock restarts, not cumulative with the failed
## attempt (AC-26). EC-6: if MissionRuntimeState is absent (empty mission_id
## or null grid_config), logs an error and takes no action — never falls
## back to fetching a fresh GridConfig from the catalogue (AC-25).
func retry_current_mission() -> void:
	if _runtime_mission_id.is_empty() or _runtime_grid_config == null:
		push_error("MissionSelect.retry_current_mission() called with no armed MissionRuntimeState.")
		return
	_runtime_launch_timestamp = Time.get_unix_time_from_system()
	GGrid.initialize(_runtime_grid_config)
	state = State.LAUNCHED
	GEventBus.mission_launched.emit(_runtime_mission_id, _runtime_modifiers, _runtime_difficulty_tier)


## Returns the completion record for mission_id/tier, or a fresh default
## record if none exists yet (EC-1 — absence == {completed:false,
## best_time_seconds:-1.0}, per Dictionary.get()-with-default, never by
## presence-testing alone).
func get_completion_record(mission_id: String, tier: int) -> MissionCompletionRecord:
	var by_tier: Dictionary = _completion_ledger.get(mission_id, {})
	return by_tier.get(tier, MissionCompletionRecord.new())


## Records a mission completion for mission_id/tier (Formula 3). Tiers are
## tracked independently (AC-6) — completing tier 1 never touches tier 2/3's
## records for the same mission_id. best_time_seconds is monotonically
## non-increasing: a slower or first-ever attempt only ever improves or
## initializes the record, never regresses it (AC-7/AC-8).
func record_completion(mission_id: String, tier: int, completion_time_seconds: float) -> void:
	if not _completion_ledger.has(mission_id):
		_completion_ledger[mission_id] = {}
	var by_tier: Dictionary = _completion_ledger[mission_id]
	var record: MissionCompletionRecord = by_tier.get(tier, null)
	if record == null:
		record = MissionCompletionRecord.new()
		by_tier[tier] = record
	record.completed = true
	# Formula 3: keep the existing time only if a real prior record exists
	# (best_time_seconds >= 0.0, i.e. not the -1.0 sentinel) AND it is
	# already faster-or-equal; otherwise adopt the new attempt's time.
	if record.best_time_seconds < 0.0 or completion_time_seconds < record.best_time_seconds:
		record.best_time_seconds = completion_time_seconds


## Save-file key this system's payload is stored under.
func get_save_key() -> String:
	return "mission_select"


## MissionRuntimeState is intentionally excluded (Rule 10 — "never persisted
## to save"). Only _completion_ledger is saved.
func get_save_data() -> Dictionary:
	var ledger_data: Dictionary = {}
	for mission_id: String in _completion_ledger:
		var by_tier: Dictionary = _completion_ledger[mission_id]
		var tier_data: Dictionary = {}
		for tier: int in by_tier:
			var record: MissionCompletionRecord = by_tier[tier]
			tier_data[str(tier)] = {
				"completed": record.completed,
				"best_time_seconds": record.best_time_seconds,
			}
		ledger_data[mission_id] = tier_data
	return {"completion_ledger": ledger_data}


## Parses one raw {"completed": bool, "best_time_seconds": float} leaf into a
## MissionCompletionRecord, or returns null on any shape/type mismatch —
## leaf values are real type-guarded (`is bool`/`is float or is int`), not
## lenient `as` coercions, so malformed save data is rejected rather than
## silently coerced into a wrong-but-accepted value.
func _parse_completion_record(record_raw: Variant) -> MissionCompletionRecord:
	if not (record_raw is Dictionary):
		return null
	var record_dict: Dictionary = record_raw as Dictionary
	if not (record_dict.has("completed") and record_dict.has("best_time_seconds")):
		return null
	var completed_raw: Variant = record_dict["completed"]
	var best_time_raw: Variant = record_dict["best_time_seconds"]
	if not (completed_raw is bool):
		return null
	if not (best_time_raw is float or best_time_raw is int):
		return null
	var record: MissionCompletionRecord = MissionCompletionRecord.new()
	record.completed = completed_raw as bool
	record.best_time_seconds = float(best_time_raw)
	return record


## Returns false (not void!) on any malformed/missing data so SavePersistence
## falls back to reset_to_defaults(), matching every other SaveRestorer in
## this project. EC-5: an entry keyed by a mission_id that no longer resolves
## via GameDataRegistry.get_mission_entry() is retained unconditionally
## (never discarded — supports the mission being re-added later), with the
## exact specified warning logged once per orphan. Never blocks or fails the
## load — orphans are a push_warning, not a validation rejection.
func restore_save_data(data: Dictionary) -> bool:
	if not data.has("completion_ledger"):
		return false
	var ledger_raw: Variant = data["completion_ledger"]
	if not (ledger_raw is Dictionary):
		return false

	var restored_ledger: Dictionary[String, Dictionary] = {}
	for mission_id: Variant in (ledger_raw as Dictionary):
		if not (mission_id is String):
			return false
		var tier_raw: Variant = (ledger_raw as Dictionary)[mission_id]
		if not (tier_raw is Dictionary):
			return false
		var by_tier: Dictionary = {}
		for tier_key: Variant in (tier_raw as Dictionary):
			if not (tier_key is String) or not (tier_key as String).is_valid_int():
				return false
			var record: MissionCompletionRecord = _parse_completion_record((tier_raw as Dictionary)[tier_key])
			if record == null:
				return false
			by_tier[int(tier_key as String)] = record
		restored_ledger[mission_id as String] = by_tier

		if GGameDataRegistry.get_mission_entry(mission_id as String) == null:
			push_warning("Orphaned completion record for unknown mission_id '%s' — retained, not discarded." % mission_id)

	_completion_ledger = restored_ledger
	return true


## Clears the completion ledger to its starting (brand-new-save) state. Never
## called by mission end — only by SavePersistence when no save data exists
## yet, or when restore_save_data() rejects malformed data.
func reset_to_defaults() -> void:
	_completion_ledger.clear()
