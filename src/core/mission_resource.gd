class_name MissionResource
extends Resource

## Data definition for a single mission's player-facing descriptive text.
##
## S5-02 — closes the missing-MissionResource gap flagged in
## design/ux/pause-menu.md (Open Questions) and the Wave Manager epic
## (Story 006/EPIC.md). ADR-0009: Resource data model — one class_name per
## file, exported fields only.
##
## Intentionally minimal: objective text only, not a general-purpose mission
## metadata system. WaveConfig (assets/data/waves/{mission_id}_waves.tres)
## already owns wave composition data — this Resource owns only what the
## player is told, not what spawns. Keyed by mission_id, the same key
## mission_launched's EventBus payload already carries.

@export var mission_id: StringName = &""
@export var objective_text: String = ""


## Load-time validation. Called by GameDataRegistry at boot (ADR-0009).
## Returns [] when valid; one string per invalid field otherwise.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if mission_id == &"":
		errors.append("mission_id must not be empty")
	if objective_text == "":
		errors.append("objective_text must not be empty")
	return errors
