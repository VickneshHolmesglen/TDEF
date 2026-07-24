# ADR-0032: Presentation Shell Hosting Pattern (Destroy-and-Recreate + Terminal Latch)

## Status
Accepted

## Date
2026-07-24

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | UI |
| **Knowledge Risk** | LOW — formalizes a pattern already shipped and verified in `mission_hud.gd` (Epic 09), not new post-cutoff API surface |
| **References Consulted** | `docs/engine-reference/godot/modules/ui.md`, `docs/engine-reference/godot/VERSION.md`, `src/presentation/mission_hud/mission_hud.gd` (lines 98–311, the `_terminal` pattern and Planning Cluster destroy-and-recreate precedent), `docs/architecture/adr-0011-ui-dual-focus-handling.md` |
| **Post-Cutoff APIs Used** | None new. `queue_free()`'s end-of-frame deferral behavior and `disconnect()`'s immediate-synchronous-removal semantics are unchanged since well before the LLM cutoff. |
| **Verification Required** | godot-specialist review (this session, 2026-07-24) confirmed the ordering (disconnect + input-gate BEFORE `queue_free()`) is correct and matches `mission_hud.gd`'s own existing implementation exactly — no live-MCP re-verification required beyond what Epic 09's own boot-verification already covered for the precedent code. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (EventBus — connect-in-`_ready()`/disconnect-in-`_exit_tree()` discipline), ADR-0002 (Scene/Autoload Structure — scene-instanced shell classification), ADR-0011 (UI Dual-Focus Handling — `InputModeTracker` pattern this ADR's roster rules build on) |
| **Enables** | Implementation of Sanctuary UI Epic 10 Stories 007/009/010 and Tarot Deck UI Epic 11 Story 003 — the 4 stories in those epics whose GDDs flagged "no dedicated architecture ADR yet" as a real gap |
| **Blocks** | None — both epics' stories were already written and marked `Ready` (not `Blocked`) against this pattern; this ADR formalizes what those stories already specified in prose, it does not gate their start |
| **Ordering Note** | This ADR should be read alongside both GDDs' own Core Rule 6/10 (`sanctuary-ui.md`) and Core Rule 4/5 (`tarot-deck-ui.md`) — those sections remain the authoritative behavioral spec; this ADR is the single shared architectural decision both derive from, replacing what would otherwise be two near-duplicate ADRs |

## Context

### Problem Statement

Two independent Presentation-layer GDDs — `sanctuary-ui.md` (6-entry tab strip hosting 4 gameplay rooms + a diorama overview) and `tarot-deck-ui.md` (2-entry tab strip hosting 2 gameplay screens) — arrived at an identical content-hosting and hand-off-safety mechanism through separate, multi-pass `/design-review` cycles (6 passes for Sanctuary UI, 2 for Tarot Deck UI). Both GDDs' own review histories repeatedly found and fixed the same class of defect: a room/screen's own EventBus subscriptions or in-flight signal callbacks surviving past the point a switch/exit was supposed to make them inert, because `queue_free()`'s end-of-frame deferral only removes a node from the tree — it does not stop signal delivery or input dispatch during the deferred window.

Both epics created from these GDDs (Epic 10 Sanctuary UI, Epic 11 Tarot Deck UI) flagged the same gap independently: no dedicated architecture ADR exists formalizing this pattern, unlike Mission HUD (ADR-0031), even though both GDDs' own Detailed Design sections are already implementation-precise enough to read as ADR-grade content. Writing two near-duplicate ADRs (one per shell) would fragment a decision that is, in substance, one decision applied twice — this ADR formalizes it once.

### Constraints
- Must not contradict `mission_hud.gd`'s own already-shipped `_terminal` pattern and Planning Cluster destroy-and-recreate precedent (Epic 09, boot-verified 2026-07-20) — this ADR is a generalization of that precedent, not a new invention.
- Must compose cleanly with ADR-0011's `InputModeTracker` pattern, which both shells already depend on for their own focus rosters.
- Must not require any new EventBus events, Autoload registrations, or save-data schema — this is a pure code-structure/lifecycle decision.

### Requirements
- Guarantee that a destroyed room/screen instance cannot deliver a stray signal callback or process a stray input event during `queue_free()`'s end-of-frame deferral window.
- Guarantee that once an irreversible hand-off transition begins (Sanctuary UI → Mission Select, Sanctuary UI → Tarot Deck UI, Tarot Deck UI → Sanctuary UI), no further EventBus event or input can mutate shell state before the hand-off completes — including a `CONNECT_DEFERRED` subscription already queued before the transition began.
- Guarantee no stale `InputModeTracker` instance survives a content switch to double-register against the next instance's input.

## Decision

Both Presentation-layer shells implement the identical **destroy-and-recreate content hosting pattern with a shared terminal latch**, as follows:

### 1. Content Hosting (Destroy-and-Recreate)

Each shell owns a `Control` host node (`RoomHost` for Sanctuary UI, `ScreenHost` for Tarot Deck UI), full-rect anchored, sized to the shell's frame minus its own chrome. Hosted content (a room, a screen) is never kept alive-but-hidden — every switch instantiates the incoming content fresh as a child of the host, and every exit runs the outgoing instance through **two synchronous cleanup steps, in this exact order, before calling `queue_free()`** on it:

1. **Disconnect every EventBus subscription the outgoing instance itself owns.** Every hosted room/screen must expose this as a callable step (naming is per that content's own GDD — this ADR does not mandate a specific method name, only that the step exists and runs first).
2. **Call `set_process_unhandled_input(false)`** on the outgoing instance.

`queue_free()` is called only after both steps complete. This ordering is load-bearing, not stylistic: `queue_free()` defers node removal to end-of-frame, but does not defer or block signal delivery or input dispatch during that window — a node freed-but-not-yet-removed can still receive and act on a signal or input event fired that same frame if its subscriptions/input processing are still live. Disconnecting and gating input first closes that window before the deferred removal even begins.

Each of the shell's own `InputModeTracker` instances (per ADR-0011) scoped to hosted content is freshly constructed on each content instantiation — never reused across a destroy/recreate cycle. Persistent, shell-owned trackers (e.g. Sanctuary UI's tab-strip tracker and `OVERVIEW` structure-selection tracker) are exempt from this rule, since they are not destroyed on content switches.

### 2. Terminal Latch (Hand-off Safety)

Any transition that hands control to a different top-level shell (a genuine hand-off, not internal navigation) shares one `_departing`-style boolean flag with every other hand-off trigger the same shell owns. Whichever handler fires first: its **first EventBus-touching or state-mutating statement** — not necessarily its literal first line, since an EventBus-inert operation (e.g. killing a shell-owned tween that touches no subscription and reads no shared state) may safely precede it — sets the shared flag **and** synchronously disconnects every EventBus subscription the shell itself owns, in the same statement/step. Flag-checking alone in each handler body is not sufficient: a `CONNECT_DEFERRED` subscription already queued for later in the same frame is not stopped by a flag check, only by the connection itself no longer existing.

This mirrors `mission_hud.gd`'s existing `_terminal` pattern exactly, generalized to shells with more than one hand-off trigger (Sanctuary UI has two: Launch/Depart and Loadout).

### 3. Ownership Boundary for In-Flight Transition Effects

Any shell-level transition visual (e.g. a drawer-slide content-switch tween) is owned by the shell's host node (`RoomHost`/`ScreenHost`), **never** by the content instance being displayed. This guarantees that killing an in-flight transition effect during a hand-off or rapid re-trigger can never null-reference against a content instance that is mid-teardown, since the effect was never that instance's own object to begin with.

### Architecture Diagram

```
Shell (Sanctuary UI / Tarot Deck UI)
├── Chrome (tab strip, header/snapshot chip) — always present, shell-owned
├── ContentHost (RoomHost / ScreenHost) — Control, full-rect minus chrome
│   └── [current content instance] — destroyed and recreated on every switch
│       ├── own EventBus subscriptions (disconnected before queue_free())
│       └── own InputModeTracker (freshly constructed per instance)
├── Shared _departing flag (terminal latch, one per shell)
└── Host-owned transition tween (never content-instance-owned)
```

### Key Interfaces

Not a new EventBus contract or Autoload API — this ADR is a code-structure convention. The one interface it formalizes for cross-shell consistency: any hosted content type (Inventory+Crafting, Menagerie, Defense Building, Equipment Forge, Tarot, Hero Skill Build) must expose a callable "disconnect my own EventBus subscriptions" step that the hosting shell can invoke synchronously during teardown — the exact method name is each content's own GDD's choice, not standardized here.

## Alternatives Considered

### Alternative 1: Keep-Alive-Hidden Content (No Destroy-and-Recreate)
- **Description**: Instantiate all hosted content once at shell mount, toggle `visible`/`process_mode` on switch instead of destroying and recreating.
- **Pros**: No re-mount cost on every switch; simpler mental model for "nothing to tear down."
- **Cons**: Every hosted content instance's own EventBus subscriptions stay live for the shell's entire lifetime regardless of visibility — multiplies the subscription-leak surface by the number of rooms, the opposite of what both GDDs' own review histories found and fixed. Nested state (e.g. Menagerie's breeding-pen flow) would persist across switches, contradicting both GDDs' explicit "always resumes at root" requirement.
- **Rejection Reason**: Directly reintroduces the class of bug both GDDs' review cycles spent multiple passes finding and fixing. Rejected.

### Alternative 2: `Node.set_block_signals(true)` Instead of Explicit Disconnect
- **Description**: Use Godot's built-in signal-blocking flag on the outgoing instance instead of manually disconnecting each subscription.
- **Pros**: One call instead of an enumerated disconnect list; no risk of forgetting one subscription.
- **Cons**: Blunt instrument — blocks all signals including engine-internal/tree signals the node may still need during its own teardown, not just the EventBus subscriptions this pattern intends to sever. Harder to audit in code review than an explicit, named disconnect step. godot-specialist review (this ADR's own validation pass) confirmed no cleaner idiomatic alternative exists for this exact guarantee.
- **Rejection Reason**: Correctness risk (over-broad blocking) outweighs the convenience. Rejected.

### Alternative 3: A Reusable Generic `ContentHost` Base Class/Component
- **Description**: Extract the destroy-and-recreate + teardown-sequence logic into a single shared `ContentHost` Control subclass both shells instantiate, rather than each shell implementing its own copy.
- **Pros**: Single point of truth for the mechanism; a bug fix in one place fixes both shells.
- **Cons**: Only 2 consumers exist today (control-manifest.md's own project-wide "never build a generic utility with no second concrete need" precedent, ADR-0019's rejected `NodePool` utility for the identical reason). Premature generalization risk given the mechanism is still being implemented for the first time in both cases.
- **Rejection Reason**: Matches this project's own established precedent (ADR-0019) for declining generalization ahead of a proven second-and-third need. Both shells implement the pattern independently for now; revisit if a third shell needs it. Noted as a Risk below, not adopted.

## Consequences

### Positive
- Formalizes a single, auditable pattern instead of two GDDs independently re-deriving (and potentially silently diverging on) the same mechanism.
- Directly closes the exact defect class both GDDs' review histories found and fixed multiple times — future implementers have one canonical reference instead of needing to re-derive the reasoning from each GDD's own revision-note prose.
- Confirms via specialist review that the pattern is correct Godot 4.6.2 usage, not merely internally consistent within the two GDDs.

### Negative
- Disconnect lists remain hand-maintained per hosted-content-type — no compiler/runtime enforcement that a newly-added subscription gets a matching disconnect line (godot-specialist's own flagged risk).
- Two independent implementations (Sanctuary UI's `RoomHost`, Tarot Deck UI's `ScreenHost`) rather than one shared component — accepted per Alternative 3's rejection, but means a future fix must be applied twice if a bug is found post-implementation.

### Risks
- **Disconnect-list drift**: a new EventBus subscription added to a hosted room/screen without a matching disconnect line added to its teardown step. Mitigation: flag as a required code-review checklist item for any story touching a hosted content type's `_ready()`.
- **InputModeTracker roster ordering**: the outgoing content's tracker must be torn down before the incoming content's tracker is constructed, not interleaved — a race here could cause a stale tracker to double-register against the new content's input. Mitigation: Sanctuary UI Epic 10 Story 007 and Tarot Deck UI Epic 11 Story 003 both include explicit call-order test coverage for their own teardown sequences; this ADR's own Validation Criteria (below) restates the requirement at the architecture level.
- **Duplicated logic across 2 shells**: see Alternative 3 — accepted for now, revisit if a third shell (none currently planned) needs the identical pattern.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| sanctuary-ui.md | Core Rule 6 — destroy-and-recreate room lifecycle, extended teardown (subscription-disconnect + input-gate, in order, before `queue_free()`) | Section 1 (Content Hosting) is the formalized version of this exact rule |
| sanctuary-ui.md | Core Rule 10 — Loadout hand-off's 4-step ordered sequence, shared terminal latch with Launch/Depart (Core Rule 8) | Sections 2 (Terminal Latch) and 3 (Ownership Boundary) formalize the latch-ordering and tween-ownership guarantees Core Rule 10's own review history found and fixed |
| tarot-deck-ui.md | Core Rule 4–5 — destroy-and-recreate screen lifecycle, "restated explicitly, not just cited by reference" per the GDD's own note | Section 1 is the shared formalization both this GDD and Sanctuary UI's independently re-derive |

## Performance Implications
- **CPU**: Negligible — instantiate/free cost on content switch already accepted by both GDDs' own precedent (`mission_hud.gd`'s Planning Cluster). No new per-frame cost; the disconnect/input-gate steps are one-time, event-triggered operations on switch, not per-frame logic.
- **Memory**: No change from what each GDD already specified — a destroyed instance is genuinely freed, not retained.
- **Load Time**: Not applicable — this is an in-session content-switch pattern, not a scene/level load.
- **Network**: Not applicable — single-player project.

## Migration Plan
Not applicable at authoring time — no existing shipped code implemented either shell (Sanctuary UI and Tarot Deck UI were both `Ready` epics with `Ready` stories). **Update (2026-07-24)**: both epics are now implemented (Sanctuary UI Stories 001-013, Tarot Deck UI Stories 001-005) — this ADR has moved from ahead-of-implementation to a shipped, tested pattern. See Validation Criteria below for what was actually confirmed.

## Validation Criteria
- Sanctuary UI Epic 10 Story 007's and Story 010's own QA Test Cases (call-order inspection via mock/logging, not just eventual tree-absence) are the direct validation of Sections 1 and 2 of this ADR.
- Tarot Deck UI Epic 11 Story 003's own QA Test Cases validate the identical pattern for that shell.
- Live-MCP verification (once implemented) should specifically test the `CONNECT_DEFERRED`-already-queued race case both GDDs' review histories flagged — Sanctuary UI Story 009's AC-7 already specifies this test.

**Verification outcome (2026-07-24, `/code-review` + `/story-done` pass)**: this Validation Criteria section's claim that Tarot Deck UI Story 003 already validated "the identical pattern" was **false at implementation time** — `confirm_return_to_sanctuary()` had no terminal latch at all (no `_departing` flag, no subscription disconnects), a real gap the code review caught and this session fixed (added the flag, `_tab_strip.tab_target_selected` disconnect, and a new `ConflictIndicator.disconnect_own_subscriptions()`). Sanctuary UI's own Section 1/2 implementation required 2 further fixes on top of what was originally shipped: `RoomHost` was injecting a decoy second `InputModeTracker` per mount instead of looking up each room's own (violates Section 1's roster rule), and the Section 3 host-owned tween was a local variable, not actually stored/killable (violates Section 3 outright). All 3 findings are now remediated and covered by passing tests — recorded here so this ADR's own validation history is accurate, not because the pattern itself was wrong.

## Related Decisions
- ADR-0001 (EventBus) — the connect/disconnect discipline this pattern extends
- ADR-0002 (Scene/Autoload Structure) — both shells are scene-instanced, not Autoloads
- ADR-0011 (UI Dual-Focus Handling) — the `InputModeTracker` pattern this ADR's roster rules build on
- ADR-0031 (Mission HUD Architecture) — the direct precedent (`_terminal` pattern, Planning Cluster destroy-and-recreate) this ADR generalizes
- ADR-0019 (Projectile Pooling Strategy) — source of the "decline premature generalization" precedent this ADR's Alternative 3 follows
- `design/gdd/sanctuary-ui.md` (Core Rule 6, Core Rule 10) and `design/gdd/tarot-deck-ui.md` (Core Rule 4–5) — the GDD-level behavioral specs this ADR formalizes the shared architecture for
