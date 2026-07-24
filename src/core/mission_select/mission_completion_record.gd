class_name MissionCompletionRecord
extends RefCounted

## Runtime, per-`mission_id`-per-`difficulty_tier` completion state.
## RefCounted, NOT a Resource — per-save mutable state, never boot-loaded or
## validated content (ADR-0028 Decision, mirrors ADR-0026's CreatureInstance
## precedent for a plain RefCounted runtime entity).
##
## GDD source: design/gdd/mission-select.md Rule 4, Formula 3.
## Governing ADR: docs/architecture/adr-0028-mission-select-runtime-state.md

var completed: bool = false
## -1.0 sentinel means "no record yet" — never a real completion time.
## Never compared as if it were a real time; see MissionSelect.record_completion().
var best_time_seconds: float = -1.0
