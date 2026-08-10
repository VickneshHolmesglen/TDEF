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
## single reset trigger is grid_initialized (zero, before any of that
## mission's resources_changed grants can arrive). No other system may
## mutate _gold_balance directly — reads only, via
## get_gold_balance()/can_afford().
##
## Reset trigger changed from mission_launched to grid_initialized,
## 2026-08-11 (real bug found while wiring ResourceEconomy into a live scene
## for the first time — see ADR-0018's dated amendment for the full account).
## ADR-0018 originally claimed mission_launched's reset "fires before Wave
## Manager's own SCOUT transition completes... so the grant always lands on
## a freshly-zeroed balance" — that claim was never actually true: Godot
## calls mission_launched subscribers in connection/boot order, and
## WaveManager (boot #7, connects before this Autoload at #8) drives its
## entire SCOUT-entry cascade — including ResourceEconomy's Scout-starting-
## gold grant — synchronously to completion INSIDE its own mission_launched
## handler, before this Autoload's mission_launched handler ever runs. The
## grant landed, then this handler's unconditional `_gold_balance = 0`
## immediately wiped it. Invisible until now because ResourceEconomy was
## never actually instanced in any real scene before this pass.
## grid_initialized (event_bus.gd) already exists for exactly this class of
## problem — MissionScene's own camera-positioning bug (2026-08-09) was
## fixed by subscribing to grid_initialized instead of mission_launched for
## the identical reason: "fires before the racy cascade even starts, not
## merely early within it — closes the ordering gap structurally rather
## than by connection-order luck." Reusing that same signal here rather
## than reordering Autoload boot positions, which would additionally
## invalidate WaveManager's own Accepted boot-position-7 claim in ADR-0012.
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
## grid_initialized, matching a fresh default with no persistence code.


var _gold_balance: int = 0


func _ready() -> void:
	GEventBus.resources_changed.connect(_on_resources_changed)
	GEventBus.grid_initialized.connect(_on_grid_initialized)


func _exit_tree() -> void:
	GEventBus.resources_changed.disconnect(_on_resources_changed)
	GEventBus.grid_initialized.disconnect(_on_grid_initialized)


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


## Sole reset trigger. Resets to 0 immediately on every grid_initialized
## (AC-11), including a second mission launched in the same session — not
## just cold boot. grid_initialized fires once per mission, strictly before
## mission_launched (see event_bus.gd's own doc comment and this file's
## class doc for why grid_initialized, not mission_launched, is used here).
func _on_grid_initialized(_cols: int, _rows: int, _cell_size: float) -> void:
	_gold_balance = 0
