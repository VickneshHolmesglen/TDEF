# Menagerie System

> **Status**: Needs Revision (`/design-review --depth lean` 2026-07-17 found `target_item_id`'s sourcing undocumented and Equipment Forge's `request_sacrifice()` signature unadopted; both fixed same-day — Rule 13/AC-29 and the Interactions/Dependencies tables now adopt `equipment-forge.md` Rule 19d's exact signature and document that `target_item_id` is Forge-supplied, not Menagerie-looked-up. Defense Building's Habitat Expansion contract independently verified to match this doc's expectations exactly, no changes needed there.)
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-07-17
> **Implements Pillar**: Everything Connects · The Sanctuary Is Your Statement
> **Known gaps**: `creature_acquired` now merged into `event-bus.md`'s catalogue (2026-07-17). Equipment Forge's sacrifice-request API is now adopted (2026-07-17, see Rule 13). Defense Building's Habitat Expansion structure is authored and verified consistent — no remaining soft dependencies on undesigned systems.

## Overview

The Menagerie System is the sanctuary's living-care layer: it lets the player collect, house, and tend creatures between missions, and turns the state of that care into a standing bonus on everything they earn in the field. Technically, it owns creature entity state (species, habitat assignment, and a per-creature `happiness` value that drifts over time and responds to player attention), acquires new creatures from `menagerie_lure` material drops earned on missions, and houses them in habitats within the Sanctuary. Aggregate happiness feeds `menagerie_quality_bonus`, a 1.0–1.5x multiplier the Resource Economy applies to the **quantity** of materials a mission kill yields (Resource Economy Formula 2) — explicitly a "well-tended menagerie yields more" mechanic, not a quality, tier, or luck improvement. Two outbound actions consume creatures: moving a pair into the breeding pen produces offspring and emits `creature_bred`, and surrendering a creature to the Equipment Forge emits `creature_sacrificed`. Like Crafting, the Menagerie is Sanctuary-only — creatures are tended between runs, never mid-mission — and all cross-system effects flow through the EventBus rather than direct references. Player-facing, it is the one system in the sanctuary that is visibly alive and can be neglected: a player who invests in it sees populated, thriving habitats that a player who ignored it never will (Pillar 3's visible, player-specific trace), and feels its bonus every time a well-kept menagerie makes a mission's haul larger than a neglected one would have.

## Player Fantasy

> A tower remembers what you told it. A creature notices whether you came back.
>
> Everything else you build in the sanctuary is a decision that keeps itself. A tower holds the commitment you made before you walked away from it; a constellation stands exactly as you arranged it until the wave breaks it; a crafted component, once it leaves the bench, is finished and does not need you again. You make the call once and the sanctuary carries it forward, faithfully, without you. The Menagerie is the one system that will not do this. A creature's happiness drifts. Left alone, it fades; attended to, it rises. It is the only thing you build that can tell whether you have been away — and so it is the only part of the sanctuary that asks you a different question than the rest. The towers ask whether you were *right*. The creatures ask whether you *came back*.
>
> This is a quieter kind of play, and it has its own hour: the moment between missions, before the forge and before the field, when the first thing you do when you get home is go to the habitats. You look for the creature whose light has gone a little dull since last time, and you tend it. Nothing about this is a grand decision committed once and left to run. It is small, and it recurs, and that is the whole point — a thriving menagerie is not something you can rush, or buy, or assemble in one clever afternoon. It can only be earned the slow way, by showing up, mission after mission, and noticing. What you are cultivating is not a stat. It is the habit of having been present.
>
> And yes — the well-kept menagerie gives back. Happy creatures make every mission you fight yield more. But the instant you tend them *for* that number, they stop being creatures and become machines, and the feeling that makes this system worth having dies on the spot. So the arrangement has to be read the other way around: you do not care for them to farm more; the greater yield is simply the world confirming that your attention had weight. Nor is this sentimental keeping. Some creatures you raise precisely to give up — moved to the breeding pen to make an offspring you could get no other way, or surrendered whole to the Equipment Forge for what only a sacrifice can buy. That cost is what keeps the Menagerie honest: the creatures are not a collection you hoard, they are lives you steward, and stewardship sometimes means letting one go.
>
> When you finally stand back and look at the whole of it — habitats full, creatures thriving, a corner of the sanctuary that is visibly, unmistakably *alive* because you kept it alive — the feeling is not the feeling the towers give you. A tower gives you the vindication of a single decision proven right. A constellation gives you the vindication of an arrangement proven right. The Menagerie gives you the one thing neither of them can, because it is the one thing that cannot be produced in a single right moment: the proof that you kept faith with something over time. No clever flash assembles a living menagerie. It only accumulates. That is the recognition the Menagerie gives you that no tower and no constellation ever will — not that you were right once, but that you were *there*, again and again, and the sanctuary is alive because you were.

## Detailed Design

### Core Rules

1. **Species roster (Alpha scope, ASSUMPTION — flagged).** Five species exist at
   Alpha, gated into the same three rarity tiers `inventory.md` already
   established for materials (Common/Uncommon/Rare), so a single tier concept
   spans both systems rather than inventing a second rarity vocabulary:
   - Tier 1 (Common): `glimmer_hare`, `mossback_toad`
   - Tier 2 (Uncommon): `emberwing_moth`, `duskfang_fox`
   - Tier 3 (Rare): `aurora_stag`
   These are placeholder names, not final creative-approved names — same
   caveat `inventory.md` already applies to its own rarity-tier material
   names. All five species are available to lure from the start; there is no
   separate discovery/unlock gate on top of the lure cost itself (ASSUMPTION —
   keeps Alpha scope small; a future revision may gate rarer species behind
   Encyclopedia discovery or story progress).
2. **Acquisition is the "Lure" action** — a Sanctuary-only, player-initiated,
   deterministic action (no RNG on species or outcome). The player selects one
   target species from the full roster (Rule 1) and confirms; Menagerie
   queries Inventory for `menagerie_lure` quantity via the same
   query/consume pattern Crafting uses (`has_items`-equivalent), and on
   success consumes the cost (Formula 4) via `materials_spent` and
   instantiates one new creature instance of that species at
   `starting_happiness` (Formula 2's table). This closes
   `resource-economy.md`'s deliberately-provisional Open Question: `menagerie_lure`
   is consumed **only** by this action.
3. **New creatures default to HABITAT if space allows, otherwise RESERVE.**
   On successful Lure, the new creature instance is placed directly into an
   open HABITAT slot if one exists; if HABITAT is at capacity, it is placed
   into RESERVE instead (see States and Transitions) — acquisition never
   fails or is blocked by a full habitat, only redirected.
4. **Habitat is capacity-gated, base 4 slots, expandable only by a Defense
   Building structure (soft/anticipated dependency — Defense Building has no
   GDD yet).** Each "Habitat Expansion" structure tier adds +2 slots, to a
   maximum of 3 tiers (4 → 6 → 8 → 10 slots). The exact material/gold cost of
   each tier is owned by Defense Building's own future GDD, not invented
   here — Menagerie only fixes the slot-count curve and the tier count.
   Unlike Inventory's slot expansion (a craftable action Inventory itself
   owns), Menagerie's expansion is deliberately routed through Defense
   Building's `sanctuary_structure_built` event so both systems agree on a
   single ownership model for Sanctuary-structure-gated capacity (ASSUMPTION —
   ties Menagerie into the existing Sanctuary-structure convention rather than
   duplicating Inventory's craft-expansion pattern).
5. **Only HABITAT creatures contribute to the aggregate `menagerie_quality_bonus`.**
   RESERVE and BREEDING_PEN creatures are fully excluded from Formula 3 —
   this is the literal mechanism behind `creature_moved_to_breeding_pen`
   "reducing" and `creature_returned_from_breeding_pen` "restoring" the
   quality bonus contribution (event-bus.md's frozen contract).
6. **Aggregate recompute-and-push rule (closes a contract gap — flagged
   ASSUMPTION).** `creature_happiness_changed`'s payload already carries both
   `new_happiness` (the individual creature's own value) and `quality_bonus`
   (the aggregate, per `resource-economy.md` Rule 3's caching model) in one
   event. `creature_moved_to_breeding_pen`/`creature_returned_from_breeding_pen`
   carry no `quality_bonus` field per the frozen event-bus.md contract, so
   Resource Economy cannot derive the new aggregate from those events alone.
   Resolution: **every** action that changes HABITAT composition — a
   Lure placing a creature directly into HABITAT, a move to/from the
   breeding pen, a sacrifice removing a HABITAT creature — triggers an
   immediate aggregate recompute (Formula 3), and Menagerie emits
   `creature_happiness_changed` for one representative creature (the
   creature that just moved, or — if a HABITAT creature was sacrificed and
   no other creature "moved" — the longest-tended remaining HABITAT creature,
   or, if HABITAT is now empty, this rule is skipped and the aggregate simply
   reports `1.0` on the *next* natural happiness-changing event) **alongside**
   the transfer/sacrifice event itself, so Resource Economy's cache always
   reflects the fresh aggregate within the same frame the transfer occurred.
7. **Happiness starts at 70 on acquisition** and decays over time spent
   un-tended, but never below a floor of 20 — a creature never "leaves" or
   dies from neglect (deliberate Alpha decision: floor-not-death, avoiding a
   punishing permadeath mechanic the brief explicitly recommended against).
8. **Time is measured in missions launched, not wall-clock time.** Every
   `mission_launched` event, each creature currently in HABITAT has its
   happiness decayed once (Formula 1) and its `missions_since_tended` counter
   incremented. RESERVE and BREEDING_PEN creatures do not decay — their
   happiness is frozen at whatever value it held when they left HABITAT
   (ASSUMPTION: ties the "ongoing care" loop to the mission-to-mission
   Sanctuary rhythm the game already has, rather than introducing a
   real-time/wall-clock system that would tick even while the game isn't
   running).
9. **Tending is a single Sanctuary-only action per creature, no cooldown.**
   Selecting "Tend" on a HABITAT creature applies Formula 2 (boosts
   happiness, resets `missions_since_tended` to 0). There is no limit on how
   often it can be used — the design lever is the decay rate itself, not an
   artificial tend cooldown, keeping the action simple (Alpha scope) rather
   than a full needs-simulation.
10. **Breeding requires two creatures of the identical species, both moved
    into the same breeding pen slot pair.** Cross-species pairing is rejected
    outright at the move-to-pen action (see Edge Cases) — there is no
    species-compatibility matrix to design or maintain at Alpha.
11. **Breeding is deterministic — no success roll.** Once two same-species
    creatures occupy a pen together, a `breeding_missions_remaining` counter
    (Formula 5) begins and decrements once per `mission_launched`, identical
    in cadence to Rule 8's happiness decay tick. When it reaches 0, exactly
    one offspring of the parent species is created directly into RESERVE
    (never auto-placed into HABITAT, unlike a Lure acquisition — the player
    must manually decide where a bred creature goes), and `creature_bred`
    fires. The two parent creatures remain in the pen, un-consumed, and may
    be bred again or returned to HABITAT.
12. **Breeding pen capacity is fixed at 2 pens (4 creature slots, 2 breeding
    pairs) at Alpha, not expandable.** Deliberately excluded from the
    Defense-Building-expansion model (Rule 4) that governs HABITAT — keeps
    the breeding side of the system small and legible rather than adding a
    second capacity-progression curve this early (ASSUMPTION, flagged as a
    scope-discipline call, not a constraint from any other GDD).
13. **Sacrifice is Equipment-Forge-initiated, Menagerie-validated,
    Menagerie-emitted.** Equipment Forge (undesigned) calls into Menagerie's
    consume API with a target `creature_id`; Menagerie validates the creature
    is **not currently in BREEDING_PEN** (a creature must be pulled from the
    pen — which immediately cancels that pairing's in-progress breeding timer,
    per Rule 10's transition table — before it can be offered to the Forge),
    then removes it (from RESERVE or HABITAT, recomputing the aggregate per
    Rule 6 if it was a HABITAT creature) and emits `creature_sacrificed`
    itself — matching the ownership precedent Inventory established for
    Tower's `tower_component_returned` (the initiating system never emits the
    event directly; the system that owns the ledger does). There is no
    minimum "age" or cooldown before a newly-acquired creature is eligible
    for sacrifice (ASSUMPTION — avoids an arbitrary restriction the brief
    didn't ask for).
14. **New cross-system event required (flagged, not yet in `event-bus.md`'s
    catalogue — same pattern Inventory used for `item_pickup_rejected` and
    Tower used for `tower_component_returned`):** `creature_acquired(creature_id:
    String, species: String)`, emitted once per successful Lure (Rule 2).
    Key Subscribers: Encyclopedia (species-discovery entry), Mission HUD
    (acquisition toast). Payload shape deliberately mirrors `creature_bred`'s
    existing `(offspring_id, species)` pair for catalogue consistency.

### States and Transitions

Each creature instance is in exactly one of three states. Sacrifice and
breeding-offspring-creation are one-way (no transition back from
`SACRIFICED`; offspring instances are created directly into `RESERVE`).

| State | Description | Contributes to `menagerie_quality_bonus`? | Happiness decays? |
|---|---|---|---|
| `RESERVE` | Owned but not on active display; a holding area for overflow acquisitions, bred offspring, and creatures the player is parking for later breeding/sacrifice | No | No (frozen at last value) |
| `HABITAT` | Actively displayed, up to habitat capacity (Rule 4) | Yes (Formula 3) | Yes (Formula 1, per `mission_launched`) |
| `BREEDING_PEN` | Paired with exactly one same-species partner, breeding timer active (Formula 5) | No | No (frozen at last value) |

| From | Trigger | To | Side Effects |
|---|---|---|---|
| *(none — new instance)* | Lure action succeeds (Rule 2), HABITAT has an open slot | `HABITAT` | `creature_acquired` fires; aggregate recomputed (Rule 6); `creature_happiness_changed` fires with the fresh aggregate |
| *(none — new instance)* | Lure action succeeds (Rule 2), HABITAT is full | `RESERVE` | `creature_acquired` fires only; no aggregate recompute (RESERVE doesn't contribute) |
| `RESERVE` | Player manually moves creature into an open HABITAT slot | `HABITAT` | Aggregate recomputed (Rule 6); `creature_happiness_changed` fires |
| `HABITAT` | Player manually moves creature to RESERVE | `RESERVE` | Aggregate recomputed (Rule 6); `creature_happiness_changed` fires (excluding the moved creature going forward) |
| `HABITAT` or `RESERVE` | Player moves creature into an open, same-species-compatible pen slot | `BREEDING_PEN` | `creature_moved_to_breeding_pen` fires; if HABITAT source, aggregate recomputed + `creature_happiness_changed` fires (Rule 5/6); `breeding_missions_remaining` starts (Formula 5) once the *second* creature joins the same pen |
| `BREEDING_PEN` | Player manually removes creature (before or after breeding completes) | `RESERVE` | `creature_returned_from_breeding_pen` fires; if the pair was mid-timer, `breeding_missions_remaining` for that pen is discarded (Rule 13's cancel-on-removal behavior) |
| `HABITAT` or `RESERVE` | Equipment Forge sacrifice request validated (Rule 13) | `SACRIFICED` (terminal) | `creature_sacrificed` fires; if HABITAT source, aggregate recomputed + `creature_happiness_changed` fires |
| *(both pen occupants, unchanged)* | `breeding_missions_remaining` reaches 0 (Formula 5) | *(pen occupants stay `BREEDING_PEN`)* — new offspring instance created into `RESERVE` | `creature_bred` fires for the new offspring; parents remain paired and may accumulate another breeding cycle immediately |

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **EventBus** | Menagerie → | `creature_happiness_changed`, `creature_bred`, `creature_sacrificed`, `creature_moved_to_breeding_pen`, `creature_returned_from_breeding_pen` (all frozen contracts, unchanged), plus the new `creature_acquired` proposal (Rule 14) |
| **Resource Economy** | Menagerie → Economy | `creature_happiness_changed`'s `quality_bonus` field is the sole feed for `menagerie_quality_bonus` (Rule 6); Resource Economy caches, never recomputes |
| **Inventory** | Menagerie ↔ Inventory | Query for `menagerie_lure` (and any future acquisition material) balance before a Lure action resolves; `materials_spent` on success (Rule 2). Bred offspring and sacrifice do not touch Inventory directly. |
| **Equipment Forge** *(authored 2026-07-17)* | Forge → Menagerie (direct call), Menagerie → Forge (indirect, via `creature_sacrificed`) | Forge calls `Menagerie.request_sacrifice(creature_id: String, target_item_id: String) -> bool` (signature adopted 2026-07-17 from `equipment-forge.md` Rule 19d — that GDD originated the exact name/shape since `menagerie.md` had only anticipated the call without naming it). `target_item_id` identifies the Equipment item Forge is about to imbue — **it is supplied by Equipment Forge, not looked up by Menagerie**; Menagerie does not read or validate it beyond passing it through unchanged into the `creature_sacrificed` payload (Forge owns validating that the item exists and is eligible for imbuing, per its own Rule 16/19). Menagerie validates the sacrifice request against its own state (Rule 13) and is the sole `creature_sacrificed` emitter, mirroring Inventory's `tower_component_returned` → `item_added` ownership precedent. |
| **Encyclopedia** | Menagerie → Encyclopedia | Subscribes to `creature_bred` (existing) and the proposed `creature_acquired` (Rule 14) for species-discovery entries |
| **Defense Building** (undesigned) | Building → Menagerie (soft, anticipated) | `sanctuary_structure_built` for the "Habitat Expansion" structure is expected to raise HABITAT capacity per Rule 4's tier table; exact structure cost is Defense Building's to define |
| **Save & Persistence** | Menagerie implements `SaveRestorer` | `restore_order = 20`, restored immediately after Inventory (10); save payload is every creature instance (`creature_id`, `species`, `state`, `happiness`, `missions_since_tended`) plus current HABITAT capacity tier and any active breeding-pen pairings/timers |
| **Mission HUD** | Menagerie → HUD (read-only) | Subscribes to `creature_happiness_changed`, `creature_bred`, `creature_acquired` for live notification/toast display; no functional dependency |
| **Crafting** | None (confirmed by `crafting.md`'s own Dependencies table) | No direct interface — Crafting lists Menagerie only as a future anticipated consumer of Inventory's Materials tab, not a direct coupling |

## Formulas

### Formula 1 — Habitat Happiness Decay (per `mission_launched`)

```
happiness' = max(happiness_floor, happiness - decay_per_mission)
```

| Symbol | Type | Range | Description |
|--------|------|-------|--------------|
| `happiness` | float | 20–100 | Creature's happiness value before this tick |
| `decay_per_mission` | float | 5–15 (default 8) | Flat happiness lost per `mission_launched` while un-tended, HABITAT creatures only |
| `happiness_floor` | float | 20 (fixed) | Hard floor — never 0, never triggers creature removal (Alpha decision: floor-not-death) |
| `happiness'` | float | 20–100 | Resulting happiness value |

**Output Range:** 20–100, clamped by `happiness_floor`.
**Example:** `happiness = 90`, `decay_per_mission = 8` → `happiness' = max(20, 82) = 82` after one un-tended mission. After 9 consecutive un-tended missions from 90: `90 - 9×8 = 18`, clamped to the floor → `happiness' = 20`.

---

### Formula 2 — Tend Boost (per Tend action)

```
happiness' = min(100, happiness + tend_boost)
```

| Symbol | Type | Range | Description |
|--------|------|-------|--------------|
| `happiness` | float | 20–100 | Creature's happiness value before tending |
| `tend_boost` | float | 15–30 (default 20) | Flat happiness gained per Tend action |
| `happiness'` | float | 20–100 | Resulting happiness value; also resets `missions_since_tended` to 0 |

**Output Range:** 20–100, clamped at 100 (overheal has no effect — no "buffed above 100" state).
**Example:** `happiness = 54`, `tend_boost = 20` → `happiness' = min(100, 74) = 74`. A creature at 90 tended once: `min(100, 110) = 100`.

**Also applies at acquisition:** `starting_happiness = 70` (fixed constant, not derived from this formula — a new creature is not "tended," it simply starts at a mid-band value that rewards early attention without requiring an immediate Tend to feel viable).

---

### Formula 3 — Aggregate `menagerie_quality_bonus`

```
menagerie_quality_bonus = 1.0                                    if N_habitat = 0
menagerie_quality_bonus = clamp(1.0 + 0.5 × (H_avg / 100), 1.0, 1.5)   if N_habitat > 0
```

| Symbol | Type | Range | Description |
|--------|------|-------|--------------|
| `N_habitat` | int | 0–10 | Count of creatures currently in `HABITAT` (excludes RESERVE and BREEDING_PEN, per Rule 5) |
| `H_avg` | float | 0–100 | Arithmetic mean of `happiness` across all `HABITAT` creatures |
| `menagerie_quality_bonus` | float | 1.0–1.5 | The registered constant (`design/registry/entities.yaml`) — must stay within this exact range |

**Output Range:** 1.0–1.5, matching the registry's `menagerie_quality_bonus` bounds exactly — the `N_habitat = 0` special case exists specifically to avoid a divide-by-zero and to guarantee the floor case is exactly `1.0`, not an undefined or negative artifact.
**Example:** 3 HABITAT creatures at happiness 82, 70, 55 → `H_avg = (82+70+55)/3 = 69.0` → `1.0 + 0.5 × 0.69 = 1.345`. Sole HABITAT creature at floor happiness 20 → `1.0 + 0.5 × 0.20 = 1.10`. Zero HABITAT creatures → `1.0` exactly.

---

### Formula 4 — Lure Acquisition Cost

```
lure_cost(tier) = base_lure_cost × tier
```

| Symbol | Type | Range | Description |
|--------|------|-------|--------------|
| `tier` | int | 1–3 | Target species' rarity tier (Rule 1) |
| `base_lure_cost` | int | 2–5 (default 3) | Tuning knob; per-tier linear step |
| `lure_cost` | int | 3–9 | `menagerie_lure` quantity required, deducted via `materials_spent` |

**Output Range:** 3 (Tier 1) to 9 (Tier 3) at default tuning.
**Example:** `base_lure_cost = 3` → Tier 1 (`glimmer_hare`/`mossback_toad`) costs 3 `menagerie_lure`; Tier 2 costs 6; Tier 3 (`aurora_stag`) costs 9.

---

### Formula 5 — Breeding Duration

```
breeding_missions_remaining(tier) = base_breeding_duration + tier_breeding_penalty × (tier - 1)
```

| Symbol | Type | Range | Description |
|--------|------|-------|--------------|
| `tier` | int | 1–3 | Both parents' shared species tier (breeding requires identical species, Rule 10, so both parents share one tier by construction) |
| `base_breeding_duration` | int | 1–4 missions (default 2) | Missions required for a Tier-1 pairing |
| `tier_breeding_penalty` | int | 0–2 (default 1) | Additional missions required per tier above 1 |
| `breeding_missions_remaining` | int | 2–4 | Missions until the pen produces an offspring, decremented once per `mission_launched` (Rule 11) |

**Output Range:** 2 (Tier 1 pair) to 4 (Tier 3 pair) at default tuning.
**Example:** Two `aurora_stag` (Tier 3) paired: `2 + 1×(3-1) = 4` missions until `creature_bred` fires. Two `glimmer_hare` (Tier 1) paired: `2 + 1×0 = 2` missions.

## Edge Cases

- **If a creature's happiness reaches `happiness_floor` (20)**: it stays a fully functional HABITAT creature indefinitely — no removal, no death, no forced eviction. It simply contributes the minimum possible per-creature share to Formula 3 until tended again.
- **If a Lure action is confirmed while HABITAT is at full capacity**: the new creature is placed into `RESERVE` automatically (never blocked, never rejected) — mirrors the "acquisition never fails" design goal; the player must free a HABITAT slot or wait for a Defense Building expansion to actually benefit from the new creature's happiness.
- **If a player attempts to pair two creatures of different species in the breeding pen**: the move-to-pen action is rejected at the eligibility check — no `creature_moved_to_breeding_pen` fires, no materials/state change occurs. This is a UI-disableable state (same pattern as Inventory's max-tier-expansion block), not a runtime failure.
- **If the last HABITAT creature is sacrificed (or moved to RESERVE/pen)**: Formula 3's `N_habitat = 0` branch applies — `menagerie_quality_bonus` drops to exactly `1.0`, and `creature_happiness_changed` fires once (per Rule 6) reporting that floor value so Resource Economy's cache updates immediately, not on some later, unrelated event.
- **If a creature is moved to the breeding pen and back to HABITAT within the same Sanctuary session (no `mission_launched` elapses in between)**: both transitions resolve synchronously and atomically — the aggregate recomputes cleanly on each transition (Rule 6), so no stale or "double-counted" quality bonus state can exist even under rapid toggling; happiness itself does not change from the toggle alone (only the mission-tick decay, Formula 1, changes it).
- **If a creature is removed from the breeding pen while `breeding_missions_remaining > 0`**: the in-progress timer for that pairing is discarded entirely, not paused/resumable — re-pairing the same two creatures later restarts the full duration from Formula 5. This is a deliberate simplicity choice (Alpha scope) over a resumable-progress model.
- **If Equipment Forge requests a sacrifice on a creature currently in `BREEDING_PEN`**: the request is rejected by Menagerie's validation (Rule 13) — Forge must first remove the creature from the pen (which cancels any in-progress breeding timer per the rule above) before the same `creature_id` becomes sacrifice-eligible.
- **If Equipment Forge requests a sacrifice on a creature acquired in the same session (0 missions old)**: the request is accepted — there is no minimum-age gate on sacrifice eligibility (Rule 13).
- **If `mission_launched` fires while HABITAT holds a large number of creatures simultaneously (up to the Rule 4 maximum of 10)**: each HABITAT creature's `creature_happiness_changed` fires independently — at a maximum of 10 firings in one frame, this stays well under EventBus's `eventbus_batch_threshold` (20 per frame), so no batched/deferred dispatch pattern is required for this event, unlike high-frequency events such as `monster_died`.
- **If a save file is restored mid-breeding-timer (a pen has `breeding_missions_remaining > 0` at save time)**: the exact `breeding_missions_remaining` value is part of the save payload (per the Save & Persistence Interactions row) and resumes counting down from where it left off — a breeding timer is not reset by a save/load cycle, since `mission_launched` (not wall-clock time) is the only thing that decrements it, and that event only fires from an active session.

## Dependencies

| System | Direction | Nature |
|---|---|---|
| **EventBus** | Hard dependency | All cross-system communication routes through it — `creature_happiness_changed`, `creature_bred`, `creature_sacrificed`, `creature_moved_to_breeding_pen`, `creature_returned_from_breeding_pen` (frozen), plus the proposed `creature_acquired` (Rule 14, not yet catalogued) |
| **Resource Economy** | Hard dependency (downstream) | Reads `menagerie_quality_bonus` exclusively through `creature_happiness_changed`'s `quality_bonus` field (Rule 6); Menagerie must push, Resource Economy never recomputes |
| **Inventory** | Hard dependency (bidirectional) | Menagerie queries/consumes `menagerie_lure` for Lure actions (Rule 2, Formula 4) via the same query/consume convention Crafting uses; Resource Economy hands `menagerie_lure` to Inventory upstream via `materials_earned`, not directly from Menagerie |
| **Equipment Forge** *(authored 2026-07-17)* | Hard dependency (bidirectional, upgraded from soft/anticipated) | Forge calls `Menagerie.request_sacrifice(creature_id, target_item_id) -> bool` — signature and `target_item_id` sourcing now adopted from `equipment-forge.md` Rule 19d, see the Interactions table above. Menagerie validates (Rule 13) and is the sole `creature_sacrificed` emitter. |
| **Defense Building** *(undesigned)* | Soft dependency (anticipated) | Expected to raise HABITAT capacity via a "Habitat Expansion" structure and `sanctuary_structure_built`; exact structure cost is Defense Building's to define, not Menagerie's |
| **Encyclopedia** | Soft dependency (downstream) | Subscribes to `creature_bred` and the proposed `creature_acquired` for species-discovery entries |
| **Save & Persistence** | Hard dependency | `restore_order = 20`, immediately after Inventory (10); save payload is creature instances (id/species/state/happiness/missions_since_tended), HABITAT capacity tier, and active breeding-pen pairings/timers |
| **Mission HUD** | Soft dependency (downstream) | Reads `creature_happiness_changed`/`creature_bred`/`creature_acquired` for live display only; no functional dependency |
| **Crafting** | None | Confirmed no direct interface by `crafting.md`'s own Dependencies table — Menagerie is listed there only as a future, anticipated consumer of Inventory's Materials tab |

## Tuning Knobs

| Parameter | Default | Safe Range | Too High | Too Low |
|---|---|---|---|---|
| `decay_per_mission` | 8 | 5–15 | Happiness collapses to the floor within 2–3 missions even with occasional tending, making the quality bonus feel unattainable and punishing players who don't min-max Sanctuary visits | Tending becomes pointless busywork — happiness barely moves without it, undermining the "ongoing care" loop the system exists for |
| `tend_boost` | 20 | 15–30 | A single Tend nearly fully offsets multiple missions of neglect, making the decay rate feel meaningless | Tending doesn't meaningfully recover happiness lost to decay, making the loop feel like a grind with no payoff |
| `happiness_floor` | 20 (fixed) | Fixed — not a balance lever | N/A — this is a floor, not a scaling knob | A lower floor (e.g. 0) would let a neglected creature contribute nothing at all, which is a harsher outcome than the Alpha "floor, not death" decision intends — do not lower |
| `habitat_base_capacity` | 4 | 3–6 | Early-game quality bonus is too easy to max out, removing the incentive to invest in Defense Building expansions | Too few slots make even modest Menagerie investment feel capped almost immediately |
| `habitat_expansion_step` | +2 slots/tier, 3 tiers (max 10) | 1–3 slots/tier, 2–4 tiers | Habitat capacity trivializes the Defense Building structure cost curve (once that GDD exists) | Expansion barely matters, making Defense Building's habitat structure feel like a low-value build target |
| `quality_bonus_coefficient` | 0.5 (fixed in Formula 3) | Fixed — changing this would move the output range outside the registered `menagerie_quality_bonus` [1.0, 1.5] bounds | N/A — any increase pushes the max bonus above the registry ceiling, requiring a registry-wide revision across Resource Economy | N/A — any decrease means even a perfectly-tended Menagerie can't reach the registered 1.5 ceiling, wasting the top of Resource Economy's own tuned range |
| `base_lure_cost` | 3 | 2–5 | Acquiring even Tier 1 species drains `menagerie_lure` faster than the rare-find drop chance replenishes it, stalling the whole system | Lure becomes nearly free, trivializing the "rare find" fantasy `resource-economy.md` built `menagerie_lure` around |
| `base_breeding_duration` / `tier_breeding_penalty` | 2 / 1 | 1–4 / 0–2 | Breeding feels too slow to matter across a normal play session, discouraging the mechanic entirely | Breeding completes almost instantly, making the pen feel like a formality rather than a deliberate investment |
| `breeding_pen_capacity` | 2 pens (4 slots) | 1–4 pens (fixed at Alpha — not intended as a live-tunable balance lever, more a scope decision) | Too many concurrent breeding pairs dilutes the significance of any single pairing | A single pen removes the "which pairing do I prioritize" decision entirely |
| `starting_happiness` | 70 | 50–85 | New creatures start near-maxed, making early Lure investment feel disconnected from the tending loop | New creatures start too low, making a freshly-lured creature feel like a liability until several Tend actions land |

## Visual/Audio Requirements

### Habitat view — diorama treatment

The habitat is the first system in the project to present living creatures as first-class visual subjects, and it must read as a physical diorama, not a panel-and-icon screen — consistent with the art bible's "wizard's cabinet" anchor. Concretely, this means:

- The habitat renders as a bounded scene (a terrarium/enclosure box, walled and floored, seen from the same oblique camera angle used elsewhere) rather than a grid of icons. Creatures are placed as individual sprites *inside* this space at hand-carved-miniature scale, each casting the standard stacked-sprite cast shadow.
- Creatures are arranged by simple placement rules, not a slot grid: each occupies a loosely-defined "spot" within the habitat bounds (a light invisible grid for layout purposes only — never rendered as UI chrome). Multiple creatures in one habitat should visibly cluster or space themselves so the habitat reads as inhabited, not itemized.
- Idle creatures animate continuously (idle-wander/idle-fidget loops) rather than sitting as static icons — this is the single biggest differentiator from Inventory/Crafting's flat icon language and is non-negotiable for the diorama read.
- **Pillar 3 externally-visible trace**: habitat population and species variety must be visible from the sanctuary's main view, not just from inside the Menagerie screen — at minimum, occupied habitats should be visually distinguishable from empty ones at the sanctuary-overview zoom level (e.g., empty enclosure vs. populated enclosure silhouette), so a player who has invested in Menagerie has a visibly different sanctuary on the main play screen, satisfying the pillar test without requiring the player to drill into the Menagerie screen to prove it.

### Happiness state visualization

Three states — Thriving / Neutral / Neglected — mapped to `creature_happiness_changed`'s `new_happiness` via threshold bands (exact numeric thresholds owned by systems-designer). Each state is communicated primarily through **creature posture and animation**, with color as a secondary confirmatory cue only, per the colorblind-safety discipline already established in Inventory/Crafting:

| State | Primary cue (posture/animation) | Secondary cue (color) | Non-color backup |
|---|---|---|---|
| Thriving | Active idle-wander loop, upright/alert posture, occasional "happy" gesture animation (species-specific, e.g., a tail-wag or perk-up) | Faint warm highlight rim (Herald Gold, low intensity, sprite-tint not bloom — per the Godot 4.6 glow constraint) | Animation state alone is fully legible with color disabled |
| Neutral | Idle-wander loop, neutral posture, no gesture animation | No tint (creature renders at native palette) | Default/baseline state, always legible |
| Neglected | Slumped/low posture, reduced or halted idle-wander (creature sits in place, minimal motion), periodic "distress" animation (species-specific, e.g., head-down or curled posture) | Faint desaturating tint (creature's own colors pull toward grey, not toward a warning hue — avoids implying "damage") | Motion/posture reduction alone is fully legible with color disabled; this is the primary tell since a static or slumped creature reads unambiguously even in a screenshot |

This deliberately avoids a health-bar-style meter as the *primary* read (a meter may still exist as a secondary at-a-glance UI element per UI Requirements below, but the creature itself must sell the state through behavior, matching the art bible's "creatures are subjects, not stat-holders" framing implied by the diorama anchor).

`quality_bonus` (the gameplay payoff for sustained high happiness) gets no separate visual treatment beyond the Thriving state's existing highlight rim — a second escalation tier would fragment the three-state read established above, and the bonus is better surfaced numerically in the at-a-glance UI (see UI Requirements).

### Tend/feed action feedback

A single unified feedback moment regardless of species or exact tending mechanic (mechanic itself is out of scope here, per the design brief):

- On action confirm: a brief, warm one-shot particle burst at the creature's position (small scale, consistent with the "information over spectacle" visual tone — reads as "attention received," not a reward-cascade moment) plus an immediate posture perk-up if the creature was in a Neglected or Neutral state.
- The happiness-state color/posture system above updates on the next `creature_happiness_changed` emission — no separate "before/after" transition animation is required beyond the state table's own posture change, keeping this a lightweight, frequent-action-appropriate feedback moment (this is meant to be done often, unlike breeding or sacrifice below).

### Breeding pen — visual distinction and offspring-arrival moment

The breeding pen is a **visually distinct sub-enclosure** from the main habitat — smaller, separately framed (its own bounded diorama box, e.g., nested within or adjacent to the main habitat scene), signaling "this is a different purpose, not just another habitat slot." Creatures moved here (`creature_moved_to_breeding_pen`) visually transition into this enclosure rather than simply disappearing from the main habitat and reappearing in a pen list.

The `creature_bred` offspring-arrival moment is a **one-shot discovery/reward beat**, comparable in weight to Constellation's rune-discovery and Crafting's unlock-cascade:

- A brief screen-level pause-beat (not a full modal interrupt) as the offspring sprite is revealed in the breeding pen — new offspring fades/scales in from a soft light-burst (non-bloom, sprite/particle-driven per the Godot 4.6 constraint) rather than simply popping into existence.
- Species identity is revealed as part of this beat (if offspring species selection carries any surprise/variance) — the reveal should hold long enough for the player to read what they got before the beat resolves and the offspring settles into ordinary idle behavior.
- Parent creatures return to the main habitat (`creature_returned_from_breeding_pen`) with a lighter, non-competing transition (simple fade/walk-back), so the offspring reveal remains the single focal moment of the sequence rather than competing with two simultaneous transitions.

### Sacrifice action feedback

Sacrifice (`creature_sacrificed`, feeding a creature permanently into Equipment Forge) is the Menagerie system's designated **loss beat** and is the one interaction in this GDD that intentionally breaks from Crafting's single-confirm convention (justified fully in UI Requirements below). Visually:

- The feedback moment itself should read as deliberate and somber rather than celebratory or neutral: a slow desaturate-and-fade on the creature sprite (echoing the hero-death treatment's noise-dissolve register, but scaled down and without the full-screen effect — this is a creature, not the player-character), accompanied by the resulting item's arrival in Equipment Forge using that system's own existing "item produced" feedback (not a Menagerie-authored effect) — the tonal contrast between "something quietly ends" and "something is gained elsewhere" is the point, and should not be softened into a single celebratory beat.
- No particle burst, no light-burst, no upbeat sting — this is the deliberate inverse of the breeding reveal's treatment, and the two must never be visually confusable.

### Audio direction (category only)

- **Ambient habitat bed**: a low, continuous species-agnostic ambient layer (soft rustle/breathing-adjacent texture) while the Menagerie screen is open — establishes the diorama as a "living" space distinct from Inventory/Crafting's comparatively sterile UI audio.
- **Tend/feed**: a short, warm, low-key confirmation sound (distinct register from Crafting's "assembly" sound and Inventory's "pickup pop" — this is a caretaking action, not an acquisition or construction action).
- **Happiness state changes**: no dedicated stinger for routine fluctuation between Neutral and Thriving (would become noise given decay is continuous); a single soft negative cue only on crossing *into* Neglected (a "something needs attention" alert register, shared conceptually with other systems' low-resource alerts).
- **Breeding offspring-arrival**: a distinct one-shot discovery sting, comparable in production weight to Constellation's rune-discovery and Crafting's unlock-cascade stings — this is one of the system's two "big" audio moments.
- **Sacrifice**: a low, somber one-shot (not silence — silence would read as a bug/non-response) that is clearly *not* a variant of the breeding sting or any other reward sound in the system; paired with the confirmation-dialog audio convention (see UI Requirements) rather than the routine-action sound set.

## UI Requirements

### Overall screen layout

One screen, organized as **habitat view (primary) + a persistent creature roster strip + the breeding pen as an always-visible sub-region**, not a tabbed sub-screen split:

- **Rationale**: unlike Inventory/Crafting's item-grid logic, Menagerie's core content (living creatures with ongoing state) benefits from staying visually present rather than being paged behind tabs — hiding a Neglected creature behind a tab risks the player forgetting it exists, which undermines the tending loop this system is built around.
- Main habitat diorama occupies the dominant screen area (per Visual Requirements above). The breeding pen renders as a smaller, clearly-bounded sub-enclosure within or beside the main habitat view (not a separate tab) — visible at all times, but visually secondary in scale.
- A slim creature roster strip (list, not grid — consistent scale differs from Inventory's item grid since these are living subjects, not stackable items) runs along one screen edge, listing every owned creature regardless of current placement (main habitat or breeding pen), enabling roster-driven navigation without requiring the player to visually hunt across the diorama for a specific creature.
- If habitat count exceeds one screen's diorama space (multiple habitats), habitats are switched via the same shoulder-button category-cycle convention Crafting/Inventory already use for their tab systems — reusing rather than inventing an inconsistent multi-habitat browsing mechanic.

### At-a-glance creature stats

Each creature in the roster strip surfaces, without drill-in:

- A small happiness-state icon (non-color-first, matching the posture-based system above in miniature — e.g., a simplified posture silhouette icon rather than a color dot) plus a thin, secondary color-coded meter sliver for players who want a precise-enough read at a glance; the icon is the source of truth, the meter is confirmatory only, per colorblind discipline.
- Species icon/name.
- Tend-cooldown status as a small radial or icon-badge indicator (ready-to-tend vs. on-cooldown), following Crafting's filled-vs-outline "actionable" visual convention (filled = ready, outline = on cooldown) rather than introducing a new visual grammar for the same underlying "is this actionable right now" concept.

Hovering/focusing a roster entry also highlights the corresponding creature sprite within the habitat diorama (a focus outline around that specific creature), so keyboard/gamepad navigation and the diorama view stay visually linked.

### Tend/feed interaction

Single confirm action per creature, mirroring Crafting's single-confirm convention (this is a frequent, low-stakes, reversible-by-repetition action — the opposite end of the permanence spectrum from sacrifice):

- Select creature (via roster strip or direct diorama focus) → single confirm button performs the tend/feed action.
- If the creature is on cooldown, confirm instead opens a context tooltip stating cooldown remaining (mirrors Inventory/Crafting's "confirm on a non-actionable target opens explanatory context" pattern, rather than doing nothing silently).

### Breeding pen assignment interaction

Multi-select-then-confirm, since this requires selecting 2+ creatures as a set rather than acting on one target:

- Player selects a first creature (roster or diorama) → selection is marked (persistent highlight, not just focus) → player selects a second (and, if the design allows >2, additional) creature → a single confirm action commits the group to the breeding pen, firing `creature_moved_to_breeding_pen` per creature.
- Selection state must be clearly distinct from mere focus/highlight (focus = "currently looked at," selection = "currently queued for breeding") — using a different highlight treatment (e.g., outline color/weight) for each, so a player scrolling the roster while building a breeding group doesn't lose track of what's already queued.
- Canceling a partial selection (before confirm) is a single dedicated action (e.g., a cancel/back button), not requiring the player to re-select each creature individually to deselect.

### Sacrifice interaction — confirmation required

Sacrifice **does** warrant a two-step "are you sure?" confirmation dialog, breaking from Crafting's established single-confirm precedent. Justification:

- Crafting's single-confirm precedent is explicitly scoped to actions the project's tone treats as "routine, frequent, and reversible-by-repetition" (per crafting.md's own reasoning) — sacrifice is none of these. It is a permanent, one-way removal of a creature the player may have invested significant tending/breeding effort into, closer in weight to a "delete my save" class of action than a "craft another item" action.
- Unlike Crafting's material-consumption concern (mitigated there by a pre-confirm preview of projected quantities, since materials are fungible and replaceable), a sacrificed creature is a unique, non-fungible asset — there's no equivalent "preview and proceed" mitigation that fully substitutes for an explicit confirmation, because the loss isn't a quantity changing, it's a specific entity ceasing to exist.
- Interaction shape: select creature → confirm opens a modal dialog stating the creature will be permanently lost and naming the resulting Equipment Forge item → a second, explicit confirm (or cancel) resolves the dialog. This mirrors the "genuinely rare, hard-to-reverse actions get modal confirmation" tone already established as the project's dividing line (per Inventory's discard-vs-Crafting's craft distinction referenced in crafting.md).

### Gamepad navigation model

Follows the same input model established by Inventory/Crafting, adapted to the habitat-view layout rather than a grid/list:

- D-pad/left-stick moves selection through the roster strip using the same 2D spatial adjacency and wrap-at-edges behavior as Inventory's grid; moving "into" the diorama (to focus a specific creature directly rather than via roster) is a single directional press from the roster's edge, treating roster + diorama + breeding pen as one continuous adjacency space, consistent with Crafting's "whole screen as one adjacency space" precedent.
- Shoulder buttons cycle habitats (when multiple exist), matching Crafting/Inventory's shoulder-button category-cycle convention.
- Single confirm button performs context-appropriate action (tend / add-to-breeding-selection / open sacrifice confirmation) depending on current focus and mode — no drag-drop equivalent anywhere in this screen (breeding assignment uses select-then-confirm per above, not drag).
- No hover-only interactions exist; all at-a-glance stats are visible via standard focus states, not mouse-hover-only tooltips (mission-critical status must be visible under gamepad-only play).

### Accessibility notes

- All happiness-state distinctions are posture/animation-first with color as confirmatory only (per Visual Requirements above) — verified against colorblind-safety discipline (art bible Sec 4.5).
- Tend-cooldown's filled-vs-outline convention and sacrifice's modal-confirmation text both carry the same information as any accompanying icon/color, so no state is identifiable by color alone.
- Focus/selection states use distinct, high-contrast outline treatments (not fill-only) to remain legible under low-vision and colorblind conditions, matching Inventory's established focus-highlight standard.
- The offspring-arrival reveal beat and the sacrifice confirmation dialog must both remain screen-reader/text-log compatible where the project's accessibility tooling supports it (i.e., the reveal's species-identity text and the sacrifice dialog's stated consequence must exist as real text elements, not baked-into-art labels).

## Acceptance Criteria

> **Test type key** (per QA story-type gate): **Logic** = automated unit test,
> BLOCKING · **Integration** = integration test or documented playtest,
> BLOCKING · **Visual/Feel** = screenshot + lead sign-off, ADVISORY ·
> **Config/Data** = smoke check, ADVISORY. All ACs below are Logic or
> Integration unless noted otherwise.

### Core Rule 1 — Species Roster

- **AC-1**: GIVEN the full five-species roster (`glimmer_hare`,
  `mossback_toad`, `emberwing_moth`, `duskfang_fox`, `aurora_stag`), WHEN a
  Lure is attempted against any one of them, THEN the action is permitted
  with no additional discovery/unlock gate beyond `has_items(lure_cost)` —
  no species is ever rejected purely for not being "discovered" yet.
  **Naming caveat flagged (qa-lead)**: this AC uses the placeholder species
  identifiers as authored; see Open Questions.

### Core Rule 2 — Lure Acquisition Action

- **AC-2**: GIVEN a selected target species and sufficient `menagerie_lure`
  per Formula 4's cost for that species' tier, WHEN Lure is confirmed, THEN
  `materials_spent` fires for the exact `lure_cost`, one new creature
  instance of that species is created at `starting_happiness = 70`, and the
  action is deterministic — no RNG roll affects species, outcome, or
  starting state.
- **AC-3**: GIVEN a selected target species and insufficient `menagerie_lure`,
  WHEN Lure is confirmed, THEN the action is rejected before any
  `materials_spent` call — no creature instance is created, no state changes.

### Core Rule 3 — Placement on Acquisition

- **AC-4**: GIVEN HABITAT has at least one open slot at the moment Lure
  succeeds, WHEN the new creature instance is created, THEN it is placed
  directly into `HABITAT` (not `RESERVE`), and the transition table's
  `creature_acquired` + aggregate-recompute + `creature_happiness_changed`
  side effects fire (Rule 6). **Interface dependency flagged (qa-lead)**:
  this AC's `creature_acquired` assertion depends on Rule 14's proposed
  event — see Open Questions.
- **AC-5**: GIVEN HABITAT is at full capacity at the moment Lure succeeds,
  WHEN the new creature instance is created, THEN it is placed into
  `RESERVE`, `creature_acquired` fires, but no aggregate recompute or
  `creature_happiness_changed` fires (RESERVE does not contribute to
  Formula 3) — acquisition is never blocked or rejected due to full HABITAT.

### Core Rule 4 — Habitat Capacity

- **AC-6**: GIVEN a fresh save with no Habitat Expansion structures built,
  WHEN HABITAT capacity is queried, THEN it equals the base 4 slots exactly.
- **AC-7**: GIVEN a `sanctuary_structure_built` event for a "Habitat
  Expansion" structure tier, WHEN Menagerie receives it, THEN HABITAT
  capacity increases by exactly +2 slots per tier, up to a maximum of 3
  tiers (10 slots total) — a 4th expansion event, if it ever arrived, would
  not raise capacity further. **Cross-system dependency flagged (qa-lead)**:
  this AC exercises an event emitted by Defense Building, which has no GDD
  yet — not automatable as an isolated Menagerie unit test until Defense
  Building's `sanctuary_structure_built` contract is authored; see Open
  Questions. A documented playtest or a Menagerie-side mock emitting the
  event is the interim test path.

### Core Rule 5 — HABITAT-Only Contribution to Quality Bonus

- **AC-8**: GIVEN one creature in `HABITAT` at happiness 80 and one creature
  in `RESERVE` at happiness 80, WHEN `menagerie_quality_bonus` is computed
  (Formula 3), THEN only the HABITAT creature counts toward `N_habitat` and
  `H_avg` — the RESERVE creature's happiness has zero effect on the result.
- **AC-9**: GIVEN one creature in `HABITAT` and one creature in
  `BREEDING_PEN`, both at happiness 80, WHEN `menagerie_quality_bonus` is
  computed, THEN the result is identical to a single-HABITAT-creature
  scenario (`1.0 + 0.5 × 0.80 = 1.40`) — the BREEDING_PEN creature is fully
  excluded.

### Core Rule 6 — Aggregate Recompute-and-Push (highest-risk rule)

- **AC-10**: GIVEN a creature moves from `RESERVE` into an open `HABITAT`
  slot, WHEN the move resolves, THEN the aggregate (Formula 3) is
  recomputed immediately and `creature_happiness_changed` fires for that
  moved creature, carrying the fresh `quality_bonus` value, within the same
  frame as the transition — not deferred to the next natural
  happiness-changing event.
- **AC-11**: GIVEN a creature moves from `HABITAT` into the breeding pen
  (`creature_moved_to_breeding_pen`), WHEN the move resolves, THEN the
  aggregate is recomputed excluding the now-departed creature, and
  `creature_happiness_changed` fires alongside (not instead of)
  `creature_moved_to_breeding_pen`, carrying the fresh `quality_bonus` —
  both events fire in the same frame, and Resource Economy's cache reflects
  the new aggregate without needing a `quality_bonus` field on
  `creature_moved_to_breeding_pen` itself (which the frozen contract does
  not carry).
- **AC-12**: GIVEN a creature is pulled from `BREEDING_PEN` back to
  `RESERVE` (not HABITAT), WHEN the move resolves, THEN
  `creature_returned_from_breeding_pen` fires but NO aggregate recompute
  and NO `creature_happiness_changed` fire — the creature never touched
  HABITAT during this transition, so Formula 3's inputs are unchanged.
- **AC-13**: GIVEN a HABITAT creature is sacrificed and at least one other
  HABITAT creature remains, WHEN the sacrifice resolves, THEN the
  aggregate recomputes over the remaining HABITAT set, and
  `creature_happiness_changed` fires for the longest-tended remaining
  HABITAT creature (as the designated "representative"), carrying the
  fresh `quality_bonus`, alongside `creature_sacrificed`.
- **AC-14**: GIVEN the last remaining HABITAT creature is sacrificed (no
  other HABITAT creature exists to serve as the representative), WHEN the
  sacrifice resolves, THEN `creature_happiness_changed` is NOT fired at
  that moment (per Rule 6's explicit skip clause) — `creature_sacrificed`
  still fires — and `menagerie_quality_bonus` correctly reports `1.0` on
  the *next* natural happiness-changing event (e.g. the next
  `mission_launched` decay tick, or the next acquisition/move into
  HABITAT), not immediately. **Testability note (qa-lead)**: this AC
  requires asserting an *absence* of an event in the same frame followed
  by a *presence* on a later, specified trigger — an automated test must
  explicitly assert both halves (no emission now; correct value on next
  qualifying event) or it will falsely pass a broken "never recomputes at
  all" implementation.
- **AC-15**: GIVEN two HABITAT-composition-changing actions occur back to
  back with no intervening `mission_launched` (e.g. a move to RESERVE
  immediately followed by a Lure landing directly in the freed HABITAT
  slot), WHEN both resolve, THEN each triggers its own independent
  recompute-and-push in resolution order — no stale aggregate value from
  the first action is ever read by anything downstream before the second
  action's recompute completes.

### Core Rule 7 & Formula 1 — Happiness Start Value and Floor

- **AC-16**: GIVEN a newly-Lured creature, WHEN its `happiness` is checked
  immediately after creation, THEN it equals exactly `70` (the fixed
  `starting_happiness` constant, not derived from Formula 2).
- **AC-17**: GIVEN a HABITAT creature at `happiness = 24`, WHEN one
  `mission_launched` decay tick applies Formula 1 with `decay_per_mission =
  8`, THEN `happiness' = max(20, 24 - 8) = 20` — the floor is respected
  exactly, not overshooting below 20.
- **AC-18**: GIVEN a HABITAT creature already at the floor (`happiness =
  20`), WHEN another `mission_launched` decay tick applies, THEN
  `happiness'` remains `20` — the creature is not removed, does not
  transition state, and continues contributing its minimum share to
  Formula 3 (per the Edge Cases floor-not-death guarantee).

### Core Rule 8 — Mission-Tick Decay Scope

- **AC-19**: GIVEN a mix of HABITAT, RESERVE, and BREEDING_PEN creatures,
  WHEN a single `mission_launched` event fires, THEN only HABITAT
  creatures' `happiness` decays (Formula 1) and have
  `missions_since_tended` incremented — RESERVE and BREEDING_PEN
  creatures' `happiness` values are read identically before and after the
  event.

### Core Rule 9 & Formula 2 — Tend Action

- **AC-20**: GIVEN a HABITAT creature at `happiness = 54`, WHEN Tend is
  confirmed once, THEN `happiness' = min(100, 54 + 20) = 74` and
  `missions_since_tended` resets to `0`.
- **AC-21**: GIVEN a HABITAT creature at `happiness = 90`, WHEN Tend is
  confirmed, THEN `happiness'` clamps to exactly `100`, not `110` —
  overheal has no stored effect.
- **AC-22**: GIVEN a HABITAT creature that was just Tended, WHEN Tend is
  confirmed again on the same creature with no intervening
  `mission_launched`, THEN the action succeeds again immediately — no
  cooldown blocks the second Tend (Rule 9's "no cooldown" guarantee).

### Core Rule 10 — Same-Species Breeding Requirement

- **AC-23**: GIVEN two creatures of the identical species both selected for
  the breeding pen, WHEN the move-to-pen action is confirmed, THEN both
  transition to `BREEDING_PEN`, `creature_moved_to_breeding_pen` fires for
  each, and `breeding_missions_remaining` begins counting once the second
  of the pair joins.
- **AC-24**: GIVEN two creatures of different species both selected for the
  breeding pen, WHEN the move-to-pen action is attempted, THEN it is
  rejected at the eligibility check — no `creature_moved_to_breeding_pen`
  fires for either creature, no state change occurs for either.

### Core Rule 11 & Formula 5 — Deterministic Breeding

- **AC-25**: GIVEN two Tier 1 (`glimmer_hare`) creatures paired in a
  breeding pen, WHEN `breeding_missions_remaining` is computed (Formula 5),
  THEN it equals exactly `2` (`2 + 1×(1-1)`).
- **AC-26**: GIVEN two Tier 3 (`aurora_stag`) creatures paired in a
  breeding pen, WHEN `breeding_missions_remaining` is computed, THEN it
  equals exactly `4` (`2 + 1×(3-1)`).
- **AC-27**: GIVEN a breeding pair with `breeding_missions_remaining = 1`,
  WHEN the next `mission_launched` fires, THEN the counter decrements to
  `0`, exactly one offspring instance of the parent species is created
  directly into `RESERVE` (never HABITAT), `creature_bred` fires exactly
  once, and both parent creatures remain in `BREEDING_PEN`, unconsumed and
  eligible to begin another breeding cycle immediately. No RNG determines
  whether breeding succeeds or what species the offspring is — outcome is
  fully determined by the parents' shared species and the elapsed mission
  count.

### Core Rule 12 — Breeding Pen Capacity

- **AC-28**: GIVEN both breeding pens already occupied by 2 pairs (4
  creatures total), WHEN a player attempts to move a 5th creature into the
  breeding pen, THEN the action is rejected — no open pen slot exists, and
  this capacity is fixed (not expandable via Defense Building or any other
  mechanism at Alpha).

### Core Rule 13 — Sacrifice Validation and Ownership

- **AC-29**: GIVEN a creature currently in `RESERVE` or `HABITAT`, WHEN
  Equipment Forge calls `Menagerie.request_sacrifice(creature_id, target_item_id) -> bool`,
  THEN Menagerie validates the request, transitions the creature to
  `SACRIFICED` (terminal), and Menagerie itself — not Equipment Forge —
  emits `creature_sacrificed(creature_id, target_item_id)`, passing
  `target_item_id` through unchanged from the call (Menagerie does not
  validate or interpret it — see the Equipment Forge Interactions-table row
  above). **Signature adopted 2026-07-17** from `equipment-forge.md` Rule
  19d, closing the gap this AC previously left unnamed. Now automatable as
  a full integration test against Equipment Forge's authored GDD, not just
  a Menagerie-side mock.
- **AC-30**: GIVEN a creature currently in `BREEDING_PEN`, WHEN Equipment
  Forge requests sacrifice against its `creature_id`, THEN the request is
  rejected outright — no `creature_sacrificed` fires, no state change — and
  the creature only becomes sacrifice-eligible after being separately
  removed from the pen first (a distinct player action).
- **AC-31**: GIVEN a creature acquired zero missions ago (same-session
  Lure), WHEN Equipment Forge requests sacrifice against it, THEN the
  request is accepted with no minimum-age rejection.

### Core Rule 14 — Proposed `creature_acquired` Event

- **AC-32** *(BLOCKED pending event-bus.md adoption)*: GIVEN a successful
  Lure action, WHEN the new creature instance is created, THEN
  `creature_acquired(creature_id: String, species: String)` fires exactly
  once, regardless of whether the creature lands in HABITAT or RESERVE.
  **Interface dependency flagged (qa-lead)**: `creature_acquired` is not
  yet in `event-bus.md`'s frozen catalogue (Rule 14) — this AC, and AC-4's
  partial dependency on the same event, cannot be exercised as a true
  cross-system integration test until the event is catalogued. A
  Menagerie-internal unit test asserting the signal is emitted locally is
  the interim, partial test path; full Encyclopedia/Mission HUD subscriber
  behavior remains untestable until then. See Open Questions.

### Formula 3 — Aggregate `menagerie_quality_bonus`

- **AC-33**: GIVEN zero creatures in HABITAT, WHEN `menagerie_quality_bonus`
  is computed, THEN it returns exactly `1.0` — the `N_habitat = 0` floor
  case, not a divide-by-zero error or undefined result.
- **AC-34**: GIVEN three HABITAT creatures at happiness 82, 70, and 55,
  WHEN `menagerie_quality_bonus` is computed, THEN `H_avg = 69.0` and the
  result is `1.345` exactly, matching Formula 3's worked example.
- **AC-35**: GIVEN a single HABITAT creature at the happiness floor (20),
  WHEN `menagerie_quality_bonus` is computed, THEN the result is `1.10`
  exactly — the lowest non-zero-HABITAT value the formula can produce
  under normal floor conditions.
- **AC-36**: GIVEN HABITAT creatures whose average happiness would compute
  above 1.5 or below 1.0 under any tuning-knob drift, WHEN
  `menagerie_quality_bonus` is computed, THEN the result is clamped to
  stay within `[1.0, 1.5]` — the registry's bounds are never exceeded
  regardless of input.

### Formula 4 — Lure Acquisition Cost

- **AC-37**: GIVEN `base_lure_cost = 3` (default) and a Tier 1 target
  species, WHEN `lure_cost` is computed, THEN it equals exactly `3`.
- **AC-38**: GIVEN `base_lure_cost = 3` and a Tier 3 target species
  (`aurora_stag`), WHEN `lure_cost` is computed, THEN it equals exactly `9`.

### Formula 5 — Breeding Duration (see also AC-25/AC-26)

- **AC-39**: GIVEN `base_breeding_duration = 2` and `tier_breeding_penalty
  = 1` (defaults), WHEN `breeding_missions_remaining` is computed across
  all three tiers, THEN the results are exactly `2`, `3`, and `4` for
  Tiers 1, 2, and 3 respectively — matching the documented 2–4 output
  range with no gaps or off-by-one errors at Tier 2 (the one tier not
  covered by Formula 5's own worked examples).

### Edge Cases

- **AC-40**: GIVEN a creature at the happiness floor for an extended
  period (multiple un-tended `mission_launched` ticks past reaching 20),
  WHEN its state is checked, THEN it remains a fully functional HABITAT
  creature — no removal, no forced eviction, no state-machine transition
  triggered purely by floor happiness.
- **AC-41**: GIVEN a creature moved to the breeding pen and back to
  HABITAT within the same Sanctuary session (no `mission_launched` between
  the two moves), WHEN both transitions resolve, THEN the aggregate
  recomputes cleanly on each transition with no stale or double-counted
  value at any point, and the creature's `happiness` is unchanged by the
  toggle itself (only a subsequent decay tick, if any, would change it).
- **AC-42**: GIVEN up to the Rule 4 maximum of 10 HABITAT creatures, WHEN
  a single `mission_launched` fires, THEN each of the 10 creatures'
  `creature_happiness_changed` fires independently (10 total emissions in
  one frame), which stays under EventBus's `eventbus_batch_threshold`
  (20/frame) — no batched/deferred dispatch is required or expected for
  this event at Alpha's maximum HABITAT size.
- **AC-43**: GIVEN a save file with an active breeding pen holding
  `breeding_missions_remaining = 1` at save time, WHEN the save is
  restored and a subsequent `mission_launched` fires, THEN the counter
  decrements from the restored value of `1` to `0` and produces offspring
  on that tick — the timer is neither reset nor paused by the save/load
  cycle itself.

### States and Transitions

- **AC-44**: GIVEN a creature in any of `RESERVE`, `HABITAT`, or
  `BREEDING_PEN`, WHEN a sacrifice request is validated and accepted
  against it, THEN it transitions to `SACRIFICED` and no further state
  transition is ever possible from that instance — `SACRIFICED` is a
  verified terminal state with no reverse edge in the transition table.
- **AC-45**: GIVEN a breeding offspring is created, WHEN its initial state
  is checked, THEN it is `RESERVE`, never `HABITAT` — unlike a Lure
  acquisition (AC-4/AC-5), a bred offspring is never auto-placed even if
  HABITAT has an open slot (Rule 11's explicit exception to the Lure
  auto-placement rule).
- **AC-46**: GIVEN every state-and-trigger pair enumerated in the States
  and Transitions table, WHEN each is exercised in isolation, THEN the
  resulting state and every listed side effect (event emissions, aggregate
  recompute, breeding-timer start/discard) match the table exactly — this
  AC exists to confirm full table coverage rather than duplicate the more
  granular ACs above (AC-4, AC-5, AC-10 through AC-15, AC-23, AC-27,
  AC-29, AC-44, AC-45 already cover the individual rows).

## Open Questions

| Question | Owner | Notes |
|---|---|---|
| `creature_acquired(creature_id: String, species: String)` does not exist in `event-bus.md`'s frozen catalogue yet | EventBus owner | **New event this GDD originates** (Rule 14) — same precedent as Inventory's `item_pickup_rejected` and Tower's `tower_component_returned`. AC-4 and AC-32 are both flagged (qa-lead) as blocked or partial pending its adoption; full Encyclopedia/Mission HUD subscriber testing cannot proceed until then. |
| Defense Building's "Habitat Expansion" structure has no GDD yet | Defense Building System owner | Soft/anticipated dependency (Rule 4) — Menagerie only fixes the slot-count curve (+2/tier, max 3 tiers) and expects `sanctuary_structure_built`; the structure's own material/gold cost, build prerequisites, and exact event payload shape are Defense Building's to define. AC-7 is flagged (qa-lead) as not fully automatable in isolation until that contract exists. |
| Real species names (`glimmer_hare`, `mossback_toad`, `emberwing_moth`, `duskfang_fox`, `aurora_stag` are placeholders per Rule 1) | game-designer | Same caveat pattern `inventory.md` already applies to its own rarity-tier material names — these are not final creative-approved names. The mechanism above (tier assignment, lure cost, breeding pairing) is name-agnostic and works unchanged once real names are assigned; AC-1/AC-25/AC-26/AC-37/AC-38 reference the placeholder identifiers as authored and will need no logic change, only a naming pass. |
| ~~Equipment Forge's sacrifice-consumer contract has no GDD yet~~ **RESOLVED (2026-07-17)** | Equipment Forge System owner | `equipment-forge.md` is now authored and Rule 19d's `Menagerie.request_sacrifice(creature_id, target_item_id) -> bool` signature has been adopted into Rule 13 and the Interactions/Dependencies tables above. AC-29/AC-30/AC-31 are now fully automatable as integration tests against Equipment Forge's authored GDD, not just a Menagerie-side mock. |
| Whether a full initialization/save-restore sweep needs to re-fire `creature_happiness_changed` with the restored aggregate immediately on load, or waits for the next natural trigger | systems-designer | Not explicitly specified by Rule 6 or the Save & Persistence interaction row — Resource Economy's cache could read a stale pre-save aggregate for one extra frame/session-start window if no restore-time push exists. Flagged during AC authoring (qa-lead); no AC currently exercises this because the GDD doesn't specify a behavior to test against. |
| Exact numeric happiness thresholds for the Thriving/Neutral/Neglected visual bands | systems-designer (per Visual Requirements' own note) | Out of scope for Acceptance Criteria — these are Visual/Feel-classified UI bands (ADVISORY gate: screenshot + lead sign-off), not Logic-tier testable thresholds, and the GDD explicitly defers the exact numbers already. |

Content type classification note (qa-lead): the majority of this GDD's ACs are **Logic** (formulas, state machine, decay/tend/breeding math) — BLOCKING gate, automated unit tests required in `tests/unit/menagerie/`. AC-7, AC-29, AC-30, AC-31, and AC-32 are **Integration**-classified (BLOCKING gate) but currently only partially satisfiable as isolated Menagerie-side tests pending the three undesigned/uncatalogued external contracts listed above — full cross-system integration coverage should be re-run once Defense Building, Equipment Forge, and the `creature_acquired` event are each finalized. The Visual/Audio/UI Requirements sections above are Visual/Feel and UI classified (ADVISORY gate: screenshot/manual-walkthrough evidence, not automated tests) and are intentionally not converted into ACs here.
