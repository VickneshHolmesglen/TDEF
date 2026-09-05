class_name Tarot
extends Node

## Deck management + the mission_launched deck-lock snapshot (Story 001,
## TR-tarot-001, ADR-0027). A real Autoload (GTarot) as of ADR-0035
## (2026-08-12) — previously scene-instanced as a child of TarotDeckUI.tscn,
## which caused a real save-persistence bug (production/qa/bugs/BUG-0001.md)
## and left Tarot unreachable from Sanctuary UI. See ADR-0035 for the full
## migration rationale.
##
## GDD source: design/gdd/tarot.md — Groups 1-2 (Rules 1-5).
##
## Scope of this story: TarotCardResource/TarotModifierEntry data model
## (separate files), deck equip/unequip with slot-cap enforcement
## (Rules 3-4), and the mission_launched deck lock (Rule 5). Modifier
## resolution/emission at SCOUT entry (Story 002), mastery accrual
## (Story 003), rune discovery (Story 004), and SaveRestorer persistence
## (Story 007) are explicitly out of scope here — see story-001's own file.
##
## `_card_unlocked` is the runtime TarotProgressLedger's read-only-from-Tarot
## slice (AC-2): Tarot's own logic (equip_card's gate) only ever reads it,
## never writes it directly. Tests still set it directly as a seam (a
## non-tech unlock path, e.g. a future Encyclopedia purchase, would write
## here too). Defense Building tech tree unlocks are wired as a second,
## OR'd check in is_card_unlocked() — see TarotCardResource.unlock_tech_id
## and that function's own doc comment. Closes tarot.md's previously
## unresolved "how a Tarot card becomes unlocked" Open Question.
##
## Story 002 (TR-tarot-001, ADR-0027): the modifier resolution pipeline
## (`_resolve_scout_modifiers()`, Rule 6) fires on `mission_phase_changed`
## SCOUT entry, emitting one `mission_modifier_applied` per equipped card's
## modifier entry, mastery-scaled via F1. Tarot performs only F1 — F2-stage
## aggregation/clamping across multiple equipped cards is Wave Manager's/
## Monster System's own responsibility as consumers, not implemented here.
## REPLACE-type (Rule 7) single-card-only enforcement is checked at
## equip-time (EC-3/AC-16's equip-time half); the data-error runtime
## fallback ("lowest deck-slot index wins, log the rest as discarded") is
## explicitly Wave Manager's own consumption-side responsibility per the
## GDD's own Formula F2 stacking-rule text. Both Wave Manager
## (wave_manager.gd) and Monster System (monster_manager.gd) do subscribe to
## `mission_modifier_applied` (confirmed by inspection, 2026-09-05) — the
## F2 aggregation/clamping/stacking logic itself lives entirely on their
## side, not here. Tarot subscribes read-only to `run_modifier_selected` (Rule 8) —
## `has_run_modifier_conflict()` is a queryable surface for a future Tarot
## Deck UI conflict indicator, never used to alter resolution logic.
##
## Story 003 (TR-tarot-002, ADR-0027): mastery progression. `_on_mission_terminal()`
## fires on MISSION_COMPLETE or DEFEAT (Rule 10/EC-5 — no outcome gate,
## identical side effects either way), incrementing `_mastery_missions_played`
## for every card_id in `_active_mission_deck` — never for a card that wasn't
## equipped this mission. `_lookup_mastery_tier()` now implements Formula
## F6's real threshold lookup (never independently stored — always
## recomputed, guaranteeing no tier-desync risk structurally).
##
## Story 004 (TR-tarot-003, ADR-0027): rune discovery — `_rune_discovered`
## is a one-way-terminal ledger, identical shape/semantics to Constellation's
## (ADR-0022) and Crafting's (ADR-0023) Discovery Ledgers. The same
## `_on_mission_terminal()` that accrues mastery also checks, per card, "was
## this the card's first-ever mission attempt" (counter was 0 before this
## increment) and fires `tarot_rune_discovered` exactly once per
## `linked_rune_id`. A card is the deck-building unit (effect active only
## while equipped, Group 3); a rune is a permanent, discovery-gated,
## always-on bonus tied 1:1 to a card via `linked_rune_id`, independent of
## whether that card is currently equipped (EC-9: unequipping never
## "undiscovers" a rune). Formula F5's actual additive-bonus aggregate
## computation/clamp is Story 005's own scope — this story covers discovery
## firing and the ledger's deck-independence only.
##
## Story 007 (TR-tarot-002/003, ADR-0027): SaveRestorer persistence, one
## implementation covering all 3 ledgers plus the Sanctuary-time deck
## template (`_current_deck`, saved under the "deck_template" key to match
## the ADR's own naming) — `restore_order = 22` (`save-persistence.md`'s
## already-assigned Feature-layer slot, independent). `_active_mission_deck`
## (the mission-locked snapshot) is deliberately never persisted — ephemeral
## and mission-scoped only, per this story's own Forbidden rule.

const TAROT_DECK_SLOT_COUNT: int = 5
const RESTORE_ORDER: int = 22

## States and Transitions table: mastery_tier_scalar ladder, indexed by tier (0-4).
const MASTERY_TIER_SCALARS: Array[float] = [1.00, 1.15, 1.30, 1.50, 1.75]

## Formula F6: mastery_tier = max { t : mastery_missions_played >= threshold[t] }.
const MASTERY_TIER_THRESHOLDS: Array[int] = [0, 3, 8, 15, 25]

var _current_deck: Array[StringName] = []
var _active_mission_deck: Array[StringName] = []
var _locked: bool = false

## TarotProgressLedger slice owned by this story. mastery_missions_played /
## rune discovery dictionaries (Stories 003/004) are added alongside this by
## whichever story implements them — not present yet, per this story's own
## Out of Scope.
var _card_unlocked: Dictionary[StringName, bool] = {}

## Story 003: TarotProgressLedger's mastery counter, keyed by card_id.
## mastery_tier is deliberately never stored independently — always
## recomputed from this via _lookup_mastery_tier() (Formula F6).
var _mastery_missions_played: Dictionary[StringName, int] = {}

## Story 004: TarotProgressLedger's rune Discovery Ledger, keyed by
## linked_rune_id. One-way-terminal — never reverts once true.
var _rune_discovered: Dictionary[StringName, bool] = {}

## Story 002: read-only cache of run_modifier_selected's modifier_type
## values seen this mission — Rule 8's UI-conflict-awareness subscription.
## Never consulted by _resolve_scout_modifiers(); resolution logic is
## unaffected by this cache's contents.
var _run_modifier_selected_types: Dictionary[String, bool] = {}


func _ready() -> void:
	GEventBus.mission_launched.connect(_on_mission_launched)
	GEventBus.mission_phase_changed.connect(_on_mission_phase_changed)
	GEventBus.run_modifier_selected.connect(_on_run_modifier_selected)
	GEventBus.scene_transition_completed.connect(_on_scene_transition_completed)
	GSavePersistence.register(self, RESTORE_ORDER)


func _exit_tree() -> void:
	GEventBus.mission_launched.disconnect(_on_mission_launched)
	GEventBus.mission_phase_changed.disconnect(_on_mission_phase_changed)
	GEventBus.run_modifier_selected.disconnect(_on_run_modifier_selected)
	GEventBus.scene_transition_completed.disconnect(_on_scene_transition_completed)
	GSavePersistence.unregister(self)


func get_active_card_count() -> int:
	return _current_deck.size()


func get_current_deck() -> Array[StringName]:
	return _current_deck.duplicate()


## Pull-based, matches Crafting's tech-gated recipe check (crafting.gd):
## _card_unlocked itself is still checked first (the existing test seam, and
## a future non-tech unlock source like Encyclopedia purchase) — an
## unlock_tech_id gate is a second, independently-true OR branch, never the
## only path. DefenseBuilding's tech ledger is a permanent one-way unlock
## (never revoked), so no caching/reconciliation is needed here: this always
## reflects DefenseBuilding's live state.
func is_card_unlocked(card_id: StringName) -> bool:
	if _card_unlocked.get(card_id, false):
		return true
	var card: TarotCardResource = GGameDataRegistry.get_tarot_card(card_id)
	if card == null:
		return false
	if card.unlock_tech_id == &"":
		return true
	return GDefenseBuilding.is_tech_unlocked(card.unlock_tech_id)


## Rule 3/AC-5/AC-6: rejects (no event fires) if locked, the card is already
## equipped, the card isn't unlocked (AC-2's read-only gate), the deck is
## already at TAROT_DECK_SLOT_COUNT, or (EC-3/AC-16) the card targets a
## REPLACE-type modifier_type already targeted by another equipped card.
## Fires tarot_deck_changed with the correct incremented count only on
## success.
func equip_card(card_id: StringName) -> bool:
	if _locked:
		return false
	if _current_deck.has(card_id):
		return false
	if not is_card_unlocked(card_id):
		return false
	if _current_deck.size() >= TAROT_DECK_SLOT_COUNT:
		return false
	if _has_replace_type_conflict(card_id):
		return false
	_current_deck.append(card_id)
	GEventBus.tarot_deck_changed.emit(_current_deck.size())
	return true


## EC-3/AC-16 (equip-time half): true if `card_id`'s card has any
## REPLACE-type modifier entry whose modifier_type is already targeted by a
## currently-equipped card. The data-error runtime fallback (if this guard
## is ever bypassed) is Wave Manager's own consumption-side responsibility —
## see this file's class doc comment.
func _has_replace_type_conflict(card_id: StringName) -> bool:
	var card: TarotCardResource = GGameDataRegistry.get_tarot_card(card_id)
	if card == null:
		return false
	for entry: TarotModifierEntry in card.modifiers:
		if not TarotModifierEntry.REPLACE_MODIFIER_TYPES.has(entry.modifier_type):
			continue
		for equipped_id: StringName in _current_deck:
			var equipped_card: TarotCardResource = GGameDataRegistry.get_tarot_card(equipped_id)
			if equipped_card == null:
				continue
			for equipped_entry: TarotModifierEntry in equipped_card.modifiers:
				if equipped_entry.modifier_type == entry.modifier_type:
					return true
	return false


## Rule 4/AC-7: fires tarot_deck_changed with the correct decremented count
## only on success (card was actually present and deck isn't locked).
func unequip_card(card_id: StringName) -> bool:
	if _locked:
		return false
	if not _current_deck.has(card_id):
		return false
	_current_deck.erase(card_id)
	GEventBus.tarot_deck_changed.emit(_current_deck.size())
	return true


## Rule 5/AC-8/AC-9: snapshots the current deck into _active_mission_deck,
## immutable for the mission's full duration. .duplicate() ensures the
## snapshot never aliases _current_deck's own Array — a later (structurally
## impossible mid-mission, per game-concept.md's phase model, but defensively
## guaranteed regardless via the _locked gate above) mutation attempt cannot
## reach _active_mission_deck through a shared reference.
func _on_mission_launched(_mission_id: String, _modifiers: PackedStringArray, _difficulty_tier: int) -> void:
	_active_mission_deck = _current_deck.duplicate()
	_locked = true


## Deck Lock Lifecycle (States and Transitions table): LOCKED -> EDITABLE on
## mission end (MISSION_COMPLETE or DEFEAT), returning to SANCTUARY.
## Story 002 (Rule 6/AC-10): SCOUT entry triggers the modifier resolution
## pipeline. Clearing _run_modifier_selected_types here (not on
## mission_launched) matches Rule 8's read scope — Mission Select's run
## modifiers are selected at the same Sanctuary→Mission commitment moment
## mission_launched fires, so a fresh mission's conflict-awareness cache
## should not carry over a previous mission's selections.
func _on_mission_phase_changed(_previous_phase: String, new_phase: String, _timestamp: float) -> void:
	if new_phase == "MISSION_COMPLETE" or new_phase == "DEFEAT":
		_locked = false
		_on_mission_terminal(new_phase)
	elif new_phase == "SCOUT":
		_resolve_scout_modifiers()


## Real bug found and fixed 2026-07-25: `_locked` was previously cleared
## ONLY by `_on_mission_phase_changed()` reaching MISSION_COMPLETE/DEFEAT —
## but `pause_menu.gd`'s "Quit to Sanctuary" option calls
## `GSceneManager.transition_to_sanctuary()` directly, with no
## `mission_phase_changed` emission at all, leaving `_locked` permanently
## stuck `true` after a mid-mission quit (Tarot Deck UI's own Loadout entry
## would then open into a genuinely LOCKED deck screen with no unlock path
## ever firing again). Mirrors `hero_skill_build.gd`'s own already-correct
## `_is_sanctuary` mechanism, which already unlocks via this exact signal —
## Tarot was the one system missing it. Redundant-but-harmless on the normal
## mission-complete path (unlock already happened earlier, via
## `_on_mission_phase_changed()` above, well before the eventual scene
## transition) — this is the sole unlock path for the pause-menu-bypass case.
func _on_scene_transition_completed(target_context: String, _mission_id: String) -> void:
	if target_context == "SANCTUARY":
		_locked = false


## Rule 10/EC-5/AC-21/22/23: increments mastery_missions_played by exactly 1
## for every card_id present in _active_mission_deck — MISSION_COMPLETE and
## DEFEAT both trigger this identically (engagement, not victory, is what
## proves a card out). A card never equipped this mission is untouched.
##
## Rule 15/AC-27/28/29 (Story 004): "first-ever mission attempt" is checked
## BEFORE the counter increments — a card whose counter is currently 0 is
## experiencing its first attempt this call. This ordering matters: reading
## is_first_attempt after incrementing would make every card look like a
## repeat attempt.
func _on_mission_terminal(_outcome: String) -> void:
	for card_id: StringName in _active_mission_deck:
		var is_first_attempt: bool = _mastery_missions_played.get(card_id, 0) == 0
		_mastery_missions_played[card_id] = _mastery_missions_played.get(card_id, 0) + 1
		if is_first_attempt:
			_maybe_discover_rune(card_id)


## AC-28/29: fires tarot_rune_discovered exactly once per linked_rune_id,
## permanently — _rune_discovered is one-way-terminal, never reverts.
func _maybe_discover_rune(card_id: StringName) -> void:
	var card: TarotCardResource = GGameDataRegistry.get_tarot_card(card_id)
	if card == null:
		return
	var rune_id: StringName = card.linked_rune_id
	if rune_id == &"" or _rune_discovered.get(rune_id, false):
		return
	_rune_discovered[rune_id] = true
	GEventBus.tarot_rune_discovered.emit(String(rune_id), String(card_id))


## AC-30: deck-independent — a discovered rune's state is readable
## regardless of whether its card is currently equipped (Formula F5's
## bonus-application logic itself is Story 005's own scope).
func is_rune_discovered(rune_id: StringName) -> bool:
	return _rune_discovered.get(rune_id, false)


## Story 005, Formula F5/AC-34: additive stacking across every DISCOVERED
## rune whose linked card targets modifier_type, clamped [0.00, 0.30].
## Deliberately scans ALL registered cards (not just _active_mission_deck)
## since a discovered rune's bonus applies "regardless of deck composition"
## (Rule 16) — a card need not be currently equipped for its already-proven
## rune to keep contributing.
func compute_rune_bonus(modifier_type: StringName) -> float:
	var total: float = 0.0
	var all_cards: Dictionary[StringName, TarotCardResource] = GGameDataRegistry.get_all_tarot_cards()
	for card_id: StringName in all_cards:
		var card: TarotCardResource = all_cards[card_id]
		if card.linked_rune_id == &"" or not _rune_discovered.get(card.linked_rune_id, false):
			continue
		for entry: TarotModifierEntry in card.modifiers:
			if entry.modifier_type == modifier_type:
				total += card.rune_bonus_flat
				break
	return clampf(total, 0.0, 0.30)


## Formula F6/AC-24: mastery_tier is never independently stored — always
## recomputed from _mastery_missions_played, guaranteeing no tier-desync
## risk structurally (not by convention).
func _lookup_mastery_tier(card_id: StringName) -> int:
	var played: int = _mastery_missions_played.get(card_id, 0)
	var tier: int = 0
	for t in range(MASTERY_TIER_THRESHOLDS.size()):
		if played >= MASTERY_TIER_THRESHOLDS[t]:
			tier = t
	return tier


func get_mastery_missions_played(card_id: StringName) -> int:
	return _mastery_missions_played.get(card_id, 0)


func get_mastery_tier(card_id: StringName) -> int:
	return _lookup_mastery_tier(card_id)


## Rule 6/AC-10/AC-11: iterates _active_mission_deck (the SCOUT-time locked
## snapshot, not the live _current_deck), emitting one mission_modifier_applied
## per TarotModifierEntry across all equipped cards, mastery-scaled via F1.
## A deck template referencing an unknown card_id is skipped with a warning,
## never a crash (orphaned content, mirrors this project's established
## unknown-content-id handling elsewhere).
func _resolve_scout_modifiers() -> void:
	for card_id: StringName in _active_mission_deck:
		var card: TarotCardResource = GGameDataRegistry.get_tarot_card(card_id)
		if card == null:
			push_warning("Tarot: deck template references unknown card_id '%s' — skipped." % card_id)
			continue
		var tier: int = _lookup_mastery_tier(card_id)
		var scalar: float = MASTERY_TIER_SCALARS[tier]
		for entry: TarotModifierEntry in card.modifiers:
			var effective_value: float = entry.base_modifier_value * scalar
			GEventBus.mission_modifier_applied.emit(String(entry.modifier_type), effective_value, String(card_id))


## Rule 8: read-only — Tarot never performs resolution logic from this
## subscription, only caches modifier_type values for a future Tarot Deck UI
## conflict indicator (has_run_modifier_conflict()).
func _on_run_modifier_selected(modifier_id: String, _modifier_value: float) -> void:
	_run_modifier_selected_types[modifier_id] = true


## AC-19: true if a Mission Select run modifier already targets modifier_type
## — surfaced for UI, never consulted by _resolve_scout_modifiers().
func has_run_modifier_conflict(modifier_type: String) -> bool:
	return _run_modifier_selected_types.get(modifier_type, false)


# ---------------------------------------------------------------------------
# SaveRestorer interface (ADR-0003, ADR-0027) — Story 007
# ---------------------------------------------------------------------------

func get_save_key() -> String:
	return "tarot"


## StringName keys/values are explicitly converted to String here (never
## relying on store_var()'s native StringName serialization) — matches this
## project's established convention (see hero.gd's own get_save_data()
## comment for the full rationale).
func get_save_data() -> Dictionary:
	var mastery_data: Dictionary = {}
	for card_id: StringName in _mastery_missions_played:
		mastery_data[String(card_id)] = _mastery_missions_played[card_id]
	var rune_data: Dictionary = {}
	for rune_id: StringName in _rune_discovered:
		rune_data[String(rune_id)] = _rune_discovered[rune_id]
	var unlocked_data: Dictionary = {}
	for card_id: StringName in _card_unlocked:
		unlocked_data[String(card_id)] = _card_unlocked[card_id]
	var deck_template: Array = []
	for card_id: StringName in _current_deck:
		deck_template.append(String(card_id))
	return {
		"mastery_missions_played": mastery_data,
		"rune_discovered": rune_data,
		"card_unlocked": unlocked_data,
		"deck_template": deck_template,
	}


## Returns false (not void!) on any malformed/missing data so SavePersistence
## falls back to reset_to_defaults() for this system, matching every other
## SaveRestorer in this project. Validates shape before mutating any field —
## no partial-restore side effects on a rejected payload. _active_mission_deck
## is never touched here — it is mission-scoped only, never persisted.
func restore_save_data(data: Dictionary) -> bool:
	if not (data.has("mastery_missions_played") and data.has("rune_discovered")
			and data.has("card_unlocked") and data.has("deck_template")):
		return false

	var mastery_raw: Variant = data["mastery_missions_played"]
	var rune_raw: Variant = data["rune_discovered"]
	var unlocked_raw: Variant = data["card_unlocked"]
	var deck_raw: Variant = data["deck_template"]
	if not (mastery_raw is Dictionary and rune_raw is Dictionary
			and unlocked_raw is Dictionary and deck_raw is Array):
		return false

	var restored_mastery: Dictionary[StringName, int] = {}
	for key: Variant in (mastery_raw as Dictionary):
		if not (key is String):
			return false
		var value: Variant = (mastery_raw as Dictionary)[key]
		if not (value is int or value is float):
			return false
		restored_mastery[StringName(key as String)] = int(value)

	var restored_rune: Dictionary[StringName, bool] = {}
	for key: Variant in (rune_raw as Dictionary):
		if not (key is String):
			return false
		var value: Variant = (rune_raw as Dictionary)[key]
		if not (value is bool):
			return false
		restored_rune[StringName(key as String)] = value as bool

	var restored_unlocked: Dictionary[StringName, bool] = {}
	for key: Variant in (unlocked_raw as Dictionary):
		if not (key is String):
			return false
		var value: Variant = (unlocked_raw as Dictionary)[key]
		if not (value is bool):
			return false
		restored_unlocked[StringName(key as String)] = value as bool

	var restored_deck: Array[StringName] = []
	for entry: Variant in (deck_raw as Array):
		if not (entry is String):
			return false
		restored_deck.append(StringName(entry as String))

	_mastery_missions_played = restored_mastery
	_rune_discovered = restored_rune
	_card_unlocked = restored_unlocked
	_current_deck = restored_deck
	return true


## Clears all 4 persisted structures to their starting (brand-new-adventure)
## state, plus the mission-scoped fields for good measure. Never called by
## mission end (MISSION_COMPLETE/DEFEAT/abandon) — only by SavePersistence
## when no save data exists yet, or when restore_save_data() rejects
## malformed data.
func reset_to_defaults() -> void:
	_mastery_missions_played.clear()
	_rune_discovered.clear()
	_card_unlocked.clear()
	_current_deck.clear()
	_active_mission_deck.clear()
	_locked = false
