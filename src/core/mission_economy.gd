class_name MissionEconomy
extends Node

## Runtime gold balance owner — Autoload #8, boots after WaveManager (#7).
##
## GDD source: design/gdd/resource-economy.md (Rule 7/8 — gold delivered via
## resources_changed, flat scout_starting_gold grant on SCOUT entry).
## ADR: docs/architecture/adr-0018-mission-economy-gold-balance.md (Accepted).
## Story: production/epics/epic-03-core-economy/story-013-gold-track-scout-starting-grant.md
## (AC-11, AC-12, AC-13).
##
## Owns exactly one piece of mutable state: _gold_balance. The single write
## path is the resources_changed EventBus subscription (accumulate every
## delta, regardless of source — Scout grant, kill drops, spending); the
## single reset trigger is mission_launched (zero, before any of that
## mission's resources_changed grants can arrive, since this Autoload boots
## before any mission scene loads). No other system may mutate _gold_balance
## directly — reads only, via get_gold_balance()/can_afford().
##
## Reads are a documented direct-call exception (ADR-0018), matching the
## same class of latency-sensitive exception already established by Grid
## (ADR-0005) and GameDataRegistry (ADR-0009) — Tower System's placement gate
## (ADR-0008 Gate 2) needs a synchronous, authoritative affordability check,
## not an EventBus round trip.
##
## No SaveRestorer registration. Gold is ephemeral mission-runtime state,
## the same category as other unsaved mission-runtime scalars already
## excluded by save-persistence.md's "What is NOT saved" list (current wave
## number, hero HP, active timers) — it resets naturally every
## mission_launched, matching a fresh default with no persistence code.


var _gold_balance: int = 0


func _ready() -> void:
	GEventBus.resources_changed.connect(_on_resources_changed)
	GEventBus.mission_launched.connect(_on_mission_launched)


func _exit_tree() -> void:
	GEventBus.resources_changed.disconnect(_on_resources_changed)
	GEventBus.mission_launched.disconnect(_on_mission_launched)


## Current runtime gold balance. Direct-call read (ADR-0018) — no EventBus
## round trip. Intended for live HUD display.
##
## Usage:
##   var gold: int = GMissionEconomy.get_gold_balance()
func get_gold_balance() -> int:
	return _gold_balance


## True when cost is affordable at the current balance. Boundary case (AC-13):
## cost == get_gold_balance() returns true — not strictly less-than.
## Resolves ADR-0008 Gate 2's ResourceSystem.can_afford(cost) placeholder;
## Tower System should call this by name.
##
## Usage:
##   if GMissionEconomy.can_afford(placement_cost): ...
func can_afford(cost: int) -> bool:
	return cost <= _gold_balance


## Sole write path. Accumulates every resources_changed delta regardless of
## source (AC-12) — a delta that drives the balance negative is applied as-is,
## no silent clamping (ADR-0018 Validation Criteria).
func _on_resources_changed(gold: int, _source: StringName) -> void:
	_gold_balance += gold


## Sole reset trigger. Resets to 0 immediately on every mission_launched
## (AC-11), including a second mission launched in the same session — not
## just cold boot.
func _on_mission_launched(_mission_id: String, _modifiers: PackedStringArray, _difficulty_tier: int) -> void:
	_gold_balance = 0
