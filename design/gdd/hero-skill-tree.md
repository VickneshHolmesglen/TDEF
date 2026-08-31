# Hero Skill Tree

> **Status**: Draft — new (not yet reviewed)
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-08-31
> **Implements Pillar**: Everything Connects · Mastery-as-Vindication
> **Solves**: Gives Tower Mastery's mid-combat proximity investment a deliberate, player-authored spend decision instead of an automatic, unasked-for unlock. Sits between Tower Mastery (unchanged accrual, revised output) and the existing Hero Skill Build System (unchanged consumer).
> **Revises an Approved GDD**: `tower-mastery.md` Rule 13 changes from "crossing a mastery threshold directly unlocks a skill" to "crossing a mastery threshold grants one spendable skill tree point." Rules 1–12 and 14 (accrual, proximity, per-`build_signature` tracking, past-100% continuation) are unchanged. See Dependencies.

## Overview

The Hero Skill Tree is a per-adventure spend-progression layer inserted between Tower Mastery and the existing Hero Skill Build System. It replaces Tower Mastery's automatic "100% mastery = skill unlocked" behavior with a spendable point economy: crossing a mastery threshold grants the hero one skill tree point in the mastered tower's archetype, rather than instantly handing over a specific skill. The player then spends points, at Sanctuary between missions, to advance one of four fixed, linear, archetype-keyed node chains (physical / ranged / elemental / support) — each chain interleaving minor stat/passive nodes with that archetype's two existing catalogued skills (`hero-skill-build.md`), unlocked strictly in order. A node that represents a real skill still fires the existing `skill_unlocked(skill_id, source_tower_id)` event, unchanged in shape, the moment it's purchased — so the Hero Skill Build System, Mission HUD, and Encyclopedia all keep consuming it exactly as they do today. Only the trigger moves: from "automatic, the instant mastery crosses 100%" to "player spend, gated by an earned point and an already-unlocked predecessor node."

## Player Fantasy

> You used to earn a skill just by standing your ground. Fight beside the same kind of tower long enough, and the game simply handed you what it had to teach — automatic, unasked-for, whatever came next on the list.
>
> Now standing your ground earns you something smaller and more honest: a point. Proof that you mastered this archetype a little further, with no promise yet of what it buys. The promise is yours to write. You carry that proof home to the sanctuary, and there — quiet, unhurried, no wave bearing down on you — you decide what your mastery was actually for.
>
> The tree in front of you does not let you skip ahead. Every path starts at its first step, and every step after that is earned only by having already taken the one before it. You cannot buy the skill at the end of a path without first buying the small, unglamorous thing that comes before it — the stat node nobody brags about, the passive nobody screenshots. That is deliberate. It is the game telling you: mastery is not a moment, it is a sequence, and you don't get the ending without the middle.
>
> So the choice that used to happen *for* you now happens *because of* you. Four archetypes, four paths, and every point you spend is a point you're choosing not to spend somewhere else — the same slot-scarcity that makes your active loadout mean something now governs how your mastery itself takes shape. You don't just become powerful. You become powerful in the specific order you decided to become powerful in — and that decision only ever gets asked of you when the fighting has stopped.

## Detailed Design

### Core Rules

#### Group 1: Points & Archetype Pools

1. The hero has **4 skill tree point pools**, one per archetype (`physical` / `ranged` / `elemental` / `support`), each a non-negative integer starting at 0. Points are **per-adventure** (reset to 0 on a new game), matching the existing per-adventure persistence of skills themselves (`hero.md` Rule 11).

2. **Tower Mastery's accrual is unchanged.** `mastery_time` accumulation per `build_signature` (`tower-mastery.md` Rules 1, 3, 10, 12, 14), the proximity radius, and the catalogue's per-entry `mastery_threshold_seconds` all continue exactly as documented there. Only what happens *at* the threshold changes (Rule 3 below).

3. **Revises `tower-mastery.md` Rule 13.** The instant `mastery_time[build_signature]` first reaches or exceeds that catalogue entry's `mastery_threshold_seconds` (gated by a new one-time-per-entry flag, `point_granted[build_signature]`, not yet `true` — replacing the old `unlocked_skills[skill_id]` gate at this point in the pipeline, since granting a point is no longer the same event as unlocking the skill), Tower Mastery grants the hero **1 skill tree point** in that build signature's Foundation `archetype`, and emits `skill_tree_point_earned(archetype, source_tower_id)` (new event, same "representative live tower_id" rule as the old `skill_unlocked`) instead of `skill_unlocked`. `point_granted[build_signature]` is then set `true` and never re-fires for that signature, mirroring the old gate's permanence exactly.

4. Because points are archetype-keyed rather than `build_signature`-keyed, two different build signatures sharing an archetype (e.g., two distinct physical-archetype tower builds) both feed the same `physical` pool — mastering either (or both) contributes points toward the same physical-branch chain.

5. Points are **not** consumed the instant they're earned. They accumulate in the pool until the player spends them (Group 3).

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

13. `Minor_1`/`Minor_2` node effect data (the actual stat/passive bonus each grants) is deferred content-authoring work, same precedent as `hero-skill-build.md`'s `effect_data` field and Tower's component effect fields — this GDD specifies the tree's *structure and economy*, not the minor nodes' numeric tuning. 8 total minor nodes (2 per archetype × 4 archetypes) need this content before Alpha completion.

### States and Transitions

No new hero states. The tree's own per-node state is a simple one-way `locked → unlocked` transition (Rule 8), identical in shape to Tower Mastery's `unlocked_skills` boolean-latch pattern.

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
point_earned_fires = (mastery_time[build_signature] >= mastery_threshold_seconds)
                      AND (point_granted[build_signature] != true)

if point_earned_fires:
    archetype = catalogue[build_signature].archetype
    skill_tree_points[archetype] += 1
    point_granted[build_signature] = true
    emit skill_tree_point_earned(archetype, source_tower_id)
```

`source_tower_id` uses the same "lowest live `tower_id` sharing this signature" rule as `tower-mastery.md` Rule 12/13 — this formula only changes what fires and what state it sets, not how the representative tower is chosen.

### Formula 2: Node Purchase

```
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

### Worked Example

Player masters a physical-archetype tower build (`found_bulwark_t2`) mid-mission; `mastery_time` crosses that catalogue entry's `mastery_threshold_seconds`.
→ `skill_tree_point_earned("physical", source_tower_id=7)` fires. `skill_tree_points["physical"]` goes from 0 → 1.
→ Mission continues; no chain node is purchasable mid-mission (Rule 11) regardless of pool balance.
→ At the next Sanctuary visit, the physical chain shows `Minor_1` as the only purchasable node (Rule 7 — `Skill_1`/`Minor_2`/`Skill_2` are all still locked behind it). Player spends the 1 banked point on `Minor_1`. `skill_tree_points["physical"]` goes to 0; `Minor_1.unlocked = true`; `skill_tree_node_unlocked("physical", 0)` fires.
→ Later, having mastered two more physical-archetype builds (2 more points banked), the player returns to Sanctuary with `skill_tree_points["physical"] = 2` and spends both in order: `Skill_1` (fires `skill_unlocked("phys_cleave", -1)`), then `Minor_2` (fires `skill_tree_node_unlocked("physical", 2)`). `Skill_2` (`phys_bulwark`) remains locked until a 3rd point is spent.

## Edge Cases

- **`skill_unlocked`'s `source_tower_id` has no live tower at spend time.** The event's original purpose (`tower-mastery.md`: "identifies which on-screen tower instance triggered this update, for Mission HUD highlighting") cannot be satisfied when the firing context is a Sanctuary purchase — there is no live mission, no `tower_id`, nothing on screen to highlight. Resolution: `source_tower_id = -1` (sentinel, "no live tower context"). Mission HUD's existing `skill_unlocked` consumer (`tower-mastery.md` Dependencies: "unlock notifications") must tolerate `-1` gracefully — in practice this is moot, since Mission HUD isn't mounted at Sanctuary at all; only Hero Skill Build's library-add consumption (which never used `source_tower_id` for anything, only `skill_id`) and Encyclopedia's logging need to handle the sentinel.
- **A build signature's catalogue entry is already `point_granted`, hero keeps standing near it.** Same no-op as `tower-mastery.md` Rule 15 today — `mastery_time` keeps accruing past threshold (unchanged Rule 14), `mastery_progress_updated` keeps firing clamped at 100%, but `skill_tree_point_earned` never re-fires for that signature. Becomes meaningful only if a future next-tier catalogue entry is authored for that signature, identical to the existing precedent.
- **All 4 nodes in a chain are already unlocked, hero keeps earning points in that archetype.** Points keep banking in the pool with no purchasable node to spend them on — not an error, just a currently-inert surplus. Worth a UI affordance (a "maxed" badge on a fully-unlocked chain) but not a rule change; this GDD does not cap pool size.
- **Player has points in an archetype whose chain is fully unlocked, but 0 points in an archetype with locked nodes.** Pools are strictly per-archetype and never fungible across archetypes (Rule 1, Rule 4) — there is no conversion or overflow mechanism. This is an intentional consequence of the archetype-locked design chosen over a shared pool, not an oversight.
- **Hero dies mid-mission with unspent banked points.** No interaction — banked points are adventure-scoped state (Rule 1), not mission-scoped, and survive hero death exactly like already-unlocked skills do today (`hero.md` Rule 11's per-adventure persistence covers this GDD's state too, per Dependencies).

## Dependencies

### Upstream Dependencies (systems this GDD depends on)

- **Tower Mastery** — supplies `skill_tree_point_earned` (this GDD's only trigger for point income); this GDD's Group 1 is a direct revision of `tower-mastery.md` Rule 13/Formula 3 and must ship together with that document's corresponding edit, not as a standalone addition.
- **EventBus** — new events `skill_tree_point_earned(archetype, source_tower_id)` and `skill_tree_node_unlocked(archetype, node_index)` need catalogue entries in `event-bus.md`, matching the existing `skill_unlocked`/`mastery_progress_updated` entries' format.
- **Save & Persistence** — 4 point-pool integers, `point_granted[build_signature]` (or equivalent per-catalogue-entry flag, likely already saved as part of Tower Mastery's existing persisted state), and per-archetype-chain `unlocked` booleans (8 total minor-node flags + the existing skill-unlock flags Hero Skill Build already persists) all need save-slot coverage.
- **Sanctuary UI** — this GDD needs a mount point (new screen or panel) inside whatever Sanctuary UI already governs screen navigation (`sanctuary-ui.md`).

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

1. Crossing a mastery threshold for any catalogued `build_signature` grants exactly 1 point to that signature's archetype pool, exactly once, and emits `skill_tree_point_earned` with the correct archetype and a valid representative `source_tower_id` — never emits the old `skill_unlocked` directly from Tower Mastery.
2. A node is purchasable if and only if its archetype pool has ≥1 point AND it is the first locked node in its chain; attempting to purchase a locked-behind-a-predecessor node, or a node with 0 available points, is rejected without mutating any state.
3. Purchasing a `Skill` node deducts 1 point, marks it unlocked, and fires `skill_unlocked(skill_id, -1)` with the correct `skill_id` for that node — verified for all 8 Skill nodes (2 × 4 archetypes) against `hero-skill-build.md`'s catalogue.
4. Purchasing a `Minor` node deducts 1 point, marks it unlocked, applies its effect, and fires `skill_tree_node_unlocked` — never fires `skill_unlocked`.
5. No node purchase is possible while `mission_phase` is `SCOUT`, `WAVE_ACTIVE`, or `INTERMISSION` — only at Sanctuary.
6. Points earned mid-mission persist (banked) into the next Sanctuary visit; a save/load cycle preserves both banked points and unlocked-node state exactly.
7. Archetype pools never go negative and are never fungible across archetypes — spending physical points never reduces any other archetype's pool.
8. A new adventure (new game) resets all 4 pools to 0 and all nodes to locked, matching the existing per-adventure reset of skills.

## Open Questions

- **OQ-1**: Exact Minor node effect content (Group 4, Tuning Knobs row 3) — deferred to a future content-authoring pass, same as `effect_data` elsewhere in this project.
- **OQ-2**: Should `hero-skill-build.md` gain a formal cross-reference note pointing at this document once Approved? (Dependencies section already flags this — low-risk, likely yes, but not this GDD's call to make unilaterally since it edits another Approved document.)
- **OQ-3**: Visual/UI treatment of the tree itself (node layout, connector art, locked/unlocked states) is explicitly out of scope for this GDD — covered by the separate art-generation delegation plan discussed with the user, once this document is Approved and node count/structure are final.
