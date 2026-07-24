# Epic 09: Mission HUD

> **Layer**: Presentation
> **GDD**: design/gdd/mission-hud.md
> **Architecture Module**: Mission HUD (real-time display widgets, read-only EventBus subscriber)
> **Status**: Complete — all 12 stories implemented and verified
> **Stories**: 12 total — 12 `Complete`, fully verified

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | HUD Scaffold & Local State Model | Integration | Complete | ADR-0031 |
| 002 | Phase-Gated Cluster Lifecycle | Integration | Complete | ADR-0031 |
| 003 | Route-Preview Overlay (PC-1) | Integration | Complete | ADR-0031 |
| 004 | Blocked-Cell Highlight (PC-2) | Integration | Complete | ADR-0031 |
| 005 | Deferred Routing Notification Banner (PC-3) | UI | Complete | ADR-0031 |
| 006 | Boss-Lane Telegraph (PC-5, boss half) | Integration | Complete | ADR-0031 |
| 007 | Wave Composition Preview Display (PC-5, composition half) | UI | Complete | ADR-0031 |
| 008 | Ready Button (+ InputModeTracker wiring) | UI | Complete | ADR-0031, ADR-0011 |
| 009 | Ultimate Button | UI | Complete | ADR-0031, ADR-0011 |
| 010 | Sell Button | UI | Complete | ADR-0031, ADR-0011 |
| 011 | Combat Cluster Live Data Widgets | Integration | Complete | ADR-0031 |
| 012 | DEFEAT Retry Button | Integration | Complete | ADR-0031, ADR-0028, ADR-0011 |

**History note on Stories 009/010**: initially implemented with verification explicitly skipped per user instruction (mid-session) to move quickly to Stories 011/012. Both stories' own test files (`ultimate-button_test.gd`, `sell-button_test.gd`) were subsequently run and confirmed passing as part of Story 011's and Story 012's own full mission-hud suite runs (98/98, then 104/104) — now genuinely `Complete`, not just implementation-complete.

**Known real gaps carried forward past epic completion** (all explicitly flagged in their owning story files, not silently glossed over):
- **AC-62 (Story 011) — floating damage numbers render at a fixed feed position, not the real monster world position.** `MonsterManager` is not an Autoload and isn't one of ADR-0031's classified direct-call dependencies; granting Mission HUD a live position lookup needs its own ADR.
- **AC-68 (Story 012) — the Retry button is housed inside Mission HUD's own CanvasLayer as a pragmatic placeholder**, since the GDD's own DEFEAT row describes a separate Outcome/Defeat screen that doesn't exist anywhere in this codebase yet. Replace once that screen is built.
- **TR registry coverage for `mission-hud.md` remains stale** (only TR-hud-001/002/003 registered against the GDD's ~27 Core Rules) — a `/architecture-review` TR-ID sync pass is still recommended.

## Batch Code Review — 2026-07-20 — APPROVED (after fixes)

Deferred batch `/code-review` across all 12 stories run 2026-07-20 (3 parallel specialist passes: godot-gdscript-specialist code quality, godot-specialist architecture/ADR compliance, qa-tester testability), matching the Equipment Forge (Epic 08) precedent.

**Real bug found and fixed**: `_on_hero_health_changed()`, `_on_boss_hp_changed()`, `_on_materials_earned()`, `_on_resources_changed()` (all Story 011) were missing the `_terminal` guard every other Rule-4 mutation handler in this file has — Hero HP, the boss bar, the materials tally, and the gold label all kept updating after DEFEAT/MISSION_COMPLETE. Fixed (all 4 now guard on `_terminal`), with a regression test (`test_terminal_latch_suppresses_hero_boss_materials_gold_handlers`, `combat-cluster-live-data_test.gd`).

**Real DRY violation found and fixed**: the ~15-line `StyleBoxFlat`-based focus-ring construction was duplicated byte-for-byte 4 times across `mission_hud.gd` and `planning_cluster.gd` (Ready/Sell/Ultimate/Retry). Extracted to `src/ui/focus_ring_factory.gd` (`FocusRingFactory.build(owner: Control) -> Panel`), a static shared helper reused by all 4 call sites — cut ~60 duplicated lines and centralizes `FOCUS_RING_COLOR` in one place instead of two independently-drifting copies.

**Real complexity issue found and fixed**: `_on_mission_phase_changed()` was at the coding-standards.md complexity ceiling (~9-10 branches). Split into 4 per-phase helpers (`_enter_scout()`, `_enter_terminal()`, `_enter_pre_wave()`, `_enter_intermission()`) dispatched via `match`, mirroring the file's own existing `_spawn_planning_cluster()`/`_teardown_planning_cluster()` helper convention.

**Real documentation gap found and fixed**: ADR-0031's own direct-Autoload-call table only listed 3 calls; `GameDataRegistry.get_monster_resource()` (used by Stories 006/007/011) was missing a table row, even though it's already classified project-wide as Criterion A by ADR-0020. Added the missing row to the ADR rather than treating it as a code violation (it wasn't one).

**Testability gaps found and closed**: 3 new tests added — `test_wave_countdown_warning_updates_timer_label`, `test_item_removed_shows_a_toast` (both previously-shipped-but-untested code paths), and `test_focusing_ready_does_not_show_sibling_buttons_rings` (cross-button focus-ring isolation across all 4 InputModeTracker-connected buttons, using real `grab_focus()` — the first test in this project to drive Godot's actual focus system rather than manually emitting `focus_entered`).

**Suggestions logged, not blocking**: `_ready()`/`_exit_tree()` disconnect-guard asymmetry between `mission_hud.gd` (unconditional disconnects) and `planning_cluster.gd` (`is_connected()`-guarded) — not a live bug since `_ready()` always completes all its connects before any `_exit_tree()` can run, but worth standardizing one way in a future pass. `BOSS_TIER`/`TIER_NAMES` duplicate the same tier-int vocabulary across 2 files — a shared constant on `MonsterResource` itself would remove the drift risk if a 4th tier is ever added.

Re-verified after all fixes: full mission-hud suite 108/108, full project regression 1474/1474 (0 errors, 1 pre-existing unrelated `TD-menag-006` failure).

**The deferred batch `/code-review` across all of Mission HUD is now complete** — this epic is closed out, not just feature-complete.

## Overview

Mission HUD is the player's primary heads-up display during a mission (SCOUT through
DEFEAT/MISSION_COMPLETE) — route-preview overlays, blocked-placement indicators, phase
announcements, wave progress, hero stats, boss telegraph, wave-composition preview, and
3 outbound player-action signals (Ready, Ultimate, Sell), plus a DEFEAT-only Retry button.
It is a leaf consumer: it reads from 10 upstream systems via EventBus and owns zero
persisted gameplay state (no `SaveRestorer`). Per ADR-0031, it is a static `CanvasLayer`
child of `MissionScene.tscn` (not an Autoload) composed of a persistent Combat Cluster
and a re-instantiated-per-wave-cycle Planning Cluster (own `PackedScene`). Sanctuary-context
display is explicitly out of scope — that belongs to the separate, not-yet-started
"Sanctuary UI" system.

This is the single biggest unblocker remaining in the project: Epic 06's Story 013
(Tower Mastery's HUD corner callout for `skill_unlocked`) is `Partial`, blocked specifically
because no Mission HUD code has existed until now. (Correction during story decomposition:
Epic 07's Tarot Story 006 AC-37/38 was initially assumed to be a second beneficiary of this
epic — verified against the story file directly and found to be unrelated. That story is
blocked on Wave Manager/Monster System's own `tarot_speed_scalar` aggregation and
`WaveConfig`-override consumption logic never subscribing to `mission_modifier_applied`
anywhere in the codebase — a completely different gap this epic does not touch.)

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0031: Mission HUD Architecture | `MissionHud` (`CanvasLayer`, static Mission-scene child) → persistent `CombatCluster` + re-instantiated `PlanningCluster` (`PackedScene`, correct `remove_child()`-then-`queue_free()` teardown); 5 typed Rule-4 state fields on the outer root; 3 direct-Autoload calls classified under ADR-0020 (2× Criterion A read, 1× Criterion B action); reuses ADR-0011's `InputModeTracker` verbatim; no `SaveRestorer` | MEDIUM |
| ADR-0002: Scene/Autoload Structure (Accepted) | Places `MissionHud` in the Mission Scene Hierarchy as a static `CanvasLayer` child, scene-instanced (not an Autoload) | LOW |
| ADR-0011: UI Dual-Focus Handling (Accepted) | `InputModeTracker` pattern — Godot 4.6's mouse/keyboard-gamepad focus split | HIGH (post-cutoff engine behavior, already mitigated) |
| ADR-0020: Direct-Autoload-call exception pattern (Accepted) | Classifies this epic's 3 non-EventBus calls (Pathfinding/Grid reads, MissionSelect action) | LOW |
| ADR-0028: Mission Select Runtime State (Accepted) | Confirms `MissionSelect` as Autoload #12, the Criterion B callee for `retry_current_mission()` | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|---------------|
| TR-hud-001 | On `path_invalidated`, call `get_path()` to re-derive route — never render `affected_cells` directly as a route line | ADR-0031 ✅ |
| TR-hud-002 | On `tower_placement_blocked`, distinguish `primary_blocking_cell` sentinel (-1,-1) uniform-highlight case from single-cell case | ADR-0031 ✅ |
| TR-hud-003 | On `tower_destroyed` during WAVE_ACTIVE, display path-update-queued-for-next-intermission messaging | ADR-0031 ✅ |

**Untraced requirements — real, flagged not hidden**: the GDD has grown substantially since the TR registry's last update (2026-07-13, `/architecture-review` Pass 4) — it now specifies 27 Core Rules across 10 Groups (PC-4/PC-5 wave-progress + boss-telegraph + wave-composition-preview, the Ready/Ultimate/Sell button contracts, the DEFEAT-only Retry button, all 10 upstream-system Interactions rows), none of which have their own TR-ID yet. ADR-0031 covers the *architecture* (scene structure, state ownership, direct-call classification) for all of it, but a full `tr-registry.yaml` sync (registering TR-IDs for Groups 3b/3c/6-10) was not run as part of this epic's creation — stories below are scoped directly from the GDD's own Core Rules/States-Transitions/Interactions tables instead, matching this project's established precedent for shipping against a GDD whose TR-ID coverage lags its own content (e.g. Epic 07/08). Recommend a `/architecture-review` TR-ID sync pass for `mission-hud.md` at a future checkpoint.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/mission-hud.md` are verified (Test Evidence per story type)
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- Live-MCP verification of the Planning Cluster's per-cycle `_ready()`-refire and the PC-5 grid-cell-to-screen-space conversion (ADR-0031's own Validation Criteria)

## Next Step

Run `/create-stories epic-09-mission-hud` to break this epic into implementable stories.
