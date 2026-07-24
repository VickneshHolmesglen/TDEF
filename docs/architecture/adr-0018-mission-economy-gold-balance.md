# ADR-0018: Mission Economy — Runtime Gold Balance Ownership

## Status
Accepted

## Date
2026-07-13

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core (Autoload / scripting) |
| **Knowledge Risk** | LOW — plain `Node` Autoload with signal wiring and two read methods; no post-cutoff API surface. No dedicated `modules/core.md` exists (expected — same as ADR-0016/ADR-0017's pure data/session-state domain). |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (EventBus — `resources_changed`, `mission_launched` signals), ADR-0002 (Scene/Autoload structure — this ADR adds `MissionEconomy` as Autoload position 8, after `WaveManager`), ADR-0012 (Wave Manager FSM — precedent for a mission-scoped Autoload whose state resets on `mission_launched` rather than persisting), ADR-0017 (Resource Economy — the sole emitter of `resources_changed` gold deltas this ADR consumes) |
| **Enables** | Fully unblocks Epic 03 Story 013 (Gold Track & Scout Starting Grant) — the last of Epic 03's 15 stories still `Status: Blocked` for an architectural reason |
| **Blocks** | None |
| **Ordering Note** | ADR-0002 must be revised to add `MissionEconomy` at boot position 8 before implementation begins — the only new Autoload this ADR introduces. |

## Context

### Problem Statement

`resource-economy.md` and ADR-0017 both explicitly flag the same open gap: Resource Economy *computes* gold deltas and emits them via the already-shipped `resources_changed(gold: int, source: StringName)` signal, but **no system tracks the resulting balance**. Tower System's own placement gate (ADR-0008, Gate 2) already assumes a `ResourceSystem.can_afford(cost)` call exists — it was written as a placeholder pending this decision. Wave Manager's GDD independently flags a "Scout Phase Economy (TODO)" for delivering the starting gold pool, which Resource Economy Rule 8 already answers by emitting a flat grant on SCOUT entry — but again, nothing stores what accumulates after that grant.

Without an owner, Epic 03 Story 013 cannot be implemented or tested end-to-end: there is no balance to assert against.

### Constraints

- `resources_changed(gold: int, source: StringName)` is a frozen, already-shipped signal (per ADR-0017) — its payload shape (`gold` is a signed delta, not an absolute balance) must not change.
- Tower System's placement-confirmation gate (ADR-0008 Gate 2) needs a synchronous, authoritative affordability check — the same latency argument that justifies Grid's direct-read exception (ADR-0005) and GameDataRegistry's lookup API (ADR-0009) applies here even more directly, since ADR-0008's pseudocode already assumes a direct call.
- Gold is mission-scoped, not save-persistent: `save-persistence.md`'s own "What is NOT saved" list already excludes other mission-runtime scalars (current wave number, hero HP, timers); gold belongs in that same category per ADR-0017's Open Questions ("gold resets at MISSION_COMPLETE/DEFEAT").
- Must not require Resource Economy or Wave Manager to hold a direct reference to the new owner (EventBus-only for writes; direct-call is reserved for reads only, matching the Grid/GameDataRegistry exception pattern).

### Requirements

- A single, unambiguous owner for the runtime `int` gold balance.
- Balance resets to 0 exactly once per mission, before any `resources_changed` grant for that mission can arrive.
- Balance accumulates every `resources_changed` delta regardless of source (Scout starting grant, kill drops, spending).
- A direct-call, read-only API for affordability checks and live HUD display — no EventBus round trip for a per-placement-attempt query.
- No save/restore obligation — the state is intentionally ephemeral.

## Decision

### New Autoload: `MissionEconomy` (boot position 8)

A new Autoload, `MissionEconomy`, owns exactly one piece of state: `_gold_balance: int`. It is added at **boot position 8**, after `WaveManager` (position 7) — updated order: `EventBus(1), SavePersistence(2), Grid(3), Pathfinding(4), GameDataRegistry(5), SceneManager(6), WaveManager(7), MissionEconomy(8)`.

This mirrors `WaveManager`'s own precedent exactly (ADR-0012): a mission-scoped Autoload whose state is reset via an EventBus-driven lifecycle hook rather than being persisted, and which is observed by other systems either through EventBus events it emits or through direct read calls it exposes — never through direct external mutation.

**Mutation — EventBus subscription only:**

```gdscript
func _on_resources_changed(gold: int, _source: StringName) -> void:
    _gold_balance += gold
```

`gold` is the signed delta already defined by ADR-0017 — no payload change. `MissionEconomy` never emits `resources_changed` itself; it is a pure subscriber.

**Reset — on `mission_launched`:**

```gdscript
func _on_mission_launched(_mission_id: String, _modifiers: PackedStringArray, _difficulty_tier: int) -> void:
    _gold_balance = 0
```

This fires before Wave Manager's own SCOUT transition completes and before Resource Economy's Scout-starting-gold grant (`resource-economy.md` Rule 8) is emitted, so the grant always lands on a freshly-zeroed balance — consistent with `mission_launched` being the single shared reset trigger already used by Wave Manager (ADR-0012 EC-9) and Save & Persistence's checkpoint write (ADR-0003).

**Reads — direct-call API, no EventBus round trip:**

```gdscript
func get_gold_balance() -> int:
    return _gold_balance

func can_afford(cost: int) -> bool:
    return cost <= _gold_balance
```

This is the same class of documented EventBus-only exception as Grid's read API (ADR-0005) and `GameDataRegistry`'s lookup methods (ADR-0009): both are justified by call frequency being too high (or, here, too latency-sensitive at the exact moment of placement confirmation) for an EventBus round trip. `can_afford()` directly resolves ADR-0008 Gate 2's placeholder `ResourceSystem.can_afford(cost)` call — Tower System should call `MissionEconomy.can_afford(cost)` by name.

**No `SaveRestorer` implementation.** `MissionEconomy` does not register with `SavePersistence` (ADR-0003) and has no `get_save_data()`/`restore_save_data()`. Gold is ephemeral mission-runtime state, structurally identical to the other fields `save-persistence.md` already excludes (current wave number, hero HP, active timers) — it resets naturally every `mission_launched`, matching a fresh Autoload-internal default with no persistence code required.

### Architecture Diagram

```
EventBus
  resources_changed(gold: int, source: StringName) ──► MissionEconomy._on_resources_changed()
                                                            _gold_balance += gold
  mission_launched(mission_id, modifiers, tier) ────► MissionEconomy._on_mission_launched()
                                                            _gold_balance = 0

TowerSystem.place_tower() Gate 2  ──► MissionEconomy.can_afford(cost) -> bool     (direct call)
Mission HUD (live gold counter)   ──► MissionEconomy.get_gold_balance() -> int   (direct call)
```

### Key Interfaces

```gdscript
# MissionEconomy.gd — Autoload #8 (boots after WaveManager)
extends Node

var _gold_balance: int = 0

func _ready() -> void:
    EventBus.resources_changed.connect(_on_resources_changed)
    EventBus.mission_launched.connect(_on_mission_launched)

func _exit_tree() -> void:
    EventBus.resources_changed.disconnect(_on_resources_changed)
    EventBus.mission_launched.disconnect(_on_mission_launched)

func _on_mission_launched(_mission_id: String, _modifiers: PackedStringArray, _difficulty_tier: int) -> void:
    _gold_balance = 0

func _on_resources_changed(gold: int, _source: StringName) -> void:
    _gold_balance += gold

# Public read-only API (direct call, mirrors Grid/GameDataRegistry exception pattern)
func get_gold_balance() -> int:
    return _gold_balance

func can_afford(cost: int) -> bool:
    return cost <= _gold_balance
```

## Alternatives Considered

### Alternative 1: Extend Wave Manager with `_gold_balance`
- **Description**: Add `_gold_balance: int` directly onto `WaveManager`, reset in the same EC-9 block as its other mission-scoped fields.
- **Pros**: No new Autoload; reuses an already-Accepted boot slot; identical reset trigger already exists.
- **Cons**: Blurs Wave Manager's single responsibility (phase FSM) with an unrelated economy ledger. Every future mission-scoped scalar (and there may be more once Crafting/Menagerie/Equipment Forge are designed) would keep piling onto the same Autoload, or force a fresh ADR each time to decide where the next one goes.
- **Rejection Reason**: A dedicated single-purpose Autoload keeps Wave Manager's FSM scope clean and gives future mission-scoped economy state (e.g. a future materials-spent counter for a HUD tally) an obvious, named home instead of an ad-hoc extension of an unrelated system.

### Alternative 2: Tower System owns the balance
- **Description**: Tower System, the only MVP consumer needing affordability checks, tracks `_gold_balance` itself and reads `resources_changed` directly.
- **Pros**: No new Autoload; balance lives next to its only consumer.
- **Cons**: Tower System is scene-instanced, not Autoload — it does not persist independently of the mission scene and is not the natural EventBus subscriber for a Resource-Economy-sourced value with no direct relationship to tower placement logic otherwise. Any future consumer (Mission HUD's live counter, a future Crafting-adjacent system) would have to read *through* Tower System, an architecturally backwards dependency (Tower becoming a secondary source of economy data).
- **Rejection Reason**: Ownership should sit with a system whose job is tracking mission-scoped state generically, not with an arbitrary first consumer.

### Alternative 3: EventBus broadcast + local cache (no direct-call read API)
- **Description**: `MissionEconomy` (or whichever owner) re-emits a `gold_balance_changed(new_balance: int)` signal on every delta; Tower System and Mission HUD each cache the last-seen value locally instead of querying live.
- **Pros**: Fully EventBus-only — no new direct-call exception needed.
- **Cons**: Introduces a one-frame-stale read risk at exactly the moment (placement confirmation, ADR-0008 Gate 2) that requires a synchronous, authoritative check. ADR-0008's existing pseudocode already assumes a direct, non-cached call (`ResourceSystem.can_afford(cost)`) — retrofitting a cache-based read would require revising an already-Accepted ADR for no correctness benefit.
- **Rejection Reason**: The direct-call exception is already the established pattern for exactly this kind of per-attempt, latency-sensitive query (Grid, GameDataRegistry); introducing staleness here would be a regression, not a simplification.

## Consequences

### Positive
- Story 013 (Gold Track & Scout Starting Grant) is now fully unblocked — Epic 03's last architectural gap is closed.
- Ownership is unambiguous and narrowly scoped: one Autoload, one `int`, one write path (EventBus subscription), one read API (direct call).
- No `SaveRestorer` boilerplate needed — the ephemeral, no-persistence design is structurally simple and matches `save-persistence.md`'s own precedent for other mission-runtime scalars.
- Sets a reusable pattern: any future mission-scoped scalar (e.g. a running kill counter, a materials-spent tally) has an obvious home in `MissionEconomy` rather than forcing a choice between "cram it into Wave Manager" or "invent a new Autoload every time."

### Negative
- An 8th Autoload adds one more entry to the boot-order invariant that must be kept in sync (ADR-0002 revision required).
- `MissionEconomy` is, for now, a very thin Autoload (one field, four methods) — some may see this as premature infrastructure for a single `int`. Accepted: the alternative (bolting it onto Wave Manager or Tower) creates worse long-term coupling for a trivial short-term saving.

### Risks
- **Risk**: A future system emits `resources_changed` with an unexpectedly large negative delta, driving `_gold_balance` negative. **Mitigation**: `can_afford()` remains correct at any value (a negative balance simply fails every affordability check), but a debug-build assertion (`assert(_gold_balance >= 0)`) is recommended in `_on_resources_changed` to catch a miscalculated Resource Economy formula early rather than silently allowing an inconsistent economy state.
- **Risk**: `MissionEconomy._ready()` subscribes to `resources_changed` before `ResourceEconomy` (a scene-instanced node, per ADR-0017) exists in the scene tree; if `ResourceEconomy` emits before `MissionEconomy` has connected, the first delta could be missed. **Mitigation**: this is not actually possible — `MissionEconomy` is an Autoload and boots before any scene (including the mission scene containing `ResourceEconomy`) loads, so its subscription is always active before `ResourceEconomy._ready()` runs. No mitigation code needed; documented here to make the invariant explicit for implementers.
- **Risk**: ADR-0008's placement-gate pseudocode still says `ResourceSystem.can_afford(cost)` (a placeholder name), not `MissionEconomy.can_afford(cost)`. **Mitigation**: ADR-0008 should be amended (small, non-behavioral edit) to reference `MissionEconomy` by name once this ADR is Accepted, so an implementer reading ADR-0008 alone doesn't go looking for a system called `ResourceSystem` that doesn't exist.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| resource-economy.md | Rule 7: gold emitted via `resources_changed`, separate from materials | `MissionEconomy` is the sole consumer that accumulates these deltas into a balance; Resource Economy's emission contract is unchanged |
| resource-economy.md | Rule 8: flat `scout_starting_gold` grant on SCOUT entry | `MissionEconomy`'s `mission_launched` reset (to 0) always precedes this grant, so it always lands on a clean balance |
| resource-economy.md | Open Question: "Who owns the runtime gold balance?" | Resolved — `MissionEconomy`, a new dedicated Autoload, per this ADR |
| tower.md / ADR-0008 | Gate 2: `ResourceSystem.can_afford(placement_cost)` placeholder | Resolved — `MissionEconomy.can_afford(cost: int) -> bool` is the concrete API; ADR-0008 should be amended to reference it by name |
| wave-manager.md | "Scout Phase Economy (TODO)" — starting resource pool delivery mechanism | Resolved by cross-reference: the mechanism is Resource Economy's existing Rule 8 grant; this ADR supplies the missing balance-tracking half |

## Performance Implications
- **CPU**: Negligible. Mutation only on discrete `resources_changed` events (per-kill, per-spend — not per-frame); reads are O(1) field accesses called at most once per tower-placement attempt and per HUD refresh tick.
- **Memory**: One `int` field. Negligible.
- **Load Time**: None — Autoload initializes with `_gold_balance = 0`, no boot-time data loading.
- **Network**: Not applicable (single-player).

## Migration Plan
Greenfield — no existing gold-tracking code to migrate. Three prerequisite changes:

1. **Update ADR-0002** to add `MissionEconomy` at boot position 8, after `WaveManager`.
2. **Update `docs/registry/architecture.yaml`**'s `autoload_boot_order` entry to reflect position 8.
3. **Amend ADR-0008** to replace its `ResourceSystem.can_afford(cost)` placeholder with `MissionEconomy.can_afford(cost)` (non-behavioral, naming-only edit).

## Validation Criteria
- `MissionEconomy.get_gold_balance()` returns 0 immediately after `mission_launched` fires, even mid-session (a second mission in the same run resets cleanly).
- Emitting `resources_changed(150, "mission_start_grant")` followed by `resources_changed(-30, "tower_placement")` leaves `get_gold_balance() == 120`.
- `can_afford(cost)` returns `true` when `cost == _gold_balance` exactly (boundary case, not strictly less-than).
- A negative-delta `resources_changed` that would drive the balance below 0 is applied as-is (no silent clamping) — `can_afford()` correctly returns `false` for any positive cost afterward.
- Integration test: `MissionEconomy`'s subscription is active (verified by successfully receiving a `resources_changed` event) before any mission scene's `_ready()` has run, confirming Autoload boot-order guarantees the no-missed-first-delta invariant.

## Related Decisions
- ADR-0001 — EventBus architecture (`resources_changed`, `mission_launched` signal contracts)
- ADR-0002 — Scene and Autoload structure (boot order revised by this ADR — `MissionEconomy` at position 8)
- ADR-0003 — Save file format (precedent for what mission-runtime state is *not* persisted)
- ADR-0005 — Grid system data model (precedent for a documented direct-call read exception)
- ADR-0008 — Tower placement gate (`ResourceSystem.can_afford()` placeholder resolved by this ADR — amendment required)
- ADR-0009 — Resource data model (precedent for a direct-call lookup Autoload, `GameDataRegistry`)
- ADR-0012 — Wave Manager FSM (precedent for a mission-scoped Autoload reset via `mission_launched`, no persistence)
- ADR-0017 — Resource Economy drop resolution (sole emitter of the `resources_changed` gold deltas this ADR consumes)
- `design/gdd/resource-economy.md` — source GDD; Open Question this ADR resolves
- `design/gdd/tower.md` — placement cost affordability check consumer
