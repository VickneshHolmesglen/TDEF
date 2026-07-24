# Epic: Wave Manager

> **Layer**: Feature
> **GDD**: design/gdd/wave-manager.md
> **Architecture Module**: WaveManager (Autoload #7)
> **Status**: Complete — all 8 stories implemented, reviewed, and closed (2026-07-05/07-06)
> **Stories**: See table below

## Overview

The Wave Manager is the mission director: it owns the full phase lifecycle of a mission (SCOUT → PRE_WAVE → WAVE_ACTIVE → INTERMISSION → MISSION_COMPLETE / DEFEAT), sequences monster spawns within each wave via a data-driven `WaveConfig` Resource, tracks wave-clear conditions (including the BOSS breach and BOSS-killed fast-paths), and drives all phase transitions. It is the sole authority on mission phase — no other system may trigger a phase change. Without it, no monsters spawn, no phases advance, and the mission has no rhythm.

A Sprint 3 Phase 1 implementation already exists (`src/gameplay/wave_manager.gd`) covering the 7-state enum, the single entry-point transition method, the 5 Timer nodes, the wave-stuck watchdog, and a single-lane spawn coroutine gated on the wave-1 `templates_ready` event. It explicitly deferred several rules to "Sprint 4" (now) per its own header comment: the DEFEAT/MISSION_COMPLETE win-loss transitions, BOSS breach handling, the penultimate-wave flag, the `wave_reward_scalar` formula, the waves-2+ pathfinding rebuild gate, and the full `WaveConfig`/`WaveScript`/`WaveSpawnEntry` Resource-driven spawn model. This epic's stories close those gaps and culminate in assembling a bootable "The Gap" mission scene that exercises the complete loop.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0012: Wave Manager FSM Architecture | `enum Phase` + `match` + scene-tree Timer nodes + a single `_transition_to()` entry point; spawn coroutine with a three-guard pattern (`is_instance_valid`, `_spawn_active`, phase check) at every await boundary; `_phase_locked` latch gives DEFEAT priority over same-frame wave-clear | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage | Code Status (verified 2026-07-04) |
|-------|-------------|--------------|-------------------------------------|
| TR-wave-001 | 7-state phase lifecycle FSM | ADR-0012 ✅ | ✅ Complete (Story 001) |
| TR-wave-002 | WaveConfig/WaveScript/WaveSpawnEntry Resources | ADR-0012 ✅ | ✅ Complete (Story 006) |
| TR-wave-003 | BOSS breach = wave-clear | ADR-0012 ✅ | ✅ Complete (Story 003) |
| TR-wave-004 | templates_ready gate before first spawn (wave-1 only) | ADR-0012 ✅ | ✅ Complete (Story 001/006) |
| TR-wave-005 | Wave-stuck watchdog (30s stalled / 60s force-clear) | ADR-0012 ✅ | ✅ Complete (pre-existing) |
| TR-wave-006 | wave_reward_scalar semantic contract | ADR-0012 ✅ | ✅ Complete (Story 004) |
| TR-wave-007 | Penultimate-wave rule (sub-boss at wave N-1) | ADR-0012 ✅ | ✅ Complete (Story 004) |
| TR-wave-008 | Waves 2+ rebuild-pending gate (`is_rebuild_pending()` check at INTERMISSION→PRE_WAVE) | ADR-0004, ADR-0012 ✅ | ✅ Complete (Story 005; TR-ID retroactively registered 2026-07-07) |

**Coverage summary**: 8/8 TRs have a governing ADR (ADR-0012, Accepted; ADR-0004 co-governs TR-wave-008) and 8/8 are now genuinely implemented in code (corrected 2026-07-06 for TR-001–007 — this table previously showed most TRs as unimplemented, which was accurate as of 2026-07-04 but is now stale; TR-wave-008 added 2026-07-07).

**Registry gap RESOLVED (2026-07-07)**: `TR-wave-004`'s registry text ("templates_ready gate before first spawn") only ever described the wave-1 gate. Story 005's waves-2+ `_rebuild_pending_gate` never had its own TR-ID — this table above previously conflated the two under `TR-wave-004`. Added `TR-wave-008` to `docs/architecture/tr-registry.yaml` to register Story 005's requirement on its own terms; `TR-wave-004`'s text now correctly reads as wave-1-only in the row above.

## Definition of Done

This epic is complete — all criteria below are satisfied:
- ✅ All 8 stories implemented, reviewed, and closed via `/story-done` (2026-07-05/07-06)
- ✅ All 7 TR-wave requirements genuinely implemented in code
- ✅ WaveManager tests cover DEFEAT, MISSION_COMPLETE, BOSS breach (both fast-paths), the waves-2+ rebuild gate, the `wave_reward_scalar` formula, and the penultimate-wave flag
- ✅ A bootable "The Gap" mission scene demonstrates the complete SCOUT → PRE_WAVE → WAVE_ACTIVE → INTERMISSION → MISSION_COMPLETE/DEFEAT loop end to end (Story 008)
- ⏳ Sprint 4's Vertical Slice critical path can now proceed to playtesting — performance measurement (FPS/draw-calls/memory) remains unverified, accepted as tracked debt (`docs/tech-debt-register.md` TD-perf-001), recommended before a full playtest round

**Real findings from this epic's implementation** (not evident from the plan): Story 008's own integration verification — the first time the real end-to-end signal chain was ever exercised, since every prior unit/integration test injected data directly — found and fixed 4 previously-invisible production bugs that had silently broken the entire game's core loop: (1) `_wave_spawn_entries` was never populated from a real loaded `WaveConfig`, meaning every real mission spawned exactly 0 monsters, ever; (2) `_on_templates_ready()`'s guard discarded the real, synchronously-nested `templates_ready` signal, permanently stalling wave 1; (3) `WaveSpawnEntry`'s plain-`var` fields didn't survive `.tres` serialization; (4) a missing `DamageStatus` node meant real Hero attacks dealt zero damage. See `docs/tech-debt-register.md` (TD-wave-002, TD-wave-003, TD-damage-001) and Story 008's own Completion Notes for full detail.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [DEFEAT & MISSION_COMPLETE Win/Loss Conditions](story-001-defeat-mission-complete.md) | Integration | Complete | ADR-0012 |
| 002 | [Wave Lifecycle Events (wave_started/wave_completed/wave_preview_available)](story-002-wave-lifecycle-events.md) | Integration | Complete | ADR-0012 |
| 003 | [BOSS Death, BOSS Breach & Wave-Clear Robustness](story-003-boss-fastpaths-wave-clear-robustness.md) | Logic | Complete | ADR-0012 |
| 004 | [Wave Reward Scalar Formula & Penultimate-Wave Flag](story-004-reward-scalar-penultimate-flag.md) | Logic | Complete | ADR-0012 |
| 005 | [Waves 2+ Pathfinding Rebuild Gate](story-005-rebuild-gate-waves-2plus.md) | Integration | Complete | ADR-0012 + ADR-0004 |
| 006 | [WaveConfig Resource Loading & Mission Launch Wiring](story-006-waveconfig-resource-loading.md) | Integration | Complete | ADR-0012 + ADR-0009 |
| 007 | [Round-Robin Spawn Cell Assignment + Modulo Wrap](story-007-round-robin-spawn-cells.md) | Logic | Complete | ADR-0012 |
| 008 | [Assemble "The Gap" Mission Scene](story-008-assemble-the-gap-mission-scene.md) | Integration | Complete | ADR-0012 + ADR-0002 |

**Story dependency order**: {001, 002, 004, 005, 006} → 003 (needs 001, 002) → 007 (needs 006, 004) → 008 (needs all of 001-007) — all resolved in this order.

**`difficulty_tier` sourcing — resolved**: `difficulty_tier: int` was added as a 3rd parameter to the real `mission_launched` EventBus signal during Story 006's implementation. The one other subscriber (`SavePersistence`) was updated in lockstep to avoid an arity mismatch.

## Next Step

This epic is closed. See `production/epics/epic-04-wave-manager/story-008-assemble-the-gap-mission-scene.md`'s Completion Notes for the full final report, and `docs/tech-debt-register.md` for tracked follow-up items (TD-wave-002/003, TD-damage-001, plus the unresolved `TR-wave-004` registry gap noted above — **all now CLOSED as of 2026-07-07**, see below). Recommended next steps: a manual/windowed playtest session to capture the deferred performance measurement, then Sprint 4's downstream stories (S4-10 pathfinding stress test, S4-11 playtest round).

**Status update (2026-07-07)**: `TD-data-001` closed via `S5-01` (MonsterManager/TowerSystem now self-populate from `GameDataRegistry` — no more scene-local wiring workaround). `TD-perf-001` closed via a live-engine Godot MCP measurement — that measurement found a new issue (**387 draw calls at baseline, ~1.9× over the 200 budget**), tracked and **also fixed same-session** as `TD-render-001` (root cause: `grid_visual.gd`'s per-cell `_draw()` loop; fix: pre-rendered texture; result: 387 → 4 draw calls). The `TR-wave-004` registry gap is resolved (see `TR-wave-008` in `docs/architecture/tr-registry.yaml`).
