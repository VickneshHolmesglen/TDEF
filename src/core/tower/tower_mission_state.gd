class_name TowerMissionState
extends RefCounted

## Per-placed-tower runtime state. Created at placement, freed when tower is
## sold or destroyed. RefCounted — no queue_free() required.
##
## ADR-0008: never @export on a persistent node (freed automatically when
##   placed_towers dict removes the entry).
##
## Amendment 2026-07-19 (ADR-0008 implementation catch-up): `tower_data:
## TowerData` (a bare shared reference to the blueprint) replaced by 4
## independent `duplicate_deep()`'d component copies. `placement_cost` is
## copied by value (immutable identity data, no isolation concern) rather
## than duplicated as a 5th component — it never has a "damaged"-style
## mutable-mission-state concept per tower.md's schema.

var tower_id: int = -1
var placement_cost: int = 0
var foundation: FoundationComponent = null
var weapon: WeaponComponent = null
var focus: FocusComponent = null
var power: PowerComponent = null
var grid_position: Vector2i = Vector2i.ZERO
var current_hp: float = 0.0
var max_hp: float = 0.0
var attack_timer_remaining: float = 0.0 # Seconds until next attack (0 = fire immediately)
var damaged: bool = false
