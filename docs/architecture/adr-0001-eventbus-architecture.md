# ADR-0001: EventBus Architecture — Framework-First Event-Driven Communication

## Status
Accepted

## Date
2026-05-15

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core / GDScript Scripting |
| **Knowledge Risk** | LOW — GDScript signal system and `call_deferred()` are in LLM training data and unchanged through Godot 4.6 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None — signal declaration, `emit_signal()`, `call_deferred()`, and Autoload lifecycle are all pre-4.4 |
| **Verification Required** | Verify `signal.connect(callable)` typed-signal syntax works for all 70 declared signals at startup. Verify `call_deferred("emit_signal", ...)` fires on the correct frame boundary when called from `_physics_process`. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None — this is the root architectural decision |
| **Enables** | ADR-0002 (Scene/Autoload structure); ADR-0003 (Save format — subscribes to EventBus triggers); ADR-0004 (Pathfinding — dispatches `templates_ready`); ADR-0005 (Grid); ADR-0006 through ADR-0009 (all Core layer ADRs) |
| **Blocks** | All Foundation + Core implementation stories. No cross-system story can be implemented before EventBus signals are declared and the Autoload is in place. |
| **Ordering Note** | This ADR must be Accepted before any other ADR is written. Changing any event name or payload shape after dependent ADRs are written is a breaking change to every subscriber. The 70-event catalogue is a frozen public API once this ADR is Accepted. |

## Context

### Problem Statement
Sanctuary Defenders has 25 systems that must share game state and react to each other's outcomes (hero equipment affecting tower stats, Tarot altering wave composition, creature happiness affecting material quality) without creating brittle direct dependencies. All 9 MVP GDDs were authored assuming a central EventBus Autoload, and game-concept.md Core Rule 10 mandates it. This ADR formally records that decision, its implementation constraints, and its consequences.

### Constraints
- All 9 MVP GDDs already designed against this pattern — changing the communication mechanism would require re-reviewing every GDD.
- Godot's `Signal` system is natively typed, C++ backed, and zero-overhead when no subscribers are connected.
- A single developer workflow: the event catalogue must be comprehensible as a list, not a graph of distributed connections.
- 60 FPS target on PC: all EventBus processing combined must fit within 1.667 ms/frame (10% of 16.67 ms frame budget).

### Requirements
- Any system must be able to subscribe to any event without requiring a direct reference to the publishing system.
- Payload data must be type-safe — no untyped Dictionaries.
- Physics-context subscribers must not cause scene-tree mutations mid-physics-step.
- Event chains must not create unbounded recursive dispatch.
- High-frequency events (40+ firings/frame) must not individually saturate the frame budget.

## Decision

A single `EventBus` GDScript Autoload declares all 70 cross-system signals. Systems connect to signals in `_ready()` and disconnect in `_exit_tree()`. No system holds a direct runtime Node reference to any other system. The EventBus owns no game state — it is a pure dispatcher.

### Five Implementation Rules

**Rule 1 — Synchronous dispatch is the default.**
`EventBus.emit_signal("event_name", payload)` is synchronous: all subscribers execute inline before the emitter continues. Use this for all non-physics events.

**Rule 2 — Physics callers and Level-1 cascade emitters use deferred dispatch.**
Any `emit_signal()` originating inside `_physics_process`, `area_body_entered`, or similar physics callbacks must use `call_deferred("emit_signal", "event_name", payload)`. Any subscriber that emits a further event (Level-1 cascade) must also emit it deferred to avoid cascade cost stacking in a single frame.

**Rule 3 — Payload convention: typed parameters for 1–4 fields; Resource subclass for 5+ fields.**
Signal parameters must be typed GDScript types. Events with 5 or more data fields must package their payload into a custom `Resource` subclass (e.g., `MonsterDiedEvent`, `HeroAutoAttackEvent`). Untyped `Dictionary` payloads are prohibited.

**Rule 4 — Cascade depth cap: maximum 2 levels.**
A subscriber that emits a further event is at cascade depth 1. A subscriber of that event may not emit a further event (depth 2 is the limit). Any attempt to emit at depth 3 is a design error — caught in design review, not at runtime.

**Rule 5 — Batch at ≥ 20 firings/frame.**
When a single event type fires more than 20 times in one frame, the emitting system switches to a single deferred `{event_name}_batch` event with an `Array[Resource]` payload. The Wave Manager owns the `monster_died` batch accumulator; the EventBus remains a pure dispatcher.

### Architecture Diagram

```
                    ┌─────────────────────┐
                    │     EventBus        │
                    │  (Autoload — 1st)   │
                    │                     │
                    │  signal A(...)      │
                    │  signal B(...)      │
                    │  ...  70 signals    │
                    └──────────┬──────────┘
                               │ emit / subscribe
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
 ┌──────▼──────┐       ┌───────▼───────┐      ┌──────▼──────┐
 │   Hero      │       │ Damage &      │      │   Tower     │
 │  System     │       │ Status        │      │  System     │
 │             │       │               │      │             │
 │ emits:      │       │ subscribes:   │      │ emits:      │
 │ hero_auto_  │       │ hero_auto_    │      │ tower_      │
 │ attacked    │       │ attacked,     │      │ attacked    │
 │             │       │ tower_attacked│      │             │
 └─────────────┘       └───────────────┘      └─────────────┘

    No direct references between systems — EventBus is the only channel.
```

### Key Interfaces

```gdscript
# EventBus.gd — Autoload (representative subset; full catalogue in event-bus.md)

# 1–4 field events: typed parameters directly on signal
signal monster_breached(entity_id: int, monster_id: StringName, tier: int)
signal hero_died()
signal wave_started(wave_number: int, total_waves: int, wave_difficulty: float)

# 5+ field events: Resource subclass payload (single typed param)
signal monster_died(payload: MonsterDiedEvent)           # 8 fields
signal hero_auto_attacked(payload: HeroAutoAttackEvent)  # 6 fields
signal monster_spawned(payload: MonsterSpawnedEvent)     # 5 fields

# Subscribing (in _ready()):
EventBus.monster_died.connect(_on_monster_died)

# Disconnecting (in _exit_tree() — MANDATORY):
EventBus.monster_died.disconnect(_on_monster_died)

# Synchronous dispatch (non-physics callers):
EventBus.wave_started.emit(wave_number, total_waves, difficulty)

# Deferred dispatch (physics callers and Level-1 cascade emitters):
EventBus.monster_damage_taken.emit.call_deferred(payload)
```

### Performance Budget

| Metric | Limit | Source |
|--------|-------|--------|
| Total EventBus processing/frame | 1.667 ms | 10% of 16.67 ms @ 60 FPS |
| Per-event-type budget (8 concurrent) | ~0.208 ms | EventBus GDD Formula 1 |
| Batch threshold | >20 firings/frame | EventBus GDD Formula 2 |
| Max cascade depth | 2 levels | EventBus GDD Core Rule 5 |

## Alternatives Considered

### Alternative A: Direct signal connections (node-to-node)
- **Description**: Systems connect directly to each other's signals. Hero emits `attacked`; Damage & Status connects directly to Hero.
- **Pros**: Simpler per-connection; no Autoload; Godot's native pattern for same-scene nodes.
- **Cons**: Creates direct runtime Node references between systems; cross-context connections (mission systems to Sanctuary systems) require scene-spanning references; the game's cross-system synergy design requires any system to react to any other without advance coupling.
- **Rejection Reason**: Violates the requirement that no system holds a direct reference to another. The combinatorial synergy depth (hero equipment → tower stats, Tarot → wave composition) would produce an unmanageable dependency graph.

### Alternative B: Message queue with object pooling
- **Description**: Systems post typed message objects to a central queue. A scheduler processes the queue each frame.
- **Pros**: Full control over dispatch timing; natural batching; event prioritisation.
- **Cons**: Requires building queue, pool, and scheduler not provided by Godot. Adds per-message allocation overhead. Delays all event processing by up to one frame, changing every GDD's timing assumptions.
- **Rejection Reason**: Over-engineered for this project's scale. Godot's signal system provides the needed functionality natively. The one-frame delay would require re-designing all GDD timing assumptions from scratch.

### Alternative C: EventBus as scene node (dependency injection, not Autoload)
- **Description**: EventBus is a scene-instanced node passed to systems at construction time.
- **Pros**: More testable in isolation; no global state.
- **Cons**: Every system must receive the reference at construction — substantial wiring boilerplate for 25 systems. The EventBus owns no game state (Rule 8), so the "global state" concern is minimal.
- **Rejection Reason**: Boilerplate cost outweighs testing benefit at this project's scale. Testing isolation for individual systems is achieved by not using EventBus for internal system events.

## Consequences

### Positive
- No system has a direct Node reference to another — systems develop, test, and modify in isolation.
- New cross-system synergies add a subscriber to an existing event without touching the emitting system.
- The 70-event catalogue documents all cross-system communication in one file.
- Typed signals enforce payload types at connection time — wrong-type errors caught immediately by GDScript.

### Negative
- The event catalogue is a central point of contract. Any event rename or payload schema change is a breaking change for all subscribers — coordinated updates required across all GDDs and all implementing systems.
- Debugging cross-system behaviour requires tracing through EventBus signal flow. Signal breakpoints in Godot's debugger mitigate this.
- The cascade depth cap (2 levels) constrains future design: interactions requiring 3+ event hops must be redesigned with intermediate state holders.

### Risks
- **Risk**: A subscriber retains a connection after its node is freed → "call to freed object" crash. **Mitigation**: Mandatory `_exit_tree()` disconnect enforced in code review. EventBus GDD EC-2 documents the exact failure mode.
- **Risk**: A Level-1 cascade is implemented synchronously by mistake, blowing the frame budget at peak wave volume. **Mitigation**: GDD EC-8 documents the failure mode. Design review of any Level-1 emitter must verify deferred usage. The control manifest lists synchronous Level-1 cascade as Forbidden.
- **Risk**: The 70-event catalogue grows unbounded as features are added. **Mitigation**: Core Rule 9 (only cross-system events in catalogue) limits growth. Internal system events are not registered.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| event-bus.md | Core Rule 1: no direct cross-system references | Decision section mandates EventBus as the only channel |
| event-bus.md | Core Rule 3: synchronous default; deferred for physics | Rule 2 defines the dispatch policy |
| event-bus.md | Core Rule 4: typed params ≤4 fields; Resource ≥5 | Rule 3 defines the payload convention |
| event-bus.md | Core Rule 5: cascade depth ≤ 2 | Rule 4 sets the cap |
| event-bus.md | Core Rule 6: mandatory `_exit_tree()` disconnect | Recorded in Key Interfaces and Consequences |
| event-bus.md | Core Rule 7: EventBus first Autoload | Recorded in ADR Dependencies; enforced by ADR-0002 |
| event-bus.md | Core Rule 8: EventBus is stateless | Decision section states this explicitly |
| event-bus.md | Formula 1–3: performance budget 1.667 ms/frame | Performance Budget table; Rule 5 (batch at ≥20) |
| event-bus.md | EC-9: monster_died batching at >20/frame | Rule 5; Wave Manager owns batch accumulator |
| game-concept.md | Core Rule 10: all 9 systems communicate via central event bus | This ADR is the formal record of that rule |
| All 9 MVP GDDs | Cross-system communication tables assume EventBus signals | This ADR is the contract those tables reference |

**Technical Requirements covered**: TR-eb-001, TR-eb-002, TR-eb-003, TR-eb-004, TR-eb-005, TR-eb-006, TR-gc-001

## Performance Implications
- **CPU**: Godot signal dispatch is C++ backed — subscriber call overhead ~0.001–0.005 ms per subscriber with no heap allocation. 70 signals × ~3 subscribers = low baseline. High-frequency events (monster_died at 40×/frame) require batching to stay within budget.
- **Memory**: 70 signal objects at boot; Resource payload subclasses allocated per event firing for 5+ field events. Instance pooling is a post-MVP optimisation if profiling shows allocation pressure.
- **Load Time**: Negligible — 70 signal declarations in one GDScript file.
- **Network**: Not applicable (single-player only).

## Migration Plan
No existing code to migrate — greenfield project. The EventBus Autoload is the first implementation deliverable. All other systems implement against it after it exists.

## Validation Criteria
- [ ] All 70 signals declared in `EventBus.gd` compile without type errors.
- [ ] `signal.connect(callable)` typed-connection syntax works for all signal shapes (0-param, N typed-param, Resource-param).
- [ ] `call_deferred` deferred dispatch confirmed to fire on the correct frame boundary when called from `_physics_process`.
- [ ] A subscriber freed mid-wave produces a runtime error when `_exit_tree()` disconnect is omitted — verified by intentional test case.
- [ ] EventBus processing under peak load (40 monster_died + 10 tower_attacked/frame) fits within 1.667 ms/frame on minimum-spec PC hardware.

## Related Decisions
- ADR-0002 — Scene and Autoload structure (enforces Autoload #1 boot position)
- ADR-0007 — Damage pipeline (D&S deferred dispatch is a direct consequence of Rule 2)
- `design/gdd/event-bus.md` — canonical source for the 70-event catalogue and performance formulas
