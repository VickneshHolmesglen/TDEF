# Cross-GDD Review Report

**Date**: 2026-08-31
**GDDs Reviewed**: 30 (all `design/gdd/*.md` except `game-concept.md`, `systems-index.md`, `game-pillars.md`, and prior `gdd-cross-review-*.md` reports)
**Systems Covered**: All Foundation/Core/Feature/Advanced/Presentation layers

**Trigger for this review**: Hero Skill Tree (`hero-skill-tree.md`) was authored, revised, and Approved same-day (2026-08-31), including a companion revision to `tower-mastery.md` and catalogue additions to `event-bus.md`/`save-persistence.md`. Two narrower checks (`/design-review --depth full` ×2, `/consistency-check`) had already passed on the touched documents and the entity registry. This holistic pass — reading all 30 GDDs together, plus a dedicated cross-system scenario walkthrough — found that the prior passes' scope was too narrow: real defects survived in the touched documents themselves, and the revision's actual blast radius extended into several documents that were never revised at all.

Process note: no GDD in this project uses a `## Summary` header, so this review proceeded directly to full parallel reads via 3 parallel passes (Consistency, Game Design Holism, Cross-System Scenario Walkthrough) rather than a summary-scan triage.

---

## Consistency Issues

### Blocking (must resolve before architecture begins)

🔴 **Double point-grant bug.** `tower-mastery.md` Formula 3 performs `skill_tree_points[archetype] += 1` *and* emits `skill_tree_point_earned`. `hero-skill-tree.md`'s own Interactions table describes itself as crediting the pool *on receipt* of that same event. As written, every threshold crossing grants **two** points, not one. Neither document states which side owns the mutation. This is a real implementation-blocking bug introduced while writing the companion revision, not a documentation nit.

🔴 **Save schema understates the persisted state by half.** `hero-skill-tree.md` Rule 6 defines 4 nodes × 4 archetypes = 16 total nodes, but its own Save & Persistence dependency note, AC-12, and `save-persistence.md`'s row 37 all say "8 per-archetype-chain unlocked booleans" — that number is the Minor-node count (Rule 13: "8 total minor nodes"), not the total. The actual persisted blob needs 16 booleans.

🔴 **Undeclared direct cross-system call, violating the project's EventBus-only architecture.** `tower-mastery.md` Formula 3 has Tower Mastery calling `hero_skill_tree.all_nodes_unlocked(archetype)` synchronously — a direct reference `systems-index.md`'s own Overview says never happens ("All gameplay systems communicate exclusively through a central EventBus; no system has a direct reference to another"). Neither document declares this dependency in either direction (`hero-skill-tree.md`'s Downstream Dependents omits Tower Mastery; `tower-mastery.md`'s Upstream Dependencies omits Hero Skill Tree). Compounding: Tower Mastery restores at `restore_order=34`, Hero Skill Tree at `37` — the caller is live before the callee has restored.

🔴 **The claimed cross-system save atomicity is actually impossible.** `hero-skill-tree.md` Edge Cases and AC-6 require `skill_tree_points` and `points_granted_count` to commit as "a single atomic operation... never two independently-observable states." They live in two different systems' save blobs (Tower Mastery owns `points_granted_count` at restore_order 34; Hero Skill Tree owns the pools at 37). `save-persistence.md`'s EC-4 restores per-system and, on one system's restore failure, calls `reset_to_defaults()` on that system only and continues — so a Hero Skill Tree restore failure zeroes the pools while Tower Mastery retains a high `points_granted_count`, permanently losing every earned point with no path to regenerate it (mastery_time has already been "spent" against that counter).

🔴 **`sanctuary-ui.md` has no mount point, and its tab strip is structurally closed.** `hero-skill-tree.md` names Sanctuary UI as an upstream dependency needing "a mount point (new screen or panel)." `sanctuary-ui.md` never mentions the skill tree, Hero Skill Tree, or skill tree points anywhere. Its Core Rule 2 fixes an exhaustive **6-entry** vertical tab strip (Overview · Inventory & Crafting · Menagerie · Defense Building · Equipment Forge · Loadout) with hotkeys 1–6, and Core Rule 5 asserts "Six instances total" of `InputModeTracker" — no seventh slot, no stated extension mechanism.

🔴 **Mission HUD has no subscription to either new event, and the "existing slot" both upstream docs claim doesn't exist.** `hero-skill-tree.md` (Interactions table) and `tower-mastery.md` (Downstream Dependents) both assert `skill_tree_point_earned` reuses "the same notification slot Mission HUD already reserves for `skill_unlocked`." `mission-hud.md` never mentions `skill_unlocked`, `skill_tree_point_earned`, or skill tree points anywhere. Its only Tower Mastery row is marked "provisional — no GDD yet" (stale since Tower Mastery's 2026-07-17 Approval), and its own Edge Case mandates "zero handling logic... treat as ghost events" for exactly this kind of unlocked payload contract.

🔴 **`hero-skill-build.md` still encodes the retired pre-revision Tower Mastery contract in load-bearing rules.** Rule 16 calls its own equippable-skill library "a local cache/mirror of Tower Mastery's `unlocked_skills`" — retired by `tower-mastery.md` Rule 5. Rule 17 says it "subscribes to Tower Mastery's `skill_unlocked`" — Tower Mastery no longer emits it (per that document's own AC-22c). Its States/Transitions section justifies keeping the `skill_unlocked` subscription active during the LOCKED state with "Tower Mastery can unlock a skill mid-wave" — impossible under the new model, since `skill_unlocked` now only fires at Sanctuary (Rule 11), i.e. only while Hero Skill Build is CONFIGURABLE, not LOCKED. Also present in Rules 14/15, its Interactions/Dependencies tables, and a stale `restore_order` recommendation (32, "after Tower Mastery's proposed 31" — Tower Mastery's actual assigned slot is 34, corrected 2026-07-17; HSB itself is the authoritative 31).

🔴 **`tower-mastery.md` contradicts itself between Rule 7 and Rule 12.** Rule 7 (written 2026-08-31) declares `skill_id`/`source_build_signature`/`output` vestigial, "no longer read by any runtime system." Rule 12 (unrevised) populates `mastery_progress_updated`'s `skill_id` field by looking it up from the catalogue entry matching `source_build_signature`, every physics frame that a signature accrues.

### Warnings (should resolve, but won't block)

⚠️ Residual `unlocked_skills`/`skill_unlocked` references remain inside `tower-mastery.md` itself: Rule 2 ("feeds `mastery_progress_updated` / `skill_unlocked`"), Rule 3 ("persistent mastery storage... `_unlocked_skills`"), an Edge Case testing `unlocked_skills[skill_id]`, AC-18 (tests the retired dictionary directly), Visual/Audio §d (still specifies a `skill_unlocked` chime for an event this system no longer emits, immediately below a correctly-revised §c), and an Open Question referencing `skill_unlocked` payloads.

⚠️ `encyclopedia.md` (Dependencies table) and `hero.md` (line 572) both still describe `skill_unlocked` as firing on "proximity threshold reached." `encyclopedia.md` also has no row for `skill_tree_node_unlocked` despite `event-bus.md` naming it as that event's primary subscriber.

⚠️ AC-5's phase lock ("SCOUT, WAVE_ACTIVE, or INTERMISSION") omits `OUTCOME`/`DEFEAT`, which `hero-skill-build.md`'s own LOCKED state and `sanctuary-ui.md`'s entry condition both treat as pre-Sanctuary — a purchase during OUTCOME/DEFEAT would pass AC-5 while violating Rule 11's intent.

⚠️ `event-bus.md`'s `skill_tree_node_unlocked` row cites "Sanctuary UI reads it live... per hero-skill-tree.md's Interactions table row for Mission HUD/Encyclopedia" — that row says nothing about Sanctuary UI, and `sanctuary-ui.md` has no such subscription (consistent with the Blocking finding above).

⚠️ Rule 14 and Formula 1 disagree on whether `points_granted_count` keeps advancing once an archetype is maxed: Rule 14 says accrual and the counter "keep advancing internally exactly as before... uninterrupted." Formula 1's `if all_nodes_unlocked(...): return` guard exits before the trailing `points_granted_count[build_signature] = points_earnable` write, freezing it instead. Currently harmless (unlocks are irreversible) but a stated rule the math violates.

---

## Game Design Issues

### Blocking

🔴 **Hero Skill Tree's central Player Fantasy promise is mechanically unreachable — for the second time today.** The system's whole pitch is "which of your four archetype pools to advance first." But pools are non-fungible (Rule 1/4), uncapped (Rule 5), spent in full in a single Sanctuary visit with no shared budget, chain order is fixed (Rule 6/7), and every node is a pure improvement. The rational — and only — policy is: spend everything, in every pool, every visit. Nothing is foreclosed, delayed, or traded off. The GDD's own Edge Cases admit "there is no conversion or overflow mechanism," and the Player Fantasy's own closing line concedes "nothing here is lost or foreclosed." This is the *second* rewrite of this exact fantasy failing for the same structural reason (the first rewrite, earlier the same day, replaced an "order you decided" framing that a fixed linear chain couldn't deliver; this framing replaced it with "which pool first," which an uncapped non-competing resource can't deliver either). The fix has to be mechanical — a shared point budget across archetypes, a per-visit spend cap, or a lossy cross-archetype conversion — not a third prose pass.

🔴 **Tower Mastery's Player Fantasy was never updated for the revision and is now false.** It still reads "when the bar finally fills... the skill locks in — the reward is the one thing the mission cannot take back," and calls itself "the only lesson in the game that is not taught in the calm of the sanctuary but in the middle of a live wave." Both statements describe exactly the behavior this revision deleted: nothing locks in at the bar filling anymore (a point does, redeemable later), and the actual skill-learning moment now happens at Sanctuary, not mid-combat. The header's own revision list (Rule 13/14/15, Formula 3, state rename, tables, Visual/Audio, 3 ACs) never mentions the Player Fantasy section at all.

🔴 **Point income may be silently gated to exactly 8 authored loadouts, and no document resolves which reading is correct.** `hero-skill-tree.md` Formula 1 reads `mastery_threshold_seconds` from the catalogue keyed by `build_signature`. `tower-mastery.md` Rule 7 says that catalogue's `source_build_signature`/`output` fields (the only way a signature maps to a catalogue entry) are "no longer read by any runtime system," while Rule 12 calls an uncatalogued signature "a valid, silent no-op." If only the 8 already-catalogued loadouts (one per `hero-skill-build.md` skill) ever produce a catalogue hit, then only those 8 exact 4-component builds can ever earn a point — directly contradicting `hero-skill-tree.md` Rule 4's promise that "two different build signatures sharing an archetype... both feed the same pool." If instead an uncatalogued signature earns at the global default threshold, Rule 4's promise holds — but nothing says which.

🔴 **Tower Mastery becomes a completely dead mechanic for the entire back half of every playthrough.** Total lifetime sink across all 4 archetype chains is 16 points (4 nodes × 4 archetypes). After an archetype's chain is fully spent, Formula 1's `all_nodes_unlocked` cap (added specifically to close an unbounded-faucet defect) stops crediting new points for that archetype — permanently, for the rest of the adventure. Once all 4 chains are cleared, standing beside any tower — Tower Mastery's entire "worth a lane, a real wager" positioning trade-off — pays literally nothing, ever again. Pre-revision, unbounded accrual was justified as reserved "to support a future next-tier skill"; the tree consumed that reservation and then capped it, leaving the core mechanic strictly dominated (never worth doing) for however many missions remain in a playthrough after chain completion.

### Warnings

⚠️ Hero Skill Tree and Hero Skill Build both claim to be "the" defining Sanctuary decision moment for the hero's build, in the same session, operating on the same `skill_id` objects — Hero Skill Tree's claim ("the one place all season where your mastery... becomes a decision with your name on it") is rhetorically the louder of the two while being, per the Blocking finding above, mechanically empty; Hero Skill Build's ("the four slots... the most expressive decision the hero has") is mechanically real.

⚠️ The revision quietly removed a Pillar-2 ("Everything Connects") synergy path. Pre-revision, each skill required mastering one *specific* 4-component build signature — a direct, discoverable Crafting → Tower-composition → Hero-skill chain. Post-revision, points are archetype-keyed and Formula 1 states a chain is "completable from as few as 1 mastered build signature per archetype." Both `tower-mastery.md` Rule 7 and `hero-skill-build.md` Rule 2 now mark `mastery_source_build_signature` "vestigial at runtime." Optimal play collapsed from "master 8 distinct loadouts" to "camp beside one tower per archetype."

⚠️ The ratified ~2x pacing slowdown to reach a given skill was never re-derived downstream. `hero-skill-build.md` Rule 7 requires all 4 active slots filled before any Ultimate resolves — `game-concept.md`'s own named High-Risk headline mechanic. Every path to a first Ultimate now costs at least 2x the mastery-threshold crossings it used to, with monster scaling, mission budgets, and difficulty tiers all unchanged. Separately, the tree's first purchasable node in every archetype is a `Minor` node whose effect content is entirely undesigned (OQ-1) — the earliest, most pacing-critical purchases are currently blank.

⚠️ As currently specified, Hero Skill Tree serves none of the 3 canonical pillars: nothing is predicted or vindicated (chain is fixed and fully visible — Pillar 1); it adds no new synergy path and net-removes one (Pillar 2, see above); and every player's completed chains are byte-identical in identical order — the explicit anti-pattern "systems that funnel all players through identical sanctuary evolution paths" (Pillar 3). `game-pillars.md`: "When a mechanic serves none, it does not ship" — meaning it needs a real branch, gate, or cross-system hook, not necessarily a cut.

⚠️ Three separate systems now bid on the single resource "where the hero stands" during WAVE_ACTIVE — combat positioning, Hero class proximity accrual (`hero.md` Rule 15), and Tower Mastery accrual — all on the identical 3-cell Chebyshev radius and phase gate, with no HUD element distinguishing which is currently progressing. Not blocking, but `mission-hud.md` specifies feedback for neither of the two accrual tracks today.

---

## Cross-System Scenario Issues

**Scenarios walked**: (1) the full mastery→point→node→skill→Ultimate causal chain; (2) hero death mid-mission with unspent banked points; (3) save/load mid-Sanctuary during a node purchase; (4) Mission HUD's live notification handling.

Findings from these walkthroughs are folded into the Consistency and Game Design sections above (the double-grant bug, the save-atomicity break, the dead Mission HUD notification slot, and the undeclared direct call all surfaced during this phase). One additional minor item:

ℹ️ `hero-skill-tree.md` AC-6 cites "the checkpoint save triggered by mission defeat, per save-persistence.md Core Rule 11" as a specific save trigger — Rule 11 is actually the save-scope reference table, not a trigger; the real DEFEAT-triggered save is Rule 4's main-slot write. Rule 11's table also has no row for Hero Skill Tree state at all.

ℹ️ The save/load-mid-purchase Edge Case in `hero-skill-tree.md` (Formula 2's deduct-then-unlock pair) is likely unfalsifiable in a single-threaded GDScript call — the real partial-state risk is the cross-system atomicity break documented above, which that Edge Case does not cover.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|---|---|---|---|
| `hero-skill-tree.md` | Double-grant bug, unreachable Player Fantasy (2nd failed attempt), ambiguous income gating, 16-vs-8 node count error | Consistency + Design Theory | Blocking |
| `tower-mastery.md` | Rule 7/12 self-contradiction, undeclared direct call to Hero Skill Tree, stale/false Player Fantasy, residual `unlocked_skills`/`skill_unlocked` references | Consistency + Design Theory | Blocking |
| `hero-skill-build.md` | Still describes retired Tower Mastery contract in load-bearing rules (Rules 14/15/16/17), stale `restore_order` recommendation | Consistency | Blocking |
| `sanctuary-ui.md` | No mount point for a declared upstream dependency; tab strip structurally closed at 6 entries | Consistency | Blocking |
| `mission-hud.md` | No subscription to either new event; the "existing notification slot" two other GDDs claim it reserves does not exist; stale "Tower Mastery not started" note | Consistency | Blocking |
| `save-persistence.md` | Save schema node count wrong (16 vs 8 booleans); cross-system atomicity two other GDDs depend on is unenforceable given per-system EC-4 reset | Consistency | Blocking |
| `encyclopedia.md` | Stale `skill_unlocked` trigger description; no row for `skill_tree_node_unlocked` | Consistency | Warning |
| `hero.md` | Stale `skill_unlocked` emitter attribution (line 572) | Consistency | Warning |

---

## Fixes Applied (2026-08-31, same day)

Both open design decisions were resolved by the player and implemented, along with every mechanical fix listed above:

- **Point economy given a real constraint** (resolves B1, the unreachable Player Fantasy): a **per-visit spend cap** — at most 1 node purchase, across any archetype or overflow, per Sanctuary visit — makes "which path first" a genuine, binding choice for the first time. `hero-skill-tree.md` Rule 13, Formula 2, and its Player Fantasy were all revised to match.
- **Late-game dead mechanic fixed** (resolves B4): an **overflow points** system — once an archetype's chain is fully spent, further mastery of that archetype converts to a wildcard point spendable on any other archetype's locked node, rather than being discarded. New `hero-skill-tree.md` Rule 3b, new `skill_tree_overflow_point_earned` event.
- **Double point-grant bug fixed**: ownership resolved — Tower Mastery emits `skill_tree_point_earned` unconditionally, forever; Hero Skill Tree's own event handler is the sole code that mutates `skill_tree_points` (crediting the pool, or overflow if the chain is full). This also eliminated the undeclared direct `hero_skill_tree.all_nodes_unlocked()` Autoload call `tower-mastery.md` Formula 3 previously made — Tower Mastery now has zero cross-system reads.
- **Save schema node count corrected**: 16 (4 nodes × 4 archetypes), not 8, throughout `hero-skill-tree.md` and both of `save-persistence.md`'s tables; that document's system count corrected 15→16.
- **Uncatalogued-signature income ambiguity resolved**: `tower-mastery.md` Rule 7's global-default threshold fallback was clarified to apply to *every* build signature, catalogued or not — point income was never intended to gate on the 8 pre-authored loadouts, and Rule 12 now fires `mastery_progress_updated` for every accruing signature, with `skill_id` downgraded to a decorative, best-effort-only field.
- **Sanctuary UI mount point resolved**: a new 7th tab-strip entry, "Skills" (`sanctuary-ui.md` Core Rule 11), hosts both Hero Skill Build's loadout screen and Hero Skill Tree's spend screen as `LB`/`RB`-toggled sub-screens of a new `ROOM_HERO_SKILLS` room — closing both Hero Skill Tree's dependency and a pre-existing, previously-unnoticed gap in Hero Skill Build's own reachability.
- **Mission HUD notification gap resolved**: new Group 11 (Rules 28-30) gives `skill_tree_point_earned`/`skill_tree_overflow_point_earned` a real corner-toast treatment — the "existing slot" both upstream documents claimed never actually existed.
- **`hero-skill-build.md` updated**: Rules 14-17, the LOCKED-state rationale, Interactions/Dependencies tables, and `restore_order` all corrected to attribute `skill_unlocked` to Hero Skill Tree, not Tower Mastery, and to describe the current model accurately.
- **`tower-mastery.md`'s own Player Fantasy rewritten** to match current behavior (a point that locks in, not a skill), and residual `unlocked_skills`/`skill_unlocked` references cleaned up throughout (Rules 2/3, AC-18 retired, AC-22b retired, the audio spec corrected).
- **Registry/event-bus/save-persistence bookkeeping**: `skill_tree_overflow_point_earned` catalogued (event count 79→84 across this whole revision), all affected system counts and cross-references updated.

All 6 flagged GDDs (`hero-skill-tree.md`, `tower-mastery.md`, `hero-skill-build.md`, `sanctuary-ui.md`, `mission-hud.md`, `save-persistence.md`) were edited same-day. None have been marked back to Approved — per this project's own convention, that requires a fresh confirmation pass (`/design-review` or `/review-all-gdds`), not a self-certification by the same session that made the fixes.

## Verdict: FAIL

### Required actions before re-running

1. Resolve the double-grant ownership question: decide whether Tower Mastery or Hero Skill Tree performs `skill_tree_points[archetype] += 1`, and remove the duplicate write.
2. Correct the save schema node count (16, not 8) in `hero-skill-tree.md` and `save-persistence.md`.
3. Remove or properly declare the direct `hero_skill_tree.all_nodes_unlocked()` call — either route it through EventBus, or explicitly document it as an approved architecture exception (as Grid/Mission Select/Mission HUD's existing exceptions are documented) with correct restore-order sequencing.
4. Resolve the cross-system atomicity claim: either move both fields into one system's save blob, or specify an actual reconciliation/replay strategy for a partial restore failure.
5. Give Hero Skill Tree an actual Sanctuary UI mount point (a 7th tab-strip entry, or a sub-panel of an existing tab) — a design decision for `sanctuary-ui.md`'s owner.
6. Give Mission HUD an actual rule for `skill_tree_point_earned` — there is currently no reserved slot to "move into."
7. Revise `hero-skill-build.md`'s Rules 14–17 to reflect the actual current Tower Mastery/Hero Skill Tree contract.
8. Fix `tower-mastery.md`'s Rule 7/Rule 12 contradiction — decide whether `skill_id` is genuinely vestigial (and stop emitting it) or genuinely still needed (and un-flag it as vestigial).
9. **Design decision needed**: resolve the unreachable Player Fantasy (B1) and the dead-late-game problem (B4) together, since they share a root cause — the point economy currently has no real constraint. A shared cross-archetype point budget, a per-Sanctuary-visit spend cap, or a genuine sink for post-completion mastery accrual would address both at once.
10. **Design decision needed**: resolve whether uncatalogued build signatures earn skill tree points at all (B3) — this determines whether the system is completable through normal play or gated behind 8 exact loadouts.
11. Rewrite Tower Mastery's Player Fantasy to match its actual current behavior.
