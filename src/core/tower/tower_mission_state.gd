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
## Shaft/Top (new 2026-09-01) — unlike TowerBlueprintData's own nullable
## fields, these are never null once TowerSystem.place_tower() finishes
## constructing this state: a blueprint with shaft/top == null gets a fresh
## inert ShaftComponent.new()/TopComponent.new() substituted at that point
## (see place_tower()'s own comment), so every consumer downstream of
## placement can assume non-null here.
##
## Defaulted to inert components (2026-10-04 smoke check) rather than null so a
## state built directly (tests, any future restore path) can never crash
## _try_attack()'s unguarded state.top.bonus_type read; place_tower() still
## overwrites both with the blueprint's own duplicated components.
var shaft: ShaftComponent = ShaftComponent.new()
var top: TopComponent = TopComponent.new()
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

## tower.md Rule 23 (TowerWaveSummary) -- per-wave engagement counters,
## accumulated during WAVE_ACTIVE by TowerSystem._try_attack()/
## _apply_splash_damage(), reset to these defaults on wave_started (mirroring
## scatter_index/last_scatter_target_id's own identical reset above), read
## and emitted once per tower on wave_completed, per active tower.
var shots_fired: int = 0
var damage_dealt: float = 0.0
var idle_ticks: int = 0
## Support/AURA only -- number of tower_aura_pulse emissions this wave.
## Always 0 for non-Support archetypes (this tower's weapon never takes the
## AURA branch in _try_attack(), so this field is simply never incremented).
var aura_applications_this_wave: int = 0
## SCATTER Focus only -- entity_id -> hit_count for every target that
## received at least one confirmed shot this wave. Empty for non-SCATTER
## towers (never written to).
var scatter_target_cycle: Dictionary = {}  ## Dictionary[int, int]
