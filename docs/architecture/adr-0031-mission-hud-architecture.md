# ADR-0031: Mission HUD Architecture

## Status
Accepted

## Acceptance Note
Accepted 2026-07-19 by explicit user decision, outside the normal `/architecture-review` gate — same precedent as ADR-0020/0021/0023/0024/0026/0028/0029/0030's Sprint 6/7 acceptances. Lightweight manual cross-check: all dependency ADRs (0002, 0011, 0020, 0028) confirmed `Accepted`; engine-specialist validation already ran and caught a real bug (the `queue_free()` deferred-delete double-connected-handler window), fixed before acceptance; no `restore_order` collision risk since Mission HUD owns zero persisted state. Unblocks Mission HUD epic/story creation, and in turn Epic 06 Story 013 and Epic 07's Tarot Story 006 AC-37/38. An independent `/architecture-review` pass in a fresh session is still recommended before this system reaches Alpha-complete.

## Date
2026-07-19

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | UI |
| **Knowledge Risk** | MEDIUM — post-LLM-cutoff. Godot 4.5 added AccessKit accessibility support and Godot 4.6 changed glow/rendering defaults (D3D12 on Windows), but this ADR's core mechanism (a `CanvasLayer`-rooted scene, re-instantiated child `PackedScene`s, `_ready()`/`_exit_tree()` signal lifecycle) uses only stable, pre-4.4 APIs. The one genuinely post-cutoff-relevant behavior — Godot 4.6's dual-focus split (mouse vs. keyboard/gamepad) — is already fully covered by ADR-0011 (Accepted), which this ADR reuses rather than re-derives. **Cross-reference, not this ADR's own risk**: `VERSION.md`'s already-characterized glow/`use_hdr_2d` finding (enabling HDR 2D to get bloom on an emissive element darkens the entire scene) applies to any future VFX polish this system adds (e.g. the PC-5 boss-lane telegraph pulse, GDD Rule 11d) — flagged here for whichever story implements that pulse's actual visual asset, not resolved by this ADR. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; ADR-0002 (Scene/Autoload Structure — already places `MissionHud` as a static `CanvasLayer` child of `MissionScene.tscn`); ADR-0011 (UI Dual-Focus Handling — `InputModeTracker`, Accepted); ADR-0020 (Direct-Autoload-call exception pattern); `design/gdd/mission-hud.md` Rule 6 (own live-MCP `_ready()` re-fire verification, 2026-07-14) |
| **Post-Cutoff APIs Used** | None new. |
| **Verification Required** | The GDD's own Rule 11c already flags the grid-cell-to-screen-space coordinate conversion (via the `CanvasLayer`'s identity transform + `Camera2D`'s one-time-set position/zoom, both already live-verified 2026-07-15) as needing a live MCP smoke test once PC-1/PC-2/PC-5 rendering code exists — carried forward here as this ADR's own Verification Criteria, not re-litigated. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Accepted — already places `MissionHud` as a static Presentation-layer `CanvasLayer` child of `MissionScene.tscn`, not an Autoload); ADR-0011 (Accepted — `InputModeTracker` pattern, reused verbatim for all 3 focusable buttons); ADR-0020 (Accepted — Criterion A/B direct-call classification for this ADR's 3 non-EventBus calls); ADR-0028 (Accepted — `MissionSelect.retry_current_mission()`, the Criterion B callee for Rule 26's Retry button) |
| **Enables** | Implementation of Mission HUD stories — the last leaf-consumer Presentation system blocking Epic 06 Story 013 (boss-lane telegraph callout) and Epic 07's Tarot Story 006 AC-37/38 (both were left Partial/blocked pending exactly this system existing in code) |
| **Blocks** | None further downstream — `systems-index.md` lists Mission HUD as a leaf consumer with no dependents |
| **Ordering Note** | None — Mission HUD has no `SaveRestorer` and no `restore_order` slot; it owns zero persisted state (GDD Core Rules Rule 3), so it has no ordering dependency on `save-persistence.md`'s table at all. |

## Context

### Problem Statement

`design/gdd/mission-hud.md` is unusually prescriptive for a first-pass GDD — 27 Core Rules across 10 Groups, a full States/Transitions table, and 5 confirmed signal contracts (PC-1 through PC-5) inherited from 3 upstream GDDs. It is also the single biggest unblocker left in the project: Epic 06's Story 013 (boss-lane telegraph audio/HUD callout) and Epic 07's Tarot Story 006 (AC-37/38) are both left `Partial`/blocked specifically because no Mission HUD code exists yet, and every Mission-context epic already implemented (02, 04, 06, 07) declares Mission HUD as a consumer of its events per `systems-index.md`'s dependency map. There is no ADR yet naming the concrete class/file structure, scene composition, or engine-idiom confirmation a programmer needs to actually implement the GDD's already-locked rules.

### Constraints

- `MissionHud` is already placed in ADR-0002's Mission Scene Hierarchy diagram as a static `CanvasLayer` child of `MissionScene.tscn` — this ADR must not re-open that classification, only build on it.
- GDD Rule 6 requires the Planning Cluster to be a **separate `PackedScene`, re-instantiated (not persisted-and-toggled)** on every SCOUT/INTERMISSION entry and `queue_free()`'d on every WAVE_ACTIVE entry — already live-MCP-verified (2026-07-14) that only re-instantiation reliably re-fires `_ready()` to reconnect EventBus subscriptions; a persistent-instance approach was confirmed to silently fail after the first cycle. This ADR must preserve that pattern, not "simplify" it away.
- GDD Rule 3: Mission HUD owns **zero gameplay state** — no `SaveRestorer`, no `restore_order` slot needed.
- GDD's own Interactions table already fixes exactly 3 non-EventBus calls this system makes: `PathfindingSystem.get_path()` (read-only), `Grid.cell_to_world()` (read-only), `MissionSelect.retry_current_mission()` (action, GDD Rule 26's own explicitly-flagged exception to the otherwise-universal emit-only pattern). This ADR must classify each under ADR-0020's Criterion A/B, not invent new direct-call justifications.
- All 3 outbound signals (`player_ready`, `hero_ultimate_activated`, `tower_sell_requested`) and every focusable button must follow ADR-0011's `InputModeTracker` pattern (GDD Rule 24).

### Requirements

- Concrete scene/class structure for `MissionHud` (root), the re-instantiated Planning Cluster, and the persistent Combat Cluster.
- HUD-local derived-state field types (GDD Rule 4): `_enemies_alive_display: int`, `_breach_count: int`, `_active_tower_hp_bars: Dictionary[int, Vector2]`, `_boss_state: Dictionary` (nullable), `_boss_telegraph_cell: Vector2i`.
- Subscription/lifecycle wiring: which subscriptions live on the outer root (persistent, `_ready()`/`_exit_tree()` of `MissionHud` itself) vs. which live on the Planning Cluster (per-cycle `_ready()`/`_exit_tree()`).
- Confirmation that the 3 non-EventBus calls satisfy ADR-0020's Criterion A (read) / Criterion B (state-guarded action) definitions.
- No new Autoload — Mission HUD remains scene-instanced per ADR-0002.

## Decision

### Scene structure: `MissionHud` (`CanvasLayer`, static child of `MissionScene.tscn`)

```
MissionHud (CanvasLayer)                          — src/presentation/mission_hud/mission_hud.gd
├── CombatCluster (Control)                        — persistent for the HUD's entire lifetime
│     Hero HP bar, skill/ultimate cooldowns, breach counter, boss bar, tower HP bars, floating damage numbers
└── PlanningClusterHost (Node)                      — empty container; holds whichever PlanningCluster instance is currently live, or none
      (PlanningCluster.tscn instances added/removed here — never persisted across a WAVE_ACTIVE cycle)
```

`PlanningCluster.tscn` (`Control`, own `PackedScene`) — `src/presentation/mission_hud/planning_cluster.gd`: route-preview overlay, blocked-cell highlight, Tower Build Panel, Ready button, Sell button, PC-5 boss-lane telegraph marker, wave-composition preview display (Rules 11f/11g). Instantiated fresh via `PlanningClusterScene.instantiate()` and `add_child()`'d to `PlanningClusterHost` on every SCOUT/INTERMISSION entry (GDD Rule 6); torn down on every WAVE_ACTIVE entry. Its own `_ready()`/`_exit_tree()` connect/disconnect its subset of subscriptions (`path_invalidated`, `tower_placement_blocked`) each cycle — this is the entire reason it must be a separate scene rather than a persistent node toggled visible/invisible (Rule 6's live-MCP-verified rationale).

**Swap mechanism, corrected during engine-specialist review**: `queue_free()` alone is insufficient for the teardown half of this swap — it schedules deletion for end-of-frame (Godot's deferred-delete queue), so the outgoing instance keeps its EventBus subscriptions live and receiving events for the rest of that frame, while a freshly-instantiated replacement would already be connecting its own subscriptions in the same frame if instantiation happened immediately after. This is a real double-connected-handler window (both old and new instances processing `path_invalidated`/`tower_placement_blocked` simultaneously until idle time), not merely a theoretical race. The correct sequence: `get_parent().remove_child(old_instance)` **synchronously** first (forces immediate `_exit_tree()`, disconnecting subscriptions right away, per Godot's node-removal contract) — only then `old_instance.queue_free()` to actually free the memory, followed by `instantiate()`/`add_child()` of the fresh instance. `remove_child()` before `queue_free()` is mandatory for every ordinary SCOUT/INTERMISSION↔WAVE_ACTIVE swap, not just the terminal-phase case the Risks section already flags.

### State ownership: outer root vs. Planning Cluster

Per GDD Rule 11a's explicit rationale (this ADR does not re-derive it, only assigns it a concrete home): `_boss_telegraph_cell` and the `wave_preview_available` subscription live on `MissionHud` (the outer root), **not** the Planning Cluster — `wave_preview_available` fires synchronously in the same call stack as the phase transition that re-instantiates the Planning Cluster, so a Planning-Cluster-owned subscription could not be guaranteed connected before that emission on every cycle (a recurring, not one-time, ordering risk). The outer root caches the value and hands it to whichever Planning Cluster instance is currently live for rendering (GDD Rule 11c).

All 5 of Rule 4's HUD-local derived-state fields (`_enemies_alive_display`, `_breach_count`, `_active_tower_hp_bars`, `_boss_state`, `_boss_telegraph_cell`) live on `MissionHud` (the outer root) for the same reason — they must survive every Planning Cluster re-instantiation cycle within one mission, since none of them are scoped to the Planning Cluster's own per-wave lifetime (breach count and tower HP bars, for instance, are Combat Cluster display data, never reset by a Planning Cluster cycle boundary).

```gdscript
class_name MissionHud
extends CanvasLayer

const PlanningClusterScene: PackedScene = preload("res://src/presentation/mission_hud/planning_cluster.tscn")

var _enemies_alive_display: int = 0
var _breach_count: int = 0
var _active_tower_hp_bars: Dictionary[int, Vector2] = {}
var _boss_state: Dictionary = {}          # {} = null-equivalent; non-empty = {entity_id, display_name, current_hp, max_hp}
var _boss_telegraph_cell: Vector2i = Vector2i(-1, -1)
var _terminal: bool = false               # latched on MISSION_COMPLETE/DEFEAT (Edge Cases)

var _planning_cluster: Control = null     # current live instance, or null

func _ready() -> void:
    # Persistent subscriptions only — Wave Manager, Monster, Damage & Status,
    # Hero, Resource Economy, Inventory, Tower (all rows in the GDD's own
    # Interactions table except path_invalidated/tower_placement_blocked,
    # which are Planning-Cluster-owned).
    GEventBus.mission_phase_changed.connect(_on_mission_phase_changed)
    GEventBus.wave_preview_available.connect(_on_wave_preview_available)
    GEventBus.templates_ready.connect(_on_templates_ready)
    # ... remaining persistent subscriptions per the Interactions table
```

### Direct-Autoload calls — ADR-0020 classification

| Call | Classification | Justification |
|---|---|---|
| `PathfindingSystem.get_path(spawn_cell, 0)` | **Criterion A** (read) | Read-only query against Pathfinding's sole-owned routing state (GDD Rules 9, PC-1) |
| `Grid.cell_to_world(cell: Vector2i) -> Vector2` | **Criterion A** (read) | Read-only coordinate-space query against Grid's sole-owned spatial data (GDD Rule 11c) |
| `MissionSelect.retry_current_mission()` | **Criterion B** (narrow, single-caller action) | The GDD's own Rule 26 already names this as the one deliberate exception to the emit-only pattern; MissionSelect is Autoload #12 (ADR-0028) specifically so this call is legal under ADR-0020 without Mission HUD holding a node reference |
| `GameDataRegistry.get_monster_resource(monster_id) -> MonsterResource` | **Criterion A** (read) | Not new to this ADR — already classified project-wide by ADR-0020's own retroactive classification (static content-data lookup). Listed here for completeness since Stories 006/007/011 call it repeatedly (tier/display_name resolution for the boss telegraph, composition preview, and boss bar) — omitted from this table's original draft, caught during the epic's deferred batch `/code-review` (2026-07-20). |

No new Autoload classification is introduced — all 4 callees (`PathfindingSystem`, `Grid`, `MissionSelect`, `GameDataRegistry`) are already Autoloads per ADR-0002/ADR-0009/ADR-0028.

### Cell-to-screen conversion (Rule 11c) — concrete API, not deferred to implementation

Given the GDD's own already-verified preconditions (the `CanvasLayer`'s identity transform, the mission's `Camera2D` position/zoom set exactly once and never updated), the correct conversion is:

```gdscript
var world_pos: Vector2 = GGrid.cell_to_world(_boss_telegraph_cell)
var screen_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos
```

`get_viewport().get_canvas_transform()` correctly folds in the camera's position/zoom without hand-rolled math, and composes correctly with the `CanvasLayer`'s confirmed identity transform (Rule 11c's own note). Named explicitly here (engine-specialist-flagged during review) rather than left as an open implementation question — it removes an ambiguity a programmer would otherwise have to rediscover from the GDD's live-MCP findings alone.

### `InputModeTracker` reuse

`MissionHud` instances one `InputModeTracker` (ADR-0011) at its own root, shared across the 3 focusable, EventBus-emitting buttons (Ready, Ultimate, Sell — GDD Rule 24) and the DEFEAT-only Retry button (Rule 26). This is the third consumer of the pattern after Inventory's two-panel screen — no changes to `InputModeTracker` itself are needed.

## Alternatives Considered

### Alternative A: Single persistent Planning Cluster, shown/hidden per phase instead of re-instantiated

- **Description**: Keep one `PlanningCluster` node alive for the HUD's entire lifetime, toggling `visible`/`process_mode` per phase instead of `queue_free()`/`instantiate()`-ing it every cycle.
- **Pros**: Simpler mental model, avoids the churn of repeated instantiation.
- **Cons**: Directly contradicts the GDD's own live-MCP-verified finding (Rule 6, 2026-07-14): a node re-added via `remove_child()`/`add_child()` does **not** re-fire `_ready()` in Godot 4.6.2, so its `path_invalidated`/`tower_placement_blocked` subscriptions (connected in `_ready()`) would silently fail to reconnect after the first WAVE_ACTIVE→INTERMISSION cycle — a real, measured engine behavior, not a hypothetical risk.
- **Rejection Reason**: The GDD already ran the live verification; this ADR's job is to formalize that finding into concrete scene structure, not re-litigate it against an unverified simpler alternative.

### Alternative B: Fold Combat Cluster and Planning Cluster into one script/scene

- **Description**: A single `MissionHud.tscn`/`.gd` handling both clusters' logic inline, rather than splitting Planning Cluster into its own `PackedScene`.
- **Pros**: Fewer files.
- **Cons**: The Combat Cluster is persistent (GDD Rule 7 — "present in every phase with no layout change") while the Planning Cluster is destroyed/recreated every wave cycle (Rule 6). Folding them into one script would force the re-instantiation churn onto Combat Cluster elements that must never reset mid-mission (hero HP bar, tower HP bars, breach counter) — directly contradicting Rule 4's stated reset-only-on-mount semantics for those fields.
- **Rejection Reason**: The GDD's phase-gated existence model (Group 2) is structurally two different lifecycles bolted onto one HUD root — splitting them into separate scenes is the only way to give each its own correct instantiation cadence.

## Consequences

### Positive
- Formalizes a scene/class structure a programmer can implement directly from the GDD's already-locked Core Rules, with no remaining architectural ambiguity.
- Unblocks Epic 06 Story 013 and the remaining half of Epic 07's Tarot Story 006 (AC-37/38) — both explicitly waiting on Mission HUD existing in code.
- Introduces no new Autoload, no new persistence slot, and no new engine-risk surface beyond what ADR-0002/ADR-0011/ADR-0020 already cover.

### Negative
- Mission HUD subscribes to more distinct EventBus signal types than any other system in the project (per the GDD's own Edge Cases note) — the `_ready()`/`_exit_tree()` connect/disconnect list on the outer root will be long and is a maintenance surface for future signal renames.
- The Planning Cluster's re-instantiation-per-cycle pattern, while correct, means its child controls (Tower Build Panel, route-preview overlay) cannot hold any state across a wave boundary without explicitly caching it on the outer root first (as `_boss_telegraph_cell` already must) — any future Planning-Cluster-local state addition must remember this constraint or silently lose data every cycle.

### Risks
- **Risk**: The grid-cell-to-screen-space coordinate conversion (Rule 11c) has not been pixel-verified end-to-end — only the two load-bearing preconditions (CanvasLayer identity transform, one-time-set Camera2D) have been live-MCP-confirmed.
  - **Mitigation**: Carried forward as this ADR's Validation Criteria — re-attempt full pixel verification once PC-1/PC-2/PC-5 rendering code exists, matching the GDD's own stated plan.
- **Risk**: `_terminal` latching (Edge Cases: combat events arriving after a terminal phase change but before `_exit_tree()` runs, since `queue_free()` is end-of-frame not instant) is easy to omit if a future contributor adds a new Combat/Planning Cluster mutation handler without checking the flag first.
  - **Mitigation**: Documented explicitly in this ADR's Key Interfaces comment and the GDD's own Edge Cases section — a code-review checklist item, not a structural guarantee this ADR can enforce mechanically.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| mission-hud.md | Rule 1: static `CanvasLayer` child of `MissionScene.tscn`, not an Autoload | Confirmed inherited from ADR-0002's existing classification; this ADR adds the concrete `class_name MissionHud extends CanvasLayer` |
| mission-hud.md | Rule 6: Planning Cluster re-instantiated per cycle, `queue_free()`'d at WAVE_ACTIVE | Formalized as a separate `PlanningCluster.tscn`/`PackedScene`, instantiated into a `PlanningClusterHost` container node |
| mission-hud.md | Rule 4: HUD-local derived state | Typed field declarations on `MissionHud`, all owned by the outer root per Rule 11a's ordering rationale |
| mission-hud.md | Rules 9, 11c, 26: the 3 non-EventBus direct calls | Classified under ADR-0020 Criterion A (×2, read-only) / Criterion B (×1, `MissionSelect.retry_current_mission()`) |
| mission-hud.md | Rule 24: `InputModeTracker` for all focusable controls | One `InputModeTracker` instance at the `MissionHud` root, reusing ADR-0011 verbatim |

## Performance Implications
- **CPU**: Negligible — all HUD updates are event-driven (EventBus signal handlers), not per-frame polling. The Planning Cluster's re-instantiation happens at most twice per wave cycle (SCOUT/INTERMISSION entry), not per-frame.
- **Memory**: One `PlanningCluster` instance's worth of nodes churns per wave — bounded, not cumulative (the prior instance is `queue_free()`'d before the next is created).
- **Load Time**: No new load-time phase — Mission HUD loads with `MissionScene.tscn` as it already does per ADR-0002.
- **Network**: N/A — single-player game.

## Migration Plan
N/A — Mission HUD has no existing implementation to migrate from. Greenfield.

## Validation Criteria
- Live-MCP smoke test (matching the GDD's own established verification standard) confirming a Planning Cluster instance's `_ready()` fires on every SCOUT/INTERMISSION entry across at least 2 full wave cycles, and its subscriptions are genuinely reconnected each time (not silently stale after cycle 1).
- Unit/integration test confirming the corrected swap sequence (`remove_child()` synchronous, then `queue_free()`, then fresh `instantiate()`/`add_child()`) never leaves two Planning Cluster instances simultaneously connected to `path_invalidated`/`tower_placement_blocked` — a regression test for the double-connected-handler window the engine-specialist review caught in this ADR's own first draft.
- Live-MCP pixel verification of the grid-cell-to-screen-space conversion for the PC-5 boss-lane telegraph marker, once implemented — confirming a marker rendered at a known `Vector2i` cell appears at the geometrically correct screen position given the CanvasLayer's identity transform and the mission's fixed Camera2D position/zoom.
- Unit/integration test confirming `_terminal` latching genuinely suppresses all Combat/Planning Cluster mutation handlers after a terminal `mission_phase_changed`, even with combat events still arriving same-frame.

## Related Decisions
- ADR-0002 (Scene/Autoload Structure) — already places `MissionHud` in the Mission Scene Hierarchy as a static `CanvasLayer` child, scene-instanced
- ADR-0011 (UI Dual-Focus Handling) — `InputModeTracker` pattern, reused verbatim for all 4 focusable buttons
- ADR-0020 (Direct-Autoload-call exception pattern) — governs all 3 of this ADR's non-EventBus calls
- ADR-0028 (Mission Select Runtime State) — confirms `MissionSelect` as Autoload #12, the Criterion B callee for `retry_current_mission()`
- `design/gdd/mission-hud.md` — source GDD for every requirement this ADR addresses (Needs Revision status, 1 advisory-only finding per its last review — does not block this ADR per this project's established precedent of shipping against a Needs-Revision GDD, e.g. Epic 03)
