# Story 007: Wave Composition Preview Display (PC-5, composition half)

> **Epic**: Epic 09 — Mission HUD
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/mission-hud.md`
**Requirement**: `TR-hud-000` *(untraced — scoped from Core Rules Group 3c, Rules 11f-11i; closes `tower.md` Rule 8's composition-bucketing mandate)*

**ADR Governing Implementation**: ADR-0031 (Mission HUD Architecture)
**ADR Decision Summary**: `wave_preview_available`'s `composition` field is resolved via `GameDataRegistry.get_monster(entry.monster_id)` — a synchronous, read-only static-data lookup, no caching required. Display differs by phase: SCOUT gets the full per-monster-type breakdown, INTERMISSION gets a tier-bucketed summary.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: None beyond ADR-0031's general notes.

**Control Manifest Rules (this layer)**:
- Required: N/A.
- Forbidden: SCOUT must NOT collapse to the same tier-only view as INTERMISSION — this was a real, previously-shipped-then-caught bug in the GDD's drafting history (Rule 11g's correction), contradicting `tower.md` Rule 8's explicit "full composition... complete information" requirement for SCOUT's Wave 1 preview.
- Guardrail: Recomputed fresh on every `wave_preview_available` — never diffed or carried over from the previous wave's data.

---

## Acceptance Criteria

*From GDD Core Rules Group 3c (Rules 11f-11i):*

- [x] AC-35 — on `wave_preview_available` received during an INTERMISSION mount: for each composition entry, resolve its tier via `GameDataRegistry.get_monster_resource(entry.monster_id).tier` and accumulate `entry.count` into one of 3 running totals (`STANDARD`/`ELITE`/`BOSS`); display one line per non-zero bucket (e.g. "10 STANDARD", "2 ELITE")
- [x] AC-36 — on `wave_preview_available` received during the SCOUT mount: render the FULL per-entry breakdown directly from `composition` — each entry's `monster_id` resolved to `display_name` via `GameDataRegistry.get_monster_resource(entry.monster_id).display_name`, alongside its `count`, with NO tier aggregation
- [x] AC-37 — which display path runs (AC-35 vs AC-36) is determined by which phase the Planning Cluster was just (re)instantiated into (MissionHud's `_current_phase`, read synchronously at mount time) — never by inspecting the event payload's own content
- [x] AC-38 — both displays are owned by the Planning Cluster instance (same `queue_free()`-on-WAVE_ACTIVE lifecycle as Story 003's route-preview overlay) — re-populated fresh from the next `wave_preview_available` on every SCOUT/INTERMISSION mount, never carried over or diffed

---

## Implementation Notes

*Derived from ADR-0031/GDD Implementation Guidelines:*

```gdscript
# Inside PlanningCluster (Story 002's scaffold), set by MissionHud's
# _on_wave_preview_available (Story 006 already owns this outer-root
# subscription — this story adds the composition-rendering call alongside
# Story 006's boss-cell caching, same handler, different payload field).
func render_composition_preview(composition: Array, current_planning_phase: String) -> void:
    if current_planning_phase == "SCOUT":
        _render_full_breakdown(composition)   # AC-36
    else:  # INTERMISSION
        _render_tier_bucketed(composition)    # AC-35

func _render_tier_bucketed(composition: Array) -> void:
    var totals: Dictionary[String, int] = {"STANDARD": 0, "ELITE": 0, "BOSS": 0}
    for entry: WaveCompositionEntry in composition:
        var tier: String = GGameDataRegistry.get_monster(entry.monster_id).tier
        totals[tier] += entry.count
    # ... display totals

func _render_full_breakdown(composition: Array) -> void:
    for entry: WaveCompositionEntry in composition:
        var display_name: String = GGameDataRegistry.get_monster(entry.monster_id).display_name
        # ... display display_name + entry.count, no aggregation
```

- The `current_planning_phase` distinguishing SCOUT vs INTERMISSION comes from which mount triggered this specific Planning Cluster instantiation (Story 002) — a constructor param or a setter called immediately after `instantiate()`, never re-derived from the event itself (AC-37).
- Exact typography/layout is a UX Spec concern (`design/ux/mission-hud.md`) — this story implements the resolution/aggregation logic and the phase-branch, not final visual polish.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: `boss_spawn_cell`'s half of the same `wave_preview_available` payload

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-35 vs AC-36**: Phase-branch correctness
  - Given: the same `composition` payload (e.g. 3 STANDARD + 1 ELITE entries)
  - When: received during a SCOUT-mounted Planning Cluster vs. an INTERMISSION-mounted one
  - Then: SCOUT renders 4 distinct per-monster-type lines with `display_name`; INTERMISSION renders exactly 2 aggregate lines ("3 STANDARD, 1 ELITE") — never the same output for both

- **AC-37**: Branch determined by mount, not payload inspection
  - Given: an INTERMISSION-mounted Planning Cluster
  - When: `wave_preview_available` fires with any `composition` content
  - Then: the tier-bucketed path runs regardless of what's inside `composition` — verified by confirming no code path branches on payload shape/size, only on the cached mount-phase value

- **AC-38**: Fresh repopulation, no carryover
  - Given: wave N's composition display already rendered
  - When: the Planning Cluster is torn down (WAVE_ACTIVE) and a fresh one instantiated for wave N+1's INTERMISSION
  - Then: the new instance's composition display starts empty and is populated only from wave N+1's own `wave_preview_available` — no diffing against wave N's data

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `production/qa/evidence/wave-composition-preview-evidence.md` OR an interaction test at `tests/integration/mission-hud/wave-composition-preview_test.gd`

**Status**: [x] `tests/integration/mission-hud/wave-composition-preview_test.gd` — 4 tests, all passing. Also live-MCP-verified end-to-end against the real running `the_gap.tscn` (real WaveManager-driven SCOUT preview + a synthetic mixed-tier INTERMISSION preview), zero errors.

---

## Implementation Deviation Notes

- The story's own Implementation Notes pseudocode referenced `WaveCompositionEntry` (a class) and `GameDataRegistry.get_monster()` — neither exists. The real shipped shape (from `WaveManager._build_composition_preview()`) is `Array[Dictionary]` with `{"monster_id": StringName, "count": int}` keys, and the real registry method is `get_monster_resource(monster_id) -> MonsterResource`. Implemented against the real shapes.
- AC-35's display is one Label line per non-zero tier bucket (matching the story's own QA Test Cases section — "exactly 2 aggregate lines" for a 2-non-zero-tier example), not a single combined summary string as the AC's parenthetical example text suggested.

---

## Dependencies

- Depends on: Story 002 (Phase-Gated Cluster Lifecycle), Story 006 (shares the `wave_preview_available` subscription's outer-root ownership)
- Unlocks: None further within this epic
