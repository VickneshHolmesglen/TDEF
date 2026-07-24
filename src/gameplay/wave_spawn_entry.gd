class_name WaveSpawnEntry
extends Resource

## Single-lane spawn entry used to drive WaveManager's spawn coroutine.
## Embedded inside WaveScript.entries (ADR-0009: "WaveConfig — Embedded
## Nested Resources").
##
## Story 006 (epic-04-wave-manager) converted this from `extends RefCounted`
## to `extends Resource`: RefCounted objects cannot be @export-ed inside
## another Resource's typed Array, and WaveScript.entries: Array[WaveSpawnEntry]
## must be .tres-serializable per ADR-0009. `to_payload()`'s 4-arg signature
## and `_init()` are preserved unchanged — Resource and RefCounted share enough
## API surface that this conversion is a low-risk, additive change (verified
## against the full existing wave_manager test suite; see Story 006 report).
##
## Story 007 (round-robin-spawn-cells) added `spawn_cell_index` below, per
## ADR-0009's canonical schema: a positive index into WaveManager's
## `_spawn_cells` array (modulo-wrapped if out of range), or -1 for
## round-robin auto-assignment (WaveManager._resolve_spawn_cell()).

## Story S4-09 (mission-scene-assembly) fix, empirically verified (not
## assumed) against the real pinned Godot 4.6.2 engine via a
## ResourceSaver.save()/ResourceLoader.load() round-trip: plain (non-@export)
## GDScript `var` fields do NOT survive .tres serialization — they silently
## reset to their field defaults on load. monster_id/pre_delay/difficulty_tier
## were left un-exported when this class was converted from RefCounted to
## Resource (Story 006) "per ADR-0009... must be .tres-serializable" — that
## conversion's whole stated purpose was defeated for 3 of this class's 4
## fields, since only spawn_cell_index (Story 007) was ever actually marked
## @export. Adding @export here is additive/non-breaking: WaveSpawnEntry.new(...)
## construction (used throughout the existing test suite) is unaffected; this
## only changes Inspector visibility and .tres storage eligibility, which is
## exactly what real WaveConfig .tres content authoring (S4-09) requires.

## Registry id of the monster to spawn (matches MonsterResource.monster_id).
@export var monster_id: StringName = &""

## Seconds to wait before this entry spawns, measured from the previous
## entry's spawn (or from spawn-sequence start / templates_ready for the
## first entry). Matches ADR-0012's WaveSpawnEntry.delay_sec / pre_delay.
@export var pre_delay: float = 0.0

## Difficulty tier forwarded into the MonsterSpawnRequest payload.
@export var difficulty_tier: int = 1

## Story 007 / Rule 15b: >= 0 selects `_spawn_cells[spawn_cell_index % size]`
## (modulo-wrapped, with a push_warning if out of range); -1 (default) selects
## round-robin auto-assignment via WaveManager._round_robin_counter.
@export var spawn_cell_index: int = -1


func _init(p_monster_id: StringName = &"", p_pre_delay: float = 0.0, p_difficulty_tier: int = 1,
		p_spawn_cell_index: int = -1) -> void:
	monster_id = p_monster_id
	pre_delay = p_pre_delay
	difficulty_tier = p_difficulty_tier
	spawn_cell_index = p_spawn_cell_index


## Builds the MonsterSpawnRequest payload for this entry.
func to_payload(wave_index: int, wave_reward_scalar: float, spawn_cell: Vector2i,
		is_penultimate_wave: bool) -> MonsterSpawnRequest:
	var payload := MonsterSpawnRequest.new()
	payload.monster_id = monster_id
	payload.spawn_cell = spawn_cell
	payload.wave_index = wave_index
	payload.difficulty_tier = difficulty_tier
	payload.wave_reward_scalar = wave_reward_scalar
	payload.is_penultimate_wave = is_penultimate_wave
	return payload
