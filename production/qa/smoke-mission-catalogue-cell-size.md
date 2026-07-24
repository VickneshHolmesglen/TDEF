# Smoke Check: Mission Catalogue & `cell_size` Resolution

**Story**: `production/epics/epic-07-cross-cutting-flow/story-008-missionselect-catalogue-cell-size.md`
**Type**: Config/Data — content-validation smoke check, not a runtime assertion.
**Date**: 2026-07-19

## Catalogue Under Test

| File | mission_id | grid_config (cols x rows @ cell_size) | wave_config_path | base_wave_count |
|------|------------|----------------------------------------|-------------------|------------------|
| `assets/data/missions/entries/the_gap_entry.tres` | `the_gap` | 16 x 12 @ 64.0 | `assets/data/waves/the_gap_waves.tres` | 6 |
| `assets/data/missions/entries/the_narrows_entry.tres` | `the_narrows` | 10 x 8 @ 64.0 | `assets/data/waves/the_narrows_waves.tres` | 1 |

**Scope note**: Only 2 catalogue entries exist at this point (not the GDD's aspirational 4-6), since only `the_gap` has real playable content (Epic 04 capstone scene). `the_narrows` is a deliberate content-authoring stub — a minimal `MissionEntry` + a 1-wave/1-spawn `WaveConfig` — authored solely to give AC-2 a second, structurally-real footprint to compare against. It is catalogue data only; no `the_narrows` mission scene exists. Expanding the catalogue to a full Alpha roster is content-authoring work for a later pass, not part of this story's `cell_size`-resolution scope.

## AC-1: Uniform `cell_size` across catalogue

Both entries inspected directly:
- `the_gap_entry.tres` → `grid_config.cell_size = 64.0`
- `the_narrows_entry.tres` → `grid_config.cell_size = 64.0`

**Result: PASS** — zero variance across the catalogue.

## AC-2: `cell_size` fixed while map footprint varies

- `the_gap`: `cols=16, rows=12, cell_size=64.0`
- `the_narrows`: `cols=10, rows=8, cell_size=64.0`

`cols`/`rows` differ between the two entries; `cell_size` is identical (`64.0`) in both. Confirms `cell_size` is carried through `GridConfig` as a fixed constant, not an authored per-mission value.

**Result: PASS**

## AC-3: `base_wave_count` sync with linked `WaveConfig`

- `the_gap_entry.tres`: `base_wave_count = 6`. `the_gap_waves.tres` → `wave_scripts` array has 6 entries (`Resource_ojowb`, `Resource_ediou`, `Resource_i6pu8`, `Resource_qvka1`, `Resource_xknpw`, `Resource_x4oen`). Match confirmed.
- `the_narrows_entry.tres`: `base_wave_count = 1`. `the_narrows_waves.tres` → `wave_scripts` array has 1 entry (`Resource_narrows_wave_1`). Match confirmed.

**Result: PASS**

## Verdict

**PASS** — all 3 ACs verified by direct static inspection of the authored `.tres` content. No CI content-validator tool exists yet (tracked as future tooling work, same status as Wave Manager's own AC-19b — never built, mirrors that precedent per this story's Implementation Notes). This smoke check is the manual substitute until that tooling exists.
