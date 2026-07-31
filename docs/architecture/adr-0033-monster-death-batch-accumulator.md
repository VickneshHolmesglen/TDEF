# ADR-0033: Monster Death Batch Accumulator — MonsterManager Buffers and Owns Emission

## Status
Proposed

## Date
2026-07-31

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core (gameplay signal/state architecture — no engine-rendering/physics/audio API surface) |
| **Knowledge Risk** | LOW — no new engine API introduced; uses only `Array`, `Dictionary`, and `Signal.emit()` patterns already used elsewhere in `monster_manager.gd` (`_pending_absorbed`, `_pending_damage`) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` (general knowledge-gap context only — no domain-specific module doc applies) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None — `godot-gdscript-specialist` review (2026-07-31) confirmed no blocking issues: `Array[MonsterDiedEvent]` is a single-level typed array of a concrete class (not the nested-generic `Dictionary[StringName, Array[int]]` case that's broken elsewhere in this codebase), and every `MonsterDiedEvent` field is a value copy taken at Pass 1 time (not an `entity` reference) — deferring emission to Pass 4 carries no `queue_free()`/signal-ordering risk. Noted that `_pending_deaths: Array[MonsterDiedEvent]` actually mirrors `_pending_damage: Array[MonsterDamageTaken]`'s existing pattern (append/clear, single typed array) more closely than `_pending_absorbed` (a `Dictionary`, needed there only because absorbed damage sums per-entity across multiple hits) — both precedents already exist in this file. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0006 (Monster Movement — Accepted, establishes the 4-pass `_physics_process` architecture and the `_pending_absorbed` buffer-then-flush precedent this decision mirrors exactly) |
| **Enables** | Closes TD-monster-005 and TD-econ-006 (`docs/tech-debt-register.md`) — the emitter-side mutual-exclusivity guarantee ADR-0017 (Resource Economy) already assumes and relies on |
| **Blocks** | None — no story is currently blocked pending this; it closes tracked tech debt, not a blocking prerequisite |
| **Ordering Note** | None |

## Context

### Problem Statement

`event_bus.gd`/`event-bus.md` document `monsters_died_batch` as a real, load-bearing signal: "Emitted by Wave Manager in place of individual `monster_died` events when more than `eventbus_batch_threshold` (20) deaths would otherwise fire in one physics frame." Three real subscribers (`WaveManager`, `MissionHUD`, `ResourceEconomy`) have working, tested handlers for it. But no code anywhere in the codebase ever emits it — `MonsterManager._emit_death()` unconditionally fires `monster_died` per-kill, with no per-frame count tracking, and `WaveManager` (the system the doc comments say "owns the accumulator") only decrements `_enemies_alive` on receipt; it contains no accumulation or re-emission logic. This was discovered while investigating TD-econ-006, whose own recommended fix (a mutual-exclusivity regression test) would have been vacuous given this gap — logged as TD-monster-005.

Investigating further surfaced a deeper problem this ADR must also resolve: **two GDDs make contradictory, individually-tested claims about the same signal pair.**

- `event-bus.md` (Formula 2, line 376: `Batching required threshold | Formula 2 | F_per_frame > 20`; AC-10) requires true mutual exclusivity — at 25 simultaneous deaths, `monster_died` must fire **zero** times and `monsters_died_batch` exactly once.
- `monster.md` (Rule, line 162; AC, line 891) requires `monster_died` to **always** fire per-kill, unconditionally, with Monster System never deferring or batching under any circumstance.

`ADR-0017` (Resource Economy Drop Resolution, Accepted) already depends on the `event-bus.md` version of this contract being true — its stateless-calculator design explicitly "resolves each batch entry identically to an individual dispatch" and its own Risk section states a violation of mutual exclusivity is "a real-money-adjacent bug class" it cannot itself detect or prevent.

### Constraints

- Must not require `ResourceEconomy`, `WaveManager`, or `MissionHUD` to change their existing subscriber-side logic — all three already correctly implement `_on_monsters_died_batch()` against the documented `Array[MonsterDiedEvent]` payload shape (confirmed via `wave_manager.gd:1084`, `mission_hud.gd:365`, `resource_economy.gd:111`); this decision is emitter-side only.
- Must preserve `boss_died`'s existing immediate, unbatched emission (`_emit_death()` line 128) — boss kills are rare and not part of this batching problem.
- Must not introduce a new EventBus signal or indirection hop where the existing 2-signal contract already suffices.

### Requirements

- `monster_died` and `monsters_died_batch` must be genuinely mutually exclusive per frame — never both fire for kills resolved in the same physics frame.
- The threshold must match `event-bus.md`'s Formula 2 exactly: `F_per_frame > 20` (21 or more deaths in one frame triggers the batch path; 20 or fewer emit individually).
- Must mirror this project's own established buffer-then-flush precedent (`_pending_absorbed`, ADR-0006) rather than inventing a new pattern.

## Decision

**`MonsterManager` buffers all death payloads during Pass 1 (damage drain) instead of emitting `monster_died` immediately, and decides — once, at end-of-frame — whether to emit one `monsters_died_batch` or individual `monster_died` events for that frame's kills. `MonsterManager` is the sole emitter of both signals; it does not hand off to `WaveManager` to emit.**

This corrects the "Wave Manager owns the accumulator" phrasing in `monster.md` and `event-bus.md` as inaccurate — `WaveManager` structurally cannot decide whether to suppress individual events after the fact, since by the time it would receive them individually, the mutual-exclusivity guarantee is already broken. Only the system that first observes the full per-frame kill list (`MonsterManager`, via its own `_emit_death()` call sites) can enforce this correctly. `WaveManager` remains exactly what it already is today: a subscriber to both signals (`wave_manager.gd:215`, `221`), unchanged.

### Implementation

1. `_emit_death()` stops calling `GEventBus.monster_died.emit(ev)` directly. Instead it appends the constructed `MonsterDiedEvent` to a new `_pending_deaths: Array[MonsterDiedEvent]` buffer (mirrors `_pending_absorbed`'s existing pattern exactly). `boss_died` emission (line 128) and `entity.queue_free()` (line 140) are unaffected — both remain immediate.
2. A new flush step, added to the existing Pass 4 (Absorbed Flush — renamed or extended to "Death & Absorbed Flush," since both are frame-scoped emission buffers flushed at the same point):
   ```
   if _pending_deaths.size() > DEATH_BATCH_THRESHOLD:  # 20, matches event-bus.md Formula 2
       GEventBus.monsters_died_batch.emit(_pending_deaths)
   else:
       for death_event in _pending_deaths:
           GEventBus.monster_died.emit(death_event)
   _pending_deaths.clear()
   ```
3. `DEATH_BATCH_THRESHOLD := 20` added to `monster_manager.gd`'s existing Tuning Constants block, matching the file's own convention that these mirror the GDD's Tuning Knobs section.
4. `monsters_died_batch`'s existing shipped signal signature, `Array[MonsterDiedEvent]`, is kept as-is — `event-bus.md`'s catalogue entry currently (incorrectly) describes the payload as `count: int` only; this is stale documentation predating the real subscriber implementations, which all already expect and correctly handle the full `Array[MonsterDiedEvent]` shape. The GDD text is corrected to match the shipped signature, not the reverse — changing the signal shape now would require touching all 3 subscribers' already-tested handler code for no benefit.

### GDD Changes Required (see GDD Requirements Addressed below)

- `monster.md`: Rule (~line 162) and AC (~line 891) amended to add the threshold exception — Monster System emits `monster_died` per-kill **unless** the current frame's death count exceeds `eventbus_batch_threshold` (20), in which case it emits exactly one `monsters_died_batch` instead.
- `event-bus.md`: `monsters_died_batch`'s catalogue row (line 77) and EC-9 (line 399) corrected — "Emitted by Wave Manager" → "Emitted by Monster System"; payload description `count: int` → `Array[MonsterDiedEvent]` (matching what's actually shipped and already relied upon by all 3 subscribers).
- `docs/registry/architecture.yaml` line 494: the `resource_economy` interface entry's claim that exclusivity was "confirmed against shipped Wave Manager handler code" is corrected — no such code existed before this ADR; the guarantee is now real, owned by `MonsterManager`, not `WaveManager`.

### Architecture Diagram

```
MonsterManager._physics_process(delta):
  Pass 1 (damage drain)
    for each entity taking lethal damage:
      boss_died.emit(...) if tier==2       [unchanged, immediate]
      _pending_deaths.append(MonsterDiedEvent)  [NEW — no longer emits monster_died here]
      entity.queue_free()                  [unchanged, immediate]
  Pass 2 (BOSS logic)                       [unchanged]
  Pass 3 (movement)                         [unchanged]
  Pass 4 (Death & Absorbed Flush)           [extended]
    if _pending_deaths.size() > 20:
      monsters_died_batch.emit(_pending_deaths)   [NEW]
    else:
      for death in _pending_deaths: monster_died.emit(death)  [moved from Pass 1]
    _pending_deaths.clear()
    [existing _pending_absorbed flush, unchanged]

WaveManager / MissionHUD / ResourceEconomy:
  subscribe to BOTH monster_died and monsters_died_batch  [unchanged — already correct]
  exactly ONE of the two ever fires per frame now (previously: only monster_died could fire, ever)
```

### Key Interfaces

```gdscript
# MonsterManager (scene-instanced, unchanged class boundary)
const DEATH_BATCH_THRESHOLD: int = 20  # matches event-bus.md Formula 2's F_per_frame > 20

var _pending_deaths: Array[MonsterDiedEvent] = []  # frame-scoped, flushed every physics frame

# _emit_death() no longer emits monster_died directly — buffers only.
# New: _flush_deaths() (or extended _flush_absorbed(), naming TBD at implementation) —
# called once per _physics_process, decides individual vs. batch emission.
```

## Alternatives Considered

### Alternative 1: WaveManager buffers, re-derives batch

- **Description**: Keep `MonsterManager` emitting `monster_died` immediately as today. `WaveManager` buffers received individual events within the frame and additionally emits `monsters_died_batch` if the frame count crosses threshold.
- **Pros**: Matches the literal "Wave Manager owns the accumulator" wording without correcting it.
- **Cons**: Structurally cannot achieve mutual exclusivity — by the time `WaveManager` could decide to batch, the individual `monster_died` events have already been dispatched to `ResourceEconomy`/`Constellation`/`MissionHUD`. A subsequent `monsters_died_batch` for the same kills would double-process them (double-award materials/gold in `ResourceEconomy`'s case) unless every subscriber added its own retroactive-suppression logic.
- **Rejection Reason**: Directly reintroduces the double-award risk `ADR-0017`/`TD-econ-006` exist to prevent. Rejected during collaborative design (see this ADR's own drafting record).

### Alternative 2: Batch is additive, not exclusive; ResourceEconomy deduplicates

- **Description**: Keep `monster_died` always-synchronous-per-kill (satisfies `monster.md`'s AC literally, unmodified). `monsters_died_batch` becomes a supplementary aggregate for consumers that want a bulk summary (e.g., a Mission HUD "12 monsters died" toast), not a replacement. `ResourceEconomy` stops relying on `monsters_died_batch` for reward calculation — removes or no-ops that handler.
- **Pros**: Requires no change to `monster.md`'s existing AC.
- **Cons**: Contradicts `event-bus.md`'s own AC-10 (25 simultaneous deaths → `monster_died` fires exactly 0 times) and Formula 2's stated performance rationale (the batching exists specifically to stay under the per-firing subscriber budget at high kill counts — an *additive* batch signal doesn't reduce `monster_died`'s firing count at all, so it doesn't solve the performance problem Formula 2/EC-9 describe). Also requires editing `ResourceEconomy`'s already-tested, Accepted-ADR-governed handler code for no correctness gain.
- **Rejection Reason**: Doesn't actually close the performance gap the mechanism exists to solve, and `event-bus.md`'s Formula 2/EC-9 are more specific and load-bearing (cited by 4 places per that document's own history) than `monster.md`'s general "always synchronous" phrasing, which reads as having been written before the batching exception was fully reasoned through. Rejected during collaborative design.

## Consequences

### Positive
- Closes TD-monster-005 and TD-econ-006 — the mutual-exclusivity guarantee `ADR-0017` already depends on becomes real and testable instead of assumed.
- `event-bus.md`'s Formula 2/EC-9 performance rationale (staying under per-firing subscriber budget at high kill counts) is finally actually implemented, not just specified.
- Mirrors an already-Accepted, already-tested pattern (`_pending_absorbed`) rather than inventing a new one — low implementation risk.
- 3 subscribers' existing `_on_monsters_died_batch()` handlers, written and tested against a payload that could never arrive, finally become reachable and exercised by real gameplay.

### Negative
- `monster_died`/`monsters_died_batch` now fire at the end of Pass 4 instead of synchronously within Pass 1 — a same-frame, sub-physics-tick timing shift. No system currently depends on `monster_died` firing before Pass 2/3 run (verified: Pass 3's `active_monsters` filtering uses local `lifecycle_state == DEAD` checks, not the signal), but this is a real behavioral change worth flagging in the story's own QA pass.
- Two GDDs (`monster.md`, `event-bus.md`) require correction as part of this ADR, not just new code — slightly larger scope than a pure implementation story.

### Risks
- **Risk**: A future change to `_emit_death()`'s call sites (e.g., a new death-trigger path added elsewhere in `MonsterManager`) could bypass the `_pending_deaths` buffer and re-introduce direct `monster_died` emission, silently breaking exclusivity again.
  - **Mitigation**: The implementing story should add a regression test asserting `monster_died` is never emitted synchronously from within `_emit_death()` itself (only ever from the Pass 4 flush) — this is exactly the emitter-side test TD-econ-006 originally asked for, now meaningful.
- **Risk**: `DEATH_BATCH_THRESHOLD = 20` is a hardcoded constant mirrored from `event-bus.md`'s `eventbus_batch_threshold` — if that GDD value is ever tuned, this constant must be updated in lockstep (no single source of truth).
  - **Mitigation**: Not resolved here — a general concern with all of `monster_manager.gd`'s Tuning Constants block (`MAX_ACTIVE_MONSTERS`, `BOSS_SCAN_INTERVAL_FRAMES`, etc. have the identical risk today, unrelated to this ADR). Out of scope to fix project-wide here.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| `event-bus.md` | Formula 2 / EC-9: `monster_died` batching required above `F_per_frame > 20` | Implements the threshold exactly as specified; corrects the catalogue's "Emitted by Wave Manager" and `count: int` payload claims to match the real emitter and shipped signal shape |
| `event-bus.md` | AC-10: 25 simultaneous deaths → `monster_died` fires 0 times, `monsters_died_batch` fires 1 time | Directly implementable against this design for the first time — was previously untestable since no code paths existed to produce this outcome |
| `monster.md` | Rule (~162) / AC (~891): Monster System's `monster_died` emission contract | Amended to add the documented threshold exception this ADR requires, resolving the cross-GDD contradiction found during this ADR's drafting |
| `resource-economy.md` / ADR-0017 | Core Rule 1 (stateless calculator) / Rule 9 (batch resolution independence) | The mutual-exclusivity guarantee this design already assumes becomes real; no change needed to `ResourceEconomy` itself |

## Performance Implications
- **CPU**: Negligible — one additional `Array.append()` per kill (replacing what was previously an immediate `.emit()` call) and one small loop at end-of-frame. At high kill counts (the exact scenario this exists for), this *reduces* total signal-dispatch overhead versus today's unconditional per-kill emission, matching Formula 2's own stated rationale.
- **Memory**: `_pending_deaths` is cleared every frame (same lifecycle as the existing `_pending_absorbed`) — no growth, no leak risk beyond what the existing pattern already carries.
- **Load Time**: None.
- **Network**: N/A — no networking exists in this project.

## Migration Plan

No save-data or persisted-state migration needed — this is pure runtime signal-dispatch behavior, not data. Implementation is a single story touching `monster_manager.gd`, `monster.md`, and `event-bus.md` together (the code and its 2 governing GDDs should land in the same story to avoid a window where they disagree again).

## Validation Criteria

- A test forcing 21+ simultaneous deaths in one physics frame asserts `monster_died` fires 0 times and `monsters_died_batch` fires exactly once with all 21+ payloads present (directly implements `event-bus.md`'s AC-10, previously untestable).
- A test forcing 20 or fewer deaths in one frame asserts `monster_died` fires once per death and `monsters_died_batch` never fires (regression guard for the existing, common-case behavior).
- The new emitter-side exclusivity test TD-econ-006 originally asked for: assert no code path in `MonsterManager` can emit `monster_died` synchronously from `_emit_death()` itself.
- Existing `ResourceEconomy`/`WaveManager`/`MissionHUD` batch-handling tests (already written and passing against a payload that could never previously arrive) continue passing unmodified — proves the shipped subscriber code was already correct.

## Related Decisions
- ADR-0006 (Monster Movement) — establishes the 4-pass architecture and `_pending_absorbed` buffer-then-flush precedent this decision mirrors
- ADR-0017 (Resource Economy Drop Resolution) — the Accepted decision whose stateless-calculator design already assumes the guarantee this ADR makes real
- TD-monster-005, TD-econ-006 (`docs/tech-debt-register.md`) — the tracked gaps this ADR closes
