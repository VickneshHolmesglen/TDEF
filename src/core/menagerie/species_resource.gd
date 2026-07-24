class_name SpeciesResource
extends Resource

## Minimal static species data for Menagerie's 5-species roster (Story 007).
##
## GDD source: design/gdd/menagerie.md — Rule 1 (Species Roster).
## ADR-0009: Resource data model — one class_name per file, exported fields only.
## ADR-0026: Menagerie creature lifecycle — deliberately minimal (no
## discovery/unlock gate per Rule 1), loaded via GameDataRegistry.

@export var species_id: StringName = &""
@export var species_tier: int = 1  # 1-3

## Load-time validation. Called by GameDataRegistry at boot (ADR-0009).
func validate() -> Array[String]:
	var errors: Array[String] = []
	if species_id == &"":
		errors.append("species_id must not be empty")
	if species_tier < 1 or species_tier > 3:
		errors.append("species_tier must be 1-3 (got %d)" % species_tier)
	return errors
