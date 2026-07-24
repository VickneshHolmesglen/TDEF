# Story 008: Mission Catalogue & `cell_size` Resolution

> **Epic**: Epic 07 — Cross-Cutting Flow Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Config/Data
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/mission-select.md`
**Requirement**: `TR-missel-002` (data model/`cell_size` portion)

**ADR Governing Implementation**: ADR-0028 (Mission Select Runtime State and Retry Architecture)
**ADR Decision Summary**: `MissionEntry` (static, immutable, `GameDataRegistry`-backed) carries `mission_id`, `display_name`, `grid_config: GridConfig`, `wave_config_path`, `base_wave_count`, `recommended_difficulty_tier`. `cell_size = 64.0` is a fixed project-wide constant, closing Grid System's OQ-4 — `GridConfig`'s schema is unchanged, but every mission's authoring must populate it with the fixed value.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Reuses ADR-0009's `GameDataRegistry` convention. No new engine subsystem.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0009/ADR-0028 directly.
- Forbidden: Never let `MissionEntry.grid_config.cell_size` vary per mission — the actual mission-shape/difficulty lever is `grid_cols`×`grid_rows` and `_cell_types`, not `cell_size`.
- Guardrail: `base_wave_count` is a **display cache only** — Wave Manager's own loaded `WaveConfig` remains the sole runtime source of truth for actual wave count; Mission Select never reads `WaveConfig` at runtime to avoid cross-system coupling.

---

## Acceptance Criteria

*From GDD `design/gdd/mission-select.md`, scoped to this story:*

- [x] AC-1 *(Config/Data)* — every `MissionEntry.grid_config.cell_size` reads exactly `64.0` with zero variance across the catalogue
- [x] AC-2 — `cell_size` identical (`64.0`) across two missions with deliberately different `grid_cols`/`grid_rows`/`_cell_types`, proving it's a fixed constant carried through `GridConfig`, not an authored per-mission value
- [x] AC-3 — `MissionEntry.base_wave_count` matches its linked `WaveConfig.wave_scripts.size()` at content-authoring time (Config/Data smoke check, not a runtime assertion)

---

## Implementation Notes

*Derived from ADR-0028 Implementation Guidelines:*

```gdscript
# MissionEntry (assets/data/missions/*.tres, loaded by GameDataRegistry)
class_name MissionEntry extends Resource
@export var mission_id: String = ""
@export var display_name: String = ""
@export var grid_config: GridConfig = null
@export var wave_config_path: String = ""
@export var base_wave_count: int = 5
@export var recommended_difficulty_tier: int = 1
func validate() -> Array[String]: ...   # confirms grid_config.cell_size == 64.0 (Rule 2)
```

- `cell_size = 64.0` world units, for every mission, always — closes Grid System's OQ-4. No other GDD's formulas/tuning knobs currently scale with a *varying* `cell_size` (hero movement feel, `tower_attack_range_cells_max`=8, `hero_class_proximity_radius_cells`=3 are all calibrated once against a single implicit physical scale).
- Registry action: `cell_size` (value `64.0`) is registered in `design/registry/entities.yaml` as a project-wide constant, sourced from `mission-select.md`, referenced by `grid-system.md` — already done per `mission-select.md`'s own Open Questions (marked RESOLVED 2026-07-17).
- `base_wave_count` sync with `WaveConfig.wave_scripts.size()` is enforced by a content-validation script (out of scope for this GDD, mirrors Wave Manager's own `AC-19b` CI pattern) — not a runtime check.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 013: `MissionRuntimeState`'s `GridConfig` same-instance guarantee (this story only covers the static `MissionEntry` schema)
- Story 009: `completion_records`/`CompletionLedger` (a separate runtime structure per ADR-0028, not part of `MissionEntry`)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-1**: Uniform `cell_size` across catalogue *(Config/Data)*
  - Given: the Alpha mission catalogue (4–6 `MissionEntry` resources)
  - When: every entry's `grid_config.cell_size` field is inspected
  - Then: reads exactly `64.0` for every mission with zero variance

- **AC-2**: `cell_size` fixed while map footprint varies
  - Given: two missions with deliberately different `grid_cols`/`grid_rows`/`_cell_types`
  - When: each mission's `GridConfig` is delivered to Grid at `mission_launched`
  - Then: `cell_size` is identical (`64.0`) across both while `grid_cols`/`grid_rows`/`_cell_types` differ

- **AC-3**: `base_wave_count` sync *(Config/Data)*
  - Given: a `MissionEntry`'s `base_wave_count` field
  - When: compared against its linked `WaveConfig.wave_scripts.size()` (content-validation script only, never runtime)
  - Then: the two values match at content-authoring time

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- `production/qa/smoke-mission-catalogue-cell-size.md` — content-validation smoke check pass

**Status**: [x] Created — `production/qa/smoke-mission-catalogue-cell-size.md`

---

## Dependencies

- Depends on: None (foundational story for this system)
- Unlocks: Story 009, Story 013

**Unblocked**: ADR-0028 accepted 2026-07-18 (Sprint 6, S6-03).

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 3/3 passing — live-verified via Godot MCP (headless class-cache rebuild + `run_project`/`run_script`), not static inspection alone.
**Deviations**:
- ADVISORY: Story cites `TR-missel-002`, but `tr-registry.yaml`'s actual text for that ID covers Rule 10/EC-6 (Story 013's territory), not Rule 1/2's `MissionEntry`/`cell_size` schema. No TR-ID currently covers this story's actual requirement — flagged for `/architecture-review` to assign one; did not block implementation since ADR-0028/GDD text was unambiguous.
- ADVISORY: `MissionEntry` authored at `assets/data/missions/entries/`, not the literal `assets/data/missions/*.tres` path in ADR-0028's Key Interfaces — that path collides with the pre-existing `MissionResource` (S5-02) loader already scanning it. Flagged for ADR-0028's next revision pass.
- ADVISORY: Catalogue has 2 entries (`the_gap` real, `the_narrows` a deliberate minimal stub for AC-2's footprint-variance proof), not the GDD's aspirational 4-6 — full Alpha roster authoring is separate content work, out of this story's `cell_size`-resolution scope.
**Test Evidence**: Config/Data — smoke check at `production/qa/smoke-mission-catalogue-cell-size.md`.
**Code Review**: Skipped — Lean mode / explicit user instruction to defer review until Story 014.
