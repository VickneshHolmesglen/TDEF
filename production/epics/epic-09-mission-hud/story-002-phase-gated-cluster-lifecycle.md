# Story 002: Phase-Gated Cluster Lifecycle

> **Epic**: Epic 09 — Mission HUD
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/mission-hud.md`
**Requirement**: `TR-hud-000` *(untraced — scoped from Core Rules Group 2, Rules 5-8)*

**ADR Governing Implementation**: ADR-0031 (Mission HUD Architecture)
**ADR Decision Summary**: `PlanningCluster.tscn` is a separate `PackedScene`, re-instantiated fresh into a `PlanningClusterHost` container on every SCOUT/INTERMISSION entry, torn down on every WAVE_ACTIVE entry. Teardown is **synchronous `remove_child()` first** (forces immediate `_exit_tree()`, disconnecting subscriptions right away), **then `queue_free()`** to actually free memory — `queue_free()` alone is insufficient and creates a double-connected-handler window (engine-specialist-caught bug in this ADR's own first draft). `CombatCluster` (`Control`) is a persistent child of `MissionHud`, never destroyed/recreated mid-mission.

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM
**Engine Notes**: `queue_free()` schedules deletion for end-of-idle-frame, not immediately — a bare `queue_free()`-then-`instantiate()`-then-`add_child()` sequence leaves the outgoing instance's EventBus subscriptions live simultaneously with the fresh instance's newly-connected ones until idle time. Live-MCP-verified (GDD Rule 6, 2026-07-14): a node re-added via `remove_child()`/`add_child()` does NOT re-fire `_ready()` in this engine version — re-instantiation from the `PackedScene` is the only path that reliably reconnects subscriptions.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates ADR-0031; follow ADR-0031 directly.
- Forbidden: Never swap Planning Cluster instances via `queue_free()` alone — `remove_child()` must precede it, synchronously, every time.
- Guardrail: Exactly one Planning Cluster instance's subscriptions may be live at any given moment — never zero (except during WAVE_ACTIVE, by design) and never two.

---

## Acceptance Criteria

*From GDD `design/gdd/mission-hud.md` Core Rules Group 2 (Rules 5-8):*

- [x] AC-8 — on SCOUT mount (Story 001's Rule-1 mount) and on every entry to INTERMISSION: a fresh `PlanningCluster` instance is instantiated from its `PackedScene` and added to `PlanningClusterHost`, fully interactive
- [x] AC-9 — on every entry to WAVE_ACTIVE: the current `PlanningCluster` instance is torn down via synchronous `remove_child()` then `queue_free()` — never `queue_free()` alone
- [x] AC-10 — during PRE_WAVE: the Planning Cluster instance carried over from the prior SCOUT/INTERMISSION mount remains present (not destroyed/re-instanced) but only its Ready button is interactive — build list, cell overlay/cursor, and Sell button are all non-interactive
- [x] AC-11 — `CombatCluster` is present in every phase with no layout change, receives no expanded treatment during WAVE_ACTIVE (peripheral awareness only)
- [x] AC-12 (regression) — across at least 2 full SCOUT→WAVE_ACTIVE→INTERMISSION cycles, each fresh `PlanningCluster` instance's `_ready()` fires exactly once, and at no point during a swap are two instances simultaneously subscribed to the same EventBus signal

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

```gdscript
# On MissionHud (the outer root, Story 001's scaffold)
const PlanningClusterScene: PackedScene = preload("res://src/presentation/mission_hud/planning_cluster.tscn")

@onready var _planning_cluster_host: Node = $PlanningClusterHost
@onready var _combat_cluster: Control = $CombatCluster

var _planning_cluster: Control = null

func _spawn_planning_cluster() -> void:
    _planning_cluster = PlanningClusterScene.instantiate()
    _planning_cluster_host.add_child(_planning_cluster)

func _teardown_planning_cluster() -> void:
    if _planning_cluster == null:
        return
    _planning_cluster_host.remove_child(_planning_cluster)  # synchronous — forces immediate _exit_tree()
    _planning_cluster.queue_free()                          # THEN free memory
    _planning_cluster = null
```

- `PlanningCluster.tscn` (`src/presentation/mission_hud/planning_cluster.gd`, `extends Control`) is created by this story as an empty scaffold — its actual content (route-preview overlay, blocked-cell highlight, Tower Build Panel, boss-lane telegraph marker, wave-composition display) is Stories 003-007's scope. This story only owns the instantiate/teardown lifecycle and the PRE_WAVE partial-interactivity rule (AC-10).
- PRE_WAVE interactivity (AC-10): do not destroy/recreate anything at this boundary — set every Planning Cluster child EXCEPT the Ready button's container to `mouse_filter = MOUSE_FILTER_IGNORE` / disabled, driven by `mission_phase_changed(_, "PRE_WAVE")`. Reversed on the next SCOUT/INTERMISSION re-instantiation (which starts fully interactive by construction).
- `CombatCluster` is a plain `Control` child added once in the `.tscn` file itself (not instantiated/freed by script) — it exists for `MissionHud`'s entire lifetime, matching Rule 7's "no layout change" requirement.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 003-007: Planning Cluster's actual visual content
- Story 011: Combat Cluster's actual visual widgets
- Stories 008-010, 012: button wiring (which live inside these clusters but are separately scoped)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-9**: No double-connected-handler window
  - Given: a live `PlanningCluster` instance subscribed to `path_invalidated`
  - When: `mission_phase_changed → WAVE_ACTIVE` triggers `_teardown_planning_cluster()`
  - Then: immediately after `remove_child()` returns (same call, before any `await`/frame yield), the old instance's `is_inside_tree()` is `false` and its `_exit_tree()` has already run (subscriptions disconnected) — verified via a spy counter on the old instance's own `_exit_tree()`

- **AC-12**: Two-cycle regression, no double subscription
  - Given: a `MissionHud` instance run through 2 full SCOUT→WAVE_ACTIVE→INTERMISSION cycles
  - When: `path_invalidated` is emitted once per Planning Cluster's live window
  - Then: exactly one live instance receives it each time — an `EventBusSpy` count of handler invocations never exceeds 1 per emission, across both cycles

- **AC-10**: PRE_WAVE partial interactivity
  - Given: a Planning Cluster instance carried from SCOUT into PRE_WAVE
  - When: the phase transition fires
  - Then: the Ready button remains interactive (`disabled == false`); the build list, cell overlay, and Sell button are all non-interactive

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/mission-hud/phase-gated-cluster-lifecycle_test.gd` — must exist and pass

**Status**: [x] Created — `tests/integration/mission-hud/phase-gated-cluster-lifecycle_test.gd` (7 tests, passing)

---

## Dependencies

- Depends on: Story 001 (HUD Scaffold & Local State Model)
- Unlocks: Stories 003, 004, 005, 006, 007 (all render into the Planning Cluster this story creates); Story 011 (renders into the Combat Cluster)

---

## Completion Notes
**Completed**: 2026-07-20
**Criteria**: 5/5 passing (7 integration tests, all passing; end-to-end live-verified via Godot MCP against the real `the_gap.tscn` running scene — a full SCOUT→PRE_WAVE→WAVE_ACTIVE→INTERMISSION cycle confirmed the corrected synchronous-teardown sequence behaves exactly as specified, no errors in debug output).
**Deviations**:
- **Test convention deliberately deviated from, with reason stated**: every other test in this project avoids `add_child()` to prevent SavePersistence pollution. This story's entire subject is real node-lifecycle behavior (`_ready()`/`_exit_tree()` firing, `add_child()`/`remove_child()`/`queue_free()` ordering) — calling handler methods directly (the usual convention) cannot exercise this at all. `MissionHud` has no `SavePersistence` registration to pollute, so `add_child()` is safe here specifically; documented in the test file's own header comment rather than silently breaking convention.
- `PlanningCluster.tscn` was authored as a minimal scaffold (`ReadyButton` + `NonReadyControls` containing 3 placeholders: build list, cell overlay, sell button) — real content for each is Stories 003-010's own scope; this story only needed real node targets to prove the PRE_WAVE interactivity toggle (AC-10) actually works, not final UI.
**Test Evidence**: Integration — `tests/integration/mission-hud/phase-gated-cluster-lifecycle_test.gd`.
**Code Review**: Pending — deferred to a batch pass at a later Mission HUD checkpoint.
