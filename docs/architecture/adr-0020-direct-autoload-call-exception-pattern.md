# ADR-0020: Direct-Autoload-Call Exception Pattern

## Status
Accepted

## Date
2026-07-17

## Acceptance Note
Accepted 2026-07-17 by direct user decision during `/create-stories epic-05-sanctuary-production`, to unblock that epic's stories — outside the normal `/architecture-review` gate (which was explicitly deferred this session, see `production/session-state/active.md`). engine-specialist validation already completed at authoring time; no re-review performed at acceptance.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core / Architecture pattern |
| **Knowledge Risk** | LOW — this ADR governs a GDScript calling-convention choice (Autoload method calls vs. signals), not any specific engine subsystem. No post-cutoff API surface is involved. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` (no domain-specific module doc applies — this is a pure GDScript/architecture convention, not an engine API) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (EventBus architecture — this ADR defines the exception to its `direct_cross_system_node_reference` forbidden pattern), ADR-0005 (Grid system data model — first instance of this exception, retroactively formalized here) |
| **Enables** | ADR-0021 (Inventory cross-system query/mutation API — applies this pattern's criteria), ADR-0022 (Constellation pattern-detection data structure — Constellation's Grid read calls follow this pattern), the eventual Tower Mastery ADR (`TowerSystem.get_component_loadout()`) |
| **Blocks** | None — this ADR retroactively documents exceptions already in use; it does not gate any currently-blocked story |
| **Ordering Note** | None |

## Context

### Problem Statement

Three narrow exceptions to the project's EventBus-only communication rule (`forbidden_patterns.direct_cross_system_node_reference`, ADR-0001) already exist in the codebase's design documents, each independently justified in its own GDD's prose:

1. **Grid's read API** (`grid-system.md` Rules 8–9, formalized in ADR-0005) — direct Autoload calls for per-frame spatial queries (`get_cell_type()`, `get_occupied_cells_in_radius()`, etc.), because routing these through EventBus would exceed the frame budget.
2. **GameDataRegistry's lookup methods** (ADR-0009) and **MissionEconomy's balance queries** (`get_gold_balance()`, `can_afford()`, ADR-0018) — the registry entry for `mission_economy_gold_balance` explicitly calls these "the same exception class" as Grid's read API.
3. **Mission Select's `retry_current_mission()`** (`mission-select.md` Rule 10) — a UI-triggered, single-caller action call, justified in the GDD's own prose as following "the same way Grid's own Rule 9/Rule 8 justify their direct-call exceptions," but with a different underlying reason (no per-frame budget concern — a narrow, single-caller action with no synergy benefit from broadcast).

Each of these re-justifies itself independently in prose rather than pointing to one governing decision. This is now the third documented instance of the pattern (Grid, Mission Select, and Mission HUD's DEFEAT Retry-button call into `retry_current_mission()`, added 2026-07-17) — and a fourth new-system requirement (Tower Mastery's proposed `TowerSystem.get_component_loadout(tower_id)`) is already queued to need it. Without a single governing ADR, each new exception has to independently reinvent and re-argue the justification, and there is no registry-checkable criteria for a reviewer (or `/architecture-review`) to validate a newly proposed exception against.

### Constraints

- Must not weaken ADR-0001's `direct_cross_system_node_reference` forbidden pattern as a general rule — this ADR carves out a narrow, criteria-bound exception, not a blanket permission.
- Must not retroactively invalidate any of the three existing instances (Grid, GameDataRegistry/MissionEconomy, Mission Select) — they must satisfy the criteria this ADR defines, or the ADR is wrong.
- Must produce criteria specific enough that `/architecture-review` or a future ADR author can mechanically check a new proposed exception against it, rather than re-deriving a justification from scratch each time.

### Requirements

- Cover both observed sub-categories: (a) high-frequency **read-only queries** where EventBus dispatch overhead is unacceptable against the frame budget, and (b) narrow, **single-caller action calls** (typically UI-triggered) where EventBus's broadcast/decoupling benefit does not apply because there is exactly one caller and one callee by design.
- Must not expand to permit **writes** to state owned by another system except through the pattern already established by Tower System's exclusive `Grid.place_tower()`/`remove_tower()` write access (ADR-0005) — i.e., a write exception is only valid when the registry already designates a single authorized writer.

## Decision

**A direct Autoload-to-Autoload (or UI-to-Autoload) method call is permitted, as a documented exception to the EventBus-only rule, if and only if it satisfies one of two criteria:**

**Criterion A — High-frequency read query.** The call is a **read-only** query (no state mutation), called at a frequency where EventBus round-trip dispatch would consume an unacceptable share of the 16.67 ms frame budget (per the `event-bus` performance budget entry in `docs/registry/architecture.yaml`), AND the callee is the single authoritative owner of the queried state (per `state_ownership` in the registry). The caller must treat the returned value as a copy — never hold a reference into the callee's internal state.

**Criterion B — Narrow single-caller action.** The call is a **UI-triggered or otherwise structurally single-caller** action (there is exactly one call site by design, not merely by current usage) where EventBus's core benefit — decoupling an unknown number of producers from an unknown number of subscribers — provides no value, because the call always has exactly one specific caller and one specific callee. The callee must guard the call with an explicit state-validity check (e.g., "only valid from a specific FSM state") and fail safely (log + no-op) if called outside that state, rather than assuming the caller's precondition always holds.

A call that is read-only but **not** high-frequency (e.g., a one-time UI query) does not need this exception — it should still prefer EventBus unless Criterion A's frequency justification applies. A call that mutates state must additionally satisfy the registry's existing single-writer rule for that state (ADR-0005's `grid_write_outside_tower_system` precedent) — this ADR does not create any new write exception.

**Retroactive classification of existing instances:**

| Instance | Criterion | Justification |
|---|---|---|
| `Grid.get_cell_type()`, `get_occupied_cells_in_radius()`, `get_towers_in_range()`, etc. | A (read) | Called by Tower, Constellation, Pathfinding, Wave Manager, Tower Mastery, Monster System at per-frame or per-event frequency during active gameplay; Grid is the sole owner of `grid_cell_data` (registry). |
| `GameDataRegistry.get_monster_resource()`, `get_perk_registry()` | A (read) | Static data lookups against the sole boot-time-loaded owner of `game_entity_resource_lookup` (registry); called frequently enough (per-spawn, per-placement) that EventBus round-trip would be wasteful for what is functionally a map lookup. |
| `MissionEconomy.get_gold_balance()`, `can_afford()` | A (read) | Sole owner of `mission_economy_gold_balance` (registry); called on every placement-gate check (Tower System Gate 2), a per-attempt-frequency read. |
| `MissionSelect.retry_current_mission()` | B (action) | Exactly one caller (Mission HUD's DEFEAT Retry button) and one callee, structurally — no other system will ever call this. Guarded by an explicit `DEFEAT`-armed-state check (`mission-select.md` Rule 10/EC-6, AC-25) that logs and no-ops if the precondition (a cached `MissionRuntimeState`) is absent. |

**Not yet written, anticipated to apply this ADR:** `TowerSystem.get_component_loadout(tower_id)` (Tower Mastery's proposed query, Criterion A — read-only, per-tick-during-WAVE_ACTIVE frequency, Tower System is sole owner of `tower_mission_state`).

### Architecture Diagram

```
EventBus (default path — any-to-any, decoupled)
  └─ used for all cross-system communication EXCEPT the two criteria below

Direct Autoload Call (exception path — requires registry entry)
  ├─ Criterion A (read query, high-frequency, sole-owner callee)
  │    Grid ← Tower/Constellation/Pathfinding/WaveManager/TowerMastery/Monster
  │    GameDataRegistry ← any system needing static data lookup
  │    MissionEconomy ← Tower System (Gate 2 can_afford check)
  │
  └─ Criterion B (single-caller action, state-guarded callee)
       MissionSelect.retry_current_mission() ← Mission HUD (DEFEAT Retry button, sole caller)
```

### Key Interfaces

This ADR does not introduce a new interface itself — it defines the *criteria* a `docs/registry/architecture.yaml` `interfaces` entry must satisfy to use `pattern: direct_call` instead of `pattern: event_bus`. A new direct-call exception must, at minimum, document:

```
- contract: <name>
  pattern: direct_call
  producer: <sole-owner system>
  consumers: [<caller(s)>]
  signal_signature: "<method signature> — Criterion A (read, high-frequency) | Criterion B (single-caller action). <one-line justification citing which criterion and why>."
```

## Alternatives Considered

### Alternative 1: No formal exception — route everything through EventBus

- **Description**: Remove all direct Autoload calls; even Grid's spatial queries would fire as EventBus request/response event pairs.
- **Pros**: Perfect architectural uniformity — one communication pattern, no special cases to reason about.
- **Cons**: Grid's read API alone is called dozens of times per frame during WAVE_ACTIVE (pathfinding rebuilds, constellation rechecks, tower range queries) — EventBus request/response round-tripping at that frequency would consume a large fraction of the 16.67 ms frame budget for what is functionally a Dictionary lookup with zero decoupling benefit (the caller already knows exactly which system owns the data).
- **Rejection Reason**: Already implicitly rejected by ADR-0005, which shipped this exception 2026-05-16. Retrofitting Grid onto EventBus now would also break the already-Accepted contract other ADRs depend on.

### Alternative 2: Blanket permission — any Autoload may call any other Autoload directly

- **Description**: Drop the EventBus-only rule generally; direct calls are always allowed between Autoloads.
- **Pros**: Maximum implementation flexibility, no criteria to check.
- **Cons**: Reintroduces the exact tight coupling and untestability-in-isolation problem ADR-0001 was written to prevent — cross-system synergies (the project's core design pillar) depend on systems not holding hard references to each other's internals.
- **Rejection Reason**: Defeats the purpose of ADR-0001. The existing three instances are narrow and criteria-bound precisely because they're exceptions, not a new default.

## Consequences

### Positive
- Future ADR authors and `/architecture-review` have a checkable rubric (Criterion A / B) instead of needing to re-derive a justification from first principles for every new direct-call proposal.
- Retroactively resolves the "third instance re-justifying itself independently" problem flagged in the 2026-07-17 architecture review — Mission Select's, Mission HUD's, and Grid's GDD prose can now cite this ADR instead of restating the argument.
- Gives Tower Mastery's forthcoming ADR a pre-established pattern to slot `get_component_loadout()` into, rather than inventing a fourth independent justification.

### Negative
- Adds one more document a new-exception author must consult before adding a direct call — a small process overhead against the benefit of a checkable rubric.

### Risks
- **Risk**: Criterion A's "high-frequency" and Criterion B's "structurally single-caller" are judgment calls, not hard numeric thresholds — a future author could stretch the criteria to justify a call that doesn't really need the exception.
  - **Mitigation**: The registry entry format above requires an explicit one-line justification citing which criterion and why; `/architecture-review` Phase 4 (cross-ADR conflict detection) is the checkpoint where an over-broad claim should be caught.
- **Risk** (godot-specialist validation): a caller in another Autoload's `_ready()` invoking a direct-call exception before the callee's own `_ready()` has run gets stale/default data silently rather than a loud error — Autoload initialization order (Project Settings) determines this, and direct calls make the failure mode silent.
  - **Mitigation**: Any Criterion A/B call made from `_ready()` must either be deferred (`call_deferred()`, or gated on an EventBus `systems_ready`-style signal) or the callee's `_ready()` must leave it in a valid, query-safe state with no boot-order assumption. This should be checked per-instance at implementation time, not assumed safe by this ADR.
- **Risk** (godot-specialist validation): "return a copy, never a reference" (Decision, Criterion A) is easy to violate accidentally in GDScript, since `Array`/`Dictionary`/`Packed*Array` are reference types — returning `self._cells` directly *looks* like returning a value but is still a live reference into the callee's internal state.
  - **Mitigation**: Sole-owner methods satisfying Criterion A must explicitly return `.duplicate()` (or construct a new container) rather than the internal container itself. Method signatures should also be fully statically typed (e.g. `Array[Vector2i]`, not bare `Array`), per `technical-preferences.md`'s static-typing mandate — an untyped or unduplicated return at an ownership boundary silently reintroduces the coupling this ADR's criteria exist to prevent.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| grid-system.md | Rules 8–9: Grid direct read API exception | Retroactively classified as Criterion A; no change to Grid's existing (Accepted, ADR-0005) contract |
| mission-select.md | Rule 10: `retry_current_mission()` as "the same way Grid's own Rule 9/Rule 8 justify their direct-call exceptions" | Formalized as Criterion B — single-caller UI action, state-guarded |
| mission-hud.md | Rule 26–27: DEFEAT Retry button calls `MissionSelect.retry_current_mission()` | Confirms Mission HUD is the sole caller satisfying Criterion B for this instance |

## Performance Implications
- **CPU**: No change — this ADR formalizes existing calling conventions; it does not alter which calls happen or how often.
- **Memory**: None.
- **Load Time**: None.
- **Network**: N/A — single-player game.

## Migration Plan
N/A — no existing code changes as a result of this ADR; it documents conventions already in use in the design layer.

## Validation Criteria
- Any new `pattern: direct_call` entry added to `docs/registry/architecture.yaml` after this ADR must cite Criterion A or B explicitly in its `signal_signature` justification field.
- `/architecture-review` Phase 4 should flag any direct-call registry entry that does not cite a criterion from this ADR.

## Related Decisions
- ADR-0001 (EventBus architecture) — defines the general rule this ADR carves a narrow exception into
- ADR-0005 (Grid system data model) — first instance of Criterion A, retroactively classified here
- ADR-0009 (Resource data model) — GameDataRegistry lookup, Criterion A
- ADR-0018 (Mission economy gold balance) — MissionEconomy balance queries, Criterion A
- `design/gdd/mission-select.md`, `design/gdd/mission-hud.md` — source of the Criterion B instance
