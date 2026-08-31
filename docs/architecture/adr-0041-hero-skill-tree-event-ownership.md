# ADR-0041: Hero Skill Tree Event Ownership and Spend-Cap Persistence

## Status
Proposed

## Date
2026-09-01

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core (event/data architecture) + UI (Sanctuary presentation shell) |
| **Knowledge Risk** | LOW — this decision uses only signal declaration, `emit_signal()`/`.emit()`, `call_deferred()`, and the Autoload/SaveRestorer pattern already established project-wide; no post-cutoff API is introduced. |
| **References Consulted** | `docs/architecture/adr-0001-eventbus-architecture.md` (dispatch/cascade rules), `docs/architecture/adr-0029-tower-mastery-proximity-detection.md`, `docs/architecture/adr-0030-hero-skill-build-ultimate-lookup.md`, `docs/architecture/adr-0032-presentation-shell-hosting-pattern.md`, `docs/registry/architecture.yaml` (state ownership + forbidden patterns), `docs/engine-reference/godot/modules/ui.md`, `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm `call_deferred("emit_signal", ...)` (or `.emit.call_deferred(...)`) on `skill_tree_point_earned` (Tower Mastery, physics-context origin) and `skill_tree_overflow_point_earned` (Hero Skill Tree, Level-1 cascade) both actually resolve on the correct next-frame boundary under real `_physics_process` load, matching ADR-0001's own verification criterion for every other physics-tied/cascade emitter in the project. **Sharper case, per engine-specialist review**: `skill_tree_overflow_point_earned` is deferred *from inside the handler that runs when Tower Mastery's own deferred call is flushed* — whether a `call_deferred` enqueued during that same flush executes in that same flush pass or is pushed to the next one is a `MessageQueue` implementation detail this project has not previously needed to test, since every other shipped deferred emitter is single-hop, non-cascading. Verify by logging `Engine.get_process_frames()` at delivery for both signals from the same triggering physics frame and asserting whether the second lands in the same flush or one flush later — this ADR is the first place in the project actually needing that answer; ADR-0001's own equivalent verification checkbox is still unchecked. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (EventBus Architecture — dispatch policy and cascade-depth cap this decision must comply with), ADR-0032 (Presentation Shell Hosting Pattern — `ROOM_HERO_SKILLS` is a new instance of this pattern, not a new pattern) |
| **Enables** | Story implementation for `hero-skill-tree.md`'s companion revisions to `tower-mastery.md`, `hero-skill-build.md`, `sanctuary-ui.md`, `mission-hud.md`, `save-persistence.md` |
| **Blocks** | Epic: Hero Skill Tree (cannot start stories until this ADR is Accepted) |
| **Ordering Note** | Amends (does not supersede) the state-ownership registry entries ADR-0029 and ADR-0030 originated — those ADRs' own decision text is unaffected; only the registry's current-state description of two fields has drifted since Hero Skill Tree's design (see Consequences → Negative). |

## Context

### Problem Statement

`hero-skill-tree.md` inserts a new system into an existing causal chain: Tower Mastery's mid-combat proximity accrual (ADR-0029) used to unlock a skill directly and hand it to Hero Skill Build (ADR-0030). After three `/design-review`/`/review-all-gdds` rounds (2026-08-31), the chain is now Tower Mastery → Hero Skill Tree → Hero Skill Build, with Hero Skill Tree owning a spendable-point economy in between. This required resolving, for the first time as a formal decision rather than emergent GDD prose:

1. **Who owns the mutation of shared-adjacent state** when one system's threshold crossing (Tower Mastery) determines whether another system's persisted pool (Hero Skill Tree) increments? An earlier draft had Tower Mastery mutate Hero Skill Tree's state directly and call a query method on it (`hero_skill_tree.all_nodes_unlocked()`) to decide whether to grant — both a double-write hazard and a direct cross-system Node reference, which the project's own registered forbidden pattern (`direct_cross_system_node_reference`, ADR-0001) already disallows. This ADR formalizes the corrected model.
2. **How does a new player-facing spend constraint (the per-visit purchase cap) get persisted correctly** without becoming exploitable across a save/quit/relaunch cycle — a real defect found and fixed during the GDD's own review history.
3. **Where does a new Sanctuary UI room (`ROOM_HERO_SKILLS`) fit the project's existing presentation-shell architecture**, established by ADR-0032 for Sanctuary UI's and Tarot Deck UI's other hosted content.

### Constraints
- Must not introduce a new exception to `direct_cross_system_node_reference` (no ADR-0020 Criterion A/B case applies here — this is not a Sanctuary-only read like Inventory's `has_room_for()`, it's a live, mid-mission, physics-tied event chain).
- Must respect ADR-0001's cascade-depth cap (≤2 levels) and deferred-dispatch rule for physics-context and Level-1 emissions.
- Must not require `ROOM_HERO_SKILLS` to invent new Sanctuary UI shell mechanics — ADR-0032's destroy-and-recreate + terminal-latch pattern already generalizes across every hosted room/screen in the project.
- Must close a real, already-identified exploit (per-visit spend cap bypass via Save & Quit → relaunch) without adding a second persistence discipline alongside Save & Persistence's existing full-snapshot model.

### Requirements
- Tower Mastery must emit its point-grant event unconditionally, with zero reads of any other system's state, at every qualifying threshold crossing, forever.
- Hero Skill Tree must be the sole owner and mutator of its own 4 archetype pools, its overflow pool, and its 16 chain-node unlock flags — no other system writes to this state.
- The per-visit spend cap (`visit_spend_count`) must survive a save/quit/relaunch mid-visit, closing the exploit `/review-all-gdds` found.
- `ROOM_HERO_SKILLS` must be indistinguishable, architecturally, from Sanctuary UI's four existing rooms — same lifecycle, same focus-tracker discipline, same terminal-latch teardown.

## Decision

**Emission-only, zero-cross-reference ownership split.** Tower Mastery (`tower-mastery.md` Formula 3) is a pure emitter: on every whole-multiple crossing of `mastery_time[build_signature] / mastery_threshold_seconds`, it emits `skill_tree_point_earned(archetype, source_tower_id)` unconditionally — no query, no direct reference, no knowledge of Hero Skill Tree's internal state. Hero Skill Tree is the sole subscriber that mutates its own state in response: its own `_ready()`-connected handler decides, per event, whether to credit the named archetype's own pool (locked node exists), credit the archetype-agnostic overflow pool (this archetype's chain is full but another archetype's isn't), or produce no effect at all (the entire 16-node tree is already complete). This is a direct application of the EventBus-only communication model ADR-0001 already establishes project-wide — not a new pattern, a correction back onto the existing one after an earlier draft briefly deviated from it.

**Deferred dispatch on both physics-tied emissions.** `skill_tree_point_earned` originates from Tower Mastery's per-`_physics_process` threshold evaluation — a physics-context emitter under ADR-0001 Rule 2's first clause, so it must use deferred dispatch (`.emit.call_deferred(...)` or `call_deferred("emit_signal", ...)`). Hero Skill Tree's own `skill_tree_overflow_point_earned`, fired synchronously in response to receiving `skill_tree_point_earned`, is a Level-1 cascade under Rule 2's second clause and must also defer. `skill_tree_node_unlocked`/`skill_unlocked`, fired from Formula 2's Sanctuary-side node purchase, originate from a player input handler, not a physics callback — they are not subject to this requirement and may emit synchronously, consistent with every other Sanctuary-side confirm action in the project (e.g. Equipment Forge's craft-confirm). No emission in this chain exceeds cascade depth 1: Mission HUD's Group 11 handler (both new events) and Hero Skill Build's `skill_unlocked` handler both terminate the chain — neither emits a further event in response.

**Persisted spend cap, mission-scoped reset.** `visit_spend_count: int` is Hero Skill Tree's own persisted state (registered with Save & Persistence at `restore_order=37`, alongside its 4 pools, overflow pool, and 16 node flags — one `get_save_data()`/`restore_save_data()` blob, one atomic full-snapshot write, no split-state risk). It resets to 0 only when `mission_launched` fires — never on generic `SANCTUARY` (re)entry, and never implicitly on process restart. Because Save & Persistence's existing full-snapshot model (ADR-0003) always writes `visit_spend_count` and any node-purchase deduction together, in the same file, there is no code path that can restore one without the other — closing the exploit without any new atomicity mechanism beyond what already exists.

**`ROOM_HERO_SKILLS` is a fifth instance of ADR-0032's pattern, not a new one.** It gets its own fresh `InputModeTracker` per ADR-0011, participates in Sanctuary UI's existing destroy-and-recreate lifecycle and shared terminal latch exactly as Inventory+Crafting/Menagerie/Defense Building/Equipment Forge already do, and hosts two sub-screens (Hero Skill Build's loadout screen, Hero Skill Tree's spend screen) toggled by the same `LB`/`RB` bumper idiom Inventory's category tabs and Equipment Forge's Craft/Imbue toggle already establish. No new shell mechanic is introduced.

### Architecture Diagram

```
Tower Mastery (physics-tied)                Hero Skill Tree (sole state owner)          Hero Skill Build
────────────────────────────                ───────────────────────────────────         ──────────────────
mastery_time crosses threshold
  │
  ▼
emit skill_tree_point_earned      ──(deferred)──►  on skill_tree_point_earned:
  (archetype, source_tower_id)                        if archetype chain has locked node:
  [zero cross-system reads]                              skill_tree_points[archetype] += 1
                                                       elif any OTHER archetype has locked node:
                                                          overflow_points += 1
                                                          emit skill_tree_overflow_point_earned  ──(deferred, Level-1)──►  Mission HUD toast
                                                       else:  # whole tree complete
                                                          (no effect)

                                              Sanctuary: player purchase (Formula 2, input-driven, not deferred)
                                                       skill_tree_points[archetype] -= 1 (or overflow_points -= 1)
                                                       node.unlocked = true
                                                       visit_spend_count += 1  [persisted, resets only on mission_launched]
                                                       if node.type == "Skill":
                                                          emit skill_unlocked(skill_id, -1)  ─────────────────────────►  add skill_id to
                                                       else:                                                            equippable library
                                                          emit skill_tree_node_unlocked(archetype, node.index)         [terminates chain]
```

### Key Interfaces

- `EventBus.skill_tree_point_earned(archetype: String, source_tower_id: int)` — emitted by Tower Mastery only, deferred, unconditional.
- `EventBus.skill_tree_overflow_point_earned(source_tower_id: int)` — emitted by Hero Skill Tree only, deferred (Level-1 cascade).
- `EventBus.skill_tree_node_unlocked(archetype: String, node_index: int)` — emitted by Hero Skill Tree only, on Minor-node purchase, synchronous (input-driven).
- `EventBus.skill_unlocked(skill_id: String, source_tower_id: int)` — emitted by Hero Skill Tree only (Tower Mastery's prior direct emission is fully retired); `source_tower_id = -1` sentinel at all times, since this now only fires from a Sanctuary purchase.
- `HeroSkillTree` (Autoload) — owns `skill_tree_points: Dictionary[String, int]` (4 entries), `overflow_points: int`, `_chain_nodes: Dictionary[String, Array]`, `visit_spend_count: int`. All four persisted via one `SaveRestorer` registration, `restore_order=37`. **Amended 2026-09-01 (still Proposed, not Accepted — amending in place, not superseding)**: `hero-skill-tree.md`'s same-day Choice-node redesign changed `_chain_nodes`' per-node shape from a plain bool to `{"unlocked": bool}` (Minor, node_index 0) or `{"unlocked": bool, "chosen_skill_id": String}` (Choice, node_index 1-3) — 16 nodes total, unchanged. The 2-3 candidate `skill_id`s per Choice node and the `LOCKED_OUT` sibling set are both resolved live from `GameDataRegistry.get_all_skill_definitions()` (filtered by `category`+the new `SkillDefinitionResource.tier` field) rather than persisted, per that GDD's own Dependencies section — avoids a second source of truth against the catalogue itself.

## Alternatives Considered

### Alternative A: Tower Mastery queries Hero Skill Tree directly before emitting
- **Description**: Tower Mastery holds a reference to the `HeroSkillTree` Autoload and calls `hero_skill_tree.all_nodes_unlocked(archetype)` before deciding whether to emit `skill_tree_point_earned`, mutating `skill_tree_points` itself on a positive result.
- **Pros**: Slightly fewer branch evaluations on Hero Skill Tree's side.
- **Cons**: Violates the registered `direct_cross_system_node_reference` forbidden pattern; creates a double-write hazard if Hero Skill Tree's own handler also credits the same event; creates an implicit restore-order dependency (Tower Mastery restores at 34, Hero Skill Tree at 37 — the caller could exist before the callee on a fresh load).
- **Rejection Reason**: This was the project's actual first draft (2026-08-31) and was found, independently, by three separate `/review-all-gdds` specialist passes to be a real double-grant bug and an undeclared architecture-rule violation. Rejected, not merely considered.

### Alternative B: A shared "SkillEconomy" mediator Autoload
- **Description**: Introduce a new intermediate Autoload that both Tower Mastery and Hero Skill Tree write to/read from, decoupling them further.
- **Pros**: Would allow a third consumer to hook the same point stream without touching either existing system.
- **Cons**: No current or foreseeable third consumer exists; adds a Level-1 cascade hop and an extra persisted-state owner for no requirement this project actually has.
- **Rejection Reason**: Speculative generality with no driving requirement — rejected per this project's own "don't design for hypothetical future requirements" discipline.

### Alternative C (chosen): Pure EventBus emission, Hero Skill Tree as sole state owner
- **Description**: As described in Decision above.
- **Pros**: Zero cross-system reads; matches the project's existing, load-bearing forbidden-pattern discipline; no new restore-order coupling; independently re-verified clean across two consecutive `/review-all-gdds` passes.
- **Cons**: Requires Hero Skill Tree's handler to re-derive "is this archetype's chain full" and "is the whole tree full" per event, rather than Tower Mastery pre-computing it — a negligible cost (4 boolean checks) against the alternative's coupling cost.
- **Rejection Reason**: N/A — chosen.

## Consequences

### Positive
- Closes a real double-grant bug and a real architecture-rule violation, independently re-verified fixed across two full holistic review passes.
- `ROOM_HERO_SKILLS` requires zero new Sanctuary UI shell code beyond configuration — it reuses ADR-0032's pattern verbatim.
- The per-visit spend cap's exploit is closed by Save & Persistence's existing full-snapshot atomicity, not a new persistence mechanism.

### Negative
- **Registry drift, found during this ADR's own research**: `docs/registry/architecture.yaml`'s `tower_mastery_progress` entry (added by ADR-0029) still describes `_unlocked_skills: Dictionary[String, bool]` as live state — that field was retired by `tower-mastery.md` Rule 5 in favor of `points_granted_count: Dictionary[String, int]`. The `hero_skill_build_state` entry (added by ADR-0030) still says its equippable-skill mirror populates "via `skill_unlocked`... subscription" without noting the event's origin moved from Tower Mastery to Hero Skill Tree. Both are amended by this ADR's registry update (Step 6) rather than requiring ADR-0029/0030 themselves to be reopened, since their own decisions (build-signature keying; Ultimate-derivation ownership) are unaffected.
- Hero Skill Tree's handler now carries slightly more branching (3-way: own pool / overflow / no-op) than a simpler always-credit model would — an accepted cost of correctness over the double-grant alternative.

### Risks
- **Risk**: A future change to Tower Mastery's accrual timing (e.g., moving evaluation off `_physics_process`) could silently invalidate the deferred-dispatch requirement this ADR states for `skill_tree_point_earned`. **Mitigation**: the requirement is tied to the emission's *context* (physics-tied), not a hardcoded assumption — any future GDD/ADR revision changing that context must re-evaluate this ADR's Engine Compatibility → Verification Required row.
- **Risk**: A future third consumer of `skill_tree_point_earned` that itself needs to cascade a further event would hit ADR-0001's depth-2 cap, since Hero Skill Tree's own response is already a Level-1 cascade. **Mitigation**: none needed today — no such consumer exists; flagged here so a future design pass doesn't discover the cap the hard way.
- **Risk (found by engine-specialist validation)**: `skill_tree_overflow_point_earned`'s deferred call is enqueued *from inside the flush of Tower Mastery's own deferred call* — a nested-deferred-within-a-flush case this project's other shipped deferred emitters (all single-hop, non-cascading) have never exercised. Whether Godot's `MessageQueue` executes it in that same flush pass or defers it one further frame is not guaranteed by the scripting reference and hasn't been measured in this project. Not a correctness risk (no state ends up wrong either way), but a timing assumption Mission HUD's toast-sequencing implementation should be built against a measured answer, not an assumed one. **Mitigation**: see Validation Criteria — log `Engine.get_process_frames()` for both signals in the same triggering frame during implementation and assert the actual relationship before writing any toast-ordering logic that depends on it.
- **Risk (minor, found by engine-specialist validation)**: this ADR doesn't state where the new `HeroSkillTree` Autoload sits in the project's registration order relative to the existing roster. **Mitigation**: not a real boot-race risk — all Autoloads complete `_ready()` before the first `_physics_process` fires, so Hero Skill Tree's `skill_tree_point_earned` subscription is safely connected before Tower Mastery's first physics frame regardless of relative order, as long as it registers after `EventBus`. Left as an explicit note for the implementation story to place it correctly in `project.godot`'s `[autoload]` section rather than leaving the ordering implicit.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| hero-skill-tree.md | Rule 3/3a/3b/3c — point crediting, overflow, terminal no-op, zero cross-system reads | Formalizes the emission-only ownership split as the accepted architecture, not just GDD prose |
| hero-skill-tree.md | Rule 13 — persisted per-visit spend cap, reset only on `mission_launched` | Formalizes the atomicity guarantee (Save & Persistence's existing full-snapshot model) that closes the identified exploit |
| tower-mastery.md | Formula 3 (revised) — unconditional emission, zero cross-system reads | Formalizes this as the corrected, Accepted architecture; supersedes the rejected Alternative A in practice |
| hero-skill-build.md | Rules 16/17 — equippable-skill mirror sourced from Hero Skill Tree's `skill_unlocked`, not Tower Mastery's | Confirms the event-origin change is an accepted, permanent architectural fact, not a temporary GDD correction |
| sanctuary-ui.md | Core Rule 11 — `ROOM_HERO_SKILLS`, a 6th tab-strip entry hosting both systems | Confirms this room requires no new shell pattern — ADR-0032 already covers it |
| save-persistence.md | Hero Skill Tree row (`restore_order=37`) — 4 pools, overflow, 16 node flags, `visit_spend_count`, one blob | Formalizes the single-blob atomicity this ADR's exploit-closure argument depends on |

## Performance Implications
- **CPU**: Negligible. Hero Skill Tree's handler adds at most 2 dictionary/array lookups per `skill_tree_point_earned` event versus a hypothetical pre-computed-by-emitter design; event volume is bounded by mastery-threshold crossings (seconds-scale, not per-frame).
- **Memory**: One new Autoload's persisted state: 4 ints (pools) + 1 int (overflow) + 16 bools (nodes) + 1 int (spend cap) — trivial.
- **Load Time**: No change — Hero Skill Tree registers with Save & Persistence exactly as every other system does; no new load-order dependency beyond `restore_order=37`'s existing placement.
- **Network**: N/A — single-player, no networked state.

## Migration Plan
N/A — no shipped code exists yet for this chain; this ADR governs first implementation, not a migration from a prior shipped design.

## Validation Criteria
- gdUnit4 coverage confirming: (1) `skill_tree_point_earned` never double-credits `skill_tree_points` under any test sequence; (2) a save/reload mid-Sanctuary-visit after a purchase restores `visit_spend_count` and the node-unlock flag together, never one without the other; (3) `ROOM_HERO_SKILLS`'s `InputModeTracker` is freshly constructed on every room re-entry, matching the other 4 rooms' existing test coverage pattern.
- Live Godot MCP verification (per this project's `docs/engine-reference/godot/VERSION.md` "live-verify, don't just static-analyze" standing instruction) of the deferred-dispatch requirement: confirm `skill_tree_point_earned`/`skill_tree_overflow_point_earned` both resolve on the correct next-frame boundary when triggered from a real `_physics_process` context, not just a synchronous unit test. Specifically: log `Engine.get_process_frames()` at delivery for both signals from the same triggering physics frame and record whether the overflow signal lands in the same `MessageQueue` flush as the point-grant signal or one flush later — this is a genuinely new case for this project (its other deferred emitters are all single-hop), not an assumed-safe repeat of an existing pattern.

## Related Decisions
- ADR-0001 — EventBus Architecture (dispatch/cascade rules this decision complies with)
- ADR-0029 — Tower Mastery Proximity Detection (state-ownership entry amended, decision text unaffected)
- ADR-0030 — Hero Skill Build Ultimate Lookup (state-ownership entry amended, decision text unaffected)
- ADR-0032 — Presentation Shell Hosting Pattern (`ROOM_HERO_SKILLS` is a new instance, not a new pattern)
- `design/gdd/reviews/hero-skill-tree-review-log.md` — full 3-round review history this ADR formalizes the outcome of
- `design/gdd/gdd-cross-review-2026-08-31.md` — the holistic review findings (double-grant, direct-call violation, spend-cap exploit) this ADR's Decision section resolves
