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

## SCATTER targeting mode (tower.md Rule 15) -- deterministic round-robin
## state, reset to these defaults at placement AND on wave_started. Only
## meaningful when focus.targeting_mode == "SCATTER"; unused otherwise.
var scatter_index: int = 0
var last_scatter_target_id: int = -1

## Support/AURA buff state (TD-tower-008 fix) -- refreshed (overwritten, not
## stacked) whenever a Support tower's aura pulse reaches this tower, decayed
## by TowerSystem._tick_combat() each frame. 0.0 = no active buff. See
## TowerSystem.AURA_BUFF_DURATION's own doc comment for why this needs a
## decay timer at all rather than a simple "reapply forever" flag.
var damage_buff_fraction: float = 0.0
var damage_buff_remaining: float = 0.0
