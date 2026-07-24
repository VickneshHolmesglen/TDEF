# ADR-0014: Pause System

## Status

Accepted

## Date

2026-07-08

## Last Verified

2026-07-08

## Decision Makers

User (mechanism + Pause Menu scope decisions), lead-programmer (implementation)

## Summary

No pause mechanism of any kind exists anywhere in the codebase (`TD-pause-001`), despite
`design/accessibility-requirements.md` committing to "pause anywhere, including mid-wave,
with no penalty" as a Standard-tier feature. This ADR adopts Godot's engine-native
`SceneTree.paused` as the single source of truth, with `PROCESS_MODE_ALWAYS` on the Pause
Menu only, over a custom EventBus-driven pause flag threaded through every timer-owning
system.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core / Input |
| **Knowledge Risk** | LOW — `SceneTree.paused`, `Node.process_mode`, and `SceneTree.create_timer()`'s `process_always` parameter are all stable since Godot 4.0 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None — confirmed via live behavior of existing Timer nodes (all use default `process_mode = PROCESS_MODE_INHERIT`, which already pauses correctly; no code change needed there) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (EventBus — `game_paused`/`game_unpaused` are new catalogue signals); ADR-0012 (Wave Manager FSM — its own Negative/Risk section already flagged that `create_timer()` timers are not pausable by default; this ADR resolves that flagged risk) |
| **Enables** | Pause Menu implementation; closes `TD-pause-001` |
| **Blocks** | None |
| **Ordering Note** | None |

## Context

### Problem Statement

`design/ux/pause-menu.md` assumes a pause mechanism exists; its own Open Questions
correctly flagged that it doesn't. A full search of `src/`, `event-bus.md`, and
`docs/architecture/adr-0002-scene-autoload-structure.md` found zero references to
`game_paused`, `game_unpaused`, or `get_tree().paused` anywhere. Nothing has been built
toward the accessibility commitment yet.

### Current State

Every timer-driven system (Wave Manager's 5 phase Timer nodes, its spawn coroutine's
per-entry `pre_delay` wait, Hero auto-attack) runs unconditionally. There is no way for a
player to halt gameplay.

### Constraints

- Must not require per-system code changes to Wave Manager, Monster System, or Hero for
  the common case — Godot's own pause propagation should do that work.
- Must remain functional identically across every mission phase, including mid-boss-fight
  (`design/accessibility-requirements.md` Motor Accessibility commitment).
- Neither `SanctuaryScene.tscn` nor a Main Menu scene/system exists yet — Quit routing is
  necessarily limited to what `GSceneManager` can actually do today.

### Requirements

- Pause input (Esc / gamepad Start) freezes gameplay within 1 frame from any mission
  phase.
- Resume (same input, or a Resume button) restores gameplay within 1 frame, no state
  loss, no time drift.
- The Pause Menu itself must remain interactive while the tree is paused.
- Scheduled mid-wave spawns must not fire while paused.

## Decision

### Chosen Approach: Engine-native `SceneTree.paused`

`get_tree().paused = true` is the single source of truth for "the game is paused."
Every existing Timer node (Wave Manager's 5 phase timers) already defaults to
`process_mode = PROCESS_MODE_INHERIT`, which already halts correctly under
`SceneTree.paused` with zero code changes — verified by grep: no `process_mode` override
exists anywhere in `src/`.

The **Pause Menu** (`src/gameplay/ui/pause_menu/`) is a `CanvasLayer` with
`process_mode = PROCESS_MODE_ALWAYS`, so it keeps receiving input and rendering while the
tree is paused. It owns the toggle: on the `pause` input action, it flips
`get_tree().paused` and its own `visible` state together, and emits
`GEventBus.game_paused` / `GEventBus.game_unpaused`.

`game_paused`/`game_unpaused` are **informational only** — no system gates its own
`_process`/`_physics_process`/Timer logic on them. `SceneTree.paused` already does that
job natively. The two signals exist solely so non-process-loop systems (e.g. a future
Audio ducking system, analytics) can react to a pause boundary without polling
`get_tree().paused` every frame.

**Resolved gap (ADR-0012's own flagged risk)**: `SceneTree.create_timer()` defaults its
`process_always` parameter to `true`, meaning it ignores pause unless told otherwise. Wave
Manager's spawn coroutine (`wave_manager.gd:569`,
`await get_tree().create_timer(entry.pre_delay).timeout`) would otherwise keep counting
down and firing scheduled spawns while the game is "paused" — a direct violation of the
pause-anywhere commitment during the single most consequential case (mid-`WAVE_ACTIVE`).
Fixed by passing `process_always: false` at that call site. This is the one code change
this ADR requires outside the new Pause Menu itself.

### Key Interfaces

```gdscript
# src/gameplay/ui/pause_menu/pause_menu.gd
extends CanvasLayer

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = false

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"pause"):
        _toggle_pause()

func _toggle_pause() -> void:
    var new_paused: bool = not get_tree().paused
    get_tree().paused = new_paused
    visible = new_paused
    if new_paused:
        GEventBus.game_paused.emit()
    else:
        GEventBus.game_unpaused.emit()
```

```gdscript
# wave_manager.gd:569 — the one existing-code change this ADR requires
await get_tree().create_timer(entry.pre_delay, false).timeout
```

### Implementation Guidelines

- No other system needs to change. Any future timer-owning system that uses
  `create_timer()` for a duration that must respect pause must pass
  `process_always: false` explicitly — this is now a standing rule, not just a one-off fix.
- The Pause Menu is instanced once per mission scene (currently only `the_gap.tscn`).

## Alternatives Considered

### Alternative 1: Custom EventBus-driven pause flag

- **Description**: Add `game_paused`/`game_unpaused` signals; every timer-owning system
  (Wave Manager, Monster System, Hero) subscribes and manually gates its own ticking logic
  on a local `_paused: bool`.
- **Pros**: Does not depend on Godot's global pause semantics; more explicit per-system
  control.
- **Cons**: Requires touching every timer-owning system individually, with a real risk one
  is missed (this is exactly the class of bug the `create_timer` gap above already
  demonstrates, and that gap exists even under the recommended engine-native approach).
  Substantially more code for the same outcome.
- **Estimated Effort**: ~3-4x the engine-native approach.
- **Rejection Reason**: User decision — engine-native handles the common case for free;
  the one real gap it has (`create_timer`'s `process_always` default) is a single,
  now-fixed call site, not a systemic one.

## Consequences

### Positive

- Zero changes required to Wave Manager's 5 phase Timer nodes, Monster System, or Hero —
  `SceneTree.paused` propagation handles them automatically.
- Pause Menu's own `PROCESS_MODE_ALWAYS` is the only process-mode override in the entire
  codebase, keeping the pattern easy to audit.
- Closes `TD-pause-001` and the flagged risk in ADR-0012.

### Negative

- `the_gap.gd`'s one-time debug auto-launch timer
  (`await get_tree().create_timer(1.0).timeout` at `the_gap.gd:144`) still ignores pause —
  accepted as negligible: it runs once, before `mission_launched`, before any real
  gameplay state exists to protect.
- Any future `create_timer()` call for gameplay-relevant durations must remember to pass
  `process_always: false` — this is a standing discipline requirement, not
  enforced by the type system.

### Neutral

- `game_paused`/`game_unpaused` exist on EventBus but currently have zero subscribers —
  acceptable since ADR-0001 Rule 9 restricts EventBus to cross-system events, and this is
  one (future Audio/analytics systems are the anticipated subscribers).

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| A future system adds its own `create_timer()` call for a gameplay duration and forgets `process_always: false` | Medium | Medium — silent pause-anywhere violation, same class of bug as the one fixed here | Documented as a standing rule in Implementation Guidelines; `/code-review` should check any new `create_timer()` call site |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | N/A | Negligible — one CanvasLayer, no per-frame polling | N/A |
| Memory | N/A | Negligible — one small scene | N/A |
| Load Time | N/A | Negligible | N/A |

## Migration Plan

Not applicable — new system, one existing call-site fix (`wave_manager.gd:569`).

**Rollback plan**: Remove the Pause Menu scene instance from `the_gap.tscn`, revert the
`wave_manager.gd:569` change, remove the `pause` input action and the two EventBus
signals.

## Validation Criteria

- [ ] Pause input freezes gameplay (Wave Manager timers, spawn coroutine, Hero
      auto-attack) within 1 frame from SCOUT, PRE_WAVE, WAVE_ACTIVE, and INTERMISSION
- [ ] A monster with a pending `pre_delay` does not spawn while paused
- [ ] Resume restores gameplay within 1 frame with no time drift
- [ ] `game_paused`/`game_unpaused` fire exactly once per toggle

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/accessibility-requirements.md` | Motor Accessibility | "Pause anywhere, including mid-wave, with no penalty" | `SceneTree.paused` halts all default-`process_mode` nodes instantly in every mission phase; `create_timer` fix closes the one gap that would otherwise violate this mid-wave |
| `design/ux/pause-menu.md` | Pause Menu | Pause/Resume toggle reachable identically from every mission phase | Pause Menu's `PROCESS_MODE_ALWAYS` + `pause` input action satisfies this directly |

## Related

- ADR-0001: EventBus Architecture (`game_paused`/`game_unpaused` added to its catalogue)
- ADR-0012: Wave Manager FSM (this ADR resolves its own flagged `create_timer` pause risk)
- `docs/tech-debt-register.md` TD-pause-001 (closed by this ADR)
