# Story 006: Boss-Lane Telegraph (PC-5, boss half)

> **Epic**: Epic 09 — Mission HUD
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/mission-hud.md`
**Requirement**: `TR-hud-000` *(untraced — scoped from Core Rules Group 3b, Rules 11a-11e; closes `tower.md`'s OQ-11 and unblocks Epic 06's Story 013, currently Partial pending exactly this)*

**ADR Governing Implementation**: ADR-0031 (Mission HUD Architecture)
**ADR Decision Summary**: `wave_preview_available` is subscribed on the outer HUD root (not the Planning Cluster) — it fires synchronously in the same call stack as the phase transition that re-instantiates the Planning Cluster, so a Planning-Cluster-owned subscription could not be guaranteed live before that emission on every cycle. `Grid.cell_to_world()` is classified ADR-0020 Criterion A (read-only). Cell-to-screen conversion uses `get_viewport().get_canvas_transform() * world_pos`.

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM
**Engine Notes**: The `CanvasLayer`'s identity transform and the mission's fixed (set-once) `Camera2D` position/zoom are already live-MCP-verified (GDD Rule 6 note, 2026-07-15) — this story's own Validation Criteria (see ADR-0031) still requires a pixel-level live-MCP verification once this rendering code exists, since only the preconditions, not the actual marker render, have been confirmed so far.

**Control Manifest Rules (this layer)**:
- Required: N/A.
- Forbidden: `_boss_telegraph_cell` must never be reset on `mission_phase_changed → WAVE_ACTIVE` — this was a real, previously-shipped-then-caught bug in the GDD's own drafting history (Rule 11e's correction) that made the confirmation pulse structurally impossible to fire. Reset only on `wave_completed` and on HUD mount (Story 001).
- Guardrail: If `_boss_telegraph_cell` is already sentinel when a BOSS unexpectedly spawns during WAVE_ACTIVE, no pulse fires — defensive, not an expected path.

---

## Acceptance Criteria

*From GDD Core Rules Group 3b (Rules 11a-11e) + Confirmed Signal Contract PC-5 (boss half):*

- [x] AC-28 — the outer `MissionHud` root subscribes to `wave_preview_available` in its own `_ready()`; on receipt, caches `boss_spawn_cell` into `_boss_telegraph_cell`
- [x] AC-29 — if `boss_spawn_cell == Vector2i(-1,-1)` (non-boss wave): `_boss_telegraph_cell` set to the same sentinel, no marker rendered or requested
- [x] AC-30 — otherwise: the cached cell is handed to whichever Planning Cluster instance is currently live; the marker's screen position resolves via `Grid.cell_to_world(_boss_telegraph_cell)` composed with `get_viewport().get_canvas_transform()`; marker is Planning-Cluster-owned (destroyed along with the rest of the cluster at WAVE_ACTIVE teardown, Story 002)
- [x] AC-31 — when `_boss_telegraph_cell` is non-sentinel and `monster_spawned(tier="BOSS")` fires during WAVE_ACTIVE: fire a single brief confirming pulse VFX at that resolved screen position (owned by the outer root, since the Planning Cluster no longer exists at this point), then clear `_boss_telegraph_cell` to sentinel
- [x] AC-32 — `_boss_telegraph_cell` is unconditionally reset to sentinel on `wave_completed`, regardless of whether the AC-31 pulse fired (belt-and-suspenders) — **never** on `mission_phase_changed → WAVE_ACTIVE`
- [x] AC-33 (regression) — across a full wave cycle where Wave Manager's own content guarantees the BOSS entry is last in its wave (arriving strictly after `mission_phase_changed → WAVE_ACTIVE`), the pulse (AC-31) genuinely fires — this is the specific regression the GDD's own Rule 11e correction exists to prove
- [x] AC-34 — if `wave_preview_available` fires twice for the same upcoming wave: the second event's `boss_spawn_cell` fully overwrites `_boss_telegraph_cell`, no stacking of two markers

---

## Implementation Notes

*Derived from ADR-0031/GDD Implementation Guidelines:*

```gdscript
# On MissionHud (outer root)
func _on_wave_preview_available(next_wave_number: int, composition: Array, boss_spawn_cell: Vector2i) -> void:
    _boss_telegraph_cell = boss_spawn_cell
    if _planning_cluster != null:
        _planning_cluster.set_boss_telegraph_cell(_boss_telegraph_cell)

func _resolve_boss_telegraph_screen_pos() -> Vector2:
    var world_pos: Vector2 = GGrid.cell_to_world(_boss_telegraph_cell)
    return get_viewport().get_canvas_transform() * world_pos

func _on_monster_spawned(entity_id: int, tier: String, ...) -> void:
    if tier == "BOSS" and _boss_telegraph_cell != Vector2i(-1, -1) and _phase == "WAVE_ACTIVE":
        _fire_boss_confirmation_pulse(_resolve_boss_telegraph_screen_pos())
        _boss_telegraph_cell = Vector2i(-1, -1)

func _on_wave_completed(...) -> void:
    _boss_telegraph_cell = Vector2i(-1, -1)  # unconditional reset — AC-32
```

- This is the ONE deliberate, narrow exception to the Player Fantasy's "recede" guardrail (GDD Rule 11d's own text) — the confirmation pulse is a single brief VFX, not a persistent marker, justified because it delivers Tower GDD OQ-11's specific in-combat validation moment.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: `composition`'s wave-composition-preview half of the same `wave_preview_available` payload

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-32/AC-33**: The Rule 11e regression, exact ordering
  - Given: a wave with a BOSS entry (guaranteed last, per Wave Manager Rule 6) and `_boss_telegraph_cell` non-sentinel from the prior `wave_preview_available`
  - When: `mission_phase_changed → WAVE_ACTIVE` fires, followed later (same wave, after at least one other spawn) by `monster_spawned(tier="BOSS")`, followed by `wave_completed`
  - Then: the WAVE_ACTIVE transition does NOT clear `_boss_telegraph_cell`; the BOSS spawn DOES fire the pulse and clears it; `wave_completed`'s own reset is a no-op on an already-sentinel value (idempotent)

- **AC-29**: Non-boss wave sentinel
  - Given: `wave_preview_available(boss_spawn_cell=Vector2i(-1,-1))`
  - When: received
  - Then: no marker requested, `_boss_telegraph_cell` remains sentinel

- **AC-34**: Double-fire overwrite
  - Given: `_boss_telegraph_cell` already set to cell A from a prior `wave_preview_available`
  - When: a second `wave_preview_available` fires for the same wave with `boss_spawn_cell=B`
  - Then: `_boss_telegraph_cell == B`, no two markers ever coexist

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/mission-hud/boss-lane-telegraph_test.gd` — must exist and pass

**Status**: [x] Created — `tests/integration/mission-hud/boss-lane-telegraph_test.gd` (9 tests, passing)

---

## Dependencies

- Depends on: Story 001 (HUD Scaffold & Local State Model), Story 002 (Phase-Gated Cluster Lifecycle)
- Unlocks: Epic 06 Story 013 (currently Partial, blocked on exactly this)

---

## Completion Notes
**Completed**: 2026-07-20
**Criteria**: 7/7 passing (9 integration tests, all passing; live-MCP-verified end-to-end against the real running `the_gap.tscn` — telegraph cached+rendered, survived WAVE_ACTIVE entry unchanged, confirmation pulse fired and cleared the cell on a real BOSS-tier `monster_spawned`, zero errors).
**Deviations**:
- **Real, confirmed blocking gap found before implementation, surfaced to the user rather than worked around silently**: `wave_preview_available`'s actual shipped signature was `(next_wave_number, composition)` — no `boss_spawn_cell` field existed anywhere in `WaveManager`/`EventBus`, despite the GDD describing this as an already-closed cross-system contract ("closes tower.md's OQ-11"). Confirmed via direct grep, not assumed. User chose (Recommended option) to extend the signal rather than leave the story Blocked.
- **`EventBus.wave_preview_available` signal extended**: added `boss_spawn_cell: Vector2i` as a 3rd parameter. `WaveManager` gained a new `_preview_boss_spawn_cell(wave_number)` — deliberately does NOT call the real `_resolve_spawn_cell()`/mutate `_round_robin_counter` (that field is live spawn-time state; calling it at preview time would desync the real spawn resolution from what was previewed) — instead simulates round-robin locally with its own throwaway counter, mirroring `_resolve_spawn_cell()`'s exact rules. New tests added directly to `wave_manager_config_loading_test.gd` covering both the correct cell computation and the no-mutation guarantee.
- **Real regression caught and fixed via full-suite discipline (recurring class, now permanently mitigated)**: extending `MissionHud` with new `@onready`-resolved nodes (`Banner`, `wave_preview_available`/`wave_completed` subscriptions) broke every earlier Mission HUD story's own test fixture the same way Story 002 broke Story 001's — because each story's test file had hand-rolled its own minimal node scaffold, predating later stories' additions. Fixed properly this time (not just patched) by extracting a shared `tests/helpers/mission_hud_test_helper.gd` (`MissionHudTestHelper.build_hud()`) that all 6 Mission HUD test files now use — a future story's new `@onready` dependency only needs to be added in this one place, not hunted down across every earlier test file again.
- **2 pre-existing WaveManager test files' order-tracking lambdas were stale** (`func(_a: int, _b: Array) -> void`) — connecting a 2-parameter callable to a signal that now emits 3 arguments silently failed to fire at all in this engine version (not a graceful arg-drop, as might be assumed) — fixed both to accept the 3rd `Vector2i` parameter.
**Test Evidence**: Integration — `tests/integration/mission-hud/boss-lane-telegraph_test.gd`, plus 2 new tests in `tests/integration/wave_manager/wave_manager_config_loading_test.gd`.
**Code Review**: Pending — deferred to a batch pass at a later Mission HUD checkpoint.
