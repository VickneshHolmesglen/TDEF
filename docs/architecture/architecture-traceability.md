# Architecture Traceability Index

**Last Updated**: 2026-05-23
**Engine**: Godot 4.6.2 / GDScript
**ADRs Accepted**: 6 (ADR-0001 … ADR-0005, ADR-0008) | ADR-0006, ADR-0007, ADR-0009 Proposed
**TR Registry Version**: 3

## Coverage Summary

| Status | Count | % |
|--------|-------|---|
| ✅ Covered | 32 | 56% |
| ⚠ Partial | 3 | 5% |
| ❌ Gap | 22 | 39% |
| **Total** | **57** | 100% |

*Note: ADR-0006 (Monster movement — Proposed) covers TR-monster-002, 003, 005, 006. Coverage will update to 35/57 (61%) when ADR-0006 Accepted. ADR-0007 covers TR-ds-001/002/003/005, TR-hero-004, TR-tower-003. ADR-0009 covers TR-tower-001, TR-tower-006, TR-wave-002.*

## Roadmap Numbering (post-Grid renumber, 2026-05-16 PM)

| ADR | System | Status |
|-----|--------|--------|
| ADR-0001 | EventBus | Accepted |
| ADR-0002 | Scene/Autoload structure | Accepted |
| ADR-0003 | Save file format | Accepted |
| ADR-0004 | Pathfinding strategy | Accepted |
| ADR-0005 | Grid system data model | Accepted |
| ADR-0006 | Monster movement | **Proposed (2026-05-22)** |
| ADR-0007 | Damage pipeline | **Proposed (2026-05-23)** |
| ADR-0008 | Tower placement gate | **Accepted (2026-05-19)** |
| ADR-0009 | Resource data model | **Proposed (2026-05-23)** |
| ADR-0010 | Hero Tower-Synced Class | Deferred |
| ADR-0011 | UI dual-focus | Deferred |
| ADR-0012 | Wave Manager FSM | Recommended (not yet in roadmap) |

## Full Matrix

| TR-ID | GDD | Requirement | ADR Coverage | Status |
|-------|-----|-------------|--------------|--------|
| TR-eb-001 | event-bus | 70-event typed signal catalogue | ADR-0001 | ✅ |
| TR-eb-002 | event-bus | Cascade depth ≤ 2 levels | ADR-0001 | ✅ |
| TR-eb-003 | event-bus | Deferred dispatch for physics callers | ADR-0001 | ✅ |
| TR-eb-004 | event-bus | Batch threshold 20/frame for monster_died | ADR-0001 | ✅ |
| TR-eb-005 | event-bus | Resource subclass payloads for 5+ field events | ADR-0001 | ✅ |
| TR-eb-006 | event-bus | ≤1.667 ms/frame total EventBus processing | ADR-0001 | ✅ |
| TR-grid-001 | grid-system | 16×12 default grid; 5 cell types | ADR-0005 | ✅ |
| TR-grid-002 | grid-system | Direct read API (Autoload); write restricted to Tower | ADR-0005 | ✅ |
| TR-grid-003 | grid-system | `world_to_cell` uses `floor()` | ADR-0005 | ✅ |
| TR-grid-004 | grid-system | Returns copies, not references | ADR-0005 | ✅ |
| TR-save-001 | save-persistence | 3 save slots; atomic write (.tmp → .dat) | ADR-0003 | ✅ |
| TR-save-002 | save-persistence | FileAccess `bool` return check (4.4+) | ADR-0003 | ✅ |
| TR-save-003 | save-persistence | Restore order 10–33; deferred 1 frame | ADR-0003 | ✅ |
| TR-save-004 | save-persistence | Format version + migration registry | ADR-0003 | ✅ |
| TR-save-005 | save-persistence | Save format decision | ADR-0003 | ✅ |
| TR-save-006 | save-persistence | 4 auto-save triggers via EventBus | ADR-0003 | ✅ |
| TR-hero-001 | hero | CharacterBody2D scene root | ADR-0002 | ✅ |
| TR-hero-002 | hero | 12 stats; Tower-Synced Class (Chebyshev 3-cell) | — (ADR-0010 deferred) | ❌ |
| TR-hero-003 | hero | Tower Affinity sqrt scaling | — (ADR-0010 deferred) | ❌ |
| TR-hero-004 | hero | Event-driven targeting (no direct Monster refs) | ADR-0007 (Proposed) | ⚠ Partial (full coverage on Accept) |
| TR-hero-005 | hero | 4 active skills + Ultimate | — (ADR-0010 deferred) | ❌ |
| TR-hero-006 | hero | 6 stat formulas (crit, lifesteal, affinity, etc.) | — (ADR-0010 deferred) | ❌ |
| TR-tower-001 | tower | 4 component slots; 4 archetypes; 4 tiers | ADR-0009 (Proposed) | ⚠ Partial (full coverage on Accept) |
| TR-tower-002 | tower | Placement blocked during WAVE_ACTIVE | ADR-0008 | ✅ |
| TR-tower-003 | tower | Monster cache via EventBus; no direct refs | ADR-0007 (Proposed) | ⚠ Partial (full coverage on Accept) |
| TR-tower-004 | tower | `would_block_all_paths()` gate before placement | ADR-0008 | ✅ |
| TR-tower-005 | tower | Pre-placement perk (Scout phase only) | ADR-0008 | ✅ |
| TR-tower-006 | tower | Support archetype aura pulse model | ADR-0009 (Proposed) | ⚠ Partial (full coverage on Accept) |
| TR-monster-001 | monster | Area2D scene root (not CharacterBody2D) | ADR-0002 | ✅ |
| TR-monster-002 | monster | MonsterResource data-driven stats; 3 tiers | ADR-0006 (Proposed) | ⚠ Partial (full coverage on Accept) |
| TR-monster-003 | monster | `_pending_damage` buffer flushed in `_physics_process` | ADR-0006 (Proposed) | ⚠ Partial (full coverage on Accept) |
| TR-monster-004 | monster | Position-based movement (not physics-driven) | ADR-0002, ADR-0004 | ✅ |
| TR-monster-005 | monster | Dual-layer AnimatedSprite2D | ADR-0006 (Proposed) | ⚠ Partial (full coverage on Accept) |
| TR-monster-006 | monster | Boss scan throttle + prepare-frames telegraph | ADR-0006 (Proposed) | ⚠ Partial (full coverage on Accept) |
| TR-ds-001 | damage-status | Two pipelines: direct hit + DoT | ADR-0007 (Proposed) | ⚠ Partial (full coverage on Accept) |
| TR-ds-002 | damage-status | `await` + `is_instance_valid` guard pattern | ADR-0007 (Proposed) | ⚠ Partial (full coverage on Accept) |
| TR-ds-003 | damage-status | `_lifesteal_pending` Dictionary[int, float] | ADR-0007 (Proposed) | ⚠ Partial (full coverage on Accept) |
| TR-ds-004 | damage-status | 5 status effect types + stack/duration rules | — (separate ADR required post-MVP) | ❌ |
| TR-ds-005 | damage-status | No direct call API — EventBus only | ADR-0007 (Proposed) | ⚠ Partial (full coverage on Accept) |
| TR-path-001 | pathfinding | AStar2D Autoload (not NavigationServer) | ADR-0004 | ✅ |
| TR-path-002 | pathfinding | Route templates with `cell_index_map` | ADR-0004 | ✅ |
| TR-path-003 | pathfinding | Super-goal node for multi-goal convergence | ADR-0004 | ✅ |
| TR-path-004 | pathfinding | `templates_ready` event gates all spawning | ADR-0004 | ✅ |
| TR-path-005 | pathfinding | `would_block_all_paths()` speculative check | ADR-0004 | ✅ |
| TR-path-006 | pathfinding | Deferred dirty rebuild on tower changes | ADR-0004 | ✅ |
| TR-path-007 | pathfinding | 100+ simultaneous agents at 60 FPS | ADR-0004 | ⚠ Partial (perf-budgeted but unverified) |
| TR-wave-001 | wave-manager | 7-state phase lifecycle FSM | — (ADR-0012 recommended) | ❌ |
| TR-wave-002 | wave-manager | WaveConfig/WaveScript/WaveSpawnEntry Resources | ADR-0009 (Proposed) | ⚠ Partial (full coverage on Accept) |
| TR-wave-003 | wave-manager | BOSS breach = wave-clear | — (ADR-0012 recommended) | ❌ |
| TR-wave-004 | wave-manager | `templates_ready` gate before first spawn | ADR-0004 | ✅ |
| TR-wave-005 | wave-manager | Wave-stuck watchdog (30 s stalled / 60 s force-clear) | — (ADR-0012 recommended) | ❌ |
| TR-wave-006 | wave-manager | `wave_reward_scalar` semantic contract | — (ADR-0012 recommended) | ❌ |
| TR-wave-007 | wave-manager | Penultimate-wave rule (sub-boss at wave N-1) | — (ADR-0012 recommended) | ❌ |
| TR-gc-001 | game-concept | All 9 systems communicate via EventBus only | ADR-0001 | ✅ |
| TR-gc-002 | game-concept | Autoload boot order: EB → Save → Grid → Path | ADR-0002 | ✅ |
| TR-gc-003 | game-concept | Mission states: SCOUT/WAVE_ACTIVE/INTERMISSION/etc. | ADR-0002 | ⚠ Partial (outer FSM only; Wave Manager FSM scoped out) |
| TR-gc-004 | game-concept | 15–25 min default mission (session length formula) | — (design tuning, not architecture) | N/A |

## Known Gaps

### Foundation Layer
- ✅ All Foundation TRs covered (EventBus, Save, Grid, Pathfinding).

### Core Layer
- Monster: TR-monster-002, 003, 005, 006 addressed by ADR-0006 (Proposed — ⚠ pending Accept)
- Damage & Status: TR-ds-001/002/003/005, TR-hero-004, TR-tower-003 addressed by ADR-0007 (Proposed — ⚠ pending Accept); TR-ds-004 (status effects) deferred to post-MVP ADR
- Tower: TR-tower-002, 004, 005 ✅ (ADR-0008 Accepted); TR-tower-001, 006 addressed by ADR-0009 (Proposed — ⚠ pending Accept)
- Wave Manager: TR-wave-002 addressed by ADR-0009 (Proposed — ⚠ pending Accept)

### Feature Layer (Wave Manager FSM — new ADR-0012 recommended)
- Wave Manager (ADR-0012 new): TR-wave-001, 003, 005, 006, 007

### Presentation Layer (ADR-0011 deferred)
- UI dual-focus handling — write when first Presentation GDD lands

### Hero subsystem (ADR-0010 deferred)
- TR-hero-002, 003, 005, 006 — pure logic, no novel APIs

## Superseded Requirements

None — TR registry is at v3 with all 57 entries `active`.
