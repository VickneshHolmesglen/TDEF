class_name TowerWaveSummary
extends Resource

## Event-payload Resource for the tower_wave_summary EventBus signal.
##
## ADR-0001 Rule 3: 7 fields — requires Resource subclass payload.
## ADR-0009: Event-payload Resources are short-lived; never saved as .tres files.
## GDD source: design/gdd/event-bus.md — Tower System event catalogue.
##
## Emitted by: Tower System (once per active tower on wave_completed, after HP reset).
## Key subscribers: Mission HUD ("Endless Theorist" feedback display).
##
## Field notes (GDD event-bus.md):
##   max_hp          — allows HUD to reconstruct full HP for towers that took no damage.
##   idle_ticks      — attack-timer expirations with no valid target in range.
##   aura_applications_this_wave — Support pulse count; 0 for non-Support towers.
##   scatter_target_cycle — SCATTER hit map {entity_id -> hit_count};
##                          empty Dictionary for non-SCATTER towers.
##
## Removed fields (do not re-add without catalogue revision):
##   hp_remaining — HP always resets to max_hp at wave end; was always redundant.
##   wave_id      — not required by Tower GDD Rule 23.

@export var tower_id: int = -1
@export var max_hp: float = 0.0
@export var shots_fired: int = 0
@export var damage_dealt: float = 0.0
@export var idle_ticks: int = 0
@export var aura_applications_this_wave: int = 0
@export var scatter_target_cycle: Dictionary = {}  ## Dictionary[int, int]: entity_id -> hit_count
