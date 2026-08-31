# Hero Skill Tree

> **Status**: Draft — revised 2026-08-31 after `/design-review --depth full` returned MAJOR REVISION NEEDED (4 specialists + creative-director synthesis). 3 blocking items resolved same-day: (1) the point-income ceiling that made half the catalogue permanently unreachable, fixed by reusing `tower-mastery.md` Rule 14's existing repeating-accrual hook instead of a one-time grant; (2) the missing `restore_order` and save-ordering question, resolved as self-contained (this system's restore never depends on another system's restored state) with `restore_order = 37` proposed; (3) the Player Fantasy's "order you decided" promise, rewritten around the real decision this structure delivers — cross-archetype allocation, not within-chain branching. 7 non-blocking findings also addressed inline (see `design/gdd/reviews/hero-skill-tree-review-log.md` once filed). Not yet re-reviewed.
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-08-31
> **Implements Pillar**: Everything Connects · Mastery-as-Vindication
> **Solves**: Gives Tower Mastery's mid-combat proximity investment a deliberate, player-authored spend decision instead of an automatic, unasked-for unlock. Sits between Tower Mastery (unchanged accrual, revised output) and the existing Hero Skill Build System (unchanged consumer).
> **Revises an Approved GDD**: `tower-mastery.md` Rule 13 changes from "crossing a mastery threshold directly unlocks a skill" to "crossing a mastery threshold grants one spendable skill tree point." Rules 1–12 and 14 (accrual, proximity, per-`build_signature` tracking, past-100% continuation) are unchanged. See Dependencies.

## Overview

The Hero Skill Tree is a per-adventure spend-progression layer inserted between Tower Mastery and the existing Hero Skill Build System. It replaces Tower Mastery's automatic "100% mastery = skill unlocked" behavior with a spendable point economy: crossing a mastery threshold grants the hero one skill tree point in the mastered tower's archetype, and mastery accrual continuing past that threshold (already an existing, deliberate Tower Mastery behavior) grants further points at each subsequent threshold multiple — rather than instantly handing over a specific skill. The player then spends banked points, at Sanctuary between missions, to advance one of four fixed, linear, archetype-keyed node chains (physical / ranged / elemental / support) — each chain interleaving minor stat/passive nodes with that archetype's two existing catalogued skills (`hero-skill-build.md`), unlocked strictly in order within its own chain. The real decision this system introduces is not node order within one archetype (that's fixed) — it's **which of the player's four archetype pools to advance first**, since points are earned unevenly across archetypes based on what the player actually mastered. A node that represents a real skill still fires the existing `skill_unlocked(skill_id, source_tower_id)` event, unchanged in shape, the moment it's purchased — so the Hero Skill Build System, Mission HUD, and Encyclopedia all keep consuming it exactly as they do today. Only the trigger moves: from "automatic, the instant mastery crosses 100%" to "player spend, gated by an earned point and an already-unlocked predecessor node."

## Player Fantasy

> You used to earn a skill just by standing your ground. Fight beside the same kind of tower long enough, and the game simply handed you what it had to teach — automatic, unasked-for, whatever came next on the list.
>
> Now standing your ground earns you something smaller and more honest: a point. Proof that you mastered this archetype a little further, with no promise yet of what it buys. You carry that proof home to the sanctuary, and there — quiet, unhurried, no wave bearing down on you — you decide what your mastery was actually for.
>
> Within a single archetype, the path is fixed — you don't get to skip ahead, and the stat node nobody brags about comes before the skill everybody wants. That's deliberate: mastery is not a moment, it's a sequence, and you don't get the ending without the middle. But the real decision was never *which* node comes next inside one path — it's *which path you walk first*. You mastered four kinds of towers this run, maybe unevenly, and you're standing in front of four separate proofs of that: banked points in physical, none yet in support, a couple in elemental. Do you round out the archetype you've nearly finished, or start climbing the one you've been neglecting? That's the question the sanctuary actually asks you — not "what order will this one path take," but "which of everything you've earned matters to you most, right now."
>
> And the moment the points get spent is not an afterthought squeezed between missions. It's the one place all season where your mastery stops being background progress and becomes a decision with your name on it — the same reason the sanctuary is where every other commitment in this game gets made, not the battlefield. You didn't get handed a skill mid-fight and move on without a second thought. You stood in front of everything four different kinds of mastery had earned you, and you chose, deliberately, what to spend it on.

## Detailed Design

### Core Rules

#### Group 1: Points & Archetype Pools

1. The hero has **4 skill tree point pools**, one per archetype (`physical` / `ranged` / `elemental` / `support`), each a non-negative integer starting at 0. Points are **per-adventure** (reset to 0 on a new game), matching the existing per-adventure persistence of skills themselves (`hero.md` Rule 11).

2. **Tower Mastery's accrual is unchanged.** `mastery_time` accumulation per `build_signature` (`tower-mastery.md` Rules 1, 3, 10, 12), the proximity radius, and the catalogue's per-entry `mastery_threshold_seconds` all continue exactly as documented there — **including Rule 14, "`mastery_time` accrual does not stop once a skill unlocks... to support a future next-tier skill on the same build signature without needing a data migration."** This GDD is that future consumer: Rule 3 below is built directly on top of Rule 14's existing extensibility hook, not a new accrual mechanism.

3. **Revises `tower-mastery.md` Rule 13.** Each catalogue entry's `mastery_threshold_seconds` now grants **repeating** points, not a single one-time unlock: every time `mastery_time[build_signature]` crosses another whole multiple of that entry's `mastery_threshold_seconds`, Tower Mastery grants the hero **1 skill tree point** in that build signature's Foundation `archetype` and emits `skill_tree_point_earned(archetype, source_tower_id)` (new event, same "representative live tower_id" rule as the old `skill_unlocked`) — instead of ever emitting `skill_unlocked` directly. Tower Mastery's own `_unlocked_skills` dictionary (`tower-mastery.md`'s persisted state) is **retired by this revision**, replaced by a new persisted counter `points_granted_count[build_signature]: int`, starting at 0. See Formula 1 for the exact multiple-crossing arithmetic and Dependencies for the save-migration note.

4. Because points are archetype-keyed rather than `build_signature`-keyed, two different build signatures sharing an archetype (e.g., two distinct physical-archetype tower builds) both feed the same `physical` pool — mastering either (or both), and continuing to master either past its first threshold, both contribute points toward the same physical-branch chain. This is also what makes cross-archetype allocation (Player Fantasy) a real, uneven decision in practice: a player who spent the mission camped beside physical towers banks physical points faster than support points, regardless of how many nodes each chain has.

5. Points are **not** consumed the instant they're earned. They accumulate in the pool until the player spends them (Group 3). There is no cap on banked points — this is a deliberate divergence from `resource-economy.md`'s comparable capped-currency convention, acceptable here because unlike a material stack, an uncapped skill tree point pool cannot be spent on anything but this system's own bounded 4-node chains, so there is no external economy for it to distort.

#### Group 2: Node Chain Structure

6. Each archetype has a **fixed, linear, ordered chain of exactly 4 nodes**: `[Minor_1, Skill_1, Minor_2, Skill_2]`. `Skill_1` and `Skill_2` correspond 1:1 to that archetype's two existing catalogued skills from `hero-skill-build.md`'s Alpha-scope catalogue (e.g. physical: `phys_cleave` then `phys_bulwark`, in catalogue order). `Minor_1` and `Minor_2` are new, tree-only nodes — small stat or passive bonuses, content-authoring deferred (Group 4).

7. A node is purchasable if and only if: (a) its archetype's point pool has ≥1 point, AND (b) it is the first not-yet-unlocked node in its chain — i.e. its predecessor (if any) is already unlocked. `Minor_1` has no predecessor and is always purchasable once ≥1 point exists in that archetype.

8. Purchasing a node deducts exactly 1 point from that archetype's pool and marks the node permanently unlocked for the remainder of the playthrough. Unlocking is **never** reversible or re-purchasable — same one-way permanence precedent as skills themselves.

9. **When the purchased node is a `Skill` node** (not `Minor`), the Skill Tree System emits `skill_unlocked(skill_id, source_tower_id)` at the moment of purchase, using the node's mapped `skill_id` and `source_tower_id = -1` (sentinel — see Edge Cases for why a live tower reference is never available at spend time). This is the **only** place `skill_unlocked` now fires; Tower Mastery no longer emits it directly (Rule 3).

10. **When the purchased node is a `Minor` node**, no `skill_unlocked` event fires. The Skill Tree System instead emits a new `skill_tree_node_unlocked(archetype, node_index)` event (for Mission HUD / Encyclopedia / UI consumers that want minor-node visibility — see Dependencies) and applies the node's stat/passive effect directly (effect format deferred, Group 4, same precedent as `effect_data`).

#### Group 3: Spend Location

11. Skill tree points may be spent **only at Sanctuary, between missions** — never mid-mission (`SCOUT`, `WAVE_ACTIVE`, or `INTERMISSION`). This matches the existing lock precedent already shared by Hero Skill Build slot changes (Rule 4), Tower component slots (`tower.md` Rule 3), and Hero class designation (`hero.md` Rule 18): every player-configurable loadout system in the game commits at Sanctuary, not mid-fight.

12. Points earned mid-mission are simply added to the relevant pool immediately (Rule 3) and sit banked, spendable the next time the player is at Sanctuary. There is no cap on banked, unspent points.

#### Group 4: Deferred Content

13. `Minor_1`/`Minor_2` node effect data (the actual stat/passive bonus each grants) is deferred content-authoring work, same precedent as `hero-skill-build.md`'s `effect_data` field and Tower's component effect fields — this GDD specifies the tree's *structure and economy*, not the minor nodes' numeric tuning. 8 total minor nodes (2 per archetype × 4 archetypes) need this content before Alpha completion. **Unlike `effect_data`'s deferral, this one is load-bearing**: Rule 7 gates `Skill_1` behind `Minor_1` already being purchased, so undesigned Minor node content blocks meaningful playtesting of the entire chain, not just that node's own flavor. Minor node content must be authored *before* implementation begins, not left as a trailing content pass after the system ships.

### States and Transitions

No new hero states. The tree's own per-node state is a simple one-way `locked → unlocked` transition (Rule 8) — the same one-way boolean-latch shape the rest of this project's permanent-unlock systems already use (e.g. Hero Skill Build's own learned-skill flags).

### Interactions with Other Systems

| System | Direction | What crosses |
|---|---|---|
| Tower Mastery | Tower Mastery → Skill Tree | `skill_tree_point_earned(archetype, source_tower_id)` (new; replaces the old direct `skill_unlocked` emission from Tower Mastery) |
| Hero Skill Build System | Skill Tree → Hero Skill Build | `skill_unlocked(skill_id, source_tower_id)` — unchanged payload shape, now sourced from node purchase instead of mastery threshold |
| Mission HUD | Skill Tree → Mission HUD | `skill_tree_point_earned` (live "you earned a point" notification, mid-mission — same notification *slot* Mission HUD already reserves for `skill_unlocked`, since a raw skill unlock can no longer happen mid-mission); `skill_tree_node_unlocked` optional, Sanctuary-only, HUD likely doesn't need it |
| Encyclopedia | Skill Tree → Encyclopedia | `skill_unlocked` (unchanged consumption), `skill_tree_node_unlocked` (new — for logging minor-node unlocks too, if Encyclopedia wants full tree completion tracking) |
| Sanctuary UI | Skill Tree ↔ Sanctuary UI | New screen (or a panel within an existing Sanctuary screen) exposing the 4 chains, current pool counts, and a purchase action per unlockable node |

## Formulas

### Formula 1: Point Grant (revises `tower-mastery.md` Formula 3)

```
points_earnable = floor(mastery_time[build_signature] / mastery_threshold_seconds)
new_points = points_earnable - points_granted_count[build_signature]

if new_points > 0:
    archetype = catalogue[build_signature].archetype
    for i in range(new_points):
        skill_tree_points[archetype] += 1
        emit skill_tree_point_earned(archetype, source_tower_id)
    points_granted_count[build_signature] = points_earnable
```

`source_tower_id` uses the same "lowest live `tower_id` sharing this signature" rule as `tower-mastery.md` Rule 12/13. `new_points` is almost always 0 or 1 per frame given per-physics-frame evaluation and realistic accrual rates, but the loop form is correct even if multiple thresholds are crossed in one evaluation (e.g. after a long period without an update) — each crossing fires its own `skill_tree_point_earned` event rather than silently batching them into a single grant, so Mission HUD's live notification (Dependencies) shows one event per point, matching how a player would expect to see it.

**A build signature's income is not capped.** As long as the hero keeps mastering the same signature (Rule 2/`tower-mastery.md` Rule 14), `points_earnable` keeps growing and keeps producing new points — this is what makes a 4-point archetype chain actually completable from as few as 1 mastered build signature per archetype, not just from mastering many distinct signatures.

### Formula 2: Node Purchase

```
if all_nodes_unlocked(chain[archetype]):
    purchase_allowed = false   # no locked node exists in this chain — nothing to buy, not an error
else:
    node = chain[archetype][next_locked_index]
    purchase_allowed = (skill_tree_points[archetype] >= 1) AND (node == first_locked_node_in_chain)

if purchase_allowed and player_confirms:
    skill_tree_points[archetype] -= 1
    node.unlocked = true
    if node.type == "Skill":
        emit skill_unlocked(node.skill_id, source_tower_id = -1)
    else:  # "Minor"
        apply node.effect_data
        emit skill_tree_node_unlocked(archetype, node.index)
```

The `all_nodes_unlocked` guard is evaluated **before** indexing into the chain — `next_locked_index` is only well-defined when at least one node is still locked, and this check must run first so a fully-cleared chain never attempts an out-of-bounds lookup. This is a real correctness requirement, not just a UX nicety: since Rule 3's income is uncapped (a build signature keeps granting points past chain completion), every archetype legitimately reaches "fully unlocked, more points still incoming" as normal end-state play, not an edge case that's rare enough to ignore.

### Worked Example

Player masters a physical-archetype tower build (`found_bulwark_t2`, `mastery_threshold_seconds = 60`) mid-mission; `mastery_time` crosses 60s for the first time. `points_earnable = floor(60/60) = 1`, `points_granted_count` was 0, so `new_points = 1`.
→ `skill_tree_point_earned("physical", source_tower_id=7)` fires once. `skill_tree_points["physical"]` goes from 0 → 1. `points_granted_count[build_signature]` set to 1.
→ Mission continues; no chain node is purchasable mid-mission (Rule 11) regardless of pool balance.
→ At the next Sanctuary visit, the physical chain shows `Minor_1` as the only purchasable node (Rule 7 — `Skill_1`/`Minor_2`/`Skill_2` are all still locked behind it). Player spends the 1 banked point on `Minor_1`. `skill_tree_points["physical"]` goes to 0; `Minor_1.unlocked = true`; `skill_tree_node_unlocked("physical", 0)` fires.
→ The player keeps mastering the *same* `found_bulwark_t2` build signature across two more missions. `mastery_time` reaches 190s total. `points_earnable = floor(190/60) = 3`, `points_granted_count` was 1, so `new_points = 2` — two more `skill_tree_point_earned("physical", ...)` events fire (one per crossing, per Formula 1), `points_granted_count` set to 3. `skill_tree_points["physical"] = 2` banked.
→ Player returns to Sanctuary with `skill_tree_points["physical"] = 2` and spends both in order: `Skill_1` (fires `skill_unlocked("phys_cleave", -1)`), then `Minor_2` (fires `skill_tree_node_unlocked("physical", 2)`). `Skill_2` (`phys_bulwark`) remains locked until a 4th point is earned (from further mastery of this or any other physical-archetype build) and spent.

## Edge Cases

- **`skill_unlocked`'s `source_tower_id` has no live tower at spend time.** The event's original purpose (`tower-mastery.md`: "identifies which on-screen tower instance triggered this update, for Mission HUD highlighting") cannot be satisfied when the firing context is a Sanctuary purchase — there is no live mission, no `tower_id`, nothing on screen to highlight. Resolution: `source_tower_id = -1` (sentinel, "no live tower context"). Mission HUD's existing `skill_unlocked` consumer (`tower-mastery.md` Dependencies: "unlock notifications") must tolerate `-1` gracefully — in practice this is moot, since Mission HUD isn't mounted at Sanctuary at all; only Hero Skill Build's library-add consumption (which never used `source_tower_id` for anything, only `skill_id`) and Encyclopedia's logging need to handle the sentinel.
- **A build signature keeps being mastered past its first threshold crossing.** This is not a special case — Formula 1's `floor(mastery_time / mastery_threshold_seconds)` naturally keeps producing new points at each subsequent whole multiple, `mastery_progress_updated` keeps firing clamped at 100% for HUD display purposes (unchanged from `tower-mastery.md` Rule 12), and `points_granted_count` simply keeps climbing alongside `points_earnable`. This is the *intended* primary income path (Rule 3), not a no-op.
- **All 4 nodes in a chain are already unlocked, hero keeps earning points in that archetype.** Because income is uncapped (previous bullet), this is a normal, expected end-state for a well-mastered archetype, not a rare edge case. Formula 2's `all_nodes_unlocked` guard makes this an explicit, always-rejected, never-erroring purchase attempt. Points keep banking with no purchasable node to spend them on — worth a UI "maxed" affordance, but not a rule change; this GDD does not cap pool size.
- **Player has points in an archetype whose chain is fully unlocked, but 0 points in an archetype with locked nodes.** Pools are strictly per-archetype and never fungible across archetypes (Rule 1, Rule 4) — there is no conversion or overflow mechanism. This is an intentional consequence of the archetype-locked design chosen over a shared pool, not an oversight.
- **Hero dies mid-mission with unspent banked points.** No interaction — banked points are adventure-scoped state (Rule 1), not mission-scoped, and survive hero death exactly like already-unlocked skills do today (`hero.md` Rule 11's per-adventure persistence covers this GDD's state too, per Dependencies). See AC-6.
- **A save is loaded mid-Sanctuary-visit, between a node purchase's pool deduction and its unlocked-flag write.** These two mutations (Formula 2's `skill_tree_points[archetype] -= 1` and `node.unlocked = true`) must be applied and persisted as a single atomic operation from Save & Persistence's perspective — never two separate `register()`-observable states a load could land between. This mirrors the same atomicity the existing Inventory/Equipment Forge rune-application path already requires (`equipment-forge.md`); no new precedent, but worth stating explicitly here since a partial application would either resurrect a spent point or unlock a node for free.

## Dependencies

### Upstream Dependencies (systems this GDD depends on)

- **Tower Mastery** — supplies `skill_tree_point_earned` (this GDD's only trigger for point income); this GDD's Group 1 is a direct revision of `tower-mastery.md` Rule 13/Formula 3 and must ship together with that document's corresponding edit, not as a standalone addition. **Migration note**: Tower Mastery's existing persisted `_unlocked_skills: Dictionary[String, bool]` (keyed by `skill_id`) is retired by this revision and replaced by `points_granted_count: Dictionary[StringName, int]` (keyed by `build_signature` — a different key space entirely, not a rename). Any save written before this revision ships carries `_unlocked_skills` data with no successor field populated; since this project is pre-Alpha with no shipped save-compatibility guarantee yet (no ADR establishes one), the resolution is: this revision requires a save-format bump, old saves are not expected to migrate `_unlocked_skills` state into `points_granted_count` — a player's already-unlocked skills before this ships would need to be treated as already-purchased tree nodes at save-load time as a one-time compatibility shim if backward compatibility is ever required, but that shim is explicitly out of scope for this GDD and is Save & Persistence's call to make if/when it becomes a real constraint.
- **EventBus** — new events `skill_tree_point_earned(archetype, source_tower_id)` and `skill_tree_node_unlocked(archetype, node_index)` need catalogue entries in `event-bus.md`. **The existing `skill_unlocked` catalogue entry also needs updating**, not just the two new events added alongside it — its current description ("Proximity threshold reached — skill added to learned library") is factually wrong once this GDD ships; it must read something like "Skill tree node purchased at Sanctuary — skill added to learned library" to match Rule 9's actual trigger.
- **Save & Persistence** — needs a new `restore_order` slot. This system's own persisted state (4 point-pool integers, 8 per-archetype-chain `unlocked` booleans) is fully self-contained — restoring it never reads any other system's *restored* state, only its own previously-saved blob (matching Save & Persistence's own stated contract: "the system does not interpret or validate the data it stores; each owning system is responsible for correct data"). Cross-system reads (Tower Mastery's `points_granted_count`, Hero Skill Build's skill list) only happen at *live* grant/spend time, never at restore time — so this system has no strict ordering dependency on either of them and does **not** need to resolve `save-persistence.md`'s pre-existing open question about whether Hero Skill Build's restore needs Tower Mastery's state already restored (that question is inherited, unaffected, and still open — not this GDD's to close). Proposed `restore_order = 37` (Advanced Feature Layer; 30=Hero, 31=Hero Skill Build, 32=Equipment Forge, 33=Building Upgrade, 34=Tower Mastery, 35=Encyclopedia, 36=Tower Assembly are all already taken).
- **Sanctuary UI** — this GDD needs a mount point (new screen or panel) inside whatever Sanctuary UI already governs screen navigation (`sanctuary-ui.md`). Functional (non-visual) requirement, independent of the deferred art/layout pass (OQ-3): the mount point must expose each archetype's current pool balance and each chain's current unlock position at a glance — a player banking points needs to see "1 more spend and I reach the next skill" without needing to reason about it from memory.

### Downstream Dependents (systems that depend on this GDD)

- **Hero Skill Build System** — unaffected in its own rules; continues consuming `skill_unlocked` exactly as documented in `hero-skill-build.md`. Only the *trigger timing* changes (now Sanctuary-gated instead of mid-combat-automatic) — worth a one-line cross-reference note in that document once this GDD is Approved, since a reader following `skill_unlocked`'s origin would otherwise land on the now-stale `tower-mastery.md` Rule 13.
- **Mission HUD** — needs a new live notification treatment for `skill_tree_point_earned` (replacing its existing `skill_unlocked` mid-mission notification, since that event no longer fires mid-mission) and no longer needs to render a mid-mission "skill unlocked" toast — that moment moves to Sanctuary.
- **Encyclopedia** — gains an optional new logging surface (`skill_tree_node_unlocked` for minor nodes); existing `skill_unlocked` logging is unaffected.

### Notes

This GDD is written to be **land-together** with a corresponding, minimal revision to `tower-mastery.md` Rule 13 — it does not stand alone as an additive system. Implementation should treat the two documents as one change set.

## Tuning Knobs

| Knob | Current Value | Safe Range | Affects |
|---|---|---|---|
| Nodes per chain | 4 (fixed: Minor, Skill, Minor, Skill) | 3–6 (must stay even if the Minor/Skill alternation is kept; must include exactly 2 Skill nodes to match the existing 2-skill-per-archetype catalogue unless `hero-skill-build.md`'s catalogue also grows) | Total playthrough-length investment per archetype; too few nodes trivializes the "sequence, not a moment" Player Fantasy, too many delays skill access unreasonably |
| Point cost per node | 1 (fixed, uniform) | Could vary per node (e.g. Skill nodes cost 2) for a steeper curve | Pacing of chain completion relative to mastery-threshold pacing already tuned in `tower-mastery.md` |
| Minor node effect magnitude | Deferred (Group 4) | — | Whether Minor nodes feel like meaningful waypoints or filler — a content-authoring decision, not a structural one |

## Acceptance Criteria

1. Crossing a whole multiple of a catalogued `build_signature`'s `mastery_threshold_seconds` (first crossing or any subsequent one, per Formula 1's `floor(mastery_time / mastery_threshold_seconds)`) grants exactly 1 point to that signature's archetype pool per crossing and emits `skill_tree_point_earned` — with the correct archetype and a `source_tower_id` equal to the lowest live `tower_id` sharing that `build_signature` (per `tower-mastery.md` Rule 12/13) — once per crossing, never batched. Tower Mastery never emits the old `skill_unlocked` directly.
2. A node is purchasable if and only if its archetype pool has ≥1 point AND it is the first locked node in its chain; attempting to purchase a locked-behind-a-predecessor node, or a node with 0 available points, is rejected without mutating any state.
3. Purchasing a `Skill` node deducts 1 point, marks it unlocked, and fires `skill_unlocked(skill_id, -1)` with the correct `skill_id` for that node — verified for all 8 Skill nodes (2 × 4 archetypes) against `hero-skill-build.md`'s catalogue.
4. Purchasing a `Minor` node deducts 1 point, marks it unlocked, applies its effect, and fires `skill_tree_node_unlocked` — never fires `skill_unlocked`.
5. No node purchase is possible while `mission_phase` is `SCOUT`, `WAVE_ACTIVE`, or `INTERMISSION` — only at Sanctuary.
6. Points earned mid-mission persist (banked) into the next Sanctuary visit, including points banked at the moment of hero death; a save/load cycle (including the checkpoint save triggered by mission defeat, per `save-persistence.md` Core Rule 11) preserves both banked points and unlocked-node state exactly, with no window in which a load can observe a purchase's pool deduction without its corresponding unlocked-flag write, or vice versa (Edge Cases' atomicity note).
7. Archetype pools never go negative and are never fungible across archetypes — spending physical points never reduces any other archetype's pool.
8. A new adventure (new game) resets all 4 pools to 0 and all nodes to locked, matching the existing per-adventure reset of skills.
9. Attempting a purchase in an archetype whose chain is already fully unlocked is rejected without error or state mutation, regardless of pool balance — verified this does not throw, crash, or attempt an out-of-bounds chain index (Formula 2's `all_nodes_unlocked` guard).
10. `skill_unlocked(skill_id, -1)` fired from a node purchase is consumed without error by both existing subscribers, Hero Skill Build and Encyclopedia — neither performs a live-tower lookup or highlighting action using the `-1` sentinel.
11. This GDD's implementation is verified to ship together with `tower-mastery.md` Rule 13's corresponding revision — specifically, a test confirming Tower Mastery's code path no longer contains any `skill_unlocked`-emitting branch at all (AC-1's "never emits" clause is not just behaviorally true at runtime, the dead code path itself is removed, not merely unreachable).

## Open Questions

- **OQ-1**: Exact Minor node effect content (Group 4, Tuning Knobs row 3) — deferred to a future content-authoring pass, same as `effect_data` elsewhere in this project.
- **OQ-2**: Should `hero-skill-build.md` gain a formal cross-reference note pointing at this document once Approved? (Dependencies section already flags this — low-risk, likely yes, but not this GDD's call to make unilaterally since it edits another Approved document.)
- **OQ-3**: Visual/UI treatment of the tree itself (node layout, connector art, locked/unlocked states) is explicitly out of scope for this GDD — covered by the separate art-generation delegation plan discussed with the user, once this document is Approved and node count/structure are final.
