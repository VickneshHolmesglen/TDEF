# Crafting System

> **Status**: Approved (`/design-review --depth lean` re-review 2026-08-27 — no blocking items remain; 7 stray body references to `component_repaired` as "proposed"/"not yet catalogued" corrected, see the "Known gaps" note below)
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-07-16
> **Implements Pillar**: Everything Connects · The Sanctuary Is Your Statement
> **Known gaps — CLOSED (2026-08-23)**: the 3 cross-system interfaces this GDD depends on (`Inventory.has_room_for()`, `Inventory.clear_damaged_flag()`, `component_repaired` EventBus event) were all implemented and tested well before this correction — this note simply was never revisited after. The one real remaining gap (no UI anywhere called `Crafting.resolve_repair()`) closed the same day: `inventory_screen.gd`'s new Repair sub-tab.

## Overview

The Crafting System is the sanctuary's production layer: it converts raw Materials — the tiered (Common / Uncommon / Rare) drops the Resource Economy awards from monster kills during missions — into the Tower Components and other Crafted Goods that the rest of the game is built from. Technically, it is both a direct-interaction surface and a resolution engine. As a surface, it presents a recipe list from which the player deliberately chooses what to produce; as an engine, it resolves each recipe against the player's current material counts, gating unbuildable recipes (greyed-out until their inputs are met) and, on craft, atomically consuming the required material stacks from the shared inventory and writing the finished item back into it. Its outputs are the four tower slot types — `foundation`, `weapon`, `focus`, `power` — the identical components the Tower System later assembles into towers, plus non-tower Crafted Goods. Crafting is strictly Sanctuary-only: it is locked for the entire duration of a mission and available only between runs, so every piece a player brings to a fight was originated in advance, never mid-combat. Per the Inventory System's locked layout (Inventory Core Rule 6), Crafting is not a screen of its own — it is the permanent right-hand panel of the single two-panel Sanctuary screen, shown at all times beside the Inventory grid so that "what do I have?" and "what can I make from it?" are always answered in the same glance. Player-facing, it transforms accumulated raw material into specific, chosen capability: the recipe panel is where a run's loot stops being fuel and becomes the exact pieces the player's build theory calls for — the origin point of everything the Tower and Constellation systems later author and arrange.

## Player Fantasy

> The Inventory asks what you could make. This is the hand that *makes* it.
>
> The two panels sit side by side so this one can answer the other. A stack of frost-touched silk is a question the moment it lands in the grid — and the answer is never on the left. It's here, on the right, where the material stops being something you *have* and becomes something you've *made*. When a recipe that sat greyed-out for six missions finally lights up, that instant belongs to your materials: you earned the access, and access is the only thing loot is ever worth. But the light-up is only permission. What happens next — reaching into a heap of raw drops and pulling out a specific foundation, a specific weapon, a specific focus that changes how a tower will fire — that is the part that is yours. Access is granted. Origination is spent.
>
> This is the one place in the entire sanctuary where a thing that did not exist begins to. A tower is a decision you *commit*; a constellation is decisions you *arrange* — but both of them work with pieces that are already real, already in your hands. Neither one makes anything. They deploy and they relate. Crafting is upstream of all of it: the single point in the whole chain where you are not choosing among your options but *creating the options everything else will choose among*. You are not the player who places the piece well, or the player who arranges the pieces well. You are the reason the piece is there to place.
>
> And it is never a number you're chasing. The moment that matters is the one where you make the exact component you built the run to be able to make — the power core you needed a specific creature bred over three missions to finally yield the material for, the weapon you'd sketched in your head a week before the recipe was reachable. When it comes out of the forge exactly as you pictured it, the feeling is the small, precise vindication of a prediction paying off: you didn't farm until something good happened. You decided what you needed, went and got the access, and made the thing on purpose.
>
> Then it leaves this panel and it never really comes back — it goes into a tower, and the tower goes into a shape, and the shape holds a lane, and none of them remember that they started as a stack of silk on a workbench. But you remember. Every component riveted into every tower on your field, every corner of every constellation the wave breaks itself against, began as a decision you made in this two-foot-wide strip of screen. The sanctuary full of machines that win your fights is downstream of this bench. That is the recognition Crafting gives you that no tower and no constellation ever can: not that a piece was placed right, and not that pieces were arranged right — but that the pieces exist at all, and they exist because you made them.

## Detailed Design

### Core Rules

**Recipe Model**

1. A **Recipe** (`RecipeResource`, `GameDataRegistry`-backed per ADR-0009) is a
   fixed, author-defined mapping — never a rolled/variable output. Its fields:

   | Field | Type | Description |
   |---|---|---|
   | `recipe_id` | StringName | Unique identifier |
   | `recipe_category` | String | `"tower_component"` or `"crafted_good"` |
   | `component_slot` | String | `foundation`/`weapon`/`focus`/`power` (only set when `recipe_category == "tower_component"`) |
   | `inputs` | Dictionary[StringName, int] | `material_id → quantity` required, 1–3 material types |
   | `tech_prerequisite` | StringName | `tech_id` from Defense Building's tech tree, or `""` if ungated |
   | `output_item_id` | StringName | The crafted item's definition id |
   | `output_quantity` | int | Always `1` for `tower_component`; `1`–`5` for `crafted_good` |
   | `quality_tier` | int | `1`–`4` for `tower_component` (see Rule 6); fixed `0` for `crafted_good` (no tier concept applies) |
   | `source_blueprint_tower_id` | StringName | *(2026-08-17, Tower Assembly extension)* Non-empty only on a **blueprint-copy** `tower_component` recipe — see Rule 1a below. `""` for every generic recipe. |

   **`inputs` keying, corrected 2026-08-17**: the table above says
   `material_id → quantity`, but the real, shipped contract (matching
   `Inventory.has_items()`) sums by **`item_type`** (`Equipment` /
   `TowerComponent` / `Material` / `CraftedGood`), not by a specific
   material. A second axis, **rarity** (`Common`/`Uncommon`/`Rare`, via
   `Inventory.has_items_by_rarity()`), was added earlier to express
   Formula 1–3's "N of rarity tier X" costs. A **third axis, specific
   `item_id`** (via `Inventory.has_items_by_material_id()`), was added
   2026-08-17 for the blueprint-copy recipes below, which need to gate on
   one exact material (e.g. `foundation_surplus`) rather than any item
   sharing its `item_type` or `rarity` — `inputs` may now mix all three
   vocabularies freely in the same Dictionary, and `RecipeResource.validate()`
   accepts a key that is a valid `item_type`, a valid rarity string, or a
   known `item_id`.

1a. **Blueprint-copy `tower_component` recipes** (2026-08-17, Tower Assembly
    extension, player-requested): a recipe with `source_blueprint_tower_id`
    set (e.g. `&"archer"`) produces a standalone component item whose stats
    are an **exact copy** of that pre-authored basic tower's own embedded
    Foundation/Weapon/Focus/Power sub-resource — not a new design, a
    reproduction of an existing one. This is a second way to obtain the raw
    material Tower Assembly's `assemble_tower()` consumes, alongside (not
    replacing) the generic raw-material recipes above; both output types
    flow into the same Assemble Towers tab identically. Funded by
    `resource-economy.md` Formula 6's new per-slot surplus materials
    (`foundation_surplus`/`weapon_surplus`/`focus_surplus`/`power_surplus`),
    granted automatically at mission end for every tower still standing.
    `source_blueprint_tower_id` is validated at load time (must reference a
    real registered `TowerBlueprintData`) but is **not** consulted by
    `Crafting.resolve_craft()` at craft time — the stat match is enforced by
    construction (the recipe author copies the exact values from the source
    blueprint into a new standalone `.tres`), verified by a dedicated
    regression test (`tests/integration/crafting/blueprint_component_copy_recipe_test.gd`)
    asserting the two files stay in sync. First content pass: all 4 slots
    for the Archer blueprint only — the remaining 5 basic towers are a pure
    data-authoring backlog, no further code needed.

    **Known, disclosed limitation (found and worked around, not fully
    closed, 2026-08-17)**: the 4 surplus materials are authored with
    `item_type = &"Material"` (so they display correctly in Inventory's
    existing Materials tab, alongside the other 13). This makes them
    vulnerable to `Inventory.consume_by_type("Material", N)` — used by
    every *generic* `tower_component`/`crafted_good` recipe's plain
    `Material` cost — which sweeps any unlocked `item_type == "Material"`
    slot indiscriminately, with no way to exclude a specific material_id.
    A real bug from this was caught during this feature's own testing
    (crafting `recipe_archer_foundation` with a mixed `{foundation_surplus:
    2, Material: 3}` cost silently drained an unrelated `weapon_surplus`
    stack) and worked around by keeping every blueprint-copy recipe's
    `inputs` keyed **only** by its own specific surplus material — never
    mixed with a generic `Material` entry. This closes the collision for
    Tower Assembly's own recipes, but the underlying risk is not
    architecturally closed: any **other**, unrelated recipe with a generic
    `Material` cost (e.g. `recipe_iron_foundation`) can still silently
    consume a player's surplus material stock if it happens to be drawn
    from Inventory's slot-iteration order before other Material items are.
    A real fix would need a way to exempt specific materials from the
    generic sweep (e.g. a new `ItemDefinitionResource` flag), which is a
    separate, not-yet-scoped follow-up.

   **Assumption flagged**: this is the deliberately simple option — one
   recipe, one fixed output, no rolled variance. Tower Components produced by
   Crafting are still unique cap=1 instances per `inventory.md` (each gets its
   own `item_id` so `damaged` can be tracked per-instance), but their *stats*
   are fixed by the recipe, not rolled. Stat-rolled variance (if the game ever
   wants Crafting to roll like a loot table) is explicitly out of scope for
   this GDD — 4 other systems (Tower, Hero, Constellation, Wave Manager) are
   already combinatorially deep; Crafting does not need to be a fifth.

2. **Repair is not a recipe.** It has no `RecipeResource` entry, no
   `tech_prerequisite`, and never fires `recipe_discovered` — it is an
   always-available Sanctuary action gated only by (a) owning a
   `damaged=true` component instance and (b) affording its material cost
   (Formula 3). This is a deliberate asymmetry: repair is upkeep on something
   you already built, not new progression, so it should not compete with the
   tech/discovery gate that new recipes use.

**Recipe Discovery**

3. A recipe has two independent gates, both of which must be true for it to
   be **craftable**:
   - **Tech gate**: `tech_prerequisite == ""` (always satisfied), or the
     matching `tech_unlocked` event has fired for that `tech_id`.
   - **Material gate**: `Inventory.has_items(recipe.inputs)` currently
     returns `true`.

4. **`recipe_discovered` fires exactly once per `recipe_id`, permanently**,
   the first moment **both** gates become simultaneously true — checked from
   two trigger paths:
   - On `tech_unlocked(tech_id, ...)`: for every recipe whose
     `tech_prerequisite == tech_id`, if `has_items(inputs)` is already true
     at that moment, fire `recipe_discovered` now.
   - On `item_added(...)`: for every tech-gate-satisfied recipe not yet
     discovered, re-check `has_items(inputs)`; if now true, fire
     `recipe_discovered`.

   Once discovered, a recipe is permanently visible in the Crafting panel and
   Encyclopedia (mirrors Constellation's one-way Discovery Ledger pattern —
   `constellation.md` States and Transitions) — it never re-hides if
   materials are later spent elsewhere and the player temporarily can't
   afford it again. **Craftability** (whether the Craft button is currently
   enabled) is a *separate*, continuously-re-evaluated check
   (`has_items(inputs)`) on every `item_added`/`item_removed` — this is what
   `inventory.md`'s "Crafting subscribes to `item_added` for recipe-
   availability refresh" line refers to. Discovery is permanent; craftability
   flickers on and off with the player's current material stock — matching
   this GDD's own Visual/Audio spec above (recipe rows transition between
   Material-insufficient and Ready-to-craft repeatedly; the one-shot
   unlock-cascade gold treatment fires only once, on the discovery
   transition, never on a craftability flicker).

**Quality Tier**

5. `quality_tier` (the `component_crafted` payload field, already frozen in
   `event-bus.md`) ranges **0–4**:
   - `0` = not applicable (`crafted_good` output — Crafted Goods have no
     tier concept anywhere else in the project).
   - `1`–`4` = fixed by the recipe at authoring time, never rolled. For
     `component_slot == "foundation"` output, `quality_tier` maps 1:1 onto
     the crafted Foundation's own `tier` field (`tower.md` Foundation
     schema). For `weapon`/`focus`/`power` output — none of which have a
     literal `tier` int field in their schema (`tower.md` 2a) —
     `quality_tier` is a **Crafting-only content-authoring signal**: it
     indicates which point in that slot type's stat range (e.g.
     `weapon_damage` [8.0, 120.0]) the recipe's fixed output sits at (Tier 1
     recipes author near the low end, Tier 4 near the high end). This is
     **not** a new schema field on Weapon/Focus/Power — it only exists on
     the `RecipeResource` and the `component_crafted` event payload.
     **Flagged assumption**: no other GDD defines what `quality_tier` means;
     this mapping is originated here and should be treated as the
     authoritative definition going forward.

**Component Repair (closes `tower.md` OQ-12)**

6. Crafting owns component repair. A component instance with `damaged==true`
   (set by Tower System per `tower.md` 2a/OQ-12) can be repaired for a
   Common-material-only cost (Formula 3), scaled by the component's own
   `quality_tier` at the time it was crafted/rolled. Repair **mutates the
   existing item instance in place** — `damaged` flips `true → false` — it
   does **not** consume the item and produce a new one, and does **not** go
   through `component_crafted` (nothing new was crafted).
   **Cross-GDD interface gap flagged**: `inventory.md`'s current API surface
   (query + whole-item add/remove) has no operation for "mutate an existing
   stored instance's metadata field." This GDD requires a new Inventory
   method, proposed as `Inventory.clear_damaged_flag(item_id: String) ->
   bool`, and a new EventBus event `component_repaired(item_id: String,
   component_type: String)` (Crafting-owned, subscribers: Inventory [applies
   the flag change], Mission HUD, Audio) — **neither exists in
   `event-bus.md`'s frozen catalogue today; both are proposed additions**,
   following the same precedent as `item_pickup_rejected` and
   `tower_component_returned`, which were added to the catalogue after being
   originated in a downstream GDD.

**Capacity Pre-Check (new proposed Inventory interface)**

7. Before consuming any materials for a `tower_component` recipe, Crafting
   must confirm Inventory has room for the output — cap=1 unique-instance
   items need a genuinely free slot, and a failed placement after materials
   are already spent would be a punishing dead loss. **Cross-GDD interface
   gap flagged**: `inventory.md` today only exposes post-hoc rejection
   (`item_pickup_rejected` fires *after* a failed add). This GDD requires a
   new pre-check, proposed as `Inventory.has_room_for(item_type: String,
   quantity: int = 1) -> bool`, called **before** Rule 8's consume step.
   `crafted_good` recipes skip this pre-check — 99-cap stackable items always
   have somewhere to overflow to per `inventory.md`'s fill-then-overflow
   algorithm, unless Inventory is completely full, which is covered by the
   Edge Cases below.

**Crafting Resolution**

8. On player confirmation of a craftable recipe, Crafting performs, in
   order: (a) re-validate `has_items(inputs)` (defends against stale UI —
   see Edge Cases), (b) for `tower_component` recipes only, validate
   `has_room_for(component_slot, 1)` (Rule 7), (c) batch-consume `inputs` via
   Inventory's consume API (fires `item_removed` per material, or the
   batch equivalent), (d) construct the output item and hand it to Inventory
   via the normal `item_added` path, (e) emit `component_crafted(component_id,
   component_type, quality_tier)` (for `tower_component`) or an equivalent
   `crafted_good`-path emission using the same event (`component_type`
   carries the item category in that case — no second event is introduced).
   Steps (a)–(e) execute synchronously and atomically within one confirm —
   there is no partial-completion state, matching this GDD's own UI
   Requirement that a single confirm crafts with no intermediate dialog.

9. **Crafting is instant on confirmation — no timer, no queue.** Rationale:
   Crafting only operates in `SANCTUARY`, which per `game-concept.md`'s
   pillar framing is a deliberate-planning space (mirroring Scout/
   Intermission), not an idle-waiting space. An idle-style crafting queue
   would be the only "wait for a timer" mechanic anywhere in the game and
   would contradict that framing. **Flagged design call** — this is a
   recommendation with no opposing GDD constraint; revisit only if a future
   pacing pass wants a deliberate meta-progression gate here.

### States and Transitions

Crafting owns **no mission-phase state of its own** — it inherits
`SANCTUARY \ SCOUT \ WAVE_ACTIVE \ INTERMISSION \ MISSION_COMPLETE \ DEFEAT`
directly from `game-concept.md`'s state table, which already marks Crafting
`LOCKED` during `SCOUT`/`WAVE_ACTIVE`/`INTERMISSION`. This mirrors
Constellation's own "inherits phase state, gates nothing itself" pattern
(`constellation.md` States and Transitions) — Crafting's screen is simply
inaccessible outside `SANCTUARY` (same UI-inaccessible-but-not-write-blocked
distinction `inventory.md` draws for `INVENTORY_HEADLESS`, except Crafting has
no headless-mode writes at all: nothing crafts itself mid-mission, so there is
no equivalent "still active" carve-out to make).

What Crafting *does* own is a permanent per-recipe discovery ledger, structured
identically to Constellation's Discovery Ledger:

| State | Entry Condition | Behavior | Exit Condition |
|---|---|---|---|
| `HIDDEN` (implicit — default, not tracked until discovered) | Recipe not yet meeting both gates (Rule 3) | Not shown in Crafting panel or Encyclopedia | Both tech gate and material gate true simultaneously (Rule 4) → `DISCOVERED` |
| `DISCOVERED` (playthrough-scoped, save-persisted) | `recipe_discovered` fires | Recipe permanently visible in Crafting panel/Encyclopedia; craftability (Craft button enabled/disabled) is re-evaluated independently on every `item_added`/`item_removed` (Rule 4) | None — terminal, one-way, matches Constellation's Discovery Ledger precedent |

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Inventory** | ← Crafting (query/consume/produce) | `has_items(cost: Dictionary) -> bool`, batch-consume on confirmed craft, produces output via normal `item_added` path. **New, proposed**: `has_room_for(item_type, quantity) -> bool` (Rule 7) and `clear_damaged_flag(item_id) -> bool` (Rule 6) — neither exists in `inventory.md` today. |
| **Inventory** | Inventory → Crafting | `item_added`/`item_removed` drive both craftability re-checks (Rule 4) and discovery re-checks (Rule 4) |
| **Defense Building** | Defense Building → Crafting | `tech_unlocked(tech_id, tech_category)` drives recipe tech-gating (Rule 3/4) |
| **Resource Economy** | No direct interface | Per `resource-economy.md`'s own explicit statement, Crafting queries Inventory for material availability — it has zero direct interface to Resource Economy, despite being downstream of the same tiered (Common/Uncommon/Rare) material drops in spirit |
| **Tower System** | Tower → Crafting (schema/data only, no runtime call) | `component_slot`/schema field ranges (Foundation/Weapon/Focus/Power, `tower.md` 2a) define what a `tower_component` recipe's fixed output must validate against; `damaged: bool` field is read/written by repair (Rule 6) |
| **EventBus** | Crafting → EventBus | Emits `component_crafted`, `recipe_discovered`, `component_repaired` (all 3 frozen in `event-bus.md`'s catalogue — `component_repaired` merged 2026-07-17, found stale here 2026-08-27) |
| **EventBus** | EventBus → Crafting | Subscribes to `tech_unlocked`, `item_added`, `item_removed` |
| **Encyclopedia** | Crafting → Encyclopedia | Subscribes to `recipe_discovered` |
| **Mission HUD / Audio** | Crafting → these | Subscribe to `component_crafted`, `component_repaired` |

## Formulas

### Formula 1 — Tower Component Recipe Material Cost

```
material_qty(rarity, T) = round(base_qty[rarity] × tier_dps_multiplier(T))
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Rarity base quantity | `base_qty[rarity]` | int | Common=8, Uncommon=4, Rare=2 | Hand-tuned baseline at Tier 1 equivalent (Tier 1 itself only ever needs Common — see gating below) |
| Recipe quality tier | `T` | int | 1–4 | The recipe's fixed `quality_tier` (Rule 5) |
| DPS scale factor | `tier_dps_multiplier(T)` | float | {1.0, 1.6, 2.4, 4.0} | **Reused directly from `tower.md`'s Foundation schema field of the same name — not redefined here.** Deliberate design choice: material cost scales in lockstep with the same multiplier that scales the crafted Foundation's DPS output, so cost-per-power stays constant across the tier ladder rather than any tier becoming a comparatively cheaper power spike. |

**Rarity gating** (mirrors `inventory.md`'s own step-change rarity
introduction — Uncommon at "tier 2", Rare at "tier 4," matching the
`inventory_rare_material_gate_tier=4` registry constant's precedent, though
this is a parallel design echo, not a shared mechanical dependency — Crafting
recipe tiers and Inventory slot-expansion tiers are different axes):

| Recipe Tier (`T`) | Common | Uncommon | Rare |
|---|---|---|---|
| 1 | `round(8×1.0)=8` | — | — |
| 2 | `round(8×1.6)=13` | `round(4×1.6)=6` | — |
| 3 | `round(8×2.4)=19` | `round(4×2.4)=10` | — |
| 4 | `round(8×4.0)=32` | `round(4×4.0)=16` | `round(2×4.0)=8` |

**Output range**: Common 8–32, Uncommon 0/6/10/16, Rare 0/0/0/8.

**Calibration note against `base_drop_rate=0.45`**: at ~0.45 per-kill drop
chance and an average successful-drop quantity of roughly 1–2 units
(`resource-economy.md` Formula 2, early/mid-wave), a Tier 1 recipe's 8 Common
units costs roughly 8–15 kills of farming — comparable in scale to
Inventory's own Tier 1 slot-expansion cost (10 Common). A Tier 4 recipe's
32 Common + 16 Uncommon + 8 Rare deliberately demands a late-game material
*diversity* investment, not just quantity grinding, matching Resource
Economy's stated "meta-progression grinds to a halt if too low / trivialized
if too high" calibration target for `base_drop_rate`.

**Worked example**: A Tier 3 Weapon-slot recipe (`component_slot="weapon"`,
`quality_tier=3`) costs 19 Common + 10 Uncommon, 0 Rare.

---

### Formula 2 — Crafted Goods Recipe Material Cost

Deliberately **not formulaic** — hand-authored per recipe within a guideline
range, same precedent as `inventory.md`'s own slot-expansion cost table
(explicitly hand-tuned, not derived from a clean exponent after that GDD's
earlier formula was found not to reproduce its own table).

| Guideline | Value |
|---|---|
| Material rarity | Common only — Crafted Goods never gate on Uncommon/Rare; that axis is reserved for Tower Component power progression (Formula 1) |
| Quantity range | 3–12 units |
| `output_quantity` | 1–5 units produced per craft |
| `quality_tier` | Fixed `0` (N/A) |

**Output range**: 3–12 Common material consumed per craft, 1–5 units
produced. **Worked example**: a "Healing Salve ×3" recipe costs 6 Common
material, produces `output_quantity=3`.

---

### Formula 3 — Component Repair Material Cost

```
repair_common_qty(T) = round(base_repair_common × tier_dps_multiplier(T))
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Repair base quantity | `base_repair_common` | int | 4 (hand-tuned, 2–8 safe range) | Baseline Common-material cost at Tier 1 equivalent |
| Component's quality tier | `T` | int | 1–4 | The `quality_tier` the component was originally crafted at (read from the instance, not re-rolled) |
| DPS scale factor | `tier_dps_multiplier(T)` | float | {1.0, 1.6, 2.4, 4.0} | Same reused constant as Formula 1 |

**Repair always costs Common material only, regardless of the component's
original tier's rarity requirements** — this is the deliberate mechanism that
keeps repair meaningfully cheaper than recrafting from scratch, not just a
smaller quantity of the same rarity mix.

| Tier | Repair Cost (Common only) | Fresh-craft equivalent (Formula 1) | Repair as % of fresh Common-only cost |
|---|---|---|---|
| 1 | 4 | 8 Common | 50% |
| 2 | 6 | 13 Common + 6 Uncommon | 46% (and avoids Uncommon entirely) |
| 3 | 10 | 19 Common + 10 Uncommon | 53% (and avoids Uncommon entirely) |
| 4 | 16 | 32 Common + 16 Uncommon + 8 Rare | 50% (and avoids Uncommon/Rare entirely) |

**Output range**: 4–16 Common material. **Worked example**: a `damaged=true`
Tier 4 Foundation instance repairs for 16 Common material — no Uncommon or
Rare required, versus 32+16+8 to build a fresh replacement.

## Edge Cases

- **If materials are insufficient at confirm-time** (stale UI — e.g. another
  system consumed materials between the button rendering and the click):
  Rule 8 step (a) re-validates `has_items(inputs)`; if false, the craft is
  rejected — no consumption, no output, no event fires, no error surfaced
  beyond a UI "insufficient materials" state refresh (the Craft button should
  already be disabled by the live `item_added`/`item_removed` re-check, so
  this is a defensive re-validation against a race, not the primary path).

- **If a `tower_component` recipe's output has no free Inventory slot**:
  Rule 7's `has_room_for()` pre-check runs *before* any material is consumed
  (Rule 8 step (b), before step (c)). If `false`, the craft is rejected in
  full — zero materials consumed, no event fires. This is a hard requirement
  distinguishing Crafting from ordinary mid-mission pickups: Inventory's own
  `item_pickup_rejected` policy ("lost, not queued") is acceptable for an
  incidental in-mission drop, but is not acceptable for a player-initiated,
  Sanctuary-side spend of materials the player chose to commit — a
  materials-spent-item-lost outcome would be a punishing dead loss with no
  recovery, so Crafting must pre-check rather than post-check.
  **Amended 2026-10-10 (player request)**: a slot the craft's own cost would
  fully empty counts as room — e.g. a full bag holding exactly the 5 Material
  `recipe_iron_foundation` costs can still craft, since step (c) clears that
  slot before step (d) places the output. The pre-check dry-runs the consume
  (`Inventory.consuming_would_free_a_slot()`), so the no-dead-loss guarantee
  above is unchanged. When the pre-check does fail, the Crafting panel shows
  the row's button as a disabled "Bag Full" with a tooltip, never a live
  Craft button that silently does nothing.

- **If a `crafted_good` recipe's output stack has genuinely no room anywhere**
  (Inventory fully at capacity, no partial stack space and no open slot at
  all): Crafting attempts the normal `item_added` path per Rule 8 step (d);
  if Inventory's fill-then-overflow algorithm still can't place any of it,
  `item_pickup_rejected` fires per `inventory.md`'s existing policy. Unlike
  the `tower_component` case above, materials **are** already consumed by
  this point — this is an accepted, lower-stakes edge case specific to
  Crafted Goods, since a genuinely-full Inventory is itself a
  player-visible, proactively-warned-about state per `inventory.md`'s own
  capacity-warning edge case; a player crafting into a known-full inventory
  has been told this could happen.

- **If a recipe's `tech_prerequisite` is somehow "un-unlocked" after
  `tech_unlocked` has already fired**: explicitly out of scope. No system in
  the project ever revokes a `tech_unlocked` state; this case is not
  defended against and should not be.

- **If two craft confirmations for the same or different recipes arrive in
  the same frame** (e.g. a double-click or an input-buffering bug): Crafting
  guards with a single `_craft_resolving: bool` flag, set `true` at the start
  of Rule 8's step (a) and cleared `false` only after step (e) completes.
  Because craft resolution is fully synchronous and instant (Rule 9), the
  window is at most the current frame; a second confirmation received while
  `_craft_resolving == true` is rejected outright (no queueing) — this
  prevents a double-consume/double-produce race without needing any
  cross-frame state.

- **If a component is repaired while it is currently equipped/installed on a
  tower**: this cannot occur — `inventory.md` Rule 5's equipped-item lock
  already prevents any mutation of a locked item's state, and a component is
  only `damaged==true` after being *returned* to Inventory (unequipped) per
  `tower.md`'s `tower_component_returned` event. A `damaged` component is
  therefore never simultaneously equipped, so no conflict exists.

## Dependencies

| System | Direction | Nature | Interface |
|---|---|---|---|
| **Inventory** | Depended on (hard) | `has_items()`, `has_room_for()`, `clear_damaged_flag()` (all shipped — added to `inventory.md` 2026-07-17, found stale here 2026-08-27), batch-consume, `item_added`/`item_removed` |
| **Resource Economy** | Indirect (soft) | No direct interface, per `resource-economy.md`'s own explicit statement — Crafting only ever reads material availability through Inventory |
| **EventBus** | Depended on (hard) | Emits `component_crafted`, `recipe_discovered`, `component_repaired` (all 3 frozen — `component_repaired` merged 2026-07-17); subscribes to `tech_unlocked`, `item_added`, `item_removed` |
| **Defense Building** | Depended on (hard, upstream) | `tech_unlocked(tech_id, tech_category)` drives recipe tech-gating (Rule 3/4) |
| **Tower System** | Depended on (hard, data-only) | Component slot schemas (Foundation/Weapon/Focus/Power field ranges) constrain what a `tower_component` recipe's fixed output must validate against; `damaged: bool` field is read/written by repair (Rule 6) |
| **Encyclopedia** | Depends on Crafting | Subscribes to `recipe_discovered` |
| **Mission HUD / Audio** | Depend on Crafting | Subscribe to `component_crafted`, `component_repaired` |

## Tuning Knobs

| Knob | Default | Safe Range | Too High | Too Low |
|---|---|---|---|---|
| `base_common_qty` (Formula 1) | 8 | 3–15 | Tier 1 recipes feel like a wall before the player has any real material stockpile | Tier 1 recipes trivialize on the very first mission's haul, undercutting the "unlock cascade" fantasy |
| `base_uncommon_qty` (Formula 1) | 4 | 1–8 | Tier 2–4 recipes stall waiting on a scarcer rarity tier disproportionately | Uncommon gating becomes a rubber-stamp, not a real diversity requirement |
| `base_rare_qty` (Formula 1) | 2 | 1–5 | Tier 4 recipes (the endgame power ceiling) become unreachable without dedicated farming | Rare-gating (the entire point of introducing a 3rd rarity tier) becomes meaningless |
| `base_repair_common` (Formula 3) | 4 | 2–8 | Repair approaches the cost of a fresh recraft, eliminating its "cheaper upkeep" identity | Repair becomes free-feeling, removing any weight from losing a tower mid-mission |
| Crafted Goods quantity range (Formula 2) | 3–12 Common | 2–20 | Crafted Goods compete with Tower Component recipes for the same material pool at a disruptive scale | Crafted Goods become a non-decision, always affordable |
| `tier_dps_multiplier` | {1.0, 1.6, 2.4, 4.0} | **Not owned here — see `tower.md`.** Any change to this constant automatically re-scales every Formula 1/3 output; do not fork a separate Crafting-only copy. | — | — |

## Visual/Audio Requirements

**Recipe list states (Crafting panel, right side)**

Every recipe entry renders in exactly one of three states, each carrying a distinct shape/icon treatment as well as color so no state is color-only (Sec 4.5 discipline):

| State | Color treatment | Non-color cue | Meaning |
|---|---|---|---|
| **Tech-locked** | UI Disabled Grey (`#6B7280`), icon at 40% opacity | Lock-icon overlay (same glyph as Inventory's equipped-lock indicator, Sec 3.3, for visual-language consistency) | Recipe not yet unlocked by progression |
| **Material-insufficient** | Full-color icon, but cost text renders in UI Warning Orange (`#F5921A`) | Insufficient quantities get a small "!" badge on the cost line, not just colored text | Unlocked, but current Inventory holdings don't cover the cost |
| **Ready-to-craft** | Full-color icon, cost text in default UI Parchment (`#DDD4B0`) | A filled (non-outline) confirm-button state — outline-only buttons read as "not currently actionable" elsewhere in the UI, so filled is the actionable tell | Craftable right now |

This mirrors Inventory's own Pair 3 convention (grey = inert, never color-only) and deliberately avoids inventing a fourth UI state color — Crafting reuses Inventory's existing UI Disabled/Warning vocabulary rather than adding new hues, reinforcing that both panels are one screen.

**The unlock-cascade moment ("recipes light up")**

This is the system's stated peak feeling (Resource Economy's Player Fantasy), so it gets the panel's only reserved one-shot treatment — but per the Godot 4.6 glow constraint, it must be sprite/particle/color-driven, not bloom-driven, following the same convention as Constellation's rune-plate ignition (`constellation.md`, activation section):

- On the `item_added` event that pushes a previously-`material-insufficient` recipe over its cost threshold, that recipe's row plays a one-shot transition: icon desaturate-to-full-color wipe (Fieldstone-Grey-adjacent → full saturation, ~0.4s) plus a brief Herald Gold border pulse (fade over ~0.5s) — the same gold reserved in Inventory for "genuine milestone" events (slot expansion), extended here to its natural crafting equivalent: a recipe becoming makeable is exactly that kind of milestone, not a routine event.
- **Off-screen/off-tab visibility**: because the trigger (`item_added`) can fire while the player is looking at a different tab of the left panel or a different recipe row, the Crafting panel's tab/category header itself gets a small Herald Gold pip badge (count of newly-available recipes) that persists until the player opens that category — this is how the cascade stays visible even if the exact row isn't on screen, without requiring a screen-wide flash that would compete with Inventory's own pickup-pop language on the same screen.
- If multiple recipes cross their threshold in the same `item_added` event (a single material pickup unlocking several recipes at once — the literal "cascade" case), each affected row plays its transition independently but the category pip badge sums the count rather than stacking multiple screen-wide effects — the moment reads as "several things opened up" via list content, not via compounded VFX noise.

**Craft-confirm moment (`component_crafted` firing)**

Deliberately distinct from Inventory's pickup pop so the two don't read as redundant when they fire back-to-back (craft confirms → `component_crafted` → output triggers `item_added` → pickup pop):

- The recipe row itself plays a quick consume-flash: a brief inward collapse of the cost icons toward the recipe icon (~0.25s), reading as "materials became this thing" rather than Inventory's "thing appeared" pop. This is a transformation cue, not an acquisition cue — different information, different animation shape.
- No new color introduced — uses existing UI Parchment/Accent tones already in the panel chrome. The subsequent `item_added` pop on the left panel remains the sole "you now own this" beat; Crafting's own flash never repeats it.

**Material consumption feedback (left panel drain)**

When a craft confirms, the consumed stacks' quantities on the left-panel Inventory grid update with a quick number-tick-down (not a re-pop, since these slots aren't newly acquiring anything) plus a brief outward-fade pulse in Fieldstone Grey (world-neutral, not a semantic color) on the consumed slot's border — visually distinct from Inventory's own "new stack" Parchment Cream border pulse so a viewer can tell "quantity went down" from "quantity went up" at a glance without reading numbers.

**Rarity-tier visual coding (Common / Uncommon / Rare — names TBD)**

Shape-first, color-second, per Sec 4.5 discipline (color pairs must always have a non-color backup):

- **Common**: circular icon frame, Fieldstone Grey border.
- **Uncommon**: hexagonal icon frame, Scout Blue border.
- **Rare**: diamond icon frame, Herald Gold border — a controlled second use of gold, justified because both "rare material" and "achievement feedback" share the same "this is exceptional" semantic register, and Rare materials are infrequent enough that this doesn't dilute gold's scarcity value. Boss-Purple-adjacent is explicitly rejected (purple is boss-reserved, zero exceptions).
- Frame shape is the primary differentiator (works fully colorblind); border color is confirmatory only. This gives real material names (assigned below in Core Rules) a locked visual system to slot into.

**Audio direction (category only — no audio bible yet)**

- Tech-locked interaction attempt: soft negative-denial tone (short, low-register thud) — same category as Inventory's item-rejected feedback, not identical asset.
- Material-insufficient interaction attempt: distinct softer denial tone, one register higher than tech-locked's — communicates "closer" vs. "not yet."
- Unlock-cascade: a bright, short chime distinct from Inventory's slot-expansion fanfare (which is a longer "milestone" cue) — this is a frequent-ish event, so it must read as a positive blip, not a fanfare, to avoid audio fatigue.
- Craft-confirm: a satisfying "assembly" sound (mechanical/material-forming register, distinct from Inventory's acquisition "pop" sound) — immediately followed by Inventory's own pickup-pop sound when `item_added` fires; the two must be authored to not clash when played in the same ~0.1s window.

**Principles most directly invoked**: Sec 4.1 (Herald Gold's controlled second use), Sec 4.2 (Semantic Color Vocabulary), Sec 4.4 (UI-only colors), Sec 4.5 (Colorblind Safety, Pair 3 convention reused), Sec 3.3 (UI Shape Grammar, lock-icon reuse).

## UI Requirements

> **Relocation, 2026-08-21**: the right-hand Crafting panel (`InventoryScreen.tscn`'s `RightPanel`) now has its own 2-entry sub-tab strip — **Recipes** (this section's layout, default) and **Assemble Towers** (relocated here from the Forge screen's former 4th tab, player-requested; see `design/quick-specs/tower-assembly-2026-08-11.md`). The two sub-tabs share the same right-hand panel real estate, toggled via `RecipeScroll`/`AssembleView` visibility — Recipes' layout below is unaffected by the relocation, it just now sits alongside a sibling sub-tab instead of being the panel's only content.

**Recipe list layout and filtering**

- Recipes list vertically in the right-hand panel, grouped by output category (mirrors the left panel's fixed tabs where applicable — e.g., recipes that output Tower Components group separately from those outputting Crafted Goods) — reinforces the two-panel-as-one-screen relationship rather than introducing an unrelated recipe taxonomy.
- Default sort: Ready-to-craft first, then Material-insufficient, then Tech-locked last within each category — surfaces actionable content without hiding progression goals entirely.
- No player-customizable filtering/sorting at MVP, consistent with Inventory's own "fixed tabs, not customizable" decision — keeps both panels' interaction models symmetric.
- Selecting a recipe row highlights (non-color outline + slight scale, matching Inventory's focus-highlight language) the specific Inventory slots on the left panel that would be consumed — this is the concrete mechanism behind the Player Fantasy's "what could I make" moment already named in `inventory.md`.

**Cost display relative to current holdings**

- Each recipe's cost line lists required materials as `[icon] current/required` (e.g., a Common-tier icon reading "12/28").
- If current ≥ required: text renders in default UI Parchment.
- If current < required: text renders in UI Warning Orange, matching the material-insufficient state's icon-level treatment above — color redundantly reinforces the already-non-color-only state indicator, it is never the sole signal.

**Craft-confirm interaction**

Single confirm (click or gamepad confirm button), **not** a two-step "confirm the confirm" dialog:

- The recipe row already requires a deliberate prior selection step (select recipe → panel shows cost/preview → confirm crafts), which functions as a de facto two-touch interaction. A further "are you sure?" modal would be a third touch for a routine, frequent action.
- Precedent: Inventory never gates destructive-but-frequent actions (e.g., discard) behind confirmation dialogs — the project's established tone reserves modal confirmation for genuinely rare, hard-to-reverse actions, which crafting a recipe is not.
- Mitigation for the "permanently consumes materials" concern: the pre-confirm preview state must show projected post-craft quantities on the left panel's affected slots (not just current cost), so the consequence is fully visible before the single confirm.

**Gamepad navigation (must match Inventory's existing model)**

- D-pad/left-stick moves recipe-row selection with the same 2D spatial adjacency and tab-wrap-at-edges behavior as the Inventory grid — up/down moves within the recipe list, left/right (or shoulder buttons) crosses from the recipe list into the left-panel grid, treating the whole screen as one adjacency space rather than two separately-tabbed regions.
- Shoulder buttons (LB/RB) cycle recipe categories directly, mirroring Inventory's tab-cycle binding.
- Single confirm button crafts the currently-selected, currently-ready recipe; if the recipe isn't ready (locked/insufficient), confirm instead opens a context tooltip explaining why (mirrors Inventory's "confirm opens context menu" pattern rather than doing nothing silently).
- Focus rendering: same visible non-color highlight (outline + slight scale) as Inventory, applied identically to recipe rows.
- Keyboard-only mirrors the same adjacency model (arrow keys / Tab-Shift+Tab), matching Inventory's stated keyboard parity.

**Accessibility notes**

- All three recipe states (locked/insufficient/ready) carry a non-color cue (lock icon, "!" badge, filled-vs-outline confirm button) — no state is identifiable by color alone.
- Rarity-tier coding is shape-first (circle/hexagon/diamond frames), color-second, so rarity remains legible under any color-vision deficiency.
- Cost-insufficient text uses both color (Warning Orange) and the icon-level "!" badge — redundant signaling.
- The unlock-cascade's category pip badge is a numeral-bearing badge (not a color dot), so its presence and count are legible independent of color perception.

## Acceptance Criteria

- **AC-1**: GIVEN a recipe with `tech_prerequisite=""` and Inventory already
  holding its full `inputs` cost at the moment Crafting's discovery sweep
  runs on session start/save-load restore, WHEN that sweep executes, THEN
  `recipe_discovered` fires for that recipe exactly once. **Testability note
  (qa-lead)**: reworded from "WHEN Crafting initializes" — Rule 4 only
  defines two trigger paths (`tech_unlocked` and `item_added`); it does not
  define an initialization/restore-time sweep. This AC currently asserts
  behavior Rule 4 doesn't specify. See Open Questions — Rule 4 needs a third,
  explicit trigger path before this AC is implementable as written.
- **AC-2**: GIVEN a recipe with a `tech_prerequisite` not yet unlocked, WHEN
  the player holds its full `inputs` cost anyway, THEN `recipe_discovered`
  does NOT fire until the matching `tech_unlocked` event arrives.
- **AC-3**: GIVEN a `DISCOVERED` recipe, WHEN the player's material stock
  later drops below `inputs`, THEN the recipe remains visible in the
  Crafting panel (still `DISCOVERED`) but its Craft button becomes disabled.
- **AC-4**: GIVEN a craftable `tower_component` recipe and a full Inventory
  (no room for the output slot type, and no input stack the cost would fully
  empty — amended 2026-10-10, see Edge Cases), WHEN Craft is confirmed, THEN zero
  materials are consumed, no `component_crafted` fires, and the craft is
  rejected before any Inventory consume call. **Interface dependency,
  resolved 2026-07-17, found stale here 2026-09-02**: this AC exercises
  `Inventory.has_room_for()` — shipped (`src/core/inventory/inventory.gd`)
  since the same pass that closed AC-6's `clear_damaged_flag()` dependency
  below; this AC's own note was simply never updated to match. Automatable
  today.
- **AC-5**: GIVEN a craftable recipe, WHEN Craft is confirmed successfully,
  THEN materials are consumed, the output is added via `item_added`, and
  `component_crafted(component_id, component_type, quality_tier)` fires
  exactly once, synchronously, with no queue delay.
- **AC-6**: GIVEN a `damaged=true` Tower Component instance and sufficient
  Common material per Formula 3, WHEN Repair is confirmed, THEN the same
  `item_id` has `damaged` flipped to `false` (no new item created, no
  `component_crafted` fires), and the `component_repaired` event
  fires exactly once. **Interface dependency, resolved 2026-07-17, found
  stale here 2026-08-27**: this AC exercises both `Inventory.clear_damaged_flag()`
  and the `component_repaired` event — both are now shipped (see Open
  Questions and Dependencies).
- **AC-7**: GIVEN two craft confirmations arriving in the same frame, WHEN
  both are processed, THEN exactly one resolves fully and the second is
  rejected by the `_craft_resolving` guard — no double-consume of materials
  occurs.
- **AC-8**: GIVEN a Tier 4 `tower_component` recipe, WHEN its material cost
  is checked, THEN it matches Formula 1's table exactly: 32 Common + 16
  Uncommon + 8 Rare.
- **AC-9**: GIVEN a Tier 4 component instance with `damaged=true`, WHEN its
  repair cost is checked, THEN it matches Formula 3 exactly: 16 Common, zero
  Uncommon/Rare required.
- **AC-10** *(new — closes Formula 2 coverage gap)*: GIVEN a `crafted_good`
  recipe authored per Formula 2's guideline (e.g. a "Healing Salve ×3"
  recipe costing 6 Common), WHEN its material cost and output are checked,
  THEN they match the recipe's authored values exactly: 6 Common consumed,
  `output_quantity=3` produced, `quality_tier=0`. **Gap found**: no prior AC
  exercised Formula 2 or any `crafted_good`-category recipe at all.
- **AC-11** *(new — closes Rule 4 `item_added`-path coverage gap)*: GIVEN a
  tech-gate-satisfied recipe not yet `DISCOVERED`, WHEN an `item_added` event
  pushes the player's material stock to newly satisfy `has_items(inputs)`,
  THEN `recipe_discovered` fires exactly once for that recipe. **Gap found**:
  AC-1 and AC-2 only exercise the `tech_unlocked` trigger path and an
  initialization-time check; Rule 4's second trigger path (`item_added`) —
  arguably the most common real-play path — had no dedicated AC.
- **AC-12** *(new — closes Edge Case "materials insufficient at confirm-time"
  gap)*: GIVEN a Craft button rendered enabled from stale UI state, WHEN
  Craft is confirmed but Rule 8 step (a)'s re-validation of `has_items(inputs)`
  now returns `false` (another action consumed the materials in the
  interim), THEN the craft is rejected: zero materials consumed, no
  `item_added`, no `component_crafted`/`component_repaired`, and no error
  beyond a UI insufficient-materials state refresh. **Gap found**: this edge
  case (Rule 8 step (a)'s entire reason for existing) had no AC.
- **AC-13** *(new — closes Edge Case "no room for crafted good" gap)*: GIVEN
  a craftable `crafted_good` recipe and an Inventory with genuinely no room
  anywhere (no partial stack space, no open slot), WHEN Craft is confirmed,
  THEN materials ARE consumed (Rule 8 step (c) already executed, since
  `crafted_good` recipes skip the Rule 7 pre-check), the output-add attempt
  fails, `item_pickup_rejected` fires per `inventory.md`'s existing policy,
  and no `component_crafted` fires for the failed placement. **Gap found**:
  this edge case — the one place Crafting accepts an already-consumed,
  lost-output outcome — had no AC, despite being the specific asymmetry the
  Edge Cases section calls out against the `tower_component` case (AC-4).

## Open Questions

| Question | Owner | Notes |
|---|---|---|
| `Inventory.has_room_for(item_type, quantity) -> bool` | Inventory System owner | **RESOLVED 2026-07-17** — added to `inventory.md`'s Cross-System Query & Mutation APIs section, found stale here 2026-08-27. |
| `Inventory.clear_damaged_flag(item_id) -> bool` | Inventory System owner | **RESOLVED 2026-07-17** — same section, same fix. |
| `component_repaired(item_id, component_type)` | EventBus owner | **RESOLVED 2026-07-17** — merged into `event-bus.md`'s frozen catalogue (event count 76→78), same precedent as `tower_component_returned`/`item_pickup_rejected`. |
| Full recipe catalogue (how many recipes, at which tiers, gated behind which specific tech nodes) is content-authoring work, not design-rules work | game-designer / content pipeline | Explicitly out of scope for this GDD — this document defines the *mechanism*, not the catalogue. |
| Should `quality_tier`'s Weapon/Focus/Power "authoring signal" meaning (Rule 5) ever become a literal schema field on those components, for consistency with Foundation's `tier` field? | tower.md owner | Flagged, not resolved — would be a `tower.md` schema change, out of scope here. |
| Real material rarity names (Common/Uncommon/Rare are placeholders per `inventory.md`) | game-designer | This GDD was the designated owner of real naming per `inventory.md`'s own note, but does not resolve it here — naming is a content/narrative decision, not a mechanics one; the mechanism above is name-agnostic and works unchanged once real names are assigned. |
| **(qa-lead, AC review) Rule 4 has no defined initialization/save-load-restore trigger path** | Crafting GDD owner | AC-1 assumes recipes whose gates are already both-true get swept and `recipe_discovered`-fired at session start / restore, but Rule 4 only names two triggers (`tech_unlocked`, `item_added`). Needs either a third explicit trigger path added to Rule 4, or confirmation that `save-persistence.md`'s restore sequence re-fires enough `item_added` events to cover this case incidentally. Resolve before AC-1 is implementable as an automated test. |
| ~~(qa-lead, AC review) AC-4 and AC-6 depend on proposed-but-nonexistent Inventory interfaces~~ | — | **RESOLVED 2026-09-02** — both `Inventory.has_room_for()` and `Inventory.clear_damaged_flag()` have been shipped since 2026-07-17 (confirmed via direct grep of `inventory.gd`); AC-6 was updated to reflect this on 2026-08-27, but AC-4's own note was missed in that pass and still said "not automatable" until this correction. Both ACs are automatable today. |
