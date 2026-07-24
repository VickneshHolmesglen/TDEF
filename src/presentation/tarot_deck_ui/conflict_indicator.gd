class_name ConflictIndicator
extends Node

## Tarot/Mission Select conflict-mapping engine (Story 004, ADR-0027/ADR-0028,
## epic-11-tarot-deck-ui).
##
## GDD source: design/gdd/tarot-deck-ui.md -- Core Rule 6, AC Group 4.
## Story: production/epics/epic-11-tarot-deck-ui/story-004-conflict-indicator.md
##
## The match is a conceptual mapping, NEVER a literal string comparison --
## `modifier_type` and `modifier_id` are disjoint string vocabularies (Tarot's
## own 4 registered modifier_types vs. Mission Select's actual 2-entry
## RUN_MODIFIER_IDS catalogue). MAPPING is this shell's own explicit constant,
## confirmed against both systems' real Formulas/data -- not inferred at
## runtime from string similarity. If Mission Select's modifier_id catalogue
## ever grows, this table needs a corresponding new entry (Tuning Knobs
## maintenance note in the GDD).
##
## Actual Tarot deck-tray UI doesn't exist yet (neither tarot.md's nor
## hero-skill-build.md's screen is built -- OQ-5), so this class owns the
## pure mapping/query LOGIC only, independently testable, exactly the same
## "generic mechanism now, real content later" split Sanctuary UI's own
## RoomHost/TabStrip used throughout this epic. A future Tarot screen story
## queries get_conflicting_modifier_ids()/has_conflict() per slotted card to
## render the actual badge.
##
## "Reads Mission Select's current live value at every render, never a
## cached one" (GDD): MissionSelect exposes no public getter for its private
## _run_modifiers Dictionary, so this class tracks the same state locally via
## MissionSelect's own EventBus emissions -- the identical event stream
## Tarot's own real subscription would use. Cleared on mission_selected
## (mirrors MissionSelect.select_mission()'s own _run_modifiers.clear() at
## the moment CONFIGURING begins for a new mission) -- this is not a
## duplicated reset mechanism, it is this class reacting to the same public
## signal MissionSelect's own reset is announced through.

const MAPPING: Dictionary[String, Array] = {
	"tarot_difficulty_growth_rate": ["difficulty_growth_boost"],
	"tarot_wave_config_override": ["extend_waves", "difficulty_growth_boost"],
	"tarot_speed_scalar_mult": [],
	"tarot_reward_scalar_mult": [],
}

var _active_modifiers: Dictionary[String, float] = {}
var _subscriptions_disconnected: bool = false


func _ready() -> void:
	GEventBus.run_modifier_selected.connect(_on_run_modifier_selected)
	GEventBus.mission_selected.connect(_on_mission_selected)


func _exit_tree() -> void:
	# Idempotent against disconnect_own_subscriptions() already having run as
	# part of the shell's own terminal latch (Story 003, ADR-0032 Section 2) --
	# Godot errors on disconnecting an already-disconnected signal.
	disconnect_own_subscriptions()


## Shell-owned-node contract (same shape as RoomHost/ScreenHost's own room/
## screen contract) -- callable explicitly and synchronously by the shell's
## own terminal latch, not only implicitly via _exit_tree() on scene unload.
func disconnect_own_subscriptions() -> void:
	if _subscriptions_disconnected:
		return
	_subscriptions_disconnected = true
	GEventBus.run_modifier_selected.disconnect(_on_run_modifier_selected)
	GEventBus.mission_selected.disconnect(_on_mission_selected)


## Every currently-active (non-0.0) Mission Select modifier_id that conflicts
## with `tarot_modifier_type` per MAPPING -- a card can conflict with more
## than one selection simultaneously (only possible for
## tarot_wave_config_override, since Mission Select's own catalogue is
## presently 2 mutually-independent modifiers).
func get_conflicting_modifier_ids(tarot_modifier_type: String) -> Array[String]:
	var conflicts: Array[String] = []
	var mapped: Array = MAPPING.get(tarot_modifier_type, [])
	for modifier_id: String in mapped:
		if _active_modifiers.has(modifier_id) and _active_modifiers[modifier_id] != 0.0:
			conflicts.append(modifier_id)
	return conflicts


func has_conflict(tarot_modifier_type: String) -> bool:
	return not get_conflicting_modifier_ids(tarot_modifier_type).is_empty()


func _on_run_modifier_selected(modifier_id: String, modifier_value: float) -> void:
	_active_modifiers[modifier_id] = modifier_value


func _on_mission_selected(_mission_id: String) -> void:
	_active_modifiers.clear()
