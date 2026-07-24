class_name WaveConfig
extends Resource

## Per-mission wave composition data. One WaveConfig.tres per mission, stored
## at assets/data/waves/{mission_id}_waves.tres (ADR-0009: Resource Data Model
## — "WaveConfig — Embedded Nested Resources"). WaveScript / WaveSpawnEntry
## are embedded sub-Resources — no separate .tres files per wave or entry.
##
## Field schema note (Story 006, epic-04-wave-manager, 2026-07-05): ADR-0009's
## canonical schema (Key Interfaces section) lists `reward_base` but not
## `wave_time_budget`. This story's own Implementation Notes and AC-41 require
## `wave_time_budget` — it has no other source anywhere in this codebase.
## Resolution: keep BOTH fields. `wave_time_budget` is read and validated by
## WaveManager (AC-41 — pre_delay-sum overrun check, logs only). `reward_base`
## is kept for ADR-0009 schema-completeness; it is NOT yet wired to anything —
## Story 004's wave_reward_scalar formula reads WaveManager's own
## `difficulty_growth_rate` field, not this Resource's `reward_base`. Do not
## drop either field.
##
## GDD source: design/gdd/wave-manager.md
## Governing ADRs: docs/architecture/adr-0009-resource-data-model.md (Accepted)
##                  docs/architecture/adr-0012-wave-manager-fsm.md (Accepted)

@export var wave_scripts: Array[WaveScript] = []
@export var difficulty_growth_rate: float = 0.20  ## safe range 0.10-0.25 (GDD Tuning Knobs); bounds-checked at mission_launched via WaveManager._validate_difficulty_growth_rate() — NOT clamped here
@export var wave_time_budget: float = 90.0        ## seconds; safe range 45-120s (AC-41 overrun check — logs only, never clamped)
@export var reward_base: float = 1.0              ## ADR-0009 canonical field; unused by any story as of Story 006 — kept for schema completeness, do not remove


## Load-time validation (ADR-0009 pattern — kept for schema-completeness /
## GameDataRegistry-style API parity with MonsterResource). NOTE: WaveManager's
## actual mission_launched runtime path does NOT call this method — it
## performs its own more specific checks (AC-19 empty wave_scripts guard,
## AC-41 per-wave pre_delay-sum overrun with offending wave index, and reuse
## of Story 004's _validate_difficulty_growth_rate()) which this generic
## Array[String] return shape can't express as precisely. This method exists
## for ADR-0009 API consistency and any future caller (e.g. a content
## validator tool, AC-19b) that wants a simple valid/invalid check.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if wave_scripts.is_empty():
		errors.append("wave_scripts must not be empty")
	if wave_time_budget <= 0.0:
		errors.append("wave_time_budget must be > 0 (got %.2f)" % wave_time_budget)
	if difficulty_growth_rate < 0.10 or difficulty_growth_rate > 0.25:
		errors.append("difficulty_growth_rate %.2f outside valid range [0.10, 0.25]" % difficulty_growth_rate)
	return errors
