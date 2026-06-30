class_name TowerAuraPulseEvent
extends Resource

## Event-payload Resource for the tower_aura_pulse EventBus signal.
##
## ADR-0001 Rule 3: 4 fields — promoted to Resource subclass for consistency
##   with tower_wave_summary and to allow future field additions without a
##   breaking change. (GDD note: "4 fields — promoted to Resource subclass
##   per Core Rule 4 for consistency [...] to allow future field additions
##   without a breaking change.")
## ADR-0009: Event-payload Resources are short-lived; never saved as .tres files.
## GDD source: design/gdd/event-bus.md — Tower System event catalogue.
##
## Emitted by: Tower System (Support archetype tower's attack timer expires;
##   aura pulse emitted unconditionally — no target required).
## Key subscribers: Damage & Status (apply effect to entities in radius), Mission HUD.
##
## IMPORTANT — anchor_cell removed:
##   D&S derives tower position from tower_id via Grid read.
##   Do not add anchor_cell back without a GDD catalogue revision.

@export var tower_id: int = -1
@export var aura_effect_type: String = ""
@export var aura_effect_value: float = 0.0
@export var aura_radius_cells: int = 0
