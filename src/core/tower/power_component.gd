class_name PowerComponent
extends Resource

## Power slot component (ADR-0008 Amendment 2026-07-19 — implementation
## catch-up). Schema per design/gdd/tower.md's Power table (lines ~86-93).
##
## constellation_eligibility_tag: relocated here from the flat TowerData
## stopgap added in Sprint 6 (S6-08) to close Constellation's OQ-4 before this
## component existed — see tower_system.gd's own doc comment for the
## EventBus payload sourcing change this move requires.

## Content-authored identifier for this named component asset (e.g.
## "power_none" for an unequipped Power slot) — see
## FoundationComponent.component_id's doc comment.
@export var component_id: String = ""

@export var effect_type: String = ""        # any effect id, or ""
@export var effect_value: float = 0.0       # [0.0, ...]
@export var effect_duration: float = 0.0    # [0.0, ...], 0 = instant
@export var constellation_eligibility_tag: String = ""  # any tag id, or ""
@export var damaged: bool = false


func validate() -> bool:
	if effect_value < 0.0:
		push_error("[PowerComponent] effect_value %.2f must be >= 0.0" % effect_value)
		return false
	if effect_duration < 0.0:
		push_error("[PowerComponent] effect_duration %.2f must be >= 0.0" % effect_duration)
		return false
	return true
