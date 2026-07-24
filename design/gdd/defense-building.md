# Defense Building System

> **Status**: Needs Revision (`/design-review --depth lean` 2026-07-17 found AC-40 asserted a `crafting.md` tech-ID mapping that doesn't actually exist there — reworded same-day to match Core Rule 3's own honest "Assumption flagged" framing rather than asserting an unverifiable fact. Menagerie's Habitat Expansion contract independently verified to match exactly, no changes needed there.)
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-07-17
> **Implements Pillar**: The Sanctuary Is Your Statement · Everything Connects
> **Delivers**: Menagerie's exact 3-tier Habitat Expansion structure contract; Crafting's 5-node tech-gating chain. **Known gaps**: gold-balance validation ownership (shared, pre-existing gap with Tower System, not introduced here); Watchtower structure's gameplay effect is deliberately undefined scaffolding. See Open Questions.

## Overview

The Defense Building System is the sanctuary's foundation layer: it is where the player spends accumulated materials and gold between missions to permanently expand the sanctuary itself, both as an unlockable technology tree and as a set of constructed physical structures. Technically, it owns two coupled progression surfaces. The first is a tech tree of unlockable nodes; unlocking a node emits `tech_unlocked`, the event other systems subscribe to as the gate on their own content — a Crafting recipe, for example, stays unbuildable until the tech node that governs it fires `tech_unlocked` (Everything Connects: this system is the permanent-progression key that opens doors for the rest of the game, the standing-investment counterpart to the per-mission access that Resource Economy's materials provide). The second is a catalogue of Sanctuary structures the player constructs, each of which provides a passive capacity increase or bonus to another system rather than any combat effect of its own — e.g. a Habitat Expansion structure that raises the Menagerie's creature-housing capacity (per `menagerie.md`). Every unlock and every structure is a permanent, persistent investment written to the save: per `game-concept.md`'s rule that Sanctuary technology unlocks are always persistent, nothing built here is ever lost, even on mission defeat. Like the other Sanctuary systems it is between-runs only — research and construction happen in the calm of the sanctuary, never mid-mission — and all cross-system effects flow through the EventBus rather than direct references. Player-facing, it is the slowest and most permanent form of growth in the game: the layer where the sanctuary visibly and structurally becomes larger and more capable as a direct, irreversible consequence of which branches the player chose to pursue — the ground that raises every other system's ceiling, and that no defeat can take back.

## Player Fantasy

> Everything else you build can be spent, broken, or staked. This is the one thing you build that only ever grows.
>
> There is a particular moment this system exists for, and it is not on the field — it is the walk back into the sanctuary after a mission, and it is at its purest after a mission you *lost*. You failed. The wave broke through, the run ended, and you came home with less than you carried out. And the new wing is still there. The tech you unlocked three missions ago is still unlocked. The structure you raised last week still stands exactly where you put it, one room larger than the sanctuary used to be. Nothing about the defeat reached it. This is the one corner of the game where the ground does not move — where a loss costs you the mission and *only* the mission, and everything you have built into the sanctuary itself is held below the reach of losing. Every other system asks you to risk something into a fight. This one asks you to put something down that no fight can take back.
>
> That is what makes it different from everything else you build, and the difference is permanence. A crafted component is spent the moment it becomes a tower. A constellation holds only as long as its shape survives the wave. A deck is staked on a single run and lived through without a take-back. Even the menagerie, the most faithful of them, fades if you look away. Every one of those is *conditional* — it can be consumed, broken, gambled, or neglected back down. The sanctuary's structure is the one investment that has no downward direction at all. You do not spend it, you do not risk it, you cannot lose it, and it does not decay. It only accumulates. This is not the authorship of a machine, or the origination of a piece, or the wager of a run. It is *foundation* — the slow, irreversible raising of the thing all of that other work is done inside of.
>
> And it does not arm you. That is the strange thing about the most fundamental system in the sanctuary: it never places a tower, never fires a shot, never touches the field. What it does instead is open doors for everyone else. A crafting recipe stays greyed-out and unreachable until the tech node that governs it unlocks — and this is the system that unlocks it. A habitat cannot house another creature until the structure that expands it is built — and this is the system that builds it. Every branch you drive is a set of new possibilities lighting up across systems you were not even looking at: you invest here, and the Crafting panel grows, the Menagerie's walls push outward, and the shape of what you are *allowed to do* everywhere else widens. It is the key that opens doors for the whole sanctuary — the quiet layer underneath the game whose entire product is other systems' reach.
>
> Which is why, more than any other system, this one *is* the sanctuary — literally, structurally: the walls and wings and unlocked branches that make your base the specific shape it is. Two players can finish the same ten missions and walk home to sanctuaries that neither look nor function alike, because they laid different ground — one drove a tech branch deep, one raised structures the other never touched, and the buildings prove it. Nothing here is cosmetic and nothing here resets. The sanctuary you are standing in is a physical record of every permanent choice you have committed to, stacked one on another and never once rolled back. That is the recognition this system gives you that no tower and no constellation and no tended creature ever can — not that you were right in a single fight, and not that you kept faith over time, but that you built something that *lasts*: a place that grew, permanently, into the exact shape of how you chose to play, and that everything else you do is done standing on top of.

## Detailed Design

### Core Rules

**Two Independent Ledgers**

1. Defense Building owns exactly two permanent, one-way ledgers: a **Tech
   Tree** (individually unlockable `tech_id` nodes) and a **Sanctuary
   Structures** roster (individually buildable `structure_id` instances,
   some grouped into ordered tiers of the same `structure_type`). Both are
   Sanctuary-only, both are gold+material-gated, and both resolve
   instant-on-confirm (Rule 8). They are cross-linked only at specific,
   named points (Rule 7) — there is no single unified "progression point"
   currency spanning both; each spends real gold/materials directly.

**Tech Node Model**

2. A **Tech Node** (`TechNodeResource`) is a fixed, author-defined entry:

   | Field | Type | Description |
   |---|---|---|
   | `tech_id` | StringName | Unique identifier, matches the `tech_unlocked` event payload |
   | `tech_category` | String | `"production_tech"` or `"structural_tech"` (Rule 3) |
   | `prerequisite_tech_id` | StringName | Another `tech_id`, or `""` if a root node |
   | `branch_tier` | int | `1`–`3`, this node's position within its own branch (root=1) |
   | `gold_cost` / `material_costs` | int / `Dictionary[StringName, int]` | Formula 1 |
   | `gates` | String (free text, content-authoring only) | What becomes available once unlocked — a Crafting recipe quality tier, or a specific structure/tier |

**Tech Tree Content (Alpha scope — originated here in full)**

3. Exactly **two categories, five nodes total**, two independent linear
   chains (no cross-category prerequisites):

   | `tech_id` | `tech_category` | `prerequisite_tech_id` | `branch_tier` | Gates |
   |---|---|---|---|---|
   | `tech_production_2` | `production_tech` | `""` (root) | 1 | Crafting `quality_tier=2` recipes become tech-gate-satisfied |
   | `tech_production_3` | `production_tech` | `tech_production_2` | 2 | Crafting `quality_tier=3` |
   | `tech_production_4` | `production_tech` | `tech_production_3` | 3 | Crafting `quality_tier=4` |
   | `tech_structural_1` | `structural_tech` | `""` (root) | 1 | Habitat Expansion Tier 2; Watchtower Tier 1 (Rule 7) |
   | `tech_structural_2` | `structural_tech` | `tech_structural_1` | 2 | Habitat Expansion Tier 3 |

   **Assumption flagged**: Crafting's own `quality_tier=1` recipes are
   authored with `tech_prerequisite=""` (ungated, per `crafting.md` Rule 3)
   — there is no `tech_production_1` node, since Tier 1 recipes need no
   gate at all. This mirrors the "early access ungated, tech gates the
   advanced tier" shape requested for structures (Rule 7) onto the
   Crafting side as well, for one consistent rule across both downstream
   consumers of this tree.

   **Node-count assumption flagged**: five nodes sits at the low end of a
   6–10 node guideline. This is a deliberate minimalism call, not an
   oversight — padding the tree with a node that gates nothing yet would
   contradict this GDD's own Alpha-scope mandate, and Menagerie already
   established the precedent of stopping a sub-system at a deliberately
   small, non-symmetric count (2 breeding pens, not padded to match Habitat's
   3 tiers) rather than inventing content for symmetry's sake alone.

**Sanctuary Structure Model**

4. A **Sanctuary Structure** (`StructureResource`) is a fixed,
   author-defined entry:

   | Field | Type | Description |
   |---|---|---|
   | `structure_id` | StringName | Unique identifier, matches the `sanctuary_structure_built` event payload — includes a `_tier_N` suffix for any tiered `structure_type` |
   | `structure_type` | String | Groups tiers of the same structure family (e.g. `"habitat_expansion"`) — matches the event's `structure_type` field |
   | `tier` | int | `1`–N within its `structure_type`; `1` for untiered structures |
   | `prerequisite_structure_id` | StringName | The prior tier's `structure_id`, or `""` if Tier 1 / untiered (Rule 6's sequential-tier enforcement) |
   | `tech_gate` | StringName | A `tech_id` that must be `UNLOCKED` before this structure/tier is buildable, or `""` if ungated |
   | `gold_cost` / `material_costs` | int / `Dictionary[StringName, int]` | Formula 2/3 |

**Sanctuary Structures Content (Alpha scope)**

5. **Habitat Expansion** (mandatory — satisfies `menagerie.md` Core Rule 4
   exactly) is a 3-tier `structure_type`. Each tier's `structure_id` follows
   the `habitat_expansion_tier_N` convention and its `structure_type` is the
   literal string `"habitat_expansion"` on every tier's `sanctuary_structure_built`
   emission — this is the exact event-payload shape Menagerie's own GDD is
   already written to expect:

   | `structure_id` | `tier` | Habitat effect (owned by `menagerie.md`, not here) | `tech_gate` |
   |---|---|---|---|
   | `habitat_expansion_tier_1` | 1 | 4 → 6 slots | `""` (ungated — early access) |
   | `habitat_expansion_tier_2` | 2 | 6 → 8 slots | `tech_structural_1` |
   | `habitat_expansion_tier_3` | 3 | 8 → 10 slots | `tech_structural_2` |

   Exact costs are Formula 2. Confirmed: the `sanctuary_structure_built`
   payload Menagerie subscribes to is emitted with **exactly**
   `structure_id="habitat_expansion_tier_N"`, `structure_type="habitat_expansion"`
   for all three tiers — Menagerie's subscriber logic can key off the fixed
   `structure_type` string to know "a Habitat Expansion happened" and read
   the tier number out of the `structure_id` suffix, or Defense Building's
   own tech-tree/structure UI can present tier as a separate lookup; either
   parsing approach works against this exact string convention.

6. A second, non-mandatory representative structure establishes the pattern
   for future systems without inventing effects nothing asks for yet:
   **Watchtower** (`structure_type="watchtower"`), a single-tier structure,
   `structure_id="watchtower_tier_1"`, gated behind `tech_structural_1`.
   **Assumption flagged**: Watchtower's gameplay effect is explicitly
   **undefined at this GDD's authoring time** — no other system currently
   anticipates consuming a `sanctuary_structure_built` event with
   `structure_type="watchtower"`. It exists purely to establish that "not
   every structure is Habitat Expansion" and to give `tech_structural_1` a
   second, structurally-distinct payoff beyond gating Habitat Tier 2 — its
   effect (Scout visibility, Mission HUD alert range, or purely cosmetic) is
   an open question for whichever future system wants to claim it, not
   invented here to avoid scope creep into another system's design space.

**Currency**

7. Both ledgers spend **gold and materials together**, never one alone —
   deliberately distinct from Crafting/Menagerie (materials-only) and
   Inventory (materials-only) — because Defense Building is the Sanctuary's
   single largest-scale investment category (tech nodes and structures,
   unlike recipes/lures, are permanent, non-repeatable purchases), so gold
   is added as a second gate reflecting that greater weight. Gold spend
   follows the existing signed-delta convention `resources_changed(gold:
   int, source: StringName)` (`resource-economy.md` Rule 7) — Defense
   Building emits its own debit as `resources_changed(-cost, "tech_unlock")`
   or `resources_changed(-cost, "structure_built")` respectively.
   **Assumption/gap flagged**: `resource-economy.md`'s own Open Questions
   already note gold-balance *ownership* (who validates affordability, who
   holds the authoritative balance) is unassigned project-wide — Tower
   System has the same open gap for its placement-cost debit. Defense
   Building's self-debit pattern here follows that same emerging,
   not-yet-centralized convention; it is not a new gap this GDD introduces,
   and should be resolved project-wide in one pass, not per-consumer.
   Material spend uses the same query/consume convention Crafting and
   Menagerie already established against Inventory (`has_items()` /
   batch-consume, `materials_spent`).

**Structure vs. Tech Node Relationship**

8. Tech nodes gate structures **only at the advanced tiers**; the first
   tier/instance of every structure family is buildable with no tech
   prerequisite (Rule 5/6's tables). This mirrors Crafting's own
   ungated-Tier-1 precedent (Rule 3's Assumption) so both of Defense
   Building's downstream-facing behaviors — gating Crafting recipes and
   gating its own structures — read as one consistent rule rather than two
   different philosophies under one GDD.

**Unlock/Build Resolution**

9. **Both a tech node unlock and a structure build are instant on
   confirm — no timer, no queue, no construction duration.** Same
   rationale as `crafting.md` Rule 9: Defense Building operates
   Sanctuary-only, which `game-concept.md`'s pillar framing treats as a
   deliberate-planning space, not an idle-waiting space. Introducing a
   real-time "under construction" state here would be the only building-
   timer mechanic anywhere in the game and would contradict that framing.
   On confirm, in order: (a) re-validate prerequisite (tech chain position
   or structure tier sequence) and tech-gate (for structures), (b)
   re-validate gold balance and `has_items(material_costs)` (defends
   against stale UI, same pattern as `crafting.md` Rule 8 step (a)), (c)
   debit gold via `resources_changed(-cost, ...)`, (d) consume materials via
   Inventory's batch-consume, (e) mark the node `UNLOCKED` / structure
   `BUILT` in the permanent ledger, (f) emit `tech_unlocked(tech_id,
   tech_category)` or `sanctuary_structure_built(structure_id,
   structure_type)`. Steps (a)–(f) execute synchronously within one confirm.

**Idempotency**

10. Once `UNLOCKED`/`BUILT`, a node/structure is **permanently** so — the
    action is a one-way ledger write. Attempting to unlock/build the same
    `tech_id`/`structure_id` again is blocked at the eligibility check
    (Edge Cases) before any cost is touched; this is the same idempotency
    guarantee Crafting's Discovery Ledger and Constellation's Discovery
    Ledger both already established as the project's standing pattern for
    permanent-unlock state.

**Sanctuary-Only Scope**

11. Defense Building owns **no mission-phase state of its own** — like
    Crafting and Menagerie, it inherits `SANCTUARY \ SCOUT \ WAVE_ACTIVE \
    INTERMISSION \ MISSION_COMPLETE \ DEFEAT` directly from
    `game-concept.md`'s state table, which already marks Defense Building
    `LOCKED` during missions. There is no headless-write carve-out
    equivalent to Inventory's `INVENTORY_HEADLESS` — nothing in this
    system's ledgers changes mid-mission, so there is nothing to keep
    active while the screen is inaccessible.

### States and Transitions

Both ledgers use the same three-state shape, one entry per node/structure,
entirely independent of `game-concept.md`'s mission-phase state (Rule 11) —
the phase state only gates *screen accessibility*, never these ledger states
themselves (matching Crafting's own "screen access vs. underlying state" split).

| State | Entry Condition | Behavior | Exit Condition |
|---|---|---|---|
| `LOCKED_PREREQ` (tech nodes) / `LOCKED_PREREQ` (structures) | Node's `prerequisite_tech_id` not yet `UNLOCKED`, or structure's `prerequisite_structure_id` not yet `BUILT`, or (structures only) `tech_gate` not yet `UNLOCKED` | Not selectable; UI renders with the same lock-icon vocabulary Crafting's tech-locked recipe state already established | Prerequisite(s) satisfied → `AVAILABLE` |
| `AVAILABLE` | All prerequisites/tech-gates satisfied, cost not yet paid | Selectable; Confirm button enabled only once affordability (gold + materials) is also currently true (a continuously-re-evaluated sub-check, mirroring Crafting's craftability-vs-discovery split — "available" here is the discovery-equivalent, "affordable" is the craftability-equivalent) | Confirm succeeds (Rule 9) → `UNLOCKED`/`BUILT` |
| `UNLOCKED` (tech nodes) / `BUILT` (structures) | Rule 9 resolves successfully | Permanently unlocked/built; save-persisted (per `save-persistence.md` `restore_order=21`); never re-locks | None — terminal, one-way, matches Crafting's Discovery Ledger and Constellation's Discovery Ledger precedent |

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **EventBus** | Defense Building → EventBus | Emits `tech_unlocked(tech_id, tech_category)` and `sanctuary_structure_built(structure_id, structure_type)` (both frozen in `event-bus.md`); emits `resources_changed(-cost, "tech_unlock")` / `resources_changed(-cost, "structure_built")` for its own gold debits |
| **Crafting** | Defense Building → Crafting | `tech_unlocked` drives Crafting's own recipe tech-gating (`crafting.md` Rule 3/4) — Crafting is the primary consumer of `production_tech` category nodes |
| **Menagerie** | Defense Building → Menagerie | `sanctuary_structure_built(structure_id="habitat_expansion_tier_N", structure_type="habitat_expansion")` drives Menagerie's HABITAT capacity increase (`menagerie.md` Rule 4) — exact contract confirmed above (Rule 5) |
| **Encyclopedia / Mission HUD** | Defense Building → these | Subscribe to both `tech_unlocked` and `sanctuary_structure_built` per `event-bus.md`'s existing subscriber list |
| **Audio** | Defense Building → Audio | Subscribes to `sanctuary_structure_built` per `event-bus.md`'s existing subscriber list |
| **Inventory** | ← Defense Building (query/consume) | `has_items(material_costs) -> bool` and batch-consume on confirmed unlock/build (Rule 9 step (d)), same convention Crafting/Menagerie already use |
| **Resource Economy** | ← Defense Building (gold read/debit) | Reads current gold balance for the Rule 9 step (b) affordability check; emits its own debit via `resources_changed` (Rule 7) — no other system validates this debit, per the project-wide open gap noted in Rule 7 |
| **Save & Persistence** | Defense Building implements `SaveRestorer` | `restore_order = 21` (per `save-persistence.md`), independent within the Feature layer; save payload is the full set of `UNLOCKED` `tech_id`s and `BUILT` `structure_id`s (Formula/Edge Cases detail below) |

## Formulas

### Formula 1 — Tech Node Unlock Cost

```
material_qty(rarity, branch_tier) = round(base_qty[rarity] × node_tier_multiplier(branch_tier))
gold_cost(branch_tier) = round(base_tech_gold × node_tier_multiplier(branch_tier))
```

| Symbol | Type | Range | Description |
|---|---|---|---|
| `branch_tier` | int | 1–3 | The node's position within its own branch (Core Rule 3's table) |
| `base_qty[rarity]` | int | Common=15, Uncommon=8, Rare=4 | Hand-tuned baseline at `branch_tier=1` |
| `node_tier_multiplier(branch_tier)` | float | {1.0, 1.8, 3.0} | Front-loaded scale factor — a new, Defense-Building-owned constant, deliberately not reusing `tower.md`'s `tier_dps_multiplier` (that constant scales combat power; a tech node's cost has no combat-power referent to stay proportionate to) |
| `base_tech_gold` | int | 30–80 (default 50) | Gold baseline at `branch_tier=1` |
| `material_qty` | int | 4–45 | `menagerie_lure`-style output, per rarity, consumed via Inventory's existing query/consume convention |
| `gold_cost` | int | 50–150 | Gold debited via `resources_changed(-gold_cost, "tech_unlock")` |

**Rarity gating** (same step-change convention as `inventory.md`'s slot-expansion
table and `crafting.md`'s Formula 1 — a new rarity tier is introduced once, as a
discrete step, not smoothed in):

| `branch_tier` | Common | Uncommon | Rare | Gold |
|---|---|---|---|---|
| 1 | `round(15×1.0)=15` | — | — | `round(50×1.0)=50` |
| 2 | `round(15×1.8)=27` | `round(8×1.8)=14` | — | `round(50×1.8)=90` |
| 3 | `round(15×3.0)=45` | `round(8×3.0)=24` | `round(4×3.0)=12` | `round(50×3.0)=150` |

**Output range**: Common 15–45, Uncommon 0/14/24, Rare 0/0/12, Gold 50–150.

**Worked example**: `tech_production_3` (`branch_tier=2`) costs 27 Common + 14
Uncommon material and 90 gold. `tech_structural_2` (`branch_tier=2`, same
formula — both categories share one cost curve since neither is intended to
feel "cheaper" than the other) costs the identical 27 Common + 14 Uncommon +
90 gold.

**Calibration note**: at `scout_starting_gold=150` and `base_wave_gold=20`
(`resource-economy.md` Formulas 5/8), a single `branch_tier=1` tech node (50
gold) costs roughly one Scout-phase grant's worth of a third of its starting
gold, or 2–3 wave-completion grants — deliberately affordable early without
being trivial, since (unlike Tower placement) this gold is never recovered
mid-mission.

---

### Formula 2 — Habitat Expansion Structure Cost (hand-tuned table, not derived)

Deliberately **not formulaic**, same precedent as `inventory.md`'s own
slot-expansion table (no clean exponent reproduces a front-loaded,
diminishing-severity curve cleanly — that GDD's own Formulas section
documents the earlier failed attempt) and `crafting.md`'s Formula 2:

| `structure_id` | `tier` | Common | Uncommon | Rare | Gold |
|---|---|---|---|---|---|
| `habitat_expansion_tier_1` | 1 | 20 | — | — | 60 |
| `habitat_expansion_tier_2` | 2 | 35 | 12 | — | 120 |
| `habitat_expansion_tier_3` | 3 | 55 | 25 | 8 | 200 |

**Output range**: 20–55 Common, 0/12/25 Uncommon, 0/0/8 Rare, 60–200 gold.
Per-tier ratios (Common 1.75× then 1.57×; Gold 2.00× then 1.67×) are
deliberately diminishing — front-loaded, matching the "diminishing-severity"
convention `inventory.md`'s own worked table established, so the *third*
Menagerie habitat expansion never feels proportionately more punishing than
the *second*.

**Worked example**: `habitat_expansion_tier_2` (6→8 HABITAT slots, per
`menagerie.md` Rule 4) costs 35 Common + 12 Uncommon material and 120 gold,
and requires `tech_structural_1` already `UNLOCKED` (Core Rule 5).

---

### Formula 3 — Watchtower Structure Cost (hand-tuned, single tier)

| `structure_id` | `tier` | Common | Gold |
|---|---|---|---|
| `watchtower_tier_1` | 1 | 25 | 70 |

**Output range**: fixed at 25 Common + 70 gold (single tier, no scaling
formula needed). **Worked example**: building `watchtower_tier_1` costs 25
Common material and 70 gold, and requires `tech_structural_1` already
`UNLOCKED`.

## Edge Cases

- **If gold or materials are insufficient at confirm-time** (stale UI — e.g.
  gold was spent by Tower System or another Defense Building action between
  the button rendering and the click): Rule 9 step (b) re-validates both the
  gold balance and `has_items(material_costs)`; if either is false, the
  action is rejected in full — no gold debited, no materials consumed, no
  ledger write, no event fires, beyond a UI "insufficient" state refresh.
  Same pattern as `crafting.md`'s Rule 8 step (a).

- **If a tech node's `prerequisite_tech_id` is not yet `UNLOCKED`**: the node
  renders `LOCKED_PREREQ` and is not selectable; if a confirm is somehow
  attempted anyway (e.g. a queued input against a state that changed this
  frame), it is rejected before any cost check — no gold/materials touched,
  no event fires.

- **If a structure's `tech_gate` is not yet `UNLOCKED`** (e.g. attempting
  `habitat_expansion_tier_2` before `tech_structural_1`): rejected at the
  same eligibility check as the prerequisite case above — the tech-gate and
  prerequisite-tier checks are evaluated together in Rule 9 step (a), and
  either failing produces an identical full-reject outcome.

- **If a player attempts `habitat_expansion_tier_2` without
  `habitat_expansion_tier_1` already `BUILT`**: rejected — `tier` sequence is
  enforced via `prerequisite_structure_id` exactly like the tech tree's own
  `prerequisite_tech_id` chain (Core Rule 4). Tiers cannot be purchased out
  of order or skipped, matching Inventory's own sequential slot-expansion-
  tier precedent.

- **If a tech node already `UNLOCKED` (or a structure already `BUILT`) is
  confirmed again** (double-click, replayed input, or a UI that failed to
  disable the control): the eligibility check in Rule 9 step (a) treats
  `UNLOCKED`/`BUILT` as a terminal state that is never re-enterable —
  the action is rejected before any cost check, identically to the
  prerequisite-not-met case. This is idempotent by construction: the ledger
  write in step (e) is a one-way state transition, not a counter, so there
  is no "unlock again" concept to accidentally trigger.

- **If two confirmations (same or different node/structure) arrive in the
  same frame**: Defense Building guards with a single `_action_resolving:
  bool` flag across both ledgers combined (not one per ledger — a tech
  unlock and a structure build could otherwise double-spend the same gold
  balance in the same frame if allowed to resolve concurrently), set `true`
  at the start of Rule 9 step (a) and cleared only after step (f) completes.
  A second confirmation received while resolving is rejected outright, no
  queueing — same pattern as `crafting.md`'s `_craft_resolving` guard,
  generalized across both ledgers because they share one gold balance.

- **If a mission ends in `DEFEAT` while the player has `UNLOCKED`/`BUILT`
  ledger entries from earlier in the same session**: explicitly **no special
  handling is required or performed**. Defense Building operates
  Sanctuary-only (Core Rule 11) — nothing in either ledger is ever touched
  by a mission's outcome, since no write to either ledger can occur while a
  mission is active in the first place. This directly satisfies
  `game-concept.md`'s stated rule that Sanctuary technology unlocks are
  always persistent and are never stripped by a defeated mission; for this
  system specifically, that guarantee reduces to "there was never a
  mission-scoped write path to roll back."

- **If a save is restored referencing a `tech_id`/`structure_id` that no
  longer exists in the current content build** (a node/structure was
  removed or renamed in a later content patch): out of scope for this GDD —
  no other system in the project defines a general content-migration policy
  for removed authored content, and Defense Building does not originate one
  here. Flagged as a shared, project-wide gap, not unique to this system.

## Dependencies

| System | Direction | Nature | Interface |
|---|---|---|---|
| **EventBus** | Depends on (hard) | Emits `tech_unlocked(tech_id, tech_category)`, `sanctuary_structure_built(structure_id, structure_type)` (both frozen); emits `resources_changed(-cost, "tech_unlock"\|"structure_built")` |
| **Inventory** | Depends on (hard) | `has_items(material_costs) -> bool`, batch-consume on confirmed unlock/build (Rule 9 step (d)) — existing query/consume convention, no new interface required |
| **Resource Economy** | Depends on (hard) | Reads current gold balance for affordability (Rule 9 step (b)); emits its own debit via the existing `resources_changed` signal — no new interface required, though gold-balance *ownership* remains an unresolved project-wide question (Core Rule 7) shared with Tower System |
| **Crafting** | Depended on by (hard, downstream) | `crafting.md` Rule 3/4 reads `tech_unlocked` to gate `quality_tier` 2–4 recipes — Defense Building must not change `tech_id` naming for `production_tech` nodes without a coordinated update to Crafting's recipe catalogue |
| **Menagerie** | Depended on by (hard, downstream) | `menagerie.md` Rule 4 reads `sanctuary_structure_built` for `structure_type="habitat_expansion"` to raise HABITAT capacity by +2 slots per tier, max 3 tiers — this GDD's Core Rule 5 table is the exact contract Menagerie already expects |
| **Encyclopedia / Mission HUD / Audio** | Depended on by (soft) | Subscribe to `tech_unlocked`/`sanctuary_structure_built` per `event-bus.md`'s existing catalogue; no functional dependency back onto Defense Building |
| **Save & Persistence** | Depends on (hard) | Implements `SaveRestorer`; `restore_order = 21` (per `save-persistence.md`), independent within the Feature layer; save payload is the set of `UNLOCKED` `tech_id`s and `BUILT` `structure_id`s (a pair of string sets — no numeric/derived state needs saving, since capacity/effects are recomputed by the *consuming* system, e.g. Menagerie, from the event history it already persists) |

## Tuning Knobs

| Knob | Default | Safe Range | Too High | Too Low |
|---|---|---|---|---|
| `base_qty[rarity]` (Formula 1) | Common=15, Uncommon=8, Rare=4 | Common 8–25, Uncommon 4–12, Rare 2–6 | Tech nodes stall behind a material grind disproportionate to their one-time nature, frustrating a player who correctly identified which branch to pursue | Tech unlocks trivialize on the first few missions' haul, undercutting the "permanent investment" weight the Player Fantasy is built on |
| `base_tech_gold` (Formula 1) | 50 | 30–80 | A single tech node consumes most of a Scout-phase starting grant, competing too directly with in-mission Tower placement gold | Tech nodes become a rubber-stamp gold sink, making the gold-gate feel decorative rather than a real second constraint |
| `node_tier_multiplier` (Formula 1) | {1.0, 1.8, 3.0} | 1.0 fixed / 1.4–2.2 / 2.2–4.0 | Later branch tiers (3–4) become effectively unreachable without dedicated farming across many missions | The tree flattens into "same cost every tier," removing any sense of escalating investment as a branch deepens |
| Habitat Expansion cost table (Formula 2) | see table | Each cell independently tunable; keep per-tier ratios diminishing (Common ~1.5–1.8×, Gold ~1.6–2.0× per step) | Late Habitat tiers gate Menagerie's quality-bonus ceiling behind a disproportionate grind, undermining Menagerie's own tuning (which assumes the player *can* reach 10 HABITAT slots) | Habitat Expansion trivializes, and Menagerie's HABITAT-capacity progression stops feeling tied to a real Sanctuary investment |
| Watchtower cost (Formula 3) | 25 Common + 70 gold | 10–40 Common, 40–100 gold | Disproportionately expensive for a structure with no defined mechanical payoff yet, making it feel like a trap purchase | Free-feeling relative to Habitat Expansion, undermining the "structures are a real investment" framing for whichever future system eventually claims its effect |
| Tech node count (Core Rule 3) | 5 (2 categories) | 4–10 | A sprawling tree contradicts this GDD's explicit Alpha-scope mandate and risks becoming a second, competing deep-progression system alongside Crafting/Hero/Tower | Fewer than 4 nodes leaves `production_tech` unable to gate all of Crafting's 2–4 recipe tiers distinctly |
| `_action_resolving` guard window | 1 frame (fixed, not a balance lever) | Fixed | N/A | N/A — removing this guard reintroduces the double-spend race Core Rule 9/Edge Cases exist to prevent |

## Visual/Audio Requirements

### Tech tree — visual presentation

The tech tree renders as a literal branching node graph, not a list or grid — this is the one screen in the project where the underlying data structure (a directed graph of prerequisites) should be directly legible as its own visual shape, since the branching itself communicates "what leads to what."

- **Node states, three total, non-color-first per the art bible's colorblind discipline (Sec 4.5):**

| State | Shape/fill treatment (primary) | Color (secondary) | Non-color backup |
|---|---|---|---|
| Locked | Outline-only node, dimmed icon, small lock glyph overlay | Fieldstone Grey desaturated | Lock glyph alone is unambiguous with color disabled |
| Available (affordable, prerequisites met) | Filled node, full-brightness icon | Sanctum Amber fill | Filled-vs-outline state alone reads without color, matching Crafting/Inventory's established filled-vs-outline "actionable" convention |
| Unlocked | Filled node, full-brightness icon, permanent checkmark/seal glyph overlay | Sanctum Amber fill retained (does not fade to grey — an unlocked node stays visibly "won," not archived) | Seal glyph alone is unambiguous with color disabled |

- **Prerequisite-chain lines** connect nodes as simple bezier/straight connector lines (not pipes or animated flows — keep the "information over spectacle" tone). A line's own state mirrors its two endpoint nodes: locked→locked and locked→available lines render dimmed/outline-style; any line where the source node is Unlocked renders in a brighter, fully-opaque line weight, so the player can visually trace "which paths are already open to me" without reading every node individually.
- Nodes are laid out in fixed, hand-authored positions per tech category (not force-directed/procedural) — this is a designed diagram, and Defense Building's system designer owns the actual tree shape; the AD's requirement is only that positions stay stable across sessions (a node never visually relocates once placed) so players build spatial memory of "where their tech is."
- Node icons follow the same hand-carved-miniature illustration language as Crafting's recipe icons (flat icon-on-panel is acceptable here, unlike the Menagerie habitat's full diorama treatment — the tech tree is an abstraction/UI space, not a physical place in the Sanctuary, so it does not need to justify itself against the "wizard's cabinet" diorama anchor the same way a physical structure does).

### Tech-unlock confirmation moment (`tech_unlocked`)

Given this fires far more often than Constellation's rune-discovery or Menagerie's breeding reveal, weight is deliberately tiered rather than flat:

- **Standard node unlock** (the common case): a brief, contained one-shot — node fill transitions locked→available→unlocked in a fast (under half a second) fill-wipe animation, a small local particle sparkle at the node itself (Herald Gold, sprite-driven, non-bloom per the Godot 4.6 constraint), and the seal glyph stamping in. No screen-level pause, no camera move, no modal. This must stay lightweight — the player may do this many times in one Sanctuary visit, and a maximal fanfare on every node would cheapen itself within the first few unlocks (the same "routine action gets a routine-weight beat" logic Menagerie applies to Tend).
- **Category-completing node** (the final node in a tech category's branch): escalated weight — the fill-wipe/sparkle plays as above, plus the entire category's connector-line network briefly pulses in sequence (a fast, single traveling highlight along the completed branch's lines, root to tip), reading as "this whole line of investment just paid off" rather than just "one more node." Still no full-screen modal — this stays a diegetic, in-screen beat, but it is visibly a bigger event than a standard unlock.
- Both tiers share a Sanctum Amber palette (matching the Available/Unlocked node color) rather than borrowing Herald Gold's Menagerie/Constellation "discovery" association wholesale — tech unlock is achievement-via-investment, not achievement-via-surprise, and should visually read as distinct from those systems' reveal beats even though it reuses the same particle/sparkle vocabulary at small scale.

### Structure-building interaction — visual manifestation

Per the systems-designer's instant-on-confirm mechanic, building a structure is an **instant appearance, not a construction/build-in-progress sequence** — a multi-stage scaffold-then-complete animation would misrepresent the actual mechanic (nothing is "in progress" between confirm and completion) and this GDD does not invent a fictional delay the system doesn't have. Concretely:

- On `sanctuary_structure_built`, the structure's sprite fades/scales in at its Sanctuary-overview position over a short beat (roughly a third of a second) — long enough to read as "something just appeared here," short enough to stay honest to the instant mechanic. This uses the same non-bloom sprite/particle-driven light-burst technique established elsewhere (Menagerie's offspring reveal, Crafting's unlock cascade) at a smaller, structure-appropriate scale — a small dust/settling-particle puff at the structure's base sells "this just materialized," not "this glowed into existence."
- This moment plays wherever the player currently is: if triggered from the tech-tree/build screen itself, a small inset/thumbnail preview of the structure appearing in its Sanctuary-overview position accompanies the primary UI confirmation (see UI Requirements below) — the player should not have to separately visit the overview to discover their structure appeared, but the overview is still the canonical place it "lives."

### Persistent Sanctuary-overview visibility — highest-priority requirement

This is the single most important visual requirement in this GDD, and the most direct expression of Pillar 3 in the project: **built structures are permanent, literal objects placed at fixed positions within the Sanctuary-overview scene, always rendered whenever that overview is on screen — never gated behind opening this system's own screen.**

- Each structure occupies a pre-authored footprint/slot within the overview layout (same "fixed hand-authored position" principle as tech-tree nodes above, applied to physical space instead of UI space) — a structure never floats, relocates, or requires the player to "place" it freely; Defense Building fixes where each structure type goes, consistent with the diorama's oblique-camera, hand-carved-miniature scale and stacked-sprite cast-shadow language used everywhere else in the Sanctuary.
- An unbuilt structure's slot is not simply empty ground — it renders as a visibly vacant foundation/plot marker (a modest outline, cleared-lot, or foundation-stub sprite) so the overview communicates "there is more to build here" even to a player who has never opened the Defense Building screen, and so two players' sanctuaries read as different specifically *because* one has active structures standing where the other still has bare foundations. This is the direct structural analogue to Menagerie's own occupied-vs-empty-habitat overview requirement.
- Structures carry no separate "state" beyond built/not-built at the overview level (no decay, no neglect-state, unlike Menagerie's creatures) — once built, a structure's overview appearance is permanent and stable for the rest of the game, reinforcing Pillar 3's "this is a settled, standing decision" register (the same "commitment held faithfully" quality the Menagerie's player-fantasy text explicitly contrasts itself against).
- Structure sprites differentiate visibly by type/tier (a Habitat Expansion should not be visually interchangeable with a different structure) so that at a glance across the whole overview, a player (or observer) can read the shape of another player's Sanctuary investment without opening any menu.

### Audio direction (category only)

- **Standard tech-node unlock**: a short, light confirmatory chime — distinct register from Crafting's "assembly" sound and Menagerie's "tend" sound; should sit comfortably as a frequent, low-weight cue since it will recur often.
- **Category-completing node unlock**: a fuller, slightly extended variant of the same chime family (not a wholly different sting) — escalated by production value, not by genre-shift, so the player recognizes it as "the big version of the thing I just heard" rather than an unrelated new sound.
- **Structure completion**: a distinct, weightier one-shot from either tech-tree cue — this is a physical-world event, not a UI event, and should read with a touch more "solid/material" timbre (a soft construction-settle/thud-adjacent texture) to reinforce that something now exists in the world, paralleling the tonal distinction Menagerie draws between its UI-driven Tend cue and its physical-diorama ambient bed.
- **Sanctuary-overview ambient**: no dedicated sting on overview load for existing structures (would become noise every time the player returns to the overview) — structures are silent, permanent fixtures once built, consistent with their "no ongoing state" visual treatment above.

## UI Requirements

### Screen layout — two linked views, not one screen

Defense Building is presented as **two connected views within one system screen**, not a single hybrid graph, and not two fully separate tabs with no visual linkage:

- **Tech tree view**: the primary branching-graph screen (per Visual Requirements above), where nodes are browsed and unlocked.
- **Structure-build view**: reached via the same shoulder-button category-cycle convention Inventory/Crafting/Menagerie already use for switching between screen regions — a simple list/panel of buildable structures (each showing cost, prerequisite tech if any, and built/unbuilt status), since structures are a small, enumerable set rather than a graph and do not benefit from tech-tree's branching-node treatment.
- **Rationale**: the tech tree's branching-prerequisite structure and the structure list's flat enumerable structure are different enough shapes of data that forcing them into one literal graph would either flatten the tree's branching read or over-complicate the structure list with unnecessary connector lines it doesn't need. Keeping them as two views under one screen (rather than fully separate top-level screens) preserves the conceptual unity the GDD's own framing implies ("two parallel systems," not "two unrelated systems") while letting each view use the layout best suited to its actual data shape.
- Where a structure has a tech-tree prerequisite, its entry in the structure-build view displays the prerequisite tech's name/icon directly (read-only reference) so the player never has to alt-tab between views to understand why a structure is locked.

### Tech tree navigation — adapting the D-pad-adjacency convention to a graph

Inventory/Crafting/Menagerie's established D-pad-adjacency model assumes a 2D grid or list where every direction has a well-defined next element. A branching graph breaks that assumption (a node may have zero, one, or several children in a given direction), so the convention is adapted rather than reused verbatim:

- **Directional traversal follows graph edges, not screen-space raycasting**: pressing toward a connected child/parent node moves focus along that specific edge. Where a node has multiple children, the direction pressed selects whichever child is most closely aligned to that screen-space direction (so a player pressing "right" from a two-child branch point gets the child positioned more to the right) — this keeps the input feel spatially intuitive without requiring a literal directional-adjacency table for every possible branch shape.
- **Where a direction has no valid edge**, input is a no-op (focus holds) rather than wrapping to an unrelated node — unlike a grid's wrap-at-edges behavior, wrapping across a branching tree would produce disorienting, non-obvious jumps, so this is a deliberate convention break from Inventory's grid-wrap, justified because the underlying data shape is fundamentally different.
- **Shoulder buttons** cycle tech categories (each category being its own branch/sub-tree) and, separately, switch between the tech-tree view and structure-build view (per screen layout above) — reusing the same shoulder-button vocabulary for two different jumps is acceptable here because they're contextually disambiguated (category-cycle only applies within the tree view; view-switch is the "leave this view" action), matching the precedent of context-sensitive shoulder actions already used elsewhere.
- The structure-build view, being a flat list, uses the standard vertical list-navigation convention (D-pad up/down, wrap-at-ends) with no adaptation needed.

### Cost/prerequisite display

Both views show cost and gating state before commit, matching the color+shape conventions already established:

- **Tech nodes**: cost (materials/gold) and prerequisite chain preview appear in a focus-triggered tooltip/side panel (not cluttering the node itself) when a node is focused/hovered. Affordability uses Crafting's own established color convention (green/warm-positive for affordable, desaturated/muted for unaffordable) layered on top of the locked/available/unlocked shape states above — affordability is a sub-state of "Available," not a fourth top-level node state, since an Available-but-unaffordable node is still conceptually "reachable," just not yet paid for.
- **Structures**: the build-list entry shows cost, any tech prerequisite (read-only reference, above), and a built/unbuilt status glyph (checkmark for built, empty-outline slot icon for unbuilt) — mirroring the tech node's own locked/unlocked glyph language so the two views feel like dialects of the same visual grammar rather than unrelated systems.
- Both use the same non-color affordability backup Crafting established: an "!" badge or disabled/greyed confirm button, never color alone.

### Confirmation convention — single confirm, for both tech and structures

Both a tech unlock and a structure build use **Crafting's single-confirm convention**, not Menagerie's two-step sacrifice-style confirmation:

- **Justification**: Menagerie's two-step confirmation is reserved specifically for *destructive, non-fungible-loss* actions (a unique creature ceasing to exist). Tech unlocks and structure builds are the opposite profile — they are **additive, permanent-but-never-destructive** investments. The player loses only a fungible resource (materials/gold), which Crafting's existing single-confirm precedent already treats as sufficiently low-stakes when paired with a pre-confirm cost preview (which both tech nodes and structures already provide per the cost/prerequisite display above). Permanence alone does not warrant a modal — Menagerie's own justification text is explicit that its two-step dialog exists because of *loss of a unique entity*, not because of *permanence* in isolation, and neither tech nodes nor structures ever remove something that existed before.
- Interaction shape: focus a node/structure → confirm → if affordable and prerequisites met, resolves immediately (per the instant-on-confirm mechanic) with the visual/audio feedback above. If confirm is pressed on a locked/unaffordable target, it opens a context tooltip stating what's missing (matching Inventory/Crafting/Menagerie's shared "confirm on non-actionable target explains why" pattern) rather than silently failing.

### Gamepad navigation model (summary)

- D-pad/left-stick: edge-following traversal in tech-tree view (adapted convention above); standard list traversal in structure-build view.
- Shoulder buttons: category-cycle within tech-tree view; view-switch between tech-tree and structure-build.
- Single confirm: unlock/build if actionable; open explanatory tooltip if not.
- No drag-drop anywhere in this system — consistent with the project-wide gamepad model.

### Accessibility notes

- All three node states (locked/available/unlocked) and both structure states (built/unbuilt) carry a non-color glyph or fill-state backup, per the table and rules above — no state is identifiable by color alone.
- Affordability (a sub-state layered on "Available") carries its own non-color badge/button-disable cue, matching Crafting's precedent.
- Prerequisite-chain lines' brightness distinction (dim vs. bright) is a luminance/opacity change, not a hue change, so it remains legible under any color-vision deficiency without a separate backup needed.
- Category-completing unlock's traveling line-pulse is a supplementary flourish, not the sole indicator that a category completed — the node's own permanent seal glyph (present regardless of whether the player was watching when the pulse played) is the actual source of truth, so a player who alt-tabs away or has motion-reduction settings enabled loses no information by missing the pulse itself.
- The Sanctuary-overview's built/unbuilt structure distinction (standing structure vs. vacant foundation marker) is a full silhouette/shape difference, not a color-only distinction, and is therefore colorblind-safe and legible even at overview zoom scale without needing a supplementary icon.

## Acceptance Criteria

> **Test type key** (per QA story-type gate): **Logic** = automated unit test,
> BLOCKING · **Integration** = integration test or documented playtest,
> BLOCKING · **Visual/Feel** = screenshot + lead sign-off, ADVISORY ·
> **Config/Data** = smoke check, ADVISORY. All ACs below are Logic or
> Integration unless noted otherwise.

### Core Rule 1 — Two Independent Ledgers

- **AC-1**: GIVEN a fresh Defense Building state, WHEN the Tech Tree and
  Sanctuary Structures rosters are queried, THEN exactly two independent
  ledgers exist, each tracking its own entries' state (`LOCKED_PREREQ` /
  `AVAILABLE` / `UNLOCKED`-or-`BUILT`) with no shared "progression point"
  currency — unlocking a tech node never debits or credits anything on the
  structures ledger and vice versa, beyond the named cross-links in Rule 7's
  `tech_gate` field.
- **AC-2**: GIVEN both a tech node unlock and a structure build are
  attempted in the same Sanctuary session, WHEN each resolves, THEN each
  spends its own `gold_cost`/`material_costs` directly against the shared
  gold/material pools (Rule 7) — there is no intermediate currency
  conversion step between the two ledgers.

### Core Rule 2/3 — Tech Node Model and Tech Tree Content

- **AC-3**: GIVEN the authored five-node tech tree, WHEN each node's
  `tech_category` is read, THEN `tech_production_2`/`_3`/`_4` are
  `"production_tech"` and `tech_structural_1`/`_2` are `"structural_tech"` —
  exactly two categories, five nodes total, matching Core Rule 3's table
  exactly.
- **AC-4 (linear-chain prerequisite enforcement)**: GIVEN
  `tech_production_2` is not yet `UNLOCKED`, WHEN an unlock is attempted on
  `tech_production_3`, THEN the action is rejected at the eligibility check
  (Rule 9 step (a)) before any cost check — no gold debited, no materials
  consumed, no `tech_unlocked` event fires. The same rejection applies to
  `tech_production_4` before `tech_production_3`, and to `tech_structural_2`
  before `tech_structural_1` — every node in both chains enforces its
  `prerequisite_tech_id` individually; a chain position can never be
  skipped.
- **AC-5**: GIVEN `tech_production_2` IS `UNLOCKED`, WHEN an unlock is
  attempted on `tech_production_3`, THEN the prerequisite check passes and
  the action proceeds to the cost-affordability check (Rule 9 step (b)) —
  prerequisite satisfaction alone does not bypass the cost gate.
- **AC-6**: GIVEN `tech_structural_1` is `UNLOCKED` and `tech_production_2`
  is still `LOCKED_PREREQ`, WHEN either chain's next node is queried, THEN
  `tech_structural_2` becomes eligible (pending cost) while
  `tech_production_3` remains `LOCKED_PREREQ` — the two categories'
  prerequisite chains are fully independent; unlocking within one category
  has zero effect on the other's chain position (no cross-category
  prerequisites, per Rule 3).

### Core Rule 4/5 — Sanctuary Structure Model and Habitat Expansion Contract (highest-priority — cross-GDD contract with `menagerie.md`)

- **AC-7 (exact `structure_id` strings)**: GIVEN the three Habitat Expansion
  tiers, WHEN each tier's `structure_id` is read, THEN they are exactly
  `habitat_expansion_tier_1`, `habitat_expansion_tier_2`, and
  `habitat_expansion_tier_3` — no other naming convention, no
  zero-indexing, no alternate suffix — matching the exact string
  `menagerie.md` Core Rule 4 subscribes against.
- **AC-8 (exact `structure_type` string, all three tiers)**: GIVEN any of
  the three Habitat Expansion tiers is built, WHEN its
  `sanctuary_structure_built` event is emitted, THEN `structure_type` is the
  literal string `"habitat_expansion"` on **all three tiers without
  exception** — Menagerie's subscriber keys off this fixed string alone to
  detect "a Habitat Expansion happened" regardless of which tier fired.
- **AC-9 (event payload shape)**: GIVEN `habitat_expansion_tier_2` is
  built, WHEN `sanctuary_structure_built` is emitted, THEN the payload is
  exactly `sanctuary_structure_built(structure_id="habitat_expansion_tier_2",
  structure_type="habitat_expansion")` — two fields only, no additional
  payload fields, no tier passed as a separate numeric argument (tier is
  recoverable only by parsing the `structure_id` suffix, per Rule 5's own
  text).
- **AC-10 (Tier 1 ungated)**: GIVEN no tech node is `UNLOCKED`, WHEN
  `habitat_expansion_tier_1` is attempted, THEN the tech-gate check passes
  unconditionally (its `tech_gate` is `""`) and the action proceeds to the
  prerequisite-structure and cost checks only.
- **AC-11 (Tier 2 tech-gated on `tech_structural_1`)**: GIVEN
  `habitat_expansion_tier_1` IS `BUILT` but `tech_structural_1` is NOT
  `UNLOCKED`, WHEN `habitat_expansion_tier_2` is attempted, THEN the action
  is rejected at the tech-gate check (Rule 9 step (a)) — no gold debited,
  no materials consumed, no event fires — even though the tier-sequence
  prerequisite (Tier 1 built) is independently satisfied.
- **AC-12 (Tier 3 tech-gated on `tech_structural_2`)**: GIVEN
  `habitat_expansion_tier_2` IS `BUILT` but `tech_structural_2` is NOT
  `UNLOCKED`, WHEN `habitat_expansion_tier_3` is attempted, THEN the action
  is rejected identically to AC-11's shape.
- **AC-13 (sequential-tier enforcement — cannot skip Tier 1)**: GIVEN
  `habitat_expansion_tier_1` is NOT yet `BUILT` (regardless of tech-gate
  state), WHEN `habitat_expansion_tier_2` is attempted, THEN the action is
  rejected at the prerequisite-structure check (`prerequisite_structure_id`
  not satisfied) — a later tier can never be purchased before its
  predecessor, even if its tech-gate happens to already be `UNLOCKED`.
- **AC-14 (sequential-tier enforcement — cannot skip Tier 2)**: GIVEN
  `habitat_expansion_tier_1` IS `BUILT` but `habitat_expansion_tier_2` is
  NOT yet `BUILT`, WHEN `habitat_expansion_tier_3` is attempted, THEN the
  action is rejected identically to AC-13's shape — both tier-sequence and
  tech-gate checks are evaluated together (Rule 9 step (a)), and either
  failing alone produces full rejection.
- **AC-15 (full happy-path sequence)**: GIVEN a fresh save, WHEN
  `habitat_expansion_tier_1` is built, then `tech_structural_1` is
  unlocked, then `habitat_expansion_tier_2` is built, then
  `tech_structural_2` is unlocked, then `habitat_expansion_tier_3` is
  built, in that exact order, THEN all three builds succeed in sequence
  and three `sanctuary_structure_built` events fire with `structure_id`
  values `habitat_expansion_tier_1`, `_tier_2`, `_tier_3` respectively, each
  carrying `structure_type="habitat_expansion"` — confirming the full
  3-tier contract end-to-end, not just individual gate checks in isolation.

### Core Rule 6 — Watchtower (scaffolding structure — build/unlock mechanics only)

- **AC-16**: GIVEN `tech_structural_1` is NOT `UNLOCKED`, WHEN
  `watchtower_tier_1` is attempted, THEN the action is rejected at the
  tech-gate check — identical mechanical shape to AC-11, confirming
  Watchtower's tech-gate enforcement follows the same rule as Habitat
  Expansion's tiers despite being a different `structure_type`.
- **AC-17**: GIVEN `tech_structural_1` IS `UNLOCKED` and sufficient gold
  (70) and Common material (25) are available, WHEN `watchtower_tier_1` is
  confirmed, THEN it resolves `BUILT` and `sanctuary_structure_built(
  structure_id="watchtower_tier_1", structure_type="watchtower")` fires.
  **Scope boundary (qa-lead)**: this AC and AC-16 test only Watchtower's
  build/unlock mechanics (gating, cost, event emission). No AC in this
  document tests any in-game *effect* of Watchtower being built, because no
  such effect is designed (Rule 6's explicit flag) — asserting on a
  gameplay consequence here would test a feature that does not exist.

### Core Rule 7 — Currency (gold + materials together)

- **AC-18**: GIVEN sufficient gold but insufficient materials for a given
  tech node, WHEN unlock is confirmed, THEN the action is rejected in full
  (Rule 9 step (b)) — gold alone satisfying the cost is not sufficient;
  both gates must independently pass.
- **AC-19**: GIVEN sufficient materials but insufficient gold for a given
  structure, WHEN build is confirmed, THEN the action is rejected in full —
  materials alone satisfying the cost is not sufficient.
- **AC-20**: GIVEN a tech node unlock resolves successfully, WHEN its gold
  debit is observed, THEN `resources_changed(-gold_cost, "tech_unlock")`
  fires with the exact negative `gold_cost` from Formula 1 and the source
  tag `"tech_unlock"` (not `"structure_built"` or any other tag).
- **AC-21**: GIVEN a structure build resolves successfully, WHEN its gold
  debit is observed, THEN `resources_changed(-gold_cost, "structure_built")`
  fires with the exact negative `gold_cost` from Formula 2/3 and the source
  tag `"structure_built"`.
- **AC-22 (interface-dependency flag)**: GIVEN Rule 9 step (b)'s
  affordability check reads "current gold balance" from Resource Economy,
  THIS AC IS FLAGGED (qa-lead) as **not independently verifiable as a pure
  Defense Building unit test** — the check's correctness depends on
  Resource Economy's balance-ownership implementation, which
  `resource-economy.md`'s own Open Questions leave unresolved project-wide
  (shared with Tower System's placement-cost debit, per Rule 7's own
  Assumption/gap flag). The debit-emission ACs above (AC-20/AC-21) are
  independently testable in isolation (assert the signal fires with the
  correct payload); the balance-read/validate step itself is only testable
  once a mocked or real Resource Economy authoritative-balance interface
  exists. See Open Questions.

### Core Rule 8 — Structure vs. Tech Node Relationship (Tier-1-ungated symmetry)

- **AC-23**: GIVEN no tech node is `UNLOCKED` anywhere in the tree, WHEN
  the buildable-without-tech-gate structures are enumerated, THEN
  `habitat_expansion_tier_1` is buildable (Tier 1, `tech_gate=""`) while
  `habitat_expansion_tier_2`/`_tier_3` and `watchtower_tier_1` are not —
  confirming exactly one ungated entry point per structure family, matching
  Crafting's ungated-Tier-1 precedent this Rule cites.

### Core Rule 9 — Unlock/Build Resolution (instant-on-confirm, ordered steps)

- **AC-24**: GIVEN a tech unlock is confirmed, WHEN the six sub-steps
  (a)–(f) are observed, THEN they execute synchronously within a single
  confirm call in the exact order: prerequisite/tech-gate re-validate →
  gold+material re-validate → gold debit → material consume → ledger write
  → event emission — no step is deferred to a later frame, and no
  intermediate "under construction" state is ever observable between
  confirm and the completed `UNLOCKED`/`BUILT` state.
- **AC-25**: GIVEN a structure build is confirmed and resolves
  successfully, WHEN the structure's state is queried on the very next
  frame, THEN it already reads `BUILT` — there is no polling or
  intermediate state where a build is "in progress."

### Core Rule 10 — Idempotency

- **AC-26**: GIVEN `tech_production_2` is already `UNLOCKED`, WHEN an
  unlock is attempted on it again, THEN the action is rejected at the
  eligibility check before any cost is touched — no gold debited, no
  materials consumed, no duplicate `tech_unlocked` event fires.
- **AC-27**: GIVEN `habitat_expansion_tier_1` is already `BUILT`, WHEN a
  build is attempted on it again, THEN the action is rejected identically
  to AC-26's shape — no duplicate `sanctuary_structure_built` event fires.

### Core Rule 11 — Sanctuary-Only Scope

- **AC-28**: GIVEN the current mission phase is `WAVE_ACTIVE` (or any
  non-`SANCTUARY` phase), WHEN the Defense Building screen is queried,
  THEN it reports `LOCKED` per `game-concept.md`'s state table, and no
  ledger write of any kind is possible while in that phase — confirming
  Defense Building owns no mission-phase state of its own.

### Persistence Through DEFEAT (Player Fantasy contract — "the one thing that only ever grows")

- **AC-29 (highest-priority persistence AC)**: GIVEN a Sanctuary session in
  which `tech_production_2` has been `UNLOCKED` and
  `habitat_expansion_tier_1` has been `BUILT`, WHEN the player subsequently
  enters a mission that resolves in `DEFEAT`, THEN both the tech node's
  `UNLOCKED` state and the structure's `BUILT` state are unchanged
  immediately after the `DEFEAT` transition — no ledger entry is reverted,
  decremented, or reset by a defeat outcome, mirroring the equivalent
  persistence ACs already established for `menagerie.md`'s creature roster
  and `tarot.md`'s deck contents.
- **AC-30 (save round-trip through DEFEAT)**: GIVEN the same session as
  AC-29, WHEN the game is saved after `DEFEAT` and then reloaded, THEN the
  restored save (`restore_order=21`) reports the identical set of
  `UNLOCKED` `tech_id`s and `BUILT` `structure_id`s as existed before the
  mission was attempted — confirming persistence survives not just the
  in-memory transition but a full save/reload cycle.

### Formula 1 — Tech Node Unlock Cost

- **AC-31**: GIVEN `branch_tier=1`, WHEN `material_qty` and `gold_cost` are
  computed for a Common-rarity node, THEN the result is exactly 15 Common
  material and 50 gold (per the worked table).
- **AC-32**: GIVEN `branch_tier=2`, WHEN costs are computed, THEN the
  result is exactly 27 Common + 14 Uncommon material and 90 gold —
  verifying `round(15×1.8)=27`, `round(8×1.8)=14`, `round(50×1.8)=90`.
- **AC-33**: GIVEN `branch_tier=3`, WHEN costs are computed, THEN the
  result is exactly 45 Common + 24 Uncommon + 12 Rare material and 150
  gold.
- **AC-34**: GIVEN `tech_production_2` and `tech_structural_1` (both
  `branch_tier=1`), WHEN their costs are compared, THEN they are identical
  — confirming both categories share one cost curve with no
  category-specific cost bias.

### Formula 2 — Habitat Expansion Structure Cost

- **AC-35**: GIVEN each Habitat Expansion tier, WHEN its cost is read,
  THEN it matches the authored table exactly: Tier 1 = 20 Common / 60
  gold; Tier 2 = 35 Common + 12 Uncommon / 120 gold; Tier 3 = 55 Common +
  25 Uncommon + 8 Rare / 200 gold — no derived/computed value, since
  Formula 2 is an explicitly hand-tuned table, not a formula.

### Formula 3 — Watchtower Structure Cost

- **AC-36**: GIVEN `watchtower_tier_1`, WHEN its cost is read, THEN it is
  exactly 25 Common material and 70 gold, fixed (no tier scaling since it
  is single-tier).

### Edge Cases

- **AC-37**: GIVEN gold or materials become insufficient between UI render
  and click (stale UI), WHEN confirm is pressed, THEN Rule 9 step (b)
  rejects the action in full — no gold debited, no materials consumed, no
  ledger write, no event fires — matching `crafting.md` Rule 8 step (a)'s
  precedent.
- **AC-38**: GIVEN two confirmations (any combination of tech-node and/or
  structure actions) arrive within the same frame, WHEN the second
  confirmation is processed, THEN it is rejected outright because
  `_action_resolving` is already `true` from the first — no queueing, and
  critically, **the guard is shared across both ledgers** (not
  per-ledger), preventing a tech unlock and a structure build from
  double-spending the same gold balance concurrently within one frame.
- **AC-39**: GIVEN a save references a `tech_id`/`structure_id` that no
  longer exists in the current content build, WHEN the save is restored,
  THEN behavior is explicitly out of scope for this GDD (no content-
  migration policy exists project-wide) — no AC in this document asserts a
  specific recovery behavior for this case; it is flagged as a shared,
  project-wide gap rather than tested here.

### Dependencies — cross-system interface ACs

- **AC-40** *(reworded 2026-07-17 — `/design-review --depth lean` found this AC asserted a `crafting.md` mapping that doesn't actually exist there yet; `crafting.md`'s `tech_prerequisite` field is only generically defined as "a `tech_id` from Defense Building's tech tree, or `""` if ungated" — it never assigns literal `tech_id` values per `quality_tier`. Downgraded to match Core Rule 3's own honest "Assumption flagged" framing rather than asserting an unverifiable fact.)*: GIVEN `crafting.md` Rule 3/4's tech-gating, WHEN
  `tech_production_2`/`_3`/`_4` are each unlocked in turn, THEN each
  corresponding `tech_unlocked(tech_id, tech_category)` event fires with
  `tech_category="production_tech"` and a `tech_id` value. **Not independently verifiable today**: this AC assumes Crafting's `quality_tier=2/3/4` recipes will be authored with `tech_prerequisite` set to exactly `tech_production_2`/`_3`/`_4` respectively, matching this GDD's own Core Rule 3 assumption — but `crafting.md` itself does not yet commit to that literal mapping anywhere. Testable once either (a) `crafting.md` is revised to add an explicit `quality_tier → tech_id` assignment table (mirroring how the Menagerie Habitat Expansion contract is mutually pinned down between the two GDDs that share it), or (b) real recipe content is authored using these `tech_id` values.
- **AC-41**: GIVEN Formula 1/2/3, WHEN each cost curve's inputs are
  checked against Inventory's rarity-tier convention, THEN `material_costs`
  keys use the same `Dictionary[StringName, int]` rarity-keyed shape
  Inventory's `has_items()`/batch-consume already expects — no new
  material-query interface is introduced.

## Open Questions

| Question | Owner | Notes |
|---|---|---|
| Gold-balance ownership (who validates affordability, who holds the authoritative balance) is unassigned project-wide | Resource Economy owner | Shared gap, not introduced by this GDD — `resource-economy.md`'s own Open Questions already flag this, and Tower System's placement-cost debit has the identical open gap (Rule 7's Assumption/gap flag). AC-22 is flagged (qa-lead) as not independently verifiable as a pure Defense Building unit test until this is resolved; the debit-emission ACs (AC-20/AC-21) are testable in isolation today, but the balance-read/validate step (Rule 9 step (b)) needs either a mocked or real authoritative-balance interface first. Should be resolved once, project-wide, not per-consumer. |
| Watchtower's gameplay effect is undefined | Whichever future system claims it (Scout, Mission HUD, or purely cosmetic) | Deliberately left as scaffolding (Rule 6's own flag) — no other system currently subscribes to `sanctuary_structure_built(structure_type="watchtower")`. AC-16/AC-17 test only Watchtower's build/unlock mechanics; no AC in this document tests or assumes any in-game consequence of building it, since none exists yet. Whoever eventually claims Watchtower's effect will need a coordinated update to both that system's GDD and this GDD's Visual/Audio Requirements (currently silent on the effect itself). |
| Content-migration policy for removed/renamed `tech_id`/`structure_id` values referenced by an old save | Save & Persistence owner | Shared, project-wide gap (Edge Cases, last bullet) — no system in the project currently defines this policy. AC-39 explicitly does not assert a recovery behavior pending this decision. |
| Placeholder rarity-tier material identifiers (`Common`/`Uncommon`/`Rare`) used throughout Formulas 1–3 are generic labels, not confirmed against Inventory's actual authored material-rarity enum | Inventory owner | Same caveat class as `menagerie.md` AC-1's flagged placeholder-species naming — AC-31 through AC-36 assume these labels resolve 1:1 to Inventory's real rarity identifiers; if Inventory's enum differs in naming, only the labels need updating, not the cost logic itself. |
