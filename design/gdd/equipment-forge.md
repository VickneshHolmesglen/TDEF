# Equipment Forge System

> **Status**: Approved (`/design-review --depth lean` re-review 2026-08-27 — all 4 upstream blockers resolved, no blocking items remain)
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-08-27 (all 4 upstream blockers confirmed resolved — stale since 2026-07-17)
> **Implements Pillar**: Everything Connects · The Sanctuary Is Your Statement
> **Closes**: `menagerie.md`'s `target_item_id` open question (creature sacrifice → new item). **Known gaps — ALL RESOLVED, found stale 2026-08-27** (previously: 10 ACs blocked): `Inventory.apply_rune_to_item()` and `Inventory.has_room_for()` both shipped in `inventory.md`'s Cross-System Query & Mutation APIs section (2026-07-17); `Menagerie.request_sacrifice(creature_id, target_item_id)` shipped in `menagerie.md` Rule 13/`menagerie.gd` (2026-07-17), matching this doc's Rule 19d signature exactly; Constellation's `restore_order` (24) was assigned 2026-07-17, closing `constellation.md`'s OQ-1. See Open Questions and the "Upstream Assumption Fragility" table in Dependencies (both updated to match).
> **Rename, 2026-08-11**: the tab-strip/screen this GDD describes is now presented to the player as **"Forge"** (`SANCTUARY_TAB_EQUIPMENT_FORGE` label text changed; the `ROOM_EQUIPMENT_FORGE` state key and `equipment_forge_screen.gd`/`EquipmentForgeScreen.tscn` file/class names are unchanged — a display-only rename, not a new room). The Craft/Imbue two-tab layout this section describes is now 2 of 3 tabs on that same screen; the third (**Upgrade Buildings**) is a separate mechanic owned by its own GDD, not by this one: see `design/gdd/building-upgrade.md`.
> **Relocation, 2026-08-21**: **Assemble Towers** (formerly this screen's 4th tab) moved to the Crafting panel inside `InventoryScreen.tscn` (Recipes/Assemble Towers sub-tab under the Inventory & Crafting room) — player-requested, since `TowerAssembly.assemble_tower()` consumes items Crafting itself produces (Foundation/Weapon/Focus/Power Tower Components), not anything Forge-specific. Forge no longer has an Assemble tab; see `design/gdd/crafting.md`'s UI Requirements and `design/quick-specs/tower-assembly-2026-08-11.md` for the current location.

## Overview

The Equipment Forge System is the sanctuary's convergence layer — the final crafting surface, and the only one that draws its inputs from every other system at once. It has two halves. The first is ordinary and closely mirrors the Crafting System's model: it consumes Materials from the shared inventory against author-defined recipes to produce Hero Equipment (the weapon, armor, and accessory slots the Hero System equips), gating unbuildable recipes until their inputs are met and, on craft, atomically consuming the required material stacks and writing the finished piece back into inventory. The second half is what makes the system distinct: **rune imbuing**. It takes a piece of hero equipment the player already owns and fuses a discovered rune into it *in-place* — modifying the existing item rather than producing a new one — where those runes are sourced from three separate upstream systems, each earned in its own way: a **Constellation** rune (from completing a spatial tower pattern), a **Tarot** rune (from mastering a deck card), and a **Menagerie** sacrifice (surrendering a tended creature to produce or enhance an item). Unlike Crafting's fungible material counts, runes are singular, non-fungible inputs that already carry a specific history, and imbuing is permanent and consuming. Like Crafting and the Menagerie, the Forge is strictly Sanctuary-only — locked for the duration of a mission, available only between runs — and all cross-system inputs arrive through the EventBus and the shared inventory rather than direct references. Player-facing, it turns proof of mastery earned in three or four unrelated corners of the game into a single object the hero physically carries into battle: the resulting item is not merely strong, it is a wearable record of the specific choices that made it.

## Player Fantasy

> The forge doesn't make new proof. It gathers the proof you earned everywhere else — and welds it into one thing you can wear into the fight.
>
> This is the last bench, and it was always going to be last. Everywhere else in the sanctuary you work with one kind of thing at a time: raw material at the crafting panel, towers on the field, creatures in the habitats, a deck in your hands. The Forge is the only place where those separate labors are allowed to touch. It has an ordinary half — it takes materials and makes the hero a sword, a guard, a set of boots, the same honest way Crafting makes a tower's parts. But its real work begins when you set a rune on the bench. And a rune is never raw. Every one of them arrived here already carrying where it came from: this one from the constellation you first closed on mission twelve, this one from the card you finally mastered fifty missions deep, this one from the creature you raised and then chose to give up. You did not find these on the floor of a fight. You earned each of them in a completely different corner of the game, under completely different rules — and the Forge is where they finally meet.
>
> So the decision here is not *what can I make*. You already made these — elsewhere, at cost. The decision is which of them to fuse, and into what, because you cannot spend them all and you cannot get most of them back. You stand at the bench with three or four proofs of three or four different masteries in front of you, each one singular, none of them interchangeable the way a stack of ore is interchangeable, and you choose which strands of your own history to weld into the single piece of gear you will actually wear into the next wave. A rune spent here is a wager you already won being staked one more time — the composition you were proud of, the card that paid, the creature you loved and surrendered — pressed permanently into one object. Nothing else in the sanctuary asks you to gather the best of what you did everywhere and commit it, all at once, to one thing you carry on your body.
>
> This is the line between the Forge and the crafting bench beside it. Crafting *originates*: it reaches into a heap of undifferentiated material that means nothing yet and pulls out a thing that did not exist before — and once that thing leaves the bench it forgets where it came from; a tower does not remember it was ever silk. The Forge does the opposite. It originates nothing. Every rune it touches already existed, already meant something specific, already had a story attached before it ever reached this table. The Forge's work is not to bring meaning into being but to *concentrate* meaning that already exists — to take proof that is currently scattered across five systems and five different feelings and gather it into one place small enough to hold. Crafting gives you the piece. The Forge gives you the piece that remembers.
>
> Because that is what comes off this bench: not a good sword, but a wearable timeline. The finished item is a physical record of specific choices you made in every far corner of the sanctuary — the exact pattern, the exact card, the exact creature — carried now on the hero's body into the one place all of it was ever for. Every other system proves one thing. A tower proves you were right about a decision. A constellation proves you were right about an arrangement. The Menagerie proves you kept faith over time. The Skill Build proves you understood what your choices would become. The Forge is the only bench that can prove they were never separate — that the composition and the wager and the creature you let go were, the whole time, one story, and here it is, forged into a single object you can close your hand around and carry into the fight. That is the recognition the Forge gives you that no single system ever could: not that one thing you did was right, but that all of it converges — that everything, finally and literally, connects.

## Detailed Design

### Core Rules

> **Reading order note**: this GDD converges seven upstream systems (Hero,
> Crafting, Menagerie, Constellation, Tarot, Inventory, Save & Persistence),
> all Designed/Approved for the first time as of this authoring pass. Every
> rule below that borrows an assumption from one of those seven documents is
> marked **[Upstream: <doc>]**. The full list of borrowed assumptions and what
> breaks if each upstream document changes is consolidated in **Dependencies →
> Upstream Assumption Fragility** at the end of this GDD — read that section
> before revising any of the seven upstream GDDs.

**Hero Equipment Slots**

1. **The hero has exactly 10 fixed equipment slots**: `helmet`, `chest`,
   `gloves`, `pants`, `boots`, `main_hand`, `neck`, `ring_1`, `ring_2`,
   `offhand`. **Expanded 2026-08-16 (player-requested)** from an earlier
   5-slot model (`weapon`/`armor`/`accessory_a`/`accessory_b`/`trinket`) to
   match a Diablo-style paperdoll layout the player specified directly —
   left column top-to-bottom Helmet/Chest/Gloves/Pants/Boots with Main Hand
   at the bottom of that column, right column top-to-bottom Neck/Ring 1/
   Ring 2 with Offhand at the bottom of that column. **Flagged assumption/
   origination** **[Upstream: hero.md]** — `hero.md` never fixes this number
   (checked; its 12-stat model and skill-slot rules are silent on gear slot
   count). `inventory.md`'s Rule 5a explicitly deferred its "≥4 free
   discretionary slots" floor check until Hero or Equipment Forge fixed a
   concrete number; this GDD is that fixing document. `inventory_starting_
   slot_count` was raised from 10 to 14 (registry constant) alongside this
   expansion, then to 18 later the same day after a live playthrough found
   14 (10 locked + 4 free, exactly at the floor) too tight in practice — 10
   mandatory-locked Hero equipment slots now leaves 8 free, well clear of the
   ≥4 floor. **This check considers Hero equipment locks only** — Tower System's per-placed-tower
   component lock count (a separate, larger source of locked slots per
   `inventory.md`'s own Defense Building row) is not fixed by any GDD yet and
   is explicitly out of scope here; Inventory's Rule 5a floor must be
   re-verified once that number exists too.
2. Each slot accepts exactly one Equipment item matching that slot's category
   (`weapon`/`offhand`/`helmet`/`chest`/`gloves`/`pants`/`boots`/`neck`/`ring`
   — `ring_1` and `ring_2` both accept the generic `ring` category, mirroring
   the old `accessory_a`/`accessory_b` precedent this replaces; there is no
   ring-subtype restriction at Alpha. Every other slot maps 1:1 to its own
   category). Equipment items are `stack_cap=1`, unique per-instance, per
   `inventory.md`'s already-established schema — no new stacking rule is
   introduced here.
3. Equipping/unequipping into a named Hero slot is an Inventory-owned action
   (`equipment_slot_changed(slot, new_item_id, previous_item_id)`,
   Inventory-emitted per `inventory.md`) — Equipment Forge does not perform
   the equip action itself; it only crafts/imbues the items that end up in
   these slots. **Confirmed non-direct-coupling** **[Upstream: hero.md]**:
   Hero reads equipment state passively by subscribing to
   `equipment_slot_changed` for stat recalculation (`hero.md`'s Interactions
   table) — Equipment Forge never calls Hero directly, in either direction,
   for equip/unequip or stat recalculation. The only direct Hero-facing event
   Equipment Forge itself emits is `item_rune_imbued`, which Hero also reaches
   via its own EventBus subscription, not a direct call (Rule 14 below).

**Equipment Crafting — Recipe Model**

4. An **Equipment Recipe** (`EquipmentRecipeResource`) extends Crafting's
   `RecipeResource` pattern **[Upstream: crafting.md]** rather than
   reinventing it — same fixed, author-defined, never-rolled output
   philosophy (`crafting.md` Rule 1's flagged assumption applies identically
   here: no stat-rolled variance). Fields:

   | Field | Type | Description |
   |---|---|---|
   | `recipe_id` | StringName | Unique identifier |
   | `recipe_category` | String | Fixed literal `"hero_equipment"` — a new value alongside Crafting's existing `"tower_component"`/`"crafted_good"` |
   | `output_slot` | String | `weapon`/`offhand`/`helmet`/`chest`/`gloves`/`pants`/`boots`/`neck`/`ring` (Rule 1's slot categories — **not** Tower's `foundation`/`weapon`/`focus`/`power`; these are two independent vocabularies that happen to share the string `"weapon"`, a naming collision flagged as a content-authoring caution, not a mechanical conflict) |
   | `inputs` | Dictionary[StringName, int] | `material_id → quantity`, 1–3 material types, same rarity-tiered materials Crafting consumes |
   | `tech_prerequisite` | StringName | `tech_id` from Defense Building's tech tree, or `""` if ungated |
   | `output_item_id` | StringName | The crafted Equipment item's definition id |
   | `quality_tier` | int | `1`–`4`, reusing Crafting's convention exactly (Rule 5 below) |
   | `rune_slot_count` | int | Fixed per `output_slot` (Rule 11) — not authored per-recipe, always matches the slot-type table |

5. `quality_tier` (1–4) reuses Crafting's own authoritative definition
   **[Upstream: crafting.md]** unchanged: a content-authoring signal
   indicating where in the output item's stat range a fixed recipe sits, not
   a rolled value and not a new schema concept. The `hero_equipment_crafted`
   event's `quality_tier: int` field (frozen, `event-bus.md`) carries this
   value.
6. **Catalogue scope (Alpha, flagged assumption)**: this GDD defines the
   mechanism only. A representative catalogue of 6–10 Equipment Recipes
   spanning all 9 slot categories × a spread of tiers is sufficient for
   Alpha — full itemization is content-authoring work, matching Crafting's
   own explicit scope boundary (`crafting.md` Open Questions).

**Equipment Recipe Discovery**

7. Discovery reuses Crafting's exact two-gate model **[Upstream:
   crafting.md]** (tech gate + material gate, both true simultaneously →
   permanent discovery) and reuses the already-frozen `recipe_discovered`
   event (`event-bus.md`) rather than inventing a parallel event — this GDD
   proposes extending `recipe_discovered`'s Key Subscribers list from
   "Encyclopedia, Crafting UI" to "Encyclopedia, Crafting UI, Equipment Forge
   UI" (no payload change; `recipe_category: String` already generically
   supports the new `"hero_equipment"` value). **Flagged for
   `event-bus.md` sign-off** — same low-risk-extension pattern already used
   elsewhere in this project (e.g. `component_crafted` carrying both
   `tower_component` and `crafted_good` semantics under one event).
8. Craftability (whether an Equipment Recipe's craft action is currently
   enabled) is continuously re-evaluated on `item_added`/`item_removed`,
   independent of the one-time discovery event — identical semantics to
   Crafting Rule 4's Discovery/Craftability split.

**Equipment Crafting Resolution**

9. On confirmation of a craftable Equipment Recipe, Equipment Forge performs,
   in order, mirroring Crafting Rule 8 exactly **[Upstream: crafting.md]**:
   (a) re-validate `has_items(inputs)`, (b) validate `has_room_for(output_slot,
   1)` (new Inventory pre-check, Rule 16), (c) batch-consume `inputs` via
   Inventory, (d) construct the output Equipment item (with
   `rune_slot_count` free rune slots per Rule 11's table, all empty) and add
   it via `item_added`, (e) emit `hero_equipment_crafted(item_id, item_type =
   output_slot, quality_tier)`. Steps (a)–(e) execute synchronously and
   atomically within one confirm — instant on confirmation, no timer, no
   queue, matching Crafting's own Rule 9 rationale (Sanctuary is a
   deliberate-planning space, not an idle-waiting space).

**Save Payload Ownership Clarification**

10. **Equipment Forge's own registered `get_save_data()` payload is narrower
    than `save-persistence.md`'s Line 81 summary** ("All crafted equipment in
    the hero's forge inventory") **[Upstream: save-persistence.md,
    inventory.md]**. Per `inventory.md`'s architecture principle ("every
    system that touches player possessions reads and writes through this
    single ledger" — Overview), actual Equipment item instances (including
    each item's `imbued_runes: Array[String]` and remaining free rune slots,
    carried in `item_added`'s `metadata` field, same convention as Tower's
    `damaged` flag) are persisted by **Inventory**, not re-persisted by
    Equipment Forge. Equipment Forge's own save data covers exactly two
    ledgers: (1) the Equipment Recipe Discovery Ledger (Rule 7/States and
    Transitions), and (2) the available (unimbued) Rune Ledger (Rule 12).
    **Flagged for `save-persistence.md` follow-up**: its own payload
    description should be corrected to match this clarification at its next
    revision pass; this GDD's version is authoritative.

**Rune System — Slot Model**

11. Every Equipment item has a fixed **rune slot count**, determined solely
    by its `output_slot` category (never authored per-recipe, never rolled).
    **Expanded 2026-08-16** alongside Rule 1's 5->10 slot expansion — the
    old armor-tier count (2) carries forward to every armor-piece slot, and
    the old accessory/trinket-tier count (1) carries forward to neck/ring;
    offhand is new and set to the lighter 1-rune tier (matching the old
    accessory/trinket tier, not the 2-rune weapon tier):

    | `output_slot` | `rune_slot_count` |
    |---|---|
    | `weapon` | 2 |
    | `offhand` | 1 |
    | `helmet` / `chest` / `gloves` / `pants` / `boots` | 2 |
    | `neck` | 1 |
    | `ring_1` / `ring_2` (category `ring`) | 1 |

    **Flagged assumption/origination** — no other GDD defines rune slot
    counts. Total possible simultaneously-imbued runes across a full 10-slot
    loadout: 16 (weapon 2 + offhand 1 + 5 armor pieces x 2 + neck 1 + 2 rings
    x 1). Small, fixed counts are a deliberate choice (per this project's
    "small, meaningful choice sets" scope discipline) — "which item gets
    this rune" must stay a real decision, not a rubber stamp.
12. **Rune Ledger (Constellation/Tarot-sourced)**: Equipment Forge maintains
    its own playthrough-scoped, save-persisted ledger,
    `available_runes: Dictionary[rune_id, {rune_source: String, stat_delta:
    Dictionary}]`, populated the moment `constellation_rune_discovered
    (rune_id, pattern_id)` **[Upstream: constellation.md]** or
    `tarot_rune_discovered(rune_id, card_id)` **[Upstream: tarot.md]** fires —
    both are one-way, permanent Discovery Ledger events per their owning
    GDDs, so a rune entering this ledger can never be un-discovered (see
    Edge Cases). `stat_delta` is authored by Equipment Forge itself (Formula
    3) — **deliberately decoupled** from whatever internal mechanical effect
    Constellation or Tarot separately apply for that same discovery (see
    Upstream Assumption Fragility for the consequence if this decoupling
    assumption ever breaks).
13. **Rune Ledger (Menagerie-sourced) is handled differently — see Creature
    Sacrifice Resolution (Rules 17–20)**: a Menagerie-sourced rune is never
    added to the `available_runes` ledger as a separate imbuable entry.
    Instead, it is consumed immediately, in the same operation that creates
    it, into a newly-crafted Equipment item — this is the one deliberate
    asymmetry between the three rune sources (flagged explicitly, not an
    oversight): Constellation/Tarot runes are discovered independently of any
    specific item and wait in the ledger for the player to choose a target;
    a Menagerie rune is inseparable from the sacrifice that produced it.

**Rune Imbuing Action (Constellation/Tarot-sourced runes)**

14. Rune Imbuing is a Sanctuary-only, player-initiated action: the player
    selects (a) an owned Equipment item with at least one free rune slot
    (Rule 11) — **equipped or unequipped, no restriction** — and (b) one
    entry from the `available_runes` ledger (Rule 12). On confirm, Equipment
    Forge calls the new `Inventory.apply_rune_to_item(item_id: String,
    rune_id: String, stat_delta: Dictionary) -> bool` interface (Rule 16),
    and on success: removes the rune from `available_runes` (Rule 15), and
    emits `item_rune_imbued(item_id, rune_id, rune_source)` — the frozen
    `event-bus.md` contract, where `rune_source` is one of the literal
    strings `"constellation"`, `"tarot"`, or `"menagerie"` (decision point
    from the design brief, resolved here).
15. **A rune is consumed on imbue — one-time use, never re-imbuable
    elsewhere.** Once spent into a specific `item_id`'s rune slot, that
    `rune_id` is permanently removed from `available_runes` and cannot be
    un-imbued, moved to a different item, or refunded by any means (no
    "un-imbue" action exists in this GDD). **Flagged design call**: matches
    the project's established "meaningful, costly choice" pattern (same
    register as Menagerie's sacrifice, Constellation's fixed shape
    commitments) — a discovered rune represents a specific, provable
    accomplishment, not a renewable resource to reallocate at will.
16. **New required Inventory interface**: `Inventory.apply_rune_to_item
    (item_id: String, rune_id: String, stat_delta: Dictionary) -> bool` —
    validates the target item still has a free rune slot (returns `false`,
    no mutation, if not — see Edge Cases), then mutates the existing item
    instance in place (`imbued_runes` array appended, one rune slot
    consumed), mirroring Crafting's `clear_damaged_flag` in-place-mutation
    precedent **[Upstream: crafting.md, inventory.md]** — does not remove or
    recreate the item, does not touch `item_added`/`item_removed`.
    **Explicit exemption to Inventory's Rule 5 equipped-item lock** —
    **[Upstream: inventory.md]** — flagged as a required amendment: Rule 5
    blocks *removal/discard* of a locked (equipped/installed) item, but rune
    imbuing is a metadata mutation, not a removal, and **must be permitted on
    a currently-equipped item** — imbuing the hero's currently-worn weapon is
    the common case this action exists for, not an edge case. If
    `apply_rune_to_item` were blocked by Rule 5's lock check, the player would
    be forced into an unequip → imbue → re-equip cycle for every rune, which
    this GDD explicitly rejects as worse UX with no compensating benefit.

**Creature Sacrifice Resolution (closes `menagerie.md`'s explicitly-flagged
open question)**

17. **Resolution decision**: `target_item_id` in `creature_sacrificed`
    **[Upstream: menagerie.md]** refers to a **NEW Equipment item Equipment
    Forge creates in the same operation that requests the sacrifice** — the
    recommended option from the design brief, chosen over the
    already-existing-item alternative because it keeps the sacrifice
    transaction fully self-contained (no dangling reference to an item the
    player must have separately prepared beforehand) and gives the sacrifice
    fantasy ("this creature becomes something") a concrete, freshly-created
    artifact.
18. **Sacrifice Recipe** (`SacrificeRecipeResource`) — analogous to
    `EquipmentRecipeResource` but consumes a `creature_id` instead of
    `inputs`: one recipe per species (5 total at Alpha, matching Menagerie's
    fixed 5-species roster **[Upstream: menagerie.md]**):

    | Field | Type | Description |
    |---|---|---|
    | `sacrifice_recipe_id` | StringName | Unique identifier |
    | `required_species` | StringName | Must match the target creature's species exactly |
    | `output_slot` | String | `weapon`/`offhand`/`helmet`/`chest`/`gloves`/`pants`/`boots`/`neck`/`ring` |
    | `output_base_item_id` | StringName | The item's base definition (before its pre-imbued rune) |
    | `quality_tier` | int | Derived, not authored (Formula 2) |
    | `rune_id` | StringName | Fixed per species — e.g. `"menagerie_aurora_stag"` |
    | `stat_delta` | Dictionary | Authored per species (Formula 3 guideline) |

19. **Full resolution flow**, in strict order:
    (a) Player selects a Sacrifice Recipe and a target `creature_id`; if the
    creature's species doesn't match `required_species`, the action is
    rejected at this UI-level pre-check (see Edge Cases) before any system
    call.
    (b) Equipment Forge validates `has_room_for(output_slot, 1)` — **checked
    before the creature is touched at all**, so a full Inventory can never
    cause a creature to be consumed with no home for the resulting item
    (mirrors Crafting's `tower_component` ordering, Rule 9 step (b), applied
    here even more strictly since the cost is a unique creature, not fungible
    materials).
    (c) Equipment Forge generates a prospective `item_id` for the not-yet-created
    item.
    (d) Equipment Forge calls the required new Menagerie interface,
    `Menagerie.request_sacrifice(creature_id: String, target_item_id: String)
    -> bool` **[Upstream: menagerie.md]** — a synchronous validation call
    Menagerie's own Rule 13 already anticipates but does not name a concrete
    signature for; this GDD originates the signature. Menagerie validates the
    creature is not currently in `BREEDING_PEN` (Menagerie's own Rule 13); on
    success, Menagerie removes/updates the creature's state internally and
    emits `creature_sacrificed(creature_id, target_item_id)` itself, using
    the `target_item_id` Equipment Forge passed in.
    (e) If step (d) returns `false`: abort — no item is created, no materials
    or creature are consumed, no further events fire (see Edge Cases).
    (f) If step (d) returns `true`: Equipment Forge constructs the new item
    (`output_base_item_id`'s stats, `rune_slot_count` slots per Rule 11 for
    its `output_slot`, with **one slot already consumed** by the pre-imbued
    rune below) and adds it via `item_added`; emits `hero_equipment_crafted
    (item_id = target_item_id, item_type = output_slot, quality_tier)`
    (Formula 2); then, in the same synchronous operation, emits
    `item_rune_imbued(item_id = target_item_id, rune_id, rune_source =
    "menagerie")` — the item arrives already-imbued with its
    species-specific rune, with any remaining rune slots (e.g. a sacrificed
    Tier-2 species producing a `weapon`-slot item: 2 total slots, 1 consumed
    at creation, 1 still free for a later Constellation/Tarot rune) open for
    further Rule 14 imbuing.
20. This ordering — validate room, then request sacrifice, then create —
    guarantees a creature is never lost without a corresponding item
    materializing, and that `creature_sacrificed`'s `target_item_id` always
    resolves to a real, successfully-created item by the time any subscriber
    (Mission HUD, Encyclopedia) processes the event.

### States and Transitions

Equipment Forge inherits mission-phase state directly from `game-concept.md`
(Sanctuary-only, `LOCKED` during SCOUT/WAVE_ACTIVE/INTERMISSION), identical
to Crafting's and Menagerie's own "inherits phase state, gates nothing
itself" pattern — no mission-phase table is repeated here.

What Equipment Forge *does* own are three independent, playthrough-scoped,
save-persisted ledgers:

**Equipment Recipe Discovery Ledger** (mirrors Crafting's Discovery Ledger
exactly):

| State | Entry Condition | Behavior | Exit Condition |
|---|---|---|---|
| `HIDDEN` (implicit) | Recipe not yet meeting both gates (Rule 7) | Not shown in Forge's Craft tab or Encyclopedia | Both tech gate and material gate true simultaneously → `DISCOVERED` |
| `DISCOVERED` | `recipe_discovered` fires (`recipe_category = "hero_equipment"`) | Permanently visible in Craft tab/Encyclopedia; craftability re-evaluated independently (Rule 8) | None — terminal, one-way |

**Available Rune Ledger** (Constellation/Tarot-sourced runes only — Rule 12;
Menagerie-sourced runes never enter this table, per Rule 13):

| State | Entry Condition | Behavior | Exit Condition |
|---|---|---|---|
| `UNAVAILABLE` (implicit) | `rune_id` not yet discovered by its owning system | Not present in `available_runes` | `constellation_rune_discovered` or `tarot_rune_discovered` fires for this `rune_id` → `AVAILABLE` |
| `AVAILABLE` | Discovery event fires | Present in `available_runes`, selectable as an Imbuing input (Rule 14) | Player imbues this `rune_id` into a target item (Rule 14) → `IMBUED` (terminal) |
| `IMBUED` (terminal) | `apply_rune_to_item` succeeds for this `rune_id` | Removed from `available_runes` permanently; the target item now carries it in its own `imbued_runes` array (Inventory-owned data, not Equipment Forge's) | None — terminal, one-way, no reversal (Rule 15) |

**Per-Item Rune Slot Occupancy** (per Equipment item instance, tracked by
Inventory as item metadata, not by Equipment Forge — listed here for
completeness since Equipment Forge's rules directly govern its transitions):

| State | Entry Condition | Exit Condition |
|---|---|---|
| `EMPTY` | Item created with `rune_slot_count` slots, none filled (equipment-crafted path) or `rune_slot_count − 1` slots (sacrifice path, one pre-filled) | Successful `apply_rune_to_item` call targeting this slot → `FILLED` |
| `FILLED` (terminal per-slot) | A rune is imbued into this specific slot | None — terminal, no un-imbue action exists (Rule 15) |

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Inventory** | Equipment Forge → Inventory (query/consume/produce) | `has_items(inputs) -> bool`, batch-consume on confirmed craft, produces output via `item_added`. `has_room_for(item_type, quantity) -> bool` and `apply_rune_to_item(item_id, rune_id, stat_delta) -> bool` (Rule 16) — both shipped in `inventory.md` 2026-07-17, found stale here 2026-08-27. |
| **Inventory** | Inventory → Equipment Forge | `item_added`/`item_removed` drive craftability re-checks (Rule 8) |
| **Hero System** | No direct interface | Hero reads equipment state passively via Inventory's `equipment_slot_changed` and directly subscribes to `item_rune_imbued` for stat recalculation — Equipment Forge never calls Hero (Rule 3) |
| **Crafting** | Crafting → Equipment Forge (schema/pattern only, no runtime call) | `RecipeResource` structure and Discovery/Craftability split reused as the template for `EquipmentRecipeResource` (Rule 4/7); `quality_tier` convention reused unchanged (Rule 5) |
| **Menagerie** | Bidirectional (Equipment Forge → Menagerie query/consume call; Menagerie → Equipment Forge via the resulting event) | Equipment Forge calls `Menagerie.request_sacrifice(creature_id, target_item_id) -> bool` (Rule 19d) — shipped in `menagerie.gd` 2026-07-17; Menagerie validates and is the sole emitter of `creature_sacrificed(creature_id, target_item_id)` |
| **Constellation** | Constellation → Equipment Forge | Subscribes to `constellation_rune_discovered(rune_id, pattern_id)` to populate `available_runes` (Rule 12) |
| **Tarot** | Tarot → Equipment Forge | Subscribes to `tarot_rune_discovered(rune_id, card_id)` to populate `available_runes` (Rule 12) |
| **Defense Building** | Defense Building → Equipment Forge | `tech_unlocked(tech_id, tech_category)` drives Equipment Recipe tech-gating (Rule 7), identical to Crafting's own dependency |
| **EventBus** | Equipment Forge → EventBus | Emits `hero_equipment_crafted` (frozen), `item_rune_imbued` (frozen), `recipe_discovered` (frozen, extended `recipe_category` value — Rule 7) |
| **EventBus** | EventBus → Equipment Forge | Subscribes to `tech_unlocked`, `item_added`, `item_removed`, `constellation_rune_discovered`, `tarot_rune_discovered` |
| **Encyclopedia** | Equipment Forge → Encyclopedia | Subscribes to `recipe_discovered` (`recipe_category = "hero_equipment"`) |
| **Mission HUD / Audio** | Equipment Forge → these | Subscribe to `hero_equipment_crafted`, `item_rune_imbued` |
| **Save & Persistence** | Equipment Forge implements `SaveRestorer` | `get_save_data()`/`restore_save_data()`/`reset_to_defaults()`, `restore_order = 32`, covering exactly the two ledgers named in Rule 10 (Equipment Recipe Discovery Ledger + Available Rune Ledger) — **not** item instance data, which Inventory owns |

## Formulas

### Formula 1 — Equipment Crafting Material Cost

Reuses Crafting's own registered `crafting_material_qty` formula
(`design/registry/entities.yaml`) **unchanged, not forked**, applied to
Equipment Recipes exactly as Crafting applies it to Tower Component recipes:

```
material_qty(rarity, T) = round(base_qty[rarity] × tier_dps_multiplier(T))
```

| Symbol | Type | Range | Description |
|---|---|---|---|
| `rarity` | enum | `{Common, Uncommon, Rare}` | Material rarity tier, same vocabulary Inventory/Crafting already established |
| `base_qty[rarity]` | int | Common=8, Uncommon=4, Rare=2 | Reused verbatim from Crafting's Formula 1 — not re-tuned separately for Equipment |
| `T` | int | 1–4 | The Equipment Recipe's `quality_tier` (Rule 5) |
| `tier_dps_multiplier(T)` | float | `{1.0, 1.6, 2.4, 4.0}` | Reused from `tower.md`, unchanged — the same "cost-per-power stays constant" rationale Crafting's own Formula 1 established applies identically here, even though the output is hero gear, not a tower component: it is still combat-relevant power, so the same combat-referent scaling curve is the correct one to reuse (unlike Defense Building's tech-cost formula, which deliberately did NOT reuse this constant because tech has no combat referent) |
| `material_qty` | int | 2–32 | Quantity of the given rarity required |

**Output range**: identical to Crafting's own table — Common 8–32, Uncommon
0/6/10/16, Rare 0/0/0/8, depending on `T`. Any future change to
`tower.md`'s `tier_dps_multiplier` automatically re-scales this formula's
output for both Crafting and Equipment Forge simultaneously — do not fork a
separate Equipment-Forge-only copy of this constant.

**Worked example**: a Tier 2 `weapon`-slot Equipment Recipe costs 13 Common
+ 6 Uncommon, 0 Rare — identical arithmetic to a Tier 2 Tower Component
recipe, since both consume the same registered formula.

---

### Formula 2 — Sacrifice Recipe Quality Tier

```
quality_tier(species_tier) = clamp(species_tier + 1, 1, 4)
```

| Symbol | Type | Range | Description |
|---|---|---|---|
| `species_tier` | int | 1–3 | The sacrificed creature's species rarity tier, per `menagerie.md` Core Rule 1 (Common=1, Uncommon=2, Rare=3) |
| `quality_tier` | int | 2–4 (never 1, by construction) | The resulting sacrifice-born item's `quality_tier`, carried in `hero_equipment_crafted`'s payload |

**Output range**: 2 (Tier 1 species) to 4 (Tier 3 species) — the clamp to
`[1,4]` is defensive only; with `species_tier` bounded at 1–3 by
`menagerie.md`, the floor branch is never actually reached. **Deliberate
design intent**: a sacrifice-born item is never Tier 1 — surrendering a
tended creature always produces at least a Tier 2 item, reflecting that this
is a costlier, more special source than a baseline material-only craft.

**Worked example**: sacrificing an `aurora_stag` (species_tier = 3, Rare)
produces a `quality_tier = clamp(3+1, 1, 4) = 4` item — the maximum tier,
matching the rarest, hardest-to-breed/lure species in the game.

---

### Formula 3 — Rune Stat Bonus Magnitude (guideline, not strict formula)

> **Update 2026-09-20:** rune magnitudes are now authored per rune (themed flat stats, two all-stats wildcards) — see `docs/superpowers/specs/2026-09-20-rune-variety-design.md`. The flat-rune path defined below is in use.

> **Update 2026-09-20:** equipment now has set bonuses (nine item-family sets earning cumulative stat bonuses) — see `docs/superpowers/specs/2026-09-20-equipment-set-bonuses-design.md`.

> **Update 2026-09-25:** each set now also has one capstone effect at its top threshold (five effect types) — see `docs/superpowers/specs/2026-09-25-equipment-set-effects-design.md`.

Deliberately **not derived from a clean expression** — hand-authored per
rune within a guideline range, same precedent as Crafting's own Formula 2
(Crafted Goods cost) and Defense Building's tech-cost table: not every
numeric system in this project needs a closed-form formula, and rune
magnitude is a content-authoring decision constrained by a range, not a
computed output.

| Bonus Type | Guideline Range | Description |
|---|---|---|
| `additive` (feeds Hero's `additive_bonus_total`, `hero.md` Formula 1) | 0.02–0.08 per rune (i.e. +2%–8%) | Deliberately modest per rune since up to 7 runes can be simultaneously imbued (Rule 11) across a full loadout; at the high end, 7 runes could contribute up to +0.56 toward Hero's `hero_additive_bonus_cap` of +3.00 (registry constant) alongside equipment affixes and class perks — leaves ample headroom, does not dominate the cap on its own |
| `flat` (feeds Hero's `flat_bonus` term, same Formula 1) | Hand-authored per targeted stat, guideline ~3%–10% of that stat's typical mid-game effective value | No universal scalar — a flat Health rune and a flat Crit Chance rune are not comparable in raw number, so this range is a per-stat authoring guideline, not a single constant |

**Output range**: bounded by the guideline table above; not formula-derived,
so no single worked "plug in numbers" example applies universally.
**Worked example (additive)**: a Constellation-sourced rune tied to a
frequently-formed shape might author `stat_delta = {stat_id: "damage",
bonus_type: "additive", value: 0.05}` — a flat +5% Damage contribution once
imbued, permanently, into whichever item slot the player chooses.
**Worked example (flat)**: a Tarot-sourced rune tied to a Master-tier
(Tier 4) card might author `stat_delta = {stat_id: "crit_chance",
bonus_type: "flat", value: 0.03}` (+3 percentage points flat Crit Chance) —
a modest but permanent contribution reflecting the significant mastery
investment (50 missions of accrual, per `tarot.md`'s Formula F6 thresholds)
that unlocked it.

**Deliberately decoupled from source-system internals**: these values are
authored entirely within Equipment Forge's own data, independent of
Constellation's `bonus_value` (Formula, `constellation.md`, applied to
towers) or Tarot's `mastery_tier_scalar` (applied to that card's own
modifiers). The same discovery event legitimately feeds two unrelated bonus
systems at two different magnitudes — see Dependencies → Upstream
Assumption Fragility for the consequence if this decoupling assumption ever
breaks.

## Edge Cases

- **If materials are insufficient for an Equipment Recipe at confirm-time**
  (stale UI): mirrors Crafting's identical edge case exactly — Rule 9 step
  (a) re-validates `has_items(inputs)`; if false, the craft is rejected with
  no consumption, no output, no event, beyond a UI "insufficient materials"
  state refresh.
- **If an Equipment Recipe's output has no free Inventory slot**: Rule 9
  step (b)'s `has_room_for()` pre-check runs before any material is
  consumed. If `false`, the craft is rejected in full — zero materials
  consumed, no event fires — identical rationale to Crafting's own
  `tower_component` edge case (a materials-spent-item-lost outcome is an
  unacceptable dead loss for a deliberate, player-initiated Sanctuary spend).
- **If a Rune Imbuing target item has no free rune slot**: `apply_rune_to_item`
  (Rule 16) returns `false` without mutating anything. The action is
  **rejected cleanly — the player is never forced to choose which existing
  rune to replace.** There is no "swap out an existing rune" mechanic in
  this GDD (matching the project's "no destructive default" pattern
  established elsewhere, e.g. Inventory's lock-check-always-gates-first drop
  rule). The rune remains `AVAILABLE` in `available_runes`, unconsumed, and
  the player must choose a different target item or free a slot on the
  intended one by imbuing a different item instead (there is no "un-imbue,"
  so "freeing a slot" in practice means choosing a different target item
  entirely).
- **If a rune's source discovery could theoretically be "undone"**: this is
  **structurally impossible, confirmed rather than assumed**. Both source
  Discovery Ledgers are explicitly one-way, terminal states in their owning
  GDDs: Constellation's Discovery Ledger (`constellation.md` States and
  Transitions: `DISCOVERED` is "Terminal — never reverts, even if all
  instances of the shape later break") and Tarot's Rune Discovery Ledger
  (`tarot.md` States and Transitions: `DISCOVERED` is "Terminal — never
  reverts"). A `rune_id` can therefore never leave `available_runes` by any
  means other than the player imbuing it (Rule 14) — no upstream event
  exists that could revoke a discovery already granted.
- **If an Equipment Recipe's `tech_prerequisite` is somehow "un-unlocked"
  after `tech_unlocked` has already fired**: explicitly out of scope,
  identical to Crafting's own equivalent edge case — no system in the
  project ever revokes a `tech_unlocked` state.
- **If a creature-sacrifice request targets a creature currently in
  `BREEDING_PEN`**: `Menagerie.request_sacrifice()` (Rule 19d) returns
  `false` per Menagerie's own Rule 13 validation. Equipment Forge aborts at
  that point — no item is created (the prospective `item_id` generated in
  step (c) is simply discarded), no materials consumed (none were ever
  spent — this path costs a creature, not materials), and the UI surfaces
  the same rejection state Menagerie's own sacrifice-eligibility check would
  (the creature must first be manually removed from the pen, cancelling its
  breeding timer per `menagerie.md`, before it becomes sacrifice-eligible).
- **If a creature-sacrifice request targets a creature whose species does
  not match the selected Sacrifice Recipe's `required_species`**: rejected
  at Equipment Forge's own UI-level pre-check (Rule 19a), before any call to
  Menagerie — this is a content-authoring/UI-disableable mismatch, not a
  runtime failure Menagerie needs to validate.
- **If loading a save references a `rune_id` that is no longer defined in
  current game data** (already imbued into an existing item, or still
  sitting `AVAILABLE` in the ledger): mirrors the established orphan pattern
  from `hero.md`'s `class_id` handling. **If already imbued**: the item's
  `imbued_runes` entry is retained (not discarded — supports future
  content re-addition), the slot is marked internally as occupied by an
  `UNKNOWN` rune, its stat contribution resolves to zero (Hero's stat
  recalculation must defensively treat an `UNKNOWN` rune as a no-op, not a
  crash), and a warning is logged. The rune slot does **not** become free
  again — a rune was historically spent there, and Rule 15's "never
  re-imbuable" guarantee must hold even across an orphaning event. **If
  still `AVAILABLE` (undiscovered-item, unimbued)**: the ledger entry is
  retained as `UNKNOWN`/unselectable in the Imbuing UI (greyed out, not
  deleted) rather than silently vanishing, so a future content patch that
  reintroduces the same `rune_id` can seamlessly reactivate it. The load is
  never blocked by either case.
- **If two Equipment Forge operations (craft, imbue, or sacrifice) are
  confirmed in the same frame**: guarded by a single `_forge_resolving: bool`
  flag, set at the start of any operation's first validation step and
  cleared only after its final event emission completes — identical
  mechanism to Crafting's `_craft_resolving` guard. A second confirmation
  received while `_forge_resolving == true` is rejected outright (no
  queueing), preventing any double-consume/double-produce race across the
  three distinct operation types this GDD defines (equipment crafting, rune
  imbuing, creature sacrifice) sharing one resolving-flag scope.
- **If a Rune Imbuing target item is currently equipped**: **explicitly
  permitted, not an edge case to defend against** — see Core Rule 16's
  exemption to Inventory's Rule 5 lock. This is called out here only to be
  unambiguous: unlike Crafting's repair mechanic (which never touches an
  equipped item because `damaged` items are, by construction, never
  simultaneously equipped), rune imbuing very often *does* target a
  currently-equipped item, and this must succeed normally.

## Dependencies

| System | Direction | Nature | Interface |
|---|---|---|---|
| **Inventory** | Depended on (hard) | `has_items()`, batch-consume, `item_added`/`item_removed` (existing); `has_room_for()` (shared need with `crafting.md`) and `apply_rune_to_item()` (this GDD's own requirement, Rule 16) — both shipped 2026-07-17, found stale here 2026-08-27 |
| **Hero System** | No direct dependency | Confirmed non-coupling (Rule 3) — Hero reaches Equipment Forge's output only via Inventory's `equipment_slot_changed` and its own `item_rune_imbued` subscription |
| **Crafting** | Schema/pattern dependency (soft) | `EquipmentRecipeResource` structurally extends `RecipeResource`; Discovery/Craftability split and `quality_tier` convention reused unchanged |
| **Menagerie** | Depended on (hard, bidirectional) | `Menagerie.request_sacrifice(creature_id, target_item_id) -> bool` interface (Rule 19d, originates the signature Menagerie's own Rule 13 anticipated but didn't name) — shipped 2026-07-17; consumes `creature_sacrificed` |
| **Constellation** | Depended on (hard, one-way) | Subscribes to `constellation_rune_discovered` |
| **Tarot** | Depended on (hard, one-way) | Subscribes to `tarot_rune_discovered` |
| **Defense Building** | Depended on (hard, upstream) | `tech_unlocked(tech_id, tech_category)` drives Equipment Recipe tech-gating |
| **EventBus** | Depended on (hard) | Emits `hero_equipment_crafted`, `item_rune_imbued`, `recipe_discovered` (all 3 frozen — `recipe_category` field confirmed present in `event-bus.md`'s catalogue, found stale here 2026-08-27) |
| **Encyclopedia** | Depends on Equipment Forge | Subscribes to `recipe_discovered` |
| **Mission HUD / Audio** | Depend on Equipment Forge | Subscribe to `hero_equipment_crafted`, `item_rune_imbued` |
| **Building Upgrade** (new, 2026-08-11) | Depended on (hard, downstream) | `building-upgrade.md`'s `"equipment"` requirement type checks whether a specific crafted `item_id` (Equipment Forge's own craft output) is currently owned, via `Inventory.has_specific_item()` (implemented 2026-08-11) — not a direct call into Equipment Forge itself, but this doc's crafted-item identifiers are the vocabulary that requirement type reads. Building Upgrade's own screen is also hosted as a tab inside Equipment Forge's UI (`building-upgrade.md`'s own Status line) — a second, structural (not just data) dependency in the same direction |
| **Save & Persistence** | Depended on (hard) | `restore_order = 32`, depends on Hero(30), Menagerie(20), Tarot(22) restoring first (see rationale below) |

**`restore_order = 32` dependency rationale** (the design brief asked this
be confirmed, not assumed): Equipment Forge's own restore work is
reconstructing its two ledgers (Rule 10) from scratch on load — this
requires each rune source's own Discovery Ledger to already be in its final
restored state, or Equipment Forge could rebuild `available_runes`
incompletely. Concretely: **Tarot (22)** must restore first so Equipment
Forge's rebuild correctly reflects every `tarot_rune_discovered` event that
has legitimately already fired across the playthrough (Tarot's own Rune
Discovery Ledger is the source of truth for which `rune_id`s exist at all).
**Hero (30)** must restore first so that any item already carrying imbued
runes in a hero equipment slot can be cross-validated against Hero's
restored 10-slot loadout without a race (an item's `imbued_runes` field is
Inventory-owned data, but Hero's own restore establishes which slots exist
to validate against). **Menagerie (20)** must restore first primarily for
consistency with the same dependency-layer discipline Save & Persistence
already applies elsewhere (Feature-layer systems before Advanced-layer
systems) — no sacrifice-in-progress state persists across saves per
`menagerie.md`'s own edge cases, so this is a structural/layering dependency
rather than a data-race one.

### Upstream Assumption Fragility

*(Per `systems-index.md`'s own explicit requirement for this GDD: every
assumption borrowed from the seven upstream GDDs that, if that document
changes during its own `/design-review` pass, would require revisiting this
document.)*

| # | Upstream Document | Assumption Borrowed/Originated Here | Consequence If It Changes |
|---|---|---|---|
| 1 | `hero.md` | Hero has no fixed equipment slot count of its own; this GDD originates 10 slots (`helmet`/`chest`/`gloves`/`pants`/`boots`/`main_hand`/`neck`/`ring_1`/`ring_2`/`offhand`), Core Rule 1. | If `hero.md` is revised to define its own slot count/names, this GDD's Core Rule 1, every recipe's `output_slot` values, the rune-slot-count table (Rule 11), and Inventory's Rule 5a floor check must all be re-verified against the new authoritative number — a name/count mismatch would silently break `equipment_slot_changed` routing. |
| 2 | `hero.md` | Hero's `additive_bonus_total` cap is `hero_additive_bonus_cap = +3.00` (registry constant); rune `additive` magnitude (Formula 3) is guided by this ceiling remaining stable and by other bonus sources (equipment affixes, class perks) not already consuming most of the headroom. | If this cap changes (or if Hero's own affix/perk bonus budget is later found to already consume most of the +3.00 headroom), Formula 3's 0.02–0.08 per-rune guideline must be re-derived — the current range assumes 16 simultaneous runes have ample room alongside other sources. |
| 3 | `hero.md` | Non-direct-coupling: Equipment Forge never calls Hero; Hero reaches this system's output only via Inventory's `equipment_slot_changed` and its own `item_rune_imbued` subscription (Core Rule 3). | If `hero.md` changes how it ingests `item_rune_imbued` (different payload shape, batched delivery, or removal of the direct subscription in favor of a different mechanism), this GDD's rune-imbuing stat-application flow breaks silently — Hero would stop reacting to a correctly-emitted event. |
| 4 | `crafting.md` | `EquipmentRecipeResource` structurally extends Crafting's `RecipeResource` (fixed, never-rolled output; two-gate discovery via `recipe_discovered`; `quality_tier` 1–4 convention; instant-on-confirm resolution) — reused, not reinvented (Core Rules 4, 5, 7, 9). | If Crafting's own Discovery/Craftability mechanism (its Rules 3/4) or its `quality_tier` definition (its Rule 5) changes, Equipment Forge's equipment recipes silently diverge from the shared Crafting-panel UX and tier semantics unless this GDD is revisited and mirrored in lockstep. |
| 5 | `crafting.md` | Formula 1 reuses `tower.md`'s `tier_dps_multiplier` (via Crafting's own registered `crafting_material_qty` formula) unchanged, rather than forking a separate Equipment-Forge-only copy. | If `tower.md`'s `tier_dps_multiplier` values change, both Crafting's and Equipment Forge's material costs rescale automatically (intended) — but if Crafting instead forks its own copy in a future revision, Equipment Forge's Formula 1 would need to explicitly choose which copy to follow, since this GDD assumed a single shared constant. |
| 6 | `menagerie.md` | `target_item_id` in `creature_sacrificed` is resolved here as a NEW Equipment item Equipment Forge creates in the same operation (Core Rule 17) — this GDD's own answer to Menagerie's explicitly-flagged open question. New `Menagerie.request_sacrifice(creature_id, target_item_id) -> bool` interface signature is originated here (Rule 19d), not in `menagerie.md` itself. | If `menagerie.md`'s Rule 13 changes sacrifice eligibility validation (e.g., adds an age-gate, changes which states are sacrifice-eligible, or changes the interface signature/return contract), Equipment Forge's pre-check ordering (room-check before `request_sacrifice`) still structurally holds, but the exact rejection conditions surfaced to the player and the interface call itself must be re-synced against the new contract. |
| 7 | `menagerie.md` | The 5-species roster (Common: `glimmer_hare`/`mossback_toad`; Uncommon: `emberwing_moth`/`duskfang_fox`; Rare: `aurora_stag`) is the exhaustive key set for this GDD's Sacrifice Recipe table (Core Rule 18) — one recipe per species. | If species are added, removed, or renamed in `menagerie.md`, the Sacrifice Recipe catalogue must be revised in lockstep — an un-updated catalogue would leave a species with no corresponding sacrifice path, or reference a `required_species` that no longer exists. |
| 8 | `constellation.md` | `constellation_rune_discovered(rune_id, pattern_id)` populates `available_runes` directly with no additional gating; the rune's Equipment-Forge-side `stat_delta` (Formula 3) is authored independently, deliberately decoupled from Constellation's own `bonus_value`/`pattern_id` mechanics (Core Rule 12). | If `constellation.md` is ever revised so that `rune_id` itself carries or implies a specific numeric bonus value (rather than being a pure identity/discovery key), this GDD's decoupled-authoring assumption breaks — rune magnitude might need to be derived from Constellation's own data instead of hand-authored here, requiring a Formula 3 rewrite. |
| 9 | `constellation.md` | Constellation's Discovery Ledger has `restore_order = 24`, assigned in `save-persistence.md` 2026-07-17 (found stale here 2026-08-27 — `constellation.md`'s own OQ-1 had been resolved the same day but not marked). | Equipment Forge's `available_runes` restore (`restore_order = 32`) depends on Constellation's discovered-rune set restoring first — confirmed compatible, since 24 < 32. This is now verifiable end-to-end, not a blocking gap. |
| 10 | `tarot.md` | Same decoupled-authoring pattern as Constellation: `tarot_rune_discovered(rune_id, card_id)` populates `available_runes`; Equipment Forge's `stat_delta` is independent of Tarot's own Formula F5 additive bonus applied internally to `modifier_type` — the same discovery event legitimately feeds two separate, non-conflicting bonus systems (Core Rule 12). | If `tarot.md`'s Rule 15 discovery condition is tightened (its own flagged "most swappable assumption" — currently "any mission attempt while equipped," MISSION_COMPLETE or DEFEAT), Equipment Forge's rune-availability timing shifts identically since it listens to the same event — no separate assumption breaks here, but the two documents' discovery-timing narratives should be kept in sync in any future rewrite. |
| 11 | `inventory.md` | New required interface `Inventory.apply_rune_to_item(item_id, rune_id, stat_delta) -> bool` (Rule 16), and an **explicit exemption to Inventory's Rule 5 equipped-item lock** for this specific mutation (rune imbuing must work on a currently-equipped item). | If `inventory.md`'s Rule 5 is ever tightened to block ALL writes (not just removal/discard) on locked items, this GDD's entire rune-imbuing flow breaks and would require forcing an unequip → imbue → re-equip cycle — a materially worse UX this GDD explicitly designed against. This is the single highest-risk fragility entry in this table, since it requires an upstream document to carve out an exception for a downstream system's needs, not merely stay stable. |
| 12 | `inventory.md` | Equipment Forge's fixed 10 Hero equipment slots (entry #1 above) are the concrete number Inventory's own Rule 5a ("≥4 free discretionary slots" floor) was explicitly waiting on. | Inventory's own Tuning Knob table (`starting_slot_count` safe range) must be revisited once Tower System's per-tower-component install-lock count is *also* fixed (still undefined as of this authoring pass) — this GDD only closes half of Rule 5a's dependency, not all of it. |
| 13 | `save-persistence.md` | Equipment Forge's own registered save payload is narrower than `save-persistence.md`'s Line 81 summary ("All crafted equipment in the hero's forge inventory") — actual item data lives in Inventory; Equipment Forge persists only its two ledgers (Core Rule 10). | If an implementer follows `save-persistence.md`'s literal payload description without cross-referencing this GDD, Equipment Forge's save/restore code could end up duplicating item state Inventory already owns, risking desync between two copies of the same data on load. `save-persistence.md` should be corrected to match this GDD at its next revision pass; until then, this GDD's version is authoritative. |

## Tuning Knobs

| Knob | Default | Safe Range | Too High | Too Low |
|---|---|---|---|---|
| `hero_equipment_slot_count` (Core Rule 1) | 10 | 8–12 | Dilutes the meaningfulness of any single gear choice; also risks violating Inventory's Rule 5a ≥4-free-slot floor at higher starting-tier counts once combined with Tower's (still undefined) install-lock count | Removes build-expression headroom; fewer simultaneous affix/rune combinations reduces the "wearable timeline" Player Fantasy this system is built around |
| `rune_slot_count` — weapon/armor pieces (Core Rule 11) | 2 | 1–3 | Every weapon/armor piece becomes a near-universal rune sink, reducing "which item gets this rune" to a non-decision | A single slot on the highest-value gear categories makes multi-rune builds nearly impossible, undercutting the "converges everything" fantasy |
| `rune_slot_count` — offhand/neck/ring (Core Rule 11) | 1 | 1–2 | Raising these toward parity with weapon/armor flattens the deliberate slot-count hierarchy (weapon/armor as the "premium" rune destinations) | Already at the practical floor — 0 would remove these categories from the rune system entirely, contradicting their inclusion as valid Imbuing targets |
| `additive` rune magnitude (Formula 3) | 0.02–0.08 per rune | 0.01–0.12 | At the high end with 7 simultaneous runes, could meaningfully erode headroom under Hero's `hero_additive_bonus_cap` (+3.00), crowding out equipment-affix and class-perk contributions | Rune-imbuing stops feeling like a meaningful reward relative to the effort (a full playthrough of proximity/mastery/tending) required to earn the source discovery |
| Sacrifice quality tier offset (Formula 2, the `+1` term) | +1 (clamped to [1,4]) | 0–2 | A larger offset (e.g. +2) would make every sacrifice-born item Tier 4 regardless of species, removing the tier spread that currently rewards sacrificing rarer species | An offset of 0 would let a Tier-1-species sacrifice produce a Tier-1 item — indistinguishable in tier from an ordinary material-crafted item, undermining "a sacrifice is always at least a little special" |
| Equipment Recipe catalogue size (Core Rule 6) | 6–10 recipes at Alpha | 4–15 | A large catalogue this early risks the same combinatorial-authoring burden Crafting explicitly scoped away from at Alpha | Fewer than 9 recipes leaves at least one of the 9 equip-slot categories with no craftable path at all, an obvious content gap |
| `_forge_resolving` guard window | Single-frame (structural, not tunable) | Fixed — do not tune | N/A | N/A — this is a race-condition guard, not a balance lever, identical in nature to Crafting's `_craft_resolving` |
| Equipment Recipe material cost (Formula 1) | Inherits Crafting's `crafting_material_qty` knobs unchanged | See `crafting.md`'s own Tuning Knobs table (`base_common_qty`/`base_uncommon_qty`/`base_rare_qty`) | Same consequences as documented there — this GDD introduces no separate copy to tune | Same consequences as documented there |

## Visual/Audio Requirements

**Forge screen — core visual language (diegetic diorama, the most literal expression yet of the "wizard's cabinet" anchor)**

Unlike Crafting's own UI-panel-adjacent recipe list (a flat two-panel screen borrowing Inventory's grid language) or Tarot's card-table panel, Equipment Forge is the single most literal fit for the art bible's founding anchor (`design/art/art-bible.md` Sec 1) among all Sanctuary systems to date — a forge is exactly the kind of hand-carved diorama object the anchor describes. The screen should read as looking *into* a physical forge/workbench scene, not *at* a UI panel:

- The screen renders as a bounded diorama scene (same oblique camera angle convention used by Menagerie's habitat and the main Sanctuary view) — a stone forge, anvil, workbench surface, and a tool/rune rack — lit with the same warm key / cool fill raking-light convention (art bible Sec 2.2) used throughout the Sanctuary's interior scenes.
- The equipment being crafted or imbued is a physical object placed on the anvil/workbench surface within this diorama, not a flat icon floating in a panel. It renders with the standard stacked-sprite cast shadow (reused from Menagerie/hero treatment) so it visually belongs to the same physical space as the anvil, not to panel-chrome space.
- The equipment-crafting recipe list and the rune-imbuing interface (equipment selector + rune inventory) render as UI chrome at the screen's edges, consistent with Crafting/Inventory's established panel language — but the forge itself is the centerpiece, not the panels. This is the deliberate inversion of Crafting's own composition (a panel *with* an icon) into a diorama *with* panels at its edges — the correct emphasis for the most "physical object" system among the abstract-UI Sanctuary screens.
- Persistent idle ambiance (low ember glow in the hearth, tool silhouettes on the workbench wall, a subtle heat-shimmer) runs continuously, sprite/particle-driven only (no bloom dependency, per the Godot 4.6 constraint flagged in every prior GDD) — the same differentiator Menagerie's idle-creature animation provides against Inventory/Crafting's static icon grid, applied here to a living workspace instead of living creatures.

**Rune iconography echoing each source system**

Each rune renders with a frame/material treatment that echoes its origin system's own established visual identity, so source is legible before reading a tooltip. This is a fourth entry in the project's shape-first grammar alongside Crafting's rarity frames (circle/hexagon/diamond) — but keyed to *source*, not rarity, since the two are orthogonal data on the same object:

| Source | Frame silhouette | Material/color echo | Reused from |
|---|---|---|---|
| Constellation | Faceted stone-tablet fragment | Warm Sanctum Amber inlay, sprite/particle-lit (never bloom) | `constellation.md`'s carved rune-plate activation treatment |
| Tarot | Miniature card standing in a small carved stand | Painted-cardstock texture, drop-shadow toward the Sanctuary's raking light | `tarot.md`'s tactile card-object treatment |
| Menagerie | Small preserved/mounted memento medallion, rounded silhouette | Deliberately desaturated/muted at rest — the one rune type whose default palette is somber rather than vivid | `menagerie.md`'s sacrifice loss-beat register |

- All three frame silhouettes (tablet / card-stand / rounded medallion) are distinguishable in monochrome by shape alone, per Sec 4.5 colorblind discipline — color is confirmatory, never the sole source cue.
- If runes carry independent rarity, it layers on top via Crafting's existing circle/hexagon/diamond border convention applied over whichever source-silhouette is present — reusing rather than reinventing the shape-first rarity vocabulary, per `tarot.md`'s own note directing future systems to do the same.

**Equipment-crafting half — reused Crafting conventions (state explicitly, not reinvented)**

- Recipe-list three-state coding (tech-locked grey+lock / material-insufficient orange+badge / ready-to-craft full-color+filled-confirm) — identical, unchanged.
- Unlock-cascade Herald Gold treatment and category pip badge — identical, unchanged.
- Craft-confirm consume-flash (inward collapse of cost icons) — identical animation shape, but its destination anchor is now the physical item resting on the anvil diorama rather than a flat panel icon.
- Rarity-tier shape/border coding (circle/hexagon/diamond, Common/Uncommon/Rare) — identical, applied to equipment the same way Crafting applies it to materials.
- Material-consumption drain feedback (number-tick-down + Fieldstone Grey fade pulse on the left-panel Inventory grid) — identical.

**The rune-imbuing moment (the system's peak "big moment" beat)**

This is where three systems' worth of earned history converges into one wearable object — heavier than Crafting's routine consume-flash, but a *creation* beat, not a loss beat, so it must not be visually confused with Menagerie's own somber sacrifice treatment even though it too permanently consumes a resource. Proposed sequence (~1.5–2.5s, non-blocking but held, comparable weight class to Constellation's and Tarot's rune-discovery reveals):

1. The target equipment item is already resting on the anvil (from the assignment interaction, see UI Requirements). The selected rune lifts from the rune-inventory panel and travels in a short physical arc onto the item — "the rune is being given up," not a panel-to-panel teleport/pop.
2. On contact, the rune's source-specific frame (tablet / card-stand / medallion) breaks open and its essence is drawn into the item as a brief, restrained particle wisp in the rune's own source-echoing color — sprite/particle-driven only, never bloom-dependent.
3. The item flashes with a single unified "imbued" mark language — a physical carved/etched accent, rendered in Sanctum Amber (the established craft-payoff amber, consistent with Constellation's and Crafting's existing amber-as-mastery-payoff precedent) — that persists afterward as a permanent part of the item's appearance, so an imbued item is visibly distinguishable from an un-imbued one from that point forward, not just at the moment of imbuing.
4. The rune's own source-echo color is deliberately *consumed*, not adopted by the item — the item's permanent mark is always Sanctum-Amber-toned regardless of which of the three sources fed it. This keeps a fully-imbued item's field readability to one hue rather than requiring the viewer to recall three different rune-source palettes on every piece of equipped gear.
5. If an item can hold multiple runes, the mark language scales by *adding* discrete facet/etch elements, never by escalating a single mark's brightness/intensity — item power stays legible by counting marks at a glance, and this stays consistent with color-vision-independent legibility (see Accessibility notes below).

**Creature-sacrifice-into-item bridging**

Mirrors how Crafting's craft-confirm and Inventory's item-pop already coexist without either canceling the other's meaning, applied to the Menagerie → Equipment Forge boundary specifically:

- Menagerie's sacrifice beat (creature desaturate-and-fade, no particle burst, somber) plays entirely within Menagerie's own screen, exactly as specified in `menagerie.md` — Equipment Forge does not shorten, modify, or reinterpret it.
- The resulting Menagerie-sourced rune's arrival in Equipment Forge's rune-inventory pool uses Forge's own standard rune-acquired pop (a restrained variant of Inventory's pickup-pop, scaled to a rune object) — this pop is deliberately upbeat/neutral, identical in register to a Constellation- or Tarot-sourced rune's arrival, *not* a somber echo of the sacrifice that produced it.
- The only carryover of the loss register into Forge is the Menagerie-sourced rune's permanent muted rest-state appearance (per the iconography table above) — the pop says "you gained something," the object's ongoing look says "and it cost something," and both remain simultaneously true without either canceling the other, matching Menagerie's own stated "tonal contrast, not cancellation" principle.
- If Forge is open at the moment of a Menagerie sacrifice (cross-screen timing), the arrival pop fires as a background event in the rune-inventory panel only — it must never interrupt or compete with whatever the player is actively doing in Forge, matching Crafting's "sum the count, don't stack the VFX" simultaneous-trigger discipline.

**Audio direction (category only, no audio bible yet)**

- Forge ambiance: continuous low ember-crackle/workbench ambient bed while the screen is open — establishes the diorama as a physical, lived-in space, distinct from Inventory/Crafting's comparatively sterile UI audio, matching Menagerie's ambient-habitat-bed precedent.
- Equipment-craft confirm: reuses Crafting's existing "assembly" sound category directly (not a new asset family) — this half of Forge is structurally the same action as Crafting's.
- Rune assignment (rune lifts toward item, pre-imbue): a soft anticipatory tone with three subtly distinct voicings by source family (bell-adjacent for Constellation, paper/card-foley-adjacent for Tarot, breath/organic-adjacent for Menagerie) — reinforces the visual source-echo goal in audio as well.
- Rune-imbuing resolution (the big moment): a fuller layered sting comparable in production weight to Constellation's and Tarot's discovery stings and Crafting's unlock-cascade chime, but built from a distinct forging/fusion signature (metal-strike plus resonant settle) — this is the game's convergence moment and should have its own identifiable sonic signature, not borrow any of the three source systems' stings.
- Menagerie-sourced rune arrival pop: uses the same Forge-standard rune-acquired pop as any other source — explicitly *not* a variant of Menagerie's own sacrifice stinger, preserving the tonal-contrast principle above.

## UI Requirements

**Forge screen layout**

- **Center**: the forge diorama with anvil/workbench — the "stage" where the equipment currently being crafted or imbued sits, per Visual/Audio Requirements above.
- **One side panel**: the equipment-crafting recipe list, reusing Crafting's own recipe-list panel wholesale (states, default sort, filtering) — Forge does not reinvent this panel.
- **Other side panel** (behind a mode toggle within the same column, see below): the rune-imbuing interface — the player's owned-equipment selector plus the rune inventory/pool.
- A persistent two-tab toggle (**Craft** / **Imbue**) sits at the top of the side-panel column, rather than merging both into one panel or one adjacency space. This is a deliberate, scoped exception to the "whole screen as one adjacency space" precedent Crafting/Menagerie otherwise establish: Craft (recipe + materials) and Imbue (item + slot + rune) are two different tools at the same workbench with genuinely different data shapes, not two views over one shared list the way Inventory/Crafting's grids are.
- The centerpiece diorama's displayed object follows the active tab: Craft shows the in-progress crafted item (or an empty anvil); Imbue shows the currently-selected equipment item awaiting a rune.

**Rune-to-item assignment interaction (three-way selection)**

A sequential select-then-confirm flow, extending Crafting's single-select and Menagerie's multi-select-then-confirm patterns to a third selection axis:

1. Select the equipment item (from the player's owned-equipment list/rack within the Imbue tab) — the item appears on the anvil.
2. Select a rune slot on that item, if it has more than one — the slot highlights directly on the item's diorama sprite (a marked facet/socket), not just in a text list, keeping the physical-object framing consistent.
3. Select a rune from the rune-inventory/pool panel (filterable by source tag, see below) — the candidate rune previews in a staging position beside the item, not yet committed.
4. A single confirm advances to the imbuing commitment step (two-step confirmation, below).

- Each stage uses the same highlight-vs-selection distinction Menagerie's breeding-pen assignment already established (focus = "currently looked at," selection = "currently queued") — reused directly rather than inventing a fourth selection-state vocabulary.
- Canceling any in-progress stage before final confirm is a single dedicated back/cancel action, matching Menagerie's own precedent (never requires re-selecting from scratch).
- An incompatible rune/slot pairing (if Detailed Design defines slot restrictions) renders the rune preview in Crafting's tech-locked grey treatment with a lock-icon overlay, rather than hiding or disabling it silently — consistent with the project's established "always show why, don't just hide" convention for locked recipes and locked cards.

**Confirmation convention for rune-imbuing**

Plain equipment-crafting stays single-confirm, identical justification to `crafting.md` (routine, frequent, reversible-by-repetition via fungible materials). Rune-imbuing specifically requires Menagerie-sacrifice-style two-step confirmation:

- The rune consumed is non-fungible and unique — it cannot be re-acquired identically and cannot later be un-imbued. This fails Crafting's single-confirm test for the exact structural reason Menagerie's sacrifice does: a specific earned resource ceases to exist, rather than a fungible quantity decrementing. The project's established dividing line (Crafting's routine/reversible vs. Menagerie's permanent/unique) places rune-imbuing unambiguously on the Menagerie side.
- Interaction shape, directly mirroring Menagerie's sacrifice dialog: after the three-way selection above, confirm opens a modal stating (i) which rune will be permanently consumed, (ii) which item/slot receives it, and (iii) that this cannot be reversed or reassigned — a second explicit confirm or cancel resolves the dialog.
- Because the rune at stake may be from any of three source systems the player has invested real effort in, the modal renders the rune's own source-echoing icon/frame (per Visual/Audio Requirements) inside the dialog itself, not just its name — the confirmation must be visually, not only textually, unambiguous about which specific rune is being spent.

**Rune inventory / browsing**

- A dedicated rune-inventory list/pool panel (within the Imbue tab), tagged by source (Constellation / Tarot / Menagerie) via each rune's source-frame iconography — filterable by source tag, reusing Crafting/Inventory's existing tab/category-filter chrome rather than inventing new filter UI.
- Default sort: grouped by source tag, then by rarity tier within each group (reusing Crafting's shape-first rarity ordering) — surfaces "what do I have from each system" at a glance and reinforces the cross-system convergence framing that defines this system.
- Once imbued (consumed), a rune is removed from the browsable pool entirely — no "used" ghost state, since it no longer exists as a discrete resource; the receiving item's permanent imbue-mark is the only remaining record of that fusion.
- Newly-arrived runes (from any of the three sources) get the same Herald-Gold-adjacent "new item" border pulse Inventory uses for newly acquired stock, so returning to Forge after other play surfaces what's new since the last visit.

**Gamepad navigation model**

- Shoulder buttons (LB/RB) switch between the Craft/Imbue tabs, matching the project's established shoulder-button tab-cycle convention.
- Within the Imbue tab, D-pad/left-stick moves through the three selection stages (equipment list → item's rune slots → rune pool) as one continuous adjacency space, per Crafting's "whole screen as one adjacency space" precedent within a tab — moving into the item's own diorama-rendered slots is a directional press from the equipment-list edge, the same pattern Crafting uses moving from its recipe list into the Inventory grid.
- Single confirm advances the current selection stage, or, on the final stage, opens the two-step confirmation modal; a dedicated cancel/back button steps back one stage at a time (never discards the whole in-progress assignment on one press).
- Focus rendering: the same non-color outline + slight scale convention as Crafting/Menagerie, applied identically across all three selection stages and to the modal's own confirm/cancel buttons.
- Keyboard-only mirrors the same adjacency model (arrow keys / Tab–Shift+Tab, Enter to confirm, Esc to back out one stage), matching established keyboard parity elsewhere.

**Accessibility notes**

- All three rune-source frame silhouettes (tablet / card-stand / rounded medallion) are distinguishable in monochrome by shape alone, per Sec 4.5 — color is confirmatory only, never the sole source cue.
- The permanent item imbue-mark is a structural, additive mark (discrete facets/etchings, not a pure intensity/glow ramp), so mark count remains legible under any color-vision deficiency.
- The rune-imbuing confirmation modal's stated consequence text exists as real text (screen-reader/text-log compatible where tooling supports it), not baked into art, matching Menagerie's sacrifice-dialog precedent.
- Incompatible rune/slot pairings use the same grey+lock-icon non-color treatment as Crafting's tech-locked state — never hidden, never color-only.
- Selection-vs-focus states across all three assignment stages use distinct, high-contrast outline treatments, matching Inventory/Crafting/Menagerie's established focus-highlight standard.

## Acceptance Criteria

> **Reading note**: per this GDD's own Reading Order note and Dependencies →
> Upstream Assumption Fragility table, several ACs below are marked
> *(unblocked — dependency shipped 2026-07-17, found stale 2026-08-27)*, mirroring the established
> pattern used in `crafting.md` (`has_room_for`/`clear_damaged_flag`),
> `tower-mastery.md` (`get_component_loadout`), `mission-select.md`
> (`retry_current_mission`), and `hero-skill-build.md` (`skill_modifier`
> item_type). These ACs are correctly specified but not automatable until the
> named interface exists — see Open Questions for the tracked follow-up.

**Group 1: Hero Equipment Slots (Rules 1–3)**

- **AC-1**: **GIVEN** a fresh save with no prior slot configuration, **WHEN**
  the Hero System and Inventory initialize, **THEN** exactly 10 named
  equipment slots exist (`helmet`, `chest`, `gloves`, `pants`, `boots`,
  `main_hand`, `neck`, `ring_1`, `ring_2`, `offhand`), and at `inventory_
  starting_slot_count = 18`, exactly 8 discretionary slots remain free —
  clearing Inventory Rule 5a's ≥4-free floor with real headroom
  (Rule 1).
- **AC-2**: **GIVEN** an Equipment item whose category is `ring`,
  **WHEN** an equip action targets either `ring_1` or `ring_2`,
  **THEN** the action succeeds for both — no ring-subtype restriction
  exists at Alpha (Rule 2). **GIVEN** the same item, **WHEN** an equip action
  targets any other slot, **THEN** it is rejected as a
  category mismatch (Inventory-owned validation, not re-specified here).
- **AC-3** — **Integration/architecture check, not a unit test.** **GIVEN**
  the full call graph of Equipment Forge's rune-imbuing and crafting
  resolution paths, **WHEN** those paths are traced, **THEN** no direct
  function call from Equipment Forge into the Hero System exists anywhere —
  Hero's only two data paths in are subscribing to Inventory's
  `equipment_slot_changed` and its own `item_rune_imbued` subscription (Rule
  3). Evidence: a documented code-path review (Integration story gate), not
  an automated unit test, since this is an absence-of-coupling claim.

**Group 2: Equipment Recipe Model & Discovery (Rules 4–8)**

- **AC-4**: **GIVEN** an authored `EquipmentRecipeResource`, **WHEN** its
  fields are inspected, **THEN** all seven fields (`recipe_id`,
  `recipe_category = "hero_equipment"`, `output_slot`, `inputs`,
  `tech_prerequisite`, `output_item_id`, `quality_tier`, `rune_slot_count`)
  are present and typed as specified (Rule 4).
- **AC-5**: **GIVEN** any authored Equipment Recipe, **WHEN**
  `quality_tier` is read, **THEN** it is a fixed author-set integer in
  `1`–`4` — never rolled, never computed at craft time (Rule 5).
- **AC-6**: **GIVEN** an Equipment Recipe whose tech gate and material gate
  both become true in the same frame, **WHEN** that frame resolves, **THEN**
  `recipe_discovered(recipe_category = "hero_equipment")` fires exactly
  once, and the recipe transitions `HIDDEN → DISCOVERED` permanently — a
  subsequent loss of the material gate (e.g., materials later spent
  elsewhere) does not revert the state (Rule 7, States and Transitions).
- **AC-7**: **GIVEN** a `DISCOVERED` Equipment Recipe whose inputs are
  currently insufficient, **WHEN** `item_added` fires for a material that
  completes the input requirement, **THEN** the recipe's craftability flag
  flips to true on that event alone, independent of the (already-fired,
  one-time) `recipe_discovered` event (Rule 8).

**Group 3: Equipment Crafting Resolution (Rule 9) + Formula 1**

- **AC-8**: **GIVEN** a craftable Equipment Recipe whose required materials
  are spent by another action between UI render and confirm (stale UI),
  **WHEN** confirm is pressed, **THEN** step (a)'s `has_items(inputs)`
  re-validation returns false, the craft is rejected, zero materials are
  consumed, and no event fires beyond a UI refresh (Rule 9 step (a), Edge
  Cases).
- **AC-9** *(unblocked — dependency shipped 2026-07-17, found stale 2026-08-27)* — **GIVEN** a
  craftable Equipment Recipe whose output slot has no free Inventory room,
  **WHEN** confirm is pressed, **THEN** step (b)'s `has_room_for(output_slot,
  1)` pre-check returns false, the craft is rejected in full before step (c)
  ever runs, and zero materials are consumed (Rule 9 step (b), Edge Cases).
  **Interface dependency, RESOLVED 2026-07-17, found stale here 2026-08-27**: `Inventory.has_room_for()`
  shipped in `inventory.md` — same shared interface `crafting.md`'s own
  AC-4 also depends on. Now automatable.
- **AC-10**: **GIVEN** a craftable Equipment Recipe with sufficient
  materials and Inventory room, **WHEN** confirm is pressed, **THEN** steps
  (a)–(e) execute synchronously within the same frame: materials are
  batch-consumed, a new Equipment item is added with `rune_slot_count` free
  rune slots (per Rule 11's table for that `output_slot`), all currently
  `EMPTY`, and `hero_equipment_crafted(item_id, item_type = output_slot,
  quality_tier)` fires exactly once with the recipe's authored values (Rule
  9).
- **AC-11**: **GIVEN** a Tier-2 `weapon`-slot Equipment Recipe, **WHEN**
  Formula 1 is evaluated, **THEN** the material cost is exactly 13 Common +
  6 Uncommon + 0 Rare — matching the worked example and identical to a
  Tier-2 Tower Component recipe's cost, since both consume the same
  registered `crafting_material_qty` formula unchanged (Formula 1).

**Group 4: Save Payload Ownership (Rule 10)**

- **AC-12**: **GIVEN** a live playthrough with discovered recipes,
  available runes, and at least one crafted Equipment item, **WHEN**
  Equipment Forge's `get_save_data()` is inspected, **THEN** its payload
  contains exactly two entries — the Equipment Recipe Discovery Ledger and
  the Available Rune Ledger — and contains **no** item-instance data
  (`imbued_runes`, slot occupancy, etc.), confirming that data is Inventory's
  responsibility, not Equipment Forge's, per Rule 10's clarification of the
  narrower-than-`save-persistence.md`-Line-81 payload scope.

**Group 5: Rune Slot Model & Ledger (Rules 11–13)**

- **AC-13**: **GIVEN** a freshly-crafted item for each `output_slot` value,
  **WHEN** `rune_slot_count` is read, **THEN** it matches Rule 11's table
  exactly: `weapon` = 2, `offhand` = 1, `helmet`/`chest`/`gloves`/`pants`/
  `boots` = 2, `neck` = 1, `ring_1`/`ring_2` = 1.
- **AC-14**: **GIVEN** `constellation_rune_discovered(rune_id, pattern_id)`
  fires for a `rune_id` not previously in `available_runes`, **WHEN** the
  event is processed, **THEN** the rune enters `available_runes` in state
  `AVAILABLE` with `rune_source = "constellation"` and an
  Equipment-Forge-authored `stat_delta` (Formula 3) — independent of any
  value Constellation applies internally (Rule 12). **GIVEN** the same
  sequence for `tarot_rune_discovered(rune_id, card_id)`, **THEN** the
  equivalent holds with `rune_source = "tarot"`.
- **AC-15**: **GIVEN** a `creature_sacrificed` event fires, **WHEN**
  `available_runes` is inspected immediately after, **THEN** no new entry
  was added to it — a Menagerie-sourced rune is never staged in the ledger
  as a separate imbuable entry; it is consumed directly into the new item in
  the same operation (Rule 13, verified jointly with Group 7 below).

**Group 6: Rune Imbuing Action — deepest treatment (Rules 14–16, highest-risk
item in this GDD)**

- **AC-16 (a) — proves the Inventory Rule 5 lock exemption actually works**
  *(unblocked — dependency shipped 2026-07-17, found stale 2026-08-27)* — **GIVEN** an Equipment item
  that is currently equipped in a Hero slot (i.e., `equipment_slot_changed`
  has already fired for it and it remains the hero's active gear) and has at
  least one free rune slot, and a `rune_id` in state `AVAILABLE`, **WHEN**
  the player confirms Rune Imbuing targeting that item, **THEN**
  `Inventory.apply_rune_to_item(item_id, rune_id, stat_delta)` is called and
  returns `true`, the item's `imbued_runes` array is appended in place (no
  `item_removed`/`item_added` pair fires), `item_rune_imbued(item_id,
  rune_id, rune_source)` fires exactly once, and **the item remains equipped
  throughout the entire operation** — no unequip → imbue → re-equip cycle
  occurs, and `equipment_slot_changed` does not fire as a side effect of the
  imbue (Rule 16's explicit exemption to Inventory's Rule 5 lock).
  **Interface dependency, RESOLVED 2026-07-17, found stale here 2026-08-27**: `Inventory.apply_rune_to_item()`
  shipped in `inventory.md`. That doc's own analysis found the originally-assumed
  Rule 5 (equip-lock) amendment is very likely unnecessary — `apply_rune_to_item`
  is an in-place metadata mutation, not a removal/discard, so it already falls
  outside Rule 5's scope as written (advisory finding, not a blocker). Now
  automatable.
- **AC-16 (b) — proves the rune is consumed, one-time use**
  *(unblocked — dependency shipped 2026-07-17, found stale 2026-08-27)* — **GIVEN** `rune_id = R` was
  successfully imbued into item `A` per AC-16(a), **WHEN** the Imbuing UI's
  rune pool is queried afterward, **THEN** `R` is absent from
  `available_runes` (transitioned `AVAILABLE → IMBUED`, terminal per States
  and Transitions), and **no** subsequent call — targeting item `A` again,
  targeting a different item `B`, or any other path — can select `R` as an
  Imbuing input; there is no "un-imbue" action anywhere in this GDD that
  could reintroduce it (Rule 15).
- **AC-16 (c) — proves clean rejection with no free rune slots**
  *(unblocked — dependency shipped 2026-07-17, found stale 2026-08-27)* — **GIVEN** a target item whose
  every rune slot is already `FILLED`, **WHEN** Rune Imbuing is confirmed
  against it with any `AVAILABLE` rune, **THEN**
  `apply_rune_to_item()` returns `false`, the item's `imbued_runes` array is
  unchanged, the candidate rune remains `AVAILABLE` in `available_runes`
  (unconsumed), no `item_rune_imbued` fires, and the player is never
  prompted to choose an existing rune to replace (Rule 16, Edge Cases — "no
  destructive default").
- **AC-16 (d) — proves each of the 3 rune sources records correctly in
  `rune_source`** *(unblocked — dependency shipped 2026-07-17, found stale 2026-08-27)* — three
  sub-cases, one per source:
  - **GIVEN** a Constellation-sourced rune (via `constellation_rune_discovered`)
    is successfully imbued, **WHEN** `item_rune_imbued` fires, **THEN**
    `rune_source == "constellation"` exactly (literal string, Rule 14).
  - **GIVEN** a Tarot-sourced rune (via `tarot_rune_discovered`) is
    successfully imbued, **WHEN** `item_rune_imbued` fires, **THEN**
    `rune_source == "tarot"` exactly.
  - **GIVEN** a Menagerie-sourced rune (via the sacrifice flow, Group 7
    below) is imbued at item creation, **WHEN** `item_rune_imbued` fires,
    **THEN** `rune_source == "menagerie"` exactly (Rule 19f). All three
    verify against the exact literal strings named in Rule 14 — no numeric
    enum, no case variance.

**Group 7: Creature Sacrifice Resolution — dedicated block (Rules 17–20,
closes `menagerie.md`'s explicitly-flagged open question)**

- **AC-17 — the happy path** *(unblocked — dependency shipped 2026-07-17, found stale 2026-08-27)* —
  **GIVEN** a valid target creature (species matches the selected Sacrifice
  Recipe's `required_species`, not in `BREEDING_PEN`) and Inventory has room
  for the recipe's `output_slot`, **WHEN** the sacrifice is confirmed,
  **THEN**, in order: (b) `has_room_for(output_slot, 1)` is checked and
  passes before the creature is touched at all; (c) a prospective `item_id`
  is generated; (d) `Menagerie.request_sacrifice(creature_id, item_id)` is
  called and returns `true`; Menagerie emits `creature_sacrificed(creature_id,
  item_id)` using that exact `item_id`; (f) Equipment Forge constructs the
  new item with one rune slot pre-filled and the rest per Rule 11's table,
  adds it via `item_added`, emits `hero_equipment_crafted(item_id, item_type
  = output_slot, quality_tier)` and then, in the same synchronous operation,
  `item_rune_imbued(item_id, rune_id, rune_source = "menagerie")` — in that
  exact order (Rule 19). ~~**Interface dependency flagged (qa-lead)**~~
  **RESOLVED 2026-07-17, found stale here 2026-09-02** (AC-19/AC-20 below
  were already corrected on 2026-08-27, this AC's own text was missed in
  that pass): `Menagerie.request_sacrifice(creature_id, target_item_id) ->
  bool` shipped in `menagerie.gd`, adopting this GDD's originated signature
  per Menagerie's own Rule 13/19d. Fully automatable today.
- **AC-18 — species mismatch, rejected before any Menagerie call**:
  **GIVEN** a selected Sacrifice Recipe with `required_species = X` and a
  target creature whose species is `Y ≠ X`, **WHEN** the sacrifice is
  attempted, **THEN** the action is rejected at Equipment Forge's own
  UI-level pre-check (Rule 19a) — `Menagerie.request_sacrifice()` is never
  called, no creature is touched, no item is created (Edge Cases).
- **AC-19 — creature in `BREEDING_PEN`, mirrors Menagerie's own Rule 13**
  *(unblocked — dependency shipped 2026-07-17, found stale 2026-08-27)* — **GIVEN** a target creature
  currently in `BREEDING_PEN`, **WHEN** the sacrifice request reaches step
  (d), **THEN** `Menagerie.request_sacrifice()` returns `false` per
  Menagerie's own Rule 13 validation, and Equipment Forge aborts: the
  prospective `item_id` generated in step (c) is discarded, no item is
  created, no materials or creature are consumed, and no further events fire
  (Edge Cases). Same interface-dependency flag as AC-17.
- **AC-20 — room check strictly precedes creature consumption**
  *(unblocked — dependency shipped 2026-07-17, found stale 2026-08-27)* — **GIVEN** Inventory has no
  free room for the recipe's `output_slot`, **WHEN** the sacrifice is
  attempted, **THEN** the action is rejected at step (b) — before step (d)'s
  `request_sacrifice()` call is ever made — so the creature is never touched
  and never consumed for a materially-impossible outcome (Rule 19b). Both
  `has_room_for()` and `request_sacrifice()` have shipped since 2026-07-17
  (found stale here 2026-09-02) — fully automatable.
- **AC-21 — Formula 2 worked example (maximum)**: **GIVEN** a sacrificed
  `aurora_stag` (`species_tier = 3`, Rare), **WHEN** Formula 2 is evaluated,
  **THEN** `quality_tier = clamp(3+1, 1, 4) = 4` exactly — matching the
  documented worked example.
- **AC-22 — Formula 2 boundary (minimum, never Tier 1)**: **GIVEN** a
  sacrificed Common-tier creature (`species_tier = 1`), **WHEN** Formula 2 is
  evaluated, **THEN** `quality_tier = clamp(1+1, 1, 4) = 2` exactly — a
  sacrifice-born item is never Tier 1, by construction (Formula 2's
  deliberate design intent).

**Group 8: Concurrency Guard, Orphaned References, Cross-Document Persistence
Gap**

- **AC-23**: **GIVEN** any two of {equipment craft, rune imbue, creature
  sacrifice} confirmed in the same frame, **WHEN** the second confirmation
  arrives while `_forge_resolving == true` from the first, **THEN** the
  second is rejected outright with no queueing, regardless of which two of
  the three operation types are involved (Edge Cases) — at minimum, one
  same-type pair (craft+craft) and one cross-type pair (imbue+sacrifice)
  must both be exercised.
- **AC-24 — orphaned rune_id, already imbued**: **GIVEN** a save references
  an item whose `imbued_runes` contains a `rune_id` no longer defined in
  current game data, **WHEN** the save loads, **THEN** the entry is
  retained (not discarded), the slot is marked internally as occupied by an
  `UNKNOWN` rune, its stat contribution resolves to zero (no crash on Hero's
  stat recalculation), a warning is logged, the slot does **not** become
  free again, and the load is not blocked — mirrors the established orphan
  pattern from `hero.md`'s `class_id` handling (Edge Cases).
- **AC-25 — orphaned rune_id, still `AVAILABLE`/unimbued**: **GIVEN** a save
  references a `rune_id` still sitting in `available_runes` that is no
  longer defined in current game data, **WHEN** the save loads, **THEN** the
  ledger entry is retained as `UNKNOWN`/unselectable (greyed out) in the
  Imbuing UI rather than silently vanishing, and the load is not blocked
  (Edge Cases).
- **AC-26 — Constellation-sourced rune persistence across save/load**
  *(unblocked — cross-doc gap resolved 2026-07-17, found stale 2026-08-27)* — **GIVEN** a
  Constellation-sourced rune already `AVAILABLE` in `available_runes` before
  save, **WHEN** a save/load cycle completes (`restore_order = 32`,
  depending on Constellation's own ledger having already restored), **THEN**
  the rune is still correctly present and selectable in `available_runes`
  post-restore. `save-persistence.md` assigned Constellation `restore_order = 24`
  on 2026-07-17 — 24 < 32, so Constellation's Discovery Ledger is guaranteed
  to restore before Equipment Forge's rebuild. Now verifiable.
- **AC-27 — Tarot-sourced rune persistence across save/load (not blocked,
  contrast case)**: **GIVEN** a Tarot-sourced rune already `AVAILABLE` in
  `available_runes` before save, **WHEN** a save/load cycle completes,
  **THEN** the rune is still correctly present post-restore. Unlike AC-26,
  this AC **is** verifiable today, since Tarot's `restore_order = 22`
  already exists and is confirmed to restore before Equipment Forge's 32
  (Dependencies → `restore_order` rationale).

## Open Questions

| Question | Owner | Notes |
|---|---|---|
| `Inventory.apply_rune_to_item(item_id, rune_id, stat_delta) -> bool` | Inventory System owner | **RESOLVED 2026-07-17** (found stale here 2026-08-27) — shipped in `inventory.md`, which also found the originally-assumed Rule 5 amendment very likely unnecessary (in-place metadata mutation, not removal/discard). AC-16(a)–(d) and AC-15's Menagerie-arrival confirmation are now automatable. |
| `Menagerie.request_sacrifice(creature_id: String, target_item_id: String) -> bool` | Menagerie System owner | **RESOLVED 2026-07-17** (found stale here 2026-08-27) — `menagerie.md` Rule 13 adopted this exact signature; shipped in `menagerie.gd`. AC-17, AC-19, AC-20 are now automatable. |
| `Inventory.has_room_for(item_type, quantity) -> bool` | Inventory System owner | **RESOLVED 2026-07-17** (found stale here 2026-08-27) — same shared interface `crafting.md` also depends on, shipped in `inventory.md`. AC-9 and AC-20 are now automatable. |
| `recipe_discovered`'s Key Subscribers list extension (Encyclopedia, Crafting UI → + Equipment Forge UI) | EventBus owner | **Documentation-only change, no payload/schema change** — `recipe_category` already generically supports `"hero_equipment"`. Flagged for `event-bus.md` sign-off at its next revision pass, same low-risk-extension precedent as `component_crafted` carrying two categories under one event (Rule 7). Does not block any AC above since the event itself already fires correctly today. |
| Constellation's Discovery Ledger has no `restore_order` assigned anywhere in `save-persistence.md` | Save & Persistence System owner / Constellation System owner | **This is a gap in `constellation.md`/`save-persistence.md`, not in this GDD** — but it makes AC-26 (Constellation-sourced rune restore-behavior) unverifiable end-to-end until resolved. Treat as a blocking cross-document gap, not a documentation nicety, per Dependencies row #9. Resolve by assigning Constellation a concrete `restore_order` and confirming it precedes 32. |
| `save-persistence.md`'s Line 81 save-payload summary ("All crafted equipment in the hero's forge inventory") is broader than what Equipment Forge actually persists | Save & Persistence System owner | This GDD's Rule 10 is the authoritative narrower scope (two ledgers only; item data is Inventory's). Flagged for `save-persistence.md`'s next revision pass to correct the mismatch — until then, an implementer following the older summary literally risks duplicating item state Inventory already owns (Dependencies row #13). |
| Full Equipment Recipe catalogue (6–10 recipes across 9 slot categories × tier spread) and 5 Sacrifice Recipes' exact `stat_delta`/`rune_id` content | game-designer / content pipeline | Explicitly out of scope for this GDD (Rule 6) — this document defines the mechanism only; itemization is content-authoring work, matching Crafting's own scope boundary. |
| **(qa-lead, AC review) RESOLVED 2026-07-17, found stale here 2026-08-27** — the 10 of 27 ACs previously BLOCKED (AC-9, AC-16(a)–(d), AC-17, AC-19, AC-20) plus AC-26's separate cross-document gap (Constellation `restore_order`) | Inventory System owner / Menagerie System owner | All 4 underlying interfaces/gaps (`has_room_for`, `apply_rune_to_item`, `request_sacrifice`, Constellation `restore_order`) shipped/resolved 2026-07-17. All 11 ACs are now automatable. |
| Rune stat magnitude authoring (Formula 3) has no closed-form example to test against, only a guideline range | game-designer | Not a testable Logic-story formula by design (deliberately hand-authored, same precedent as Crafting's Formula 2 and Defense Building's tech-cost table) — no AC above attempts to assert a specific numeric output for Formula 3 beyond the documented worked examples staying within the 0.02–0.08 / ~3%–10% guideline ranges; content review, not automated test, is the correct evidence gate for actual authored rune values. |
